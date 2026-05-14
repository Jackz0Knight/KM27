extends Control

# Phase 6/7 Weekly Summary per GDD §5. Last screen before the next week
# begins. Renders:
#   • Event outcome (one-line verdict).
#   • Rewards landed in the stores this week.
#   • Merchant Caravan picker (when applicable; commits a bundle when picked).
#   • Stat changes (training + Determination + Duel reward).
#   • Expedition returns (from last_tick_results).
#   • Tournament streak update line.
# Routes:
#   • Home Battle loss → game_over.tscn
#   • Grand Tournament win → run_win.tscn
#   • Otherwise → planning.tscn (after wrap_week + roll).

@onready var header_lbl: Label = $Margin/VBox/Header
@onready var resources_lbl: Label = $Margin/VBox/Resources
@onready var outcome_lbl: Label = $Margin/VBox/Scroll/Body/EventOutcome
@onready var rewards_list: VBoxContainer = $Margin/VBox/Scroll/Body/Rewards
@onready var caravan_pane: VBoxContainer = $Margin/VBox/Scroll/Body/CaravanPicker
@onready var deltas_list: VBoxContainer = $Margin/VBox/Scroll/Body/Deltas
@onready var returns_list: VBoxContainer = $Margin/VBox/Scroll/Body/Returns
@onready var streak_lbl: Label = $Margin/VBox/Scroll/Body/StreakLine
@onready var status_lbl: Label = $Margin/VBox/Bottom/StatusLabel
@onready var next_btn: Button = $Margin/VBox/Bottom/NextBtn


func _ready() -> void:
	if not GameState.has_active_run():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return

	next_btn.pressed.connect(_on_next)
	_render()


func _render() -> void:
	var r: Dictionary = GameState.last_battle_result
	var label: String = r.get("event_label", "—")
	if r.get("sub_event", "") != "":
		label = "%s — %s" % [label, BattleEvent.label(r["sub_event"])]
	header_lbl.text = "Weekly Summary — Week %d · %s" % [GameState.week, label]
	resources_lbl.text = "Stores — %s" % GameState.resources.describe()

	_render_outcome(r)
	_render_rewards(r)
	_render_caravan(r)
	_render_deltas()
	_render_returns()
	_render_streak(r)
	_refresh_next_button(r)


func _render_outcome(r: Dictionary) -> void:
	if r.is_empty():
		outcome_lbl.text = "Nothing happened this week."
		outcome_lbl.modulate = Color(0.78, 0.78, 0.78)
		return

	if r.get("is_game_over", false):
		outcome_lbl.text = "✗ Homestead breached — your run ends."
		outcome_lbl.modulate = Color(0.95, 0.5, 0.5)
		return

	if r.get("is_run_win", false):
		outcome_lbl.text = "★ Grand Tournament won — the realm is yours!"
		outcome_lbl.modulate = Color(1.0, 0.85, 0.4)
		return

	if not r.get("fought", false):
		outcome_lbl.text = "%s — no battle this week." % EventKind.label(r["event_kind"])
		outcome_lbl.modulate = Color(0.78, 0.78, 0.78)
		return

	if r["won"]:
		outcome_lbl.text = "✓ Won %s — %d vs %d enemy." % [label_for(r), r["player_total"], r["enemy_total"]]
		outcome_lbl.modulate = Color(0.6, 0.95, 0.6)
	else:
		outcome_lbl.text = "✗ Lost %s — %d vs %d enemy." % [label_for(r), r["player_total"], r["enemy_total"]]
		outcome_lbl.modulate = Color(0.95, 0.6, 0.6)


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

	var castle: Castle = r.get("castle_taken")
	if castle != null:
		var lbl := Label.new()
		lbl.text = "Castle (%d,%d) seized — removed from the world." % [castle.x, castle.y]
		lbl.modulate = Color(0.85, 0.85, 0.6)
		rewards_list.add_child(lbl)

	# Duel reward already applied during Resolution; surface the stat change.
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
	GameState.merchant_pick = idx
	var offer: ResourceBundle = GameState.merchant_offers[idx]
	GameState.resources.add(offer)
	# Stamp the reward onto the result so the rewards pane reflects the pick.
	GameState.last_battle_result["reward"] = offer
	_render()


func _render_deltas() -> void:
	for c in deltas_list.get_children():
		c.queue_free()
	var any: bool = false

	var t: Dictionary = GameState.last_tick_results
	for entry in t.get("training", []):
		var u: Unit = GameState.find_unit(entry["unit_id"])
		var name: String = u.unit_name if u != null else "?"
		var lbl := Label.new()
		if entry["applied"]:
			lbl.text = "  • %s: %s %d → %d" % [
				name, String(entry["stat"]).capitalize(), entry["before"], entry["after"],
			]
			lbl.modulate = Color(0.7, 0.95, 0.7)
		else:
			lbl.text = "  • %s: %s capped (no growth)" % [name, String(entry["stat"]).capitalize()]
			lbl.modulate = Color(0.85, 0.85, 0.6)
		deltas_list.add_child(lbl)
		any = true
		if entry.get("bonus_stat", "") != "":
			var bonus_lbl := Label.new()
			bonus_lbl.text = "      ↳ +1 %s bonus (Determination)" % String(entry["bonus_stat"]).capitalize()
			bonus_lbl.modulate = Color(0.6, 0.85, 0.6)
			deltas_list.add_child(bonus_lbl)

	for entry in t.get("determination", []):
		var u: Unit = entry["unit"]
		var lbl := Label.new()
		lbl.text = "  • %s: +1 %s (Determination)" % [u.unit_name, String(entry["stat"]).capitalize()]
		lbl.modulate = Color(0.7, 0.95, 0.7)
		deltas_list.add_child(lbl)
		any = true

	if not any:
		var none := Label.new()
		none.text = "—"
		none.modulate = Color(0.6, 0.6, 0.6)
		deltas_list.add_child(none)


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
			bits.append("+%d %s" % [r["yield_amount"], r["yield_resource"]])
		var lbl := Label.new()
		lbl.text = "  • " + (" — ".join(bits))
		returns_list.add_child(lbl)


func _render_streak(r: Dictionary) -> void:
	if EventKind.is_tournament(r.get("event_kind", -1)):
		streak_lbl.text = "Tournament streak: %d" % GameState.tournament_streak
		streak_lbl.modulate = Color(1.0, 0.85, 0.4) if GameState.tournament_streak > 0 else Color(0.85, 0.85, 0.85)
	else:
		streak_lbl.text = ""


# ---------- next button + routing ----------

func _refresh_next_button(r: Dictionary) -> void:
	# Caravan choice is required before Next Week becomes available.
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
	# Snapshot the resolved week into the history log BEFORE we clear buffers.
	GameState.append_history_entry()

	var r: Dictionary = GameState.last_battle_result
	if r.get("is_game_over", false):
		get_tree().change_scene_to_file("res://scenes/screens/game_over.tscn")
		return
	if r.get("is_run_win", false):
		get_tree().change_scene_to_file("res://scenes/screens/run_win.tscn")
		return

	# Normal week wrap: bump week, clear buffers, roll next event, back to Planning.
	GameState.wrap_week()
	GameState.phase_machine.transition(PhaseMachine.Phase.PLANNING)
	GameState.roll_current_event()
	get_tree().change_scene_to_file("res://scenes/screens/planning.tscn")
