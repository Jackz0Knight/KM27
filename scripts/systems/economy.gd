class_name Economy
extends RefCounted

# §18.2 — the single tuning surface for every gold edge in the game.
#
# Values here MIRROR the pre-§18 placeholders exactly: this commit centralises
# the formulas without rebalancing (Phase 8 owns the actual balance pass). The
# point is that when Phase 8 starts, the whole economy is retunable from one
# file instead of being scattered across game_state / tick / resolution.
#
# Where the GDD §18.2 proposes a richer formula than what ships today, the
# proposal is noted inline so the Phase-8 pass has the design intent in front
# of it. Unwired proposals (holdings income) are documented but not applied —
# wiring them changes balance, which is deliberately out of scope until Phase 8.

# --- Income ----------------------------------------------------------------

## Flat weekly stipend. GDD §18.2 proposes `8 + (year × 2)`; ships flat.
const WEEKLY_STIPEND: int = 10

## Per-castle holdings income. GDD §18.2 proposes `castles_held × 6`. NOT wired
## (no held-castle tracking exists yet — assaulted castles are removed from the
## world, not retained). Left as a documented Phase-8 hook.
const HOLDINGS_INCOME_PER_CASTLE: int = 6

# --- Upkeep ----------------------------------------------------------------

## Flat per-roster-unit weekly upkeep. GDD §18.2 proposes a class split
## (`4 + knights×3 + squires×2`); ships flat per unit.
const UPKEEP_PER_UNIT: int = 5

# --- Tournament purse ------------------------------------------------------

const TOURNAMENT_PURSE_BASE: int = 50
const TOURNAMENT_PURSE_PER_NUMBER: int = 25
const TOURNAMENT_REP_DIVISOR: int = 4
const TOURNAMENT_REP_CAP: int = 25

# --- Tavern riot win bonus -------------------------------------------------

const TAVERN_RIOT_BASE_GOLD: int = 6
const TAVERN_RIOT_WEEK_DIVISOR: int = 8


# --- Helpers (read by game_state / tick / resolution) ----------------------

static func upkeep_cost(gs: Node) -> int:
	return gs.roster.size() * UPKEEP_PER_UNIT


## Reputation contribution to a tournament purse, clamped (no penalty for low
## standing). Exposed separately so the resolver can name it in the result note.
static func tournament_rep_bonus(reputation: int) -> int:
	return clampi(reputation / TOURNAMENT_REP_DIVISOR, 0, TOURNAMENT_REP_CAP)


## Full tournament / grand-tournament purse.
static func tournament_purse(week: int, reputation: int) -> int:
	return TOURNAMENT_PURSE_BASE \
		+ (Calendar.tournament_number(week) * TOURNAMENT_PURSE_PER_NUMBER) \
		+ tournament_rep_bonus(reputation)


## Tavern-riot win purse.
static func tavern_riot_gold(week: int) -> int:
	return TAVERN_RIOT_BASE_GOLD + floori(float(week) / float(TAVERN_RIOT_WEEK_DIVISOR))
