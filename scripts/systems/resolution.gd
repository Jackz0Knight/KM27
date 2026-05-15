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

	_apply_reward(gs, result)
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

	var enemy: int = 0
	if gs.pending_away_mode == "assault":
		if gs.pending_assault_castle == null:
			result["notes"].append("Assault chosen but no castle selected — skipped.")
			return
		enemy = gs.pending_assault_castle.difficulty
		result["notes"].append("Assaulting castle (%d,%d) diff %d." % [
			gs.pending_assault_castle.x, gs.pending_assault_castle.y,
			gs.pending_assault_castle.difficulty,
		])
	else:
		enemy = Combat.enemy_power_pillage(gs.week)
		result["notes"].append("Pillage Camp — enemy power %d." % enemy)

	var combat: Dictionary = Combat.resolve_formation(party, gs.formation, enemy, false)
	_fill_combat(result, combat)

	if combat["won"]:
		if gs.pending_away_mode == "assault":
			var castle: Castle = gs.pending_assault_castle
			result["reward"] = castle.reward.duplicate_bundle()
			result["castle_taken"] = castle
			_remove_castle(gs, castle)
		else:
			result["reward"] = Combat.roll_pillage_reward(gs.week)
	else:
		result["notes"].append("Battle lost — no reward.")


# ---------- Home Battle ----------

static func _resolve_home(gs: Node, result: Dictionary) -> void:
	var party: Array[Unit] = gs.at_home_units()
	var enemy: int = Combat.enemy_power_home(gs.week)
	result["notes"].append("Defending homestead — enemy power %d." % enemy)

	if party.is_empty():
		# No defenders at all. GDD §2: lose Home Battle → game over.
		result["fought"] = true
		result["won"] = false
		result["enemy_total"] = enemy
		result["enemy_pre_intim"] = enemy
		result["notes"].append("No defenders at home — homestead breached.")
		result["is_game_over"] = true
		return

	var combat: Dictionary = Combat.resolve_formation(party, gs.formation, enemy, true)
	_fill_combat(result, combat)

	if combat["won"]:
		result["reward"] = Combat.roll_home_win_reward(gs.week)
	else:
		result["is_game_over"] = true
		result["notes"].append("Homestead breached — GAME OVER.")


# ---------- Battle Event ----------

static func _resolve_battle_event(gs: Node, result: Dictionary) -> void:
	match gs.current_battle_event:
		"bandit_ambush":
			_resolve_bandit_ambush(gs, result)
		"champion_duel":
			_resolve_champion_duel(gs, result)
		"bountiful_harvest":
			_resolve_bountiful_harvest(gs, result)
		"merchant_caravan":
			_resolve_merchant_caravan(gs, result)
		_:
			result["notes"].append("Unknown Battle Event sub-type.")


static func _resolve_bandit_ambush(gs: Node, result: Dictionary) -> void:
	var party: Array[Unit] = gs.at_home_units()
	var enemy: int = Combat.enemy_power_bandit_ambush(gs.week)
	result["notes"].append("Bandits at the gate — enemy power %d." % enemy)
	if party.is_empty():
		result["fought"] = true
		result["won"] = false
		result["enemy_total"] = enemy
		result["enemy_pre_intim"] = enemy
		result["notes"].append("No one home — bandits help themselves.")
		return

	var combat: Dictionary = Combat.resolve_formation(party, gs.formation, enemy, true)
	_fill_combat(result, combat)
	if combat["won"]:
		result["reward"] = Combat.roll_bandit_ambush_reward(gs.week)
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
		var stat: String = gs.champion_target_stat
		if stat == "":
			result["notes"].append("No target stat picked — reward forfeit.")
		else:
			var applied: bool = champ.stats.try_increment(stat, champ.potential_ability)
			result["duel_stat"] = stat
			result["duel_stat_applied"] = applied
			if not applied:
				result["notes"].append("Duel won but %s is capped — no growth." % stat)
	else:
		result["notes"].append("Duel lost — champion limps home.")


static func _resolve_bountiful_harvest(gs: Node, result: Dictionary) -> void:
	var bundle: ResourceBundle = BattleEvent.roll_harvest_bundle(gs.week)
	result["harvest_bundle"] = bundle
	result["reward"] = bundle
	result["won"] = true
	result["notes"].append("Bountiful Harvest — the fields are heavy.")


static func _resolve_merchant_caravan(gs: Node, result: Dictionary) -> void:
	gs.merchant_offers = BattleEvent.roll_caravan_offers(gs.week, 3)
	result["notes"].append("Merchant Caravan — pick a bundle on the summary.")
	# Reward is decided by the Weekly Summary's picker, not here.


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
		if is_grand:
			result["is_run_win"] = true
			result["notes"].append("Grand Tournament won — the realm is yours!")
			# Streak doesn't matter after a win; reset for hygiene.
			gs.tournament_streak = 0
		else:
			gs.tournament_streak += 1
			result["notes"].append("Tournament won — streak now %d." % gs.tournament_streak)
			result["reward"] = Combat.roll_tournament_reward(gs.week, participants)
	else:
		gs.tournament_streak = 0
		if is_grand:
			result["notes"].append("Grand Tournament lost — streak reset, the run goes on.")
		else:
			result["notes"].append("Tournament lost — streak reset.")


# ---------- helpers ----------

static func _away_party(gs: Node) -> Array[Unit]:
	var out: Array[Unit] = []
	for uid in gs.pending_away_party:
		var u: Unit = gs.find_unit(uid)
		if u != null and u.is_at_home():
			out.append(u)
	return out


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


# Reward delivery — push resources into GameState.inventory via the bundle's
# inventory mapping. Caravan reward is delivered by the Weekly Summary picker.
static func _apply_reward(gs: Node, result: Dictionary) -> void:
	var reward: ResourceBundle = result.get("reward")
	if reward == null:
		return
	var inv_delta: Dictionary = reward.to_inventory_dict()
	for id: String in inv_delta:
		gs.inventory[id] = gs.inventory.get(id, 0) + inv_delta[id]
