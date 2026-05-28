class_name CombatSim
extends RefCounted

# Turn-based tactical combat simulation. Takes two groups of CombatUnits,
# simulates rounds until one side is eliminated or the turn cap is hit, and
# returns a detailed result dictionary. Pure — no GameState access.
#
# Each "turn" is one combatant's action (not a full round). All combatants
# act in initiative order (highest first); the cycle repeats until combat ends.
# Targets are chosen randomly from living enemies — no focus-fire.
#
# Attack resolution per action:
#   1. Hit roll    — attacker.hit_chance vs RNG
#   2. Dodge roll  — defender.dodge_chance vs RNG (only if hit)
#   3. Block roll  — defender.block_chance vs RNG (only if not dodged)
#   4. Damage roll — rand(damage_min, damage_max) × crit_mult if crit
#   5. Reduction   — max(1, raw_damage − defender.armour_value)
#
# Result shape:
#   {
#     "winner":                "player" | "enemy" | "draw",
#     "player_hp_remaining":   int,
#     "enemy_hp_remaining":    int,
#     "combatant_stats":       Array[Dictionary],
#     "turn_log":              Array[Dictionary],
#     "notes":                 Array[String],
#   }
#
# combatant_stats entry:
#   { unit_id, name, side, weapon, armour, hp_start, hp_end,
#     hits_landed, hits_taken, damage_dealt, damage_taken, crits, dodges }
#
# turn_log entry:
#   { turn, attacker_id, attacker_name, defender_id, defender_name,
#     hit, dodged, blocked, crit, damage, defender_hp }

const DEFAULT_MAX_TURNS: int = 30


static func run(
	player_units: Array,   # Array[CombatUnit]
	enemy_units:  Array,   # Array[CombatUnit]
	max_turns: int = DEFAULT_MAX_TURNS,
) -> Dictionary:

	var result: Dictionary = {
		"winner":              "draw",
		"player_hp_remaining": 0,
		"enemy_hp_remaining":  0,
		"combatant_stats":     [],
		"turn_log":            [],
		"notes":               [],
	}

	if player_units.is_empty() or enemy_units.is_empty():
		result["notes"].append("Combat aborted: one side has no combatants.")
		return result

	var tracking: Dictionary = {}
	for cu in player_units:
		tracking[cu.unit.id] = _blank_tracking(cu, "player")
	for cu in enemy_units:
		tracking[cu.unit.id] = _blank_tracking(cu, "enemy")

	var turn: int = 0

	while turn < max_turns:
		var living_player: Array = _living(player_units)
		var living_enemy:  Array = _living(enemy_units)

		if living_player.is_empty() or living_enemy.is_empty():
			break

		# Build round order: all living combatants sorted by initiative,
		# with a small random tiebreaker so identical values don't always go
		# in the same order. The jitter is rolled ONCE per combatant before
		# the sort, then stored in `_init_jitter` so the comparator is
		# deterministic for a given pair — calling RNG inside the lambda
		# would mean the same (a, b) could compare both ways across calls,
		# violating sort invariants.
		var order: Array = living_player + living_enemy
		for cu: CombatUnit in order:
			cu._init_jitter = cu.initiative + RNG.randi_range(0, 2)
		order.sort_custom(
			func(a: CombatUnit, b: CombatUnit) -> bool:
				return a._init_jitter > b._init_jitter
		)

		for cu: CombatUnit in order:
			if not cu.is_alive():
				continue

			turn += 1
			if turn > max_turns:
				break

			var is_player: bool = player_units.has(cu)
			var enemy_pool: Array = _living(enemy_units if is_player else player_units)
			if enemy_pool.is_empty():
				break

			# Random target — avoids tank/focus-fire degenerate strategy.
			var target: CombatUnit = enemy_pool[RNG.randi_range(0, enemy_pool.size() - 1)]

			var entry: Dictionary = _resolve_attack(cu, target, turn)
			result["turn_log"].append(entry)

			var atk_tr: Dictionary = tracking[cu.unit.id]
			var def_tr: Dictionary = tracking[target.unit.id]

			if entry["hit"] and not entry["dodged"] and not entry["blocked"]:
				atk_tr["hits_landed"]  += 1
				atk_tr["damage_dealt"] += entry["damage"]
				def_tr["hits_taken"]   += 1
				def_tr["damage_taken"] += entry["damage"]
				if entry["crit"]:
					atk_tr["crits"] += 1
			elif entry["dodged"]:
				def_tr["dodges"] += 1

		if _living(player_units).is_empty() or _living(enemy_units).is_empty():
			break

	var hp_player: int = 0
	for cu: CombatUnit in player_units:
		hp_player += cu.current_hp
	var hp_enemy: int = 0
	for cu: CombatUnit in enemy_units:
		hp_enemy += cu.current_hp
	result["player_hp_remaining"] = hp_player
	result["enemy_hp_remaining"]  = hp_enemy

	var alive_player: int = _living(player_units).size()
	var alive_enemy:  int = _living(enemy_units).size()

	if alive_player > 0 and alive_enemy == 0:
		result["winner"] = "player"
		result["notes"].append("Player victorious.")
	elif alive_enemy > 0 and alive_player == 0:
		result["winner"] = "enemy"
		result["notes"].append("Enemy victorious.")
	else:
		result["winner"] = "draw" if hp_player == hp_enemy else ("player" if hp_player > hp_enemy else "enemy")
		result["notes"].append(
			"Turn limit — %s ahead on HP (%d vs %d)." % [
				result["winner"], hp_player, hp_enemy
			]
		)

	for cu: CombatUnit in player_units + enemy_units:
		var tr: Dictionary = tracking[cu.unit.id]
		tr["hp_end"] = cu.current_hp
		result["combatant_stats"].append(tr)

	return result


# Fast matchup analysis — no RNG, no HP mutation. Uses aggregate combat scores
# to estimate win probability. Safe to call from UI on every frame.
#
# Returns:
#   { win_probability: float (0–1), label: String, color: Color,
#     player_score: float, enemy_score: float }
static func analyze(player_units: Array, enemy_units: Array) -> Dictionary:
	var p_score: float = _side_score(player_units)
	var e_score: float = _side_score(enemy_units)
	var total: float = p_score + e_score
	var win_prob: float = (p_score / total) if total > 0.0 else 0.5

	# Map to OutcomeBracket colours using scaled integer proxy values.
	var p_int: int = roundi(p_score * 10.0)
	var e_int: int = roundi(e_score * 10.0)
	return {
		"win_probability": win_prob,
		"label":           OutcomeBracket.label_for(p_int, e_int),
		"color":           OutcomeBracket.color_for(p_int, e_int),
		"player_score":    p_score,
		"enemy_score":     e_score,
	}


# ---------- helpers ----------

static func _living(group: Array) -> Array:
	var out: Array = []
	for cu: CombatUnit in group:
		if cu.is_alive():
			out.append(cu)
	return out


# Combat score: expected damage output × effective survivability.
# Higher is better. Used by analyze() — no randomness involved.
static func _side_score(units: Array) -> float:
	var score: float = 0.0
	for cu: CombatUnit in units:
		var dpt: float = cu.hit_chance * float(cu.damage_min + cu.damage_max) * 0.5
		var evasion: float = cu.dodge_chance + (1.0 - cu.dodge_chance) * cu.block_chance
		var effective_hp: float = float(cu.max_hp) * (1.0 + evasion * 0.5)
		score += dpt * effective_hp
	return score


static func _resolve_attack(attacker: CombatUnit, defender: CombatUnit, turn: int) -> Dictionary:
	var entry: Dictionary = {
		"turn":          turn,
		"attacker_id":   attacker.unit.id,
		"attacker_name": attacker.unit.unit_name,
		"defender_id":   defender.unit.id,
		"defender_name": defender.unit.unit_name,
		"hit":           false,
		"dodged":        false,
		"blocked":       false,
		"crit":          false,
		"damage":        0,
		"defender_hp":   defender.current_hp,
	}

	if RNG.randf_range(0.0, 1.0) >= attacker.hit_chance:
		return entry
	entry["hit"] = true

	if RNG.randf_range(0.0, 1.0) < defender.dodge_chance:
		entry["dodged"] = true
		return entry

	if RNG.randf_range(0.0, 1.0) < defender.block_chance:
		entry["blocked"] = true
		return entry

	var is_crit: bool = RNG.randf_range(0.0, 1.0) < attacker.crit_chance
	entry["crit"] = is_crit
	var raw: int = attacker.roll_damage()
	if is_crit:
		raw = ceili(float(raw) * attacker.crit_multiplier)
	var effective: int = maxi(1, raw - defender.armour_value)
	entry["damage"] = effective
	defender.current_hp = maxi(0, defender.current_hp - effective)
	entry["defender_hp"] = defender.current_hp

	return entry


static func _blank_tracking(cu: CombatUnit, side: String) -> Dictionary:
	return {
		"unit_id":      cu.unit.id,
		"name":         cu.unit.unit_name,
		"side":         side,
		"weapon":       cu.weapon.get("name", "?"),
		"armour":       cu.armour.get("name", "?"),
		"hp_start":     cu.max_hp,
		"hp_end":       0,
		"hits_landed":  0,
		"hits_taken":   0,
		"damage_dealt": 0,
		"damage_taken": 0,
		"crits":        0,
		"dodges":       0,
	}
