extends Control

# Phase 1 dev tool. Generates a World via WorldGenerator and renders the result
# to a RichTextLabel (and prints to the output panel). Also runs a battery of
# sanity checks against the GDD §3, §4 rules and a determinism comparison.
#
# Run in the editor with F6 while this scene is open.

@export var test_seed: int = 1627
@export var compare_seed: int = 1627   # If == test_seed, a second gen is compared for determinism.

@onready var output: RichTextLabel = $Scroll/Output


func _ready() -> void:
	var report: String = _build_report()
	output.text = "[code]%s[/code]" % report
	print(report)


func _build_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("KM27 — world_dump")
	lines.append("seed = %d" % test_seed)
	lines.append("")

	var world: World = WorldGenerator.generate(test_seed)

	lines.append(_render_terrain_grid(world))
	lines.append("")
	lines.append(_render_knowledge_grid(world))
	lines.append("")
	lines.append("Castles (%d):" % world.castles.size())
	for c in world.castles:
		var cheb: int = World.chebyshev(c.x, c.y, World.TOWN_X, World.TOWN_Y)
		var tile_terrain: String = MapTile.Terrain.keys()[world.tiles[c.x][c.y].terrain]
		lines.append("  (%2d,%2d) diff=%3d cheb=%d on=%s reward=%s" % [
			c.x, c.y, c.difficulty, cheb, tile_terrain, c.reward.describe(),
		])
	lines.append("")

	var violations: Array = _validate(world)
	if violations.is_empty():
		lines.append("[ok] All Phase 1 checks passed.")
	else:
		lines.append("[!! VIOLATIONS] (%d):" % violations.size())
		for v in violations:
			lines.append("  - " + v)
	lines.append("")

	# Determinism check: regenerate with the same seed and compare.
	var world_b: World = WorldGenerator.generate(test_seed)
	var det_ok: bool = _worlds_match(world, world_b)
	lines.append("Determinism: same seed produces %s world." % (
		"the SAME" if det_ok else "a DIFFERENT (!) "
	))

	return "\n".join(lines)


# Grid 1: terrain. Town renders as '@', castles overlay terrain as 'C'.
func _render_terrain_grid(world: World) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Terrain (@ town, V village, . plains, F forest, h hills, M mountain, b beach, ~ ocean, C castle):")
	for y in range(World.SIZE):
		var row: String = ""
		for x in range(World.SIZE):
			var tile: MapTile = world.tiles[x][y]
			var ch: String = tile.terrain_code()
			if tile.castle != null:
				ch = "C"
			row += ch + " "
		lines.append(row.strip_edges(false, true))
	return "\n".join(lines)


# Grid 2: knowledge mask. Useful for verifying the 3x3 reveal at start.
func _render_knowledge_grid(world: World) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Knowledge (X explored, . unknown):")
	for y in range(World.SIZE):
		var row: String = ""
		for x in range(World.SIZE):
			var tile: MapTile = world.tiles[x][y]
			row += ("X " if tile.knowledge == MapTile.Knowledge.EXPLORED else ". ")
		lines.append(row.strip_edges(false, true))
	return "\n".join(lines)


func _validate(world: World) -> Array:
	var v: Array = []

	var centre: MapTile = world.tiles[World.TOWN_X][World.TOWN_Y]
	if centre.terrain != MapTile.Terrain.TOWN:
		v.append("Centre tile (%d,%d) is not TOWN terrain." % [World.TOWN_X, World.TOWN_Y])

	var explored: int = world.count_tiles_with(MapTile.Knowledge.EXPLORED)
	if explored != 9:
		v.append("Explored count = %d, expected 9." % explored)

	for x in range(World.SIZE):
		for y in range(World.SIZE):
			var tile: MapTile = world.tiles[x][y]
			var cheb: int = World.chebyshev(x, y, World.TOWN_X, World.TOWN_Y)
			var should_be_explored: bool = cheb <= 1
			var is_explored: bool = tile.knowledge == MapTile.Knowledge.EXPLORED
			if should_be_explored != is_explored:
				v.append("Tile (%d,%d) explored=%s but cheb=%d (expected explored=%s)."
					% [x, y, is_explored, cheb, should_be_explored])

	if world.castles.size() != 8:
		v.append("Castle count = %d, expected 8." % world.castles.size())

	for c in world.castles:
		var cheb: int = World.chebyshev(c.x, c.y, World.TOWN_X, World.TOWN_Y)
		if cheb < 3:
			v.append("Castle at (%d,%d) cheb=%d (< 3 from town)." % [c.x, c.y, cheb])
		if c.difficulty < 30 or c.difficulty > 200:
			v.append("Castle at (%d,%d) difficulty=%d (out of [30,200])."
				% [c.x, c.y, c.difficulty])
		var registered: Castle = world.tiles[c.x][c.y].castle
		if registered != c:
			v.append("Castle at (%d,%d) not registered on its tile." % [c.x, c.y])

	# Unique castle tiles.
	var seen_coords: Dictionary = {}
	for c in world.castles:
		var key: String = "%d,%d" % [c.x, c.y]
		if seen_coords.has(key):
			v.append("Two castles on the same tile (%s)." % key)
		seen_coords[key] = true

	return v


func _worlds_match(a: World, b: World) -> bool:
	if a.castles.size() != b.castles.size():
		return false
	for i in range(a.castles.size()):
		var ca: Castle = a.castles[i]
		var cb: Castle = b.castles[i]
		if ca.x != cb.x or ca.y != cb.y or ca.difficulty != cb.difficulty:
			return false
		if ca.reward.wood != cb.reward.wood \
			or ca.reward.fibres != cb.reward.fibres \
			or ca.reward.copper_ore != cb.reward.copper_ore:
			return false
	for x in range(World.SIZE):
		for y in range(World.SIZE):
			if a.tiles[x][y].terrain != b.tiles[x][y].terrain:
				return false
			if a.tiles[x][y].knowledge != b.tiles[x][y].knowledge:
				return false
	return true
