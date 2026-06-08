extends Node

# Resource database — full tree of raw materials and processed resources per
# GDD §14 expansion. Registered as an autoload so any system can query it.

enum ResType { FABRIC, TIMBER, METAL }

# §18.2 scarcity bands — a design-target yardstick for the Phase-8 balance pass,
# not a runtime gate. Derived from tier (see `scarcity_band`) so balance work can
# read "how rare should a week's supply of this be?" straight from code. Raw
# materials (no tier) read as Plentiful (the bulk gather/drop trickle); processed
# tiers climb T1→Common … T5→Legendary.
enum Band { PLENTIFUL, COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

const BAND_LABELS: Dictionary = {
	Band.PLENTIFUL: "Plentiful",
	Band.COMMON:    "Common",
	Band.UNCOMMON:  "Uncommon",
	Band.RARE:      "Rare",
	Band.EPIC:      "Epic",
	Band.LEGENDARY: "Legendary",
}

const TIER_TO_BAND: Dictionary = {
	1: Band.COMMON,
	2: Band.UNCOMMON,
	3: Band.RARE,
	4: Band.EPIC,
	5: Band.LEGENDARY,
}

const TIER_COLORS: Dictionary = {
	1: Color(0.72, 0.72, 0.72),   # Grey   T1
	2: Color(0.20, 0.80, 0.20),   # Green  T2
	3: Color(0.30, 0.60, 1.00),   # Blue   T3
	4: Color(0.75, 0.20, 0.90),   # Purple T4
	5: Color(1.00, 0.84, 0.10),   # Gold   T5
}

# Full resource tree keyed by ID.
# Processed resources have "type" and "tier"; raw materials do not.
# "recipe" is null for gather-only resources.
# "research" is a string key gate — null means always available.
const RESOURCES: Dictionary = {
	# ── TIER 1 ──────────────────────────────────────────────────────────────
	"plant_weave": {
		"name": "Plant Weave", "type": ResType.FABRIC, "tier": 1,
		"recipe": {"plant_fibres": 2}, "map_source": "tree", "research": null,
	},
	"cloth": {
		"name": "Cloth", "type": ResType.FABRIC, "tier": 1,
		"recipe": {"cotton": 1}, "map_source": "cotton_plant", "research": "cotton_cultivation",
	},
	"planks": {
		"name": "Planks", "type": ResType.TIMBER, "tier": 1,
		"recipe": {"logs": 2}, "map_source": "tree", "research": null,
	},
	"thatch": {
		"name": "Thatch", "type": ResType.TIMBER, "tier": 1,
		"recipe": {"logs": 1}, "map_source": "tree", "research": null,
	},
	"tin": {
		"name": "Tin", "type": ResType.METAL, "tier": 1,
		"recipe": {"tin_ore": 2}, "map_source": "mountain", "research": null,
	},
	"copper": {
		"name": "Copper", "type": ResType.METAL, "tier": 1,
		"recipe": {"copper_ore": 2}, "map_source": "mountain", "research": null,
	},
	# ── TIER 2 ──────────────────────────────────────────────────────────────
	"spidersilk": {
		"name": "Spidersilk", "type": ResType.FABRIC, "tier": 2,
		"recipe": {"spider_web": 3}, "map_source": "spider", "research": null,
	},
	"leather": {
		"name": "Leather", "type": ResType.FABRIC, "tier": 2,
		"recipe": {"cow_hide": 2}, "map_source": "cow", "research": null,
	},
	"plankshrooms": {
		"name": "Plankshrooms", "type": ResType.TIMBER, "tier": 2,
		"recipe": {"fungal_log": 2}, "map_source": "fungal_log", "research": null,
	},
	"timber_plank": {
		"name": "Timber Plank", "type": ResType.TIMBER, "tier": 2,
		"recipe": {"hardwood": 2}, "map_source": "hardwood", "research": null,
	},
	"bronze_ingot": {
		"name": "Bronze Ingot", "type": ResType.METAL, "tier": 2,
		"recipe": {"tin": 1, "copper": 1}, "map_source": null, "research": "alloy_research",
	},
	"iron_ingot": {
		"name": "Iron Ingot", "type": ResType.METAL, "tier": 2,
		"recipe": {"iron_ore": 2}, "map_source": "mountain", "research": null,
	},
	# Mob-drop-driven T2 recipes (2026-05-28 resource overhaul). Each consumes
	# one of the new T1 mob raws so combat drops feed back into the
	# crafting loop. Adding more later is one dict entry.
	"quilted_padding": {
		"name": "Quilted Padding", "type": ResType.FABRIC, "tier": 2,
		"recipe": {"goblin_hide": 2, "plant_fibres": 1}, "map_source": null, "research": null,
	},
	"feather_arrow": {
		"name": "Feathered Arrow", "type": ResType.TIMBER, "tier": 2,
		"recipe": {"feathers": 3, "logs": 1}, "map_source": null, "research": null,
	},
	"reforged_blade": {
		"name": "Reforged Blade", "type": ResType.METAL, "tier": 2,
		"recipe": {"scrap_iron": 3, "coal": 1}, "map_source": null, "research": null,
	},
	# ── TIER 3 ──────────────────────────────────────────────────────────────
	"wyrm_hide": {
		"name": "Wyrm Hide", "type": ResType.FABRIC, "tier": 3,
		"recipe": null, "map_source": "dragon", "research": null,
	},
	"shadow_weave": {
		"name": "Shadow Weave", "type": ResType.FABRIC, "tier": 3,
		"recipe": null, "map_source": "underdark", "research": null,
	},
	"duskwood_planks": {
		"name": "Duskwood Planks", "type": ResType.TIMBER, "tier": 3,
		"recipe": {"duskwood": 2}, "map_source": null, "research": null,
	},
	"elven_planks": {
		"name": "Elven Planks", "type": ResType.TIMBER, "tier": 3,
		"recipe": {"elven_wood": 2}, "map_source": null, "research": null,
	},
	"steel_ingot": {
		"name": "Steel Ingot", "type": ResType.METAL, "tier": 3,
		"recipe": {"iron_ingot": 2, "coal": 1}, "map_source": null, "research": "blast_furnace",
	},
	"mythril_ingot": {
		"name": "Mythril Ingot", "type": ResType.METAL, "tier": 3,
		"recipe": {"mythril_ore": 2}, "map_source": null, "research": null,
	},
	# ── RAW MATERIALS (no type / tier — stockpileable intermediates) ─────────
	"plant_fibres": { "name": "Plant Fibres", "map_source": "tree" },
	"logs":         { "name": "Logs",         "map_source": "tree" },
	"tin_ore":      { "name": "Tin Ore",      "map_source": "mountain" },
	"copper_ore":   { "name": "Copper Ore",   "map_source": "mountain" },
	"cotton":       { "name": "Cotton",       "map_source": "cotton_plant" },
	"spider_web":   { "name": "Spider Web",   "map_source": "spider" },
	"cow_hide":     { "name": "Cow Hide",     "map_source": "cow" },
	"fungal_log":   { "name": "Fungal Log",   "map_source": "fungal_log" },
	"hardwood":     { "name": "Hardwood",     "map_source": "hardwood" },
	"iron_ore":     { "name": "Iron Ore",     "map_source": "hills" },
	"coal":         { "name": "Coal",         "map_source": "mountain" },
	"duskwood":     { "name": "Duskwood",     "map_source": null },
	"elven_wood":   { "name": "Elven Wood",   "map_source": null },
	"mythril_ore":  { "name": "Mythril Ore",  "map_source": "mountain" },
	# ── Mob-drop raws (no map_source — sourced from EnemyDB drops only) ────
	# Pure T1 stockpileables. Each is tied to one or more enemy types in
	# `EnemyDB.ENEMY_TYPES[*].drops` and lands on a combat win. The mob-drop
	# raws are intentionally distinct from gather raws so the player feels
	# the difference between "I scouted this tile" and "I killed this thing."
	"goblin_hide":   { "name": "Goblin Hide",   "map_source": null },
	"wolf_pelt":     { "name": "Wolf Pelt",     "map_source": null },
	"bone_shard":    { "name": "Bone Shard",    "map_source": null },
	"scrap_iron":    { "name": "Scrap Iron",    "map_source": null },
	"feathers":      { "name": "Feathers",      "map_source": null },
	"troll_bile":    { "name": "Troll Bile",    "map_source": null },
	"strange_relic": { "name": "Strange Relic", "map_source": null },
}


# Returns the ID of the highest-tier resource of `res_type` the player has any
# amount of in inventory, or "" if the inventory holds none of that type.
func best_for_type(inventory: Dictionary, res_type: int) -> String:
	var best_id: String = ""
	var best_tier: int = 0
	for id: String in RESOURCES:
		var entry: Dictionary = RESOURCES[id]
		if not entry.has("type") or entry["type"] != res_type:
			continue
		if inventory.get(id, 0) <= 0:
			continue
		if entry["tier"] > best_tier:
			best_tier = entry["tier"]
			best_id = id
	return best_id


# Returns a BBCode string for the persistent resource HUD.
# Gold + best-held resource per type, each prefixed with the same tier glyph
# we use in the Crafting tab so the HUD reads like a proper inventory strip
# even when slots are empty.
# `reputation` is optional with a 0 default — callers that don't pass it
# (legacy or unit tests) see the original Gold + types line. Passing a value
# prepends a "❦ Rep:" chip styled by reputation band.
func resource_hud_bbcode(gold: int, inventory: Dictionary, reputation: int = 0) -> String:
	const TYPE_LABEL: Dictionary = {
		ResType.FABRIC: "Fabric",
		ResType.TIMBER: "Timber",
		ResType.METAL:  "Metal",
	}
	const TYPE_GLYPH: Dictionary = {
		ResType.FABRIC: "◆",
		ResType.TIMBER: "▲",
		ResType.METAL:  "■",
	}
	# Use the lowest tier's colour as the muted "no holdings yet" tint so each
	# slot still reads as belonging to its type when empty.
	const TIER1_HEX: Dictionary = {
		ResType.FABRIC: "#7A8B5C",
		ResType.TIMBER: "#8B6A45",
		ResType.METAL:  "#7E8294",
	}

	var parts: Array[String] = []
	# Reputation chip — coloured by band. Skipped when zero/default so callers
	# that haven't been updated yet still get the original HUD layout.
	if reputation != 0:
		var rep_hex: String = _reputation_hex(reputation)
		var rep_label: String = _reputation_label(reputation)
		parts.append("[color=#C4A24B]❦ Rep:[/color] [color=%s]%d (%s)[/color]" % [
			rep_hex, reputation, rep_label,
		])
	parts.append("[color=#FFD61A]✦ Gold:[/color] [color=#F1E2A4]%d[/color]" % gold)

	for res_type: int in [ResType.FABRIC, ResType.TIMBER, ResType.METAL]:
		var glyph: String = TYPE_GLYPH[res_type]
		var name: String = TYPE_LABEL[res_type]
		var best_id: String = best_for_type(inventory, res_type)
		if best_id == "":
			# Empty slot — muted glyph + label + em-dash. No more naked dashes.
			parts.append(
				"[color=%s]%s[/color] [color=#5C544A]%s —[/color]"
				% [TIER1_HEX[res_type], glyph, name]
			)
		else:
			var entry: Dictionary = RESOURCES[best_id]
			var tc: Color = color_for_tier(entry["tier"])
			var hex: String = "#" + tc.to_html(false)
			var amt: int = inventory.get(best_id, 0)
			parts.append("[color=%s]%s %s:[/color] %d" % [hex, glyph, entry["name"], amt])

	return "   ".join(parts)


func color_for_tier(tier: int) -> Color:
	return TIER_COLORS.get(tier, Color.WHITE)


# §18.2 scarcity band for a resource id, as a Band enum value. Raw materials
# (entries with no "tier") read Plentiful; processed resources map by tier.
func scarcity_band(id: String) -> int:
	var entry: Dictionary = RESOURCES.get(id, {})
	if entry.is_empty():
		return Band.COMMON
	if not entry.has("tier"):
		return Band.PLENTIFUL
	return TIER_TO_BAND.get(int(entry["tier"]), Band.COMMON)


func band_label(id: String) -> String:
	return BAND_LABELS.get(scarcity_band(id), "")


# True if this resource has a recipe and its research gate (if any) is cleared.
func is_craftable(id: String, researched: Array) -> bool:
	var entry: Dictionary = RESOURCES.get(id, {})
	if entry.is_empty() or not entry.has("recipe") or entry["recipe"] == null:
		return false
	var gate = entry.get("research", null)
	if gate != null and gate != "" and not researched.has(gate):
		return false
	return true


# Research project table. Keys here must match the "research" gate strings used
# in RESOURCES above. Each project has a gold cost and lists what it unlocks.
# Five categories — these are the swimlanes the Research tab renders by.
# "category" on each project must match one of these keys exactly.
const RESEARCH_CATEGORIES: Array[String] = ["cultivation", "forestry", "metallurgy", "husbandry", "lore"]
const RESEARCH_CATEGORY_LABELS: Dictionary = {
	"cultivation": "Cultivation",
	"forestry":    "Forestry",
	"metallurgy":  "Metallurgy",
	"husbandry":   "Husbandry",
	"lore":        "Lore",
}

const RESEARCH_PROJECTS: Dictionary = {
	"cotton_cultivation": {
		"name": "Cotton Cultivation",
		"description": "Commission a study of cotton preparation — enables fine cloth weaving from gathered cotton.",
		"cost_gold": 40,
		"unlocks": ["cloth"],
		"category": "cultivation",
		"tier": 2,
		"prerequisites": [],
	},
	"alloy_research": {
		"name": "Alloy Research",
		"description": "Learn to combine tin and copper into bronze — the first step in serious metallurgy.",
		"cost_gold": 60,
		"unlocks": ["bronze_ingot"],
		"category": "metallurgy",
		"tier": 2,
		"prerequisites": [],
	},
	"blast_furnace": {
		"name": "Blast Furnace",
		"description": "Commission a proper furnace capable of refining iron ore and coal into steel.",
		"cost_gold": 120,
		"unlocks": ["steel_ingot"],
		"category": "metallurgy",
		"tier": 3,
		"prerequisites": ["alloy_research"],
	},
	# ---- Suggested/placeholder projects below this line. They flesh the tree
	# ---- out visually; their `unlocks` reference future content not yet wired
	# ---- to ResourceDB.RESOURCES (the detail panel renders the prettified IDs).
	"forester_guild": {
		"name": "Forester's Guild",
		"description": "Charter a guild of foresters — better axes, better paths, better yields from every wooded tile your scouts walk into.",
		"cost_gold": 50,
		"unlocks": ["seasoned_lumber"],
		"category": "forestry",
		"tier": 2,
		"prerequisites": [],
	},
	"falconry": {
		"name": "Falconry",
		"description": "Raise hunting birds for the mews — their eyes reach further than any rider, and your scouts learn to read the skies.",
		"cost_gold": 55,
		"unlocks": ["scouting_birds"],
		"category": "husbandry",
		"tier": 2,
		"prerequisites": [],
	},
	"cartography": {
		"name": "Cartography",
		"description": "Engage a scribe of maps — distant tiles can be drawn from rumour alone, and your scouts no longer cross the same ridge twice.",
		"cost_gold": 70,
		"unlocks": ["chart_room"],
		"category": "lore",
		"tier": 2,
		"prerequisites": [],
	},
	"apothecary": {
		"name": "Apothecary's Cabinet",
		"description": "Stock the cabinet with bark, willow, and known restoratives. Injured retainers return to the field one week sooner.",
		"cost_gold": 90,
		"unlocks": ["restorative_draught"],
		"category": "husbandry",
		"tier": 3,
		"prerequisites": ["falconry"],
	},
	"tannery": {
		"name": "Tannery",
		"description": "Build a proper tannery beside the lower stream — leather goods for the household, light armour for the squires, and trade against neighbouring estates.",
		"cost_gold": 80,
		"unlocks": ["cured_leather"],
		"category": "cultivation",
		"tier": 3,
		"prerequisites": ["cotton_cultivation", "forester_guild"],
	},
}


# ─────────────────────────────────────────────────────────────────────────────
# Reward Dictionary helpers — the canonical reward shape across the codebase.
#
# Every reward roller (Combat, BattleEvent, StoryEventDB, WorldGenerator)
# returns a Dictionary keyed by ResourceDB ids, valued ints. These helpers
# do the four operations the old `ResourceBundle` class wrapped:
#
#   merge(target, addition)     — accumulate one bundle into another in-place
#   scale(dict, factor)         — multiply every value (round to int)
#   subtract_from(inv, cost)    — atomic deduct from inventory, bool result
#   describe(dict)              — formatted string, sorted tier-ascending
#   bundle_is_empty(dict)       — true if every value is 0 (filters keys
#                                  that exist but hold a zero count)
#
# Using a plain Dictionary instead of a typed Resource class means:
#   - no dual key namespace (ResourceBundle's wood/fibres/copper_ore vs the
#     canonical logs/plant_fibres/copper_ore)
#   - any reward roller can mention any resource (feathers, hides, etc.)
#     without extending a fixed-shape class
#   - inventory + reward + cost all share the same shape, so merging /
#     subtracting / comparing is one operation
# ─────────────────────────────────────────────────────────────────────────────

# Add `addition` into `target` in place, summing per key. Negative values are
# clamped to zero in the result so callers can safely use this for both
# adding rewards and applying penalties (penalty paths should use subtract_from
# instead when atomicity matters).
func merge(target: Dictionary, addition: Dictionary) -> void:
	for id: String in addition:
		var v: int = int(addition[id])
		if v == 0:
			continue
		var new_v: int = int(target.get(id, 0)) + v
		if new_v <= 0:
			target.erase(id)
		else:
			target[id] = new_v


# Multiply every value by `factor` (rounded to nearest int, minimum 0).
# Returns a new Dictionary — does not mutate the input. Values rounded to
# zero are pruned so the result is "tight" (no zero entries).
func scale(dict: Dictionary, factor: float) -> Dictionary:
	var out: Dictionary = {}
	for id: String in dict:
		var v: int = roundi(float(dict[id]) * factor)
		if v > 0:
			out[id] = v
	return out


# True if every value in `dict` is zero (or the dict is empty). Callers can
# also use `dict.is_empty()` directly when they know zero values are pruned;
# this helper is for paths where a roller might emit `{logs: 0}` and the
# caller wants to treat that as "no reward."
func bundle_is_empty(dict: Dictionary) -> bool:
	if dict.is_empty():
		return true
	for id: String in dict:
		if int(dict[id]) != 0:
			return false
	return true


# Deduct `cost` from `inventory` in place. Returns false (and leaves inventory
# untouched) if any line item would go negative. Atomic — used by crafting,
# upkeep checks, and any "you can afford this exact bundle" path.
func subtract_from(inventory: Dictionary, cost: Dictionary) -> bool:
	# Affordability pass first so partial deductions don't leak.
	for id: String in cost:
		var need: int = int(cost[id])
		if need <= 0:
			continue
		if int(inventory.get(id, 0)) < need:
			return false
	for id: String in cost:
		var need2: int = int(cost[id])
		if need2 <= 0:
			continue
		var left: int = int(inventory.get(id, 0)) - need2
		if left <= 0:
			inventory.erase(id)
		else:
			inventory[id] = left
	return true


# Format a reward / inventory dict for display. Sorted tier-ascending then
# alphabetical so the output is stable across rolls and easy to scan. Raw
# materials (no `tier` field in RESOURCES) sort as tier 0 — they're the
# entry-level stuff and read first.
func describe(dict: Dictionary) -> String:
	if dict.is_empty():
		return "—"
	var rows: Array = []
	for id: String in dict:
		var v: int = int(dict[id])
		if v == 0:
			continue
		var entry: Dictionary = RESOURCES.get(id, {})
		var label: String = entry.get("name", id.capitalize())
		var tier: int = int(entry.get("tier", 0))
		rows.append({"label": label, "tier": tier, "amount": v})
	rows.sort_custom(func(a, b):
		if a["tier"] != b["tier"]:
			return a["tier"] < b["tier"]
		return a["label"] < b["label"]
	)
	var bits: PackedStringArray = PackedStringArray()
	for row: Dictionary in rows:
		bits.append("%s:%d" % [row["label"], row["amount"]])
	return " ".join(bits)


# True if the player's inventory covers all recipe inputs for this resource.
func can_afford(id: String, inventory: Dictionary) -> bool:
	var entry: Dictionary = RESOURCES.get(id, {})
	if entry.is_empty() or not entry.has("recipe") or entry["recipe"] == null:
		return false
	for input_id: String in entry["recipe"]:
		if inventory.get(input_id, 0) < entry["recipe"][input_id]:
			return false
	return true


# Reputation band → display label. Used by the HUD chip and any other surface
# that wants a one-word descriptor instead of a raw number.
func reputation_label(rep: int) -> String:
	return _reputation_label(rep)


func reputation_color(rep: int) -> Color:
	return Color(_reputation_hex(rep))


# Bands chosen so the player crosses a label every ~10 reputation, both ways.
# Negatives are darker; positives warm up; the legend tier reads bright gold.
func _reputation_label(rep: int) -> String:
	if rep <= -30: return "Outcast"
	if rep <= -10: return "Disreputable"
	if rep <  0:   return "Suspect"
	if rep <  10:  return "Known"
	if rep <  20:  return "Respected"
	if rep <  40:  return "Renowned"
	return "Legendary"


func _reputation_hex(rep: int) -> String:
	if rep <= -30: return "#8A4A4A"
	if rep <= -10: return "#A86A55"
	if rep <  0:   return "#B89A6A"
	if rep <  10:  return "#C4A24B"
	if rep <  20:  return "#E6C25A"
	if rep <  40:  return "#FFD61A"
	return "#FFEB7A"
