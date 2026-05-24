extends Control

# GDD §2 Loss screen. Triggered by Home Battle loss (or Bandit Ambush /
# village_raid / equivalent with no defenders). Surfaces the chronicler's
# closing reflection, a grouped record of the run, and per-unit chronicle
# lines so the household reads as a household, not a row of stats.

@onready var title_lbl: Label = $Center/VBox/Title
@onready var cause_lbl: Label = $Center/VBox/Cause
@onready var stats_pane: VBoxContainer = $Center/VBox/Stats
@onready var new_run_btn: Button = $Center/VBox/NewRunBtn


func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	_render()
	ScreenFade.fade_in(self, 0.5)


func _render() -> void:
	var r: Dictionary = GameState.last_battle_result
	cause_lbl.text = "Cause: %s loss." % EventKind.label(r.get("event_kind", EventKind.HOME_BATTLE))

	for c in stats_pane.get_children():
		c.queue_free()

	# Chronicler's closing reflection — three lines, drawn from the Knight's
	# oath / reputation band / castles taken. Sets the tone above the dry
	# record of facts.
	var epitaph: String = Chronicle.generate_run_epitaph(GameState, "loss")
	if epitaph != "":
		var epitaph_lbl := Label.new()
		epitaph_lbl.text = epitaph
		epitaph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		epitaph_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		epitaph_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		epitaph_lbl.modulate = Palette.PARCHMENT_BRIGHT
		epitaph_lbl.add_theme_font_size_override("font_size", 14)
		stats_pane.add_child(epitaph_lbl)
		stats_pane.add_child(_fleuron_divider())

	# Record block.
	_add_header("The Record")
	_add("Week reached: %d  (Year %d, week %d / 48 — %s)" % [
		GameState.week, GameState.current_year(), GameState.current_week_of_year(),
		Calendar.season_for(GameState.week),
	])
	_add("Reputation at the end: %d  (%s)" % [GameState.reputation, ResourceDB.reputation_label(GameState.reputation)])
	_add("Tournament streak: %d" % GameState.tournament_streak)
	_add("Castles taken: %d / 8" % _castles_taken())
	_add("Stores at the end: Gold %d  ·  %s" % [GameState.gold, _describe_inventory()])

	if r.get("fought", false):
		_add("Final battle: %d player vs %d enemy." % [r["player_total"], r["enemy_total"]])

	# Per-unit chronicle.
	stats_pane.add_child(_fleuron_divider())
	_add_header("The Household")
	for u in GameState.roster:
		_add_unit_line(u)

	EventBus.run_ended.emit("loss")


func _castles_taken() -> int:
	if GameState.world == null:
		return 0
	return 8 - GameState.world.castles.size()


func _add(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_pane.add_child(lbl)


func _add_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = "❦  %s" % text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Palette.GOLD
	lbl.add_theme_font_size_override("font_size", 16)
	stats_pane.add_child(lbl)


# One line per unit, dressed with their epithet (if earned), trait label,
# and oath stat-key — the chronicler's compact version of who they were.
func _add_unit_line(u: Unit) -> void:
	var bits: Array[String] = []
	var name_part: String = "%s — %s" % [u.unit_name, u.class_label()]
	if u.epithet != "":
		name_part = "%s, %s" % [name_part, u.epithet]
	bits.append(name_part)
	if u.trait_id != "" and TraitPool.is_valid(u.trait_id):
		bits.append("❖ %s" % TraitPool.name_for(u.trait_id))
	if u.oath_kind != "":
		bits.append("oath of %s" % u.oath_kind.capitalize())
	bits.append("stat total %d" % u.stats.sum())

	var lbl := Label.new()
	lbl.text = "  •  " + "  ·  ".join(bits)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.modulate = Palette.PARCHMENT
	stats_pane.add_child(lbl)


# Matches the chronicle fleuron used on chooser cards + knight overview —
# centred glyph flanked by faint rules.
func _fleuron_divider() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var left := HSeparator.new()
	left.modulate = Palette.FADED_BG
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var glyph := Label.new()
	glyph.text = "❦"
	glyph.modulate = Palette.GOLD_DEEP
	glyph.add_theme_font_size_override("font_size", 14)
	row.add_child(glyph)

	var right := HSeparator.new()
	right.modulate = Palette.FADED_BG
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)

	return row


func _describe_inventory() -> String:
	var parts: Array[String] = []
	for id: String in GameState.inventory:
		var amt: int = GameState.inventory[id]
		if amt > 0:
			var entry: Dictionary = ResourceDB.RESOURCES.get(id, {})
			parts.append("%s×%d" % [entry.get("name", id), amt])
	if parts.is_empty():
		return "nothing"
	return ", ".join(parts)


func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
