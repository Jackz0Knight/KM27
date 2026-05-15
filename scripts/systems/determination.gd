class_name Determination
extends RefCounted

# GDD §10 "Determination": every 4th week, each at-home unit rolls a
# (Determination × 0.5)% chance for a free +1 on a random non-maxed visible
# stat (PA cap honoured). Units on expedition are skipped entirely.
#
# Phase 5's Tick wires this; Phase 3 just defines the helper.

const TRIGGER_INTERVAL: int = 4


static func should_trigger(week: int) -> bool:
	return week > 0 and week % TRIGGER_INTERVAL == 0


# Returns an array of {unit: Unit, stat: String} dicts, one per successful roll.
# Empty array if nobody got lucky.
static func roll_for_units(units: Array[Unit]) -> Array:
	var results: Array = []
	for u in units:
		if u.is_on_expedition():
			continue
		var chance_pct: float = float(u.stats.determination) * 0.5
		var roll: float = RNG.randf_range(0.0, 100.0)
		if roll < chance_pct:
			var stat_picked: String = u.stats.try_increment_random(u.potential_ability)
			if stat_picked != "":
				results.append({"unit": u, "stat": stat_picked})
	return results
