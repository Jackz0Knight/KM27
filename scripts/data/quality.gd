class_name Quality
extends RefCounted

# §18.5 — item quality brackets. A crafted item rolls a bracket at forge time;
# loot drops come in at a fixed bracket by rarity. The bracket scales the item's
# effective power by a percentage (Terrible −30% … Legendary +75%), applied to
# weapon damage and armour rating in BOTH combat layers (the strategy estimate
# in Combat and the blow-by-blow CombatSim).
#
# Quality is INDEPENDENT of rarity (where the item came from) — a Common sword
# can roll Legendary and outclass a Rare drop. That independence is the headline
# of the system (§18.5).
#
# Back-compat: OK (2) is the neutral bracket (×1.0). Any item with no stored
# bracket defaults to OK, so existing saves and un-stamped gear behave exactly
# as before — this layer adds zero rebalance on its own.
#
# `mods` is a per-instance additive layer (§18.5 rolled modifiers) — reserved
# and persisted now, lightly applied here, fully rolled in a later pass.

enum Bracket { TERRIBLE, POOR, OK, GOOD, EXCELLENT, MASTERWORK, LEGENDARY }
const DEFAULT: int = Bracket.OK

const LABELS: Dictionary = {
	Bracket.TERRIBLE: "Terrible", Bracket.POOR: "Poor", Bracket.OK: "Ok",
	Bracket.GOOD: "Good", Bracket.EXCELLENT: "Excellent",
	Bracket.MASTERWORK: "Masterwork", Bracket.LEGENDARY: "Legendary",
}
const PCT: Dictionary = {
	Bracket.TERRIBLE: -0.30, Bracket.POOR: -0.15, Bracket.OK: 0.0,
	Bracket.GOOD: 0.15, Bracket.EXCELLENT: 0.30,
	Bracket.MASTERWORK: 0.50, Bracket.LEGENDARY: 0.75,
}
const MARKERS: Dictionary = {
	Bracket.TERRIBLE: "▼▼", Bracket.POOR: "▼", Bracket.OK: "",
	Bracket.GOOD: "▲", Bracket.EXCELLENT: "▲▲",
	Bracket.MASTERWORK: "▲▲▲", Bracket.LEGENDARY: "★",
}
const COLORS: Dictionary = {
	Bracket.TERRIBLE: Color(0.74, 0.30, 0.26), Bracket.POOR: Color(0.82, 0.55, 0.34),
	Bracket.OK: Color(0.78, 0.74, 0.62), Bracket.GOOD: Color(0.52, 0.78, 0.46),
	Bracket.EXCELLENT: Color(0.40, 0.74, 0.92), Bracket.MASTERWORK: Color(0.74, 0.52, 0.92),
	Bracket.LEGENDARY: Color(1.00, 0.84, 0.28),
}


static func clamp_bracket(b: int) -> int:
	return clampi(b, Bracket.TERRIBLE, Bracket.LEGENDARY)


static func label(b: int) -> String:
	return LABELS.get(clamp_bracket(b), "Ok")


static func multiplier(b: int) -> float:
	return 1.0 + float(PCT.get(clamp_bracket(b), 0.0))


static func marker(b: int) -> String:
	return MARKERS.get(clamp_bracket(b), "")


static func color(b: int) -> Color:
	return COLORS.get(clamp_bracket(b), Color.WHITE)


## " · Excellent ▲▲" for non-Ok brackets, "" for Ok — appended to item lines.
static func suffix(b: int) -> String:
	if clamp_bracket(b) == Bracket.OK:
		return ""
	var mk: String = marker(b)
	return " · %s%s" % [label(b), (" " + mk) if mk != "" else ""]


## Scale an int value by the bracket multiplier, never below 0.
static func scale(value: int, b: int) -> int:
	return maxi(0, roundi(float(value) * multiplier(b)))


## Strategy-layer weapon damage contribution: avg of the damage range, scaled.
static func weapon_damage(weapon_id: String, b: int = DEFAULT) -> int:
	var e: Dictionary = Weapon.CATALOGUE.get(weapon_id, {})
	if e.is_empty():
		return 0
	var avg: float = float(int(e.get("damage_min", 0)) + int(e.get("damage_max", 0))) / 2.0
	return maxi(0, floori(avg * multiplier(b)))


## Strategy-layer armour resistance: power_rating, scaled.
static func armour_resistance(armour_id: String, b: int = DEFAULT) -> int:
	return scale(Armour.power_rating(armour_id), b)


## Effective weapon entry for the sim — a duplicated catalogue dict with
## damage_min/max scaled by the bracket (plus any per-instance mods). The
## catalogue itself is never touched.
static func weapon_entry(weapon_id: String, b: int = DEFAULT, mods: Dictionary = {}) -> Dictionary:
	var e: Dictionary = Weapon.get_entry(weapon_id).duplicate(true)
	e["damage_min"] = scale(int(e.get("damage_min", 0)), b)
	e["damage_max"] = maxi(int(e["damage_min"]), scale(int(e.get("damage_max", 0)), b))
	if mods.has("damage_max"):
		e["damage_max"] = int(e["damage_max"]) + int(mods["damage_max"])
	if mods.has("hit_bonus"):
		e["hit_bonus"] = int(e.get("hit_bonus", 0)) + int(mods["hit_bonus"])
	return e


## Effective armour entry for the sim — base_rating scaled by the bracket.
static func armour_entry(armour_id: String, b: int = DEFAULT, mods: Dictionary = {}) -> Dictionary:
	var e: Dictionary = Armour.get_entry(armour_id).duplicate(true)
	e["base_rating"] = scale(int(e.get("base_rating", 0)), b)
	if mods.has("armour_resistance"):
		e["base_rating"] = int(e["base_rating"]) + int(mods["armour_resistance"])
	return e


## §18.5 biased bracket roll for crafting. `bias` is the recipe's centre; the
## spread is ±2 by weighted RNG peaking at the centre; a 2% "the forge sang"
## crit bumps the result up one step. Returns {bracket, forge_sang}.
static func roll(bias: int) -> Dictionary:
	var r: int = RNG.randi_range(1, 13)
	var offset: int
	if r <= 1:
		offset = -2
	elif r <= 4:
		offset = -1
	elif r <= 9:
		offset = 0
	elif r <= 12:
		offset = 1
	else:
		offset = 2
	var b: int = clamp_bracket(bias + offset)
	var sang: bool = false
	if RNG.randf_range(0.0, 1.0) < 0.02:
		b = mini(Bracket.LEGENDARY, b + 1)
		sang = true
	return {"bracket": b, "forge_sang": sang}


## Fixed bracket for a loot drop, by rarity (§18.5). Most loot is Ok; Heirlooms
## come in at Excellent, Grand-Tournament Heirlooms at Masterwork.
static func drop_bracket(rarity: int, grand: bool = false) -> int:
	if rarity >= Weapon.Rarity.HEIRLOOM:
		return Bracket.MASTERWORK if grand else Bracket.EXCELLENT
	return Bracket.OK
