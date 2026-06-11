extends Node

# Headless CLI shell over SmokeEngine (scripts/dev/smoke_engine.gd — the
# actual auto-player lives there, shared with the F1 Dev Toolbar's "Smoke
# Harness" section).
#
# Runs as a scene (scenes/dev/smoke_run.tscn) so the game boots normally with
# all autoloads — a bare --script SceneTree can't compile the project's
# classes, which reference autoload globals. Via the wrapper (preferred — it
# also greps for engine error lines):
#   tools/smoke.sh --seeds=10 --weeks=60
# or directly:
#   godot --headless --path . res://scenes/dev/smoke_run.tscn -- --seeds=3
#
# Flags: --seeds=N --weeks=N --start-seed=N --no-ui (skip the screen probe)

const DEFAULT_SEEDS: int = 10
const DEFAULT_WEEKS: int = 60
const DEFAULT_START_SEED: int = 1627


func _ready() -> void:
	var seeds: int = DEFAULT_SEEDS
	var weeks: int = DEFAULT_WEEKS
	var start_seed: int = DEFAULT_START_SEED
	var ui_probe: bool = true
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--weeks="):
			weeks = maxi(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--start-seed="):
			start_seed = int(arg.get_slice("=", 1))
		elif arg == "--no-ui":
			ui_probe = false

	var engine := SmokeEngine.new()
	add_child(engine)
	engine.progress.connect(func(line: String) -> void: print(line))
	var report: Dictionary = await engine.run_battery(seeds, weeks, start_seed, ui_probe)
	get_tree().quit(0 if bool(report["passed"]) else 1)
