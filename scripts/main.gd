extends Control

# Title / main-menu screen. Layout:
#   LEFT  — Title, seed row, New Game, Continue (if save), Quit, Quick Start (debug)
#   RIGHT — Run History panel (from SaveManager)

var _seed_edit: LineEdit = null
var _history_rtl: RichTextLabel = null


func _ready() -> void:
	randomize()
	_build_layout()
	print("[KM27] Title ready.")


func _build_layout() -> void:
	# Clear scene-provided children so we fully own the layout.
	for c in get_children():
		c.queue_free()

	# Full-screen HBox: Left panel | Right panel
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 0)
	add_child(hbox)

	# ── LEFT PANEL ──────────────────────────────
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(440, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_panel)

	var left_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		left_margin.add_theme_constant_override("margin_" + side, 40)
	left_panel.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_theme_constant_override("separation", 18)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_margin.add_child(left_vbox)

	# Title
	var title_lbl := Label.new()
	title_lbl.text = "Knight Manager 1627"
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	title_lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.02))
	title_lbl.add_theme_constant_override("outline_size", 4)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	left_vbox.add_child(title_lbl)

	var subtitle_lbl := Label.new()
	subtitle_lbl.text = "A survival management tale of knights and tournaments"
	subtitle_lbl.add_theme_font_size_override("font_size", 14)
	subtitle_lbl.modulate = Color(0.78, 0.74, 0.60)
	subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	left_vbox.add_child(subtitle_lbl)

	left_vbox.add_child(_make_spacer(8))

	# Seed row
	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	left_vbox.add_child(seed_row)

	var seed_pfx := Label.new()
	seed_pfx.text = "Seed"
	seed_pfx.modulate = Color(0.78, 0.74, 0.60)
	seed_row.add_child(seed_pfx)

	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size = Vector2(170, 32)
	_seed_edit.placeholder_text = "(random)"
	_seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_edit.max_length = 12
	_seed_edit.text_submitted.connect(_on_seed_submitted)
	seed_row.add_child(_seed_edit)

	var rand_btn := Button.new()
	rand_btn.text = "↻"
	rand_btn.custom_minimum_size = Vector2(44, 32)
	rand_btn.tooltip_text = "Roll a fresh random seed"
	rand_btn.pressed.connect(func(): _set_seed(randi()))
	seed_row.add_child(rand_btn)

	_set_seed(randi())

	left_vbox.add_child(_make_spacer(4))

	# New Game button
	var new_game_btn := Button.new()
	new_game_btn.text = "Begin a New Run"
	new_game_btn.custom_minimum_size = Vector2(280, 52)
	new_game_btn.add_theme_font_size_override("font_size", 20)
	new_game_btn.pressed.connect(_on_start)
	left_vbox.add_child(new_game_btn)

	# Continue button (only if save exists)
	if SaveManager.has_save():
		var cont_btn := Button.new()
		cont_btn.text = "Continue Run"
		cont_btn.custom_minimum_size = Vector2(280, 44)
		cont_btn.add_theme_font_size_override("font_size", 17)
		cont_btn.modulate = Color(0.80, 0.95, 0.80)
		cont_btn.pressed.connect(_on_continue)
		left_vbox.add_child(cont_btn)

	# Options
	var options_btn := Button.new()
	options_btn.text = "Options"
	options_btn.custom_minimum_size = Vector2(280, 40)
	options_btn.pressed.connect(_on_options)
	left_vbox.add_child(options_btn)

	# Quit
	var quit_btn := Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.custom_minimum_size = Vector2(280, 40)
	quit_btn.pressed.connect(func(): get_tree().quit())
	left_vbox.add_child(quit_btn)

	# Quick Start (debug only)
	if OS.is_debug_build():
		var qs_btn := Button.new()
		qs_btn.text = "⚙ Quick Start (Dev)"
		qs_btn.custom_minimum_size = Vector2(280, 36)
		qs_btn.modulate = Color(0.85, 0.85, 0.50)
		qs_btn.tooltip_text = "Start at week 10 with gold, stocked inventory, and preset stats (debug only)"
		qs_btn.pressed.connect(_on_quick_start)
		left_vbox.add_child(qs_btn)

	# ── RIGHT PANEL ──────────────────────────────
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hbox.add_child(right_panel)

	var right_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		right_margin.add_theme_constant_override("margin_" + side, 32)
	right_panel.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_child(right_vbox)

	var hist_hdr := Label.new()
	hist_hdr.text = "Run History"
	hist_hdr.add_theme_font_size_override("font_size", 22)
	hist_hdr.modulate = Color(1.0, 0.84, 0.42)
	right_vbox.add_child(hist_hdr)

	right_vbox.add_child(HSeparator.new())

	var hist_scroll := ScrollContainer.new()
	hist_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_child(hist_scroll)

	_history_rtl = RichTextLabel.new()
	_history_rtl.bbcode_enabled = true
	_history_rtl.fit_content = false
	_history_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hist_scroll.add_child(_history_rtl)

	_refresh_history()


func _refresh_history() -> void:
	if _history_rtl == null:
		return
	var history: Array[Dictionary] = SaveManager.run_history
	if history.is_empty():
		_history_rtl.parse_bbcode("[color=#666666]No completed runs yet — get out there.[/color]")
		return

	var lines: Array[String] = []
	var reversed: Array[Dictionary] = history.duplicate()
	reversed.reverse()
	for i in range(reversed.size()):
		var entry: Dictionary = reversed[i]
		var run_num: int = reversed.size() - i
		var outcome: String = str(entry.get("outcome", "?"))
		var weeks: int = int(entry.get("weeks_survived", 0))
		var date: String = str(entry.get("date", ""))

		if outcome == "won":
			lines.append("[color=#FFD61A]Run #%d   Week %d / WON 🏆   %s[/color]" % [run_num, weeks, date])
		else:
			lines.append("[color=#888888]Run #%d   Week %d / Lost   %s[/color]" % [run_num, weeks, date])

	_history_rtl.parse_bbcode("\n".join(lines))


func _make_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


# ---------- seed ----------

func _set_seed(value: int) -> void:
	if _seed_edit != null:
		_seed_edit.text = str(value)


func _resolve_seed() -> int:
	if _seed_edit == null:
		return randi()
	var raw: String = _seed_edit.text.strip_edges()
	if raw == "" or not raw.is_valid_int():
		var fresh: int = randi()
		_set_seed(fresh)
		return fresh
	return int(raw)


# ---------- button handlers ----------

func _on_start() -> void:
	var seed_value: int = _resolve_seed()
	GameState.start_run(seed_value)
	GameState.knight_candidates = RosterGenerator.roll_knight_candidates()
	GameState.starting_squires = RosterGenerator.roll_starting_squires()
	get_tree().change_scene_to_file("res://scenes/screens/knight_chooser.tscn")


func _on_seed_submitted(_text: String) -> void:
	_on_start()


func _on_continue() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/screens/planning.tscn")


func _on_options() -> void:
	const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")
	SettingsPopup.show_for(self)


func _on_quick_start() -> void:
	# Dev convenience: start at week 10 with gold + stocked inventory + strong stats.
	var seed_value: int = _resolve_seed()
	GameState.start_run(seed_value)
	GameState.knight_candidates = RosterGenerator.roll_knight_candidates()
	GameState.starting_squires = RosterGenerator.roll_starting_squires()

	# Pick the first knight candidate automatically.
	if not GameState.knight_candidates.is_empty():
		var knight: Unit = GameState.knight_candidates[0]
		for k in Stats.STAT_KEYS:
			knight.stats.set_value(k, 8)
		knight.potential_ability = 180
		GameState.roster.clear()
		GameState.roster.append(knight)
		for sq in GameState.starting_squires:
			for k in Stats.STAT_KEYS:
				sq.stats.set_value(k, 8)
			sq.potential_ability = 140
			GameState.roster.append(sq)

	GameState.week = 10
	GameState.gold = 200

	# Stock T1 resources × 10 each
	for id in ResourceDB.RESOURCES:
		var entry: Dictionary = ResourceDB.RESOURCES[id]
		if not entry.has("type"):   # raw material
			GameState.inventory[id] = 10

	GameState.roll_current_event()
	get_tree().change_scene_to_file("res://scenes/screens/planning.tscn")
