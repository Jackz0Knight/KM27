class_name KnightIcon
extends PanelContainer

# Draggable mini-icon for one Unit. Placeholder visuals only (initials +
# class colour); easy to swap for real portraits later. Click handler is
# optional — when set, clicking the icon (without dragging) opens that
# unit's Knight Overview screen.

const ICON_SIZE: Vector2 = Vector2(74, 74)

var unit: Unit
var on_click: Callable = Callable()
# Set by FormationEditor when this icon is hosted inside one. Right-clicking
# the icon then opens a "Assign to slot…" popup (alternative to drag-drop).
var on_assign_request: Callable = Callable()


func _ready() -> void:
	if unit == null:
		return
	custom_minimum_size = ICON_SIZE
	# Background colour by class — knight gold or squire pewter.
	var class_color: Color = Palette.KNIGHT if unit.unit_class == Unit.UnitClass.KNIGHT else Palette.SQUIRE
	add_theme_stylebox_override("panel", UiStyle.knight_tile(class_color))
	tooltip_text = _tooltip()

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	margin.add_child(vbox)

	var initials_lbl := Label.new()
	initials_lbl.text = _initials()
	initials_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	initials_lbl.add_theme_font_size_override("font_size", 22)
	initials_lbl.add_theme_color_override("font_color", Color(0.12, 0.08, 0.04))
	vbox.add_child(initials_lbl)

	var class_lbl := Label.new()
	class_lbl.text = unit.class_label()
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_lbl.add_theme_font_size_override("font_size", 11)
	class_lbl.add_theme_color_override("font_color", Color(0.18, 0.12, 0.08))
	vbox.add_child(class_lbl)


func _initials() -> String:
	var parts: PackedStringArray = unit.unit_name.split(" ", false)
	var out := ""
	for p in parts:
		if p.length() > 0:
			out += p.substr(0, 1)
	if out.length() > 2:
		out = out.substr(0, 2)
	return out.to_upper()


func _tooltip() -> String:
	return "%s — %s\nStr %d · Bra %d · Sword %d · Arch %d\nLea %d · Etq %d · Int %d" % [
		unit.unit_name, unit.class_label(),
		unit.stats.strength, unit.stats.bravery,
		unit.stats.swordsmanship, unit.stats.archery,
		unit.stats.leadership, unit.stats.etiquette, unit.stats.intimidation,
	]


# Standard Godot 4 drag — return any non-null Variant and we're draggable.
# Sets a small preview Control so the cursor carries a visual.
func _get_drag_data(_at_position: Vector2) -> Variant:
	var preview := KnightIcon.new()
	preview.unit = unit
	preview.modulate = Color(1, 1, 1, 0.85)
	set_drag_preview(preview)
	return {"type": "knight", "unit_id": unit.id}


func _gui_input(event: InputEvent) -> void:
	# Right-click → assignment popup (formation editor wires this). Cheap to
	# allow on every icon — if no host installed a callback the event is a no-op.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		if on_assign_request.is_valid():
			on_assign_request.call(self)
			accept_event()
		return
	if not on_click.is_valid():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Click registers on press; drag would cancel the click by starting drag-mode.
		# Mouse-released-here after a drag won't reach _gui_input the same way.
		pass
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		on_click.call()
