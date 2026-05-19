extends Node

# Enemy type definitions and combat party factory.
#
# stat_ranges covers all 12 visible stats so CombatUnit can derive a full
# combat profile. Stats not meaningful for a given enemy type (e.g. archery
# for a troll) are set to [0, 0] — they won't contribute to the sim.
#
# default_weapon_id / default_armour_id map to Weapon.CATALOGUE and
# Armour.CATALOGUE entries used when building CombatUnits.
#
# loot_tags: reserved for a future loot-variety system — no code reads them yet.
# TIER2_TYPES: defined but not yet active — activation deferred to Phase 8
#   balance pass (week >= 20 threshold).

const ENEMY_TYPES: Dictionary = {
	"goblin": {
		"name": "Goblin",
		"display_name": "Goblin",
		"stat_ranges": {
			"strength":     [2, 4],
			"speed":        [3, 5],
			"technique":    [1, 3],
			"bravery":      [1, 3],
			"loyalty":      [1, 2],
			"determination":[1, 3],
			"swordsmanship":[2, 4],
			"archery":      [1, 3],
			"horsemanship": [0, 1],
			"leadership":   [0, 1],
			"etiquette":    [0, 1],
			"intimidation": [1, 3],
		},
		"default_weapon_id": "shortsword",
		"default_armour_id": "unarmoured",
		"tier": 1,
		"loot_tags": ["basic"],
	},
	"goblin_warrior": {
		"name": "Goblin Warrior",
		"display_name": "Goblin Warrior",
		"stat_ranges": {
			"strength":     [4, 6],
			"speed":        [3, 5],
			"technique":    [2, 4],
			"bravery":      [2, 4],
			"loyalty":      [2, 3],
			"determination":[2, 4],
			"swordsmanship":[3, 5],
			"archery":      [1, 3],
			"horsemanship": [0, 1],
			"leadership":   [0, 1],
			"etiquette":    [0, 1],
			"intimidation": [2, 4],
		},
		"default_weapon_id": "shortsword",
		"default_armour_id": "padded",
		"tier": 1,
		"loot_tags": ["basic"],
	},
	"bandit": {
		"name": "Bandit",
		"display_name": "Bandit",
		"stat_ranges": {
			"strength":     [4, 7],
			"speed":        [4, 6],
			"technique":    [3, 6],
			"bravery":      [3, 5],
			"loyalty":      [2, 4],
			"determination":[3, 5],
			"swordsmanship":[4, 7],
			"archery":      [2, 5],
			"horsemanship": [1, 3],
			"leadership":   [1, 3],
			"etiquette":    [1, 2],
			"intimidation": [2, 4],
		},
		"default_weapon_id": "shortsword",
		"default_armour_id": "unarmoured",
		"tier": 1,
		"loot_tags": ["basic", "coin"],
	},
	"bandit_leader": {
		"name": "Bandit Leader",
		"display_name": "Bandit Leader",
		"stat_ranges": {
			"strength":     [6, 9],
			"speed":        [4, 6],
			"technique":    [5, 8],
			"bravery":      [4, 6],
			"loyalty":      [3, 5],
			"determination":[4, 7],
			"swordsmanship":[6, 9],
			"archery":      [3, 6],
			"horsemanship": [2, 4],
			"leadership":   [3, 5],
			"etiquette":    [2, 4],
			"intimidation": [4, 6],
		},
		"default_weapon_id": "longsword",
		"default_armour_id": "leather",
		"tier": 1,
		"loot_tags": ["basic", "coin"],
	},
	"dire_wolf": {
		"name": "Dire Wolf",
		"display_name": "Dire Wolf",
		"stat_ranges": {
			"strength":     [5, 8],
			"speed":        [7, 10],
			"technique":    [1, 2],
			"bravery":      [4, 7],
			"loyalty":      [4, 6],
			"determination":[3, 6],
			"swordsmanship":[0, 0],
			"archery":      [0, 0],
			"horsemanship": [0, 0],
			"leadership":   [0, 0],
			"etiquette":    [0, 0],
			"intimidation": [3, 6],
		},
		"default_weapon_id": "unarmed",
		"default_armour_id": "unarmoured",
		"tier": 1,
		"loot_tags": ["pelt"],
	},
	"orc": {
		"name": "Orc",
		"display_name": "Orc",
		"stat_ranges": {
			"strength":     [7, 11],
			"speed":        [2, 4],
			"technique":    [3, 5],
			"bravery":      [5, 8],
			"loyalty":      [3, 5],
			"determination":[4, 7],
			"swordsmanship":[5, 8],
			"archery":      [0, 2],
			"horsemanship": [0, 1],
			"leadership":   [1, 3],
			"etiquette":    [0, 1],
			"intimidation": [4, 7],
		},
		"default_weapon_id": "axe",
		"default_armour_id": "unarmoured",
		"tier": 2,
		"loot_tags": ["scrap", "basic"],
	},
	"orc_berserker": {
		"name": "Orc Berserker",
		"display_name": "Orc Berserker",
		"stat_ranges": {
			"strength":     [10, 14],
			"speed":        [3, 5],
			"technique":    [2, 4],
			"bravery":      [3, 6],
			"loyalty":      [2, 4],
			"determination":[6, 9],
			"swordsmanship":[5, 8],
			"archery":      [0, 1],
			"horsemanship": [0, 0],
			"leadership":   [0, 1],
			"etiquette":    [0, 0],
			"intimidation": [6, 9],
		},
		"default_weapon_id": "axe",
		"default_armour_id": "unarmoured",
		"tier": 2,
		"loot_tags": ["scrap"],
	},
	"giant_spider": {
		"name": "Giant Spider",
		"display_name": "Giant Spider",
		"stat_ranges": {
			"strength":     [3, 5],
			"speed":        [7, 11],
			"technique":    [4, 7],
			"bravery":      [2, 4],
			"loyalty":      [1, 3],
			"determination":[2, 4],
			"swordsmanship":[3, 6],
			"archery":      [0, 0],
			"horsemanship": [0, 0],
			"leadership":   [0, 0],
			"etiquette":    [0, 0],
			"intimidation": [7, 10],
		},
		"default_weapon_id": "dagger",
		"default_armour_id": "unarmoured",
		"tier": 2,
		"loot_tags": ["web"],
	},
	"troll": {
		"name": "Troll",
		"display_name": "Troll",
		"stat_ranges": {
			"strength":     [12, 16],
			"speed":        [1, 3],
			"technique":    [1, 3],
			"bravery":      [8, 12],
			"loyalty":      [1, 2],
			"determination":[5, 8],
			"swordsmanship":[2, 4],
			"archery":      [0, 0],
			"horsemanship": [0, 0],
			"leadership":   [0, 0],
			"etiquette":    [0, 0],
			"intimidation": [5, 9],
		},
		"default_weapon_id": "unarmed",
		"default_armour_id": "unarmoured",
		"tier": 2,
		"loot_tags": ["basic"],
	},
}

const TIER1_TYPES: Array[String] = [
	"goblin", "goblin_warrior", "bandit", "bandit_leader", "dire_wolf",
]

# Tier 2 enemy types — defined but not yet selected by any combat path.
# Activation deferred to Phase 8 balance pass: week >= 20 (or a configurable
# threshold) will weight the roll toward TIER2_TYPES for mid-game variety.
const TIER2_TYPES: Array[String] = [
	"orc", "orc_berserker", "giant_spider", "troll",
]

# How many enemies appear per event type. Tunable from play.
const PARTY_SIZES: Dictionary = {
	"home_battle":   3,
	"pillage":       3,
	"bandit_ambush": 2,
	"tournament":    4,
	"duel":          1,
}


# ---------- CombatUnit party factories ----------

# Rolls a real combat party (uses RNG — call only from Resolution, not from UI).
func roll_combat_party(event_key: String, week: int) -> Array:
	var type_ids: Array[String] = _types_for_event(event_key, week)
	var count: int = PARTY_SIZES.get(event_key, 3)
	var out: Array = []
	var week_bonus: int = floori(float(week) / 10.0)
	for i in range(count):
		var type_id: String = type_ids[RNG.randi_range(0, type_ids.size() - 1)]
		var actor: EnemyActor = _roll_actor(i + 100, type_id, week_bonus)
		out.append(CombatUnit.new(actor))
	return out


# Builds a preview party from midpoint averages — NO RNG, safe to call from UI.
func preview_party(event_key: String, week: int) -> Array:
	var type_ids: Array[String] = _types_for_event(event_key, week)
	var count: int = PARTY_SIZES.get(event_key, 3)
	var out: Array = []
	var week_bonus: int = floori(float(week) / 10.0)
	for i in range(count):
		# Use the most common type for the event as the representative preview.
		var type_id: String = type_ids[0]
		var actor: EnemyActor = _midpoint_actor(i + 100, type_id, week_bonus)
		out.append(CombatUnit.new(actor))
	return out


# ---------- legacy helpers (kept for expedition flavor and old display code) ----------

func roll_enemy_group(type_id: String, count: int) -> Array[Dictionary]:
	var entry: Dictionary = ENEMY_TYPES.get(type_id, {})
	if entry.is_empty():
		return []
	var ranges: Dictionary = entry["stat_ranges"]
	var out: Array[Dictionary] = []
	for i in range(count):
		var unit_stats: Dictionary = {"type_id": type_id, "display_name": entry["display_name"]}
		for stat_key in ranges:
			var lo: int = ranges[stat_key][0]
			var hi: int = ranges[stat_key][1]
			unit_stats[stat_key] = RNG.randi_range(lo, hi)
		out.append(unit_stats)
	return out


func group_power(units: Array[Dictionary]) -> int:
	var total: int = 0
	for u in units:
		total += int(u.get("strength", 0)) + int(u.get("bravery", 0)) + floori(float(u.get("intimidation", 0)) * 0.5)
	return total


func roll_t1_group() -> Array[Dictionary]:
	var count: int = RNG.randi_range(2, 4)
	var type_id: String = TIER1_TYPES[RNG.randi_range(0, TIER1_TYPES.size() - 1)]
	return [{"type_id": type_id, "count": count}]


func describe_group(composition: Array[Dictionary]) -> String:
	var parts: Array[String] = []
	for entry in composition:
		var type_entry: Dictionary = ENEMY_TYPES.get(entry["type_id"], {})
		var dname: String = type_entry.get("display_name", entry["type_id"])
		parts.append("%d× %s" % [entry["count"], dname])
	return ", ".join(parts)


# ---------- internal ----------

func _types_for_event(event_key: String, week: int) -> Array[String]:
	if week >= 20 and event_key in ["home_battle", "pillage"]:
		# Mix in Tier 2 enemies at higher weeks.
		return ["orc", "orc_berserker", "bandit_leader"]
	match event_key:
		"home_battle":   return ["bandit", "goblin_warrior", "bandit"]
		"pillage":       return ["goblin", "bandit", "goblin_warrior"]
		"bandit_ambush": return ["bandit", "bandit_leader"]
		"tournament":    return ["bandit_leader", "orc", "bandit"]
		"duel":          return ["bandit_leader"]
	return ["goblin"]


func _roll_actor(p_id: int, type_id: String, week_bonus: int) -> EnemyActor:
	var entry: Dictionary = ENEMY_TYPES.get(type_id, ENEMY_TYPES["goblin"])
	var s: Stats = Stats.new()
	for k in Stats.STAT_KEYS:
		var range_arr = entry["stat_ranges"].get(k, [1, 2])
		var val: int = RNG.randi_range(int(range_arr[0]), int(range_arr[1])) + week_bonus
		s.set_value(k, val)
	var wid: String = entry.get("default_weapon_id", "unarmed")
	var aid: String = entry.get("default_armour_id", "unarmoured")
	var label: String = entry.get("display_name", type_id)
	return EnemyActor.new(p_id, label, type_id, s, wid, aid)


func _midpoint_actor(p_id: int, type_id: String, week_bonus: int) -> EnemyActor:
	var entry: Dictionary = ENEMY_TYPES.get(type_id, ENEMY_TYPES["goblin"])
	var s: Stats = Stats.new()
	for k in Stats.STAT_KEYS:
		var range_arr = entry["stat_ranges"].get(k, [1, 2])
		var mid: int = (int(range_arr[0]) + int(range_arr[1])) / 2 + week_bonus
		s.set_value(k, mid)
	var wid: String = entry.get("default_weapon_id", "unarmed")
	var aid: String = entry.get("default_armour_id", "unarmoured")
	var label: String = entry.get("display_name", type_id)
	return EnemyActor.new(p_id, label, type_id, s, wid, aid)
