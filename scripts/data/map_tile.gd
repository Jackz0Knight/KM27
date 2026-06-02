class_name MapTile
extends Resource

# One cell of the 15×15 world grid per GDD §4. Terrain → gather resource is a
# function (see `gather_resource()`), so we only store terrain and derive
# resource on demand — no duplication / drift.

enum Terrain { TOWN, VILLAGE, PLAINS, FOREST, HILLS, MOUNTAIN, BEACH, OCEAN }
enum Knowledge { UNKNOWN, EXPLORED, EXPEDITION_ACTIVE }
# Gather-yield band per GDD §18.2. Rolled deterministically at world-gen (so
# it round-trips through the seed without an extra save field), surfaced on
# the tile tooltip only after the tile is EXPLORED — gives scout expeditions
# a real prize beyond "knowledge of existence".
enum Richness { POOR, AVERAGE, RICH }


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
var richness: Richness = Richness.AVERAGE   # default Average; world-gen rolls it
var castle: Castle = null
var active_expedition: Expedition = null   # null when no expedition is targeting this tile


func _init(p_x: int = 0, p_y: int = 0, p_terrain: Terrain = Terrain.PLAINS) -> void:
	x = p_x
	y = p_y
	terrain = p_terrain


# Display label for the richness band — feeds the tile tooltip on EXPLORED
# tiles. Returns "" for tiles that don't yield anything to gather (Town,
# Village, Ocean), so the tooltip omits the line entirely.
func richness_label() -> String:
	if gather_resource() == "":
		return ""
	match richness:
		Richness.POOR: return "Poor"
		Richness.AVERAGE: return "Average"
		Richness.RICH: return "Rich"
	return ""


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
