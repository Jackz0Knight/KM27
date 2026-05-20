class_name Weapon
extends RefCounted

# Weapon data definitions. Units carry a weapon_id string; CombatUnit looks up
# the entry from CATALOGUE to derive combat stats.
#
# hit_bonus: integer offset applied as hit_bonus × 0.01 in CombatUnit.
#   Positive = easier to connect (spear reach, dagger speed).
#   Negative = harder to land accurately (heavy axe swing).
# crit_bonus: added directly to crit_chance as a float.
# primary_skill: strategy-layer stat that drives accuracy with this weapon.
#   "swordsmanship" for all melee, "archery" for all ranged.
# damage_min/max: base damage before Strength bonus is added.
# power_rating: integer 0–5 added to formation-battle unit_power. The
#   strategy layer reads this directly from `Combat.weapon_power_rating`;
#   no derived formula so balance tuning happens in one place.
# rarity: 0 Common, 1 Uncommon, 2 Rare, 3 Heirloom. Drives loot pools and
#   the colour tint of the item name on UI cards. Common items can roll
#   from any battle; Heirlooms only appear as Grand Tournament prizes or
#   specific seeded drops.

enum WeaponType { UNARMED, SWORD, AXE, SPEAR, DAGGER, BOW, CROSSBOW, MACE, POLEARM }
enum RangeType  { MELEE, RANGED }
enum Rarity     { COMMON, UNCOMMON, RARE, HEIRLOOM }


const RARITY_LABELS: Dictionary = {
	Rarity.COMMON:   "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE:     "Rare",
	Rarity.HEIRLOOM: "Heirloom",
}

# Colour ramp for item names on cards / popups. Same intent as the resource
# tier colours — grey baseline, gold for the dramatic stuff.
const RARITY_COLORS: Dictionary = {
	Rarity.COMMON:   Color(0.78, 0.74, 0.62),
	Rarity.UNCOMMON: Color(0.55, 0.85, 0.55),
	Rarity.RARE:     Color(0.55, 0.75, 0.95),
	Rarity.HEIRLOOM: Color(1.0, 0.84, 0.42),
}


const CATALOGUE: Dictionary = {
	"unarmed": {
		"name":          "Unarmed",
		"weapon_type":   WeaponType.UNARMED,
		"damage_min":    1,
		"damage_max":    2,
		"hit_bonus":     0,
		"crit_bonus":    0.00,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  0,
		"rarity":        Rarity.COMMON,
		"flavour":       "Bare hands. Better than nothing — but not much.",
	},
	"shortsword": {
		"name":          "Shortsword",
		"weapon_type":   WeaponType.SWORD,
		"damage_min":    3,
		"damage_max":    7,
		"hit_bonus":     2,
		"crit_bonus":    0.02,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  1,
		"rarity":        Rarity.COMMON,
		"flavour":       "Squire's standard. Light, fast, and forgiving of an unschooled grip.",
	},
	"arming_sword": {
		"name":          "Arming Sword",
		"weapon_type":   WeaponType.SWORD,
		"damage_min":    4,
		"damage_max":    9,
		"hit_bonus":     2,
		"crit_bonus":    0.03,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  2,
		"rarity":        Rarity.UNCOMMON,
		"flavour":       "A knight's everyday blade — balanced for foot, mount, and the long ride home.",
	},
	"longsword": {
		"name":          "Longsword",
		"weapon_type":   WeaponType.SWORD,
		"damage_min":    5,
		"damage_max":    10,
		"hit_bonus":     1,
		"crit_bonus":    0.03,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  2,
		"rarity":        Rarity.COMMON,
		"flavour":       "The household standard — two-handed reach, single-handed when the line breaks.",
	},
	"dueling_sword": {
		"name":          "Dueling Sword",
		"weapon_type":   WeaponType.SWORD,
		"damage_min":    4,
		"damage_max":    9,
		"hit_bonus":     4,
		"crit_bonus":    0.06,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  3,
		"rarity":        Rarity.RARE,
		"flavour":       "Tournament-tempered, narrow of point. It wants a duelist, not a brawler.",
	},
	"greatsword": {
		"name":          "Greatsword",
		"weapon_type":   WeaponType.SWORD,
		"damage_min":    8,
		"damage_max":    14,
		"hit_bonus":    -1,
		"crit_bonus":    0.05,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  3,
		"rarity":        Rarity.RARE,
		"flavour":       "Two hands required, no apologies given. A swing you commit to.",
	},
	"axe": {
		"name":          "Battle Axe",
		"weapon_type":   WeaponType.AXE,
		"damage_min":    7,
		"damage_max":    13,
		"hit_bonus":    -1,
		"crit_bonus":    0.05,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  2,
		"rarity":        Rarity.COMMON,
		"flavour":       "Heavy at the head, honest in its intentions.",
	},
	"war_pick": {
		"name":          "War Pick",
		"weapon_type":   WeaponType.MACE,
		"damage_min":    6,
		"damage_max":    11,
		"hit_bonus":     1,
		"crit_bonus":    0.04,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  2,
		"rarity":        Rarity.UNCOMMON,
		"flavour":       "A short steel beak that does not care for plate. Tournaments forbid it.",
	},
	"spear": {
		"name":          "Spear",
		"weapon_type":   WeaponType.SPEAR,
		"damage_min":    4,
		"damage_max":    9,
		"hit_bonus":     3,
		"crit_bonus":    0.02,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  2,
		"rarity":        Rarity.COMMON,
		"flavour":       "First to engage, last to retreat — reach is a kind of patience.",
	},
	"halberd": {
		"name":          "Halberd",
		"weapon_type":   WeaponType.POLEARM,
		"damage_min":    7,
		"damage_max":    13,
		"hit_bonus":     1,
		"crit_bonus":    0.04,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  3,
		"rarity":        Rarity.RARE,
		"flavour":       "Axe, spear, and hook on one shaft — three tools for the price of a long carry.",
	},
	"dagger": {
		"name":          "Dagger",
		"weapon_type":   WeaponType.DAGGER,
		"damage_min":    2,
		"damage_max":    5,
		"hit_bonus":     4,
		"crit_bonus":    0.08,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  1,
		"rarity":        Rarity.COMMON,
		"flavour":       "A whisper of steel for tight quarters and close conversations.",
	},
	"shortbow": {
		"name":          "Shortbow",
		"weapon_type":   WeaponType.BOW,
		"damage_min":    3,
		"damage_max":    7,
		"hit_bonus":     1,
		"crit_bonus":    0.03,
		"range_type":    RangeType.RANGED,
		"primary_skill": "archery",
		"power_rating":  1,
		"rarity":        Rarity.COMMON,
		"flavour":       "A hunter's bow, repurposed. Quick to draw, light on the back.",
	},
	"longbow": {
		"name":          "Longbow",
		"weapon_type":   WeaponType.BOW,
		"damage_min":    5,
		"damage_max":    11,
		"hit_bonus":     0,
		"crit_bonus":    0.04,
		"range_type":    RangeType.RANGED,
		"primary_skill": "archery",
		"power_rating":  2,
		"rarity":        Rarity.COMMON,
		"flavour":       "Yew, gut, and a lifetime's practice. The arm is half the weapon.",
	},
	"warbow": {
		"name":          "Warbow",
		"weapon_type":   WeaponType.BOW,
		"damage_min":    7,
		"damage_max":    13,
		"hit_bonus":     0,
		"crit_bonus":    0.05,
		"range_type":    RangeType.RANGED,
		"primary_skill": "archery",
		"power_rating":  3,
		"rarity":        Rarity.RARE,
		"flavour":       "A draw weight that breaks the unschooled. At range, breaks everything else.",
	},
	"crossbow": {
		"name":          "Crossbow",
		"weapon_type":   WeaponType.CROSSBOW,
		"damage_min":    8,
		"damage_max":    14,
		"hit_bonus":     2,
		"crit_bonus":    0.05,
		"range_type":    RangeType.RANGED,
		"primary_skill": "archery",
		"power_rating":  3,
		"rarity":        Rarity.UNCOMMON,
		"flavour":       "Slow to load, hard to ignore. Aristocrats call it ungentlemanly. They lose anyway.",
	},
	# --- Heirlooms — only awarded as Grand Tournament prizes or seeded drops.
	"ancestral_blade": {
		"name":          "Ancestral Blade",
		"weapon_type":   WeaponType.SWORD,
		"damage_min":    7,
		"damage_max":    13,
		"hit_bonus":     3,
		"crit_bonus":    0.07,
		"range_type":    RangeType.MELEE,
		"primary_skill": "swordsmanship",
		"power_rating":  4,
		"rarity":        Rarity.HEIRLOOM,
		"flavour":       "A blade with three centuries of provenance. The pommel still remembers each hand.",
	},
	"master_warbow": {
		"name":          "Master's Warbow",
		"weapon_type":   WeaponType.BOW,
		"damage_min":    8,
		"damage_max":    15,
		"hit_bonus":     2,
		"crit_bonus":    0.06,
		"range_type":    RangeType.RANGED,
		"primary_skill": "archery",
		"power_rating":  4,
		"rarity":        Rarity.HEIRLOOM,
		"flavour":       "Layered horn, sinew, and yew, set by a bowyer whose marks every realm respects.",
	},
}


static func get_entry(id: String) -> Dictionary:
	return CATALOGUE.get(id, CATALOGUE["unarmed"])


static func display_name(id: String) -> String:
	return get_entry(id).get("name", "Unarmed")


static func is_ranged(id: String) -> bool:
	return get_entry(id).get("range_type", RangeType.MELEE) == RangeType.RANGED


static func power_rating(id: String) -> int:
	return int(get_entry(id).get("power_rating", 0))


static func rarity(id: String) -> int:
	return int(get_entry(id).get("rarity", Rarity.COMMON))


static func rarity_label(id: String) -> String:
	return RARITY_LABELS.get(rarity(id), "Common")


static func rarity_color(id: String) -> Color:
	return RARITY_COLORS.get(rarity(id), Color.WHITE)


static func flavour(id: String) -> String:
	return get_entry(id).get("flavour", "")


# Concise one-line stat summary for tooltips and Knight Overview rows.
# e.g. "Longsword — dmg 5–10, +1 hit, +3% crit, +2 power"
static func describe(id: String) -> String:
	var e: Dictionary = get_entry(id)
	var bits: Array[String] = []
	bits.append("dmg %d–%d" % [int(e.get("damage_min", 0)), int(e.get("damage_max", 0))])
	if int(e.get("hit_bonus", 0)) != 0:
		bits.append("%+d hit" % int(e["hit_bonus"]))
	if float(e.get("crit_bonus", 0)) > 0.0:
		bits.append("+%d%% crit" % int(round(float(e["crit_bonus"]) * 100.0)))
	bits.append("+%d power" % power_rating(id))
	return "%s — %s" % [display_name(id), ", ".join(bits)]


# All ids that match a rarity tier. Used by loot drops.
static func ids_of_rarity(target: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in CATALOGUE:
		if int(CATALOGUE[id].get("rarity", Rarity.COMMON)) == target:
			out.append(id)
	return out
