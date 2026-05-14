extends Control

# Title screen — the project's main_scene. The seed is editable so the
# player can re-roll the same world, paste a friend's seed, etc. The
# Randomise button rolls a fresh int into the field. Begin reads whatever
# is in the box (parsing as int, falling back to random if it's empty
# or non-numeric).

@onready var seed_edit: LineEdit = $Center/VBox/SeedRow/SeedEdit
@onready var randomise_btn: Button = $Center/VBox/SeedRow/RandomiseBtn
@onready var start_button: Button = $Center/VBox/StartButton
@onready var options_button: Button = $Center/VBox/OptionsButton
@onready var quit_button: Button = $Center/VBox/QuitButton

const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")


func _ready() -> void:
	randomize()
	_set_seed(randi())
	start_button.pressed.connect(_on_start)
	options_button.pressed.connect(_on_options)
	quit_button.pressed.connect(_on_quit)
	randomise_btn.pressed.connect(_on_randomise)
	seed_edit.text_submitted.connect(_on_seed_submitted)
	print("[KM27] Title ready.")


func _set_seed(value: int) -> void:
	seed_edit.text = str(value)


# Parse whatever's in the seed field. Empty / non-numeric input falls back
# to a fresh random seed (and the field is updated to match, so the player
# can see what they actually launched with).
func _resolve_seed() -> int:
	var raw: String = seed_edit.text.strip_edges()
	if raw == "" or not raw.is_valid_int():
		var fresh: int = randi()
		_set_seed(fresh)
		return fresh
	return int(raw)


func _on_start() -> void:
	var seed_value: int = _resolve_seed()
	GameState.start_run(seed_value)
	GameState.knight_candidates = RosterGenerator.roll_knight_candidates()
	GameState.starting_squires = RosterGenerator.roll_starting_squires()
	get_tree().change_scene_to_file("res://scenes/screens/knight_chooser.tscn")


func _on_randomise() -> void:
	_set_seed(randi())


func _on_seed_submitted(_text: String) -> void:
	# Pressing Enter in the seed field acts like clicking Begin.
	_on_start()


func _on_options() -> void:
	SettingsPopup.show_for(self)


func _on_quit() -> void:
	get_tree().quit()
