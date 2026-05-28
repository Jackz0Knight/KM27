class_name BattleEvent
extends RefCounted

# Phase 6 Battle Event sub-types per GDD §6. The weekly EventRoller picks
# BATTLE_EVENT; this helper then picks which of the four templates fires.
# All sub-type rolls flow through the RNG autoload for determinism.
#
# Sub-type ids are kept as kebab-case strings so they round-trip through
# GameState.current_battle_event cleanly (Resource serialisation safe).

const SUB_TYPES: Array[String] = [
	"bandit_ambush",
	"champion_duel",
	"bountiful_harvest",
	"merchant_caravan",
	"refugee_caravan",
	"noble_petition",
	"village_raid",
	"tavern_riot",
]

# Weight pool used by roll_sub_type. "story_event" is a gateway entry —
# when it wins the roll, we defer to StoryEventDB to pick a specific story.
# "combat_event" is the same idea for CombatEventDB. Both gateways may
# fall back to a hard-coded sub-type if no entry is eligible at the
# current week.
const ROLL_POOL: Array[String] = [
	"bandit_ambush",
	"champion_duel",
	"bountiful_harvest",
	"merchant_caravan",
	"refugee_caravan",
	"noble_petition",
	"village_raid",
	"tavern_riot",
	"story_event",
	"story_event",
	"story_event",
	"combat_event",
	"combat_event",
]


# Picks the sub-type for this week's Battle Event. When the roll lands on
# the "story_event" gateway, defer to StoryEventDB for a specific story id
# (gated by min_week / min_gold / min_roster_at_home in the story entry).
# "combat_event" works the same way for CombatEventDB. If no entry is
# eligible at the current week, falls back to a random hard-coded sub-type
# so the week still produces something.
static func roll_sub_type(gs: Node = null) -> String:
	var picked: String = ROLL_POOL[RNG.randi_range(0, ROLL_POOL.size() - 1)]
	if picked == "story_event":
		if gs == null:
			return SUB_TYPES[RNG.randi_range(0, SUB_TYPES.size() - 1)]
		var story_id: String = StoryEventDB.roll_event_id(gs)
		if story_id == "":
			return SUB_TYPES[RNG.randi_range(0, SUB_TYPES.size() - 1)]
		return StoryEventDB.STORY_PREFIX + story_id
	if picked == "combat_event":
		if gs == null:
			return SUB_TYPES[RNG.randi_range(0, SUB_TYPES.size() - 1)]
		var ids: Array[String] = CombatEventDB.available_at_week(gs.week)
		if ids.is_empty():
			return SUB_TYPES[RNG.randi_range(0, SUB_TYPES.size() - 1)]
		return ids[RNG.randi_range(0, ids.size() - 1)]
	return picked


static func label(sub_type: String) -> String:
	if StoryEventDB.is_story_sub_type(sub_type):
		return StoryEventDB.label_for(StoryEventDB.story_id_from_sub_type(sub_type))
	if CombatEventDB.has_mode(sub_type):
		return CombatEventDB.label_for(sub_type)
	match sub_type:
		"bandit_ambush": return "Bandit Ambush"
		"champion_duel": return "Travelling Champion's Duel"
		"bountiful_harvest": return "Bountiful Harvest"
		"merchant_caravan": return "Merchant Caravan"
		"refugee_caravan": return "Refugees at the Gate"
		"noble_petition": return "A Noble's Petition"
		"village_raid": return "A Village Under Attack"
		"tavern_riot": return "A Tavern Riot"
	return "Battle Event"


static func is_combat(sub_type: String) -> bool:
	if CombatEventDB.has_mode(sub_type):
		return true
	return (
		sub_type == "bandit_ambush"
		or sub_type == "champion_duel"
		or sub_type == "village_raid"
		or sub_type == "tavern_riot"
	)


# ---------- non-combat rewards ----------

# Bountiful Harvest — small bundle delivered automatically (GDD §6).
# Routes through RewardTableDB so the harvest curve is one table entry.
static func roll_harvest_bundle(week: int) -> Dictionary:
	return RewardTableDB.roll("harvest", week, 1.0)


# Merchant Caravan offer — 3 small bundles the player picks from on the
# Weekly Summary screen. Each offer is an independent roll of the caravan
# table so they vary in composition without explicit "biasing" logic.
static func roll_caravan_offers(week: int, count: int = 3) -> Array:
	var offers: Array = []
	for i in range(count):
		offers.append(RewardTableDB.roll("caravan_offer", week, 1.0))
	return offers


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
