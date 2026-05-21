class_name RosterGenerator
extends RefCounted

# Rolls the starting roster per GDD §3, §9, §10.
#
# Knight candidates: stats 7–14, plus a small flat bonus on every visible stat
# (interpreted here as +1, clamped at 20). Squires: stats 4–10, no bonus.
# PA is hidden from the player but rolled into ranges 100–180 (Knight) or
# 60–140 (Squire).

const KNIGHT_STAT_MIN: int = 7
const KNIGHT_STAT_MAX: int = 14
const KNIGHT_PA_MIN: int = 100
const KNIGHT_PA_MAX: int = 180
const KNIGHT_FLAT_BONUS: int = 1   # GDD §9 "small flat bonus to all visible stats"

const SQUIRE_STAT_MIN: int = 4
const SQUIRE_STAT_MAX: int = 10
const SQUIRE_PA_MIN: int = 60
const SQUIRE_PA_MAX: int = 140

const KNIGHT_CANDIDATE_COUNT: int = 3
const STARTING_SQUIRE_COUNT: int = 3


# The two roll_* calls share `_taken_names` so the entire Knight Chooser
# screen — 3 squires + 3 candidate knights — never shows two units with the
# same first name or surname. Cleared at the start of each call to
# `roll_starting_squires` since that's the first call the chooser makes.
static var _taken_names: Array[String] = []


static func roll_knight_candidates() -> Array[Unit]:
	var out: Array[Unit] = []
	for i in range(KNIGHT_CANDIDATE_COUNT):
		out.append(_roll_knight(i + 1))
	return out


# Pre-rolled Squires — assigned the final roster ids 2..4 at roll time so
# the Knight chooser screen can show them before the Knight pick (the player
# decides which Knight best complements the Squires they're getting).
static func roll_starting_squires() -> Array[Unit]:
	_taken_names.clear()
	var out: Array[Unit] = []
	for i in range(STARTING_SQUIRE_COUNT):
		out.append(_roll_squire(2 + i))
	return out


# Final roster: chosen Knight (id=1) plus the pre-rolled Squires (ids 2..4).
# The unchosen Knight candidates are discarded.
static func build_starting_roster(chosen_knight: Unit, squires: Array[Unit]) -> Array[Unit]:
	chosen_knight.id = 1
	var out: Array[Unit] = []
	out.append(chosen_knight)
	for s in squires:
		out.append(s)
	return out


static func _roll_knight(unit_id: int) -> Unit:
	var stats: Stats = Stats.roll(KNIGHT_STAT_MIN, KNIGHT_STAT_MAX)
	stats.apply_flat_bonus(KNIGHT_FLAT_BONUS)
	var house_id: String = HousePool.random_house_id()
	HousePool.apply_lean(stats, house_id, Stats.STAT_CAP)
	var pa: int = RNG.randi_range(KNIGHT_PA_MIN, KNIGHT_PA_MAX)
	var name: String = NamePool.random_name_avoiding(_taken_names)
	_taken_names.append(name)
	var u := Unit.new(unit_id, name, Unit.UnitClass.KNIGHT, stats, pa)
	u.house_id = house_id
	u.body_type = BodyType.random_body_type()
	u.weapon_id = "longsword"
	u.armour_id = "leather"
	# Trait is rolled AFTER house lean — house biases the baseline, trait
	# colours the individual on top of that baseline. Stat clamp uses the
	# full 20 cap so a knight can plausibly stretch beyond the roll band.
	u.trait_id = TraitPool.roll()
	TraitPool.apply(u, u.trait_id, Stats.STAT_CAP)
	_enrich(u)
	return u


static func _roll_squire(unit_id: int) -> Unit:
	var stats: Stats = Stats.roll(SQUIRE_STAT_MIN, SQUIRE_STAT_MAX)
	var house_id: String = HousePool.random_house_id()
	# Squires use the same lean — they're sworn to a household too.
	# Cap squire stats at SQUIRE_STAT_MAX so the lean doesn't push them out
	# of their roll band.
	HousePool.apply_lean(stats, house_id, SQUIRE_STAT_MAX)
	var pa: int = RNG.randi_range(SQUIRE_PA_MIN, SQUIRE_PA_MAX)
	var name: String = NamePool.random_name_avoiding(_taken_names)
	_taken_names.append(name)
	var u := Unit.new(unit_id, name, Unit.UnitClass.SQUIRE, stats, pa)
	u.house_id = house_id
	u.body_type = BodyType.random_body_type()
	u.weapon_id = "shortsword"
	u.armour_id = "unarmoured"
	# Squires use a tighter ceiling so a trait can't push them out of the
	# squire roll band; the trait still adds personality, just not headroom.
	u.trait_id = TraitPool.roll()
	TraitPool.apply(u, u.trait_id, SQUIRE_STAT_MAX + 2)
	_enrich(u)
	return u


static func _enrich(u: Unit) -> void:
	u.origin_text = Chronicle.generate_origin(u)
	u.banner_line  = Chronicle.generate_banner(u)
	u.oath         = Chronicle.generate_oath(u)
	# Capture the stat that drove the oath text so OathLedger can check
	# honour conditions against a stable key — see Chronicle.derive_oath_kind.
	u.oath_kind    = Chronicle.derive_oath_kind(u)
