extends Control

# Title / main-menu screen. Built procedurally in code rather than from a
# scene tree because the layout is data-driven (button list reacts to save
# state, Quick Start gates on debug build).
#
# Layout:
#   LEFT  — Heraldic frieze (4 house crests) → title → seed row → action
#           buttons (New Game / Continue / Options / Quit / Quick Start).
#   RIGHT — Run History totals strip + scrollable per-run list.

const HOUSE_FRIEZE_IDS: Array[String] = ["brann", "aldermere", "daven", "faldur"]
const GOLD: Color = Color(1.0, 0.84, 0.42)
const PARCHMENT: Color = Color(0.78, 0.74, 0.60)
const DIM_PARCHMENT: Color = Color(0.55, 0.50, 0.38)

var _seed_edit: LineEdit = null
var _history_rtl: RichTextLabel = null
var _totals_lbl: Label = null


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

	hbox.add_child(_build_left_panel())
	hbox.add_child(_build_right_panel())


# ─── LEFT PANEL ────────────────────────────────────────────────────────────

func _build_left_panel() -> Control:
	var left_panel := PanelContainer.new()
	left_panel.custom_minimum_size = Vector2(480, 0)
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var left_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		left_margin.add_theme_constant_override("margin_" + side, 40)
	left_panel.add_child(left_margin)

	var left_vbox := VBoxContainer.new()
	left_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	left_vbox.add_theme_constant_override("separation", 14)
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_margin.add_child(left_vbox)

	# Heraldic frieze — the four noble houses, side by side, as decoration.
	left_vbox.add_child(_build_heraldic_frieze())

	left_vbox.add_child(_make_spacer(4))

	# Title block — overline, big title, year, subtitle.
	left_vbox.add_child(_build_title_block())

	left_vbox.add_child(_make_ornament_divider())

	# Seed row.
	left_vbox.add_child(_build_seed_row())

	left_vbox.add_child(_make_spacer(2))

	# Primary action.
	var new_game_btn := Button.new()
	new_game_btn.text = "⚔  Begin a New Run"
	new_game_btn.custom_minimum_size = Vector2(300, 54)
	new_game_btn.add_theme_font_size_override("font_size", 20)
	new_game_btn.pressed.connect(_on_start)
	left_vbox.add_child(new_game_btn)

	# Continue (only if save exists).
	if SaveManager.has_save():
		var cont_btn := Button.new()
		cont_btn.text = "Continue Run"
		cont_btn.custom_minimum_size = Vector2(300, 44)
		cont_btn.add_theme_font_size_override("font_size", 17)
		cont_btn.modulate = Color(0.80, 0.95, 0.80)
		cont_btn.pressed.connect(_on_continue)
		left_vbox.add_child(cont_btn)

	# Options.
	var options_btn := Button.new()
	options_btn.text = "Options"
	options_btn.custom_minimum_size = Vector2(300, 40)
	options_btn.pressed.connect(_on_options)
	left_vbox.add_child(options_btn)

	# Quit.
	var quit_btn := Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.custom_minimum_size = Vector2(300, 40)
	quit_btn.pressed.connect(func(): get_tree().quit())
	left_vbox.add_child(quit_btn)

	# Quick Start (debug only).
	if OS.is_debug_build():
		var qs_btn := Button.new()
		qs_btn.text = "⚙ Quick Start (Dev)"
		qs_btn.custom_minimum_size = Vector2(300, 36)
		qs_btn.modulate = Color(0.85, 0.85, 0.50)
		qs_btn.tooltip_text = "Start at week 10 with gold, stocked inventory, and preset stats (debug only)"
		qs_btn.pressed.connect(_on_quick_start)
		left_vbox.add_child(qs_btn)

	# Push a footer chronicle line to the bottom of the panel.
	left_vbox.add_child(_make_spacer(0))
	var footer_spacer := Control.new()
	footer_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_vbox.add_child(footer_spacer)

	var footer_lbl := Label.new()
	footer_lbl.text = _flavour_footer()
	footer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	footer_lbl.add_theme_font_size_override("font_size", 12)
	footer_lbl.modulate = DIM_PARCHMENT
	left_vbox.add_child(footer_lbl)

	return left_panel


func _build_heraldic_frieze() -> Control:
	# A row of all four house crests. Pure decoration — anchors the houses
	# as canonical lore the moment the player loads the game.
	var frieze_row := HBoxContainer.new()
	frieze_row.alignment = BoxContainer.ALIGNMENT_CENTER
	frieze_row.add_theme_constant_override("separation", 14)
	for hid in HOUSE_FRIEZE_IDS:
		var crest := BannerIcon.new()
		crest.custom_minimum_size = Vector2(56, 72)
		crest.set_show_body(false)
		crest.set_house(hid)
		crest.modulate.a = 0.92
		frieze_row.add_child(crest)
	return frieze_row


func _build_title_block() -> Control:
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 2)

	# Overline — small caps tracked out, sits above the title.
	var overline := Label.new()
	overline.text = "K  N  I  G  H  T     M  A  N  A  G  E  R"
	overline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overline.add_theme_font_size_override("font_size", 13)
	overline.modulate = PARCHMENT
	vbox.add_child(overline)

	# Year — the dramatic centerpiece.
	var year := Label.new()
	year.text = "MDCXXVII"
	year.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	year.add_theme_font_size_override("font_size", 56)
	year.add_theme_color_override("font_color", GOLD)
	year.add_theme_color_override("font_outline_color", Color(0.12, 0.07, 0.02))
	year.add_theme_constant_override("outline_size", 5)
	vbox.add_child(year)

	# Subline — small Arabic year + tagline.
	var sub := Label.new()
	sub.text = "1627  ·  A roguelike of sworn service"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 13)
	sub.modulate = DIM_PARCHMENT
	vbox.add_child(sub)

	return vbox


func _make_ornament_divider() -> Control:
	# A single-line decorative divider. Three diamonds with thin rules either
	# side, all in muted parchment. Matches medieval chapter-break aesthetic
	# without needing an art asset.
	var lbl := Label.new()
	lbl.text = "─  ◆  ◆  ◆  ─"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = DIM_PARCHMENT
	return lbl


func _build_seed_row() -> Control:
	var seed_row := HBoxContainer.new()
	seed_row.alignment = BoxContainer.ALIGNMENT_CENTER
	seed_row.add_theme_constant_override("separation", 8)

	var seed_pfx := Label.new()
	seed_pfx.text = "Seed"
	seed_pfx.modulate = PARCHMENT
	seed_row.add_child(seed_pfx)

	_seed_edit = LineEdit.new()
	_seed_edit.custom_minimum_size = Vector2(180, 32)
	_seed_edit.placeholder_text = "(random)"
	_seed_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_seed_edit.max_length = 12
	_seed_edit.text_submitted.connect(_on_seed_submitted)
	seed_row.add_child(_seed_edit)

	var rand_btn := Button.new()
	rand_btn.text = "↻"
	rand_btn.custom_minimum_size = Vector2(40, 32)
	rand_btn.tooltip_text = "Roll a fresh random seed"
	rand_btn.pressed.connect(func(): _set_seed(randi()))
	seed_row.add_child(rand_btn)

	_set_seed(randi())
	return seed_row


# ─── RIGHT PANEL ───────────────────────────────────────────────────────────

func _build_right_panel() -> Control:
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var right_margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		right_margin.add_theme_constant_override("margin_" + side, 32)
	right_panel.add_child(right_margin)

	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 12)
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_margin.add_child(right_vbox)

	var hist_hdr := Label.new()
	hist_hdr.text = "Chronicle of Runs"
	hist_hdr.add_theme_font_size_override("font_size", 24)
	hist_hdr.add_theme_color_override("font_color", GOLD)
	right_vbox.add_child(hist_hdr)

	_totals_lbl = Label.new()
	_totals_lbl.add_theme_font_size_override("font_size", 13)
	_totals_lbl.modulate = PARCHMENT
	right_vbox.add_child(_totals_lbl)

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
	return right_panel


func _refresh_history() -> void:
	var history: Array[Dictionary] = SaveManager.run_history

	# Totals strip.
	if _totals_lbl != null:
		if history.is_empty():
			_totals_lbl.text = "No completed runs yet."
		else:
			var wins: int = 0
			var best_week: int = 0
			for entry in history:
				if str(entry.get("outcome", "")) == "won":
					wins += 1
				best_week = maxi(best_week, int(entry.get("weeks_survived", 0)))
			_totals_lbl.text = "%d runs  ·  %d won  ·  longest run: %d weeks" % [
				history.size(), wins, best_week,
			]

	if _history_rtl == null:
		return
	if history.is_empty():
		_history_rtl.parse_bbcode(
			"[color=#666666]No completed runs yet — get out there.[/color]"
		)
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

		var label: String
		var colour: String
		if outcome == "won":
			label = "Grand Tournament won"
			colour = "#FFD61A"
		else:
			label = "Homestead breached, week %d" % weeks
			colour = "#888888"

		var date_part: String = ""
		if date != "":
			date_part = "  [color=#666666]%s[/color]" % date

		lines.append(
			"[color=%s]Run %02d  ·  %s[/color]%s" % [colour, run_num, label, date_part]
		)

	_history_rtl.parse_bbcode("\n".join(lines))


# ─── helpers ──────────────────────────────────────────────────────────────

func _make_spacer(height: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, height)
	return s


func _flavour_footer() -> String:
	# Rotating flavour line at the bottom of the menu. Pure cosmetic.
	const LINES: Array[String] = [
		"The household waits.",
		"Steel before words.",
		"The chronicler keeps his pen sharp.",
		"By measure and by mind.",
		"First to the tide.",
		"Higher than the throne.",
		"The pennant has not yet been raised.",
	]
	return LINES[randi() % LINES.size()]


# ─── seed ──────────────────────────────────────────────────────────────────

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


# ─── button handlers ───────────────────────────────────────────────────────

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
