class_name PoolDropZone
extends PanelContainer

# Holds the un-slotted KnightIcons. Accepts a drop from any slot, returning
# that knight to the pool (`knight_returned(unit_id)`).

signal knight_returned(unit_id: int)


func _ready() -> void:
	# Faint pool background — sits behind the unslotted knight icons.
	add_theme_stylebox_override("panel", UiStyle.chip(
		Color(0.16, 0.16, 0.2, 1.0), Color(0.35, 0.35, 0.4, 1.0), 1,
	))


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "knight"


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return
	knight_returned.emit(int(data["unit_id"]))
