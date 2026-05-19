class_name WorldMapView
extends GridContainer

# Reusable 15×15 world renderer. Each tile is a Button (so hover/click come
# for free) with a child `TileIcon` Control overlay that draws procedural
# decoration (terrain hint / castle tower / town keep / unknown question
# mark + optional expedition pennant). Re-call `render(world, selected)`
# whenever state changes.

signal tile_clicked(x: int, y: int)

const TILE_SIZE: Vector2 = Vector2(40, 40)
const SELECTION_COLOR: Color = Color(0.98, 0.88, 0.45)


func _ready() -> void:
	columns = World.SIZE
	add_theme_constant_override("h_separation", 2)
	add_theme_constant_override("v_separation", 2)


func render(world: World, selected: Vector2i = Vector2i(-1, -1)) -> void:
	for child in get_children():
		child.queue_free()
	for y in range(World.SIZE):
		for x in range(World.SIZE):
			add_child(_make_tile_button(world, world.tiles[x][y], selected))


func _make_tile_button(world: World, tile: MapTile, selected: Vector2i) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = TILE_SIZE
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ""   # Icon overlay handles all visual content.

	var is_known: bool = tile.knowledge == MapTile.Knowledge.EXPLORED
	var is_fogged: bool = (not is_known) and MapTile.is_fogged_in(world, tile.x, tile.y)
	var is_selected: bool = selected.x == tile.x and selected.y == tile.y

	# Background tint by tile type.
	var bg: Color
	var kind: int
	if not is_known:
		bg = Color(0.22, 0.20, 0.16) if is_fogged else Color(0.14, 0.12, 0.10)
		kind = TileIcon.Kind.FOGGED if is_fogged else TileIcon.Kind.UNKNOWN
	elif tile.terrain == MapTile.Terrain.TOWN:
		bg = Color(0.86, 0.66, 0.30)
		kind = TileIcon.Kind.TOWN
	elif tile.castle != null:
		bg = Color(0.62, 0.24, 0.22)
		kind = TileIcon.Kind.CASTLE
	else:
		bg = _terrain_color(tile.terrain)
		kind = TileIcon.Kind.TERRAIN

	_apply_tile_style(btn, bg, is_selected)

	# Decoration overlay — drawn on top of the bg by a child Control.
	var icon := TileIcon.new()
	var exp_weeks: int = -1
	if tile.active_expedition != null:
		exp_weeks = tile.active_expedition.weeks_remaining
	icon.configure(kind, tile.terrain, bg, exp_weeks)
	btn.add_child(icon)

	btn.tooltip_text = _tooltip_for(tile)
	btn.pressed.connect(_on_tile_pressed.bind(tile.x, tile.y))
	return btn


# Three near-identical styleboxes (normal / hover / pressed) so the tile
# colour stays stable through interaction. Selection draws a thick gold
# border so the highlighted tile pops out without competing with castles.
func _apply_tile_style(btn: Button, bg: Color, selected: bool) -> void:
	btn.add_theme_stylebox_override("normal", _tile_stylebox(bg, 1.0, selected))
	btn.add_theme_stylebox_override("hover", _tile_stylebox(bg, 1.10, selected))
	btn.add_theme_stylebox_override("pressed", _tile_stylebox(bg, 0.85, selected))
	btn.add_theme_stylebox_override("focus", _tile_stylebox(bg, 1.0, selected))


func _tile_stylebox(bg: Color, brightness: float, selected: bool) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var c: Color = bg
	if brightness != 1.0:
		c = c.lightened(brightness - 1.0) if brightness > 1.0 else c.darkened(1.0 - brightness)
	sb.bg_color = c
	if selected:
		sb.border_color = SELECTION_COLOR
		sb.border_width_left = 3
		sb.border_width_right = 3
		sb.border_width_top = 3
		sb.border_width_bottom = 3
	else:
		sb.border_color = Color(0.08, 0.06, 0.04)
		sb.border_width_left = 1
		sb.border_width_right = 1
		sb.border_width_top = 1
		sb.border_width_bottom = 1
	sb.corner_radius_top_left = 3
	sb.corner_radius_top_right = 3
	sb.corner_radius_bottom_left = 3
	sb.corner_radius_bottom_right = 3
	return sb


func _terrain_color(t: int) -> Color:
	# Slightly desaturated from the original palette so the drawn icons
	# (which use a darkened-bg ink) read with more contrast.
	match t:
		MapTile.Terrain.VILLAGE: return Color(0.78, 0.68, 0.42)
		MapTile.Terrain.PLAINS:  return Color(0.65, 0.78, 0.42)
		MapTile.Terrain.FOREST:  return Color(0.28, 0.55, 0.32)
		MapTile.Terrain.HILLS:   return Color(0.58, 0.50, 0.36)
		MapTile.Terrain.MOUNTAIN:return Color(0.48, 0.48, 0.50)
		MapTile.Terrain.BEACH:   return Color(0.92, 0.85, 0.58)
		MapTile.Terrain.OCEAN:   return Color(0.28, 0.45, 0.68)
	return Color.WHITE


func _tooltip_for(tile: MapTile) -> String:
	if tile.knowledge != MapTile.Knowledge.EXPLORED:
		# Note: we don't have `world` in scope here, so we can't tell fogged
		# from true unknown — the per-tile button does, and rendering already
		# differentiates them. The tooltip stays a generic Unknown hint.
		return "(%d,%d) — Unknown — send scouts to reveal" % [tile.x, tile.y]
	var bits: PackedStringArray = PackedStringArray()
	bits.append("(%d,%d) %s" % [tile.x, tile.y, MapTile.Terrain.keys()[tile.terrain]])
	if tile.castle != null:
		bits.append("Castle diff=%d" % tile.castle.difficulty)
	var res: String = tile.gather_resource()
	if res != "":
		bits.append("Yields %s" % res)
	if tile.active_expedition != null:
		bits.append("Active: %s (%dw)" % [
			tile.active_expedition.kind_label(),
			tile.active_expedition.weeks_remaining,
		])
	return "\n".join(bits)


func _on_tile_pressed(x: int, y: int) -> void:
	tile_clicked.emit(x, y)
