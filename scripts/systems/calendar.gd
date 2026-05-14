class_name Calendar
extends RefCounted

# Pure calendar helpers per GDD §16: 1 year = 48 weeks, tournament every 12.
# The game's first week is Week 1 of Year 1627.

const WEEKS_PER_YEAR: int = 48
const START_YEAR: int = 1627
const TOURNAMENT_INTERVAL: int = 12


static func year_for(week: int) -> int:
	return START_YEAR + (week - 1) / WEEKS_PER_YEAR


static func week_of_year(week: int) -> int:
	return ((week - 1) % WEEKS_PER_YEAR) + 1


static func is_tournament_week(week: int) -> bool:
	return week > 0 and week % TOURNAMENT_INTERVAL == 0


# 0 if not a tournament week, else the running tournament index (1, 2, 3, ...).
# Used by GDD §6's tournament enemy-power formula `60 + tournament_number × 25`.
static func tournament_number(week: int) -> int:
	if not is_tournament_week(week):
		return 0
	return week / TOURNAMENT_INTERVAL
