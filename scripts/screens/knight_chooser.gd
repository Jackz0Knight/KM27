extends Control

# Shows the 3 Knight candidates rolled at the start of a run and lets the
# player pick one. The chosen Knight + 3 pre-rolled Squires become the run's
# permanent roster (GDD §3, §9).
#
# Squires are pre-rolled in `RosterGenerator.roll_starting_squires()` and
# displayed in a top row so the player can see who they're picking a Knight
# to lead before committing.

@onready var squires_row: HBoxContainer = $Margin/VBox/Scroll/ScrollBody/SquiresRow
@onready var cards: HBoxContainer = $Margin/VBox/Scroll/ScrollBody/Cards


func _ready() -> void:
	# Fallback for F6'ing this scene directly without going through Title.
	if GameState.knight_candidates.is_empty() or GameState.starting_squires.is_empty():
		print("[KnightChooser] No candidates on GameState — rolling a fresh run for dev.")
		GameState.start_run(randi())
		GameState.knight_candidates = RosterGenerator.roll_knight_candidates()
		GameState.starting_squires = RosterGenerator.roll_starting_squires()

	for squire in GameState.starting_squires:
		var card: Control = UnitCard.build(squire)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		squires_row.add_child(card)

	for i in range(GameState.knight_candidates.size()):
		var u: Unit = GameState.knight_candidates[i]
		# show_chronicle = true: origin paragraph and oath shown on the chooser
		# so the player recruits a person, not just a stat block.
		var card: Control = UnitCard.build(
			u, _on_choose.bind(i), "Take %s into service" % u.unit_name,
			Callable(), true,
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cards.add_child(card)

	ScreenFade.fade_in(self)


func _on_choose(index: int) -> void:
	var chosen: Unit = GameState.knight_candidates[index]
	GameState.roster = RosterGenerator.build_starting_roster(chosen, GameState.starting_squires)
	GameState.knight_candidates.clear()
	GameState.starting_squires.clear()
	print("[KnightChooser] Chose %s. Roster: %d units." % [
		chosen.unit_name, GameState.roster.size(),
	])
	get_tree().change_scene_to_file("res://scenes/screens/roster_view.tscn")
