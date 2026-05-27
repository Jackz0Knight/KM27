extends Node

# Resource database — full tree of raw materials and processed resources per
# GDD §14 expansion. Registered as an autoload so any system can query it.

enum ResType { FABRIC, TIMBER, METAL }

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
