extends Node

# Cross-scene signal hub. Declared signals fire from GameState / PhaseMachine /
# battle resolvers; any scene can listen without holding a hard reference.
# Add new signals here as future phases need them.

signal run_started(seed_value: int)
signal run_ended(outcome: String)          # "win" | "loss"

signal week_advanced(week: int)
signal phase_changed(phase: int)           # PhaseMachine.Phase

signal event_rolled(kind: int)             # EventKind
signal battle_resolved(result: Dictionary)
signal expedition_returned(expedition: Resource)
