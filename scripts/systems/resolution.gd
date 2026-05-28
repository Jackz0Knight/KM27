class_name Resolution
extends RefCounted

# Phase 6/7 Resolution coordinator. Given the current GameState (event,
# sub-event, formation, away party, tournament participants, champion pick),
# runs the right Combat / BattleEvent helper, applies rewards, and writes
# the outcome to GameState.last_battle_result.
#
# Resolution does NOT mutate week / phase machine — those are managed by the
# UI flow (Weekly Summary's Next Week button calls GameState.wrap_week()).
#
# Result keys (see header comments for shape):
#   "event_kind", "event_label", "sub_event", "fought", "won",
#   "player_total", "enemy_total", "enemy_pre_intim",
#   "intimidation_reduction", "per_unit", "tournament_per_unit",
#   "reward", "castle_taken", "duel_unit_id", "duel_stat",
#   "duel_stat_applied", "harvest_bundle",
#   "is_game_over", "is_run_win", "notes" (Array[String])


static func run(gs: Node) -> Dictionary:
	var result: Dictionary = _blank_result(gs)

	match gs.current_event:
		EventKind.AWAY_BATTLE:
			_resolve_away(gs, result)
		EventKind.HOME_BATTLE:
			_resolve_home(gs, result)
		EventKind.BATTLE_EVENT:
			_resolve_battle_event(gs, result)
		EventKind.TOURNAMENT:
			_resolve_tournament(gs, result, false)
		EventKind.GRAND_TOURNAMENT:
			_resolve_tournament(gs, result, true)
		_:
			result["notes"].append("No event rolled — nothing to resolve.")

	# Don't apply rewards when the run is already over — the game_over screen
	# takes over from here and the inventory state is irrelevant.
	if not result.get("is_game_over", false):
		_apply_reward(gs, result)
		# Per-unit oath honour checks. Runs after the result is fully
		# populated so every signal (combat per_unit, injuries, tournament
		# participation) is observable. Skipped on game-over for the same
		# reason rewards are skipped — the run's done.
		OathLedger.check_roster(gs, result)
	gs.last_battle_result = result
	EventBus.battle_resolved.emit(result)
	return result


static func _blank_result(gs: Node) -> Dictionary:
	return {
		"event_kind": gs.current_event,
		"event_label": EventKind.label(gs.current_event),
		"sub_event": gs.current_battle_event,
		"fought": false,
		"won": false,
		"player_total": 0,
		"enemy_total": 0,
		"enemy_pre_intim": 0,
		"intimidation_reduction": 0,
		"per_unit": [],
		"tournament_per_unit": [],
		"reward": null,
		"castle_taken": null,
		"duel_unit_id": -1,
		"duel_stat": "",
		"duel_stat_applied": false,
		"duel_player_power": 0,
		"duel_enemy_power": 0,
		"harvest_bundle": null,
		"is_game_over": false,
		"is_run_win": false,
		"notes": [],
		"injuries": [],
		"tournament_gold": 0,
		# Item loot rolled by ItemDrops on win paths. Dict (slot/id) or {}.
		"item_drop": {},
	}


# ---------- Away Battle ----------

static func _resolve_away(gs: Node, result: Dictionary) -> void:
	var party: Array[Unit] = _away_party(gs)
	if gs.pending_away_mode == "":
		result["notes"].append("No away action chosen — skipped.")
		return
	if party.is_empty():
		result["notes"].append("No party committed — Away Battle skipped.")
		return

	# Data-driven away mission variants. Falls through to the original
	# pillage/assault path for "pillage" / "assault" / any unknown string.
	if AwayModeDB.has_mode(gs.pending_away_mode):
		_resolve_away_custom(gs, party, result)
		return

	if gs.pending_away_mode == "assault":
		if gs.pending_assault_castle == null:
			result["notes"].append("Assault chosen but no castle selected — skipped.")
			return
		result["notes"].append("Assaulting castle (%d,%d) diff %d." % [
			gs.pending_assault_castle.x, gs.pending_assault_castle.y,
			gs.pending_assault_castle.difficulty,
		])
	else:
		result["notes"].append("Pillage Camp.")

	var player_cus: Array = _player_cus(party)
	var enemy_cus: Array  = EnemyDB.roll_combat_party("pillage", gs.week)
	var sim: Dictionary   = CombatSim.run(player_cus, enemy_cus)
	_fill_from_sim(result, sim, enemy_cus)

	var bracket: int = _bracket_from_sim(sim, player_cus)
	var injuries: Array[Dictionary] = OutcomeBracket.maybe_apply_injuries(party, bracket)
	if not injuries.is_empty():
		result["injuries"] = injuries
		for inj in injuries:
			result["notes"].append("%s injured: %s (%dw)" % [
				gs.find_unit(inj["unit_id"]).unit_name if gs.find_unit(inj["unit_id"]) != null else "?",
				inj["stat"].capitalize(), inj["weeks_remaining"],
			])

	if result["won"]:
		if gs.pending_away_mode == "assault":
			var castle: Castle = gs.pending_assault_castle
			result["reward"] = castle.reward.duplicate(true)
			result["castle_taken"] = castle
			_remove_castle(gs, castle)
			# Castle-takers earn realm attention.
			_log_reputation_crossing(result, gs.adjust_reputation(4))
		else:
			result["reward"] = Combat.roll_pillage_reward(gs.week)
			# Pillaging the marches earns coin but not standing — only a
			# small +1 because the chronicler is supposed to call it
			# something more dignified.
			_log_reputation_crossing(result, gs.adjust_reputation(1))
		var tag: String = Chronicle.TAG_ASSAULT_WIN if gs.pending_away_mode == "assault" else Chronicle.TAG_PILLAGE_WIN
		for u in party:
			var old_ep: String = u.epithet
			Chronicle.grant_epithet(u, tag)
			if u.epithet != "" and old_ep == "":
				result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])
		_apply_item_drop(result, ItemDrops.roll_away_drop(gs, gs.pending_away_mode))
	else:
		result["notes"].append("Battle lost — no reward.")
		# Losing on the field shows. Not catastrophic, but noticeable.
		_log_reputation_crossing(result, gs.adjust_reputation(-1))


# Resolve a data-driven away mode (anything in AwayModeDB.MODES). Mirrors
# the pillage path's structure — combat sim → injuries → reward + epithet
# + item drop + rep — but reads its parameters from the mode entry instead
# of branching on hard-coded "pillage" vs "assault" strings. The reward
# kinds (gold_and_bundle / iron_haul / rare_loot) are dispatched here so
# adding a new mode is purely a data add.
static func _resolve_away_custom(gs: Node, party: Array[Unit], result: Dictionary) -> void:
	var mode: Dictionary = AwayModeDB.MODES.get(gs.pending_away_mode, {})
	if mode.is_empty():
		result["notes"].append("Unknown away mode: %s" % gs.pending_away_mode)
		return

	result["notes"].append("%s" % str(mode.get("label", "Away Mission")))

	var template: String = str(mode.get("combat_template", "pillage"))
	var player_cus: Array = _player_cus(party)
	var enemy_cus: Array  = EnemyDB.roll_combat_party(template, gs.week)
	var sim: Dictionary   = CombatSim.run(player_cus, enemy_cus)
	_fill_from_sim(result, sim, enemy_cus)

	var bracket: int = _bracket_from_sim(sim, player_cus)
	var injuries: Array[Dictionary] = OutcomeBracket.maybe_apply_injuries(party, bracket)
	if not injuries.is_empty():
		result["injuries"] = injuries
		for inj in injuries:
			result["notes"].append("%s injured: %s (%dw)" % [
				gs.find_unit(inj["unit_id"]).unit_name if gs.find_unit(inj["unit_id"]) != null else "?",
				inj["stat"].capitalize(), inj["weeks_remaining"],
			])

	if result["won"]:
		_apply_away_custom_reward(gs, mode, result)
		var tag: String = str(mode.get("epithet_tag", "pillage_win"))
		for u in party:
			var old_ep: String = u.epithet
			Chronicle.grant_epithet(u, tag)
			if u.epithet != "" and old_ep == "":
				result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])
		# Item drop — modes can override the standard chance via a roll
		# against item_drop_chance, biased toward the listed rarity.
		_apply_custom_item_drop(gs, mode, result)
		var rep_win: int = int(mode.get("rep_on_win", 0))
		if rep_win != 0:
			_log_reputation_crossing(result, gs.adjust_reputation(rep_win))
	else:
		result["notes"].append("Mission failed — no reward.")
		var rep_loss: int = int(mode.get("rep_on_loss", 0))
		if rep_loss != 0:
			_log_reputation_crossing(result, gs.adjust_reputation(rep_loss))


# Apply the reward shape declared on the mode entry. Three kinds today:
#   gold_and_bundle — gold_range + a Dictionary {logs, plant_fibres, copper_ore}
#                     roll using the mode entry's bundle_lo/bundle_hi range
#   iron_haul       — iron_ore inventory_add + plant_fibres inventory_add
#                     + optional small gold tip
#   rare_loot       — small gold + a forced item drop (handled at the
#                     drop step; here we just push the gold note)
static func _apply_away_custom_reward(gs: Node, mode: Dictionary, result: Dictionary) -> void:
	var kind: String = str(mode.get("reward_kind", "gold_and_bundle"))
	match kind:
		"gold_and_bundle":
			var purse: int = RNG.randi_range(int(mode.get("gold_min", 0)), int(mode.get("gold_max", 0)))
			if purse > 0:
				gs.gold += purse
				result["notes"].append("+%d gold" % purse)
			var lo: int = int(mode.get("bundle_lo", 1))
			var hi: int = int(mode.get("bundle_hi", 2))
			if hi >= lo and hi > 0:
				result["reward"] = {
					"logs":         RNG.randi_range(lo, hi),
					"plant_fibres": RNG.randi_range(lo, hi),
					"copper_ore":   RNG.randi_range(lo, hi),
				}
		"iron_haul":
			var iron: int = RNG.randi_range(int(mode.get("iron_min", 0)), int(mode.get("iron_max", 0)))
			if iron > 0:
				gs.inventory["iron_ore"] = int(gs.inventory.get("iron_ore", 0)) + iron
				result["notes"].append("+%d Iron Ore" % iron)
			var fibres: int = RNG.randi_range(int(mode.get("fibres_min", 0)), int(mode.get("fibres_max", 0)))
			if fibres > 0:
				gs.inventory["plant_fibres"] = int(gs.inventory.get("plant_fibres", 0)) + fibres
				result["notes"].append("+%d Plant Fibres" % fibres)
			var tip: int = RNG.randi_range(int(mode.get("gold_min", 0)), int(mode.get("gold_max", 0)))
			if tip > 0:
				gs.gold += tip
				result["notes"].append("+%d gold" % tip)
		"rare_loot":
			var purse2: int = RNG.randi_range(int(mode.get("gold_min", 0)), int(mode.get("gold_max", 0)))
			if purse2 > 0:
				gs.gold += purse2
				result["notes"].append("+%d gold" % purse2)
		_:
			result["notes"].append("(unhandled reward kind: %s)" % kind)


# Roll the mode's declared item drop chance. Uses the same ItemDrops machinery
# the standard pillage/assault path uses, but biased to the mode's preferred
# rarity ceiling.
static func _apply_custom_item_drop(gs: Node, mode: Dictionary, result: Dictionary) -> void:
	var chance: float = float(mode.get("item_drop_chance", 0.0))
	if chance <= 0.0:
		return
	if RNG.randf_range(0.0, 1.0) >= chance:
		return
	# Build a small rarity pool centred on the mode's listed rarity.
	# Rarity 0=Common 1=Uncommon 2=Rare 3=Heirloom. We let nearby rarities
	# leak in at lower weight so the drops feel varied without ever rolling
	# Heirloom outside the Grand Tournament path.
	var target_rarity: int = int(mode.get("item_drop_rarity", 1))
	var pool: Array[int] = []
	for r in range(max(0, target_rarity - 1), min(3, target_rarity + 1) + 1):
		var weight: int = 4 if r == target_rarity else 1
		# Cap at Rare on this path; Heirlooms remain Grand-Tournament-only.
		if r >= 3:
			continue
		for _i in range(weight):
			pool.append(r)
	if pool.is_empty():
		return
	var rolled: int = pool[RNG.randi_range(0, pool.size() - 1)]
	var drop: Dictionary = ItemDrops.drop_at_rarity(gs, rolled)
	_apply_item_drop(result, drop)


# ---------- Home Battle ----------

static func _resolve_home(gs: Node, result: Dictionary) -> void:
	var party: Array[Unit] = gs.at_home_units()
	result["notes"].append("Defending homestead.")

	if party.is_empty():
		result["fought"] = true
		result["won"] = false
		result["notes"].append("No defenders at home — homestead breached.")
		result["is_game_over"] = true
		return

	# Apply the home-battle 0.75× penalty to non-Defend units.
	var player_cus: Array = _player_cus_home(party)
	var enemy_cus: Array  = EnemyDB.roll_combat_party("home_battle", gs.week)
	var sim: Dictionary   = CombatSim.run(player_cus, enemy_cus)
	_fill_from_sim(result, sim, enemy_cus)

	var bracket: int = _bracket_from_sim(sim, player_cus)
	var injuries: Array[Dictionary] = OutcomeBracket.maybe_apply_injuries(party, bracket)
	if not injuries.is_empty():
		result["injuries"] = injuries

	if result["won"]:
		result["reward"] = Combat.roll_home_win_reward(gs.week)
		# Holding the gate against a raid is the kind of news that travels.
		_log_reputation_crossing(result, gs.adjust_reputation(3))
		# Survival epithets first — they're the more dramatic story when the
		# defence was a close-margin win, and grant_epithet skips units who
		# already have one. WON tag fills the gaps for units who weren't
		# eligible for survival (i.e., were injured or it wasn't a close win).
		_maybe_grant_survival_epithets(party, bracket, injuries, result)
		for u in party:
			var old_ep: String = u.epithet
			Chronicle.grant_epithet(u, Chronicle.TAG_HOME_BATTLE_WON)
			if u.epithet != "" and old_ep == "":
				result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])
		_apply_item_drop(result, ItemDrops.roll_home_defence_drop(gs))
	else:
		result["is_game_over"] = true
		result["notes"].append("Homestead breached — GAME OVER.")


# ---------- Battle Event ----------

static func _resolve_battle_event(gs: Node, result: Dictionary) -> void:
	# Story events take precedence — their sub_type starts with "story:" so
	# the match statement below would always miss them.
	if StoryEventDB.is_story_sub_type(gs.current_battle_event):
		StoryEventDB.resolve(gs, StoryEventDB.story_id_from_sub_type(gs.current_battle_event), result)
		return
	# Data-driven combat events route through CombatEventDB. The three
	# legacy combat resolvers (bandit_ambush / village_raid / tavern_riot)
	# keep their hard-coded paths below — migration to data is a future
	# follow-up once the framework has shipped a few more entries.
	if CombatEventDB.has_mode(gs.current_battle_event):
		_resolve_combat_event(gs, result)
		return
	match gs.current_battle_event:
		"bandit_ambush":
			_resolve_bandit_ambush(gs, result)
		"champion_duel":
			_resolve_champion_duel(gs, result)
		"bountiful_harvest":
			_resolve_bountiful_harvest(gs, result)
		"merchant_caravan":
			_resolve_merchant_caravan(gs, result)
		"refugee_caravan":
			_resolve_refugee_caravan(gs, result)
		"noble_petition":
			_resolve_noble_petition(gs, result)
		"village_raid":
			_resolve_village_raid(gs, result)
		"tavern_riot":
			_resolve_tavern_riot(gs, result)
		_:
			result["notes"].append("Unknown Battle Event sub-type.")


# Data-driven combat event resolver. Mirrors the legacy bandit_ambush /
# village_raid / tavern_riot path's structure (no-defender check →
# CombatSim → injuries → win-branch with reward + survival epithets +
# WON loop + item drop + rep, or loss-branch with rep penalty) but
# reads every parameter from `CombatEventDB.EVENTS[sub_type]`.
static func _resolve_combat_event(gs: Node, result: Dictionary) -> void:
	var mode: Dictionary = CombatEventDB.EVENTS.get(gs.current_battle_event, {})
	if mode.is_empty():
		result["notes"].append("Unknown combat event: %s" % gs.current_battle_event)
		return

	var party: Array[Unit] = gs.at_home_units()
	result["notes"].append(str(mode.get("intro_set", "")))

	if party.is_empty():
		result["fought"] = true
		result["won"] = false
		result["notes"].append(str(mode.get("intro_no_defender", "No defenders at home.")))
		var rep_nd: int = int(mode.get("rep_on_no_defender", 0))
		if rep_nd != 0:
			_log_reputation_crossing(result, gs.adjust_reputation(rep_nd))
		return

	var template: String = str(mode.get("combat_template", "bandit_ambush"))
	var player_cus: Array = _player_cus_home(party)
	var enemy_cus: Array  = EnemyDB.roll_combat_party(template, gs.week)
	var sim: Dictionary   = CombatSim.run(player_cus, enemy_cus)
	_fill_from_sim(result, sim, enemy_cus)

	var bracket: int = _bracket_from_sim(sim, player_cus)
	var injuries: Array[Dictionary] = OutcomeBracket.maybe_apply_injuries(party, bracket)
	if not injuries.is_empty():
		result["injuries"] = injuries

	if result["won"]:
		_apply_combat_event_reward(gs, mode, result)
		_maybe_grant_survival_epithets(party, bracket, injuries, result)
		var tag: String = str(mode.get("epithet_tag", "home_battle_won"))
		for u in party:
			var old_ep: String = u.epithet
			Chronicle.grant_epithet(u, tag)
			if u.epithet != "" and old_ep == "":
				result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])
		_apply_combat_event_item_drop(gs, mode, result)
		var rep_w: int = int(mode.get("rep_on_win", 0))
		if rep_w != 0:
			_log_reputation_crossing(result, gs.adjust_reputation(rep_w))
	else:
		result["notes"].append("Battle lost — the household pulls back behind the walls.")
		var rep_l: int = int(mode.get("rep_on_loss", 0))
		if rep_l != 0:
			_log_reputation_crossing(result, gs.adjust_reputation(rep_l))


# Reward dispatch for combat events. Reward kinds are intentionally narrow
# so adding a new combat event is "pick one of these four" + a few numbers.
static func _apply_combat_event_reward(gs: Node, mode: Dictionary, result: Dictionary) -> void:
	var kind: String = str(mode.get("reward_kind", ""))
	match kind:
		"bandit_bundle":
			result["reward"] = Combat.roll_bandit_ambush_reward(gs.week)
		"home_bundle":
			result["reward"] = Combat.roll_home_win_reward(gs.week)
		"gold_and_bundle":
			var purse: int = RNG.randi_range(int(mode.get("gold_min", 0)), int(mode.get("gold_max", 0)))
			if purse > 0:
				gs.gold += purse
				result["notes"].append("+%d gold" % purse)
			var lo: int = int(mode.get("bundle_lo", 1))
			var hi: int = int(mode.get("bundle_hi", 2))
			if hi >= lo and hi > 0:
				result["reward"] = {
					"logs":         RNG.randi_range(lo, hi),
					"plant_fibres": RNG.randi_range(lo, hi),
					"copper_ore":   RNG.randi_range(lo, hi),
				}
		"gold_only":
			var purse2: int = RNG.randi_range(int(mode.get("gold_min", 0)), int(mode.get("gold_max", 0)))
			if purse2 > 0:
				gs.gold += purse2
				result["notes"].append("+%d gold" % purse2)
		_:
			result["notes"].append("(unhandled reward kind: %s)" % kind)


# Item drop dispatch for combat events. Mirrors the named roll_*_drop
# functions on ItemDrops + the rarity-biased fallback the away custom
# modes use.
static func _apply_combat_event_item_drop(gs: Node, mode: Dictionary, result: Dictionary) -> void:
	var kind: String = str(mode.get("item_drop_fn", "none"))
	match kind:
		"ambush":
			_apply_item_drop(result, ItemDrops.roll_ambush_drop(gs))
		"home_defence":
			_apply_item_drop(result, ItemDrops.roll_home_defence_drop(gs))
		"rare_biased":
			var chance: float = float(mode.get("item_drop_chance", 0.0))
			if chance <= 0.0:
				return
			if RNG.randf_range(0.0, 1.0) >= chance:
				return
			_apply_item_drop(result, ItemDrops.drop_at_rarity(gs, Weapon.Rarity.RARE))
		"none":
			pass
		_:
			result["notes"].append("(unhandled item_drop_fn: %s)" % kind)


static func _resolve_bandit_ambush(gs: Node, result: Dictionary) -> void:
	var party: Array[Unit] = gs.at_home_units()
	result["notes"].append("Bandits at the gate.")
	if party.is_empty():
		result["fought"] = true
		result["won"] = false
		result["notes"].append("No one home — bandits help themselves.")
		return

	var player_cus: Array = _player_cus_home(party)
	var enemy_cus: Array  = EnemyDB.roll_combat_party("bandit_ambush", gs.week)
	var sim: Dictionary   = CombatSim.run(player_cus, enemy_cus)
	_fill_from_sim(result, sim, enemy_cus)

	var bracket: int = _bracket_from_sim(sim, player_cus)
	var injuries: Array[Dictionary] = OutcomeBracket.maybe_apply_injuries(party, bracket)
	if not injuries.is_empty():
		result["injuries"] = injuries

	if result["won"]:
		result["reward"] = Combat.roll_bandit_ambush_reward(gs.week)
		_maybe_grant_survival_epithets(party, bracket, injuries, result)
		for u in party:
			var old_ep: String = u.epithet
			Chronicle.grant_epithet(u, Chronicle.TAG_HOME_BATTLE_WON)
			if u.epithet != "" and old_ep == "":
				result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])
		_apply_item_drop(result, ItemDrops.roll_ambush_drop(gs))
	else:
		result["notes"].append("Bandits drove us off — no loot.")


static func _resolve_champion_duel(gs: Node, result: Dictionary) -> void:
	if gs.champion_unit_id < 0:
		result["notes"].append("No champion sent — Duel forfeit.")
		result["fought"] = true
		result["enemy_total"] = Combat.enemy_power_champion_duel(gs.week)
		result["enemy_pre_intim"] = result["enemy_total"]
		return

	var champ: Unit = gs.find_unit(gs.champion_unit_id)
	if champ == null or champ.is_on_expedition():
		result["notes"].append("Champion unavailable — Duel forfeit.")
		result["fought"] = true
		result["enemy_total"] = Combat.enemy_power_champion_duel(gs.week)
		result["enemy_pre_intim"] = result["enemy_total"]
		return

	var duel: Dictionary = BattleEvent.resolve_champion_duel(champ, gs.week)
	result["fought"] = true
	result["won"] = duel["won"]
	result["duel_unit_id"] = champ.id
	result["duel_player_power"] = duel["player_power"]
	result["duel_enemy_power"] = duel["enemy_power"]
	result["player_total"] = duel["player_power"]
	result["enemy_total"] = duel["enemy_power"]
	result["enemy_pre_intim"] = duel["enemy_power"]

	if duel["won"]:
		var old_ep: String = champ.epithet
		Chronicle.grant_epithet(champ, Chronicle.TAG_DUEL_WIN)
		if champ.epithet != "" and old_ep == "":
			result["notes"].append("%s earns the epithet '%s'." % [champ.unit_name, champ.epithet])
		var stat: String = gs.champion_target_stat
		if stat == "":
			result["notes"].append("No target stat picked — reward forfeit.")
		else:
			var bump: int = BodyType.cap_bump_for(champ.body_type, stat)
			# Staged: the duel feeds development rather than an instant +1.
			var dev: Dictionary = champ.stats.add_progress(stat, 2.5, champ.potential_ability, bump)
			result["duel_stat"] = stat
			result["duel_stat_applied"] = int(dev["leveled"]) > 0
			if int(dev["leveled"]) == 0:
				if champ.stats.get_value(stat) >= Stats.STAT_CAP + bump:
					result["notes"].append("Duel won but %s is already mastered." % stat)
				else:
					result["notes"].append("Duel won — its lessons settle into %s's %s over the weeks." % [champ.unit_name, stat])
	else:
		result["notes"].append("Duel lost — champion limps home.")


static func _resolve_bountiful_harvest(gs: Node, result: Dictionary) -> void:
	var bundle: Dictionary = BattleEvent.roll_harvest_bundle(gs.week)
	result["harvest_bundle"] = bundle
	result["reward"] = bundle
	result["won"] = true
	result["notes"].append("Bountiful Harvest — the fields are heavy.")


static func _resolve_merchant_caravan(gs: Node, result: Dictionary) -> void:
	gs.merchant_offers = BattleEvent.roll_caravan_offers(gs.week, 3)
	result["notes"].append("Merchant Caravan — pick a bundle on the summary.")
	# Reward is decided by the Weekly Summary's picker, not here.


# Refugees at the Gate. Three weighted outcomes:
#   sheltered  — costs gold, a random at-home unit gains +1 loyalty
#   passing    — free, a small reward bundle in coin/cloth
#   turned_away — flavour only, no cost, no reward
# Outcome is rolled once; the Weekly Summary surfaces the prose.
static func _resolve_refugee_caravan(gs: Node, result: Dictionary) -> void:
	var roll: float = RNG.randf_range(0.0, 1.0)
	var defenders: Array[Unit] = gs.at_home_units()
	result["fought"] = false
	result["won"] = true
	if roll < 0.40 and gs.gold >= 10:
		# Sheltered them. Costs gold, witnesses a small kindness.
		var cost: int = 10
		gs.gold = maxi(0, gs.gold - cost)
		result["notes"].append("Refugees sheltered at the gate. The kitchen ran lean and warm.")
		if not defenders.is_empty():
			var witness: Unit = defenders[RNG.randi_range(0, defenders.size() - 1)]
			var dev: Dictionary = witness.stats.add_progress("loyalty", 1.5, witness.potential_ability, BodyType.cap_bump_for(witness.body_type, "loyalty"))
			if int(dev["leveled"]) > 0:
				result["notes"].append("%s stood at the gate. He saw it, and a stat changed quietly. (+1 Loyalty)" % witness.unit_name)
			else:
				result["notes"].append("%s stood at the gate — something in him steadies." % witness.unit_name)
		result["refugee_outcome"] = "sheltered"
		result["refugee_cost"] = cost
	elif roll < 0.80:
		# They moved on — left a small payment in thanks.
		result["reward"] = {
			"logs":         1 + floori(gs.week / 18.0),
			"plant_fibres": 1 + floori(gs.week / 22.0),
		}
		result["notes"].append("Refugees passed in the night and left their thanks in cloth and kindling.")
		result["refugee_outcome"] = "passing"
	else:
		# Turned away. No cost, no reward. A note for the chronicler.
		result["notes"].append("Refugees turned away — the household is not yet a sanctuary.")
		result["refugee_outcome"] = "turned_away"


# A Noble's Petition. Half the time the household earns favour (gold + a
# random unit's etiquette polished); the other half it's a courtesy visit
# that costs nothing and rewards nothing. Either way it's a chronicle beat.
static func _resolve_noble_petition(gs: Node, result: Dictionary) -> void:
	var defenders: Array[Unit] = gs.at_home_units()
	var roll: float = RNG.randf_range(0.0, 1.0)
	result["fought"] = false
	result["won"] = true
	if roll < 0.55:
		var purse: int = 12 + floori(gs.week / 4.0)
		gs.gold += purse
		result["notes"].append("A neighbouring lord's envoy paid call — a small purse for hospitality. (+%d gold)" % purse)
		if not defenders.is_empty():
			var host: Unit = defenders[RNG.randi_range(0, defenders.size() - 1)]
			var dev: Dictionary = host.stats.add_progress("etiquette", 1.5, host.potential_ability, BodyType.cap_bump_for(host.body_type, "etiquette"))
			if int(dev["leveled"]) > 0:
				result["notes"].append("%s hosted the table. Watched, listened, learned. (+1 Etiquette)" % host.unit_name)
			else:
				result["notes"].append("%s hosted the table — courtesy sinks a little deeper." % host.unit_name)
		result["petition_outcome"] = "honoured"
	else:
		result["notes"].append("A noble's envoy arrived, drank deep, and rode out at dawn with vague promises.")
		result["petition_outcome"] = "courtesy"


# A Village Under Attack — a real fight on the home side. The household
# rides to defend a nearby village. Strong combat (uses the home_battle
# enemy template) but the reward is village-grateful: gold purse + small
# bundle + a meaningful reputation bump on the win. Loss costs reputation
# and contributes no reward — symmetric with how home-battle losses read
# on the chip.
static func _resolve_village_raid(gs: Node, result: Dictionary) -> void:
	var party: Array[Unit] = gs.at_home_units()
	result["notes"].append("Riding to defend the village.")
	if party.is_empty():
		result["fought"] = true
		result["won"] = false
		result["notes"].append("No one home to ride — the village burns without you.")
		_log_reputation_crossing(result, gs.adjust_reputation(-3))
		return

	var player_cus: Array = _player_cus_home(party)
	var enemy_cus: Array  = EnemyDB.roll_combat_party("home_battle", gs.week)
	var sim: Dictionary   = CombatSim.run(player_cus, enemy_cus)
	_fill_from_sim(result, sim, enemy_cus)

	var bracket: int = _bracket_from_sim(sim, player_cus)
	var injuries: Array[Dictionary] = OutcomeBracket.maybe_apply_injuries(party, bracket)
	if not injuries.is_empty():
		result["injuries"] = injuries

	if result["won"]:
		# Gold purse from the saved village + a small bundle of cloth and
		# timber pressed on the riders before they leave.
		var purse: int = 14 + floori(gs.week / 6.0)
		gs.gold += purse
		result["notes"].append("Village saved — +%d gold pressed on the household." % purse)
		var hi: int = 2 + floori(gs.week / 12.0)
		result["reward"] = {
			"logs":         RNG.randi_range(1, hi),
			"plant_fibres": RNG.randi_range(1, hi),
			"copper_ore":   RNG.randi_range(1, hi),
		}
		_maybe_grant_survival_epithets(party, bracket, injuries, result)
		for u in party:
			var old_ep: String = u.epithet
			Chronicle.grant_epithet(u, Chronicle.TAG_HOME_BATTLE_WON)
			if u.epithet != "" and old_ep == "":
				result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])
		_apply_item_drop(result, ItemDrops.roll_home_defence_drop(gs))
		_log_reputation_crossing(result, gs.adjust_reputation(4))
	else:
		result["notes"].append("Village lost — the household rides home in silence.")
		_log_reputation_crossing(result, gs.adjust_reputation(-2))


# A Tavern Riot — light combat that doubles as a discipline lesson. The
# household marshal quells a brawl at the nearest inn before it spreads to
# the village proper. Combat uses the bandit-ambush template (gentler than
# a home-battle band); the reward is a small purse + a roster-wide loyalty
# tick from the shared show of force.
static func _resolve_tavern_riot(gs: Node, result: Dictionary) -> void:
	var party: Array[Unit] = gs.at_home_units()
	result["notes"].append("The marshal rides to the village inn.")
	if party.is_empty():
		result["fought"] = true
		result["won"] = false
		result["notes"].append("No one home — the riot burns itself out by morning, the inn does not.")
		_log_reputation_crossing(result, gs.adjust_reputation(-1))
		return

	var player_cus: Array = _player_cus_home(party)
	var enemy_cus: Array  = EnemyDB.roll_combat_party("bandit_ambush", gs.week)
	var sim: Dictionary   = CombatSim.run(player_cus, enemy_cus)
	_fill_from_sim(result, sim, enemy_cus)

	var bracket: int = _bracket_from_sim(sim, player_cus)
	var injuries: Array[Dictionary] = OutcomeBracket.maybe_apply_injuries(party, bracket)
	if not injuries.is_empty():
		result["injuries"] = injuries

	if result["won"]:
		var purse: int = 6 + floori(gs.week / 8.0)
		gs.gold += purse
		result["notes"].append("Riot quelled — innkeeper presses %d gold on the marshal." % purse)
		# Roster-wide loyalty development — the show of unity at a small action
		# matters more than the action itself. Staged, so it deepens over time.
		for u in party:
			u.stats.add_progress("loyalty", 1.0, u.potential_ability, BodyType.cap_bump_for(u.body_type, "loyalty"))
		result["notes"].append("Household discipline tightens — loyalty deepens across the roster.")
		_maybe_grant_survival_epithets(party, bracket, injuries, result)
		for u in party:
			var old_ep: String = u.epithet
			Chronicle.grant_epithet(u, Chronicle.TAG_HOME_BATTLE_WON)
			if u.epithet != "" and old_ep == "":
				result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])
		_log_reputation_crossing(result, gs.adjust_reputation(1))
	else:
		result["notes"].append("Riot spills into the street — the inn is half-wrecked by dawn.")
		_log_reputation_crossing(result, gs.adjust_reputation(-1))


# ---------- Tournament ----------

static func _resolve_tournament(gs: Node, result: Dictionary, is_grand: bool) -> void:
	var participants: Array[Unit] = []
	for uid in gs.tournament_participants:
		var u: Unit = gs.find_unit(uid)
		if u != null and u.is_at_home():
			participants.append(u)

	var enemy: int = (
		Combat.enemy_power_grand_tournament(gs.week)
		if is_grand
		else Combat.enemy_power_tournament(gs.week)
	)
	result["notes"].append(
		"%s — enemy power %d." % [EventKind.label(gs.current_event), enemy]
	)
	if participants.is_empty():
		result["fought"] = true
		result["won"] = false
		result["enemy_total"] = enemy
		result["enemy_pre_intim"] = enemy
		result["notes"].append("No participants — automatic forfeit.")
	else:
		var combat: Dictionary = Combat.resolve_tournament(participants, enemy)
		result["fought"] = true
		result["won"] = combat["won"]
		result["tournament_per_unit"] = combat["per_unit"]
		result["player_total"] = combat["player_total"]
		result["enemy_total"] = combat["enemy_after_intimidation"]
		result["enemy_pre_intim"] = combat["enemy_power"]
		result["intimidation_reduction"] = 0

	# Streak + Grand handling per GDD §6.
	if result["won"]:
		# Reputation bonus on tournament prizes — every 4 rep adds 1 gold to
		# the purse, capped at +25 so legendary status doesn't trivialise
		# tournament economy. Negative reputation halves the bonus to zero
		# but never reduces the base prize.
		var rep_bonus: int = clampi(gs.reputation / 4, 0, 25)
		if is_grand:
			result["is_run_win"] = true
			result["notes"].append("Grand Tournament won — the realm is yours!")
			gs.tournament_streak = 0
			var prize: int = 50 + (Calendar.tournament_number(gs.week) * 25) + rep_bonus
			gs.gold += prize
			result["tournament_gold"] = prize
			if rep_bonus > 0:
				result["notes"].append("Grand Tournament prize: +%d gold (incl. +%d for standing)." % [prize, rep_bonus])
			else:
				result["notes"].append("Grand Tournament prize: +%d gold." % prize)
			for u in participants:
				var old_ep: String = u.epithet
				Chronicle.grant_epithet(u, Chronicle.TAG_GRAND_TOURNAMENT_WIN)
				if u.epithet != "" and old_ep == "":
					result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])
			_apply_item_drop(result, ItemDrops.roll_grand_tournament_drop(gs))
			# Winning the realm is worth a healthy reputation jump on top of
			# the win itself — narratively, "Realm-Winner" should at least
			# nudge the chip into Renowned territory.
			_log_reputation_crossing(result, gs.adjust_reputation(8))
		else:
			gs.tournament_streak += 1
			result["notes"].append("Tournament won — streak now %d." % gs.tournament_streak)
			result["reward"] = Combat.roll_tournament_reward(gs.week, participants)
			var prize: int = 50 + (Calendar.tournament_number(gs.week) * 25) + rep_bonus
			gs.gold += prize
			result["tournament_gold"] = prize
			if rep_bonus > 0:
				result["notes"].append("Tournament prize: +%d gold (incl. +%d for standing)." % [prize, rep_bonus])
			else:
				result["notes"].append("Tournament prize: +%d gold." % prize)
			for u in participants:
				var old_ep: String = u.epithet
				Chronicle.grant_epithet(u, Chronicle.TAG_TOURNAMENT_WIN)
				if u.epithet != "" and old_ep == "":
					result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])
			_apply_item_drop(result, ItemDrops.roll_tournament_drop(gs))
			# Smaller bump for a regular tournament win.
			_log_reputation_crossing(result, gs.adjust_reputation(2))
	else:
		gs.tournament_streak = 0
		if is_grand:
			result["notes"].append("Grand Tournament lost — streak reset, the run goes on.")
		else:
			result["notes"].append("Tournament lost — streak reset.")


# ---------- helpers ----------

# Stash a rolled drop on the result and add a flavour note so the Weekly
# Summary "Rewards" section can surface it. No-op when the drop dict is empty.
static func _apply_item_drop(result: Dictionary, drop: Dictionary) -> void:
	if drop.is_empty():
		return
	result["item_drop"] = drop
	result["notes"].append("Found in the field: %s" % ItemDrops.describe_drop(drop))


# Echoes the chip-band crossing returned by GameState.adjust_reputation()
# into the result notes. Empty string = no boundary crossed, no note. Up-vs-
# down phrasing is left simple: the band label is the same in both directions,
# so the prose distinction is in the verb. We default to the "down" phrasing
# whenever the new band sounds worse than the previous one, but a fully
# robust direction check would need a band index — that's fine for now since
# rep deltas in Resolution are signed and the caller already knows direction
# from the call site. To keep this helper agnostic, we just announce the new
# label and let the surrounding note carry the win/loss context.
static func _log_reputation_crossing(result: Dictionary, new_band: String) -> void:
	if new_band == "":
		return
	result["notes"].append("→ Standing crossed: now %s." % new_band)


# Grant TAG_HOME_BATTLE_SURVIVED to defenders who stood through a close-margin
# home-side win. The "close win" trigger is OutcomeBracket.Bracket.ORANGE on a
# winning sim — the player's HP fell below 50% of starting but still beat the
# enemy. The bandit_ambush / home_battle / village_raid / tavern_riot resolvers
# all call this BEFORE their TAG_HOME_BATTLE_WON loop so survival epithets
# (more dramatic) take precedence over the generic win tag.
#
# Wires the previously-dead TAG_HOME_BATTLE_SURVIVED pool — see the CLAUDE.md
# pitfalls note about that tag being defined but never granted.
static func _maybe_grant_survival_epithets(party: Array, bracket: int, injuries: Array, result: Dictionary) -> void:
	if bracket != OutcomeBracket.Bracket.ORANGE:
		return
	# Build a set of injured unit ids — survivors are everyone else in the
	# party. A unit injured in this very battle wouldn't read as "the Wall"
	# — the survival epithets are for the units who held without being hurt.
	var injured_ids: Array[int] = []
	for inj in injuries:
		injured_ids.append(int(inj.get("unit_id", -1)))
	for u in party:
		if injured_ids.has(u.id):
			continue
		var old_ep: String = u.epithet
		Chronicle.grant_epithet(u, Chronicle.TAG_HOME_BATTLE_SURVIVED)
		if u.epithet != "" and old_ep == "":
			result["notes"].append("%s earns the epithet '%s'." % [u.unit_name, u.epithet])


static func _away_party(gs: Node) -> Array[Unit]:
	var out: Array[Unit] = []
	for uid in gs.pending_away_party:
		var u: Unit = gs.find_unit(uid)
		if u != null and u.is_at_home():
			out.append(u)
	return out


# Populate result from a CombatSim run. player_total/enemy_total are HP
# remainders — used by weekly_summary for the "X vs Y" display line.
# per_unit is left empty until the breakdown is migrated to the sim turn_log
# (weekly_summary's battle breakdown section renders per_unit when populated).
static func _fill_from_sim(result: Dictionary, sim: Dictionary, enemy_cus: Array = []) -> void:
	result["fought"] = true
	result["won"] = sim["winner"] == "player"
	result["player_total"] = sim["player_hp_remaining"]
	result["enemy_total"] = sim["enemy_hp_remaining"]
	result["enemy_pre_intim"] = sim["enemy_hp_remaining"]
	result["intimidation_reduction"] = 0
	result["per_unit"] = []
	result["sim_result"] = sim
	for note in sim["notes"]:
		result["notes"].append(note)
	# Mob drops from the kill — separate from the encounter `reward` bundle.
	# Defaults to an empty array for callers that haven't been updated, in
	# which case no spoils are rolled (back-compat).
	if not enemy_cus.is_empty():
		_roll_spoils_from_enemies(result, enemy_cus)


# Roll mob-drop spoils from every enemy CombatUnit that died this fight.
# Spoils live on `result["spoils"]` as a Dictionary keyed by ResourceDB ids,
# separate from `result["reward"]` (which is the *encounter* bundle from
# RewardTableDB). Conceptually: reward = "loot from the cause," spoils =
# "loot from the kill." Surfaces as a distinct line on the Weekly Summary.
#
# Only fired on wins — a loss / draw doesn't get the kill loot. Per-enemy
# drops come from `EnemyDB.ENEMY_TYPES[type_id].drops`, so adding a new
# enemy automatically expands the loot pool without touching any resolver.
static func _roll_spoils_from_enemies(result: Dictionary, enemy_cus: Array) -> void:
	if not result.get("won", false):
		return
	var spoils: Dictionary = {}
	for cu: CombatUnit in enemy_cus:
		if cu.is_alive():
			continue
		var type_id: String = ""
		if cu.unit != null and "type_id" in cu.unit:
			type_id = str(cu.unit.type_id)
		if type_id == "":
			continue
		var drops: Dictionary = EnemyDB.roll_drops_for(type_id, 1.0)
		ResourceDB.merge(spoils, drops)
	if spoils.is_empty():
		return
	# Merge into any pre-existing spoils (e.g. if a future path adds extra
	# kill-bonus drops before this call).
	var existing: Dictionary = result.get("spoils", {})
	if existing.is_empty():
		result["spoils"] = spoils
	else:
		ResourceDB.merge(existing, spoils)
		result["spoils"] = existing
	# Quick chronicle note so the player feels the kill.
	result["notes"].append("Spoils from the fallen: %s" % ResourceDB.describe(spoils))


# Derive OutcomeBracket injury bracket from HP remaining after the sim.
static func _bracket_from_sim(sim: Dictionary, player_cus: Array) -> int:
	if sim["winner"] != "player":
		return OutcomeBracket.Bracket.RED
	var hp_start: int = 0
	for cu: CombatUnit in player_cus:
		hp_start += cu.max_hp
	if hp_start == 0:
		return OutcomeBracket.Bracket.RED
	var pct: float = float(sim["player_hp_remaining"]) / float(hp_start)
	return OutcomeBracket.Bracket.GREEN if pct >= 0.50 else OutcomeBracket.Bracket.ORANGE


# Build CombatUnits for a plain away party (no home-battle penalty).
static func _player_cus(party: Array) -> Array:
	var out: Array = []
	for u: Unit in party:
		out.append(CombatUnit.new(u))
	return out


# Build CombatUnits for a home-battle party, applying 0.75× to non-Defend units.
static func _player_cus_home(party: Array) -> Array:
	var out: Array = []
	for u: Unit in party:
		var mult: float = 1.0 if u.current_task == Unit.TASK_DEFEND else 0.75
		out.append(CombatUnit.new(u, "", "", mult))
	return out


# Kept for tournament resolution which still uses the scalar model.
static func _fill_combat(result: Dictionary, combat: Dictionary) -> void:
	result["fought"] = true
	result["won"] = combat["won"]
	result["per_unit"] = combat["per_unit"]
	result["player_total"] = combat["player_total"]
	result["enemy_total"] = combat["enemy_after_intimidation"]
	result["enemy_pre_intim"] = combat["enemy_power"]
	result["intimidation_reduction"] = combat["intimidation_reduction"]


static func _remove_castle(gs: Node, castle: Castle) -> void:
	gs.world.castles.erase(castle)
	var tile: MapTile = gs.world.get_tile(castle.x, castle.y)
	if tile != null and tile.castle == castle:
		tile.castle = null


# Reward delivery — merge the result's reward Dictionary into the household
# inventory. Caravan reward is delivered by the Weekly Summary picker (not here).
# Spoils (per-kill mob drops, accumulated in result["spoils"]) are merged the
# same way so the inventory sees the full take of the week.
static func _apply_reward(gs: Node, result: Dictionary) -> void:
	var reward: Dictionary = result.get("reward", {})
	if not reward.is_empty():
		ResourceDB.merge(gs.inventory, reward)
	var spoils: Dictionary = result.get("spoils", {})
	if not spoils.is_empty():
		ResourceDB.merge(gs.inventory, spoils)
