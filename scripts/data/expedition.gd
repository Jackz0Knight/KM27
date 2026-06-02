class_name Expedition
extends Resource

# An away mission per GDD §8. Removes its `unit_ids` from the home pool until
# `weeks_remaining` ticks down to 0 in Phase 5's Tick.
#
# Cannot be recalled (GDD §8 "Cannot be recalled. Once launched, the
# expedition runs to completion.").

enum Kind { EXPLORE, GATHER }

const DURATION: Dictionary = {
	Kind.EXPLORE: 2,
	Kind.GATHER: 3,
}

# Per-resource weekly base yield per GDD §18.2. The total yield over a gather
# expedition is `base × richness_mult × (1 + Σstrength / STRENGTH_DIVISOR) ×
# DURATION[GATHER]` — see `estimate_yield()`. Resources not in this dict yield
# nothing from gather (T2+ comes from assault / story-event rewards).
const BASE_YIELDS_PER_WEEK: Dictionary = {
	"logs":         3,
	"plant_fibres": 4,
	"copper_ore":   2,
	"iron_ore":     2,
}

const RICHNESS_MULT: Dictionary = {
	MapTile.Richness.POOR:    0.5,
	MapTile.Richness.AVERAGE: 1.0,
	MapTile.Richness.RICH:    1.5,
}

const STRENGTH_DIVISOR: float = 20.0   # each Strength point = +5% weekly yield

# Legacy constant kept so older save / dev paths that reference it don't
# break; the new formula in `estimate_yield()` doesn't read it.
const GATHER_BASE_YIELD: int = 4

var id: int = 0
var kind: Kind = Kind.EXPLORE
var target_x: int = 0
var target_y: int = 0
var weeks_remaining: int = 0
var unit_ids: Array[int] = []


func _init(
	p_id: int = 0,
	p_kind: Kind = Kind.EXPLORE,
	p_x: int = 0,
	p_y: int = 0,
	p_units: Array[int] = [],
) -> void:
	id = p_id
	kind = p_kind
	target_x = p_x
	target_y = p_y
	weeks_remaining = DURATION[p_kind]
	unit_ids = p_units.duplicate()


# GDD §18.2 gather formula. Per-week yield scales with the resource's base
# value, the tile's richness band, and the party's combined Strength, then
# multiplies by the gather duration. Returns 0 for tiles that don't yield
# anything (or unknown resources).
static func estimate_yield(tile: MapTile, party_strength: int) -> int:
	if tile == null:
		return 0
	var res_key: String = tile.gather_resource()
	if res_key == "":
		return 0
	var base: int = int(BASE_YIELDS_PER_WEEK.get(res_key, 0))
	if base <= 0:
		return 0
	var richness_mult: float = float(RICHNESS_MULT.get(tile.richness, 1.0))
	var strength_mult: float = 1.0 + float(party_strength) / STRENGTH_DIVISOR
	var weekly: float = float(base) * richness_mult * strength_mult
	return roundi(weekly * float(DURATION[Kind.GATHER]))


func kind_label() -> String:
	match kind:
		Kind.EXPLORE: return "Explore"
		Kind.GATHER: return "Gather"
	return "?"


func describe() -> String:
	return "%s @ (%d,%d) — %dw left, %d unit(s)" % [
		kind_label(), target_x, target_y, weeks_remaining, unit_ids.size(),
	]
