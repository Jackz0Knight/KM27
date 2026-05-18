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


static func accept_caravan_offer(gs: Node, idx: int) -> void:
	gs.merchant_pick = idx
	var offer: ResourceBundle = gs.merchant_offers[idx]
	var inv_delta: Dictionary = offer.to_inventory_dict()
	for id: String in inv_delta:
		gs.inventory[id] = gs.inventory.get(id, 0) + inv_delta[id]
	gs.last_battle_result["reward"] = offer
