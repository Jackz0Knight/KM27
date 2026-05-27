class_name CombatEventDB
extends RefCounted

# Data-driven catalog of combat-side BattleEvent sub-types. Pillage / Assault
# are AwayModeDB (player-picked); the entries here are battle-event combat
# rolls (the home-side cousin of away missions — bandit_ambush, village_raid,
# tavern_riot land in this slot in `BattleEvent.SUB_TYPES`).
#
# Adding a new combat sub-type is one entry + a SUB_TYPES line. The dispatcher
# (`Resolution._resolve_combat_event`) reads combat_template, reward_kind,
# epithet_tag, item_drop_fn, and rep deltas off the entry and assembles the
# same flow the hard-coded resolvers use:
#
#   party check → no-defender branch → CombatSim → injuries → win-branch
#   (reward + survival epithets + WON loop + item drop + rep) / loss-branch
#
# Existing hard-coded resolvers (`_resolve_bandit_ambush`,
# `_resolve_village_raid`, `_resolve_tavern_riot`) are deliberately NOT
# migrated yet — they keep their bit-for-bit behaviour. Migration is pure
# data work, deferred until the framework has shipped a few more entries
# and the pattern is stable.
#
# Reward kinds the dispatcher knows:
#   "bandit_bundle"   → Combat.roll_bandit_ambush_reward(week) → reward bundle
#   "home_bundle"     → Combat.roll_home_win_reward(week)
#   "gold_and_bundle" → gold_range + ResourceBundle (bundle_lo / bundle_hi)
#   "gold_only"       → gold_range, no bundle
#
# Item drop kinds:
#   "ambush"        → ItemDrops.roll_ambush_drop(gs)
#   "home_defence"  → ItemDrops.roll_home_defence_drop(gs)
#   "rare_biased"   → ItemDrops.drop_at_rarity(gs, RARE) with chance roll
#   "none"          → no drop

const EVENTS: Dictionary = {
	"harpy_raid": {
		"label":            "A Harpy Raid",
		"intro_set":        "A flight of shrieks at the third hour — harpies on the wall, harpies in the courtyard.",
		"intro_no_defender": "No one home — by morning the storerooms are half-emptied through the open shutter.",
		"combat_template":  "home_battle",
		"reward_kind":      "home_bundle",
		"item_drop_fn":     "home_defence",
		"epithet_tag":      "home_battle_won",
		"rep_on_win":       4,
		"rep_on_loss":      -2,
		"rep_on_no_defender": -2,
		"min_week":         14,
		"flavour_text":     "Old menace. They were thought hunted out of these hills. They were not.",
		"tactics_advice":   "Use Defense formation — a night raid, all hands needed.",
		"stakes":           "Win → home bundle + +4 reputation. Loss → −2 reputation, no reward.",
	},

	"goblin_warband": {
		"label":            "A Goblin Warband",
		"intro_set":        "A larger goblin company than the marches usually produce camps within striking distance of the household.",
		"intro_no_defender": "No defenders — by dawn the warband has taken what it wanted and moved on.",
		"combat_template":  "pillage",
		"reward_kind":      "bandit_bundle",
		"item_drop_fn":     "ambush",
		"epithet_tag":      "home_battle_won",
		"rep_on_win":       2,
		"rep_on_loss":      -1,
		"rep_on_no_defender": -1,
		"min_week":         8,
		"flavour_text":     "Numbers compensate for what individual goblins lack. Hold the line; do not let them flank.",
		"tactics_advice":   "Use Defense formation — a larger band than usual, take it seriously.",
		"stakes":           "Win → bandit bundle + +2 reputation. Loss → −1 reputation.",
	},

	"cultist_incursion": {
		"label":            "A Cultist Incursion",
		"intro_set":        "Robed figures move on the household before dawn — small numbers, careful weapons, intent that has nothing to do with theft.",
		"intro_no_defender": "No one home — by morning the chapel post bears a mark the chaplain refuses to translate.",
		"combat_template":  "pillage",
		"reward_kind":      "gold_and_bundle",
		"gold_min":         8,
		"gold_max":         18,
		"bundle_lo":        1,
		"bundle_hi":        2,
		"item_drop_fn":     "rare_biased",
		"item_drop_chance": 0.35,
		"epithet_tag":      "home_battle_won",
		"rep_on_win":       3,
		"rep_on_loss":      -2,
		"rep_on_no_defender": -2,
		"min_week":         18,
		"flavour_text":     "Cultists in your stretch of the marches. The chaplain insists on a blessing for every defender.",
		"tactics_advice":   "Use Defense formation — careful weapons, careful intent. Hold the line.",
		"stakes":           "Win → gold purse + bundle + 35% Rare item drop + +3 reputation. Loss → −2 reputation.",
	},

	"midnight_skirmish": {
		"label":            "A Midnight Skirmish",
		"intro_set":        "A small enemy force has crossed the boundary stones — twenty riders by the watch's count, no banner, no warning.",
		"intro_no_defender": "No one home — the riders pass through, light a roof, and ride on by dawn.",
		"combat_template":  "bandit_ambush",
		"reward_kind":      "gold_and_bundle",
		"gold_min":         12,
		"gold_max":         22,
		"bundle_lo":        1,
		"bundle_hi":        2,
		"item_drop_fn":     "ambush",
		"epithet_tag":      "home_battle_won",
		"rep_on_win":       2,
		"rep_on_loss":      -1,
		"rep_on_no_defender": -2,
		"min_week":         10,
		"flavour_text":     "Riders without colours — bandits or worse, hard to tell at this hour.",
		"tactics_advice":   "Use Defense formation — a small contact, but no warning means little time to set the field.",
		"stakes":           "Win → gold purse + bundle + Uncommon item chance + +2 reputation. Loss → −1 reputation.",
	},

	"ogre_in_the_hills": {
		"label":            "An Ogre in the Hills",
		"intro_set":        "Three shepherds in the last week have come to the gate with the same story, told in the same uneasy voice.",
		"intro_no_defender": "No one home — the shepherds will not return to the upland pasture until autumn.",
		"combat_template":  "home_battle",
		"reward_kind":      "home_bundle",
		"item_drop_fn":     "rare_biased",
		"item_drop_chance": 0.30,
		"epithet_tag":      "assault_win",
		"rep_on_win":       5,
		"rep_on_loss":      -3,
		"rep_on_no_defender": -2,
		"min_week":         20,
		"flavour_text":     "An ogre, or a creature near enough that the distinction is academic. It has thinned a herd already.",
		"tactics_advice":   "Use Attack formation — a single hard target, hit it together.",
		"stakes":           "Win → home bundle + 30% Rare item drop + +5 reputation. Loss → −3 reputation.",
	},
}


static func has_mode(id: String) -> bool:
	return EVENTS.has(id)


static func label_for(id: String) -> String:
	return str(EVENTS.get(id, {}).get("label", "Battle Event"))


static func intro_for(id: String) -> String:
	return str(EVENTS.get(id, {}).get("intro_set", ""))


static func flavour_text_for(id: String) -> String:
	return str(EVENTS.get(id, {}).get("flavour_text", ""))


static func tactics_advice_for(id: String) -> String:
	return str(EVENTS.get(id, {}).get("tactics_advice", ""))


static func stakes_text_for(id: String) -> String:
	return str(EVENTS.get(id, {}).get("stakes", ""))


# Enemy power for the displayed forecast — matches the combat_template the
# resolver will actually use. Used by Pre-Battle Review's _battle_enemy_power.
static func enemy_power_for(id: String, week: int) -> int:
	var template: String = str(EVENTS.get(id, {}).get("combat_template", "pillage"))
	match template:
		"bandit_ambush": return Combat.enemy_power_bandit_ambush(week)
		"home_battle":   return Combat.enemy_power_home(week)
	return Combat.enemy_power_pillage(week)


# Forecast event key — what CombatSim's preview party should be rolled
# against on the Pre-Battle Review's win-probability gauge.
static func forecast_event_key_for(id: String) -> String:
	return str(EVENTS.get(id, {}).get("combat_template", "pillage"))


# Returns the ids eligible at the given week. Used by `BattleEvent` to
# include / exclude them from the roll pool.
static func available_at_week(week: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in EVENTS:
		var entry: Dictionary = EVENTS[id]
		if week >= int(entry.get("min_week", 0)):
			out.append(id)
	return out
