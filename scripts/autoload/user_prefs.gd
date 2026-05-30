extends Node

# Per-machine user preferences. Lives outside the run save (`savegame.json`)
# so a fresh run inherits the player's chosen UI scale and audio bus volumes,
# rather than resetting every campaign. Backed by `user://prefs.cfg` via
# Godot's `ConfigFile`.
#
# Autoload pattern (see CLAUDE.md): `extends Node`, no `class_name`.

const PREFS_PATH: String = "user://prefs.cfg"

const UI_SCALE_MIN: float = 0.75
const UI_SCALE_MAX: float = 1.40
const UI_SCALE_DEFAULT: float = 1.0

var ui_scale: float = UI_SCALE_DEFAULT


func _ready() -> void:
	_load()
	# Apply on startup so the title screen already honours the saved scale.
	# Deferred so the viewport is fully set up before we touch its scale.
	call_deferred("_apply_ui_scale")


# ── UI scale ──────────────────────────────────────────────────────────────

func set_ui_scale(scale: float) -> void:
	ui_scale = clampf(scale, UI_SCALE_MIN, UI_SCALE_MAX)
	_apply_ui_scale()
	_save()


func _apply_ui_scale() -> void:
	# `content_scale_factor` scales every Control in the viewport in one shot —
	# the project's `canvas_items` stretch mode (project.godot) plays nice with
	# this, so 0.85 reads as "everything 15% smaller" without any per-screen work.
	var win: Window = get_tree().root
	if win != null:
		win.content_scale_factor = ui_scale


# ── Persistence ────────────────────────────────────────────────────────────

func _load() -> void:
	var cfg := ConfigFile.new()
	var err: int = cfg.load(PREFS_PATH)
	if err != OK:
		return  # first launch, no file yet — defaults are fine
	ui_scale = clampf(float(cfg.get_value("ui", "scale", UI_SCALE_DEFAULT)), UI_SCALE_MIN, UI_SCALE_MAX)


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(PREFS_PATH)  # preserve any other sections we may add later
	cfg.set_value("ui", "scale", ui_scale)
	cfg.save(PREFS_PATH)
