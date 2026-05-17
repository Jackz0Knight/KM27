class_name HousePool
extends RefCounted

# Four archetypal noble houses. A unit's house biases their stat roll (per
# `lean_plus` / `lean_minus`) without changing the cap or the rough sum, and
# drives the visual banner rendered by `BannerIcon`. House identity is rolled
# at unit creation by `RosterGenerator`.
#
# Design intent (locked 2026-05-17):
#   • 4 houses, one per fantasy archetype (warrior / scholar / scout / cavalier).
#   • Leans are IMPLICIT — motto and origin hint at them; no stat-tag chips,
#     no tooltip on the crest. Players learn by playing.
#   • Net stat budget stays roughly constant — +1 on each preferred stat is
#     paid for by -1 on the discouraged stats.
#
# Heraldry encoding for BannerIcon:
#   field          → background tincture
#   accent         → outline / detail tincture
#   ordinary       → one of: "pale" | "chevron" | "bend" | "saltire"
#   ordinary_color → tincture for the ordinary band
#   charge         → one of: "swords" | "book" | "arrow" | "horseshoe"
#   charge_color   → tincture for the charge

const HOUSES: Dictionary = {
	"brann": {
		"name": "House Brann",
		"motto": "Steel before words.",
		"archetype": "warrior",
		"field": Color(0.55, 0.10, 0.12),         # deep crimson
		"accent": Color(0.08, 0.06, 0.06),        # black
		"ordinary": "pale",
		"ordinary_color": Color(0.10, 0.08, 0.08),
		"charge": "swords",
		"charge_color": Color(0.90, 0.80, 0.35),  # gold
		"lean_plus": ["strength", "swordsmanship", "bravery"],
		"lean_minus": ["etiquette", "technique"],
	},
	"aldermere": {
		"name": "House Aldermere",
		"motto": "By measure and by mind.",
		"archetype": "scholar",
		"field": Color(0.12, 0.20, 0.50),         # deep blue
		"accent": Color(0.85, 0.85, 0.90),        # silver
		"ordinary": "chevron",
		"ordinary_color": Color(0.85, 0.85, 0.90),
		"charge": "book",
		"charge_color": Color(0.95, 0.92, 0.78),  # parchment
		"lean_plus": ["etiquette", "leadership", "loyalty"],
		"lean_minus": ["strength", "intimidation"],
	},
	"daven": {
		"name": "House Daven",
		"motto": "First to the tide.",
		"archetype": "scout",
		"field": Color(0.18, 0.45, 0.40),         # sea green
		"accent": Color(0.90, 0.88, 0.78),        # bone
		"ordinary": "bend",
		"ordinary_color": Color(0.90, 0.88, 0.78),
		"charge": "arrow",
		"charge_color": Color(0.10, 0.25, 0.30),  # dark teal
		"lean_plus": ["speed", "archery", "technique"],
		"lean_minus": ["bravery", "leadership"],
	},
	"faldur": {
		"name": "House Faldur",
		"motto": "Higher than the throne.",
		"archetype": "cavalier",
		"field": Color(0.18, 0.32, 0.18),         # forest green
		"accent": Color(0.70, 0.50, 0.20),        # ochre
		"ordinary": "saltire",
		"ordinary_color": Color(0.70, 0.50, 0.20),
		"charge": "horseshoe",
		"charge_color": Color(0.95, 0.90, 0.78),  # bone
		"lean_plus": ["horsemanship", "bravery", "leadership"],
		"lean_minus": ["archery", "determination"],
	},
}

const HOUSE_IDS: Array[String] = ["brann", "aldermere", "daven", "faldur"]


static func random_house_id() -> String:
	return HOUSE_IDS[RNG.randi_range(0, HOUSE_IDS.size() - 1)]


static func get_house(house_id: String) -> Dictionary:
	return HOUSES.get(house_id, {})


static func name_for(house_id: String) -> String:
	var h: Dictionary = HOUSES.get(house_id, {})
	return h.get("name", "")


static func motto_for(house_id: String) -> String:
	var h: Dictionary = HOUSES.get(house_id, {})
	return h.get("motto", "")


static func archetype_for(house_id: String) -> String:
	var h: Dictionary = HOUSES.get(house_id, {})
	return h.get("archetype", "")


# Apply the house's stat lean as a +/- to the rolled stat block, clamped to
# the legal range. Net change to the sum is small (typically +1 to +3 over
# -1 to -2), so the player's effective stat budget shifts more than it grows.
static func apply_lean(stats: Stats, house_id: String, stat_max: int) -> void:
	var h: Dictionary = HOUSES.get(house_id, {})
	if h.is_empty():
		return
	for stat in h.get("lean_plus", []):
		var key: String = str(stat)
		var v: int = stats.get_value(key)
		stats.set_value(key, clampi(v + 1, 1, stat_max))
	for stat in h.get("lean_minus", []):
		var key: String = str(stat)
		var v: int = stats.get_value(key)
		stats.set_value(key, clampi(v - 1, 1, stat_max))
