class_name ItemRecipeDB
extends RefCounted

# §18.4 — item crafting recipes. Distinct from ResourceDB recipes (which are
# resource→resource processing): these consume resources + gold and forge a
# crafted *item* (a weapon or armour) into the household stockpile.
#
# Keyed by output item id (the id in Weapon.CATALOGUE / Armour.CATALOGUE) — each
# craftable item has exactly one recipe. The output's slot is derived from which
# catalogue holds the id, so a recipe never has to declare weapon-vs-armour.
#
# `bracket_bias` is the centre of the §18.5 quality roll (0 Terrible … 6
# Legendary; 2 = Ok, 3 = Good). It's carried now but only consumed once the
# quality layer ships, so recipes don't need re-touching then.
#
# `research_gate` is a RESEARCH_PROJECTS id (or null) — the recipe only appears
# in the Crafting tab once that project is researched, the same gate model the
# resource recipes use.

const RECIPES: Dictionary = {
	# --- Weapons ---
	"dagger": {
		"inputs": {"iron_ingot": 1}, "base_gold": 4,
		"bracket_bias": 2, "research_gate": null,
	},
	"spear": {
		"inputs": {"planks": 2, "copper": 1}, "base_gold": 6,
		"bracket_bias": 2, "research_gate": null,
	},
	"arming_sword": {
		"inputs": {"iron_ingot": 2, "planks": 1}, "base_gold": 10,
		"bracket_bias": 3, "research_gate": null,
	},
	"longbow": {
		"inputs": {"timber_plank": 2, "spidersilk": 1}, "base_gold": 8,
		"bracket_bias": 3, "research_gate": "forester_guild",
	},
	"bastard_sword": {
		"inputs": {"steel_ingot": 2, "timber_plank": 1}, "base_gold": 16,
		"bracket_bias": 3, "research_gate": "blast_furnace",
	},
	# --- Armour ---
	"padded": {
		"inputs": {"plant_weave": 2}, "base_gold": 4,
		"bracket_bias": 2, "research_gate": null,
	},
	"studded_leather": {
		"inputs": {"leather": 2, "copper": 1}, "base_gold": 8,
		"bracket_bias": 2, "research_gate": "tannery",
	},
	"chainmail": {
		"inputs": {"iron_ingot": 3}, "base_gold": 12,
		"bracket_bias": 3, "research_gate": null,
	},
	"half_plate": {
		"inputs": {"steel_ingot": 2, "leather": 1}, "base_gold": 18,
		"bracket_bias": 3, "research_gate": "blast_furnace",
	},
	"field_plate": {
		"inputs": {"steel_ingot": 3}, "base_gold": 24,
		"bracket_bias": 4, "research_gate": "blast_furnace",
	},
}


static func has_recipe(output_id: String) -> bool:
	return RECIPES.has(output_id)


static func get_recipe(output_id: String) -> Dictionary:
	return RECIPES.get(output_id, {})


static func all_ids() -> Array:
	return RECIPES.keys()


## "weapon" if the output id is a weapon, else "armour".
static func slot_for(output_id: String) -> String:
	return "weapon" if Weapon.CATALOGUE.has(output_id) else "armour"


static func display_name(output_id: String) -> String:
	if Weapon.CATALOGUE.has(output_id):
		return Weapon.display_name(output_id)
	return Armour.display_name(output_id)


## One-line catalogue description (dmg/armour stats) for tooltips.
static func describe(output_id: String) -> String:
	if Weapon.CATALOGUE.has(output_id):
		return Weapon.describe(output_id)
	return Armour.describe(output_id)


## Research-gated availability. Null/empty gate = always available.
static func is_unlocked(output_id: String, researched: Array) -> bool:
	var r: Dictionary = RECIPES.get(output_id, {})
	if r.is_empty():
		return false
	var gate = r.get("research_gate", null)
	return gate == null or gate == "" or researched.has(gate)


## True if the player has the gold and every input material in hand.
static func can_afford(output_id: String, inventory: Dictionary, gold: int) -> bool:
	var r: Dictionary = RECIPES.get(output_id, {})
	if r.is_empty():
		return false
	if gold < int(r.get("base_gold", 0)):
		return false
	for input_id: String in r.get("inputs", {}):
		if inventory.get(input_id, 0) < int(r["inputs"][input_id]):
			return false
	return true
