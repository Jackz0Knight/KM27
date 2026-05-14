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


func _apply_style() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.22, 0.22, 0.26, 1.0)
	if matched:
		style.border_color = Color(0.55, 0.95, 0.55, 1.0)
		style.bg_color = Color(0.20, 0.30, 0.22, 1.0)
	else:
		style.border_color = Color(0.45, 0.45, 0.5, 1.0)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
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
