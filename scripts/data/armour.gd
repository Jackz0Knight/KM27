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
# power_rating: integer 0–4 added to formation-battle unit_power. Heavy plate
#   is worth more than chain in formation combat; the strategy layer reads
#   this directly from `Combat.armour_power_rating`.
# rarity: 0 Common, 1 Uncommon, 2 Rare, 3 Heirloom. Drives loot pools and
#   the colour tint of the item name on UI cards.

enum ArmourTier { UNARMOURED, LIGHT, MEDIUM, HEAVY, MASTERWORK }
enum Rarity     { COMMON, UNCOMMON, RARE, HEIRLOOM }


const RARITY_LABELS: Dictionary = {
	Rarity.COMMON:   "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE:     "Rare",
	Rarity.HEIRLOOM: "Heirloom",
}

const RARITY_COLORS: Dictionary = {
	Rarity.COMMON:   Color(0.78, 0.74, 0.62),
	Rarity.UNCOMMON: Color(0.55, 0.85, 0.55),
	Rarity.RARE:     Color(0.55, 0.75, 0.95),
	Rarity.HEIRLOOM: Color(1.0, 0.84, 0.42),
}


const CATALOGUE: Dictionary = {
	"unarmoured": {
		"name":          "Unarmoured",
		"tier":          ArmourTier.UNARMOURED,
		"base_rating":   0,
		"dodge_penalty": 0,
		"block_chance":  0.00,
		"power_rating":  0,
		"rarity":        Rarity.COMMON,
		"flavour":       "Shirt and trousers. The sky is your roof.",
	},
	"padded": {
		"name":          "Padded Cloth",
		"tier":          ArmourTier.LIGHT,
		"base_rating":   2,
		"dodge_penalty": 1,
		"block_chance":  0.00,
		"power_rating":  0,
		"rarity":        Rarity.COMMON,
		"flavour":       "Quilted linen, layered until it stops the worst of a glancing blow.",
	},
	"leather": {
		"name":          "Leather Armour",
		"tier":          ArmourTier.LIGHT,
		"base_rating":   4,
		"dodge_penalty": 2,
		"block_chance":  0.04,
		"power_rating":  1,
		"rarity":        Rarity.COMMON,
		"flavour":       "Boiled, riveted, and patched twice. Standard for those who can afford a horse.",
	},
	"studded_leather": {
		"name":          "Studded Leather",
		"tier":          ArmourTier.LIGHT,
		"base_rating":   5,
		"dodge_penalty": 2,
		"block_chance":  0.06,
		"power_rating":  1,
		"rarity":        Rarity.UNCOMMON,
		"flavour":       "Leather with iron studs at the joints. A compromise that pleases no one and works anyway.",
	},
	"scale_mail": {
		"name":          "Scale Mail",
		"tier":          ArmourTier.MEDIUM,
		"base_rating":   6,
		"dodge_penalty": 3,
		"block_chance":  0.06,
		"power_rating":  2,
		"rarity":        Rarity.UNCOMMON,
		"flavour":       "Overlapping plates sewn to leather. Heavier than chain, kinder to the smith.",
	},
	"chainmail": {
		"name":          "Chainmail",
		"tier":          ArmourTier.MEDIUM,
		"base_rating":   7,
		"dodge_penalty": 4,
		"block_chance":  0.08,
		"power_rating":  2,
		"rarity":        Rarity.COMMON,
		"flavour":       "Riveted rings, hauberk-length. Two days to put on, two minutes to be glad you did.",
	},
	"brigandine": {
		"name":          "Brigandine",
		"tier":          ArmourTier.MEDIUM,
		"base_rating":   8,
		"dodge_penalty": 4,
		"block_chance":  0.10,
		"power_rating":  2,
		"rarity":        Rarity.UNCOMMON,
		"flavour":       "Steel plates riveted between cloth. Worn by sergeants and sober knights.",
	},
	"half_plate": {
		"name":          "Half Plate",
		"tier":          ArmourTier.HEAVY,
		"base_rating":   10,
		"dodge_penalty": 6,
		"block_chance":  0.14,
		"power_rating":  3,
		"rarity":        Rarity.COMMON,
		"flavour":       "Cuirass, pauldrons, gauntlets, greaves. The body sealed, the rest still alive.",
	},
	"plated_mail": {
		"name":          "Plated Mail",
		"tier":          ArmourTier.HEAVY,
		"base_rating":   12,
		"dodge_penalty": 7,
		"block_chance":  0.17,
		"power_rating":  3,
		"rarity":        Rarity.RARE,
		"flavour":       "Plate over chain over padding. A walking forge with a sword in it.",
	},
	"full_plate": {
		"name":          "Full Plate",
		"tier":          ArmourTier.HEAVY,
		"base_rating":   14,
		"dodge_penalty": 8,
		"block_chance":  0.20,
		"power_rating":  4,
		"rarity":        Rarity.RARE,
		"flavour":       "Articulated, fitted, polished. A second skin that costs a manor.",
	},
	# --- Uncommon / Rare additions thickening the mid-tier drop pool ---
	"gambeson": {
		"name":          "Gambeson",
		"tier":          ArmourTier.LIGHT,
		"base_rating":   3,
		"dodge_penalty": 1,
		"block_chance":  0.02,
		"power_rating":  1,
		"rarity":        Rarity.UNCOMMON,
		"flavour":       "Layered linen, quilted by a tailor who has buried a brother. Lighter than mail and warmer than truth.",
	},
	"mail_hauberk": {
		"name":          "Mail Hauberk",
		"tier":          ArmourTier.MEDIUM,
		"base_rating":   8,
		"dodge_penalty": 4,
		"block_chance":  0.10,
		"power_rating":  2,
		"rarity":        Rarity.UNCOMMON,
		"flavour":       "Knee-length rings over a thicker padding than a chainmail's. The smith's mark is on the inside of the collar.",
	},
	"field_plate": {
		"name":          "Field Plate",
		"tier":          ArmourTier.HEAVY,
		"base_rating":   13,
		"dodge_penalty": 7,
		"block_chance":  0.18,
		"power_rating":  3,
		"rarity":        Rarity.RARE,
		"flavour":       "Lighter than full plate by intent — fitted for a long campaign, not a short procession.",
	},
	# --- Heirlooms — Grand Tournament / seeded drops only.
	"ornate_breastplate": {
		"name":          "Ornate Breastplate",
		"tier":          ArmourTier.MASTERWORK,
		"base_rating":   13,
		"dodge_penalty": 5,
		"block_chance":  0.22,
		"power_rating":  4,
		"rarity":        Rarity.HEIRLOOM,
		"flavour":       "Etched with a chronicler's care. Lighter than full plate, prouder than any.",
	},
	"warden_harness": {
		"name":          "Warden's Harness",
		"tier":          ArmourTier.MASTERWORK,
		"base_rating":   15,
		"dodge_penalty": 6,
		"block_chance":  0.24,
		"power_rating":  4,
		"rarity":        Rarity.HEIRLOOM,
		"flavour":       "A captain's kit, fitted across a generation of wearers. Each scar is signed.",
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
		ArmourTier.MASTERWORK: return "Masterwork"
	return "Unarmoured"


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


# Concise one-liner for tooltips / Knight Overview rows.
static func describe(id: String) -> String:
	var e: Dictionary = get_entry(id)
	var bits: Array[String] = []
	bits.append("AR %d" % int(e.get("base_rating", 0)))
	if int(e.get("dodge_penalty", 0)) > 0:
		bits.append("-%d dodge" % int(e["dodge_penalty"]))
	if float(e.get("block_chance", 0)) > 0.0:
		bits.append("+%d%% block" % int(round(float(e["block_chance"]) * 100.0)))
	bits.append("+%d power" % power_rating(id))
	return "%s — %s" % [display_name(id), ", ".join(bits)]


static func ids_of_rarity(target: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in CATALOGUE:
		if int(CATALOGUE[id].get("rarity", Rarity.COMMON)) == target:
			out.append(id)
	return out
