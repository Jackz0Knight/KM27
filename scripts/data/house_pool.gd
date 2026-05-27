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


# Per-run lean randomisation pools, keyed by archetype. Each run, GameState
# rolls 3 stats from the archetype's plus pool and 2 from its minus pool;
# the picks override the static `lean_plus` / `lean_minus` on `HOUSES` for
# the duration of the run. The pools are intentionally consonant with the
# archetype so any picked subset still feels right — Brann always reads
# warrior, Aldermere always reads scholar, even if their specific stat
# distribution shifts run-to-run. The static lean_plus/lean_minus on
# `HOUSES` remain as the "default" pick — used when no per-run leans have
# been rolled (e.g., on a save loaded before this system, or in dev tools).
const LEAN_PLUS_POOL_BY_ARCHETYPE: Dictionary = {
	"warrior":  ["strength", "swordsmanship", "bravery", "intimidation", "determination"],
	"scholar":  ["etiquette", "leadership", "loyalty", "technique", "determination"],
	"scout":    ["speed", "archery", "technique", "horsemanship", "intimidation"],
	"cavalier": ["horsemanship", "bravery", "leadership", "swordsmanship", "etiquette"],
}
const LEAN_MINUS_POOL_BY_ARCHETYPE: Dictionary = {
	"warrior":  ["etiquette", "technique", "leadership", "archery"],
	"scholar":  ["strength", "intimidation", "swordsmanship", "speed"],
	"scout":    ["bravery", "leadership", "strength", "etiquette"],
	"cavalier": ["archery", "determination", "technique", "intimidation"],
}
const PLUS_PICKS: int = 3
const MINUS_PICKS: int = 2


static func random_house_id() -> String:
	return HOUSE_IDS[RNG.randi_range(0, HOUSE_IDS.size() - 1)]


# Roll a per-run leans dictionary: {house_id: {plus: Array[String], minus:
# Array[String]}}. Called from GameState.start_run() so every run gets a
# fresh slant — your Brann knights might feel intimidation-heavy this run
# and bravery-leaning the next, while always reading as a warrior house.
# Returns a fresh dict; static defaults on HOUSES are never mutated.
static func roll_per_run_leans() -> Dictionary:
	var out: Dictionary = {}
	for house_id in HOUSE_IDS:
		var archetype: String = str(HOUSES[house_id].get("archetype", ""))
		out[house_id] = {
			"plus":  _pick_n(LEAN_PLUS_POOL_BY_ARCHETYPE.get(archetype, []), PLUS_PICKS),
			"minus": _pick_n(LEAN_MINUS_POOL_BY_ARCHETYPE.get(archetype, []), MINUS_PICKS),
		}
	return out


# Without-replacement pick of n entries from `pool`. Caps at pool size if
# pool is shorter than n.
static func _pick_n(pool: Array, n: int) -> Array[String]:
	var available: Array[String] = []
	for s in pool:
		available.append(str(s))
	var out: Array[String] = []
	var picks: int = mini(n, available.size())
	for _i in range(picks):
		var idx: int = RNG.randi_range(0, available.size() - 1)
		out.append(available[idx])
		available.remove_at(idx)
	return out


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
#
# When `per_run_leans` is non-empty, the picks for this house override the
# static HOUSES.lean_plus / lean_minus arrays — that's how per-run slant
# randomisation lands. When per_run_leans is empty (legacy callers,
# pre-system saves), the static defaults are used so old behaviour is
# unchanged.
static func apply_lean(stats: Stats, house_id: String, stat_max: int, per_run_leans: Dictionary = {}) -> void:
	var h: Dictionary = HOUSES.get(house_id, {})
	if h.is_empty():
		return
	var plus_list: Array
	var minus_list: Array
	if not per_run_leans.is_empty() and per_run_leans.has(house_id):
		var entry: Dictionary = per_run_leans[house_id]
		plus_list  = entry.get("plus", h.get("lean_plus", []))
		minus_list = entry.get("minus", h.get("lean_minus", []))
	else:
		plus_list  = h.get("lean_plus", [])
		minus_list = h.get("lean_minus", [])
	for stat in plus_list:
		var key: String = str(stat)
		var v: int = stats.get_value(key)
		stats.set_value(key, clampi(v + 1, 1, stat_max))
	for stat in minus_list:
		var key: String = str(stat)
		var v: int = stats.get_value(key)
		stats.set_value(key, clampi(v - 1, 1, stat_max))
