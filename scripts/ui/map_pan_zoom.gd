class_name MapPanZoom
extends Control

# Wraps a WorldMapView in a pan/zoom-capable viewport. Used by the Town & Map
# tab — the raw map (15×15 tiles at 40px each) doesn't always fit; the player
# can scroll-wheel to zoom and middle-mouse-drag to pan. Left-click on tiles
# still selects them (tile_clicked signal). Center-on-town is callable so the
# tab can recenter every time it's reopened.

signal tile_clicked(x: int, y: int)

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 2.5
const ZOOM_STEP: float = 1.12

var _world: World = null
var _map: WorldMapView = null
var _dragging: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	_map = WorldMapView.new()
	_map.tile_clicked.connect(_on_tile_clicked)
	add_child(_map)


func set_world(world: World) -> void:
	_world = world
	_map.render(world)
	# Layout sizes for the new WorldMapView aren't known until the next frame;
	# wait one tick so the centering math has the correct dimensions.
	await get_tree().process_frame
	center_on_town()


func refresh(selected: Vector2i = Vector2i(-1, -1)) -> void:
	if _world != null and _map != null:
		_map.render(_world, selected)


# Reset zoom to 1.0 and pan so the town tile (centre of the world) sits at
# the centre of the viewport. Called when first showing the map and every
# time the player returns to the Town & Map tab.
func center_on_town() -> void:
	if _map == null:
		return
	_map.scale = Vector2.ONE
	var pitch: float = WorldMapView.TILE_SIZE.x + 2.0   # tile + h_separation
	var town_center_local := Vector2(
		World.TOWN_X * pitch + WorldMapView.TILE_SIZE.x * 0.5,
		World.TOWN_Y * pitch + WorldMapView.TILE_SIZE.y * 0.5,
	)
	_map.position = size * 0.5 - town_center_local


# Hooked at the global _input level so middle-click and wheel events reach us
# even though the WorldMapView's tile Buttons cover the full grid. Left-click
# events pass through to the buttons unchanged so tile selection still works.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton:
		var global_pos: Vector2 = event.position
		if not get_global_rect().has_point(global_pos):
			return
		var local_pos: Vector2 = global_pos - global_position
		match event.button_index:
			MOUSE_BUTTON_MIDDLE:
				_dragging = event.pressed
				get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					_zoom_at(ZOOM_STEP, local_pos)
					get_viewport().set_input_as_handled()
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					_zoom_at(1.0 / ZOOM_STEP, local_pos)
					get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_map.position += event.relative
		get_viewport().set_input_as_handled()


func _zoom_at(factor: float, anchor: Vector2) -> void:
	var current: float = _map.scale.x
	var new_scale: float = clampf(current * factor, MIN_ZOOM, MAX_ZOOM)
	if is_equal_approx(new_scale, current):
		return
	# Keep the world point under the cursor stationary while zooming.
	var ratio: float = new_scale / current
	_map.position = anchor + (_map.position - anchor) * ratio
	_map.scale = Vector2(new_scale, new_scale)


func _on_tile_clicked(x: int, y: int) -> void:
	tile_clicked.emit(x, y)
