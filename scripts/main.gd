extends Control


func _ready() -> void:
	print("[KM27] Main scene ready. Year %d, week-of-year %d (week #%d)." % [
		GameState.current_year(), GameState.current_week_of_year(), GameState.week,
	])
	print("[KM27] Starting resources: %s" % GameState.resources.describe())
	print("[KM27] Phase: %s" % PhaseMachine.label(GameState.phase_machine.current))
