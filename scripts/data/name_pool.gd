class_name NamePool
extends RefCounted

# Names for procedurally generated Knights and Squires per GDD §3.
# Pure medieval-fantasy flavour, no real-world surnames.

const FIRST_NAMES: Array[String] = [
	"Aldric", "Bertran", "Cedric", "Dorian", "Edmund", "Florian", "Garrick",
	"Halden", "Ivar", "Jaron", "Kael", "Lothar", "Magnus", "Nolen", "Orin",
	"Percival", "Quentin", "Rolf", "Stellan", "Tomas", "Ulric", "Varic",
	"Wulf", "Xander", "Yorath", "Zane", "Alaric", "Brennan", "Caelum",
	"Darius", "Elias", "Faelan",
]

const SURNAMES: Array[String] = [
	"Blackmoor", "Stormcrow", "Ironheart", "Coldwater", "Ravensford",
	"Hartwood", "Wolfsbane", "Marchwarden", "Hollowmere", "Stagsleap",
	"Whitehall", "Redbrook", "Ashvale", "Greenwell", "Northgate", "Foxhollow",
	"Brackenbough", "Silvermark", "Oakenshield", "Frostmere", "Lightholm",
	"Carrowmoor", "Vaelis", "Thornwood", "Greyfell",
]


static func random_name() -> String:
	var first: String = FIRST_NAMES[RNG.randi_range(0, FIRST_NAMES.size() - 1)]
	var sur: String = SURNAMES[RNG.randi_range(0, SURNAMES.size() - 1)]
	return "%s %s" % [first, sur]


# Pulls a name whose first AND surname don't already appear in `used_names`.
# Falls back to the unconstrained roll after a few attempts so we never spin
# forever if the pool runs out — but with 32×25 entries that's only a worry
# if the caller pushes hundreds of names at once. The starting roster only
# needs six unique surnames out of 25, so collisions resolve quickly.
static func random_name_avoiding(used_names: Array[String]) -> String:
	var used_firsts: Array[String] = []
	var used_surs: Array[String] = []
	for full_name in used_names:
		var bits: PackedStringArray = full_name.split(" ", false, 1)
		if bits.size() > 0:
			used_firsts.append(bits[0])
		if bits.size() > 1:
			used_surs.append(bits[1])
	for _attempt in range(12):
		var first: String = FIRST_NAMES[RNG.randi_range(0, FIRST_NAMES.size() - 1)]
		var sur: String = SURNAMES[RNG.randi_range(0, SURNAMES.size() - 1)]
		if used_firsts.has(first) or used_surs.has(sur):
			continue
		return "%s %s" % [first, sur]
	return random_name()
