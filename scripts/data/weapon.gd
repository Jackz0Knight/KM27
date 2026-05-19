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

enum WeaponType { UNARMED, SWORD, AXE, SPEAR, DAGGER, BOW, CROSSBOW }
enum RangeType  { MELEE, RANGED }


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
	},
}


static func get_entry(id: String) -> Dictionary:
	return CATALOGUE.get(id, CATALOGUE["unarmed"])


static func display_name(id: String) -> String:
	return get_entry(id).get("name", "Unarmed")


static func is_ranged(id: String) -> bool:
	return get_entry(id).get("range_type", RangeType.MELEE) == RangeType.RANGED
