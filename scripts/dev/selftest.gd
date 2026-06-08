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
	_test_quality()
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


func _test_quality() -> void:
	_check(is_equal_approx(Quality.multiplier(Quality.Bracket.OK), 1.0), "OK = ×1.0")
	_check(is_equal_approx(Quality.multiplier(Quality.Bracket.EXCELLENT), 1.30), "Excellent = ×1.30")
	_check(Quality.scale(10, Quality.Bracket.GOOD) == 12, "scale 10×1.15 → 12")
	_check(Quality.suffix(Quality.Bracket.OK) == "", "Ok has no suffix")
	_check(Quality.suffix(Quality.Bracket.EXCELLENT).find("Excellent") != -1, "Excellent suffix labelled")
	_check(Quality.drop_bracket(Weapon.Rarity.COMMON) == Quality.Bracket.OK, "common drop = Ok")
	_check(Quality.drop_bracket(Weapon.Rarity.HEIRLOOM) == Quality.Bracket.EXCELLENT, "heirloom drop = Excellent")
	_check(Quality.drop_bracket(Weapon.Rarity.HEIRLOOM, true) == Quality.Bracket.MASTERWORK, "grand heirloom = Masterwork")

	# Bracket scales the strategy-layer weapon contribution monotonically.
	var ok_dmg: int = Quality.weapon_damage("arming_sword", Quality.Bracket.OK)
	var exc_dmg: int = Quality.weapon_damage("arming_sword", Quality.Bracket.EXCELLENT)
	var poor_dmg: int = Quality.weapon_damage("arming_sword", Quality.Bracket.POOR)
	_check(exc_dmg > ok_dmg and ok_dmg > poor_dmg, "weapon dmg scales with quality")
	_check(Combat.weapon_damage_contrib("arming_sword", Quality.Bracket.EXCELLENT) == exc_dmg, "Combat reads quality")

	# A biased roll always lands in-range.
	var all_in_range: bool = true
	for _i in range(50):
		var b: int = int(Quality.roll(3)["bracket"])
		if b < Quality.Bracket.TERRIBLE or b > Quality.Bracket.LEGENDARY:
			all_in_range = false
	_check(all_in_range, "50 biased rolls all in range")

	# Forged quality travels onto a unit and back through equip/unequip.
	GameState.start_run(999)
	GameState.inventory["iron_ingot"] = 5
	GameState.gold = 100
	var cres: Dictionary = Crafting.craft_item(GameState, "chainmail")
	var forged_bracket: int = int(cres.get("bracket", -1))
	var idx: int = GameState.item_stockpile.size() - 1
	var knight: Unit = Unit.new()   # roster isn't assembled in this harness
	var ok: bool = ItemDrops.equip_from_stockpile(GameState, knight, idx)
	_check(ok, "equip succeeds")
	_check(knight.armour_id == "chainmail", "armour id set on equip")
	_check(knight.armour_bracket == forged_bracket, "forged quality follows onto the unit")


func _check(cond: bool, label: String) -> void:
	if not cond:
		_fails += 1
	print("[SELFTEST] %s — %s" % ["PASS" if cond else "FAIL", label])
