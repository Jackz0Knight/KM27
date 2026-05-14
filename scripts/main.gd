extends Control

# Title screen — the project's main_scene. Picks a random seed, lets the
# player kick off a new run, then routes to the Knight chooser.

@onready var seed_label: Label = $Center/VBox/SeedLabel
@onready var start_button: Button = $Center/VBox/StartButton
@onready var options_button: Button = $Center/VBox/OptionsButton
@onready var quit_button: Button = $Center/VBox/QuitButton

const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")

var _next_seed: int = 0


func _ready() -> void:
	randomize()
	_next_seed = randi()
	seed_label.text = "Seed: %d" % _next_seed
	start_button.pressed.connect(_on_start)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	print("[KM27] Title ready. Next seed=%d." % _next_seed)


func _on_start() -> void:
	GameState.start_run(_next_seed)
	GameState.knight_candidates = RosterGenerator.roll_knight_candidates()
	GameState.starting_squires = RosterGenerator.roll_starting_squires()
	get_tree().change_scene_to_file("res://scenes/screens/knight_chooser.tscn")


func _on_options() -> void:
	SettingsPopup.show_for(self)


func _on_quit() -> void:
	get_tree().quit()
