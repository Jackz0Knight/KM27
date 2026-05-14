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


func setup(roster_in: Array[Unit], formation_dict: Dictionary) -> void:
	roster = roster_in
	formation = formation_dict
	_prune_invalid()
	_build_once()
	_rebuild_icons()


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

	var pool_header := Label.new()
	pool_header.text = "Available Knights — drag onto a slot above"
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


# ---------- drop handlers ----------

func _on_slot_drop(unit_id: int, slot_key: String) -> void:
	# Remove the unit from any other slot (drag-from-slot to a different slot).
	for k in Combat.SLOTS:
		if k != slot_key and int(formation.get(k, -1)) == unit_id:
			formation[k] = -1
	formation[slot_key] = unit_id
	_rebuild_icons()
	formation_changed.emit()


func _on_pool_drop(unit_id: int) -> void:
	for k in Combat.SLOTS:
		if int(formation.get(k, -1)) == unit_id:
			formation[k] = -1
	_rebuild_icons()
	formation_changed.emit()
