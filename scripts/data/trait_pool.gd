class_name TraitPool
extends RefCounted

# Personal traits — one per unit, rolled at creation. Traits shift the unit
# slightly off the house lean's neutral roll: a trait might add +2 to one
# stat and −1 to another, or shift PA, or skew starting kit. They're how
# a Brann knight in your roster ends up feeling like a *particular* Brann
# knight, not just "another swordsman from a warrior house."
#
# Each entry:
#   id:             snake_case trait key (saved on Unit.trait_id)
#   name:           one-line display label
#   description:    sentence describing the trait's effect/feel
#   stat_mods:      Dictionary stat_key -> int (applied once at roll time,
#                   clamped to 1–STAT_CAP)
#   pa_mod:         int adjustment to potential_ability at roll time
#                   (positive = greater ceiling; negative = already-drilled)
#   weight:         relative roll weight (higher = more common)
#
# Traits are purely roll-time adjustments today. The fields they touch are
# the same ones a future "continuous trait effect" system would need, so
# wiring them up later (e.g. "Pious units recover injuries 1w faster") is
# additive — no schema break.

const TRAITS: Dictionary = {
	"veteran": {
		"name":        "Veteran",
		"description": "Years on the field have already trained out the worst habits — and most of the room for new ones.",
		"stat_mods":   {"swordsmanship": 2, "bravery": 1},
		"pa_mod":     -15,
		"weight":      3,
	},
	"hot_headed": {
		"name":        "Hot-Headed",
		"description": "Quick to the blade, slower to the apology. The lists eject him often; his sergeants love him anyway.",
		"stat_mods":   {"strength": 2, "intimidation": 1, "etiquette": -2},
		"pa_mod":      0,
		"weight":      3,
	},
	"pious": {
		"name":        "Pious",
		"description": "Carries a small book. Reads it before battles and after them. Speaks of duty without irony.",
		"stat_mods":   {"loyalty": 2, "determination": 1, "intimidation": -1},
		"pa_mod":      5,
		"weight":      3,
	},
	"tournament_brat": {
		"name":        "Tournament Brat",
		"description": "Raised in the lists since boyhood. Knows every band's signal, every herald's preference, every judge's blind spot.",
		"stat_mods":   {"technique": 2, "etiquette": 1, "bravery": -1},
		"pa_mod":      0,
		"weight":      3,
	},
	"scholar_knight": {
		"name":        "Scholar Knight",
		"description": "Reads field histories the way other knights read maps. Quiet in council; not silent.",
		"stat_mods":   {"leadership": 2, "etiquette": 1, "strength": -1},
		"pa_mod":      10,
		"weight":      2,
	},
	"horse_born": {
		"name":        "Horse-Born",
		"description": "Learned to ride before to walk. Saddles strange horses for fun.",
		"stat_mods":   {"horsemanship": 3, "speed": 1},
		"pa_mod":      0,
		"weight":      2,
	},
	"marked": {
		"name":        "Marked",
		"description": "A long scar across the jaw. Enemies look once and look again. Friends stopped looking long ago.",
		"stat_mods":   {"intimidation": 3, "bravery": 1, "etiquette": -1},
		"pa_mod":      0,
		"weight":      2,
	},
	"lucky": {
		"name":        "Lucky",
		"description": "Survives encounters that no audit of stats could explain. Carries a small coin. Will not discuss it.",
		"stat_mods":   {},
		"pa_mod":      20,
		"weight":      2,
	},
	"sworn_defender": {
		"name":        "Sworn Defender",
		"description": "Took the household oath under a vow witness. Mentions it once, then never again.",
		"stat_mods":   {"bravery": 1, "loyalty": 2, "swordsmanship": 1},
		"pa_mod":      0,
		"weight":      2,
	},
	"reluctant": {
		"name":        "Reluctant",
		"description": "Came to arms by inheritance, not appetite. Better at the dinner than the field. The dinner matters too.",
		"stat_mods":   {"etiquette": 2, "technique": 1, "swordsmanship": -1, "bravery": -1},
		"pa_mod":      5,
		"weight":      1,
	},
	"poacher": {
		"name":        "Poacher",
		"description": "Spent his boyhood losing arrows in the wrong forests. Now he loses them on purpose, and finds them later.",
		"stat_mods":   {"archery": 3, "speed": 1, "loyalty": -1},
		"pa_mod":      0,
		"weight":      2,
	},
	"stoic": {
		"name":        "Stoic",
		"description": "Doesn't flinch. People notice this and stop testing it.",
		"stat_mods":   {"determination": 2, "bravery": 1, "speed": -1},
		"pa_mod":      0,
		"weight":      2,
	},
}


# Pick a weighted-random trait id from TRAITS. Uses the RNG autoload so
# rolls are reproducible per seed.
static func roll() -> String:
	var ids: Array[String] = []
	var weights: Array[int] = []
	for id: String in TRAITS:
		ids.append(id)
		weights.append(int(TRAITS[id].get("weight", 1)))

	var total: int = 0
	for w in weights:
		total += w
	if total <= 0 or ids.is_empty():
		return ""

	var pick: int = RNG.randi_range(1, total)
	var acc: int = 0
	for i in range(ids.size()):
		acc += weights[i]
		if pick <= acc:
			return ids[i]
	return ids[ids.size() - 1]


# Apply the rolled trait's stat_mods and pa_mod to a freshly-rolled unit.
# Called once during RosterGenerator._roll_knight/_roll_squire after the
# house lean is applied, so trait shifts read as personal flair on top of
# the household's baseline.
static func apply(unit: Unit, trait_id: String, stat_cap: int) -> void:
	var entry: Dictionary = TRAITS.get(trait_id, {})
	if entry.is_empty():
		return
	for stat_key: String in entry.get("stat_mods", {}):
		var current: int = unit.stats.get_value(stat_key)
		var delta: int = int(entry["stat_mods"][stat_key])
		unit.stats.set_value(stat_key, clampi(current + delta, 1, stat_cap))
	unit.potential_ability = maxi(20, unit.potential_ability + int(entry.get("pa_mod", 0)))


static func name_for(trait_id: String) -> String:
	return TRAITS.get(trait_id, {}).get("name", "")


static func description_for(trait_id: String) -> String:
	return TRAITS.get(trait_id, {}).get("description", "")


# True iff the id resolves to a defined trait. Used by SaveManager + Unit
# de-serialisation to skip garbage data from older saves.
static func is_valid(trait_id: String) -> bool:
	return TRAITS.has(trait_id)
