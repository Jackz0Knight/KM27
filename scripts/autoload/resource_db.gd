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
# Gold (gold), then best held resource per type with tier colour.
func resource_hud_bbcode(gold: int, inventory: Dictionary) -> String:
	var parts: Array[String] = []
	parts.append("[color=#FFD61A]Gold: %d[/color]" % gold)
	var type_labels: Dictionary = {
		ResType.FABRIC: "Fabric",
		ResType.TIMBER: "Timber",
		ResType.METAL:  "Metal",
	}
	for res_type: int in [ResType.FABRIC, ResType.TIMBER, ResType.METAL]:
		var best_id: String = best_for_type(inventory, res_type)
		if best_id == "":
			parts.append("[color=#555555]— %s —[/color]" % type_labels[res_type])
		else:
			var entry: Dictionary = RESOURCES[best_id]
			var tc: Color = color_for_tier(entry["tier"])
			var hex: String = "#" + tc.to_html(false)
			var amt: int = inventory.get(best_id, 0)
			parts.append("[color=%s]%s[/color]: %d" % [hex, entry["name"], amt])
	return "  ".join(parts)


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
const RESEARCH_PROJECTS: Dictionary = {
	"cotton_cultivation": {
		"name": "Cotton Cultivation",
		"description": "Commission a study of cotton preparation — enables fine cloth weaving from gathered cotton.",
		"cost_gold": 40,
		"unlocks": ["cloth"],
		"category": "fabric",
		"tier": 2,
		"prerequisites": [],
	},
	"alloy_research": {
		"name": "Alloy Research",
		"description": "Learn to combine tin and copper into bronze — the first step in serious metallurgy.",
		"cost_gold": 60,
		"unlocks": ["bronze_ingot"],
		"category": "metal",
		"tier": 2,
		"prerequisites": [],
	},
	"blast_furnace": {
		"name": "Blast Furnace",
		"description": "Commission a proper furnace capable of refining iron ore and coal into steel.",
		"cost_gold": 120,
		"unlocks": ["steel_ingot"],
		"category": "metal",
		"tier": 3,
		"prerequisites": ["alloy_research"],
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
