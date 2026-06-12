extends CanvasLayer

# F1 dev toolbar. Only visible in debug builds. Provides:
#   • Resources — add arbitrary quantities to inventory
#   • Gold — set gold directly
#   • Time — advance N weeks, or force-queue a specific event
#   • Units — edit individual unit stats live

const DEFAULT_SMOKE_SEED: int = 1627

var _panel: PanelContainer = null
var _visible: bool = false

# Unit attribute editor state
var _attr_unit_id: int = -1
var _attr_spinners: Dictionary = {}   # stat_key -> SpinBox


func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	layer = 128
	_build_panel()
	_panel.visible = false


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			_toggle()
			get_viewport().set_input_as_handled()


func _toggle() -> void:
	_visible = not _visible
	_panel.visible = _visible
	if _visible:
		_refresh_attr_editor()


func _build_panel() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(520, 560)
	_panel.position = Vector2(20, 20)
	add_child(_panel)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 560)
	_panel.add_child(scroll)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	scroll.add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	# Title bar
	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title_lbl := Label.new()
	title_lbl.text = "  Dev Toolbar  [F1 to close]"
	title_lbl.add_theme_font_size_override("font_size", 16)
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_lbl)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(_toggle)
	title_row.add_child(close_btn)

	root.add_child(HSeparator.new())

	# Resources section
	_add_section_header(root, "Resources")
	var res_hbox := HBoxContainer.new()
	res_hbox.add_theme_constant_override("separation", 6)
	root.add_child(res_hbox)

	var res_dropdown := OptionButton.new()
	res_dropdown.custom_minimum_size = Vector2(180, 0)
	for id in ResourceDB.RESOURCES:
		res_dropdown.add_item(ResourceDB.RESOURCES[id]["name"])
		res_dropdown.set_item_metadata(res_dropdown.item_count - 1, id)
	res_hbox.add_child(res_dropdown)

	var res_spin := SpinBox.new()
	res_spin.min_value = 1
	res_spin.max_value = 999
	res_spin.value = 10
	res_spin.custom_minimum_size = Vector2(90, 0)
	res_hbox.add_child(res_spin)

	var res_add_btn := Button.new()
	res_add_btn.text = "Add to Inventory"
	res_add_btn.pressed.connect(func():
		if not GameState.has_active_run():
			return
		var idx: int = res_dropdown.selected
		var rid: String = res_dropdown.get_item_metadata(idx)
		GameState.inventory[rid] = GameState.inventory.get(rid, 0) + int(res_spin.value)
	)
	res_hbox.add_child(res_add_btn)

	root.add_child(HSeparator.new())

	# Gold section
	_add_section_header(root, "Gold")
	var gold_hbox := HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 6)
	root.add_child(gold_hbox)

	var gold_input := LineEdit.new()
	gold_input.placeholder_text = "amount"
	gold_input.custom_minimum_size = Vector2(120, 0)
	gold_hbox.add_child(gold_input)

	var gold_btn := Button.new()
	gold_btn.text = "Set Gold"
	gold_btn.pressed.connect(func():
		if not GameState.has_active_run():
			return
		var raw: String = gold_input.text.strip_edges()
		if raw.is_valid_int():
			GameState.gold = int(raw)
	)
	gold_hbox.add_child(gold_btn)

	root.add_child(HSeparator.new())

	# Time section
	_add_section_header(root, "Time")
	var time_hbox := HBoxContainer.new()
	time_hbox.add_theme_constant_override("separation", 6)
	root.add_child(time_hbox)

	var week_lbl := Label.new()
	week_lbl.text = "Advance"
	time_hbox.add_child(week_lbl)

	var week_spin := SpinBox.new()
	week_spin.min_value = 1
	week_spin.max_value = 48
	week_spin.value = 1
	week_spin.custom_minimum_size = Vector2(80, 0)
	time_hbox.add_child(week_spin)

	var week_lbl2 := Label.new()
	week_lbl2.text = "weeks"
	time_hbox.add_child(week_lbl2)

	var advance_btn := Button.new()
	advance_btn.text = "Run Ticks"
	advance_btn.pressed.connect(func():
		if not GameState.has_active_run():
			return
		for _i in range(int(week_spin.value)):
			Tick.apply(GameState)
			GameState.wrap_week()
			GameState.roll_current_event()
	)
	time_hbox.add_child(advance_btn)

	# Force event dropdown
	var event_hbox := HBoxContainer.new()
	event_hbox.add_theme_constant_override("separation", 6)
	root.add_child(event_hbox)

	var ev_lbl := Label.new()
	ev_lbl.text = "Force event:"
	event_hbox.add_child(ev_lbl)

	var ev_dropdown := OptionButton.new()
	ev_dropdown.custom_minimum_size = Vector2(200, 0)
	ev_dropdown.add_item("Away Battle");       ev_dropdown.set_item_metadata(0, EventKind.AWAY_BATTLE)
	ev_dropdown.add_item("Home Battle");       ev_dropdown.set_item_metadata(1, EventKind.HOME_BATTLE)
	ev_dropdown.add_item("Battle Event");      ev_dropdown.set_item_metadata(2, EventKind.BATTLE_EVENT)
	ev_dropdown.add_item("Tournament");        ev_dropdown.set_item_metadata(3, EventKind.TOURNAMENT)
	ev_dropdown.add_item("Grand Tournament");  ev_dropdown.set_item_metadata(4, EventKind.GRAND_TOURNAMENT)
	event_hbox.add_child(ev_dropdown)

	var ev_btn := Button.new()
	ev_btn.text = "Queue"
	ev_btn.pressed.connect(func():
		if not GameState.has_active_run():
			return
		var idx2: int = ev_dropdown.selected
		GameState.current_event = int(ev_dropdown.get_item_metadata(idx2))
		GameState.current_battle_event = ""
	)
	event_hbox.add_child(ev_btn)

	root.add_child(HSeparator.new())

	# ── Items — spawn a weapon or armour straight into the stockpile.
	# Saves grinding a tournament when you just want to test equip / kit math.
	_add_section_header(root, "Items")
	var item_hbox := HBoxContainer.new()
	item_hbox.add_theme_constant_override("separation", 6)
	root.add_child(item_hbox)

	var item_dropdown := OptionButton.new()
	item_dropdown.custom_minimum_size = Vector2(260, 0)
	for wid in Weapon.CATALOGUE:
		item_dropdown.add_item("⚔ %s" % str(Weapon.CATALOGUE[wid].get("name", wid)))
		item_dropdown.set_item_metadata(item_dropdown.item_count - 1, {"slot": "weapon", "id": String(wid)})
	for aid in Armour.CATALOGUE:
		item_dropdown.add_item("🛡 %s" % str(Armour.CATALOGUE[aid].get("name", aid)))
		item_dropdown.set_item_metadata(item_dropdown.item_count - 1, {"slot": "armour", "id": String(aid)})
	item_hbox.add_child(item_dropdown)

	var item_add_btn := Button.new()
	item_add_btn.text = "Add to Stockpile"
	item_add_btn.pressed.connect(func() -> void:
		if not GameState.has_active_run():
			return
		var meta: Dictionary = item_dropdown.get_item_metadata(item_dropdown.selected)
		GameState.item_stockpile.append({"slot": str(meta["slot"]), "id": str(meta["id"])})
	)
	item_hbox.add_child(item_add_btn)

	root.add_child(HSeparator.new())

	# ── Jump to event — fast-forward weeks until a specific event lands.
	# Mirrors the existing "Run Ticks" loop but stops when the target hits.
	_add_section_header(root, "Jump to Event")
	var jump_hbox := HBoxContainer.new()
	jump_hbox.add_theme_constant_override("separation", 6)
	root.add_child(jump_hbox)

	var jump_t_btn := Button.new()
	jump_t_btn.text = "Next Tournament"
	jump_t_btn.pressed.connect(func() -> void:
		if not GameState.has_active_run():
			return
		var safety: int = 0
		while not Calendar.is_tournament_week(GameState.week) and safety < 60:
			Tick.apply(GameState)
			GameState.wrap_week()
			GameState.roll_current_event()
			safety += 1
	)
	jump_hbox.add_child(jump_t_btn)

	var jump_gt_btn := Button.new()
	jump_gt_btn.text = "Next Grand Tournament"
	jump_gt_btn.pressed.connect(func() -> void:
		if not GameState.has_active_run():
			return
		# GT fires on a tournament week when tournament_streak >= 2 (event_roller).
		# Force the streak then advance to the next tournament week.
		GameState.tournament_streak = maxi(GameState.tournament_streak, 2)
		var safety: int = 0
		while not Calendar.is_tournament_week(GameState.week) and safety < 60:
			Tick.apply(GameState)
			GameState.wrap_week()
			GameState.roll_current_event()
			safety += 1
	)
	jump_hbox.add_child(jump_gt_btn)

	root.add_child(HSeparator.new())

	# ── Reputation — slam the chip to a specific value to test band crossings.
	_add_section_header(root, "Reputation")
	var rep_hbox := HBoxContainer.new()
	rep_hbox.add_theme_constant_override("separation", 6)
	root.add_child(rep_hbox)

	var rep_spin := SpinBox.new()
	rep_spin.min_value = 0
	rep_spin.max_value = 100
	rep_spin.value = 0
	rep_spin.custom_minimum_size = Vector2(90, 0)
	rep_hbox.add_child(rep_spin)

	var rep_set_btn := Button.new()
	rep_set_btn.text = "Set Reputation"
	rep_set_btn.pressed.connect(func() -> void:
		if not GameState.has_active_run():
			return
		GameState.reputation = int(rep_spin.value)
	)
	rep_hbox.add_child(rep_set_btn)

	root.add_child(HSeparator.new())

	# Unit attribute editor
	_add_section_header(root, "Unit Attribute Editor")

	var unit_hbox := HBoxContainer.new()
	unit_hbox.add_theme_constant_override("separation", 6)
	root.add_child(unit_hbox)

	var unit_lbl := Label.new()
	unit_lbl.text = "Unit:"
	unit_hbox.add_child(unit_lbl)

	var unit_dropdown := OptionButton.new()
	unit_dropdown.custom_minimum_size = Vector2(200, 0)
	unit_dropdown.add_item("(select a unit)")
	unit_dropdown.set_item_metadata(0, -1)
	unit_dropdown.item_selected.connect(func(idx: int):
		_attr_unit_id = int(unit_dropdown.get_item_metadata(idx))
		_refresh_attr_editor()
	)
	unit_hbox.add_child(unit_dropdown)

	# Populate unit dropdown in _refresh_attr_editor
	var attr_grid := GridContainer.new()
	attr_grid.columns = 4
	attr_grid.name = "AttrGrid"
	attr_grid.add_theme_constant_override("h_separation", 8)
	attr_grid.add_theme_constant_override("v_separation", 4)
	root.add_child(attr_grid)

	var apply_btn := Button.new()
	apply_btn.text = "Apply Stat Changes"
	apply_btn.name = "AttrApply"
	apply_btn.pressed.connect(_apply_attr_changes)
	root.add_child(apply_btn)

	var heal_btn := Button.new()
	heal_btn.text = "Heal All Injuries"
	heal_btn.tooltip_text = "Clears every injury on every roster unit."
	heal_btn.pressed.connect(func():
		if not GameState.has_active_run():
			return
		var cleared: int = 0
		for u in GameState.roster:
			cleared += u.injuries.size()
			u.injuries.clear()
		print("[dev] healed %d injuries across the roster" % cleared)
	)
	root.add_child(heal_btn)

	root.add_child(HSeparator.new())

	# Smoke Harness — run the SmokeEngine auto-player from inside the game.
	# The live run (if any) is snapshotted via SaveManager and restored after
	# the battery, then the current scene reloads so it re-reads GameState.
	_add_section_header(root, "Smoke Harness")

	var smoke_hbox := HBoxContainer.new()
	smoke_hbox.add_theme_constant_override("separation", 6)
	root.add_child(smoke_hbox)

	var seeds_lbl := Label.new()
	seeds_lbl.text = "Seeds:"
	smoke_hbox.add_child(seeds_lbl)
	var seeds_spin := SpinBox.new()
	seeds_spin.min_value = 1
	seeds_spin.max_value = 50
	seeds_spin.value = 5
	seeds_spin.custom_minimum_size = Vector2(70, 0)
	smoke_hbox.add_child(seeds_spin)

	var weeks_lbl := Label.new()
	weeks_lbl.text = "Weeks:"
	smoke_hbox.add_child(weeks_lbl)
	var weeks_spin := SpinBox.new()
	weeks_spin.min_value = 1
	weeks_spin.max_value = 120
	weeks_spin.value = 30
	weeks_spin.custom_minimum_size = Vector2(70, 0)
	smoke_hbox.add_child(weeks_spin)

	var probe_check := CheckBox.new()
	probe_check.text = "Probe screens"
	probe_check.tooltip_text = "Also instantiate every real screen against the run — they flash over the game for a few frames each. Watch the console for SCRIPT ERROR lines."
	smoke_hbox.add_child(probe_check)

	var smoke_btn := Button.new()
	smoke_btn.text = "Run Smoke Battery"
	root.add_child(smoke_btn)

	var smoke_out := RichTextLabel.new()
	smoke_out.bbcode_enabled = false   # smoke lines start with "[smoke]" — keep literal
	smoke_out.fit_content = true
	smoke_out.scroll_following = true
	smoke_out.custom_minimum_size = Vector2(0, 150)
	smoke_out.add_theme_font_size_override("normal_font_size", 11)
	root.add_child(smoke_out)

	smoke_btn.pressed.connect(func():
		_run_smoke(int(seeds_spin.value), int(weeks_spin.value),
			probe_check.button_pressed, smoke_btn, smoke_out)
	)

	# Store refs for later refresh
	_panel.set_meta("unit_dropdown", unit_dropdown)
	_panel.set_meta("attr_grid", attr_grid)


# Run the smoke battery in-game. GameState is parked via SaveManager's
# in-memory snapshot and restored afterwards; the current scene is then
# reloaded so whatever screen is open re-reads the restored state in _ready.
# When run with no active run (e.g. from the title), the battery's leftover
# state is cleared instead so the title doesn't think a run exists.
func _run_smoke(seeds: int, weeks: int, probe: bool, btn: Button, out: RichTextLabel) -> void:
	btn.disabled = true
	btn.text = "Running…"
	out.text = ""
	out.self_modulate = Color.WHITE

	var snapshot: Dictionary = SaveManager.snapshot_state()
	var engine := SmokeEngine.new()
	add_child(engine)
	engine.progress.connect(func(line: String) -> void:
		out.add_text(line + "\n")
		print(line)   # mirror to console so SCRIPT ERROR context lines up
	)
	var report: Dictionary = await engine.run_battery(seeds, weeks, DEFAULT_SMOKE_SEED, probe)
	engine.queue_free()

	if snapshot.is_empty():
		# No run was active — wipe the battery's leftovers.
		GameState.world = null
		GameState.roster.clear()
		GameState.knight_candidates.clear()
		GameState.starting_squires.clear()
		GameState.week = 1
	else:
		SaveManager.restore_snapshot(snapshot)
		get_tree().reload_current_scene()

	out.self_modulate = Color(0.6, 0.95, 0.6) if bool(report["passed"]) else Color(0.95, 0.5, 0.4)
	btn.text = "Run Smoke Battery"
	btn.disabled = false


func _add_section_header(parent: Control, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.modulate = Color(0.85, 0.75, 0.45)
	parent.add_child(lbl)


func _refresh_attr_editor() -> void:
	if not _panel.has_meta("unit_dropdown"):
		return
	var unit_dropdown: OptionButton = _panel.get_meta("unit_dropdown")
	var attr_grid: GridContainer = _panel.get_meta("attr_grid")

	# Rebuild unit dropdown if run is active
	if GameState.has_active_run():
		unit_dropdown.clear()
		unit_dropdown.add_item("(select a unit)")
		unit_dropdown.set_item_metadata(0, -1)
		for u in GameState.roster:
			unit_dropdown.add_item("%s (%s)" % [u.unit_name, u.class_label()])
			unit_dropdown.set_item_metadata(unit_dropdown.item_count - 1, u.id)
			if u.id == _attr_unit_id:
				unit_dropdown.select(unit_dropdown.item_count - 1)

	# Clear and rebuild stat grid
	for c in attr_grid.get_children():
		c.queue_free()
	_attr_spinners.clear()

	if _attr_unit_id < 0 or not GameState.has_active_run():
		return
	var u: Unit = GameState.find_unit(_attr_unit_id)
	if u == null:
		return

	for stat_key in Stats.STAT_KEYS:
		var name_lbl := Label.new()
		name_lbl.text = stat_key.capitalize()
		attr_grid.add_child(name_lbl)

		var spin := SpinBox.new()
		spin.min_value = 0
		spin.max_value = Stats.STAT_CAP
		spin.value = u.stats.get_value(stat_key)
		spin.custom_minimum_size = Vector2(80, 0)
		attr_grid.add_child(spin)
		_attr_spinners[stat_key] = spin

		var pa_lbl := Label.new()
		pa_lbl.text = "PA: %d" % u.potential_ability
		pa_lbl.modulate = Color(0.6, 0.6, 0.6)
		attr_grid.add_child(pa_lbl)

		attr_grid.add_child(Control.new())   # spacer


func _apply_attr_changes() -> void:
	if _attr_unit_id < 0 or not GameState.has_active_run():
		return
	var u: Unit = GameState.find_unit(_attr_unit_id)
	if u == null:
		return
	for stat_key in _attr_spinners:
		var spin: SpinBox = _attr_spinners[stat_key]
		u.stats.set_value(stat_key, int(spin.value))
