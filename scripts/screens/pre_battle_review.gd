extends Control

# Phase 5/6 Pre-Battle Review per GDD §5. Sits between Tick (already applied
# before this scene loads) and Resolution. Shows:
#   • A recap of what changed during Tick (training, Determination, returns).
#   • The post-Tick roster snapshot.
#   • A combat-setup pane that depends on the week's event:
#       – AWAY_BATTLE / HOME_BATTLE / Bandit Ambush → 4-slot formation editor.
#       – Champion's Duel → single champion + target stat picker.
#       – Tournament / Grand Tournament → up-to-4 participant picker.
#       – Bountiful Harvest / Merchant Caravan → just a note.
#
# The Tick has already mutated GameState (training applied, expeditions
# returned). This screen reads `GameState.last_tick_results` to show the recap.

@onready var header_lbl: Label = $Margin/VBox/Header
@onready var resources_lbl: Label = $Margin/VBox/Resources
@onready var tick_recap: VBoxContainer = $Margin/VBox/Scroll/Body/TickRecap
@onready var roster_list: VBoxContainer = $Margin/VBox/Scroll/Body/Roster
@onready var setup_header: Label = $Margin/VBox/Scroll/Body/SetupHeader
@onready var setup_pane: VBoxContainer = $Margin/VBox/Scroll/Body/Setup
@onready var status_lbl: Label = $Margin/VBox/Bottom/StatusLabel
@onready var confirm_btn: Button = $Margin/VBox/Bottom/ConfirmBtn
@onready var settings_btn: Button = $Margin/VBox/Bottom/SettingsBtn

const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")


func _ready() -> void:
	if not GameState.has_active_run():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return

	GameState.phase_machine.transition(PhaseMachine.Phase.PRE_BATTLE)
	_seed_formation_from_default()
	confirm_btn.pressed.connect(_on_confirm)
	settings_btn.pressed.connect(_on_settings)

	_refresh_header()
	_refresh_tick_recap()
	_refresh_roster()
	_refresh_setup()
	_refresh_confirm_button()


# Seed this week's formation from the Tactics tab default when the week's
# formation hasn't been touched yet (all slots -1). Invalid picks (units on
# expedition, units not in the combat-participant set) are pruned later
# by `_build_formation_editor`. Tournament / Duel weeks don't use formations.
func _seed_formation_from_default() -> void:
	if not GameState.current_event_uses_formation():
		return
	var all_empty: bool = true
	for slot_key in Combat.SLOTS:
		if int(GameState.formation.get(slot_key, -1)) >= 0:
			all_empty = false
			break
	if not all_empty:
		return

	var src: Dictionary
	if GameState.current_event == EventKind.AWAY_BATTLE:
		src = GameState.default_attack_formation
	else:
		src = GameState.default_defense_formation
	for slot_key in Combat.SLOTS:
		GameState.formation[slot_key] = int(src.get(slot_key, -1))


# ---------- header / resources ----------

func _refresh_header() -> void:
	var label: String = EventKind.label(GameState.current_event)
	if GameState.current_event == EventKind.BATTLE_EVENT and GameState.current_battle_event != "":
		label = "%s — %s" % [label, BattleEvent.label(GameState.current_battle_event)]
	header_lbl.text = "Pre-Battle Review — Year %d, Week %d (%d/48) · %s" % [
		GameState.current_year(),
		GameState.week,
		GameState.current_week_of_year(),
		label,
	]
	resources_lbl.text = "Stores — %s" % GameState.resources.describe()
	confirm_btn.text = "To Battle →" if _is_combat_week() else "Continue →"


# ---------- tick recap ----------

func _refresh_tick_recap() -> void:
	for child in tick_recap.get_children():
		child.queue_free()

	var t: Dictionary = GameState.last_tick_results
	if t.is_empty():
		_add_recap_line("(No Tick recorded.)", true)
		return

	# Training
	var training: Array = t.get("training", [])
	if training.is_empty():
		_add_recap_line("Training: nobody trained this week.", true)
	else:
		_add_recap_line("Training:", false)
		for entry in training:
			var u: Unit = GameState.find_unit(entry["unit_id"])
			var name: String = u.unit_name if u != null else "?"
			var stat: String = entry["stat"]
			if entry["applied"]:
				_add_recap_line(
					"  • %s trained %s: %d → %d" % [name, stat.capitalize(), entry["before"], entry["after"]],
					false,
				)
			else:
				_add_recap_line(
					"  • %s trained %s — blocked by cap (now %d)" % [name, stat.capitalize(), entry["after"]],
					true,
				)
			if entry.get("bonus_stat", "") != "":
				_add_recap_line(
					"      ↳ bonus +1 %s (Determination)" % String(entry["bonus_stat"]).capitalize(),
					false,
				)

	# Determination
	var det: Array = t.get("determination", [])
	if Determination.should_trigger(GameState.week):
		if det.is_empty():
			_add_recap_line("Determination: no one's grit paid off this week.", true)
		else:
			_add_recap_line("Determination rolls:", false)
			for entry in det:
				var u: Unit = entry["unit"]
				_add_recap_line(
					"  • %s gained +1 %s" % [u.unit_name, String(entry["stat"]).capitalize()],
					false,
				)

	# Expedition returns
	var returns: Array = t.get("expedition_returns", [])
	if not returns.is_empty():
		_add_recap_line("Expedition returns:", false)
		for r in returns:
			_add_recap_line("  • %s" % _describe_return(r), false)


func _describe_return(r: Dictionary) -> String:
	var bits: PackedStringArray = PackedStringArray()
	bits.append("%s at (%d,%d)" % [r["kind_label"], r["target_x"], r["target_y"]])
	if r["kind"] == Expedition.Kind.EXPLORE:
		var castle: Castle = r.get("revealed_castle")
		if castle != null:
			bits.append("revealed %s (Castle, diff %d)" % [r["revealed_terrain"], castle.difficulty])
		elif r["revealed_terrain"] != "":
			bits.append("revealed %s" % r["revealed_terrain"])
		else:
			bits.append("nothing new revealed")
	elif r["kind"] == Expedition.Kind.GATHER:
		if r["yield_amount"] > 0:
			bits.append("+%d %s" % [r["yield_amount"], r["yield_resource"]])
		else:
			bits.append("no yield (terrain not gatherable)")
	return " — ".join(bits)


func _add_recap_line(text: String, faded: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	if faded:
		lbl.modulate = Color(0.7, 0.7, 0.7)
	tick_recap.add_child(lbl)


# ---------- roster snapshot ----------

func _refresh_roster() -> void:
	for child in roster_list.get_children():
		child.queue_free()
	for u in GameState.roster:
		roster_list.add_child(UnitCard.build(u))


# ---------- setup pane (event-specific) ----------

func _refresh_setup() -> void:
	# Clear cached references — the children below get freed and we don't
	# want to read stale Labels in `_update_forecast`.
	_forecast_lbl = null
	_forecast_slots_lbl = null
	_forecast_participants = []
	for child in setup_pane.get_children():
		child.queue_free()

	match GameState.current_event:
		EventKind.AWAY_BATTLE:
			_build_formation_editor(GameState.combat_participants(), "Send your away party into battle.")
		EventKind.HOME_BATTLE:
			_build_formation_editor(GameState.combat_participants(), "All at-home units defend (Defend = full power, others = 75%).")
		EventKind.BATTLE_EVENT:
			match GameState.current_battle_event:
				"bandit_ambush":
					_build_formation_editor(GameState.combat_participants(), "Bandits at the gate — slot your defenders.")
				"champion_duel":
					_build_champion_picker()
				"bountiful_harvest":
					_build_simple_note("Bountiful Harvest — a small bundle will arrive automatically.")
				"merchant_caravan":
					_build_simple_note("Merchant Caravan — you'll pick a bundle on the Weekly Summary.")
				_:
					_build_simple_note("Battle Event with no setup.")
		EventKind.TOURNAMENT:
			_build_tournament_picker(false)
		EventKind.GRAND_TOURNAMENT:
			_build_tournament_picker(true)
		_:
			_build_simple_note("(No event resolved this week.)")


var _forecast_lbl: Label = null
var _forecast_slots_lbl: Label = null
var _forecast_participants: Array = []


# Drag-and-drop FormationEditor + live forecast. The editor mutates
# GameState.formation in place; on `formation_changed` we re-run the
# preview without rebuilding the editor (would lose visual state).
func _build_formation_editor(participants: Array, blurb: String) -> void:
	setup_header.text = "Formation Editor"
	if participants.is_empty():
		_build_simple_note("No participants available — this battle will auto-resolve.")
		return

	var intro := Label.new()
	intro.text = blurb
	intro.modulate = Color(0.78, 0.78, 0.78)
	setup_pane.add_child(intro)

	var editor := FormationEditor.new()
	setup_pane.add_child(editor)
	# Typed-array contract: FormationEditor expects Array[Unit].
	var typed_participants: Array[Unit] = []
	for u in participants:
		typed_participants.append(u)
	editor.setup(typed_participants, GameState.formation)
	editor.formation_changed.connect(_on_formation_changed)

	_forecast_participants = participants
	_forecast_lbl = Label.new()
	setup_pane.add_child(_forecast_lbl)
	_forecast_slots_lbl = Label.new()
	_forecast_slots_lbl.modulate = Color(0.7, 0.7, 0.7)
	setup_pane.add_child(_forecast_slots_lbl)
	_update_forecast()


func _on_formation_changed() -> void:
	_update_forecast()


func _update_forecast() -> void:
	if _forecast_lbl == null or _forecast_participants.is_empty():
		return
	var enemy: int = _forecast_enemy_power()
	var preview: Dictionary = Combat.resolve_formation(
		_forecast_participants, GameState.formation, enemy, _is_home_battle()
	)
	var verdict: String = "Win" if preview["won"] else "Loss"
	_forecast_lbl.text = "Forecast: %d vs %d enemy (after intim. %d) → %s" % [
		preview["player_total"],
		preview["enemy_power"],
		preview["enemy_after_intimidation"],
		verdict,
	]
	var assigned: int = 0
	for slot_key in Combat.SLOTS:
		if int(GameState.formation.get(slot_key, -1)) >= 0:
			assigned += 1
	_forecast_slots_lbl.text = "Slots filled: %d/4 — unslotted participants still fight, just without the +2 match bonus." % assigned


func _forecast_enemy_power() -> int:
	match GameState.current_event:
		EventKind.AWAY_BATTLE:
			if GameState.pending_away_mode == "assault" and GameState.pending_assault_castle != null:
				return GameState.pending_assault_castle.difficulty
			return Combat.enemy_power_pillage(GameState.week)
		EventKind.HOME_BATTLE:
			return Combat.enemy_power_home(GameState.week)
		EventKind.BATTLE_EVENT:
			if GameState.current_battle_event == "bandit_ambush":
				return Combat.enemy_power_bandit_ambush(GameState.week)
	return 0


func _is_home_battle() -> bool:
	if GameState.current_event == EventKind.HOME_BATTLE:
		return true
	return GameState.current_event == EventKind.BATTLE_EVENT and GameState.current_battle_event == "bandit_ambush"


# ---------- Champion's Duel ----------

func _build_champion_picker() -> void:
	setup_header.text = "Choose Your Champion"
	var intro := Label.new()
	intro.text = "A travelling champion has come to duel. Send one unit (Str + Bra + Sword vs %d)." % Combat.enemy_power_champion_duel(GameState.week)
	intro.modulate = Color(0.78, 0.78, 0.78)
	setup_pane.add_child(intro)

	var at_home: Array[Unit] = GameState.at_home_units()
	if at_home.is_empty():
		_build_simple_note("No units at home — duel will be forfeit.")
		return

	var champ_row := HBoxContainer.new()
	champ_row.add_theme_constant_override("separation", 8)
	var champ_label := Label.new()
	champ_label.text = "Champion:"
	champ_label.custom_minimum_size = Vector2(120, 0)
	champ_row.add_child(champ_label)
	var champ_picker := OptionButton.new()
	champ_picker.add_item("(none)")
	champ_picker.set_item_metadata(0, -1)
	for u in at_home:
		var power: int = u.stats.strength + u.stats.bravery + u.stats.swordsmanship
		champ_picker.add_item("%s — Str+Bra+Sword = %d" % [u.unit_name, power])
		champ_picker.set_item_metadata(champ_picker.item_count - 1, u.id)
	for i in range(champ_picker.item_count):
		if champ_picker.get_item_metadata(i) == GameState.champion_unit_id:
			champ_picker.select(i)
			break
	champ_picker.item_selected.connect(_on_champion_picked.bind(champ_picker))
	champ_row.add_child(champ_picker)
	setup_pane.add_child(champ_row)

	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 8)
	var stat_label := Label.new()
	stat_label.text = "Reward stat:"
	stat_label.custom_minimum_size = Vector2(120, 0)
	stat_row.add_child(stat_label)
	var stat_picker := OptionButton.new()
	stat_picker.add_item("(pick a stat)")
	stat_picker.set_item_metadata(0, "")
	for stat_key in Stats.STAT_KEYS:
		stat_picker.add_item(stat_key.capitalize())
		stat_picker.set_item_metadata(stat_picker.item_count - 1, stat_key)
	for i in range(stat_picker.item_count):
		if stat_picker.get_item_metadata(i) == GameState.champion_target_stat:
			stat_picker.select(i)
			break
	stat_picker.item_selected.connect(_on_champion_stat_picked.bind(stat_picker))
	stat_row.add_child(stat_picker)
	setup_pane.add_child(stat_row)


func _on_champion_picked(idx: int, picker: OptionButton) -> void:
	GameState.champion_unit_id = int(picker.get_item_metadata(idx))
	_refresh_confirm_button()


func _on_champion_stat_picked(idx: int, picker: OptionButton) -> void:
	GameState.champion_target_stat = picker.get_item_metadata(idx)
	_refresh_confirm_button()


# ---------- Tournament ----------

func _build_tournament_picker(is_grand: bool) -> void:
	setup_header.text = "Tournament Roster"
	var enemy: int = (
		Combat.enemy_power_grand_tournament(GameState.week)
		if is_grand else Combat.enemy_power_tournament(GameState.week)
	)
	var intro := Label.new()
	intro.text = "Send up to 4 units (no formation). Enemy power %d.%s" % [
		enemy,
		"\nGrand Tournament — winning this ends the run." if is_grand else "",
	]
	intro.modulate = Color(0.78, 0.78, 0.78)
	setup_pane.add_child(intro)

	var at_home: Array[Unit] = GameState.at_home_units()
	# Prune stale tournament_participants
	var pruned: Array[int] = []
	for uid in GameState.tournament_participants:
		var u: Unit = GameState.find_unit(uid)
		if u != null and u.is_at_home():
			pruned.append(uid)
	GameState.tournament_participants = pruned

	for u in at_home:
		var row := HBoxContainer.new()
		var chk := CheckBox.new()
		var power: int = Combat.TOURNAMENT_BASE_POWER + u.stats.strength + u.stats.technique + maxi(u.stats.swordsmanship, u.stats.archery)
		chk.text = "%s — power %d (Str %d, Tec %d, max(Sword,Arch) %d, Etq %d)" % [
			u.unit_name, power, u.stats.strength, u.stats.technique,
			maxi(u.stats.swordsmanship, u.stats.archery), u.stats.etiquette,
		]
		chk.button_pressed = GameState.tournament_participants.has(u.id)
		chk.toggled.connect(_on_tournament_toggled.bind(u.id))
		row.add_child(chk)
		setup_pane.add_child(row)

	var forecast := Label.new()
	var participants: Array[Unit] = []
	for uid in GameState.tournament_participants:
		var u: Unit = GameState.find_unit(uid)
		if u != null:
			participants.append(u)
	var preview: Dictionary = Combat.resolve_tournament(participants, enemy)
	forecast.text = "Forecast: %d vs %d enemy → %s" % [
		preview["player_total"], enemy,
		"Win" if preview["won"] else "Loss",
	]
	setup_pane.add_child(forecast)


func _on_tournament_toggled(pressed: bool, unit_id: int) -> void:
	if pressed:
		if not GameState.tournament_participants.has(unit_id):
			if GameState.tournament_participants.size() >= 4:
				status_lbl.text = "Tournament roster already at 4. Untick someone first."
				_refresh_setup()
				return
			GameState.tournament_participants.append(unit_id)
	else:
		GameState.tournament_participants.erase(unit_id)
	status_lbl.text = ""
	_refresh_setup()


# ---------- non-combat note ----------

func _build_simple_note(text: String) -> void:
	setup_header.text = "Combat Setup"
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = Color(0.78, 0.78, 0.78)
	setup_pane.add_child(lbl)


# ---------- confirm + route ----------

func _is_combat_week() -> bool:
	var ev: int = GameState.current_event
	if ev == EventKind.AWAY_BATTLE or ev == EventKind.HOME_BATTLE:
		return true
	if ev == EventKind.TOURNAMENT or ev == EventKind.GRAND_TOURNAMENT:
		return true
	if ev == EventKind.BATTLE_EVENT:
		return BattleEvent.is_combat(GameState.current_battle_event)
	return false


func _refresh_confirm_button() -> void:
	confirm_btn.disabled = false
	if GameState.current_event == EventKind.BATTLE_EVENT and GameState.current_battle_event == "champion_duel":
		# Require both a champion AND a target stat — otherwise the reward is forfeit.
		if GameState.champion_unit_id < 0 or GameState.champion_target_stat == "":
			confirm_btn.disabled = true


func _on_confirm() -> void:
	GameState.phase_machine.transition(PhaseMachine.Phase.RESOLUTION)
	Resolution.run(GameState)
	if _is_combat_week():
		get_tree().change_scene_to_file("res://scenes/screens/battle_log.tscn")
	else:
		get_tree().change_scene_to_file("res://scenes/screens/weekly_summary.tscn")


func _on_settings() -> void:
	SettingsPopup.show_for(self)
