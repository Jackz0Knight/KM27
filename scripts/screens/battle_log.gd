extends Control

# Phase 6 Battle Log — renders the breakdown from GameState.last_battle_result.
# Only reached for combat events: Away (Pillage/Assault), Home, Bandit Ambush,
# Champion's Duel, Tournament, Grand Tournament. Non-combat events (Harvest,
# Caravan) skip this screen and route straight to the Weekly Summary.

@onready var header_lbl: Label = $Margin/VBox/Header
@onready var verdict_lbl: Label = $Margin/VBox/Verdict
@onready var breakdown_list: VBoxContainer = $Margin/VBox/Scroll/Body/Breakdown
@onready var totals_list: VBoxContainer = $Margin/VBox/Scroll/Body/Totals
@onready var notes_list: VBoxContainer = $Margin/VBox/Scroll/Body/Notes
@onready var continue_btn: Button = $Margin/VBox/Bottom/ContinueBtn
@onready var settings_btn: Button = $Margin/VBox/Bottom/SettingsBtn

const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")


func _ready() -> void:
	if not GameState.has_active_run() or GameState.last_battle_result.is_empty():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return

	continue_btn.pressed.connect(_on_continue)
	settings_btn.pressed.connect(_on_settings)
	_render()


func _render() -> void:
	var r: Dictionary = GameState.last_battle_result
	var label: String = r["event_label"]
	if r["sub_event"] != "":
		label = "%s — %s" % [label, BattleEvent.label(r["sub_event"])]
	header_lbl.text = "Battle Log — Week %d · %s" % [GameState.week, label]

	var won: bool = r["won"]
	verdict_lbl.text = "Result: %s" % ("VICTORY" if won else "DEFEAT")
	verdict_lbl.modulate = Color(0.6, 0.95, 0.6) if won else Color(0.95, 0.5, 0.5)

	for c in breakdown_list.get_children():
		c.queue_free()
	for c in totals_list.get_children():
		c.queue_free()
	for c in notes_list.get_children():
		c.queue_free()

	# Per-unit breakdown — shape varies by event type.
	if r["sub_event"] == "champion_duel":
		_render_duel_breakdown(r)
	elif not r.get("tournament_per_unit", []).is_empty():
		_render_tournament_breakdown(r)
	elif not r.get("per_unit", []).is_empty():
		_render_formation_breakdown(r)
	else:
		var none := Label.new()
		none.text = "No participants — automatic forfeit."
		none.modulate = Color(0.7, 0.7, 0.7)
		breakdown_list.add_child(none)

	# Totals
	_add_total_line("Player total: %d" % r["player_total"])
	if r["intimidation_reduction"] > 0:
		_add_total_line("Intimidation reduced enemy by %d (raw %d → %d)" % [
			r["intimidation_reduction"], r["enemy_pre_intim"], r["enemy_total"],
		])
	_add_total_line("Enemy total: %d" % r["enemy_total"])
	_add_total_line("Margin: %+d" % (r["player_total"] - r["enemy_total"]))

	# Notes
	for note in r.get("notes", []):
		var lbl := Label.new()
		lbl.text = "• %s" % note
		lbl.modulate = Color(0.8, 0.8, 0.8)
		notes_list.add_child(lbl)


func _render_formation_breakdown(r: Dictionary) -> void:
	var header := _row(["Unit", "Slot", "Base+Str+Bra+Skill", "+Match", "+Lead", "Raw", "×Mult", "Total"], true)
	breakdown_list.add_child(header)
	for entry in r["per_unit"]:
		var u: Unit = GameState.find_unit(entry["unit_id"])
		var name: String = u.unit_name if u != null else "?"
		var slot_label: String = entry["slot"] if entry["slot"] != "" else "—"
		var skill_breakdown: String = "%d+%d+%d+%d" % [
			entry["base"], entry["str"], entry["bra"], entry["skill"],
		]
		var mult_str: String = ("×%.2f" % entry["mult"]) if entry["mult"] != 1.0 else "—"
		breakdown_list.add_child(_row([
			name,
			slot_label,
			skill_breakdown,
			"+%d" % entry["slot_bonus"],
			"+%d" % entry["leadership_buff"],
			"%d" % entry["raw"],
			mult_str,
			"%d" % entry["total"],
		], false))


func _render_tournament_breakdown(r: Dictionary) -> void:
	var header := _row(["Unit", "Base+Str+Tec+max(Sword,Arch)", "Total"], true)
	breakdown_list.add_child(header)
	for entry in r["tournament_per_unit"]:
		var u: Unit = GameState.find_unit(entry["unit_id"])
		var name: String = u.unit_name if u != null else "?"
		var build_str: String = "%d+%d+%d+%d" % [
			Combat.TOURNAMENT_BASE_POWER,
			entry["str"], entry["tec"], entry["skill"],
		]
		breakdown_list.add_child(_row([name, build_str, "%d" % entry["total"]], false))


func _render_duel_breakdown(r: Dictionary) -> void:
	var u: Unit = GameState.find_unit(r["duel_unit_id"])
	var name: String = u.unit_name if u != null else "?"
	var lbl := Label.new()
	lbl.text = "Champion: %s — Str+Bra+Sword = %d vs %d" % [
		name, r["duel_player_power"], r["duel_enemy_power"],
	]
	breakdown_list.add_child(lbl)
	if r["won"] and r["duel_stat"] != "":
		var reward_lbl := Label.new()
		if r["duel_stat_applied"]:
			reward_lbl.text = "Reward: +1 %s applied." % String(r["duel_stat"]).capitalize()
			reward_lbl.modulate = Color(0.6, 0.95, 0.6)
		else:
			reward_lbl.text = "Reward: %s capped — no growth." % String(r["duel_stat"]).capitalize()
			reward_lbl.modulate = Color(0.95, 0.85, 0.5)
		breakdown_list.add_child(reward_lbl)


func _add_total_line(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	totals_list.add_child(lbl)


func _row(cells: Array, header: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for i in range(cells.size()):
		var lbl := Label.new()
		lbl.text = str(cells[i])
		# First column is the unit name — give it more room so it doesn't wrap.
		lbl.custom_minimum_size = Vector2(160 if i == 0 else 90, 0)
		if header:
			lbl.modulate = Color(0.75, 0.85, 1.0)
			lbl.add_theme_font_size_override("font_size", 14)
		row.add_child(lbl)
	return row


func _on_continue() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/weekly_summary.tscn")


func _on_settings() -> void:
	SettingsPopup.show_for(self)
