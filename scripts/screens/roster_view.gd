extends Control

# Shows all 4 units after the Knight has been chosen and routes to the
# Planning screen on Continue.

@onready var header: Label = $Margin/VBox/Header
@onready var resources_lbl: RichTextLabel = $Margin/VBox/Resources
@onready var cards: VBoxContainer = $Margin/VBox/Scroll/Cards
@onready var continue_btn: Button = $Margin/VBox/ContinueButton


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
	resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory))

	for unit in GameState.roster:
		cards.add_child(UnitCard.build(unit))

	continue_btn.pressed.connect(_on_continue)
	ScreenFade.fade_in(self)


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/planning.tscn")
