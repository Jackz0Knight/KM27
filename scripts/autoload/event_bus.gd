extends Node

# Cross-scene signal hub. Signals are declared here so any scene can wire to
# them without coupling to the emitting node. Add signals as each phase lands.
#
# Planned signals (declare as phases need them):
#   signal week_advanced(week: int)
#   signal phase_changed(phase: String)
#   signal expedition_returned(expedition: Resource)
#   signal battle_resolved(result: Dictionary)
#   signal run_ended(outcome: String)  # "win" | "loss"
