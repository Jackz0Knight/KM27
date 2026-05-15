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
	}
	_apply_training(gs, results)
	_apply_expedition_returns(gs, results)
	if Determination.should_trigger(gs.week):
		results["determination"] = Determination.roll_for_units(gs.roster)
	_apply_gold_maintenance(gs, results)
	gs.last_tick_results = results
	return results


static func _apply_gold_maintenance(gs: Node, results: Dictionary) -> void:
	var cost: int = gs.gold_maintenance_cost()
	results["gold_deducted"] = cost
	if gs.gold >= cost:
		gs.gold -= cost
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
		var applied: bool = u.stats.try_increment(stat, u.potential_ability)
		var entry: Dictionary = {
			"unit_id": u.id,
			"stat": stat,
			"applied": applied,
			"before": before,
			"after": u.stats.get_value(stat),
			"bonus_stat": "",
		}
		# GDD §7 training-bonus roll. Independent of the every-4-weeks
		# Determination roll in GDD §10 (that's handled by Determination.gd).
		var chance_pct: float = float(u.stats.determination) * 0.5
		if RNG.randf_range(0.0, 100.0) < chance_pct:
			var bonus: String = u.stats.try_increment_random_excluding(u.potential_ability, stat)
			if bonus != "":
				entry["bonus_stat"] = bonus
		results["training"].append(entry)


# Decrement every active expedition. Any that hit 0 deliver their effects:
#   Explore → flip tile to Explored, surface castle if present.
#   Gather  → roll yield = base × (1 + Σstrength / 30), add to stores.
# Returning units drop back into the at-home pool via complete_expedition().
static func _apply_expedition_returns(gs: Node, results: Dictionary) -> void:
	var to_complete: Array = []
	for exp in gs.expeditions:
		exp.weeks_remaining -= 1
		if exp.weeks_remaining <= 0:
			to_complete.append(exp)
	for exp in to_complete:
		results["expedition_returns"].append(_complete_one(gs, exp))


static func _complete_one(gs: Node, exp: Expedition) -> Dictionary:
	var tile: MapTile = gs.world.get_tile(exp.target_x, exp.target_y)
	var info: Dictionary = {
		"expedition_id": exp.id,
		"kind": exp.kind,
		"kind_label": exp.kind_label(),
		"target_x": exp.target_x,
		"target_y": exp.target_y,
		"unit_ids": exp.unit_ids.duplicate(),
		"yield_resource": "",
		"yield_amount": 0,
		"yield_bundle": null,
		"revealed_terrain": "",
		"revealed_castle": null,
	}

	if exp.kind == Expedition.Kind.EXPLORE:
		if tile != null and tile.knowledge != MapTile.Knowledge.EXPLORED:
			tile.knowledge = MapTile.Knowledge.EXPLORED
			info["revealed_terrain"] = MapTile.Terrain.keys()[tile.terrain]
			if tile.castle != null:
				info["revealed_castle"] = tile.castle
	elif exp.kind == Expedition.Kind.GATHER:
		if tile != null:
			var res_key: String = tile.gather_resource()
			if res_key != "":
				var party_strength: int = 0
				for uid in exp.unit_ids:
					var u: Unit = gs.find_unit(uid)
					if u != null:
						party_strength += u.stats.strength
				var amount: int = roundi(
					float(Expedition.GATHER_BASE_YIELD) * (1.0 + float(party_strength) / 30.0)
				)
				var bundle := ResourceBundle.new()
				bundle.set(res_key, amount)
				gs.resources.add(bundle)
				info["yield_resource"] = res_key
				info["yield_amount"] = amount
				info["yield_bundle"] = bundle

	gs.complete_expedition(exp)
	EventBus.expedition_returned.emit(exp)
	return info
