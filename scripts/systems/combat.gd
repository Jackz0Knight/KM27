class_name Combat
extends RefCounted

# Phase 6 battle math per GDD §12 + §13. Pure functions — given a roster, a
# formation, and an enemy total, return the per-unit breakdown and the
# winner. Resolution.gd is the caller; Combat doesn't read GameState directly.
#
# Formation battles (Home, Away-Pillage, Away-Assault, Bandit Ambush):
#   unit_power = 5
#              + Strength
#              + Bravery
#              + relevant_skill            (slot-dependent; see _slot_skill)
#              + slot_bonus                (+2 if matched)
#              + leadership_buff           (+1 if Blue is filled by another unit)
# Intimidation reduces enemy power separately (sum of Intimidation/4 floor).
# Home rule: Defend = full, other tasks = 0.75× (floored).
# Ties go to the player.
#
# Tournament: unit_power = 10 + Str + Tec + max(Sword, Arch). No formation.

const SLOTS: Array[String] = ["blue", "green", "yellow", "red"]
const SLOT_LABELS: Dictionary = {
	"blue": "Blue (Camp Leader)",
	"green": "Green (Ranged)",
	"yellow": "Yellow (Heavy Melee)",
	"red": "Red (Light Melee)",
}

const SLOT_BONUS: int = 2
const LEADERSHIP_BUFF: int = 1
const HOME_NON_DEFEND_MULT: float = 0.75
const BASE_POWER: int = 5
const TOURNAMENT_BASE_POWER: int = 10


# ---------- enemy power (GDD §13) ----------

static func enemy_power_pillage(week: int) -> int:
	return 20 + week * 3


static func enemy_power_home(week: int) -> int:
	return 25 + week * 4


static func enemy_power_bandit_ambush(week: int) -> int:
	return 15 + week * 2


static func enemy_power_champion_duel(week: int) -> int:
	return 20 + week * 2


static func enemy_power_tournament(week: int) -> int:
	return 60 + Calendar.tournament_number(week) * 25


static func enemy_power_grand_tournament(week: int) -> int:
	return 200 + Calendar.run_year(week) * 50


# ---------- per-unit math ----------

# Skill stat the unit uses in `slot`. "" means unit is unassigned — fall back
# to max(Sword, Archery) per GDD §13.
static func _slot_skill(unit: Unit, slot: String) -> int:
	var s: Stats = unit.stats
	match slot:
		"blue": return maxi(s.swordsmanship, s.archery)
		"green": return s.archery
		"yellow": return s.swordsmanship
		"red": return s.swordsmanship
	return maxi(s.swordsmanship, s.archery)


# Slot-match rule (binary; GDD §12 "MVP simplification: no 1-slot-away rule").
# Picks broadly per the "Best Stats" column in the slot table.
static func is_slot_match(unit: Unit, slot: String) -> bool:
	var s: Stats = unit.stats
	match slot:
		"blue":
			return s.leadership >= 8 and s.bravery >= 8
		"green":
			return s.archery > s.swordsmanship
		"yellow":
			return s.swordsmanship >= s.archery and s.strength >= s.speed
		"red":
			return s.swordsmanship >= s.archery and s.speed >= s.strength
	return false


# `formation`: slot key → unit_id (-1 = empty). `participants` is the list of
# units actually fighting (e.g. away_party for Away weeks, all at-home for
# Home weeks). `home_battle`: applies the 0.75× non-Defend modifier per GDD §13.
#
# Returns:
#   {
#     "per_unit": [{unit_id, slot, base, str, bra, skill, slot_bonus,
#                   leadership_buff, raw, mult, total}],
#     "player_total": int,
#     "intimidation_reduction": int,
#     "enemy_power": int,
#     "enemy_after_intimidation": int,
#     "won": bool,
#   }
static func resolve_formation(
	participants: Array,           # Array[Unit]
	formation: Dictionary,
	enemy_power: int,
	home_battle: bool = false,
) -> Dictionary:
	# Resolve who is in which slot for quick lookup, and detect whether the
	# Blue slot is filled (drives the leadership buff for everyone else).
	var slot_for_unit: Dictionary = {}      # unit_id -> slot key
	for slot_key in SLOTS:
		var slotted_id: int = int(formation.get(slot_key, -1))
		if slotted_id >= 0:
			slot_for_unit[slotted_id] = slot_key
	var blue_unit_id: int = int(formation.get("blue", -1))
	var blue_filled: bool = blue_unit_id >= 0

	var per_unit: Array = []
	var player_total: int = 0
	var intimidation_total: int = 0

	for u in participants:
		var slot: String = slot_for_unit.get(u.id, "")
		var skill: int = _slot_skill(u, slot)
		var slot_bonus: int = SLOT_BONUS if slot != "" and is_slot_match(u, slot) else 0
		# Leadership buff: every unit EXCEPT the one in Blue gets +1 when Blue
		# is occupied. GDD §13 "the unit currently in the Blue slot does NOT
		# get this +1 (they're providing it, not receiving it)."
		var leadership: int = 0
		if blue_filled and u.id != blue_unit_id:
			leadership = LEADERSHIP_BUFF

		var raw: int = BASE_POWER + u.stats.strength + u.stats.bravery + skill + slot_bonus + leadership

		var mult: float = 1.0
		if home_battle and u.current_task != Unit.TASK_DEFEND:
			mult = HOME_NON_DEFEND_MULT
		var total: int = floori(float(raw) * mult)

		intimidation_total += u.stats.intimidation / 4   # GDD §13 — rounded down

		per_unit.append({
			"unit_id": u.id,
			"slot": slot,
			"base": BASE_POWER,
			"str": u.stats.strength,
			"bra": u.stats.bravery,
			"skill": skill,
			"slot_bonus": slot_bonus,
			"leadership_buff": leadership,
			"raw": raw,
			"mult": mult,
			"total": total,
		})
		player_total += total

	var enemy_after_intim: int = maxi(0, enemy_power - intimidation_total)
	return {
		"per_unit": per_unit,
		"player_total": player_total,
		"intimidation_reduction": intimidation_total,
		"enemy_power": enemy_power,
		"enemy_after_intimidation": enemy_after_intim,
		"won": player_total >= enemy_after_intim,        # ties to the player
	}


# Tournament resolution (no formation, no Leadership buff, no Intimidation).
#   unit_power = 10 + Str + Tec + max(Sword, Arch)
static func resolve_tournament(participants: Array, enemy_power: int) -> Dictionary:
	var per_unit: Array = []
	var total: int = 0
	for u in participants:
		var skill: int = maxi(u.stats.swordsmanship, u.stats.archery)
		var raw: int = TOURNAMENT_BASE_POWER + u.stats.strength + u.stats.technique + skill
		per_unit.append({
			"unit_id": u.id,
			"str": u.stats.strength,
			"tec": u.stats.technique,
			"skill": skill,
			"total": raw,
		})
		total += raw
	return {
		"per_unit": per_unit,
		"player_total": total,
		"enemy_power": enemy_power,
		"enemy_after_intimidation": enemy_power,    # tournaments ignore intimidation
		"intimidation_reduction": 0,
		"won": total >= enemy_power,
	}


# ---------- reward bundles (GDD §6 / §13) ----------

# Pillage reward roll. Per resource: int in [1 + floor(week/10), 3 + floor(week/5)].
static func roll_pillage_reward(week: int) -> ResourceBundle:
	var lo: int = 1 + week / 10
	var hi: int = 3 + week / 5
	var b := ResourceBundle.new()
	for key in ResourceBundle.KEYS:
		b.set(key, RNG.randi_range(lo, hi))
	return b


# Home Battle reward — "Small resource reward" (GDD §6). Placeholder bundle;
# tune in Phase 8 if needed.
static func roll_home_win_reward(_week: int) -> ResourceBundle:
	return ResourceBundle.new(2, 2, 1)


# Bandit Ambush loot — "small resource loot" (GDD §6).
static func roll_bandit_ambush_reward(_week: int) -> ResourceBundle:
	return ResourceBundle.new(1, 1, 1)


# Tournament reward modified by the highest Etiquette among participants
# (GDD §10 / §13). `reward × (1 + highest_Etiquette / 40)`.
static func roll_tournament_reward(_week: int, participants: Array) -> ResourceBundle:
	var base := ResourceBundle.new(3, 3, 2)
	var highest_etq: int = 0
	for u in participants:
		highest_etq = maxi(highest_etq, u.stats.etiquette)
	var factor: float = 1.0 + float(highest_etq) / 40.0
	return base.scaled(factor)
