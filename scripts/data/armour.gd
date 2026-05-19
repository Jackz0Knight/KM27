class_name Armour
extends RefCounted

# Armour data definitions. Units carry an armour_id string; CombatUnit looks up
# the entry from CATALOGUE to derive combat stats.
#
# base_rating: flat damage absorbed per hit. Combined with Strength/6 in
#   CombatUnit to get the final armour_value. Heavier armour requires more
#   Strength to use at full effectiveness.
# dodge_penalty: integer offset subtracted as penalty × 0.01 from dodge_chance.
#   Heavy armour constrains movement — high Speed still helps, but less.
# block_chance: flat addition to block_chance in CombatUnit (on top of the
#   Swordsmanship contribution). Plate and shields parry more.

enum ArmourTier { UNARMOURED, LIGHT, MEDIUM, HEAVY }


const CATALOGUE: Dictionary = {
	"unarmoured": {
		"name":          "Unarmoured",
		"tier":          ArmourTier.UNARMOURED,
		"base_rating":   0,
		"dodge_penalty": 0,
		"block_chance":  0.00,
	},
	"padded": {
		"name":          "Padded Cloth",
		"tier":          ArmourTier.LIGHT,
		"base_rating":   2,
		"dodge_penalty": 1,
		"block_chance":  0.00,
	},
	"leather": {
		"name":          "Leather Armour",
		"tier":          ArmourTier.LIGHT,
		"base_rating":   4,
		"dodge_penalty": 2,
		"block_chance":  0.04,
	},
	"chainmail": {
		"name":          "Chainmail",
		"tier":          ArmourTier.MEDIUM,
		"base_rating":   7,
		"dodge_penalty": 4,
		"block_chance":  0.08,
	},
	"half_plate": {
		"name":          "Half Plate",
		"tier":          ArmourTier.HEAVY,
		"base_rating":   10,
		"dodge_penalty": 6,
		"block_chance":  0.14,
	},
	"full_plate": {
		"name":          "Full Plate",
		"tier":          ArmourTier.HEAVY,
		"base_rating":   14,
		"dodge_penalty": 8,
		"block_chance":  0.20,
	},
}


static func get_entry(id: String) -> Dictionary:
	return CATALOGUE.get(id, CATALOGUE["unarmoured"])


static func display_name(id: String) -> String:
	return get_entry(id).get("name", "Unarmoured")


static func tier_label(id: String) -> String:
	match get_entry(id).get("tier", ArmourTier.UNARMOURED):
		ArmourTier.LIGHT:      return "Light"
		ArmourTier.MEDIUM:     return "Medium"
		ArmourTier.HEAVY:      return "Heavy"
	return "Unarmoured"
