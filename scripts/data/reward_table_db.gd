class_name RewardTableDB
extends RefCounted

# Reward Table database. The single source of truth for "what does a roll of
# this kind of loot yield." Mirrors the data-driven shape of CombatEventDB and
# AwayModeDB — adding a new loot category is one dict entry.
#
# Two axes of scaling per Jack's design call (2026-05-28):
#
#   1. Progression (week)  — `amount` per pool entry is [w1_lo, w1_hi, w40_lo,
#      w40_hi]. The roller linearly interpolates the lo/hi by week. Week 1 uses
#      the first pair; week 40 uses the second; weeks between blend.
#
#   2. Difficulty (per call) — `roll(table_id, week, difficulty_mult)` accepts
#      a multiplier the caller decides. Castles pass `castle.difficulty / 100.0`.
#      Combat events pass an entry-specific scalar. Tournaments pass a
#      `tournament_number` scalar. Bandit ambushes pass 1.0 (baseline).
#
# Each table is a *biased pool* — `rolls` entries are picked from the pool by
# weight (with replacement), each rolls an amount in its interpolated range
# scaled by difficulty. Result is a Dictionary keyed by ResourceDB ids.
#
# Pool entry shape:
#   { "id": String, "weight": int, "amount": [w1_lo, w1_hi, w40_lo, w40_hi] }
#
# Table entry shape:
#   { "label": String, "rolls": int, "pool": Array[entry] }

const W1: int = 1
const W_REF: int = 40    # week at which the "late" amount pair applies

const TABLES: Dictionary = {
	# ── Combat reward tables (formation + bundle paths) ─────────────────────

	# Wilderness loot — the default for pillage and forest-flavoured raids.
	# Plant fibres + logs dominate, copper ore is a fallback, occasional hide
	# when the band fought through wolf country.
	"wilderness_loot": {
		"label": "Wilderness loot",
		"rolls": 3,
		"pool": [
			{"id": "logs",         "weight": 5, "amount": [1, 3, 3, 7]},
			{"id": "plant_fibres", "weight": 4, "amount": [1, 3, 2, 6]},
			{"id": "copper_ore",   "weight": 2, "amount": [1, 2, 2, 5]},
			{"id": "wolf_pelt",    "weight": 1, "amount": [0, 1, 1, 2]},
		],
	},

	# Mountain loot — assault on a mountain-region castle or a hard mountain
	# ambush. Ore-heavy, with coal as a less-common late-game payoff.
	"mountain_loot": {
		"label": "Mountain loot",
		"rolls": 3,
		"pool": [
			{"id": "copper_ore",   "weight": 4, "amount": [1, 3, 3, 6]},
			{"id": "tin_ore",      "weight": 3, "amount": [1, 2, 2, 5]},
			{"id": "iron_ore",     "weight": 3, "amount": [0, 2, 2, 5]},
			{"id": "coal",         "weight": 2, "amount": [0, 1, 1, 3]},
			{"id": "logs",         "weight": 1, "amount": [1, 2, 1, 3]},
		],
	},

	# Hill loot — the middle ground between wilderness and mountain. Iron
	# country, modest cloth, occasional copper. Castles on hills, hilly
	# pillage runs.
	"hill_loot": {
		"label": "Hill loot",
		"rolls": 3,
		"pool": [
			{"id": "iron_ore",     "weight": 4, "amount": [1, 3, 3, 6]},
			{"id": "copper_ore",   "weight": 2, "amount": [1, 2, 2, 4]},
			{"id": "plant_fibres", "weight": 2, "amount": [1, 2, 1, 4]},
			{"id": "cotton",       "weight": 1, "amount": [0, 1, 1, 3]},
			{"id": "logs",         "weight": 2, "amount": [1, 2, 1, 4]},
		],
	},

	# Homestead defence — what the household pulls in after a successful Home
	# Battle or the village-raid / tavern-riot mission. Smaller, more
	# household-flavoured stuff (cloth, lumber, the odd bone shard from
	# whatever broke through the gate).
	"homestead_defence": {
		"label": "Homestead defence",
		"rolls": 2,
		"pool": [
			{"id": "logs",         "weight": 4, "amount": [1, 2, 2, 5]},
			{"id": "plant_fibres", "weight": 3, "amount": [1, 2, 2, 4]},
			{"id": "cotton",       "weight": 2, "amount": [0, 1, 1, 3]},
			{"id": "bone_shard",   "weight": 1, "amount": [0, 1, 1, 2]},
		],
	},

	# Bandit pouch — small loot from a bandit ambush. Plant fibres + the odd
	# fragment of copper they were carrying.
	"bandit_pouch": {
		"label": "Bandit pouch",
		"rolls": 2,
		"pool": [
			{"id": "plant_fibres", "weight": 4, "amount": [1, 2, 1, 3]},
			{"id": "logs",         "weight": 2, "amount": [0, 1, 1, 3]},
			{"id": "copper_ore",   "weight": 2, "amount": [0, 1, 1, 2]},
		],
	},

	# Tournament prize — purely cloth + iron, modest scale. Etiquette
	# multiplier and the tournament-number difficulty multiplier together
	# drive the actual size at the call site (Combat.roll_tournament_reward).
	"tournament_prize": {
		"label": "Tournament prize",
		"rolls": 3,
		"pool": [
			{"id": "cotton",       "weight": 3, "amount": [1, 3, 2, 5]},
			{"id": "iron_ore",     "weight": 2, "amount": [1, 2, 2, 4]},
			{"id": "plant_fibres", "weight": 3, "amount": [1, 2, 1, 4]},
			{"id": "logs",         "weight": 2, "amount": [1, 2, 1, 3]},
		],
	},

	# ── BattleEvent tables (non-combat reward paths) ────────────────────────

	# Bountiful Harvest — a small free gift. Pure cloth + lumber, no metal.
	"harvest": {
		"label": "Bountiful harvest",
		"rolls": 2,
		"pool": [
			{"id": "plant_fibres", "weight": 4, "amount": [2, 4, 3, 6]},
			{"id": "logs",         "weight": 3, "amount": [1, 3, 2, 5]},
			{"id": "cotton",       "weight": 1, "amount": [0, 1, 1, 3]},
		],
	},

	# Merchant Caravan offers — three of these are rolled to populate the
	# Weekly Summary picker. Each is a small, mixed bundle.
	"caravan_offer": {
		"label": "Caravan offer",
		"rolls": 2,
		"pool": [
			{"id": "plant_fibres", "weight": 2, "amount": [1, 3, 2, 4]},
			{"id": "logs",         "weight": 2, "amount": [1, 3, 2, 4]},
			{"id": "copper_ore",   "weight": 2, "amount": [1, 2, 1, 3]},
			{"id": "cotton",       "weight": 1, "amount": [0, 1, 1, 2]},
			{"id": "iron_ore",     "weight": 1, "amount": [0, 1, 1, 2]},
		],
	},

	# ── Gather tables (terrain-driven, regional gather) ─────────────────────
	# These are what `MapTile.gather_table_id()` resolves to. The gather
	# expedition rolls the target tile's table at full weight, plus each
	# Chebyshev-1 neighbour with a table at 0.3 weight — Strength scaling
	# applies to the final sum.

	"gather_forest": {
		"label": "Forest yield",
		"rolls": 2,
		"pool": [
			{"id": "logs",         "weight": 5, "amount": [1, 3, 2, 5]},
			{"id": "plant_fibres", "weight": 3, "amount": [1, 2, 1, 4]},
			{"id": "hardwood",     "weight": 1, "amount": [0, 1, 1, 2]},
		],
	},

	"gather_mountain": {
		"label": "Mountain yield",
		"rolls": 2,
		"pool": [
			{"id": "copper_ore",   "weight": 3, "amount": [1, 2, 2, 4]},
			{"id": "tin_ore",      "weight": 3, "amount": [1, 2, 1, 3]},
			{"id": "iron_ore",     "weight": 2, "amount": [0, 1, 1, 3]},
			{"id": "coal",         "weight": 2, "amount": [0, 1, 1, 2]},
		],
	},

	"gather_hills": {
		"label": "Hill yield",
		"rolls": 2,
		"pool": [
			{"id": "iron_ore",     "weight": 4, "amount": [1, 2, 1, 3]},
			{"id": "copper_ore",   "weight": 2, "amount": [0, 1, 1, 2]},
			{"id": "plant_fibres", "weight": 2, "amount": [1, 2, 1, 3]},
		],
	},

	"gather_plains": {
		"label": "Plains yield",
		"rolls": 2,
		"pool": [
			{"id": "plant_fibres", "weight": 4, "amount": [1, 2, 1, 3]},
			{"id": "logs",         "weight": 2, "amount": [0, 1, 1, 2]},
			{"id": "cotton",       "weight": 1, "amount": [0, 1, 1, 2]},
		],
	},

	"gather_beach": {
		"label": "Beach yield",
		"rolls": 1,
		"pool": [
			{"id": "plant_fibres", "weight": 3, "amount": [1, 2, 1, 3]},
			{"id": "logs",         "weight": 1, "amount": [0, 1, 1, 2]},
		],
	},
}


# Roll a table. Returns a Dictionary keyed by ResourceDB ids.
#
# `week`           — current week (drives the lo/hi interpolation).
# `difficulty_mult`— flat scalar applied to every line item's amount roll.
#                    Castles use castle.difficulty / 100.0; combat-event
#                    rewards use a per-entry scalar; bandit ambushes use 1.0.
# `rolls_override` — pass > 0 to override the table's default `rolls` count.
#                    Used by the regional-gather neighbour rolls (which want
#                    fewer picks at the 0.3 weight) and by future events that
#                    want a "small" or "large" roll of the same pool.
static func roll(table_id: String, week: int, difficulty_mult: float = 1.0, rolls_override: int = -1) -> Dictionary:
	var table: Dictionary = TABLES.get(table_id, {})
	if table.is_empty():
		push_warning("[RewardTableDB] No table for id: %s" % table_id)
		return {}
	var pool: Array = table.get("pool", [])
	if pool.is_empty():
		return {}
	var rolls: int = rolls_override if rolls_override > 0 else int(table.get("rolls", 2))
	# Build the cumulative weight ladder once so each roll is O(log n).
	var total_weight: int = 0
	for entry in pool:
		total_weight += int(entry.get("weight", 1))
	var t: float = clampf(float(week - W1) / float(W_REF - W1), 0.0, 1.0)
	var out: Dictionary = {}
	for i in range(rolls):
		var pick: Dictionary = _weighted_pick(pool, total_weight)
		var amt_range: Array = pick.get("amount", [0, 0, 0, 0])
		var lo: int = roundi(lerpf(float(amt_range[0]), float(amt_range[2]), t))
		var hi: int = roundi(lerpf(float(amt_range[1]), float(amt_range[3]), t))
		if hi < lo:
			hi = lo
		var raw: int = RNG.randi_range(lo, hi)
		var scaled: int = roundi(float(raw) * difficulty_mult)
		if scaled <= 0:
			continue
		var id: String = str(pick.get("id", ""))
		if id == "":
			continue
		out[id] = int(out.get(id, 0)) + scaled
	return out


# Tier-blended roll that splits N rolls across multiple tables — used by the
# regional gather. Each (table_id, weight) pair contributes proportionally.
# Weight < 1.0 reduces the table's contribution; 0.3 is the value the gather
# uses for each adjacent tile.
static func roll_blended(weighted_tables: Array, week: int, difficulty_mult: float = 1.0) -> Dictionary:
	var out: Dictionary = {}
	for entry in weighted_tables:
		var table_id: String = str(entry.get("table", ""))
		var weight: float = float(entry.get("weight", 1.0))
		if table_id == "" or weight <= 0.0:
			continue
		var contribution: Dictionary = roll(table_id, week, difficulty_mult * weight)
		ResourceDB.merge(out, contribution)
	return out


# Preview the *expected* yield from a table — no RNG. Returns a Dictionary
# of {id: midpoint expected value} so UI surfaces ("you might gather logs,
# plant fibres") can list resources without rolling. The values are decimal
# expectations × rolls × pool_share, then rounded to the nearest int for
# legibility.
static func preview(table_id: String, week: int, difficulty_mult: float = 1.0) -> Dictionary:
	var table: Dictionary = TABLES.get(table_id, {})
	if table.is_empty():
		return {}
	var pool: Array = table.get("pool", [])
	var rolls: int = int(table.get("rolls", 2))
	var total_weight: float = 0.0
	for entry in pool:
		total_weight += float(entry.get("weight", 1))
	var t: float = clampf(float(week - W1) / float(W_REF - W1), 0.0, 1.0)
	var out: Dictionary = {}
	for entry: Dictionary in pool:
		var share: float = float(entry.get("weight", 1)) / total_weight
		var amt_range: Array = entry.get("amount", [0, 0, 0, 0])
		var lo: float = lerpf(float(amt_range[0]), float(amt_range[2]), t)
		var hi: float = lerpf(float(amt_range[1]), float(amt_range[3]), t)
		var midpoint: float = (lo + hi) * 0.5
		var expected: int = roundi(midpoint * share * float(rolls) * difficulty_mult)
		if expected > 0:
			out[str(entry["id"])] = expected
	return out


static func has_table(table_id: String) -> bool:
	return TABLES.has(table_id)


static func label_for(table_id: String) -> String:
	var t: Dictionary = TABLES.get(table_id, {})
	return str(t.get("label", table_id.capitalize()))


# ── internal ────────────────────────────────────────────────────────────────

static func _weighted_pick(pool: Array, total_weight: int) -> Dictionary:
	var pick: int = RNG.randi_range(1, total_weight)
	var acc: int = 0
	for entry: Dictionary in pool:
		acc += int(entry.get("weight", 1))
		if pick <= acc:
			return entry
	return pool[pool.size() - 1]
