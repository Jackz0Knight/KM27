extends Node

# Central run state — populated as phases land. The GameState is an autoload
# (singleton), so scenes can read/write it without passing references around.
#
# Phase ownership:
#   Phase 1: World / WorldGenerator wiring (`world`).
#   Phase 2: PhaseMachine, calendar helpers, EventRoller (`current_event`,
#            `tournament_streak`, week/year helpers).
#   Phase 3: Roster population (1 Knight + 3 Squires).
#   Phase 4+: Per-week tasks, expeditions, formation, battle resolution.

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

func start_run(seed_value: int) -> void:
	world = WorldGenerator.generate(seed_value)
	week = 1
	tournament_streak = 0
	resources = ResourceBundle.new(5, 5, 2)
	roster.clear()
	current_event = -1
	if phase_machine != null:
		phase_machine.current = PhaseMachine.Phase.PLANNING
	EventBus.run_started.emit(seed_value)


# ---------- weekly clock ----------

# Rolls the event for the *current* week and stores it on the GameState.
# Called at the top of the Planning Phase (Phase 4 wires this).
func roll_current_event() -> int:
	current_event = EventRoller.roll(week, tournament_streak)
	EventBus.event_rolled.emit(current_event)
	return current_event


# Bumps the week counter. Called by the phase machine when the cycle wraps
# from Resolution back to Planning. Phase 6+ will trigger this.
func advance_to_next_week() -> void:
	week += 1
	current_event = -1
	EventBus.week_advanced.emit(week)


# ---------- helpers ----------

func at_home_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in roster:
		if u.is_at_home():
			out.append(u)
	return out
