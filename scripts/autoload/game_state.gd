extends Node

# Central run state — populated as phases land. The GameState is an autoload
# (singleton), so scenes can read/write it without passing references around.
#
# Phase ownership:
#   Phase 1: World / WorldGenerator wiring (`world`).
#   Phase 2: PhaseMachine, calendar helpers, EventRoller (`current_event`,
#            `tournament_streak`, week/year helpers).
#   Phase 3: Roster population (1 Knight + 3 Squires).
#   Phase 4: Expedition tracking, pending-task buffer, away-week selections.
#   Phase 5+: Tick / Pre-Battle / battle resolution.

var week: int = 1
var phase_machine: PhaseMachine = null
var resources: ResourceBundle = null
var roster: Array[Unit] = []
var world: World = null
var tournament_streak: int = 0
var current_event: int = -1   # EventKind; -1 means "no event rolled yet".

# Transient: Knight candidates shown on the chooser screen. Cleared once one
# is picked.
var knight_candidates: Array[Unit] = []

# Phase 4: active expeditions. Each one removes its units from the home pool
# until weeks_remaining ticks to 0 (Phase 5).
var expeditions: Array[Expedition] = []
var _next_expedition_id: int = 1

# Phase 4: away-week selections — the player decides during Planning, the
# battle resolves during Resolution (Phase 6 wires that). Reset every week.
var pending_away_party: Array[int] = []
var pending_away_mode: String = ""             # "pillage" | "assault" | ""
var pending_assault_castle: Castle = null


func _ready() -> void:
	phase_machine = PhaseMachine.new()
	resources = ResourceBundle.new(5, 5, 2)


# ---------- calendar passthroughs ----------

func current_year() -> int:
	return Calendar.year_for(week)


func current_week_of_year() -> int:
	return Calendar.week_of_year(week)


func is_tournament_week() -> bool:
	return Calendar.is_tournament_week(week)


# ---------- run lifecycle ----------

func has_active_run() -> bool:
	return world != null


func start_run(seed_value: int) -> void:
	world = WorldGenerator.generate(seed_value)
	week = 1
	tournament_streak = 0
	resources = ResourceBundle.new(5, 5, 2)
	roster.clear()
	current_event = -1
	expeditions.clear()
	_next_expedition_id = 1
	_clear_pending_away()
	if phase_machine != null:
		phase_machine.current = PhaseMachine.Phase.PLANNING
	EventBus.run_started.emit(seed_value)


# ---------- weekly clock ----------

func roll_current_event() -> int:
	current_event = EventRoller.roll(week, tournament_streak)
	EventBus.event_rolled.emit(current_event)
	return current_event


func advance_to_next_week() -> void:
	week += 1
	current_event = -1
	_clear_pending_away()
	EventBus.week_advanced.emit(week)


# ---------- roster helpers ----------

func find_unit(unit_id: int) -> Unit:
	for u in roster:
		if u.id == unit_id:
			return u
	return null


func at_home_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in roster:
		if u.is_at_home():
			out.append(u)
	return out


# ---------- expeditions ----------

func launch_expedition(kind: Expedition.Kind, target_x: int, target_y: int, unit_ids: Array[int]) -> Expedition:
	var exp := Expedition.new(_next_expedition_id, kind, target_x, target_y, unit_ids)
	_next_expedition_id += 1
	expeditions.append(exp)

	for uid in unit_ids:
		var u: Unit = find_unit(uid)
		if u != null:
			u.current_task = Unit.TASK_EXPEDITION
			u.expedition_id = exp.id

	var tile: MapTile = world.get_tile(target_x, target_y)
	if tile != null:
		tile.active_expedition = exp

	return exp


# Removes an expedition from the active list and clears its tile + units.
# Phase 5's Tick will call this when weeks_remaining hits 0.
func complete_expedition(exp: Expedition) -> void:
	expeditions.erase(exp)
	var tile: MapTile = world.get_tile(exp.target_x, exp.target_y)
	if tile != null and tile.active_expedition == exp:
		tile.active_expedition = null
	for uid in exp.unit_ids:
		var u: Unit = find_unit(uid)
		if u != null:
			u.current_task = Unit.TASK_IDLE
			u.expedition_id = -1


# ---------- planning helpers ----------

func _clear_pending_away() -> void:
	pending_away_party.clear()
	pending_away_mode = ""
	pending_assault_castle = null
