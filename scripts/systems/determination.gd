class_name Determination
extends RefCounted

# GDD §10 "Determination": every 4th week, each at-home unit rolls a
# (Determination × 0.5)% chance for a free +1 on a random non-maxed visible
# stat (PA cap honoured). Units on expedition are skipped entirely.
#
# Phase 5's Tick wires this; Phase 3 just defines the helper.

const TRIGGER_INTERVAL: int = 4
# Percentage chance per point of Determination. Used by roll_for_units() and
# also referenced by Tick._apply_training() for the per-training bonus roll.
# Single source of truth — change here to retune both roll sites.
const CHANCE_PER_POINT: float = 0.5


static func should_trigger(week: int) -> bool:
	return week > 0 and week % TRIGGER_INTERVAL == 0


# Returns an array of {unit: Unit, stat: String, leveled: int} dicts, one per
# successful roll. `leveled` is the points actually ticked (often 0 now that
# the gain is staged). Empty array if nobody got lucky.
static func roll_for_units(units: Array[Unit]) -> Array:
	var results: Array = []
	for u in units:
		if u.is_on_expedition():
			continue
		var chance_pct: float = float(u.stats.determination) * CHANCE_PER_POINT
		var roll: float = RNG.randf_range(0.0, 100.0)
		if roll < chance_pct:
			# Staged: the lucky roll feeds development into a random stat rather
			# than instantly popping +1 (it may or may not tick a point yet).
			var dev: Dictionary = u.stats.add_progress_random_excluding(1.0, u.potential_ability, "", BodyType.cap_bumps(u.body_type))
			if str(dev["stat"]) != "":
				results.append({"unit": u, "stat": dev["stat"], "leveled": int(dev["leveled"])})
	return results
