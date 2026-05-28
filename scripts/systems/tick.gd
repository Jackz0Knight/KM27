class_name Tick
extends RefCounted

# Phase 5 Tick application per GDD §5. Walks the per-unit at-home tasks
# (training), advances expedition timers, drops returning expeditions, and on
# every 4th week runs the Determination roll. Returns a result Dictionary the
# Pre-Battle Review and Weekly Summary screens render.
#
# Tick is stateless — `apply(gs)` reads roster / expeditions / world off the
# passed-in GameState and mutates them in place. Combat math lives in
# scripts/systems/combat.gd; Tick is purely "what changes during the week".

# Regional-gather neighbour weight (per Jack's 2026-05-28 design call). A
# Gather expedition rolls its target tile's RewardTableDB at full weight and
# each Chebyshev-1 neighbour with a gather table at this reduced weight, so
# placement on the map matters but the chosen tile still dominates the yield.
const GATHER_NEIGHBOUR_WEIGHT: float = 0.3

# Result shape:
#   {
#     "training": [{unit_id, stat, applied, before, after}],
#     "determination": [{unit_id, stat}],
#     "expedition_returns": [{
#       expedition_id, kind, kind_label, target_x, target_y, unit_ids,
#       yield_resource, yield_amount, yield_bundle (or null),
#       revealed_terrain, revealed_castle (or null),
#     }],
#   }


static func apply(gs: Node) -> Dictionary:
	var results: Dictionary = {
		"training": [],
		"determination": [],
		"expedition_returns": [],
		"gold_deducted": 0,
		"maintenance_debt": false,
		"gold_income": 0,
		"injury_recoveries": [],
	}
	for u in gs.roster:
		u.stats.decay_development()
	_apply_injury_tick(gs, results)
	_apply_training(gs, results)
	_apply_expedition_returns(gs, results)
	if Determination.should_trigger(gs.week):
		results["determination"] = Determination.roll_for_units(gs.roster)
	_apply_gold_income(gs, results)
	_apply_gold_maintenance(gs, results)
	gs.last_tick_results = results
	return results


static func _apply_gold_income(gs: Node, results: Dictionary) -> void:
	var income: int = gs.total_gold_income()
	gs.gold += income
	results["gold_income"] = income


static func _apply_injury_tick(gs: Node, results: Dictionary) -> void:
	for u in gs.roster:
		var healed: Array[String] = []
		var still_injured: Array = []
		for inj in u.injuries:
			inj["weeks_remaining"] -= 1
			if inj["weeks_remaining"] <= 0:
				healed.append(inj["stat"])
			else:
				still_injured.append(inj)
		u.injuries = still_injured
		for stat in healed:
			results["injury_recoveries"].append({"unit_id": u.id, "stat": stat})


static func _apply_gold_maintenance(gs: Node, results: Dictionary) -> void:
	var cost: int = gs.gold_maintenance_cost()
	results["gold_deducted"] = cost
	if gs.gold >= cost:
		gs.gold -= cost
		# Per-week truth: cleared when funds covered upkeep so chronicle prose
		# and any future debt-aware system only read the flag on weeks where
		# the household actually fell short. Previously sticky — once set
		# true on any week it stayed true for the rest of the run, so
		# `Chronicle._event_line` kept appending "The ledger fell short this
		# week" indefinitely after the first short week.
		gs.maintenance_debt = false
	else:
		results["maintenance_debt"] = true
		gs.maintenance_debt = true
		gs.gold = 0


# Training: +1 to the target stat for every at-home unit on "train:<stat>",
# plus the per-training Determination-rolled chance of a bonus +1 to a random
# OTHER stat (GDD §7). Both rolls share the (Det × 0.5)% chance formula.
# Records both pass and fail (PA-capped / stat-capped) so the Weekly Summary
# can explain why a training session yielded nothing.
static func _apply_training(gs: Node, results: Dictionary) -> void:
	for u in gs.roster:
		if not u.is_at_home():
			continue
		if not u.is_training():
			continue
		var stat: String = u.training_target()
		var before: int = u.stats.get_value(stat)
		var body_bumps: Dictionary = BodyType.cap_bumps(u.body_type)
		# Staged: a drill feeds hidden progress rather than always popping +1.
		# The point only ticks when enough accumulates (GDD §10, FM-style).
		var dev: Dictionary = u.stats.add_progress(stat, 1.0, u.potential_ability, int(body_bumps.get(stat, 0)))
		var after: int = u.stats.get_value(stat)
		var leveled: int = int(dev["leveled"])
		var ceiling: int = Stats.STAT_CAP + int(body_bumps.get(stat, 0))
		var entry: Dictionary = {
			"unit_id": u.id,
			"stat": stat,
			"leveled": leveled,
			"applied": leveled > 0,  # back-compat alias for older readers
			"developing": leveled == 0 and after < ceiling and (u.potential_ability - u.stats.sum()) > 0,
			"before": before,
			"after": after,
			"bonus_stat": "",
			"bonus_leveled": false,
		}
		# GDD §7 training-bonus roll. Independent of the every-4-weeks
		# Determination roll in GDD §10 (that's handled by Determination.gd).
		var chance_pct: float = float(u.stats.determination) * Determination.CHANCE_PER_POINT
		if RNG.randf_range(0.0, 100.0) < chance_pct:
			var bonus: Dictionary = u.stats.add_progress_random_excluding(1.0, u.potential_ability, stat, body_bumps)
			if str(bonus["stat"]) != "":
				entry["bonus_stat"] = bonus["stat"]
				entry["bonus_leveled"] = int(bonus["leveled"]) > 0
		results["training"].append(entry)


# Decrement every active expedition. Any that hit 0 deliver their effects:
#   Explore → flip tile to Explored, surface castle if present.
#   Gather  → roll yield = base × (1 + Σstrength / 30), add to stores.
# Returning units drop back into the at-home pool via complete_expedition().
static func _apply_expedition_returns(gs: Node, results: Dictionary) -> void:
	var to_complete: Array = []
	for exped in gs.expeditions:
		exped.weeks_remaining -= 1
		if exped.weeks_remaining <= 0:
			to_complete.append(exped)
	for exped in to_complete:
		results["expedition_returns"].append(_complete_one(gs, exped))


static func _complete_one(gs: Node, exped: Expedition) -> Dictionary:
	var tile: MapTile = gs.world.get_tile(exped.target_x, exped.target_y)
	var info: Dictionary = {
		"expedition_id": exped.id,
		"kind": exped.kind,
		"kind_label": exped.kind_label(),
		"target_x": exped.target_x,
		"target_y": exped.target_y,
		"unit_ids": exped.unit_ids.duplicate(),
		"yield_resource": "",
		"yield_amount": 0,
		"yield_bundle": null,
		"revealed_terrain": "",
		"revealed_castle": null,
	}

	if exped.kind == Expedition.Kind.EXPLORE:
		if tile != null and tile.knowledge != MapTile.Knowledge.EXPLORED:
			tile.knowledge = MapTile.Knowledge.EXPLORED
			info["revealed_terrain"] = MapTile.Terrain.keys()[tile.terrain]
			if tile.castle != null:
				info["revealed_castle"] = tile.castle
	elif exped.kind == Expedition.Kind.GATHER:
		if tile != null:
			# Regional gather (Jack's 2026-05-28 call): the expedition rolls
			# loot from the target tile's RewardTableDB at full weight, plus
			# each Chebyshev-1 neighbour with a table at a reduced weight, so
			# placement on the map matters. A forest tile next to two
			# mountains pulls logs + a little ore; a remote plains tile pulls
			# only plains. Strength still scales the final dict via
			# Expedition.estimate_yield so a strong party brings home more.
			var weighted: Array = []
			var primary: String = tile.gather_table_id()
			if primary != "":
				weighted.append({"table": primary, "weight": 1.0})
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if dx == 0 and dy == 0:
						continue
					var n: MapTile = gs.world.get_tile(exped.target_x + dx, exped.target_y + dy)
					if n == null:
						continue
					var ntable: String = n.gather_table_id()
					if ntable == "":
						continue
					weighted.append({"table": ntable, "weight": GATHER_NEIGHBOUR_WEIGHT})
			if not weighted.is_empty():
				var bundle: Dictionary = RewardTableDB.roll_blended(weighted, gs.week, 1.0)
				# Apply Strength scaling. estimate_yield(party_strength) returns
				# a small integer multiplier-ish proxy; using it as a scalar so
				# a 1-Strength party doesn't multiply through to zero, we clamp
				# the multiplier at a minimum of 1.0.
				var party_strength: int = 0
				for uid in exped.unit_ids:
					var u: Unit = gs.find_unit(uid)
					if u != null:
						party_strength += u.stats.strength
				var strength_mult: float = maxf(1.0, 1.0 + float(party_strength) / 30.0)
				var final_bundle: Dictionary = ResourceDB.scale(bundle, strength_mult)
				ResourceDB.merge(gs.inventory, final_bundle)
				info["yield_bundle"] = final_bundle
				# Back-compat info fields — pre_battle_review / weekly_summary
				# still surface a single-resource summary; pick the largest
				# line for that one-glance readout.
				var top_id: String = ""
				var top_amount: int = 0
				for id: String in final_bundle:
					var v: int = int(final_bundle[id])
					if v > top_amount:
						top_amount = v
						top_id = id
				info["yield_resource"] = top_id
				info["yield_amount"] = top_amount

	gs.complete_expedition(exped)
	EventBus.expedition_returned.emit(exped)
	return info
