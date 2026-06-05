class_name ItemDrops
extends RefCounted

# Loot pipeline for weapons + armour. Resolution.gd calls into here after a
# winning battle to roll a chance of dropping a new item into the household
# armoury (GameState.item_stockpile). The drop chance + rarity ceiling vary
# by event type — castle assaults push higher, ambush wins lower, the Grand
# Tournament guarantees an Heirloom.
#
# Pure functions: take GameState, mutate `item_stockpile`, return the drop
# dictionary (or {} when nothing dropped) so callers can surface it on the
# Weekly Summary rewards section.

# Drop chance per win type. Probabilities chosen to feel like welcome
# surprises rather than mandatory pulls — over a 48-week run the player
# should pick up ~6–10 items, not 30.
const CHANCE_PILLAGE: float       = 0.18
const CHANCE_ASSAULT: float       = 0.45
const CHANCE_HOME_DEFENCE: float  = 0.12
const CHANCE_AMBUSH: float        = 0.20
const CHANCE_TOURNAMENT: float    = 0.30


# Roll a drop after an Away-Pillage / Away-Assault win. Castle assaults pull
# from a richer pool (Rare possible). Pillage stays at Uncommon ceiling.
static func roll_away_drop(gs: Node, mode: String) -> Dictionary:
	if mode == "assault":
		return _try_drop(gs, CHANCE_ASSAULT, _weighted_pool([
			[Weapon.Rarity.COMMON, 30],
			[Weapon.Rarity.UNCOMMON, 50],
			[Weapon.Rarity.RARE, 20],
		]))
	return _try_drop(gs, CHANCE_PILLAGE, _weighted_pool([
		[Weapon.Rarity.COMMON, 60],
		[Weapon.Rarity.UNCOMMON, 35],
		[Weapon.Rarity.RARE, 5],
	]))


# Roll a drop after winning a Home Battle. Defenders pick over the field
# afterwards — usually nothing, occasionally an Uncommon kit piece.
static func roll_home_defence_drop(gs: Node) -> Dictionary:
	return _try_drop(gs, CHANCE_HOME_DEFENCE, _weighted_pool([
		[Weapon.Rarity.COMMON, 70],
		[Weapon.Rarity.UNCOMMON, 28],
		[Weapon.Rarity.RARE, 2],
	]))


# Roll a drop after winning a Bandit Ambush battle event.
static func roll_ambush_drop(gs: Node) -> Dictionary:
	return _try_drop(gs, CHANCE_AMBUSH, _weighted_pool([
		[Weapon.Rarity.COMMON, 70],
		[Weapon.Rarity.UNCOMMON, 28],
		[Weapon.Rarity.RARE, 2],
	]))


# Tournament prize. Rare-or-better — winning the lists earns you a named blade.
static func roll_tournament_drop(gs: Node) -> Dictionary:
	return _try_drop(gs, CHANCE_TOURNAMENT, _weighted_pool([
		[Weapon.Rarity.UNCOMMON, 65],
		[Weapon.Rarity.RARE, 35],
	]))


# Grand Tournament — guaranteed Heirloom. Win the realm, take the heirloom.
static func roll_grand_tournament_drop(gs: Node) -> Dictionary:
	return _drop_at_rarity(gs, Weapon.Rarity.HEIRLOOM, true)


# ---------- internals ----------

# Roll a chance gate; if it passes, pull a rarity from the weighted pool and
# drop an item of that rarity.
static func _try_drop(gs: Node, chance: float, rarity_pool: Array[int]) -> Dictionary:
	if RNG.randf_range(0.0, 1.0) >= chance:
		return {}
	if rarity_pool.is_empty():
		return {}
	var target_rarity: int = rarity_pool[RNG.randi_range(0, rarity_pool.size() - 1)]
	return _drop_at_rarity(gs, target_rarity)


# Public alias for `_drop_at_rarity` — exposes the rarity-targeted drop so
# Resolution's data-driven away modes (AwayModeDB) can request a specific
# rarity without going through one of the named roll_*_drop functions.
static func drop_at_rarity(gs: Node, target_rarity: int) -> Dictionary:
	return _drop_at_rarity(gs, target_rarity)


# Drop a specific rarity. Picks weapon vs armour 50/50, then a random id of
# that rarity from the respective catalog. Returns the drop entry.
static func _drop_at_rarity(gs: Node, target_rarity: int, grand: bool = false) -> Dictionary:
	var slot: String = "weapon" if RNG.randf_range(0.0, 1.0) < 0.5 else "armour"
	var candidates: Array[String] = (
		Weapon.ids_of_rarity(target_rarity)
		if slot == "weapon"
		else Armour.ids_of_rarity(target_rarity)
	)
	# Fallback: if a tier is empty on one side, swap. Shouldn't happen with
	# the current catalog but guards against future deletions.
	if candidates.is_empty():
		slot = "armour" if slot == "weapon" else "weapon"
		candidates = (
			Weapon.ids_of_rarity(target_rarity)
			if slot == "weapon"
			else Armour.ids_of_rarity(target_rarity)
		)
	if candidates.is_empty():
		return {}
	var picked_id: String = candidates[RNG.randi_range(0, candidates.size() - 1)]
	# §18.5 — loot comes in at a fixed quality by rarity (Heirlooms shine).
	var entry: Dictionary = {
		"slot": slot, "id": picked_id,
		"bracket": Quality.drop_bracket(target_rarity, grand), "mods": {},
	}
	gs.item_stockpile.append(entry)
	return entry


# Expand a list of [rarity, weight] pairs into a flat repeating array, the
# cheapest possible weighted-pick. Pool sizes are tiny so the redundancy is
# fine. Returns int array so the caller can pass to randi_range indexing.
static func _weighted_pool(pairs: Array) -> Array[int]:
	var out: Array[int] = []
	for pair in pairs:
		var r: int = int(pair[0])
		var weight: int = int(pair[1])
		for _i in range(weight):
			out.append(r)
	return out


# UI helper — what to call the new item in the Weekly Summary line.
static func describe_drop(drop: Dictionary) -> String:
	if drop.is_empty():
		return ""
	var slot: String = str(drop.get("slot", ""))
	var id: String = str(drop.get("id", ""))
	var rarity_label: String
	var item_name: String
	if slot == "weapon":
		rarity_label = Weapon.rarity_label(id)
		item_name = Weapon.display_name(id)
	else:
		rarity_label = Armour.rarity_label(id)
		item_name = Armour.display_name(id)
	return "%s — %s" % [item_name, rarity_label]


# ---------- equip / swap ----------

# Move a stockpile item onto a unit, sending the unit's current item back to
# the stockpile. Returns true on success; false if the entry was invalid.
static func equip_from_stockpile(gs: Node, unit: Unit, stockpile_index: int) -> bool:
	if stockpile_index < 0 or stockpile_index >= gs.item_stockpile.size():
		return false
	var entry: Dictionary = gs.item_stockpile[stockpile_index]
	var slot: String = str(entry.get("slot", ""))
	var new_id: String = str(entry.get("id", ""))
	if new_id == "":
		return false
	# §18.5 — quality travels with the item instance, both onto the unit and
	# back into the armoury on a swap, so nothing's lost or silently reset.
	var new_bracket: int = int(entry.get("bracket", Quality.DEFAULT))
	var new_mods: Dictionary = entry.get("mods", {})
	var is_weapon: bool = slot == "weapon"
	var old_id: String = unit.weapon_id if is_weapon else unit.armour_id
	var old_bracket: int = unit.weapon_bracket if is_weapon else unit.armour_bracket
	var old_mods: Dictionary = unit.weapon_mods if is_weapon else unit.armour_mods
	gs.item_stockpile.remove_at(stockpile_index)
	if old_id != "":
		gs.item_stockpile.append({"slot": slot, "id": old_id, "bracket": old_bracket, "mods": old_mods})
	if is_weapon:
		unit.weapon_id = new_id
		unit.weapon_bracket = new_bracket
		unit.weapon_mods = new_mods
	else:
		unit.armour_id = new_id
		unit.armour_bracket = new_bracket
		unit.armour_mods = new_mods
	return true
