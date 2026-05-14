extends Control

# Planning screen per GDD §5. Top-bar shell holds tabs + Advance Time + the
# Settings cog so navigation is consistent across every tab and the primary
# action sits in the same place. Below the bar, a TabContainer with hidden
# tabs hosts the four panes (Overview / Tactics / Town & Map / Calendar).
#
# Overview — roster at a glance. Names link to the Knight Overview screen.
# Tactics  — persistent Default Defense / Default Attack formations; Pre-Battle
#            Review seeds the week's formation from these.
# Town & Map — per-unit task picker, expedition launcher, away-week chooser,
#            pan/zoomable world map.
# Calendar — upcoming tournament + expedition return weeks, run history log.

const TAB_OVERVIEW: int = 0
const TAB_TACTICS: int = 1
const TAB_TOWNMAP: int = 2
const TAB_CALENDAR: int = 3
const TAB_NAMES: Array[String] = ["Overview", "Tactics", "Town & Map", "Calendar"]

const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")

@onready var tabs: TabBar = $Margin/VBox/TopBar/Tabs
@onready var advance_btn: Button = $Margin/VBox/TopBar/AdvanceBtn
@onready var settings_btn: Button = $Margin/VBox/TopBar/SettingsBtn
@onready var context_lbl: Label = $Margin/VBox/ContextLabel
@onready var resources_lbl: Label = $Margin/VBox/ResourcesLabel
@onready var intro_panel: PanelContainer = $Margin/VBox/IntroPanel
@onready var intro_dismiss_btn: Button = $Margin/VBox/IntroPanel/IntroMargin/IntroVBox/IntroDismiss
@onready var content: TabContainer = $Margin/VBox/Content
@onready var status_lbl: Label = $Margin/VBox/StatusLabel

# Overview tab.
@onready var roster_cards: VBoxContainer = $Margin/VBox/Content/Overview/RosterScroll/RosterCards

# Tactics tab.
@onready var tactics_mode_tabs: TabBar = $Margin/VBox/Content/Tactics/ModeTabs
@onready var tactics_hint: Label = $Margin/VBox/Content/Tactics/TacticsHint
@onready var editor_pane: VBoxContainer = $Margin/VBox/Content/Tactics/EditorPane

const TACTICS_DEFENSE: int = 0
const TACTICS_ATTACK: int = 1
var _tactics_mode: int = TACTICS_DEFENSE

# Town & Map tab.
@onready var unit_list: VBoxContainer = $Margin/VBox/Content/TownMap/LeftPane/UnitScroll/UnitList
@onready var away_section: VBoxContainer = $Margin/VBox/Content/TownMap/LeftPane/AwaySection
@onready var map_viewport: Panel = $Margin/VBox/Content/TownMap/RightPane/MapViewport
@onready var map_canvas: Control = $Margin/VBox/Content/TownMap/RightPane/MapViewport/MapCanvas
@onready var selection_lbl: Label = $Margin/VBox/Content/TownMap/RightPane/SelectionInfo
@onready var explore_btn: Button = $Margin/VBox/Content/TownMap/RightPane/Actions/ExploreBtn
@onready var gather_btn: Button = $Margin/VBox/Content/TownMap/RightPane/Actions/GatherBtn
@onready var reset_map_btn: Button = $Margin/VBox/Content/TownMap/RightPane/Actions/ResetMapBtn
@onready var expedition_list: VBoxContainer = $Margin/VBox/Content/TownMap/RightPane/ExpeditionList

# Calendar tab.
@onready var upcoming_list: VBoxContainer = $Margin/VBox/Content/Calendar/UpcomingList
@onready var history_list: VBoxContainer = $Margin/VBox/Content/Calendar/HistoryScroll/HistoryList

var _map_panzoom: Node = null   # MapPanZoom instance
var _selected: Vector2i = Vector2i(-1, -1)

# Pending plan, committed when Advance Time is pressed.
var _pending_tasks: Dictionary = {}
var _expedition_party: Array[int] = []


func _ready() -> void:
	if not GameState.has_active_run():
		print("[Planning] No active run — bouncing to Title.")
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return

	if GameState.current_event < 0:
		GameState.roll_current_event()

	_build_tabs()
	_build_map_panzoom()

	advance_btn.pressed.connect(_on_advance)
	settings_btn.pressed.connect(_on_settings)
	explore_btn.pressed.connect(_on_explore)
	gather_btn.pressed.connect(_on_gather)
	reset_map_btn.pressed.connect(_on_reset_map)
	intro_dismiss_btn.pressed.connect(_on_dismiss_intro)

	_default_pending_tasks()
	_show_intro_if_first_week()
	_refresh_all()


func _build_tabs() -> void:
	for name in TAB_NAMES:
		tabs.add_tab(name)
	tabs.current_tab = TAB_TOWNMAP
	content.current_tab = TAB_TOWNMAP
	tabs.tab_changed.connect(_on_tab_changed)

	# Tactics sub-tabs (Defense / Attack). Only one FormationEditor is mounted
	# at a time so the screen stays compact.
	tactics_mode_tabs.add_tab("Defense")
	tactics_mode_tabs.add_tab("Attack")
	tactics_mode_tabs.current_tab = _tactics_mode
	tactics_mode_tabs.tab_changed.connect(_on_tactics_mode_changed)


func _build_map_panzoom() -> void:
	_map_panzoom = MapPanZoom.new()
	_map_panzoom.tile_clicked.connect(_on_tile_clicked)
	map_canvas.add_child(_map_panzoom)
	_map_panzoom.set_world(GameState.world)


func _on_tab_changed(idx: int) -> void:
	content.current_tab = idx
	if idx == TAB_TOWNMAP:
		# Recenter the map every time we re-enter the Town & Map tab.
		if _map_panzoom != null:
			_map_panzoom.center_on_town()


func _default_pending_tasks() -> void:
	for u in GameState.roster:
		if u.is_on_expedition():
			continue
		if not _pending_tasks.has(u.id):
			_pending_tasks[u.id] = Unit.TASK_DEFEND


func _show_intro_if_first_week() -> void:
	# Show the thematic intro only on the very first Planning render of a run.
	if GameState.week == 1 and not GameState.intro_shown_for_run:
		intro_panel.visible = true


func _on_dismiss_intro() -> void:
	intro_panel.visible = false
	GameState.intro_shown_for_run = true


func _refresh_all() -> void:
	_refresh_header()
	_refresh_overview_tab()
	_refresh_tactics_tab()
	_refresh_unit_list()
	_refresh_away_section()
	_refresh_map()
	_refresh_selection()
	_refresh_expeditions()
	_refresh_action_buttons()
	_refresh_calendar_tab()


func _refresh_header() -> void:
	var event_label: String = EventKind.label(GameState.current_event)
	if GameState.current_event == EventKind.BATTLE_EVENT and GameState.current_battle_event != "":
		event_label = "%s — %s" % [event_label, BattleEvent.label(GameState.current_battle_event)]
	context_lbl.text = "Year %d, Week %d (week %d / 48) — %s" % [
		GameState.current_year(),
		GameState.week,
		GameState.current_week_of_year(),
		event_label,
	]
	resources_lbl.text = "Stores — %s" % GameState.resources.describe()
	status_lbl.text = ""


# ---------- Overview tab ----------

func _refresh_overview_tab() -> void:
	for c in roster_cards.get_children():
		c.queue_free()
	for u in GameState.roster:
		var card: Control = UnitCard.build(
			u, Callable(), "", _open_knight_overview.bind(u.id)
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roster_cards.add_child(card)


func _open_knight_overview(unit_id: int) -> void:
	GameState.focused_unit_id = unit_id
	get_tree().change_scene_to_file("res://scenes/screens/knight_overview.tscn")


# ---------- Tactics tab ----------

func _on_tactics_mode_changed(idx: int) -> void:
	_tactics_mode = idx
	_refresh_tactics_tab()


# Mounts a single FormationEditor bound to whichever default Dict the
# Defense / Attack sub-tab is on. Pre-Battle Review seeds the week's
# formation from the relevant one at battle time.
func _refresh_tactics_tab() -> void:
	for c in editor_pane.get_children():
		c.queue_free()

	var dict: Dictionary
	var label: String
	if _tactics_mode == TACTICS_DEFENSE:
		dict = GameState.default_defense_formation
		label = "Defense"
	else:
		dict = GameState.default_attack_formation
		label = "Attack"
	tactics_hint.text = "Default %s formation. Pre-Battle Review applies this automatically; override there for one-off battles." % label

	var editor := FormationEditor.new()
	editor_pane.add_child(editor)
	editor.setup(GameState.roster, dict)


# ---------- Town & Map tab — assignments ----------

func _refresh_unit_list() -> void:
	for child in unit_list.get_children():
		child.queue_free()
	for u in GameState.roster:
		unit_list.add_child(_build_unit_row(u))


func _build_unit_row(u: Unit) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_bottom", 4)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)

	var name_btn := LinkButton.new()
	name_btn.text = "%s — %s" % [u.unit_name, u.class_label()]
	name_btn.pressed.connect(_open_knight_overview.bind(u.id))
	vbox.add_child(name_btn)

	if u.is_on_expedition():
		var locked_lbl := Label.new()
		var exp: Expedition = _find_expedition_for(u)
		locked_lbl.text = "On expedition #%d (%dw left)" % [
			u.expedition_id,
			exp.weeks_remaining if exp != null else -1,
		]
		locked_lbl.modulate = Color(0.7, 0.7, 0.7)
		vbox.add_child(locked_lbl)
		return panel

	var task_picker := OptionButton.new()
	task_picker.add_item("Defend")
	var train_start: int = task_picker.item_count
	for stat_key in Stats.STAT_KEYS:
		task_picker.add_item("Train %s (now %d)" % [stat_key.capitalize(), u.stats.get_value(stat_key)])

	var saved_task: String = _pending_tasks.get(u.id, Unit.TASK_DEFEND)
	if saved_task == Unit.TASK_DEFEND:
		task_picker.select(0)
	else:
		var stat_name: String = saved_task.substr(Unit.TASK_TRAIN_PREFIX.length())
		var idx: int = Stats.STAT_KEYS.find(stat_name)
		if idx >= 0:
			task_picker.select(train_start + idx)
	task_picker.item_selected.connect(_on_task_picked.bind(u.id, train_start))
	vbox.add_child(task_picker)

	var send_chk := CheckBox.new()
	send_chk.text = "Add to next expedition party"
	send_chk.button_pressed = _expedition_party.has(u.id)
	send_chk.toggled.connect(_on_party_toggled.bind(u.id))
	vbox.add_child(send_chk)

	if EventKind.is_tournament(GameState.current_event):
		var hint := Label.new()
		hint.text = "Tournament participants picked on Pre-Battle Review."
		hint.modulate = Color(0.65, 0.65, 0.65)
		vbox.add_child(hint)
	elif GameState.current_event == EventKind.AWAY_BATTLE:
		var away_chk := CheckBox.new()
		away_chk.text = "Send to Away Battle"
		away_chk.button_pressed = GameState.pending_away_party.has(u.id)
		away_chk.toggled.connect(_on_away_party_toggled.bind(u.id))
		vbox.add_child(away_chk)

	return panel


func _on_task_picked(option_idx: int, unit_id: int, train_start: int) -> void:
	if option_idx == 0:
		_pending_tasks[unit_id] = Unit.TASK_DEFEND
	else:
		var stat_idx: int = option_idx - train_start
		if stat_idx >= 0 and stat_idx < Stats.STAT_KEYS.size():
			_pending_tasks[unit_id] = Unit.TASK_TRAIN_PREFIX + Stats.STAT_KEYS[stat_idx]


func _on_party_toggled(pressed: bool, unit_id: int) -> void:
	if pressed:
		if not _expedition_party.has(unit_id):
			_expedition_party.append(unit_id)
	else:
		_expedition_party.erase(unit_id)
	_refresh_action_buttons()


func _on_away_party_toggled(pressed: bool, unit_id: int) -> void:
	if pressed:
		if not GameState.pending_away_party.has(unit_id):
			GameState.pending_away_party.append(unit_id)
	else:
		GameState.pending_away_party.erase(unit_id)
	_refresh_away_section()


# ---------- Town & Map tab — away-week options ----------

func _refresh_away_section() -> void:
	for child in away_section.get_children():
		child.queue_free()

	if GameState.current_event != EventKind.AWAY_BATTLE:
		away_section.visible = false
		return
	away_section.visible = true

	var header := Label.new()
	header.text = "Away Battle this week"
	header.add_theme_font_size_override("font_size", 18)
	away_section.add_child(header)

	var party_size: int = GameState.pending_away_party.size()
	var party_lbl := Label.new()
	party_lbl.text = "Party: %d unit(s) (tick units in the list above)" % party_size
	party_lbl.modulate = Color(0.78, 0.78, 0.78)
	away_section.add_child(party_lbl)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	away_section.add_child(actions)

	var pillage_btn := Button.new()
	pillage_btn.text = "Pillage Camp"
	pillage_btn.disabled = party_size == 0
	pillage_btn.pressed.connect(_on_pick_pillage)
	if GameState.pending_away_mode == "pillage":
		pillage_btn.modulate = Color(0.7, 1.0, 0.7)
	actions.add_child(pillage_btn)

	var explored_castles: Array = _explored_castles()

	var assault_btn := Button.new()
	assault_btn.text = "Assault Castle"
	assault_btn.disabled = party_size == 0 or explored_castles.is_empty()
	assault_btn.pressed.connect(_on_pick_assault)
	if GameState.pending_away_mode == "assault":
		assault_btn.modulate = Color(0.7, 1.0, 0.7)
	actions.add_child(assault_btn)

	if GameState.pending_away_mode == "assault":
		var picker := OptionButton.new()
		picker.add_item("— pick a castle —")
		for castle in explored_castles:
			picker.add_item("(%d,%d) diff %d, reward %s" % [
				castle.x, castle.y, castle.difficulty, castle.reward.describe(),
			])
			picker.set_item_metadata(picker.item_count - 1, castle)
		var current_idx: int = 0
		for i in range(1, picker.item_count):
			if picker.get_item_metadata(i) == GameState.pending_assault_castle:
				current_idx = i
		picker.select(current_idx)
		picker.item_selected.connect(_on_assault_castle_picked.bind(picker))
		away_section.add_child(picker)


func _on_pick_pillage() -> void:
	GameState.pending_away_mode = "pillage"
	GameState.pending_assault_castle = null
	_refresh_away_section()


func _on_pick_assault() -> void:
	GameState.pending_away_mode = "assault"
	_refresh_away_section()


func _on_assault_castle_picked(idx: int, picker: OptionButton) -> void:
	if idx <= 0:
		GameState.pending_assault_castle = null
		return
	GameState.pending_assault_castle = picker.get_item_metadata(idx)


func _explored_castles() -> Array:
	var out: Array = []
	for c in GameState.world.castles:
		var tile: MapTile = GameState.world.get_tile(c.x, c.y)
		if tile != null and tile.knowledge == MapTile.Knowledge.EXPLORED:
			out.append(c)
	return out


# ---------- Town & Map tab — map + expedition launch ----------

func _refresh_map() -> void:
	if _map_panzoom != null:
		_map_panzoom.refresh(_selected)


func _on_reset_map() -> void:
	if _map_panzoom != null:
		_map_panzoom.center_on_town()


func _refresh_selection() -> void:
	if _selected.x < 0:
		selection_lbl.text = "Click a tile on the map to select it."
		return
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	var bits: PackedStringArray = PackedStringArray()
	bits.append("Tile (%d,%d):" % [tile.x, tile.y])
	if tile.knowledge == MapTile.Knowledge.EXPLORED:
		bits.append("Terrain: %s" % MapTile.Terrain.keys()[tile.terrain])
		var res: String = tile.gather_resource()
		bits.append("Yield: %s" % (res if res != "" else "—"))
		if tile.castle != null:
			bits.append("Castle: difficulty %d, reward %s" % [
				tile.castle.difficulty, tile.castle.reward.describe(),
			])
	else:
		bits.append("Knowledge: Unknown — Explore to reveal")
	if tile.active_expedition != null:
		bits.append("Active: %s" % tile.active_expedition.describe())
	selection_lbl.text = " · ".join(bits)


func _on_tile_clicked(x: int, y: int) -> void:
	_selected = Vector2i(x, y)
	_refresh_map()
	_refresh_selection()
	_refresh_action_buttons()


func _refresh_action_buttons() -> void:
	explore_btn.disabled = not _can_explore()
	gather_btn.disabled = not _can_gather()


func _can_explore() -> bool:
	if _selected.x < 0:
		return false
	if _expedition_party.is_empty():
		return false
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	if tile == null:
		return false
	if tile.active_expedition != null:
		return false
	return tile.knowledge == MapTile.Knowledge.UNKNOWN


func _can_gather() -> bool:
	if _selected.x < 0:
		return false
	if _expedition_party.is_empty():
		return false
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	if tile == null:
		return false
	if tile.active_expedition != null:
		return false
	if tile.knowledge != MapTile.Knowledge.EXPLORED:
		return false
	return tile.gather_resource() != ""


func _on_explore() -> void:
	if not _can_explore():
		return
	_launch(Expedition.Kind.EXPLORE)


func _on_gather() -> void:
	if not _can_gather():
		return
	_launch(Expedition.Kind.GATHER)


func _launch(kind: Expedition.Kind) -> void:
	var party: Array[int] = _expedition_party.duplicate()
	var exp: Expedition = GameState.launch_expedition(kind, _selected.x, _selected.y, party)
	status_lbl.text = "Launched: %s" % exp.describe()
	_expedition_party.clear()
	for uid in party:
		_pending_tasks.erase(uid)
		GameState.pending_away_party.erase(uid)
	_refresh_overview_tab()
	_refresh_tactics_tab()
	_refresh_unit_list()
	_refresh_away_section()
	_refresh_map()
	_refresh_selection()
	_refresh_expeditions()
	_refresh_action_buttons()
	_refresh_calendar_tab()


func _refresh_expeditions() -> void:
	for child in expedition_list.get_children():
		child.queue_free()
	if GameState.expeditions.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "No active expeditions."
		none_lbl.modulate = Color(0.7, 0.7, 0.7)
		expedition_list.add_child(none_lbl)
		return
	for exp in GameState.expeditions:
		var lbl := Label.new()
		lbl.text = "  • #%d %s" % [exp.id, exp.describe()]
		expedition_list.add_child(lbl)


func _find_expedition_for(unit: Unit) -> Expedition:
	for exp in GameState.expeditions:
		if exp.id == unit.expedition_id:
			return exp
	return null


# ---------- Calendar tab ----------

func _refresh_calendar_tab() -> void:
	for c in upcoming_list.get_children():
		c.queue_free()
	for c in history_list.get_children():
		c.queue_free()

	var next_t: int = _next_tournament_week()
	if next_t > 0:
		var weeks_away: int = next_t - GameState.week
		var label: String = "Tournament — Week %d (in %d week%s)" % [
			next_t, weeks_away, "s" if weeks_away != 1 else "",
		]
		if GameState.tournament_streak >= 2:
			label += " — will be Grand Tournament!"
		_add_upcoming_line(label, GameState.tournament_streak >= 2)

	if GameState.expeditions.is_empty():
		_add_upcoming_line("No active expeditions.", true)
	else:
		for exp in GameState.expeditions:
			var return_week: int = GameState.week + exp.weeks_remaining
			_add_upcoming_line("Expedition #%d (%s) returns Week %d (in %dw)" % [
				exp.id, exp.kind_label(), return_week, exp.weeks_remaining,
			], false)

	if GameState.run_history.is_empty():
		var none := Label.new()
		none.text = "No weeks recorded yet."
		none.modulate = Color(0.65, 0.65, 0.65)
		history_list.add_child(none)
		return

	var entries: Array = GameState.run_history.duplicate()
	entries.reverse()
	for entry in entries:
		var bits: PackedStringArray = PackedStringArray()
		bits.append("Y%d W%d (%d/48)" % [entry["year"], entry["week"], entry["week_of_year"]])
		bits.append(entry["event_label"])
		bits.append(entry["outcome"])
		if int(entry.get("player_total", 0)) > 0 or int(entry.get("enemy_total", 0)) > 0:
			bits.append("%d vs %d" % [entry["player_total"], entry["enemy_total"]])
		if entry.get("reward_str", "") != "":
			bits.append("+ %s" % entry["reward_str"])
		var lbl := Label.new()
		lbl.text = " · ".join(bits)
		history_list.add_child(lbl)


func _add_upcoming_line(text: String, faded: bool) -> void:
	var lbl := Label.new()
	lbl.text = "  • " + text
	if faded:
		lbl.modulate = Color(0.7, 0.7, 0.7)
	upcoming_list.add_child(lbl)


func _next_tournament_week() -> int:
	var n: int = GameState.week
	while n % Calendar.TOURNAMENT_INTERVAL != 0:
		n += 1
	return n


# ---------- advance time + settings ----------

func _on_advance() -> void:
	for u in GameState.roster:
		if u.is_on_expedition():
			continue
		if _pending_tasks.has(u.id):
			u.current_task = _pending_tasks[u.id]
		else:
			u.current_task = Unit.TASK_DEFEND

	GameState.phase_machine.transition(PhaseMachine.Phase.TICK)
	Tick.apply(GameState)
	get_tree().change_scene_to_file("res://scenes/screens/pre_battle_review.tscn")


func _on_settings() -> void:
	SettingsPopup.show_for(self)
