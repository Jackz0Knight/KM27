class_name WorldGenerator
extends RefCounted

# Deterministic world gen per GDD §3, §4.
#
# Same seed in → same World out. All randomness routes through the RNG autoload
# so a single `seed_run(seed)` at the top of `generate` makes every downstream
# roll reproducible.
#
# Rules enforced here:
#   • 15×15 grid; town at (7,7) gets TOWN terrain.
#   • The 9 tiles in the 3×3 box centred on town are revealed as EXPLORED.
#   • Every other tile gets a uniformly-random wilderness terrain.
#   • Exactly 8 castles, with difficulty spread across 30–200 via fixed anchors
#     ±10 jitter. Each castle reward = round(difficulty / 15) ± 1 per material.
#   • No castle within Chebyshev distance ≤ 2 of the town.

const WILDERNESS_TERRAINS: Array = [
	MapTile.Terrain.VILLAGE,
	MapTile.Terrain.PLAINS,
	MapTile.Terrain.FOREST,
	MapTile.Terrain.HILLS,
	MapTile.Terrain.MOUNTAIN,
	MapTile.Terrain.BEACH,
	MapTile.Terrain.OCEAN,
]

const CASTLE_DIFFICULTY_ANCHORS: Array[int] = [
	30, 55, 80, 105, 130, 155, 180, 205
]
const CASTLE_DIFFICULTY_MIN: int = 30
const CASTLE_DIFFICULTY_MAX: int = 200
const CASTLE_DIFFICULTY_JITTER: int = 10
const CASTLE_MIN_TOWN_DISTANCE: int = 3   # Chebyshev > 2 ⇒ ≥ 3
const CASTLE_PLACEMENT_ATTEMPTS: int = 200
# Week to feed to RewardTableDB when pre-rolling a castle's loot at world gen.
# The world is built at week 1, but castles are end-game assault targets — so
# we pre-roll using a mid-game baseline so the rewards aren't punishingly thin.
# `difficulty / 100.0` is the per-castle scalar applied on top.
const CASTLE_REWARD_BASELINE_WEEK: int = 20


static func generate(seed_value: int) -> World:
	RNG.seed_run(seed_value)

	var world := World.new()
	world.seed_value = seed_value

	_build_grid(world)
	_reveal_starting_area(world)
	_place_castles(world)

	return world


static func _build_grid(world: World) -> void:
	for x in range(World.SIZE):
		var col: Array = []
		for y in range(World.SIZE):
			var terrain: int
			if x == World.TOWN_X and y == World.TOWN_Y:
				terrain = MapTile.Terrain.TOWN
			else:
				terrain = WILDERNESS_TERRAINS[RNG.randi_range(0, WILDERNESS_TERRAINS.size() - 1)]
			col.append(MapTile.new(x, y, terrain))
		world.tiles.append(col)


static func _reveal_starting_area(world: World) -> void:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var nx: int = World.TOWN_X + dx
			var ny: int = World.TOWN_Y + dy
			if world.in_bounds(nx, ny):
				world.tiles[nx][ny].knowledge = MapTile.Knowledge.EXPLORED


static func _place_castles(world: World) -> void:
	for anchor in CASTLE_DIFFICULTY_ANCHORS:
		var castle: Castle = _try_place_castle(world, anchor)
		if castle != null:
			world.castles.append(castle)


static func _try_place_castle(world: World, anchor: int) -> Castle:
	var difficulty: int = clampi(
		anchor + RNG.randi_range(-CASTLE_DIFFICULTY_JITTER, CASTLE_DIFFICULTY_JITTER),
		CASTLE_DIFFICULTY_MIN,
		CASTLE_DIFFICULTY_MAX,
	)

	for _attempt in range(CASTLE_PLACEMENT_ATTEMPTS):
		var x: int = RNG.randi_range(0, World.SIZE - 1)
		var y: int = RNG.randi_range(0, World.SIZE - 1)
		if World.chebyshev(x, y, World.TOWN_X, World.TOWN_Y) < CASTLE_MIN_TOWN_DISTANCE:
			continue
		var tile: MapTile = world.tiles[x][y]
		if tile.castle != null:
			continue
		if tile.terrain == MapTile.Terrain.TOWN:
			continue
		# Ocean is impassable (MapTile.is_passable) — an expedition can never
		# target it, so a castle there can never be explored or assaulted: a
		# dead castle the chronicle still counts. Found 2026-06-10 via the
		# world_dump scene (seed 1627 placed its diff-174 castle at sea).
		# NOTE: this changes worldgen RNG consumption, so pre-fix saves that
		# regenerate their world from world_seed will see a shifted map —
		# same accepted degradation as the pre-seed-fix saves.
		if not tile.is_passable():
			continue
		# Position is decided; now derive the loot context from the surrounding
		# terrain and pre-roll the reward bundle. Mountain-country castles drop
		# ore, hill castles drop iron + cloth, everything else uses wilderness.
		var table_id: String = _castle_reward_table_for(world, x, y)
		var diff_mult: float = float(difficulty) / 100.0
		var reward: Dictionary = RewardTableDB.roll(
			table_id, CASTLE_REWARD_BASELINE_WEEK, diff_mult
		)
		var castle := Castle.new(x, y, difficulty, reward, table_id)
		tile.castle = castle
		return castle

	# Shouldn't happen with 8 castles on a 15×15 board, but return null rather
	# than crash so the dev dump can report the failure cleanly.
	return null


# Terrain context heuristic: count mountain / hill neighbours within Chebyshev 1
# of the castle. Mountain-dominant → mountain_loot; hill-dominant → hill_loot;
# everything else → wilderness_loot. The threshold of 2 means a single stray
# mountain tile doesn't shift the loot — it's the region, not the tile.
static func _castle_reward_table_for(world: World, x: int, y: int) -> String:
	var mountain_neighbours: int = 0
	var hill_neighbours: int = 0
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if not world.in_bounds(nx, ny):
				continue
			var t: int = world.tiles[nx][ny].terrain
			if t == MapTile.Terrain.MOUNTAIN:
				mountain_neighbours += 1
			elif t == MapTile.Terrain.HILLS:
				hill_neighbours += 1
	if mountain_neighbours >= 2:
		return "mountain_loot"
	if hill_neighbours >= 2:
		return "hill_loot"
	return "wilderness_loot"
