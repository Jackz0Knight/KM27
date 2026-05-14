extends Node

# Central run state. Stubbed in Phase 0; populated by Phases 1–7.
# See ROADMAP.md for what each field will end up driving.

var week: int = 1
var year: int = 1627
var phase: String = "planning"  # "planning" | "tick" | "pre_battle" | "resolution"

var resources: Dictionary = {
	"wood": 5,
	"fibres": 5,
	"copper_ore": 2,
}

var roster: Array = []          # Array[Unit] — populated in Phase 3.
var world = null                # World instance — populated in Phase 1.
var tournament_streak: int = 0  # Counter for win-2-in-a-row → Grand Tournament.
