class_name MapTile
extends Resource

# One cell of the 15×15 world grid per GDD §4. Terrain → gather resource is a
# function (see `gather_resource()`), so we only store terrain and derive
# resource on demand — no duplication / drift.

enum Terrain { TOWN, VILLAGE, PLAINS, FOREST, HILLS, MOUNTAIN, BEACH, OCEAN }
enum Knowledge { UNKNOWN, EXPLORED, EXPEDITION_ACTIVE }


# Derived fog state — true when the tile is still UNKNOWN but borders at least
# one EXPLORED tile. The map view renders these differently so the player can
# see "this is the next ring you could send scouts into" without persisting an
# extra knowledge state (and without touching save format).
static func is_fogged_in(world: World, tx: int, ty: int) -> bool:
	if world == null:
		return false
	var t: MapTile = world.get_tile(tx, ty)
	if t == null or t.knowledge != Knowledge.UNKNOWN:
		return false
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var neigh: MapTile = world.get_tile(tx + dx, ty + dy)
			if neigh != null and neigh.knowledge == Knowledge.EXPLORED:
				return true
	return false

var x: int = 0
var y: int = 0
var terrain: Terrain = Terrain.PLAINS
var knowledge: Knowledge = Knowledge.UNKNOWN
var castle: Castle = null
var active_expedition: Expedition = null   # null when no expedition is targeting this tile


func _init(p_x: int = 0, p_y: int = 0, p_terrain: Terrain = Terrain.PLAINS) -> void:
	x = p_x
	y = p_y
	terrain = p_terrain


# Legacy single-resource gather. Kept for back-compat with anything that
# still does the "what's this tile worth?" check on a single key; the
# new path is `gather_table_id()` → RewardTableDB.roll(...).
# "" when the tile has no gather yield (Town, Village, Ocean).
func gather_resource() -> String:
	match terrain:
		Terrain.FOREST: return "logs"
		Terrain.PLAINS, Terrain.BEACH: return "plant_fibres"
		Terrain.MOUNTAIN: return "copper_ore"
		Terrain.HILLS: return "iron_ore"
		_: return ""


# RewardTableDB id for this terrain — drives the regional gather. The target
# tile's table rolls at full weight; each Chebyshev-1 neighbour's table rolls
# at a reduced weight (set by Tick._complete_one). Town / Village / Ocean
# return "" so they contribute nothing.
func gather_table_id() -> String:
	match terrain:
		Terrain.FOREST:   return "gather_forest"
		Terrain.MOUNTAIN: return "gather_mountain"
		Terrain.HILLS:    return "gather_hills"
		Terrain.PLAINS:   return "gather_plains"
		Terrain.BEACH:    return "gather_beach"
		_: return ""


# "Passable" — whether an expedition (Explore or Gather) can target this tile.
# Per Jack's 2026-05-28 call, Mountain is now passable (the tile itself holds
# the resources — the old "gather from adjacent mountain" rule is scrapped in
# favour of regional gather). Ocean stays non-passable.
func is_passable() -> bool:
	return terrain != Terrain.OCEAN


# Single-char label for ASCII debug dumps. Castle overlay is applied by the
# caller (the dev dump scene) because it's a render concern, not state.
func terrain_code() -> String:
	match terrain:
		Terrain.TOWN: return "@"
		Terrain.VILLAGE: return "V"
		Terrain.PLAINS: return "."
		Terrain.FOREST: return "F"
		Terrain.HILLS: return "h"
		Terrain.MOUNTAIN: return "M"
		Terrain.BEACH: return "b"
		Terrain.OCEAN: return "~"
	return "?"
