class_name CombatSim
extends RefCounted

# Turn-based tactical combat simulation. Takes two groups of CombatUnits,
# simulates rounds until one side is eliminated or the turn cap is hit, and
# returns a detailed result dictionary. Pure — no GameState access.
#
# Each "turn" is one combatant's action (not a full round). All combatants
# act in initiative order (highest first); the cycle repeats until combat ends.
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
#     "winner":                "attackers" | "defenders" | "draw",
#     "turns_taken":           int,
#     "attacker_hp_remaining": int,
#     "defender_hp_remaining": int,
#     "combatant_stats":       Array[Dictionary],   # one per combatant
#     "turn_log":              Array[Dictionary],   # one per action
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
	attackers: Array,   # Array[CombatUnit]
	defenders: Array,   # Array[CombatUnit]
	max_turns: int = DEFAULT_MAX_TURNS,
) -> Dictionary:

	var result: Dictionary = {
		"winner":                "draw",
		"turns_taken":           0,
		"attacker_hp_remaining": 0,
		"defender_hp_remaining": 0,
		"combatant_stats":       [],
		"turn_log":              [],
		"notes":                 [],
	}

	if attackers.is_empty() or defenders.is_empty():
		result["notes"].append("Combat aborted: one side has no combatants.")
		return result

	# Per-combatant tracking (accumulated across turns).
	var tracking: Dictionary = {}
	for cu in attackers:
		tracking[cu.unit.id] = _blank_tracking(cu, "attackers")
	for cu in defenders:
		tracking[cu.unit.id] = _blank_tracking(cu, "defenders")

	var turn: int = 0

	while turn < max_turns:
		var living_atk: Array = _living(attackers)
		var living_def: Array = _living(defenders)

		if living_atk.is_empty() or living_def.is_empty():
			break

		# Build turn order for this round: all living combatants sorted by
		# initiative descending. A small random tiebreaker keeps fights dynamic
		# when two units share an initiative value.
		var order: Array = living_atk + living_def
		order.sort_custom(
			func(a: CombatUnit, b: CombatUnit) -> bool:
				var ia: int = a.initiative + RNG.randi_range(0, 2)
				var ib: int = b.initiative + RNG.randi_range(0, 2)
				return ia > ib
		)

		for cu: CombatUnit in order:
			if not cu.is_alive():
				continue

			turn += 1
			if turn > max_turns:
				break

			var is_attacker: bool = attackers.has(cu)
			var enemy_pool: Array = _living(defenders if is_attacker else attackers)
			if enemy_pool.is_empty():
				break

			# Target selection: lowest HP enemy (focus-fire).
			enemy_pool.sort_custom(
				func(a: CombatUnit, b: CombatUnit) -> bool:
					return a.current_hp < b.current_hp
			)
			var target: CombatUnit = enemy_pool[0]

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

		# Check termination after each full round cycle.
		if _living(attackers).is_empty() or _living(defenders).is_empty():
			break

	result["turns_taken"] = turn

	# Final HP tallies.
	var hp_atk: int = 0
	for cu: CombatUnit in attackers:
		hp_atk += cu.current_hp
	var hp_def: int = 0
	for cu: CombatUnit in defenders:
		hp_def += cu.current_hp
	result["attacker_hp_remaining"] = hp_atk
	result["defender_hp_remaining"] = hp_def

	# Determine winner.
	var alive_atk: int = _living(attackers).size()
	var alive_def: int = _living(defenders).size()

	if alive_atk > 0 and alive_def == 0:
		result["winner"] = "attackers"
		result["notes"].append("Attackers victorious in %d turns." % turn)
	elif alive_def > 0 and alive_atk == 0:
		result["winner"] = "defenders"
		result["notes"].append("Defenders held in %d turns." % turn)
	else:
		# Turn cap reached — winner by remaining HP.
		if hp_atk > hp_def:
			result["winner"] = "attackers"
			result["notes"].append("Turn limit reached — attackers ahead on HP (%d vs %d)." % [hp_atk, hp_def])
		elif hp_def > hp_atk:
			result["winner"] = "defenders"
			result["notes"].append("Turn limit reached — defenders ahead on HP (%d vs %d)." % [hp_def, hp_atk])
		else:
			result["winner"] = "draw"
			result["notes"].append("Combat ended — equal HP remaining, declared a draw.")

	# Finalise combatant summaries.
	for cu: CombatUnit in attackers + defenders:
		var tr: Dictionary = tracking[cu.unit.id]
		tr["hp_end"] = cu.current_hp
		result["combatant_stats"].append(tr)

	return result


# ---------- helpers ----------

static func _living(group: Array) -> Array:
	var out: Array = []
	for cu: CombatUnit in group:
		if cu.is_alive():
			out.append(cu)
	return out


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

	# 1. Hit roll.
	if RNG.randf_range(0.0, 1.0) >= attacker.hit_chance:
		return entry
	entry["hit"] = true

	# 2. Dodge roll.
	if RNG.randf_range(0.0, 1.0) < defender.dodge_chance:
		entry["dodged"] = true
		return entry

	# 3. Block roll.
	if RNG.randf_range(0.0, 1.0) < defender.block_chance:
		entry["blocked"] = true
		return entry

	# 4. Damage.
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
