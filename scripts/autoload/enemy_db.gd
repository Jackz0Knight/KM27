extends Node

# Enemy type definitions and stat rolling per GDD §13 expansion.
# Enemies use a subset of combat-relevant stats. Tier 1 = early-game threats;
# Tier 2 = mid-game. Stat ranges roll to individual unit blocks via
# roll_enemy_group(), which the expedition forecast and battle displays consume.

# Stat keys enemies use (maps to same-named fields on Stats, subset only).
const ENEMY_STAT_KEYS: Array[String] = [
	"strength", "speed", "bravery", "leadership", "intimidation",
]

# Enemy type table. stat_ranges: {stat_key: [min, max]}
const ENEMY_TYPES: Dictionary = {
	"goblin": {
		"name": "Goblin",
		"display_name": "Goblin",
		"stat_ranges": {
			"strength":    [2, 4],
			"speed":       [3, 5],
			"bravery":     [1, 3],
			"leadership":  [0, 1],
			"intimidation":[1, 3],
		},
		"tier": 1,
		"loot_tags": ["basic"],
	},
	"goblin_warrior": {
		"name": "Goblin Warrior",
		"display_name": "Goblin Warrior",
		"stat_ranges": {
			"strength":    [4, 6],
			"speed":       [3, 5],
			"bravery":     [2, 4],
			"leadership":  [0, 1],
			"intimidation":[2, 4],
		},
		"tier": 1,
		"loot_tags": ["basic"],
	},
	"bandit": {
		"name": "Bandit",
		"display_name": "Bandit",
		"stat_ranges": {
			"strength":    [4, 7],
			"speed":       [4, 6],
			"bravery":     [3, 5],
			"leadership":  [1, 3],
			"intimidation":[2, 4],
		},
		"tier": 1,
		"loot_tags": ["basic", "coin"],
	},
	"bandit_leader": {
		"name": "Bandit Leader",
		"display_name": "Bandit Leader",
		"stat_ranges": {
			"strength":    [6, 9],
			"speed":       [4, 6],
			"bravery":     [4, 6],
			"leadership":  [3, 5],
			"intimidation":[4, 6],
		},
		"tier": 1,
		"loot_tags": ["basic", "coin"],
	},
	"dire_wolf": {
		"name": "Dire Wolf",
		"display_name": "Dire Wolf",
		"stat_ranges": {
			"strength":    [5, 8],
			"speed":       [7, 10],
			"bravery":     [4, 7],
			"leadership":  [0, 0],
			"intimidation":[3, 6],
		},
		"tier": 1,
		"loot_tags": ["pelt"],
	},
	"orc": {
		"name": "Orc",
		"display_name": "Orc",
		"stat_ranges": {
			"strength":    [7, 11],
			"speed":       [2, 4],
			"bravery":     [5, 8],
			"leadership":  [1, 3],
			"intimidation":[4, 7],
		},
		"tier": 2,
		"loot_tags": ["scrap", "basic"],
	},
	"orc_berserker": {
		"name": "Orc Berserker",
		"display_name": "Orc Berserker",
		"stat_ranges": {
			"strength":    [10, 14],
			"speed":       [3, 5],
			"bravery":     [3, 6],
			"leadership":  [0, 1],
			"intimidation":[6, 9],
		},
		"tier": 2,
		"loot_tags": ["scrap"],
	},
	"giant_spider": {
		"name": "Giant Spider",
		"display_name": "Giant Spider",
		"stat_ranges": {
			"strength":    [3, 5],
			"speed":       [7, 11],
			"bravery":     [2, 4],
			"leadership":  [0, 0],
			"intimidation":[7, 10],
		},
		"tier": 2,
		"loot_tags": ["web"],
	},
	"troll": {
		"name": "Troll",
		"display_name": "Troll",
		"stat_ranges": {
			"strength":    [12, 16],
			"speed":       [1, 3],
			"bravery":     [8, 12],
			"leadership":  [0, 0],
			"intimidation":[5, 9],
		},
		"tier": 2,
		"loot_tags": ["basic"],
	},
}

# Tier 1 enemy types for early-game rolls.
const TIER1_TYPES: Array[String] = [
	"goblin", "goblin_warrior", "bandit", "bandit_leader", "dire_wolf",
]

# Tier 2 enemy types for mid-game rolls.
const TIER2_TYPES: Array[String] = [
	"orc", "orc_berserker", "giant_spider", "troll",
]


# Returns an Array of stat Dictionaries, one per enemy unit.
# Each dict has keys from ENEMY_STAT_KEYS plus "type_id" and "display_name".
static func roll_enemy_group(type_id: String, count: int) -> Array[Dictionary]:
	var entry: Dictionary = ENEMY_TYPES.get(type_id, {})
	if entry.is_empty():
		return []
	var ranges: Dictionary = entry["stat_ranges"]
	var out: Array[Dictionary] = []
	for i in range(count):
		var unit_stats: Dictionary = {
			"type_id": type_id,
			"display_name": entry["display_name"],
		}
		for stat_key in ranges:
			var lo: int = ranges[stat_key][0]
			var hi: int = ranges[stat_key][1]
			unit_stats[stat_key] = RNG.randi_range(lo, hi)
		out.append(unit_stats)
	return out


# Compute a single effective power value from a rolled enemy group.
# Uses strength + bravery + half intimidation per unit, similar to formation base.
static func group_power(units: Array[Dictionary]) -> int:
	var total: int = 0
	for u in units:
		total += int(u.get("strength", 0)) + int(u.get("bravery", 0)) + floori(float(u.get("intimidation", 0)) * 0.5)
	return total


# Pick a random Tier 1 group composition for a bandit ambush or expedition encounter.
# Returns Array[{type_id, count}].
static func roll_t1_group() -> Array[Dictionary]:
	var count: int = RNG.randi_range(2, 4)
	var type_id: String = TIER1_TYPES[RNG.randi_range(0, TIER1_TYPES.size() - 1)]
	return [{"type_id": type_id, "count": count}]


# Returns a human-readable encounter string, e.g. "2× Goblin Warrior, 1× Bandit".
static func describe_group(composition: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry in composition:
		var type_entry: Dictionary = ENEMY_TYPES.get(entry["type_id"], {})
		var dname: String = type_entry.get("display_name", entry["type_id"])
		parts.append("%d× %s" % [entry["count"], dname])
	return ", ".join(parts)
