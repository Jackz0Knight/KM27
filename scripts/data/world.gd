class_name World
extends Resource

# The 15×15 game world per GDD §4. Built by WorldGenerator.generate(seed).
# Tiles are stored column-major: `tiles[x][y]` is the cell at (x, y).

const SIZE: int = 15
const TOWN_X: int = 7
const TOWN_Y: int = 7

var seed_value: int = 0
var tiles: Array = []         # Array[Array[MapTile]]
var castles: Array = []       # Array[Castle]


func get_tile(x: int, y: int) -> MapTile:
	if not in_bounds(x, y):
		return null
	return tiles[x][y]


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < SIZE and y >= 0 and y < SIZE


# Chebyshev distance — also the "king's move" distance. Used by the world gen
# rule that no castle may sit within 2 tiles of the player's town.
static func chebyshev(ax: int, ay: int, bx: int, by: int) -> int:
	return maxi(absi(ax - bx), absi(ay - by))


func count_tiles_with(predicate_knowledge: int) -> int:
	var n: int = 0
	for col in tiles:
		for tile in col:
			if tile.knowledge == predicate_knowledge:
				n += 1
	return n
