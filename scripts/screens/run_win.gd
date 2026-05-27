extends Control

# GDD §2 Win screen — reached only by winning a Grand Tournament. Mirrors
# game_over's structure with the celebratory variant of every line: the
# chronicler's closing reflection in the high style, a grouped record of
# the achievement, and per-unit chronicle lines so the household is named
# as a household, not a final stat table.

@onready var stats_pane: VBoxContainer = $Center/VBox/Stats
@onready var new_run_btn: Button = $Center/VBox/NewRunBtn


func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	_render()
	ScreenFade.fade_in(self, 0.6)


func _render() -> void:
	for c in stats_pane.get_children():
		c.queue_free()

	# Chronicler's closing reflection — three lines, written in the high
	# style allowed only at the realm-won moment.
	var epitaph: String = Chronicle.generate_run_epitaph(GameState, "win")
	if epitaph != "":
		var epitaph_lbl := Label.new()
		epitaph_lbl.text = epitaph
		epitaph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		epitaph_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		epitaph_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		epitaph_lbl.modulate = Palette.GOLD_BRIGHT
		epitaph_lbl.add_theme_font_size_override("font_size", 14)
		stats_pane.add_child(epitaph_lbl)
		stats_pane.add_child(_fleuron_divider())

	_add_header("The Record")
	_add("Year %d, Week %d  (week %d / 48 — %s)" % [
		GameState.current_year(), GameState.week, GameState.current_week_of_year(),
		Calendar.season_for(GameState.week),
	])
	_add("Reputation at the crown: %d  (%s)" % [GameState.reputation, ResourceDB.reputation_label(GameState.reputation)])
	_add("Castles taken: %d / 8" % _castles_taken())
	_add("Stores at the close: Gold %d  ·  %s" % [GameState.gold, _describe_inventory()])

	stats_pane.add_child(_fleuron_divider())
	_add_header("The Household")
	for u in GameState.roster:
		_add_unit_line(u)

	EventBus.run_ended.emit("win")


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
	lbl.modulate = Palette.PARCHMENT_BRIGHT
	stats_pane.add_child(lbl)


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
