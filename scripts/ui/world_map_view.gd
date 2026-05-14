class_name WorldMapView
extends GridContainer

# Reusable 15×15 world renderer. Each tile is a Button so we get hover and
# click for free. Emits `tile_clicked(x, y)` so the parent screen can wire
# it up. Re-call `render(world, selected)` whenever state changes.

signal tile_clicked(x: int, y: int)

const TILE_SIZE: Vector2 = Vector2(40, 40)


func _ready() -> void:
	columns = World.SIZE
	add_theme_constant_override("h_separation", 2)
	add_theme_constant_override("v_separation", 2)


func render(world: World, selected: Vector2i = Vector2i(-1, -1)) -> void:
	for child in get_children():
		child.queue_free()
	for y in range(World.SIZE):
		for x in range(World.SIZE):
			add_child(_make_tile_button(world.tiles[x][y], selected))


func _make_tile_button(tile: MapTile, selected: Vector2i) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = TILE_SIZE
	btn.focus_mode = Control.FOCUS_NONE

	var is_known: bool = tile.knowledge == MapTile.Knowledge.EXPLORED
	var has_active: bool = tile.active_expedition != null

	var bg: Color
	if not is_known:
		btn.text = "?"
		bg = Color(0.22, 0.20, 0.18)
	elif tile.castle != null:
		btn.text = "C"
		bg = Color(0.62, 0.20, 0.20)
	elif tile.terrain == MapTile.Terrain.TOWN:
		btn.text = "@"
		bg = Color(0.85, 0.65, 0.22)
	else:
		btn.text = tile.terrain_code()
		bg = _terrain_color(tile.terrain)

	if has_active:
		btn.text = "%s\n%dw" % [btn.text, tile.active_expedition.weeks_remaining]
	if selected.x == tile.x and selected.y == tile.y:
		bg = bg.lightened(0.30)

	# Apply tile-specific styles so the project theme's burgundy button bg
	# doesn't tint the terrain. Buttons keep their normal click behaviour.
	_apply_tile_style(btn, bg)
	# Dark text reads cleanly on the warm tile palette.
	var text_col := Color(0.12, 0.10, 0.08)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", text_col)
	btn.add_theme_color_override("font_pressed_color", text_col)

	btn.tooltip_text = _tooltip_for(tile)
	btn.pressed.connect(_on_tile_pressed.bind(tile.x, tile.y))
	return btn


# Three near-identical styleboxes (normal / hover / pressed) so the tile
# colour stays stable through interaction. Hover lightens slightly.
func _apply_tile_style(btn: Button, bg: Color) -> void:
	btn.add_theme_stylebox_override("normal", _tile_stylebox(bg, 1.0))
	btn.add_theme_stylebox_override("hover", _tile_stylebox(bg, 1.12))
	btn.add_theme_stylebox_override("pressed", _tile_stylebox(bg, 0.85))
	btn.add_theme_stylebox_override("focus", _tile_stylebox(bg, 1.0))


func _tile_stylebox(bg: Color, brightness: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c: Color = bg
	if brightness != 1.0:
		c = c.lightened(brightness - 1.0) if brightness > 1.0 else c.darkened(1.0 - brightness)
	sb.bg_color = c
	sb.border_color = Color(0.08, 0.06, 0.04)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 2
	sb.corner_radius_top_right = 2
	sb.corner_radius_bottom_left = 2
	sb.corner_radius_bottom_right = 2
	return sb


func _terrain_color(t: int) -> Color:
	match t:
		MapTile.Terrain.VILLAGE: return Color(0.85, 0.7, 0.4)
		MapTile.Terrain.PLAINS: return Color(0.7, 0.85, 0.4)
		MapTile.Terrain.FOREST: return Color(0.32, 0.65, 0.38)
		MapTile.Terrain.HILLS: return Color(0.65, 0.55, 0.4)
		MapTile.Terrain.MOUNTAIN: return Color(0.55, 0.55, 0.55)
		MapTile.Terrain.BEACH: return Color(0.95, 0.9, 0.6)
		MapTile.Terrain.OCEAN: return Color(0.32, 0.5, 0.8)
	return Color.WHITE


func _tooltip_for(tile: MapTile) -> String:
	if tile.knowledge != MapTile.Knowledge.EXPLORED:
		return "(%d,%d) — Unknown" % [tile.x, tile.y]
	var bits: PackedStringArray = PackedStringArray()
	bits.append("(%d,%d) %s" % [tile.x, tile.y, MapTile.Terrain.keys()[tile.terrain]])
	if tile.castle != null:
		bits.append("Castle diff=%d" % tile.castle.difficulty)
	var res: String = tile.gather_resource()
	if res != "":
		bits.append("Yields %s" % res)
	if tile.active_expedition != null:
		bits.append("Active: %s" % tile.active_expedition.kind_label())
	return "\n".join(bits)


func _on_tile_pressed(x: int, y: int) -> void:
	tile_clicked.emit(x, y)
