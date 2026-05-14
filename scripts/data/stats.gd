class_name Stats
extends Resource

# The 12 visible stats from GDD §10. Scale 1–20.
#
# Increment is gated by both the hard cap (20) and the unit's Potential Ability
# (hidden, see GDD §10 "Hidden"). Training, Determination rolls, and the
# Travelling Champion's Duel reward all route through `try_increment` so the
# PA / cap rules live in one place.

const STAT_KEYS: PackedStringArray = PackedStringArray([
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
])

const STAT_CAP: int = 20

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
	set(stat, clampi(value, 0, STAT_CAP))


func sum() -> int:
	var total: int = 0
	for k in STAT_KEYS:
		total += int(get(k))
	return total


# +1 to `stat`. Returns true if applied, false if blocked by stat cap or by PA.
func try_increment(stat: String, potential_ability: int) -> bool:
	var current: int = int(get(stat))
	if current >= STAT_CAP:
		return false
	if sum() + 1 > potential_ability:
		return false
	set(stat, current + 1)
	return true


# Pick a random non-maxed stat that still has PA headroom, +1 it.
# Returns the chosen stat name, or "" if no stat can grow.
func try_increment_random(potential_ability: int) -> String:
	return try_increment_random_excluding(potential_ability, "")


# Same as try_increment_random but skips `exclude_stat`. Phase 5's training
# system uses this for the per-training Determination-rolled +1 (GDD §7),
# which goes to a stat OTHER than the unit's training target.
func try_increment_random_excluding(potential_ability: int, exclude_stat: String) -> String:
	if sum() >= potential_ability:
		return ""
	var candidates: Array[String] = []
	for k in STAT_KEYS:
		if k == exclude_stat:
			continue
		if int(get(k)) < STAT_CAP:
			candidates.append(k)
	if candidates.is_empty():
		return ""
	var pick: String = candidates[RNG.randi_range(0, candidates.size() - 1)]
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
