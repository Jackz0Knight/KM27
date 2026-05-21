class_name Stats
extends Resource

# The 12 visible stats from GDD §10. Scale 1–20.
#
# Increment is gated by both the hard cap (20) and the unit's Potential Ability
# (hidden, see GDD §10 "Hidden"). Training, Determination rolls, and the
# Travelling Champion's Duel reward all route through `try_increment` so the
# PA / cap rules live in one place.

const STAT_KEYS: Array[String] = [
	"strength",
	"speed",
	"technique",
	"bravery",
	"loyalty",
	"determination",
	"swordsmanship",
	"archery",
	"horsemanship",
	"leadership",
	"etiquette",
	"intimidation",
]

const STAT_CAP: int = 20

# Descriptor bands for stat obfuscation. Cards show the word, Knight Overview
# shows the word + the number. Hover tooltips on the cards reveal the number
# so the player can verify when they need to. Bands chosen so each holds 3
# values across the 1-20 scale — keeps the spread legible.
const DESCRIPTORS: Array[Dictionary] = [
	{"max": 0,  "label": "—",         "color": Color(0.50, 0.46, 0.40)},
	{"max": 3,  "label": "Wretched",  "color": Color(0.60, 0.28, 0.22)},
	{"max": 6,  "label": "Poor",      "color": Color(0.75, 0.45, 0.30)},
	{"max": 9,  "label": "Decent",    "color": Color(0.80, 0.72, 0.45)},
	{"max": 12, "label": "Good",      "color": Color(0.70, 0.82, 0.55)},
	{"max": 15, "label": "Strong",    "color": Color(0.50, 0.85, 0.50)},
	{"max": 18, "label": "Excellent", "color": Color(0.40, 0.82, 0.85)},
	{"max": 20, "label": "Masterful", "color": Color(0.95, 0.78, 0.30)},
]


static func descriptor(value: int) -> String:
	for band in DESCRIPTORS:
		if value <= int(band["max"]):
			return str(band["label"])
	return "Masterful"


static func descriptor_color(value: int) -> Color:
	for band in DESCRIPTORS:
		if value <= int(band["max"]):
			return band["color"]
	return DESCRIPTORS[-1]["color"]


var strength: int = 0
var speed: int = 0
var technique: int = 0
var bravery: int = 0
var loyalty: int = 0
var determination: int = 0
var swordsmanship: int = 0
var archery: int = 0
var horsemanship: int = 0
var leadership: int = 0
var etiquette: int = 0
var intimidation: int = 0


func get_value(stat: String) -> int:
	return get(stat)


func set_value(stat: String, value: int) -> void:
	# Upper clamp is `STAT_CAP + 5` rather than STAT_CAP so body-type
	# implicit cap bumps (BodyType.CAP_BUMPS) survive save/load round-trips.
	# A Burly knight whose Strength reached 21 in-play would otherwise be
	# clamped back to 20 here when SaveManager restores their stats. The
	# 5-point margin is generous to allow future stacking (e.g., trait +
	# body) without changing this clamp again. Callers that need a tighter
	# bound (e.g., HousePool.apply_lean clamps to its own `stat_max`) still
	# enforce it themselves before calling this.
	set(stat, clampi(value, 0, STAT_CAP + 5))


func sum() -> int:
	var total: int = 0
	for k in STAT_KEYS:
		total += int(get(k))
	return total


# +1 to `stat`. Returns true if applied, false if blocked by stat cap or by PA.
# `extra_cap` lifts the per-stat ceiling above STAT_CAP — used by body-type
# implicit bumps so a Burly knight can reach Strength 21. Default 0
# preserves existing behaviour for callers that don't know about the unit's
# body type.
func try_increment(stat: String, potential_ability: int, extra_cap: int = 0) -> bool:
	var current: int = int(get(stat))
	if current >= STAT_CAP + extra_cap:
		return false
	if sum() + 1 > potential_ability:
		return false
	set(stat, current + 1)
	return true


# Pick a random non-maxed stat that still has PA headroom, +1 it.
# Returns the chosen stat name, or "" if no stat can grow.
# `extra_caps` is a per-stat dict of cap bonuses, same shape as
# `BodyType.cap_bumps()` — applied to the per-stat ceiling check so the
# random pick can still grow a body-favoured stat past STAT_CAP.
func try_increment_random(potential_ability: int, extra_caps: Dictionary = {}) -> String:
	return try_increment_random_excluding(potential_ability, "", extra_caps)


# Same as try_increment_random but skips `exclude_stat`. Phase 5's training
# system uses this for the per-training Determination-rolled +1 (GDD §7),
# which goes to a stat OTHER than the unit's training target.
func try_increment_random_excluding(potential_ability: int, exclude_stat: String, extra_caps: Dictionary = {}) -> String:
	if sum() >= potential_ability:
		return ""
	var candidates: Array[String] = []
	for k in STAT_KEYS:
		if k == exclude_stat:
			continue
		var stat_cap: int = STAT_CAP + int(extra_caps.get(k, 0))
		if int(get(k)) < stat_cap:
			candidates.append(k)
	if candidates.is_empty():
		return ""
	var pick: String = candidates[RNG.randi_range(0, candidates.size() - 1)]
	# Set bypasses set_value's STAT_CAP clamp deliberately — extra_caps already
	# said this stat is allowed above 20. set_value would clamp it back down.
	set(pick, int(get(pick)) + 1)
	return pick


static func roll(low: int, high: int) -> Stats:
	var s := Stats.new()
	for k in STAT_KEYS:
		s.set(k, RNG.randi_range(low, high))
	return s


# Apply a flat bonus to every visible stat (clamped at STAT_CAP).
# Used for the Knight class bonus on the chosen starting Knight.
func apply_flat_bonus(amount: int) -> void:
	for k in STAT_KEYS:
		set(k, mini(int(get(k)) + amount, STAT_CAP))


func describe() -> String:
	return (
		"Str:%d Spd:%d Tec:%d Bra:%d Loy:%d Det:%d Swd:%d Arc:%d Hrs:%d Lea:%d Etq:%d Int:%d"
		% [
			strength, speed, technique, bravery, loyalty, determination,
			swordsmanship, archery, horsemanship, leadership, etiquette, intimidation,
		]
	)
