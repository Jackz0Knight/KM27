class_name BattleEvent
extends RefCounted

# Phase 6 Battle Event sub-types per GDD §6. The weekly EventRoller picks
# BATTLE_EVENT; this helper then picks which of the four templates fires.
# All sub-type rolls flow through the RNG autoload for determinism.
#
# Sub-type ids are kept as kebab-case strings so they round-trip through
# GameState.current_battle_event cleanly (Resource serialisation safe).

const SUB_TYPES: PackedStringArray = PackedStringArray([
	"bandit_ambush",
	"champion_duel",
	"bountiful_harvest",
	"merchant_caravan",
])


static func roll_sub_type() -> String:
	return SUB_TYPES[RNG.randi_range(0, SUB_TYPES.size() - 1)]


static func label(sub_type: String) -> String:
	match sub_type:
		"bandit_ambush": return "Bandit Ambush"
		"champion_duel": return "Travelling Champion's Duel"
		"bountiful_harvest": return "Bountiful Harvest"
		"merchant_caravan": return "Merchant Caravan"
	return "Battle Event"


static func is_combat(sub_type: String) -> bool:
	return sub_type == "bandit_ambush" or sub_type == "champion_duel"


# ---------- non-combat rewards ----------

# Bountiful Harvest — small bundle delivered automatically (GDD §6).
static func roll_harvest_bundle(week: int) -> ResourceBundle:
	# Bountiful Harvest is comfortably "T1 bundle" sized — slightly skewed up
	# from a Bandit Ambush win because it has no risk.
	var lo: int = 1 + week / 12
	var hi: int = 3 + week / 8
	var b := ResourceBundle.new()
	for key in ResourceBundle.KEYS:
		b.set(key, RNG.randi_range(lo, hi))
	return b


# Merchant Caravan offer — 3 small bundles the player picks from on the
# Weekly Summary screen.
static func roll_caravan_offers(week: int, count: int = 3) -> Array:
	var offers: Array = []
	for i in range(count):
		offers.append(_roll_caravan_offer(week))
	return offers


static func _roll_caravan_offer(week: int) -> ResourceBundle:
	# Each offer biases heavily toward one resource so the choice matters.
	var primary_idx: int = RNG.randi_range(0, ResourceBundle.KEYS.size() - 1)
	var lo_primary: int = 2 + week / 10
	var hi_primary: int = 4 + week / 6
	var lo_secondary: int = 0
	var hi_secondary: int = 1 + week / 15
	var b := ResourceBundle.new()
	for i in range(ResourceBundle.KEYS.size()):
		var key: String = ResourceBundle.KEYS[i]
		if i == primary_idx:
			b.set(key, RNG.randi_range(lo_primary, hi_primary))
		else:
			b.set(key, RNG.randi_range(lo_secondary, hi_secondary))
	return b


# ---------- Champion's Duel ----------

# Single-unit check: unit_power = Strength + Bravery + Swordsmanship vs
# enemy = 20 + week × 2 (GDD §6 / §13). Ties go to the player.
# Returns:
#   {"player_power": int, "enemy_power": int, "won": bool, "unit_id": int}
static func resolve_champion_duel(unit: Unit, week: int) -> Dictionary:
	var enemy: int = Combat.enemy_power_champion_duel(week)
	var power: int = unit.stats.strength + unit.stats.bravery + unit.stats.swordsmanship
	return {
		"unit_id": unit.id,
		"player_power": power,
		"enemy_power": enemy,
		"won": power >= enemy,
	}
