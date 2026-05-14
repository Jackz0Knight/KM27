extends Control

# Title screen — the project's main_scene. Picks a random seed, lets the
# player kick off a new run, then routes to the Knight chooser.

@onready var seed_label: Label = $Center/VBox/SeedLabel
@onready var start_button: Button = $Center/VBox/StartButton

var _next_seed: int = 0


func _ready() -> void:
	randomize()
	_next_seed = randi()
	seed_label.text = "Seed: %d" % _next_seed
	start_button.pressed.connect(_on_start)
	print("[KM27] Title ready. Next seed=%d." % _next_seed)


func _on_start() -> void:
	GameState.start_run(_next_seed)
	GameState.knight_candidates = RosterGenerator.roll_knight_candidates()
	get_tree().change_scene_to_file("res://scenes/screens/knight_chooser.tscn")
