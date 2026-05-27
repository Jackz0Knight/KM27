class_name FormationEditor
extends VBoxContainer

# Drag-and-drop formation editor. Hosts 4 SlotDropZones (Blue / Green /
# Yellow / Red) on top of a PoolDropZone showing un-slotted Knights as
# draggable KnightIcons. Used by both the Tactics tab (persistent default
# formations) and the Pre-Battle Review screen (this week's formation).
#
# Caller seeds it once with `setup(roster, formation_dict)`. Drops mutate
# the formation_dict in place and emit `formation_changed`. Roster filter
# (e.g. away party only) is the caller's responsibility — only Units in
# `roster` show up as draggable icons.

signal formation_changed

var roster: Array[Unit] = []
var formation: Dictionary = {}

var _slots_row: HBoxContainer = null
var _slot_zones: Dictionary = {}      # slot_key -> SlotDropZone
var _pool: PoolDropZone = null
var _pool_row: HBoxContainer = null
var _power_lbl: Label = null
var _power_breakdown_lbl: Label = null


func setup(roster_in: Array[Unit], formation_dict: Dictionary) -> void:
	roster = roster_in
	formation = formation_dict
	_prune_invalid()
	_build_once()
	_rebuild_icons()
	_refresh_power_readout()


# Drop slot assignments that don't match a current roster unit (e.g. unit
# went on expedition, so they shouldn't appear in the formation this week).
func _prune_invalid() -> void:
	var allowed: Array[int] = []
	for u in roster:
		allowed.append(u.id)
	for slot_key in Combat.SLOTS:
		if not allowed.has(int(formation.get(slot_key, -1))):
			formation[slot_key] = -1


func _build_once() -> void:
	# Build slot row + pool only on the first call; subsequent updates
	# reuse them.
	if _slots_row != null:
		return

	add_theme_constant_override("separation", 14)

	_slots_row = HBoxContainer.new()
	_slots_row.add_theme_constant_override("separation", 10)
	_slots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_slots_row)

	for slot_key in Combat.SLOTS:
		var zone := SlotDropZone.new()
		zone.set_slot(slot_key, Combat.SLOT_LABELS[slot_key])
		zone.knight_dropped.connect(_on_slot_drop)
		_slots_row.add_child(zone)
		_slot_zones[slot_key] = zone

	# Projected combat power — sits between the slot row and the pool so the
	# player can see the math update as they place units. Two lines: a bold
	# total + a quieter per-slot breakdown.
	_power_lbl = Label.new()
	_power_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_lbl.add_theme_font_size_override("font_size", 14)
	_power_lbl.modulate = Color(0.92, 0.84, 0.55)
	add_child(_power_lbl)

	_power_breakdown_lbl = Label.new()
	_power_breakdown_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_power_breakdown_lbl.add_theme_font_size_override("font_size", 12)
	_power_breakdown_lbl.modulate = Color(0.72, 0.68, 0.55)
	add_child(_power_breakdown_lbl)

	var pool_header := Label.new()
	pool_header.text = "Available Knights — drag onto a slot above (right-click for menu)"
	pool_header.modulate = Color(0.72, 0.72, 0.72)
	add_child(pool_header)

	_pool = PoolDropZone.new()
	_pool.knight_returned.connect(_on_pool_drop)
	_pool.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_pool)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_pool.add_child(margin)

	_pool_row = HBoxContainer.new()
	_pool_row.add_theme_constant_override("separation", 8)
	margin.add_child(_pool_row)


func _rebuild_icons() -> void:
	# Reset both slot occupants and pool contents from the current formation
	# state. Cheap enough to do on every change because we have ≤ 4 units.
	for slot_key in Combat.SLOTS:
		var zone: SlotDropZone = _slot_zones[slot_key]
		var unit_id: int = int(formation.get(slot_key, -1))
		var unit: Unit = _find_unit(unit_id)
		if unit != null:
			zone.set_occupant(_make_icon(unit))
			zone.set_matched(Combat.is_slot_match(unit, slot_key))
		else:
			zone.set_occupant(null)
			zone.set_matched(false)

	# Pool = everyone NOT currently in a slot.
	for child in _pool_row.get_children():
		child.queue_free()
	var pool_units := _unslotted_units()
	if pool_units.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "(all knights are slotted)"
		empty_lbl.modulate = Color(0.6, 0.6, 0.6)
		_pool_row.add_child(empty_lbl)
	else:
		for u in pool_units:
			_pool_row.add_child(_make_icon(u))


func _make_icon(unit: Unit) -> KnightIcon:
	var icon := KnightIcon.new()
	icon.unit = unit
	icon.on_assign_request = _open_assign_popup
	return icon


func _unslotted_units() -> Array[Unit]:
	var slotted_ids: Array[int] = []
	for slot_key in Combat.SLOTS:
		var uid: int = int(formation.get(slot_key, -1))
		if uid >= 0:
			slotted_ids.append(uid)
	var out: Array[Unit] = []
	for u in roster:
		if not slotted_ids.has(u.id):
			out.append(u)
	return out


func _find_unit(unit_id: int) -> Unit:
	if unit_id < 0:
		return null
	for u in roster:
		if u.id == unit_id:
			return u
	return null


# ---------- power readout ----------

func _refresh_power_readout() -> void:
	if _power_lbl == null:
		return
	# Build the participants list from whoever is currently in roster, then
	# call the same Combat.resolve_formation the real battle uses (with
	# enemy_power=0 so the result is pure projection). This keeps the
	# preview honest — if the formula changes, the preview tracks it.
	var participants: Array[Unit] = []
	for u in roster:
		participants.append(u)
	if participants.is_empty():
		_power_lbl.text = "Projected combat power: —"
		_power_breakdown_lbl.text = ""
		return

	var result: Dictionary = Combat.resolve_formation(participants, formation, 0, false)
	var per_unit: Array = result["per_unit"]
	var total: int = int(result["player_total"])

	# Per-slot breakdown — one chip per filled slot, dash for empty.
	var by_unit: Dictionary = {}
	for entry in per_unit:
		by_unit[int(entry["unit_id"])] = entry

	var slot_bits: PackedStringArray = PackedStringArray()
	var filled: int = 0
	for slot_key in Combat.SLOTS:
		var uid: int = int(formation.get(slot_key, -1))
		var short: String = String(slot_key).substr(0, 1).to_upper()
		if uid >= 0 and by_unit.has(uid):
			filled += 1
			slot_bits.append("%s %d" % [short, int(by_unit[uid]["total"])])
		else:
			slot_bits.append("%s —" % short)

	_power_lbl.text = "Projected combat power: %d  ·  %d/4 slots filled" % [total, filled]
	_power_breakdown_lbl.text = "Per slot:  " + "   ".join(slot_bits)


# ---------- right-click assign popup ----------

# A KnightIcon asks the editor "where can I be assigned?" — we open a popup
# next to the icon and on pick run the same path as a drag-drop.
func _open_assign_popup(icon: KnightIcon) -> void:
	if icon == null or icon.unit == null:
		return
	var unit_id: int = icon.unit.id
	var popup := PopupMenu.new()
	for i in range(Combat.SLOTS.size()):
		var slot_key: String = Combat.SLOTS[i]
		var current: int = int(formation.get(slot_key, -1))
		var match_glyph: String = "★" if Combat.is_slot_match(icon.unit, slot_key) else " "
		var occ_name: String = ""
		if current >= 0 and current != unit_id:
			var occ: Unit = _find_unit(current)
			occ_name = "  (replaces %s)" % occ.unit_name if occ != null else ""
		popup.add_item("%s  %s%s" % [match_glyph, Combat.SLOT_LABELS[slot_key], occ_name], i)
	# A second separator + "Return to pool" entry when the unit is currently
	# slotted, so right-click is a one-stop control surface.
	if _is_unit_slotted(unit_id):
		popup.add_separator()
		popup.add_item("Return to pool", Combat.SLOTS.size())
	popup.id_pressed.connect(_on_assign_popup_picked.bind(unit_id, popup))
	popup.close_requested.connect(func(): popup.queue_free())
	add_child(popup)
	var p: Vector2 = icon.get_screen_position() + Vector2(0, icon.size.y)
	popup.position = Vector2i(p)
	popup.popup()


func _on_assign_popup_picked(picked: int, unit_id: int, popup: PopupMenu) -> void:
	if picked >= 0 and picked < Combat.SLOTS.size():
		_on_slot_drop(unit_id, Combat.SLOTS[picked])
	elif picked == Combat.SLOTS.size():
		_on_pool_drop(unit_id)
	popup.queue_free()


func _is_unit_slotted(unit_id: int) -> bool:
	for k in Combat.SLOTS:
		if int(formation.get(k, -1)) == unit_id:
			return true
	return false


# ---------- drop handlers ----------

func _on_slot_drop(unit_id: int, slot_key: String) -> void:
	# Remove the unit from any other slot (drag-from-slot to a different slot).
	for k in Combat.SLOTS:
		if k != slot_key and int(formation.get(k, -1)) == unit_id:
			formation[k] = -1
	formation[slot_key] = unit_id
	_rebuild_icons()
	_refresh_power_readout()
	formation_changed.emit()


func _on_pool_drop(unit_id: int) -> void:
	for k in Combat.SLOTS:
		if int(formation.get(k, -1)) == unit_id:
			formation[k] = -1
	_rebuild_icons()
	_refresh_power_readout()
	formation_changed.emit()


# ---------- drag preview wiring ----------
#
# Godot raises NOTIFICATION_DRAG_BEGIN / NOTIFICATION_DRAG_END to every Control
# in the tree when a drag is active. We use that to scan the active drag data
# for a knight unit_id, then ask every slot zone whether the dragged unit
# matches its bonus axis — slots that match light up gold while the drag is
# in flight, and clear on release. No polling, no per-frame work.

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN:
		_apply_drag_preview()
	elif what == NOTIFICATION_DRAG_END:
		_clear_drag_preview()


func _apply_drag_preview() -> void:
	if _slot_zones.is_empty():
		return
	var data: Variant = get_viewport().gui_get_drag_data()
	if not (data is Dictionary) or data.get("type", "") != "knight":
		return
	var unit_id: int = int(data.get("unit_id", -1))
	var unit: Unit = _find_unit(unit_id)
	if unit == null:
		return
	for slot_key in Combat.SLOTS:
		var zone: SlotDropZone = _slot_zones[slot_key]
		zone.set_preview_match(Combat.is_slot_match(unit, slot_key))


func _clear_drag_preview() -> void:
	for slot_key in Combat.SLOTS:
		var zone: SlotDropZone = _slot_zones.get(slot_key)
		if zone != null:
			zone.set_preview_match(false)
