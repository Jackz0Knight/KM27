class_name MapTile
extends Resource

# One cell of the 15×15 world grid per GDD §4. Terrain → gather resource is a
# function (see `gather_resource()`), so we only store terrain and derive
# resource on demand — no duplication / drift.

enum Terrain { TOWN, VILLAGE, PLAINS, FOREST, HILLS, MOUNTAIN, BEACH, OCEAN }
enum Knowledge { UNKNOWN, EXPLORED, EXPEDITION_ACTIVE }

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


# "" when the tile has no gather yield (Town, Village, Hills, Ocean).
func gather_resource() -> String:
	match terrain:
		Terrain.FOREST: return "logs"
		Terrain.PLAINS, Terrain.BEACH: return "plant_fibres"
		Terrain.MOUNTAIN: return "copper_ore"
		Terrain.HILLS: return "iron_ore"
		_: return ""


# "Passable" per GDD §4: affects whether an expedition can target this tile
# directly. Mountain & Ocean are non-passable; Mountain's Copper Ore is gathered
# from an adjacent passable tile (Phase 5 will enforce that rule).
func is_passable() -> bool:
	return terrain != Terrain.MOUNTAIN and terrain != Terrain.OCEAN


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
