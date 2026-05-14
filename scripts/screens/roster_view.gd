extends Control

# Shows all 4 units after the Knight has been chosen. Read-only in Phase 3 —
# Phase 4's Planning screen takes over the "Continue" hand-off.

@onready var header: Label = $Margin/VBox/Header
@onready var resources_lbl: Label = $Margin/VBox/Resources
@onready var cards: VBoxContainer = $Margin/VBox/Scroll/Cards


func _ready() -> void:
	if GameState.roster.is_empty():
		print("[RosterView] Roster empty — bouncing back to Title.")
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return

	header.text = "Year %d, Week %d (week %d of year) — Your Household" % [
		GameState.current_year(),
		GameState.week,
		GameState.current_week_of_year(),
	]
	resources_lbl.text = "Stores — %s" % GameState.resources.describe()

	for unit in GameState.roster:
		cards.add_child(UnitCard.build(unit))
