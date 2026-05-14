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


static func roll_knight_candidates() -> Array[Unit]:
	var out: Array[Unit] = []
	for i in range(KNIGHT_CANDIDATE_COUNT):
		out.append(_roll_knight(i + 1))
	return out


# Pre-rolled Squires — assigned the final roster ids 2..4 at roll time so
# the Knight chooser screen can show them before the Knight pick (the player
# decides which Knight best complements the Squires they're getting).
static func roll_starting_squires() -> Array[Unit]:
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
	var pa: int = RNG.randi_range(KNIGHT_PA_MIN, KNIGHT_PA_MAX)
	return Unit.new(unit_id, NamePool.random_name(), Unit.UnitClass.KNIGHT, stats, pa)


static func _roll_squire(unit_id: int) -> Unit:
	var stats: Stats = Stats.roll(SQUIRE_STAT_MIN, SQUIRE_STAT_MAX)
	var pa: int = RNG.randi_range(SQUIRE_PA_MIN, SQUIRE_PA_MAX)
	return Unit.new(unit_id, NamePool.random_name(), Unit.UnitClass.SQUIRE, stats, pa)
