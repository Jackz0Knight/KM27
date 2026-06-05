extends Node

# Headless logic self-test for systems that the boot-only validation can't
# exercise. Run with autoloads bound (a real scene, not --script mode):
#   godot --headless --path . res://scenes/dev/selftest.tscn
# Prints PASS/FAIL per check and a final failure count, then quits.
#
# Throwaway / dev-only. Grows alongside the §18 arc.

var _fails: int = 0

func _ready() -> void:
	_test_economy()
	_test_item_crafting()
	print("[SELFTEST] complete — %d failure(s)" % _fails)
	get_tree().quit()


func _test_economy() -> void:
	GameState.start_run(777)
	_check(Economy.upkeep_cost(GameState) == GameState.roster.size() * 5, "upkeep = units × 5")
	_check(Economy.tournament_rep_bonus(40) == 10, "rep bonus 40/4 = 10")
	_check(Economy.tournament_rep_bonus(1000) == Economy.TOURNAMENT_REP_CAP, "rep bonus caps")
	_check(Economy.tournament_rep_bonus(-50) == 0, "rep bonus floors at 0")
	_check(Economy.tavern_riot_gold(16) == 6 + 2, "tavern riot gold w16")
	_check(ResourceDB.band_label("logs") == "Plentiful", "raw → Plentiful band")
	_check(ResourceDB.band_label("steel_ingot") == "Rare", "T3 → Rare band")


func _test_item_crafting() -> void:
	GameState.start_run(12345)
	GameState.inventory["iron_ingot"] = 5
	GameState.gold = 100

	var n0: int = GameState.item_stockpile.size()
	var r: Dictionary = Crafting.craft_item(GameState, "chainmail")
	_check(r.get("ok", false), "chainmail forge succeeds")
	_check(GameState.item_stockpile.size() == n0 + 1, "stockpile grows by 1")
	_check(GameState.item_stockpile.back()["id"] == "chainmail", "correct item stored")
	_check(GameState.item_stockpile.back()["slot"] == "armour", "slot derived as armour")
	_check(GameState.inventory["iron_ingot"] == 2, "3 iron consumed")
	_check(GameState.gold == 88, "12 gold spent")

	var r2: Dictionary = Crafting.craft_item(GameState, "chainmail")
	_check(not r2.get("ok", true) and r2.get("reason", "") == "already_crafted", "one-per-week cap")

	GameState.inventory["steel_ingot"] = 9
	var r3: Dictionary = Crafting.craft_item(GameState, "field_plate")
	_check(not r3.get("ok", true) and r3.get("reason", "") == "locked", "research gate blocks")

	GameState.researched.append("blast_furnace")
	var r4: Dictionary = Crafting.craft_item(GameState, "field_plate")
	_check(r4.get("ok", false), "forges once researched")

	# New week clears the cap; top up materials (the first craft spent the iron)
	# to prove the cap-clear and the material gate are independent.
	GameState._clear_week_buffers()
	GameState.inventory["iron_ingot"] = 5
	var r5: Dictionary = Crafting.craft_item(GameState, "chainmail")
	_check(r5.get("ok", false), "new week re-enables recipe")


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails += 1
	print("[SELFTEST] %s — %s" % ["PASS" if cond else "FAIL", label])
