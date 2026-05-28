class_name AwayModeDB
extends RefCounted

# Data-driven catalog of Away Mission variants — the riche r palette of
# things your knight can ride out to do beyond the original Pillage/Assault
# pair. Each entry is a self-contained data record: combat template
# (selects which enemy party EnemyDB rolls), reward shape, epithet tag,
# rep deltas, and the prose lines surfaced by Pre-Battle Review and the
# Planning Map tab.
#
# Pillage and Assault stay hard-coded in Resolution._resolve_away —
# they're the spine of the away flow and changing them touches castle
# capture, reward bundles, and the existing Map UI. New modes live here
# and route through Resolution._resolve_away_custom, which mirrors the
# pillage path's structure (combat sim → injuries → reward + epithet +
# item drop + rep) but reads its parameters from the entry.
#
# Reward kinds (each entry's "reward_kind" field):
#   "gold_and_bundle"   — gold_range + Dictionary bundle (ResourceDB ids)
#   "iron_haul"         — iron_ore inventory_add + optional plant_fibres
#   "rare_loot"         — gold_range + item_drop forced (bypasses chance roll)
#
# Adding a new variant is pure data: drop a key into MODES, choose a
# combat template, reward shape, epithet tag, and write a one-line label
# + intro. Min_week gates it so early-game weeks don't see endgame missions.

const MODES: Dictionary = {
	"rescue_merchant": {
		"label":            "🆘  Rescue a Captured Merchant",
		"glyph":            "🆘",
		"intro":            "A merchant of moderate worth was taken on the eastern track three days ago. His house pays for the return; his captors are bandits at best.",
		"min_week":         6,
		"combat_template":  "pillage",
		"reward_kind":      "gold_and_bundle",
		"gold_min":         18,
		"gold_max":         30,
		"bundle_lo":        1,
		"bundle_hi":        2,
		"item_drop_chance": 0.18,
		"item_drop_rarity": 1,    # Weapon/Armour.Rarity.UNCOMMON
		"rep_on_win":       3,
		"rep_on_loss":      -1,
		"epithet_tag":      "pillage_win",
		"map_tooltip":      "Easier than an assault, less crude than a pillage. The merchant's house pays well for him.",
	},
	"hunt_beast": {
		"label":            "🐺  Hunt a Forest Beast",
		"glyph":            "🐺",
		"intro":            "Three villages on the western edge have lost stock to something with teeth. A bounty has been pooled; the household marshal has been asked, politely, to oblige.",
		"min_week":         8,
		"combat_template":  "bandit_ambush",
		"reward_kind":      "iron_haul",
		"iron_min":         1,
		"iron_max":         3,
		"fibres_min":       2,
		"fibres_max":       4,
		"gold_min":         8,
		"gold_max":         18,
		"item_drop_chance": 0.12,
		"item_drop_rarity": 1,
		"rep_on_win":       2,
		"rep_on_loss":      0,
		"epithet_tag":      "pillage_win",
		"map_tooltip":      "Lighter combat than a pillage. The hide is worth the ride.",
	},
	"destroy_nest": {
		"label":            "🪺  Destroy a Monster Nest",
		"glyph":            "🪺",
		"intro":            "Outriders find the nest of something nobody wants to name. It will not stay small if left alone.",
		"min_week":         14,
		"combat_template":  "pillage",
		"reward_kind":      "iron_haul",
		"iron_min":         3,
		"iron_max":         6,
		"fibres_min":       1,
		"fibres_max":       2,
		"gold_min":         0,
		"gold_max":         0,
		"item_drop_chance": 0.28,
		"item_drop_rarity": 2,    # RARE
		"rep_on_win":       4,
		"rep_on_loss":      -1,
		"epithet_tag":      "assault_win",
		"map_tooltip":      "Tough combat. Big metal haul. Increased chance of a Rare item drop.",
	},
	"intercept_convoy": {
		"label":            "🚚  Intercept Enemy Supply Convoy",
		"glyph":            "🚚",
		"intro":            "A neighbouring lord's supply convoy crosses your knight's stretch of road on the third day. The convoy is escorted; not heavily, but enough to make a memory of it.",
		"min_week":         12,
		"combat_template":  "pillage",
		"reward_kind":      "gold_and_bundle",
		"gold_min":         24,
		"gold_max":         44,
		"bundle_lo":        2,
		"bundle_hi":        3,
		"item_drop_chance": 0.18,
		"item_drop_rarity": 1,
		"rep_on_win":       2,
		"rep_on_loss":      -1,
		"epithet_tag":      "pillage_win",
		"map_tooltip":      "Heavier purse than pillage. A neighbour will not forget it; balance the gold against the standing.",
	},
	"capture_scout_captain": {
		"label":            "🎯  Capture an Enemy Scout Captain",
		"glyph":            "🎯",
		"intro":            "Reports place an enemy scout captain on the outer track with a thin escort. Take him alive, and his maps come home with him.",
		"min_week":         10,
		"combat_template":  "bandit_ambush",
		"reward_kind":      "gold_and_bundle",
		"gold_min":         16,
		"gold_max":         28,
		"bundle_lo":        1,
		"bundle_hi":        2,
		"item_drop_chance": 0.16,
		"item_drop_rarity": 1,
		"rep_on_win":       2,
		"rep_on_loss":      0,
		"epithet_tag":      "pillage_win",
		"map_tooltip":      "Light escort, decent purse, useful information. The chronicler will read the captured maps with quiet pleasure.",
	},
	"explore_catacombs": {
		"label":            "⚱  Explore Ancient Catacombs",
		"glyph":            "⚱",
		"intro":            "Older stone under newer hill — a sealed catacomb half-flooded since the last reign. The chaplain insists on lanterns and silence; the marshal insists on a longer rope.",
		"min_week":         18,
		"combat_template":  "pillage",
		"reward_kind":      "gold_and_bundle",
		"gold_min":         10,
		"gold_max":         22,
		"bundle_lo":        1,
		"bundle_hi":        2,
		"item_drop_chance": 0.42,
		"item_drop_rarity": 2,
		"rep_on_win":       3,
		"rep_on_loss":      -1,
		"epithet_tag":      "assault_win",
		"map_tooltip":      "Hard combat. Smaller purse than a convoy but the best odds of a Rare item drop outside the lists.",
	},
	"raid_cultist_site": {
		"label":            "🕯  Raid a Cultist Ritual Site",
		"glyph":            "🕯",
		"intro":            "A clearing has lights it should not, on a night the chaplain will not name. Their host expects no interruption.",
		"min_week":         18,
		"combat_template":  "pillage",
		"reward_kind":      "gold_and_bundle",
		"gold_min":         22,
		"gold_max":         38,
		"bundle_lo":        2,
		"bundle_hi":        3,
		"item_drop_chance": 0.22,
		"item_drop_rarity": 2,
		"rep_on_win":       5,
		"rep_on_loss":      -2,
		"epithet_tag":      "assault_win",
		"map_tooltip":      "Hard combat. Standing soars on a win; falls further on a loss. The chronicler will write the ballad either way.",
	},
	"investigate_meteor": {
		"label":            "☄  Investigate a Fallen Meteor",
		"glyph":            "☄",
		"intro":            "A streak across the night sky, a crater on the western moor, and a low ringing audible only to the dogs. The chronicler insists.",
		"min_week":         22,
		"combat_template":  "bandit_ambush",
		"reward_kind":      "iron_haul",
		"iron_min":         4,
		"iron_max":         7,
		"fibres_min":       0,
		"fibres_max":       1,
		"gold_min":         4,
		"gold_max":         10,
		"item_drop_chance": 0.35,
		"item_drop_rarity": 2,
		"rep_on_win":       3,
		"rep_on_loss":      0,
		"epithet_tag":      "pillage_win",
		"map_tooltip":      "Lighter combat than expected. Big metal haul from the strike. Good odds on a Rare item; the chronicler is half-mad with anticipation.",
	},
	"hunt_rogue_mage": {
		"label":            "🔮  Hunt a Rogue Mage",
		"glyph":            "🔮",
		"intro":            "A village headman writes the household: a hedge-witch has gone too far. The neighbouring lord will not act; he asks if your knight will.",
		"min_week":         14,
		"combat_template":  "bandit_ambush",
		"reward_kind":      "gold_and_bundle",
		"gold_min":         18,
		"gold_max":         30,
		"bundle_lo":        1,
		"bundle_hi":        2,
		"item_drop_chance": 0.28,
		"item_drop_rarity": 2,
		"rep_on_win":       4,
		"rep_on_loss":      -2,
		"epithet_tag":      "assault_win",
		"map_tooltip":      "Single dangerous target. Big rep on the win — the realm notices a knight who handles what neighbouring lords will not.",
	},
	"escort_diplomat": {
		"label":            "📜  Escort a Diplomat",
		"glyph":            "📜",
		"intro":            "A herald in a friendly house's colours rides for the gate at speed: their diplomat needs an armed escort to the next county. Today.",
		"min_week":         8,
		"combat_template":  "pillage",
		"reward_kind":      "gold_and_bundle",
		"gold_min":         22,
		"gold_max":         36,
		"bundle_lo":        1,
		"bundle_hi":        2,
		"item_drop_chance": 0.14,
		"item_drop_rarity": 1,
		"rep_on_win":       3,
		"rep_on_loss":      -2,
		"epithet_tag":      "pillage_win",
		"map_tooltip":      "Decent purse + standing for hosting the friendly house's interest. Combat varies — sometimes nothing, sometimes a road ambush.",
	},
}


static func has_mode(id: String) -> bool:
	return MODES.has(id)


static func label_for(id: String) -> String:
	return str(MODES.get(id, {}).get("label", "Away Mission"))


static func intro_for(id: String) -> String:
	return str(MODES.get(id, {}).get("intro", ""))


static func tooltip_for(id: String) -> String:
	return str(MODES.get(id, {}).get("map_tooltip", ""))


# Returns mode ids unlocked at the given week, ordered as defined in MODES
# (Dictionary preserves insertion order in GDScript 4). Planning's Map tab
# uses this to render a row of buttons gated by min_week.
static func available_at_week(week: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in MODES:
		var entry: Dictionary = MODES[id]
		if week >= int(entry.get("min_week", 0)):
			out.append(id)
	return out
