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

const CASTLE_DIFFICULTY_ANCHORS: PackedInt32Array = PackedInt32Array([
	30, 55, 80, 105, 130, 155, 180, 205
])
const CASTLE_DIFFICULTY_MIN: int = 30
const CASTLE_DIFFICULTY_MAX: int = 200
const CASTLE_DIFFICULTY_JITTER: int = 10
const CASTLE_REWARD_DIVISOR: int = 15
const CASTLE_REWARD_JITTER: int = 1
const CASTLE_MIN_TOWN_DISTANCE: int = 3   # Chebyshev > 2 ⇒ ≥ 3
const CASTLE_PLACEMENT_ATTEMPTS: int = 200


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
	var reward: ResourceBundle = _roll_castle_reward(difficulty)

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
		var castle := Castle.new(x, y, difficulty, reward)
		tile.castle = castle
		return castle

	# Shouldn't happen with 8 castles on a 15×15 board, but return null rather
	# than crash so the dev dump can report the failure cleanly.
	return null


static func _roll_castle_reward(difficulty: int) -> ResourceBundle:
	var base: int = roundi(float(difficulty) / float(CASTLE_REWARD_DIVISOR))
	var wood: int = maxi(0, base + RNG.randi_range(-CASTLE_REWARD_JITTER, CASTLE_REWARD_JITTER))
	var fibres: int = maxi(0, base + RNG.randi_range(-CASTLE_REWARD_JITTER, CASTLE_REWARD_JITTER))
	var copper: int = maxi(0, base + RNG.randi_range(-CASTLE_REWARD_JITTER, CASTLE_REWARD_JITTER))
	return ResourceBundle.new(wood, fibres, copper)
