extends Control

# GDD §2 Loss screen. Only triggered by Home Battle loss (or Bandit Ambush
# with no defenders, etc.). Shows cause + run stats and offers a fresh start.

@onready var title_lbl: Label = $Center/VBox/Title
@onready var cause_lbl: Label = $Center/VBox/Cause
@onready var stats_pane: VBoxContainer = $Center/VBox/Stats
@onready var new_run_btn: Button = $Center/VBox/NewRunBtn


func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	_render()


func _render() -> void:
	var r: Dictionary = GameState.last_battle_result
	cause_lbl.text = "Cause: %s loss." % EventKind.label(r.get("event_kind", EventKind.HOME_BATTLE))

	for c in stats_pane.get_children():
		c.queue_free()
	_add("Week reached: %d (Year %d, week %d/48)" % [
		GameState.week, GameState.current_year(), GameState.current_week_of_year(),
	])
	_add("Tournaments won (streak): %d" % GameState.tournament_streak)
	_add("Castles taken: %d" % _castles_taken())
	_add("Stores at end: %s" % GameState.resources.describe())

	# Run final breakdown of the last battle.
	if r.get("fought", false):
		_add("Final battle: %d player vs %d enemy." % [r["player_total"], r["enemy_total"]])

	EventBus.run_ended.emit("loss")


func _castles_taken() -> int:
	# At world gen there are 8 castles; subtract whatever's left to count wins.
	if GameState.world == null:
		return 0
	return 8 - GameState.world.castles.size()


func _add(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_pane.add_child(lbl)


func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
