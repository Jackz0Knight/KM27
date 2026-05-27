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

# ── Staged development (FM-style gradual growth, GDD §10 "Hidden") ──────────
# Stats no longer jump the moment a training week succeeds. Every development
# source (training, Determination, duel/event rewards) feeds *hidden* progress
# into `progress[stat]`; once a whole point accumulates the visible integer
# ticks up by one and the remainder carries. Growth tapers as a unit's total
# nears its Potential Ability, so development slows near potential without ever
# exposing the PA number — the dev arrow simply fades. All constants here are
# Phase-8 tuning knobs.
const DEV_PACE: float = 4.5            # nominal training weeks for one point at full rate
const DEV_HEADROOM_RANGE: float = 8.0  # PA headroom (points) above which growth runs full-rate
const DEV_MIN_FACTOR: float = 0.12     # slowest non-zero growth rate as PA approaches
const DEV_EPSILON: float = 0.02        # carry held just under a point when ceiling-blocked
const MOMENTUM_WEEKS: int = 3          # weeks a fresh level-up keeps its bright arrow
const DEV_ACTIVE_WEEKS: int = 2        # weeks the small "developing" arrow lingers after a feed

# Development arrow states, surfaced by UnitCard / Knight Overview.
const DEV_NONE: int = 0
const DEV_RISING: int = 1    # small ▲ — accruing hidden progress
const DEV_SURGING: int = 2   # bright ▲ — gained a point within MOMENTUM_WEEKS
const DEV_FALLING: int = 3   # ▼ — a stat currently suppressed by injury

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

# Hidden development state, all persisted through SaveManager (old saves load
# empty). `progress`: stat → carried fraction toward the next point [0,1).
# `momentum`: stat → weeks left on the bright "just levelled" arrow.
# `developing`: stat → weeks left on the small "recently trained" arrow (driven
# by recency of input, not residual carry, so the arrow is honest).
var progress: Dictionary = {}
var momentum: Dictionary = {}
var developing: Dictionary = {}


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


# Feed staged development into `stat`. `points` is the nominal strength of the
# source (1.0 = one standard training success; events / duels pass more). The
# feed is scaled by DEV_PACE and a headroom factor that shrinks as the unit's
# total nears its Potential Ability, so growth slows near potential without
# revealing PA. Each whole accumulated point ticks the integer up (honouring
# the per-stat cap + PA) and lights the momentum arrow. Returns {"leveled": N}.
func add_progress(stat: String, points: float, potential_ability: int, extra_cap: int = 0) -> Dictionary:
	var result: Dictionary = {"leveled": 0}
	if points <= 0.0:
		return result
	var ceiling: int = STAT_CAP + extra_cap
	if int(get(stat)) >= ceiling:
		return result  # stat already maxed — no progress, no arrow
	var factor: float = _headroom_factor(potential_ability)
	if factor <= 0.0:
		return result  # at potential — development stalls (PA stays hidden)
	# Mark active development for the small arrow (recency-based, see decay).
	developing[stat] = DEV_ACTIVE_WEEKS
	var accrued: float = float(progress.get(stat, 0.0)) + (points / DEV_PACE) * factor
	while accrued >= 1.0:
		if int(get(stat)) >= ceiling or sum() + 1 > potential_ability:
			# Hit a ceiling mid-feed — hold just under a point so the rising
			# arrow stays lit rather than silently banking infinite progress.
			accrued = minf(accrued, 1.0 - DEV_EPSILON)
			break
		set(stat, int(get(stat)) + 1)
		accrued -= 1.0
		result["leveled"] += 1
		momentum[stat] = MOMENTUM_WEEKS
	progress[stat] = accrued
	return result


# Growth-rate multiplier from remaining PA headroom. Full rate with ample
# headroom, tapering to DEV_MIN_FACTOR as the total approaches PA, then 0 at
# (or past) potential.
func _headroom_factor(potential_ability: int) -> float:
	var headroom: int = potential_ability - sum()
	if headroom <= 0:
		return 0.0
	return clampf(float(headroom) / DEV_HEADROOM_RANGE, DEV_MIN_FACTOR, 1.0)


# Age both development arrows down by one week. Called once per Tick (before
# this week's training, so a fresh feed re-arms the arrow).
func decay_development() -> void:
	for k in momentum.keys():
		var mv: int = int(momentum[k]) - 1
		if mv <= 0:
			momentum.erase(k)
		else:
			momentum[k] = mv
	for k in developing.keys():
		var dv: int = int(developing[k]) - 1
		if dv <= 0:
			developing.erase(k)
		else:
			developing[k] = dv


# Which development arrow (if any) a stat should show. `injured` is passed by
# the caller (Unit owns the injury list). Injury suppression wins over a rising
# arrow so the player sees the setback.
func development_state(stat: String, potential_ability: int, injured: bool) -> int:
	if injured:
		return DEV_FALLING
	if int(momentum.get(stat, 0)) > 0:
		return DEV_SURGING
	if int(developing.get(stat, 0)) > 0 \
			and (potential_ability - sum()) > 0 \
			and int(get(stat)) < STAT_CAP:
		return DEV_RISING
	return DEV_NONE


static func development_glyph(state: int) -> String:
	match state:
		DEV_RISING, DEV_SURGING: return "▲"
		DEV_FALLING: return "▼"
	return ""


static func development_color(state: int) -> Color:
	match state:
		DEV_RISING: return Color(0.45, 0.68, 0.45)   # muted green — quietly improving
		DEV_SURGING: return Color(0.55, 0.95, 0.55)   # bright green — recent gain
		DEV_FALLING: return Color(0.95, 0.45, 0.30)   # injury orange
	return Color(0, 0, 0, 0)


static func development_tooltip(state: int) -> String:
	match state:
		DEV_RISING: return "Developing"
		DEV_SURGING: return "Improving — recently gained ground"
		DEV_FALLING: return "Hampered by injury"
	return ""


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


# Staged counterpart to try_increment_random_excluding: pick a random eligible
# stat and feed `points` of development into it. Returns {"stat", "leveled"};
# stat is "" when nothing is eligible.
func add_progress_random_excluding(points: float, potential_ability: int, exclude_stat: String, extra_caps: Dictionary = {}) -> Dictionary:
	var candidates: Array[String] = []
	for k in STAT_KEYS:
		if k == exclude_stat:
			continue
		if int(get(k)) < STAT_CAP + int(extra_caps.get(k, 0)):
			candidates.append(k)
	if candidates.is_empty():
		return {"stat": "", "leveled": 0}
	var pick: String = candidates[RNG.randi_range(0, candidates.size() - 1)]
	var dev: Dictionary = add_progress(pick, points, potential_ability, int(extra_caps.get(pick, 0)))
	return {"stat": pick, "leveled": int(dev["leveled"])}


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
