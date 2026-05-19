extends Control

# Phase 6/7 Weekly Summary per GDD §5. Events reveal sequentially with
# short fade-in delays, grouped: Training → Expeditions → Battle → Resources → Gold.

@onready var header_lbl: Label = $Margin/VBox/Header
@onready var resources_lbl: RichTextLabel = $Margin/VBox/Resources
@onready var summary_body: VBoxContainer = $Margin/VBox/Scroll/Body
@onready var outcome_lbl: Label = $Margin/VBox/Scroll/Body/EventOutcome
@onready var rewards_list: VBoxContainer = $Margin/VBox/Scroll/Body/Rewards
@onready var caravan_pane: VBoxContainer = $Margin/VBox/Scroll/Body/CaravanPicker
@onready var deltas_list: VBoxContainer = $Margin/VBox/Scroll/Body/Deltas
@onready var returns_list: VBoxContainer = $Margin/VBox/Scroll/Body/Returns
@onready var streak_lbl: Label = $Margin/VBox/Scroll/Body/StreakLine
@onready var status_lbl: Label = $Margin/VBox/Bottom/StatusLabel
@onready var next_btn: Button = $Margin/VBox/Bottom/NextBtn
@onready var settings_btn: Button = $Margin/VBox/Bottom/SettingsBtn

const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")

# Sections that animate in one by one.
var _anim_sections: Array[Control] = []
var _anim_timer: float = 0.0
var _anim_idx: int = 0
var _anim_done: bool = false
const SECTION_DELAY: float = 0.4


func _ready() -> void:
	if not GameState.has_active_run():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return

	next_btn.pressed.connect(_on_next)
	settings_btn.pressed.connect(_on_settings)

	# Render content into the nodes first (hidden).
	_render_content()

	# Chronicle panel is the first child after render_content() inserts it.
	var chronicle_panel: Control = summary_body.get_child(0) if summary_body.get_child_count() > 0 else null

	# Collect the sections we'll animate in — Chronicle first, then ledger data.
	_anim_sections = []
	if chronicle_panel != null and chronicle_panel.name == "ChroniclePanel":
		_anim_sections.append(chronicle_panel)
	_anim_sections.append_array([
		outcome_lbl,
		rewards_list,
		deltas_list,
		returns_list,
		caravan_pane,
		streak_lbl,
	])

	# Hide all sections initially.
	for sec in _anim_sections:
		sec.modulate.a = 0.0

	# Disable Next until animation is done.
	next_btn.disabled = true
	_anim_timer = 0.3   # brief initial pause
	_anim_idx = 0
	_anim_done = false


func _process(delta: float) -> void:
	if _anim_done:
		return
	_anim_timer -= delta
	if _anim_timer > 0.0:
		return

	if _anim_idx < _anim_sections.size():
		var sec: Control = _anim_sections[_anim_idx]
		# Only animate sections that have content (skip invisible/empty ones).
		var tween: Tween = create_tween()
		tween.tween_property(sec, "modulate:a", 1.0, 0.25)
		_anim_idx += 1
		_anim_timer = SECTION_DELAY
	else:
		_anim_done = true
		set_process(false)
		# Re-enable Next now that everything is visible.
		_refresh_next_button(GameState.last_battle_result)
		resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory))


func _render_content() -> void:
	var r: Dictionary = GameState.last_battle_result
	var label: String = r.get("event_label", "—")
	if r.get("sub_event", "") != "":
		label = "%s — %s" % [label, BattleEvent.label(r["sub_event"])]
	header_lbl.text = "Weekly Summary — Week %d · %s" % [GameState.week, label]
	resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory))

	_render_chronicle()
	_render_outcome(r)
	_render_rewards(r)
	_render_caravan(r)
	_render_deltas()
	_render_returns()
	_render_streak(r)
	# Next button state set after animation.
	next_btn.text = "Please wait…"


func _render_chronicle() -> void:
	# Remove any previously-rendered chronicle panel (re-render safety).
	for c in summary_body.get_children():
		if c.name == "ChroniclePanel":
			c.queue_free()
			break

	var prose: String = Chronicle.generate_week_entry(GameState)

	var panel := PanelContainer.new()
	panel.name = "ChroniclePanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Chronicle"
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(0.72, 0.62, 0.38)
	vbox.add_child(title)

	var prose_lbl := Label.new()
	prose_lbl.text = prose
	prose_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	prose_lbl.modulate = Color(0.86, 0.80, 0.65)
	prose_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(prose_lbl)

	summary_body.add_child(panel)
	summary_body.move_child(panel, 0)


func _render(r: Dictionary = GameState.last_battle_result) -> void:
	_render_content()
	_refresh_next_button(r)
	resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory))


func _render_outcome(r: Dictionary) -> void:
	if r.is_empty():
		outcome_lbl.text = "Nothing happened this week."
		outcome_lbl.modulate = Color(0.78, 0.78, 0.78, 0.0)
		return

	if r.get("is_game_over", false):
		outcome_lbl.text = "✗ Homestead breached — your run ends."
		outcome_lbl.modulate = Color(0.95, 0.5, 0.5, 0.0)
		return

	if r.get("is_run_win", false):
		outcome_lbl.text = "★ Grand Tournament won — the realm is yours!"
		outcome_lbl.modulate = Color(1.0, 0.85, 0.4, 0.0)
		return

	if not r.get("fought", false):
		outcome_lbl.text = "%s — no battle this week." % EventKind.label(r["event_kind"])
		outcome_lbl.modulate = Color(0.78, 0.78, 0.78, 0.0)
		return

	if r["won"]:
		outcome_lbl.text = "✓ Won %s — %d vs %d enemy." % [label_for(r), r["player_total"], r["enemy_total"]]
		outcome_lbl.modulate = Color(0.6, 0.95, 0.6, 0.0)
	else:
		outcome_lbl.text = "✗ Lost %s — %d vs %d enemy." % [label_for(r), r["player_total"], r["enemy_total"]]
		outcome_lbl.modulate = Color(0.95, 0.6, 0.6, 0.0)


func label_for(r: Dictionary) -> String:
	if r.get("sub_event", "") != "":
		return BattleEvent.label(r["sub_event"])
	return EventKind.label(r["event_kind"])


func _render_rewards(r: Dictionary) -> void:
	for c in rewards_list.get_children():
		c.queue_free()

	var reward: ResourceBundle = r.get("reward")
	if reward != null and not reward.is_empty():
		var lbl := Label.new()
		lbl.text = "+ %s" % reward.describe()
		lbl.modulate = Color(0.7, 0.95, 0.7)
		rewards_list.add_child(lbl)

	var tournament_gold: int = int(r.get("tournament_gold", 0))
	if tournament_gold > 0:
		var lbl := Label.new()
		lbl.text = "+ %d gold (tournament prize)" % tournament_gold
		lbl.modulate = Color(1.0, 0.85, 0.4)
		rewards_list.add_child(lbl)

	var castle: Castle = r.get("castle_taken")
	if castle != null:
		var lbl := Label.new()
		lbl.text = "Castle (%d,%d) seized — removed from the world." % [castle.x, castle.y]
		lbl.modulate = Color(0.85, 0.85, 0.6)
		rewards_list.add_child(lbl)

	if r.get("sub_event", "") == "champion_duel" and r.get("won", false):
		var champ: Unit = GameState.find_unit(r["duel_unit_id"])
		var stat: String = r.get("duel_stat", "")
		var lbl := Label.new()
		if champ != null and stat != "" and r.get("duel_stat_applied", false):
			lbl.text = "+1 %s applied to %s." % [stat.capitalize(), champ.unit_name]
			lbl.modulate = Color(0.7, 0.95, 0.7)
		else:
			lbl.text = "Duel won but no stat growth (cap or no pick)."
			lbl.modulate = Color(0.85, 0.85, 0.6)
		rewards_list.add_child(lbl)

	# Injury report
	for inj in r.get("injuries", []):
		var u: Unit = GameState.find_unit(inj["unit_id"])
		var uname: String = u.unit_name if u != null else "?"
		var lbl := Label.new()
		lbl.text = "⚠ %s — injured %s (%dw recovery)" % [uname, inj["stat"].capitalize(), inj["weeks_remaining"]]
		lbl.modulate = Color(0.95, 0.55, 0.25)
		rewards_list.add_child(lbl)

	if rewards_list.get_child_count() == 0:
		var none := Label.new()
		none.text = "—"
		none.modulate = Color(0.6, 0.6, 0.6)
		rewards_list.add_child(none)


func _render_caravan(r: Dictionary) -> void:
	for c in caravan_pane.get_children():
		c.queue_free()
	caravan_pane.visible = false

	if r.get("sub_event", "") != "merchant_caravan":
		return
	caravan_pane.visible = true

	if GameState.merchant_pick >= 0:
		var taken: ResourceBundle = GameState.merchant_offers[GameState.merchant_pick]
		var taken_lbl := Label.new()
		taken_lbl.text = "Took: %s" % taken.describe()
		taken_lbl.modulate = Color(0.7, 0.95, 0.7)
		caravan_pane.add_child(taken_lbl)
		return

	var prompt := Label.new()
	prompt.text = "Merchant offers — pick one bundle:"
	caravan_pane.add_child(prompt)

	for i in range(GameState.merchant_offers.size()):
		var offer: ResourceBundle = GameState.merchant_offers[i]
		var btn := Button.new()
		btn.text = "Take: %s" % offer.describe()
		btn.pressed.connect(_on_caravan_pick.bind(i))
		caravan_pane.add_child(btn)


func _on_caravan_pick(idx: int) -> void:
	Crafting.accept_caravan_offer(GameState, idx)
	_render()


func _render_deltas() -> void:
	for c in deltas_list.get_children():
		c.queue_free()

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.parse_bbcode(_build_delta_bbcode())
	deltas_list.add_child(rtl)


func _build_delta_bbcode() -> String:
	var t: Dictionary = GameState.last_tick_results
	var lines: Array[String] = []
	const GREEN: String = "#50E050"
	const AMBER: String = "#D9B84C"
	const RED:   String = "#E05050"
	const CYAN:  String = "#55CCCC"
	const GREY:  String = "#888888"
	const DIV:   String = "[color=#555555]────────────────────────[/color]"

	# Training
	var training: Array = t.get("training", [])
	if not training.is_empty():
		lines.append("[color=%s]── TRAINING[/color]" % AMBER)
		for entry in training:
			var u: Unit = GameState.find_unit(entry["unit_id"])
			var uname: String = "%-14s" % (u.unit_name if u != null else "?")
			var stat_name: String = "%-14s" % String(entry["stat"]).capitalize()
			if entry["applied"]:
				lines.append("[color=%s]%s %s %d → %d  ▲[/color]" % [GREEN, uname, stat_name, entry["before"], entry["after"]])
			else:
				lines.append("[color=%s]%s %s %d    (capped)[/color]" % [GREY, uname, stat_name, entry["after"]])
			if entry.get("bonus_stat", "") != "":
				lines.append("[color=%s]      ↳ +1 %s bonus (Determination)  ▲[/color]" % [GREEN, String(entry["bonus_stat"]).capitalize()])
		lines.append(DIV)

	# Determination
	var det: Array = t.get("determination", [])
	if not det.is_empty():
		lines.append("[color=%s]── DETERMINATION[/color]" % AMBER)
		for entry in det:
			var u: Unit = entry["unit"]
			lines.append("[color=%s]%s  +1 %s  ▲[/color]" % [GREEN, u.unit_name, String(entry["stat"]).capitalize()])
		lines.append(DIV)

	# Expedition returns
	var returns: Array = t.get("expedition_returns", [])
	if not returns.is_empty():
		lines.append("[color=%s]── RESOURCES[/color]" % AMBER)
		for r in returns:
			if r["kind"] == Expedition.Kind.GATHER and r["yield_amount"] > 0:
				var entry: Dictionary = ResourceDB.RESOURCES.get(r["yield_resource"], {})
				var res_name: String = entry.get("name", r["yield_resource"])
				lines.append("[color=%s]%-16s +%d    (Expedition)[/color]" % [GREEN, res_name, r["yield_amount"]])
		lines.append(DIV)

	# Gold
	var gold_income: int = int(t.get("gold_income", 0))
	var gold_cost: int = int(t.get("gold_deducted", 0))
	var gold_net: int = gold_income - gold_cost
	var debt: bool = t.get("maintenance_debt", false)
	lines.append("[color=%s]── GOLD[/color]" % AMBER)
	if gold_income > 0:
		lines.append("[color=%s]%-16s +%d/wk  (Stipend & income)[/color]" % [GREEN, "Income:", gold_income])
	lines.append("[color=%s]%-16s −%d/wk  (%d units × 5)%s[/color]" % [
		RED, "Upkeep:", gold_cost, GameState.roster.size(), "  ⚠ DEBT" if debt else "",
	])
	var net_color: String = GREEN if gold_net >= 0 else RED
	lines.append("[color=%s]%-16s %s%d/wk[/color]" % [net_color, "Net:", "+" if gold_net >= 0 else "", gold_net])

	# Injury recoveries
	var recoveries: Array = t.get("injury_recoveries", [])
	if not recoveries.is_empty():
		lines.append(DIV)
		lines.append("[color=%s]── RECOVERIES[/color]" % AMBER)
		for entry in recoveries:
			var u: Unit = GameState.find_unit(entry["unit_id"])
			var uname: String = u.unit_name if u != null else "?"
			lines.append("[color=%s]%s  %s injury healed[/color]" % [CYAN, uname, entry["stat"].capitalize()])

	if lines.is_empty():
		return "[color=%s]—[/color]" % GREY

	return "\n".join(lines)


func _render_returns() -> void:
	for c in returns_list.get_children():
		c.queue_free()
	var t: Dictionary = GameState.last_tick_results
	var returns: Array = t.get("expedition_returns", [])
	if returns.is_empty():
		var none := Label.new()
		none.text = "—"
		none.modulate = Color(0.6, 0.6, 0.6)
		returns_list.add_child(none)
		return
	for r in returns:
		var bits: PackedStringArray = PackedStringArray()
		bits.append("%s at (%d,%d)" % [r["kind_label"], r["target_x"], r["target_y"]])
		if r["kind"] == Expedition.Kind.EXPLORE:
			var castle: Castle = r.get("revealed_castle")
			if castle != null:
				bits.append("revealed %s (Castle, diff %d)" % [r["revealed_terrain"], castle.difficulty])
			elif r["revealed_terrain"] != "":
				bits.append("revealed %s" % r["revealed_terrain"])
		elif r["kind"] == Expedition.Kind.GATHER and r["yield_amount"] > 0:
			var entry: Dictionary = ResourceDB.RESOURCES.get(r["yield_resource"], {})
			bits.append("+%d %s" % [r["yield_amount"], entry.get("name", r["yield_resource"])])
		var lbl := Label.new()
		lbl.text = "  • " + (" — ".join(bits))
		returns_list.add_child(lbl)


func _render_streak(r: Dictionary) -> void:
	if EventKind.is_tournament(r.get("event_kind", -1)):
		streak_lbl.text = "Tournament streak: %d" % GameState.tournament_streak
		streak_lbl.modulate = Color(1.0, 0.85, 0.4, 0.0) if GameState.tournament_streak > 0 else Color(0.85, 0.85, 0.85, 0.0)
	else:
		streak_lbl.text = ""
		streak_lbl.modulate.a = 0.0


# ---------- next button + routing ----------

func _refresh_next_button(r: Dictionary) -> void:
	if r.get("sub_event", "") == "merchant_caravan" and GameState.merchant_pick < 0:
		next_btn.disabled = true
		next_btn.text = "Pick a bundle first"
		return

	next_btn.disabled = false
	if r.get("is_game_over", false):
		next_btn.text = "View Game Over →"
	elif r.get("is_run_win", false):
		next_btn.text = "View Final Result →"
	else:
		next_btn.text = "Next Week →"


func _on_next() -> void:
	GameState.append_history_entry()

	var r: Dictionary = GameState.last_battle_result
	if r.get("is_game_over", false):
		_record_completed_run("lost")
		get_tree().change_scene_to_file("res://scenes/screens/game_over.tscn")
		return
	if r.get("is_run_win", false):
		_record_completed_run("won")
		get_tree().change_scene_to_file("res://scenes/screens/run_win.tscn")
		return

	GameState.wrap_week()
	GameState.phase_machine.transition(PhaseMachine.Phase.PLANNING)
	GameState.roll_current_event()
	get_tree().change_scene_to_file("res://scenes/screens/planning.tscn")


func _record_completed_run(outcome: String) -> void:
	var entry: Dictionary = {
		"run_number": SaveManager.run_history.size() + 1,
		"seed": 0,
		"weeks_survived": GameState.week,
		"outcome": outcome,
		"date": Time.get_date_string_from_system(),
		"tournament_streak": GameState.tournament_streak,
	}
	SaveManager.append_run_history(entry)
	SaveManager.delete_save()


func _on_settings() -> void:
	SettingsPopup.show_for(self)
