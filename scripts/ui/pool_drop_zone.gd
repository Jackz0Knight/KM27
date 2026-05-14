class_name PoolDropZone
extends PanelContainer

# Holds the un-slotted KnightIcons. Accepts a drop from any slot, returning
# that knight to the pool (`knight_returned(unit_id)`).

signal knight_returned(unit_id: int)


func _ready() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.2, 1.0)
	style.border_color = Color(0.35, 0.35, 0.4, 1.0)
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", style)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "knight"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	knight_returned.emit(int(data["unit_id"]))
