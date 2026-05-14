extends Control

# Shows the 3 Knight candidates rolled at the start of a run and lets the
# player pick one. The chosen Knight + 3 fresh Squires become the run's
# permanent roster (GDD §3, §9).

@onready var cards: VBoxContainer = $Margin/VBox/Scroll/Cards


func _ready() -> void:
	var candidates: Array[Unit] = GameState.knight_candidates
	# Fallback for F6'ing this scene directly without going through Title.
	if candidates.is_empty():
		print("[KnightChooser] No candidates on GameState — rolling a fresh run for dev.")
		GameState.start_run(randi())
		candidates = RosterGenerator.roll_knight_candidates()
		GameState.knight_candidates = candidates

	for i in range(candidates.size()):
		var u: Unit = candidates[i]
		var card: Control = UnitCard.build(
			u, _on_choose.bind(i), "Take %s into service" % u.unit_name
		)
		cards.add_child(card)


func _on_choose(index: int) -> void:
	var chosen: Unit = GameState.knight_candidates[index]
	GameState.roster = RosterGenerator.build_starting_roster(chosen)
	GameState.knight_candidates.clear()
	print("[KnightChooser] Chose %s. Roster: %d units." % [
		chosen.unit_name, GameState.roster.size(),
	])
	get_tree().change_scene_to_file("res://scenes/screens/roster_view.tscn")
