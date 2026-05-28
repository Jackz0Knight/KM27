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
# `drops`: per-enemy mob-drop table. Each entry is {id, chance, amount: [lo, hi]}.
#   On a combat win, Resolution rolls each living-then-dead enemy's drops and
#   accumulates them into result["spoils"]. The kill itself produces the loot;
#   the encounter's `reward` (bundle from RewardTableDB) is separate.
# `loot_tags`: kept for compatibility / future tagging — no code reads them.
# TIER2_TYPES: defined but lightly used — activation curve a Phase 8 knob.

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
		"drops": [
			{"id": "goblin_hide", "chance": 0.55, "amount": [1, 1]},
			{"id": "bone_shard",  "chance": 0.35, "amount": [1, 2]},
		],
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
		"drops": [
			{"id": "goblin_hide", "chance": 0.65, "amount": [1, 2]},
			{"id": "bone_shard",  "chance": 0.30, "amount": [1, 2]},
			{"id": "scrap_iron",  "chance": 0.20, "amount": [1, 1]},
		],
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
		"drops": [
			{"id": "plant_fibres", "chance": 0.50, "amount": [1, 2]},
			{"id": "scrap_iron",   "chance": 0.30, "amount": [1, 2]},
			{"id": "copper_ore",   "chance": 0.20, "amount": [1, 1]},
		],
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
		"drops": [
			{"id": "scrap_iron",  "chance": 0.70, "amount": [1, 2]},
			{"id": "plant_fibres","chance": 0.40, "amount": [1, 2]},
			{"id": "iron_ore",    "chance": 0.25, "amount": [1, 1]},
		],
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
		"drops": [
			{"id": "wolf_pelt",  "chance": 0.85, "amount": [1, 1]},
			{"id": "bone_shard", "chance": 0.45, "amount": [1, 2]},
		],
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
		"drops": [
			{"id": "scrap_iron",  "chance": 0.75, "amount": [1, 3]},
			{"id": "goblin_hide", "chance": 0.40, "amount": [1, 2]},
			{"id": "iron_ore",    "chance": 0.30, "amount": [1, 2]},
		],
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
		"drops": [
			{"id": "scrap_iron",  "chance": 0.65, "amount": [2, 3]},
			{"id": "bone_shard",  "chance": 0.50, "amount": [1, 3]},
			{"id": "troll_bile",  "chance": 0.10, "amount": [1, 1]},
		],
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
		"drops": [
			{"id": "spider_web", "chance": 0.85, "amount": [1, 2]},
			{"id": "bone_shard", "chance": 0.30, "amount": [1, 1]},
		],
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
		"drops": [
			{"id": "troll_bile", "chance": 0.65, "amount": [1, 2]},
			{"id": "bone_shard", "chance": 0.60, "amount": [2, 4]},
			{"id": "hardwood",   "chance": 0.25, "amount": [1, 2]},
		],
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


# Roll mob drops from a single enemy of `type_id`. Each entry in the enemy's
# `drops` array is an independent Bernoulli — if it fires, the amount is rolled
# in its [lo, hi] range. `kill_mult` (default 1.0) lets the caller scale the
# whole table — Resolution passes 1.0 per dead enemy and accumulates across
# the party. Returns a Dictionary keyed by ResourceDB ids.
func roll_drops_for(type_id: String, kill_mult: float = 1.0) -> Dictionary:
	var entry: Dictionary = ENEMY_TYPES.get(type_id, {})
	if entry.is_empty():
		return {}
	var table: Array = entry.get("drops", [])
	if table.is_empty():
		return {}
	var out: Dictionary = {}
	for line: Dictionary in table:
		var chance: float = float(line.get("chance", 0.0)) * kill_mult
		if chance <= 0.0:
			continue
		if RNG.randf_range(0.0, 1.0) >= chance:
			continue
		var amt_range: Array = line.get("amount", [1, 1])
		var amount: int = RNG.randi_range(int(amt_range[0]), int(amt_range[1]))
		if amount <= 0:
			continue
		var id: String = str(line.get("id", ""))
		if id == "":
			continue
		out[id] = int(out.get(id, 0)) + amount
	return out


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
		var mid: int = roundi((float(range_arr[0]) + float(range_arr[1])) / 2.0) + week_bonus
		s.set_value(k, mid)
	var wid: String = entry.get("default_weapon_id", "unarmed")
	var aid: String = entry.get("default_armour_id", "unarmoured")
	var label: String = entry.get("display_name", type_id)
	return EnemyActor.new(p_id, label, type_id, s, wid, aid)
