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


# 1-based "years into the run". Week 1–48 → year 1, week 49–96 → year 2, ...
# Used by GDD §6's Grand Tournament enemy-power formula `200 + (year × 50)`,
# which is per-run year, not the calendar year (year_for returns 1627+).
static func run_year(week: int) -> int:
	return (week - 1) / WEEKS_PER_YEAR + 1


# Season cuts the 48-week year into six rough thirds-of-a-tournament-cycle
# that align with the prose pools in `Chronicle._season_clause`. Surfaced on
# the Planning / Pre-Battle / Weekly Summary headers as a small ❀ chip so
# the player feels the year pass.
const SEASON_EARLY_SPRING: String = "Early Spring"
const SEASON_LATE_SPRING: String  = "Late Spring"
const SEASON_SUMMER: String       = "Summer"
const SEASON_HARVEST: String      = "Harvest"
const SEASON_AUTUMN: String       = "Autumn"
const SEASON_WINTER: String       = "Winter"

const SEASON_GLYPHS: Dictionary = {
	SEASON_EARLY_SPRING: "❁",
	SEASON_LATE_SPRING:  "❀",
	SEASON_SUMMER:       "☀",
	SEASON_HARVEST:      "🌾",
	SEASON_AUTUMN:       "🍂",
	SEASON_WINTER:       "❄",
}


# Returns the season label for the given week (1-based). Boundaries match
# `Chronicle._season_clause` so the prose feel and the HUD label agree.
static func season_for(week: int) -> String:
	var w: int = week_of_year(week)
	if w <= 6:
		return SEASON_EARLY_SPRING
	elif w <= 12:
		return SEASON_LATE_SPRING
	elif w <= 24:
		return SEASON_SUMMER
	elif w <= 32:
		return SEASON_HARVEST
	elif w <= 40:
		return SEASON_AUTUMN
	return SEASON_WINTER


# Short "❀ Summer" style chip — used on the Planning ContextLabel + the
# Pre-Battle / Weekly Summary headers. Empty when the input week is invalid.
static func season_chip(week: int) -> String:
	if week <= 0:
		return ""
	var label: String = season_for(week)
	var glyph: String = str(SEASON_GLYPHS.get(label, "❀"))
	return "%s %s" % [glyph, label]
