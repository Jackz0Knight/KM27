class_name Crafting
extends RefCounted

# Centralises all inventory-mutation for crafting and caravan reward delivery.
# Planning._do_craft() and WeeklySummary._on_caravan_pick() call helpers here
# instead of writing to GameState.inventory directly — all reward delivery is
# auditable in one place and mirrors Resolution._apply_reward() for combat loot.


static func craft(gs: Node, resource_id: String) -> void:
	var entry: Dictionary = ResourceDB.RESOURCES.get(resource_id, {})
	for input_id: String in entry["recipe"]:
		gs.inventory[input_id] = gs.inventory.get(input_id, 0) - entry["recipe"][input_id]
	gs.inventory[resource_id] = gs.inventory.get(resource_id, 0) + 1
	if not gs.crafted_ids.has(resource_id):
		gs.crafted_ids.append(resource_id)


## §18.4 — forge a crafted item from resources + gold into the stockpile.
## Instant, one-click. Caps at one craft per recipe per Planning week (the
## `items_crafted_this_week` guard, cleared each week). Returns a result dict
## the Crafting tab renders: `{ok, reason?, slot, id, label}`.
static func craft_item(gs: Node, output_id: String) -> Dictionary:
	var recipe: Dictionary = ItemRecipeDB.get_recipe(output_id)
	if recipe.is_empty():
		return {"ok": false, "reason": "no_recipe"}
	if not ItemRecipeDB.is_unlocked(output_id, gs.researched):
		return {"ok": false, "reason": "locked"}
	if gs.items_crafted_this_week.has(output_id):
		return {"ok": false, "reason": "already_crafted"}
	if not ItemRecipeDB.can_afford(output_id, gs.inventory, gs.gold):
		return {"ok": false, "reason": "cant_afford"}

	for input_id: String in recipe.get("inputs", {}):
		gs.inventory[input_id] = gs.inventory.get(input_id, 0) - int(recipe["inputs"][input_id])
	gs.gold -= int(recipe.get("base_gold", 0))

	# §18.5 — roll a quality bracket biased by the recipe's `bracket_bias`.
	var qroll: Dictionary = Quality.roll(int(recipe.get("bracket_bias", Quality.DEFAULT)))
	var bracket: int = int(qroll["bracket"])

	var slot: String = ItemRecipeDB.slot_for(output_id)
	gs.item_stockpile.append({"slot": slot, "id": output_id, "bracket": bracket, "mods": {}})
	gs.items_crafted_this_week.append(output_id)
	return {
		"ok": true, "slot": slot, "id": output_id,
		"label": ItemRecipeDB.display_name(output_id),
		"bracket": bracket, "forge_sang": bool(qroll.get("forge_sang", false)),
	}


static func accept_caravan_offer(gs: Node, idx: int) -> void:
	gs.merchant_pick = idx
	# Caravan offers are now plain Dictionaries (ResourceDB ids → ints) per
	# the resource-system unification — same shape as every other reward.
	var offer: Dictionary = gs.merchant_offers[idx]
	ResourceDB.merge(gs.inventory, offer)
	gs.last_battle_result["reward"] = offer.duplicate(true)
