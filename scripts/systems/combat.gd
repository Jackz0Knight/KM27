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

# Strategy-layer weapon contribution to unit_power. Folds the catalogue
# damage range into a single number so modifiers shift damage_min/max in the
# catalogue and the formula re-derives — one source of truth. Replaces the
# old flat `weapon_power_rating` axis per GDD §18.3. Combat-sim layer (the
# per-hit roll, when it lands) still uses damage_min/max directly.
static func weapon_damage_contrib(weapon_id: String) -> int:
	var entry: Dictionary = Weapon.CATALOGUE.get(weapon_id, {})
	if entry.is_empty():
		return 0
	var dmin: int = int(entry.get("damage_min", 0))
	var dmax: int = int(entry.get("damage_max", 0))
	return floori(float(dmin + dmax) / 2.0)


# Strategy-layer armour contribution. Subtracted from enemy power per defender
# (sum across the party), mirroring Intimidation. Net mathematical effect on
# the win comparison is identical to the old `+armour_power_rating` on
# player_total, so balance on the armour axis is preserved when this PR
# lands — only the weapon axis shifts. Re-uses Armour.power_rating (0–4)
# as the resistance value rather than introducing a parallel field today.
static func armour_resistance(armour_id: String) -> int:
	return Armour.power_rating(armour_id)


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
	var armour_total: int = 0

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

		# Equipment contribution — per GDD §18.3 the strategy layer folds weapon
		# damage into unit_power (replacing the old flat `power_rating` axis) and
		# treats armour as resistance that subtracts from enemy power, mirroring
		# Intimidation. Mathematically equivalent net effect to the old `+armour`
		# on player_total, so balance is preserved on the armour axis; weapon
		# contribution shifts heavier — Phase 8 retunes enemy multipliers.
		var weapon_dmg: int = weapon_damage_contrib(u.weapon_id)
		var armour_res: int = armour_resistance(u.armour_id)

		var raw: int = BASE_POWER + u.stats.strength + u.stats.bravery + skill + slot_bonus + leadership + weapon_dmg

		var mult: float = 1.0
		if home_battle and u.current_task != Unit.TASK_DEFEND:
			mult = HOME_NON_DEFEND_MULT
		var total: int = floori(float(raw) * mult)

		intimidation_total += floori(u.stats.intimidation / 4.0)   # GDD §13 — rounded down
		armour_total += armour_res

		per_unit.append({
			"unit_id": u.id,
			"slot": slot,
			"base": BASE_POWER,
			"str": u.stats.strength,
			"bra": u.stats.bravery,
			"skill": skill,
			"slot_bonus": slot_bonus,
			"leadership_buff": leadership,
			"weapon_damage": weapon_dmg,
			"armour_resistance": armour_res,
			"raw": raw,
			"mult": mult,
			"total": total,
		})
		player_total += total

	var enemy_after_intim: int = maxi(0, enemy_power - intimidation_total)
	var enemy_after_armour: int = maxi(0, enemy_after_intim - armour_total)
	return {
		"per_unit": per_unit,
		"player_total": player_total,
		"intimidation_reduction": intimidation_total,
		"armour_reduction": armour_total,
		"enemy_power": enemy_power,
		"enemy_after_intimidation": enemy_after_intim,
		"enemy_after_armour": enemy_after_armour,
		"won": player_total >= enemy_after_armour,       # ties to the player
	}


# Named helper so the UI and resolve_tournament() share exactly one formula.
# Tournament rules forbid the war pick and the crossbow — equipment bonus only
# applies if the unit's weapon is tournament-legal. Armour bonus always counts;
# the lists are about steel and skill, not who wore plate to the rope.
static func tournament_unit_power(unit: Unit) -> int:
	var base: int = TOURNAMENT_BASE_POWER + unit.stats.strength + unit.stats.technique + maxi(unit.stats.swordsmanship, unit.stats.archery)
	var weapon_power: int = Weapon.power_rating(unit.weapon_id) if _is_tournament_legal(unit.weapon_id) else 0
	var armour_power: int = Armour.power_rating(unit.armour_id)
	return base + weapon_power + armour_power


# Banned in tournaments by historical convention — the war pick punches plate,
# the crossbow ignores skill. Players can still field knights kitted with them
# in normal weeks; they simply don't gain the kit bonus on tournament week.
static func _is_tournament_legal(weapon_id: String) -> bool:
	return weapon_id != "war_pick" and weapon_id != "crossbow"


# Tournament resolution (no formation, no Leadership buff, no Intimidation).
#   unit_power = 10 + Str + Tec + max(Sword, Arch) + tournament-legal kit
static func resolve_tournament(participants: Array, enemy_power: int) -> Dictionary:
	var per_unit: Array = []
	var total: int = 0
	for u in participants:
		var raw: int = tournament_unit_power(u)
		var weapon_power: int = Weapon.power_rating(u.weapon_id) if _is_tournament_legal(u.weapon_id) else 0
		per_unit.append({
			"unit_id": u.id,
			"str": u.stats.strength,
			"tec": u.stats.technique,
			"skill": maxi(u.stats.swordsmanship, u.stats.archery),
			"weapon_power": weapon_power,
			"armour_power": Armour.power_rating(u.armour_id),
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
#
# Every roller now returns a Dictionary keyed by ResourceDB ids. The size,
# distribution, and week-scaling all live on the corresponding RewardTableDB
# entry — these functions are thin wrappers that name the table + the
# per-event difficulty multiplier, so retuning is one number on one entry.

# Pillage reward roll — wilderness loot, baseline difficulty.
static func roll_pillage_reward(week: int) -> Dictionary:
	return RewardTableDB.roll("wilderness_loot", week, 1.0)


# Home Battle reward — smaller homestead-flavoured bundle.
static func roll_home_win_reward(week: int) -> Dictionary:
	return RewardTableDB.roll("homestead_defence", week, 1.0)


# Bandit Ambush loot — small consolation bundle.
static func roll_bandit_ambush_reward(week: int) -> Dictionary:
	return RewardTableDB.roll("bandit_pouch", week, 1.0)


# Tournament reward modified by the highest Etiquette among participants
# (GDD §10 / §13). Difficulty multiplier folds the Etiquette factor
# (`1 + highest_Etq / 40`) and the tournament-number scalar (so a Grand
# Tournament prize scales above a regular).
static func roll_tournament_reward(week: int, participants: Array) -> Dictionary:
	var highest_etq: int = 0
	for u in participants:
		highest_etq = maxi(highest_etq, u.stats.etiquette)
	var etq_factor: float = 1.0 + float(highest_etq) / 40.0
	# Tournament number adds a modest progression on top of the table's
	# internal week scaling (1.0 at the first tournament, ~1.5 by Grand).
	var tour_factor: float = 1.0 + float(Calendar.tournament_number(week)) * 0.15
	return RewardTableDB.roll("tournament_prize", week, etq_factor * tour_factor)
