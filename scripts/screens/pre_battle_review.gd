extends Control

# Phase 5/6 Pre-Battle Review per GDD §5. Sits between Tick (already applied)
# and Resolution. Layout (top to bottom in scroll):
#   1. Battle Info — event label, enemy power, stakes, gold maintenance.
#   2. Combat Setup — formation editor / champion picker / tournament picker.
#   3. Tick Recap — training, Determination, expedition returns.
#   4. Roster — full post-Tick snapshot.

@onready var header_lbl: Label             = $Margin/VBox/Header
@onready var resources_lbl: RichTextLabel  = $Margin/VBox/Resources
@onready var battle_info: VBoxContainer    = $Margin/VBox/Scroll/Body/BattleInfo
@onready var tick_recap: VBoxContainer     = $Margin/VBox/Scroll/Body/TickRecap
@onready var roster_list: VBoxContainer    = $Margin/VBox/Scroll/Body/Roster
@onready var setup_header: Label           = $Margin/VBox/Scroll/Body/SetupHeader
@onready var setup_pane: VBoxContainer     = $Margin/VBox/Scroll/Body/Setup
@onready var status_lbl: Label             = $Margin/VBox/Bottom/StatusLabel
@onready var confirm_btn: Button           = $Margin/VBox/Bottom/ConfirmBtn
@onready var settings_btn: Button          = $Margin/VBox/Bottom/SettingsBtn

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
	_refresh_battle_info()
	_refresh_setup()
	_refresh_tick_recap()
	_refresh_roster()
	_refresh_confirm_button()
	ScreenFade.fade_in(self)


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
	var src: Dictionary = (
		GameState.default_attack_formation
		if GameState.current_event == EventKind.AWAY_BATTLE
		else GameState.default_defense_formation
	)
	for slot_key in Combat.SLOTS:
		GameState.formation[slot_key] = int(src.get(slot_key, -1))


# ---------- header / resources ----------

func _refresh_header() -> void:
	var label: String = EventKind.label(GameState.current_event)
	if GameState.current_event == EventKind.BATTLE_EVENT and GameState.current_battle_event != "":
		label = "%s — %s" % [label, BattleEvent.label(GameState.current_battle_event)]
	header_lbl.text = "Pre-Battle Review — Year %d, Week %d (%d/48) · %s" % [
		GameState.current_year(), GameState.week,
		GameState.current_week_of_year(), label,
	]
	resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory))
	confirm_btn.text = "To Battle →" if _is_combat_week() else "Continue →"


# ---------- battle info panel ----------

func _refresh_battle_info() -> void:
	for c in battle_info.get_children():
		c.queue_free()

	var ev: int = GameState.current_event
	var sub: String = GameState.current_battle_event

	var event_lbl := Label.new()
	var full_label: String = EventKind.label(ev)
	if ev == EventKind.BATTLE_EVENT and sub != "":
		full_label += " — " + BattleEvent.label(sub)
	event_lbl.text = full_label
	event_lbl.add_theme_font_size_override("font_size", 20)
	battle_info.add_child(event_lbl)

	var enemy: int = _battle_enemy_power()
	if enemy > 0:
		var enemy_lbl := Label.new()
		enemy_lbl.text = "Enemy strength: %d" % enemy
		enemy_lbl.modulate = Color(0.95, 0.55, 0.45)
		battle_info.add_child(enemy_lbl)

		var flavor: String = _enemy_flavor_text(ev, sub)
		if flavor != "":
			var flavor_lbl := Label.new()
			flavor_lbl.text = flavor
			flavor_lbl.modulate = Color(0.72, 0.68, 0.55)
			flavor_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			battle_info.add_child(flavor_lbl)

	var stakes_lbl := Label.new()
	stakes_lbl.text = _stakes_text(ev, sub)
	stakes_lbl.modulate = Color(0.82, 0.78, 0.58)
	stakes_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	battle_info.add_child(stakes_lbl)

	var cost: int = GameState.gold_maintenance_cost()
	var gold_lbl := Label.new()
	gold_lbl.text = "Maintenance: %d gold (have %d)" % [cost, GameState.gold]
	gold_lbl.modulate = (
		Color(1.0, 0.84, 0.1) if GameState.gold >= cost else Color(0.95, 0.38, 0.38)
	)
	battle_info.add_child(gold_lbl)


func _battle_enemy_power() -> int:
	match GameState.current_event:
		EventKind.AWAY_BATTLE:
			if GameState.pending_away_mode == "assault" and GameState.pending_assault_castle != null:
				return GameState.pending_assault_castle.difficulty
			return Combat.enemy_power_pillage(GameState.week)
		EventKind.HOME_BATTLE:
			return Combat.enemy_power_home(GameState.week)
		EventKind.BATTLE_EVENT:
			match GameState.current_battle_event:
				"bandit_ambush": return Combat.enemy_power_bandit_ambush(GameState.week)
				"champion_duel": return Combat.enemy_power_champion_duel(GameState.week)
		EventKind.TOURNAMENT:
			return Combat.enemy_power_tournament(GameState.week)
		EventKind.GRAND_TOURNAMENT:
			return Combat.enemy_power_grand_tournament(GameState.week)
	return 0


func _enemy_flavor_text(ev: int, sub: String) -> String:
	var week: int = GameState.week
	match ev:
		EventKind.HOME_BATTLE:
			if week <= 8:
				return "Opportunistic raiders from the borderlands — disorganised but hungry."
			elif week <= 20:
				return "A war band, emboldened. They have scouted your walls."
			else:
				return "A well-organised force. Someone has given them orders."
		EventKind.AWAY_BATTLE:
			if GameState.pending_away_mode == "assault":
				return "The castle garrison will not yield their post without argument."
			if week <= 8:
				return "A bandit camp — poorly armed, not poorly motivated."
			elif week <= 20:
				return "Goblin warriors dug in on broken ground."
			else:
				return "Orc veterans. They have held this field before."
		EventKind.BATTLE_EVENT:
			match sub:
				"bandit_ambush":
					if week <= 8:
						return "Goblins out of the eastern wood — fast and loud."
					elif week <= 16:
						return "A bandit crew, road-worn and desperate enough to try this."
					else:
						return "Orc skirmishers. They tested the outer wall first."
				"champion_duel":
					return "A travelling champion — reputation arrives before him, as always."
		EventKind.TOURNAMENT:
			if GameState.tournament_streak >= 2:
				return "The field is watching. Every house has a stake in the result."
			return "Rivals with months of preparation. The lists will tell."
		EventKind.GRAND_TOURNAMENT:
			return "Every knight in the realm has come to see this settled."
	return ""


func _stakes_text(ev: int, sub: String) -> String:
	match ev:
		EventKind.HOME_BATTLE:
			return "⚠ Defeat → Game Over. All at-home units defend (Defend = full power, others = 75%)."
		EventKind.AWAY_BATTLE:
			if GameState.pending_away_mode == "assault":
				return "Win → seize the castle and claim its reward. Loss → return empty-handed."
			return "Win → pillage reward. Loss → return empty-handed."
		EventKind.BATTLE_EVENT:
			match sub:
				"bandit_ambush": return "Win → loot reward. No game-over risk."
				"champion_duel": return "Win → +1 to chosen stat. Loss → no penalty."
				"bountiful_harvest": return "Free resource gift — no combat needed."
				"merchant_caravan": return "Pick one of three bundles on the Weekly Summary screen."
				"refugee_caravan": return "Roll: shelter (costs gold, may earn loyalty) or pass through (small kindness in cloth) or turned away (no effect)."
				"noble_petition": return "A courtesy visit. Often a small purse + etiquette nudge for the host; sometimes only the wine bill."
		EventKind.TOURNAMENT:
			var note: String = ""
			if GameState.tournament_streak >= 1:
				note = " Streak: %d." % GameState.tournament_streak
			if GameState.tournament_streak >= 2:
				note += " Win → GRAND TOURNAMENT next!"
			return "Win → resource reward + streak +1. Loss → streak resets." + note
		EventKind.GRAND_TOURNAMENT:
			return "★ Win → RUN COMPLETE — the realm is yours! Loss → streak resets, run continues."
	return ""


# ---------- tick recap ----------

func _refresh_tick_recap() -> void:
	for child in tick_recap.get_children():
		child.queue_free()

	var t: Dictionary = GameState.last_tick_results
	if t.is_empty():
		_add_recap_line("(No Tick recorded.)", true)
		return

	var training: Array = t.get("training", [])
	if training.is_empty():
		_add_recap_line("Training: nobody trained this week.", true)
	else:
		_add_recap_line("Training:", false)
		for entry in training:
			var u: Unit = GameState.find_unit(entry["unit_id"])
			var uname: String = u.unit_name if u != null else "?"
			var stat: String = entry["stat"]
			if entry["applied"]:
				_add_recap_line(
					"  • %s trained %s: %d → %d" % [uname, stat.capitalize(), entry["before"], entry["after"]],
					false,
				)
			else:
				_add_recap_line(
					"  • %s trained %s — blocked by cap (now %d)" % [uname, stat.capitalize(), entry["after"]],
					true,
				)
			if entry.get("bonus_stat", "") != "":
				_add_recap_line(
					"      ↳ bonus +1 %s (Determination)" % String(entry["bonus_stat"]).capitalize(),
					false,
				)

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

	var returns: Array = t.get("expedition_returns", [])
	if not returns.is_empty():
		_add_recap_line("Expedition returns:", false)
		for r in returns:
			_add_recap_line("  • %s" % _describe_return(r), false)

	var gold_cost: int = t.get("gold_deducted", 0)
	if gold_cost > 0:
		var debt: bool = t.get("maintenance_debt", false)
		if debt:
			_add_recap_line("Maintenance: %d gold due — insufficient funds." % gold_cost, true)
		else:
			_add_recap_line("Maintenance: %d gold deducted." % gold_cost, true)


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
			var entry: Dictionary = ResourceDB.RESOURCES.get(r["yield_resource"], {})
			var res_name: String = entry.get("name", r["yield_resource"])
			bits.append("+%d %s" % [r["yield_amount"], res_name])
		else:
			bits.append("no yield")
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
	_forecast_lbl = null
	_forecast_slots_lbl = null
	_forecast_bar = null
	_forecast_bar_style = null
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
				"refugee_caravan":
					_build_simple_note("Refugees at the Gate — the household's choice will play out automatically; outcome on the Weekly Summary.")
				"noble_petition":
					_build_simple_note("A Noble's Petition — courtesy visit. Outcome on the Weekly Summary.")
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
var _forecast_bar: ProgressBar = null
var _forecast_bar_style: StyleBoxFlat = null
var _forecast_participants: Array = []


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
	var typed_participants: Array[Unit] = []
	for u in participants:
		typed_participants.append(u)
	editor.setup(typed_participants, GameState.formation)
	editor.formation_changed.connect(_on_formation_changed)

	_forecast_participants = participants

	# Win-probability gauge — horizontal bar tinted by OutcomeBracket. Bar sits
	# above the text so the eye picks up the colour first; precise percentage
	# stays in the label underneath for players who want the number.
	_forecast_bar = ProgressBar.new()
	_forecast_bar.min_value = 0.0
	_forecast_bar.max_value = 100.0
	_forecast_bar.show_percentage = false
	_forecast_bar.custom_minimum_size = Vector2(0, 14)
	_forecast_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_forecast_bar_style = StyleBoxFlat.new()
	_forecast_bar_style.bg_color = OutcomeBracket.COLOR_GREEN
	_forecast_bar_style.corner_radius_top_left = 4
	_forecast_bar_style.corner_radius_top_right = 4
	_forecast_bar_style.corner_radius_bottom_left = 4
	_forecast_bar_style.corner_radius_bottom_right = 4
	_forecast_bar.add_theme_stylebox_override("fill", _forecast_bar_style)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.18, 0.14, 0.10, 1.0)
	bg_style.border_color = Color(0.42, 0.32, 0.16, 1.0)
	bg_style.border_width_left = 1
	bg_style.border_width_right = 1
	bg_style.border_width_top = 1
	bg_style.border_width_bottom = 1
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	_forecast_bar.add_theme_stylebox_override("background", bg_style)
	setup_pane.add_child(_forecast_bar)

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

	# Build player CombatUnits, applying home-battle 0.75× to non-Defend units.
	var is_home: bool = _is_home_battle()
	var player_cus: Array = []
	for u: Unit in _forecast_participants:
		var mult: float = 1.0
		if is_home and u.current_task != Unit.TASK_DEFEND:
			mult = 0.75
		player_cus.append(CombatUnit.new(u, "", "", mult))

	# Preview party uses midpoint averages — no RNG consumed, safe for live UI.
	var event_key: String = _forecast_event_key()
	var enemy_cus: Array = EnemyDB.preview_party(event_key, GameState.week)

	var analysis: Dictionary = CombatSim.analyze(player_cus, enemy_cus)
	var pct: int = roundi(analysis["win_probability"] * 100.0)
	var col: Color = analysis["color"]

	if _forecast_bar != null:
		# Tween the bar fill so the number doesn't snap on each slot tweak —
		# 0.18s is fast enough not to lag behind the player's eye but slow
		# enough to register as a deliberate update.
		var t: Tween = _forecast_bar.create_tween()
		t.tween_property(_forecast_bar, "value", float(pct), 0.18)
		if _forecast_bar_style != null:
			_forecast_bar_style.bg_color = col

	_forecast_lbl.text = "Forecast: %d%% chance  ·  Score %.1f vs %.1f enemy" % [
		pct, analysis["player_score"], analysis["enemy_score"],
	]
	_forecast_lbl.modulate = col
	_forecast_slots_lbl.text = "%s  ·  Slots: %d/4 filled" % [analysis["label"], _count_filled_slots()]
	_forecast_slots_lbl.modulate = col


func _forecast_event_key() -> String:
	match GameState.current_event:
		EventKind.HOME_BATTLE:   return "home_battle"
		EventKind.AWAY_BATTLE:   return "pillage"
		EventKind.TOURNAMENT:    return "tournament"
		EventKind.GRAND_TOURNAMENT: return "tournament"
	if GameState.current_battle_event == "bandit_ambush":
		return "bandit_ambush"
	return "pillage"


func _count_filled_slots() -> int:
	var count: int = 0
	for slot_key in Combat.SLOTS:
		if int(GameState.formation.get(slot_key, -1)) >= 0:
			count += 1
	return count


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
	var pruned: Array[int] = []
	for uid in GameState.tournament_participants:
		var u: Unit = GameState.find_unit(uid)
		if u != null and u.is_at_home():
			pruned.append(uid)
	GameState.tournament_participants = pruned

	for u in at_home:
		var row := HBoxContainer.new()
		var chk := CheckBox.new()
		var power: int = Combat.tournament_unit_power(u)
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
		preview["player_total"], enemy, "Win" if preview["won"] else "Loss",
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
		if GameState.champion_unit_id < 0 or GameState.champion_target_stat == "":
			confirm_btn.disabled = true


func _on_confirm() -> void:
	GameState.phase_machine.transition(PhaseMachine.Phase.RESOLUTION)
	Resolution.run(GameState)
	# Always route to the Weekly Summary now — the per-unit breakdown that
	# used to live on Battle Log is rendered there as an animated section.
	# The Battle Log scene is no longer reachable in the normal flow.
	get_tree().change_scene_to_file("res://scenes/screens/weekly_summary.tscn")


func _on_settings() -> void:
	SettingsPopup.show_for(self)


# Enter triggers the primary action (To Battle / Continue) so the player can
# burn through a string of non-combat weeks with the keyboard.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		if not confirm_btn.disabled:
			_on_confirm()
			accept_event()
