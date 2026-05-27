class_name SlotDropZone
extends PanelContainer

# One of the 4 formation slots in a FormationEditor. Accepts a dragged
# KnightIcon; emits `knight_dropped(unit_id, slot_key)` for the parent
# to apply. Visually displays slot label + current occupant (or "(empty)").

signal knight_dropped(unit_id: int, slot_key: String)

const SLOT_SIZE: Vector2 = Vector2(170, 170)

var slot_key: String = "blue"
var slot_label: String = "Slot"
var occupant: KnightIcon = null
var matched: bool = false
# Live drag preview state — true while the cursor is dragging a knight icon
# whose primary stat matches this slot's bonus axis. Independent of `matched`
# (which describes the currently-dropped occupant). Repaints the border with
# a gold glow so the player can see "yes, drop here" before releasing.
var preview_match: bool = false


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	_apply_style()
	_build()


func set_slot(key: String, label: String) -> void:
	slot_key = key
	slot_label = label
	if is_inside_tree():
		_build()


# Place a fresh KnightIcon into this slot (caller passes a NEW icon, since
# the icon may have come from elsewhere). Pass null to clear.
func set_occupant(icon: KnightIcon) -> void:
	occupant = icon
	_build()


func set_matched(is_match: bool) -> void:
	matched = is_match
	_apply_style()


func set_preview_match(is_match: bool) -> void:
	if preview_match == is_match:
		return
	preview_match = is_match
	_apply_style()


func _apply_style() -> void:
	# Three visual states share the same chip shape — only colour + border
	# width vary. UiStyle.slot() builds the chip; this function just picks
	# which palette pair to feed it.
	var style: StyleBoxFlat
	if preview_match:
		# Live "drop here" hint — gold glow + warm bed, distinct from the
		# post-drop green-match border so the two states never blur together.
		style = UiStyle.slot(Palette.SLOT_BG_PREVIEW, Palette.SLOT_BORDER_PREVIEW, 3)
	elif matched:
		style = UiStyle.slot(Palette.SLOT_BG_MATCHED, Palette.SLOT_BORDER_MATCHED, 2)
	else:
		style = UiStyle.slot(Palette.SLOT_BG_IDLE, Palette.SLOT_BORDER_IDLE, 2)
	add_theme_stylebox_override("panel", style)


func _build() -> void:
	for child in get_children():
		child.queue_free()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var label := Label.new()
	label.text = slot_label
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(label)

	if occupant != null:
		var center := CenterContainer.new()
		center.add_child(occupant)
		vbox.add_child(center)
	else:
		var empty_lbl := Label.new()
		empty_lbl.text = "(empty)"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.modulate = Color(0.65, 0.65, 0.65)
		vbox.add_child(empty_lbl)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "knight"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	knight_dropped.emit(int(data["unit_id"]), slot_key)
