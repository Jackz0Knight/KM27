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

# Phase 5 yield formula: yield = base × (1 + Σstrength / 30). Base values are
# placeholders per GDD §8 ("MVP baseline, tune from play").
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


static func estimate_yield(party_strength: int) -> int:
	return roundi(float(GATHER_BASE_YIELD) * (1.0 + float(party_strength) / 30.0))


func kind_label() -> String:
	match kind:
		Kind.EXPLORE: return "Explore"
		Kind.GATHER: return "Gather"
	return "?"


func describe() -> String:
	return "%s @ (%d,%d) — %dw left, %d unit(s)" % [
		kind_label(), target_x, target_y, weeks_remaining, unit_ids.size(),
	]
