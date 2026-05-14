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
