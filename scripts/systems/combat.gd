class_name Combat
extends RefCounted

# Strategy-layer combat math. Pure functions — Combat doesn't read GameState.
#
# Formation battles resolve through CombatSim on CombatUnits; the old
# strategy-layer formula (resolve_formation) was retired 2026-06-12 once its
# last caller (the formation editor preview) repointed at CombatSim.analyze.
# What remains here:
#   • enemy power curves (tournament / duel use them; EnemyDB scales parties)
#   • is_slot_match — slot-fitness markers (editor ★, oath fallback)
#   • tournament resolution — deterministic totals, no sim, no formation:
#       unit_power = 10 + Str + Tec + max(Sword, Arch) + tournament-legal kit
#   • reward-table wrappers

const SLOTS: Array[String] = ["blue", "green", "yellow", "red"]
const SLOT_LABELS: Dictionary = {
	"blue": "Blue (Camp Leader)",
	"green": "Green (Ranged)",
	"yellow": "Yellow (Heavy Melee)",
	"red": "Red (Light Melee)",
}

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


# ---------- slot fitness ----------

# Slot-match rule (binary; GDD §12 "MVP simplification: no 1-slot-away rule").
# Picks broadly per the "Best Stats" column in the slot table. Drives the
# editor's ★ markers and the oath ledger's slot-oath fallback. Has no combat
# effect yet — slot effects enter the sim in plan step 3 (CLAUDE.md).
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
