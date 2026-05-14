class_name PhaseMachine
extends RefCounted

# Owns the weekly phase cycle per GDD §5: Planning → Tick → Pre-Battle Review
# → Resolution → back to Planning (next week).
#
# Held as a field on GameState rather than registered as an autoload so the
# transitions stay testable in isolation. Every transition emits via the
# EventBus autoload so any scene can listen without coupling.

enum Phase { PLANNING, TICK, PRE_BATTLE, RESOLUTION }

const ORDER: Array = [
	Phase.PLANNING,
	Phase.TICK,
	Phase.PRE_BATTLE,
	Phase.RESOLUTION,
]

var current: Phase = Phase.PLANNING


func transition(new_phase: Phase) -> void:
	if new_phase == current:
		return
	current = new_phase
	EventBus.phase_changed.emit(new_phase)


func next_phase() -> Phase:
	var idx: int = ORDER.find(current)
	return ORDER[(idx + 1) % ORDER.size()]


# Step to the next phase in the cycle. Returns true when the cycle wraps
# (Resolution → Planning), i.e. the week is finished — caller can then bump
# the week counter and roll a new event.
func advance() -> bool:
	var wrapped: bool = current == Phase.RESOLUTION
	transition(next_phase())
	return wrapped


static func label(phase: Phase) -> String:
	match phase:
		Phase.PLANNING: return "Planning"
		Phase.TICK: return "Tick"
		Phase.PRE_BATTLE: return "Pre-Battle Review"
		Phase.RESOLUTION: return "Resolution"
	return "Unknown"
