extends Control

# Planning screen per GDD §5.
#
# Overview  — roster at a glance.
# Tactics   — situation report (this week + upcoming) + persistent formations.
# Map       — per-unit tasks, expedition launcher, away-week options, world map.
# Crafting  — manual recipe crafting; only gathered raw materials shown.
# Research  — stub pane for Phase 8+.
# Calendar  — toggle button in the top bar (not a main tab).

const TAB_OVERVIEW:      int = 0
const TAB_TACTICS:       int = 1
const TAB_MAP:           int = 2
const TAB_CRAFTING:      int = 3
const TAB_RESEARCH:      int = 4
const TAB_CALENDAR_IDX:  int = 5  # Content child index; driven by CalendarBtn
const TAB_NAMES: Array[String] = ["Overview", "Tactics", "Map", "Crafting", "Research"]

const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")

@onready var tabs: TabBar                 = $Margin/VBox/TopBar/Tabs
@onready var calendar_btn: Button         = $Margin/VBox/TopBar/CalendarBtn
@onready var advance_btn: Button          = $Margin/VBox/TopBar/AdvanceBtn
@onready var settings_btn: Button         = $Margin/VBox/TopBar/SettingsBtn
@onready var context_lbl: Label           = $Margin/VBox/ContextLabel
@onready var resources_lbl: RichTextLabel = $Margin/VBox/ResourcesLabel
@onready var intro_panel: PanelContainer  = $Margin/VBox/IntroPanel
@onready var intro_dismiss_btn: Button    = $Margin/VBox/IntroPanel/IntroMargin/IntroVBox/IntroDismiss
@onready var content: TabContainer        = $Margin/VBox/Content
@onready var status_lbl: Label            = $Margin/VBox/StatusLabel

# Overview tab.
@onready var roster_cards: VBoxContainer = $Margin/VBox/Content/Overview/RosterCards

# Tactics tab.
@onready var tactics_upcoming_list: VBoxContainer = $Margin/VBox/Content/Tactics/TacticsUpcoming/UpcomingList
@onready var tactics_mode_tabs: TabBar    = $Margin/VBox/Content/Tactics/ModeTabs
@onready var tactics_hint: Label          = $Margin/VBox/Content/Tactics/TacticsHint
@onready var editor_pane: VBoxContainer   = $Margin/VBox/Content/Tactics/EditorPane

const TACTICS_DEFENSE: int = 0
const TACTICS_ATTACK:  int = 1
var _tactics_mode: int = TACTICS_DEFENSE

# Map tab (scene node still named TownMap).
@onready var unit_list: VBoxContainer     = $Margin/VBox/Content/TownMap/LeftPane/UnitScroll/UnitList
@onready var away_section: VBoxContainer  = $Margin/VBox/Content/TownMap/LeftPane/AwaySection
@onready var map_viewport: Panel          = $Margin/VBox/Content/TownMap/RightPane/MapViewport
@onready var map_canvas: Control          = $Margin/VBox/Content/TownMap/RightPane/MapViewport/MapCanvas
@onready var selection_lbl: Label         = $Margin/VBox/Content/TownMap/RightPane/SelectionInfo
@onready var explore_btn: Button          = $Margin/VBox/Content/TownMap/RightPane/Actions/ExploreBtn
@onready var gather_btn: Button           = $Margin/VBox/Content/TownMap/RightPane/Actions/GatherBtn
@onready var reset_map_btn: Button        = $Margin/VBox/Content/TownMap/RightPane/Actions/ResetMapBtn
@onready var expedition_list: VBoxContainer = $Margin/VBox/Content/TownMap/RightPane/ExpeditionList

# Crafting tab.
@onready var crafting_vbox: VBoxContainer = $Margin/VBox/Content/Crafting/CraftingScroll/CraftingVBox

# Research tab.
@onready var research_body: VBoxContainer = $Margin/VBox/Content/Research/ResearchPanel/ResearchMargin/ResearchBody

# Calendar pane.
@onready var upcoming_list: VBoxContainer = $Margin/VBox/Content/Calendar/UpcomingList
@onready var history_list: VBoxContainer  = $Margin/VBox/Content/Calendar/HistoryScroll/HistoryList

# Info overlay popup.
@onready var info_overlay: PanelContainer   = $InfoOverlay
@onready var info_overlay_title: Label      = $InfoOverlay/OM/OV/TitleRow/OverlayTitle
@onready var info_overlay_close: Button     = $InfoOverlay/OM/OV/TitleRow/OverlayClose
@onready var info_overlay_body: VBoxContainer = $InfoOverlay/OM/OV/OverlayBody

var _map_panzoom: Node = null
var _selected: Vector2i = Vector2i(-1, -1)

var _pending_tasks: Dictionary = {}
var _expedition_party: Array[int] = []

var _calendar_active: bool = false
var _last_main_tab: int = TAB_MAP


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
	calendar_btn.pressed.connect(_on_calendar_btn)
	settings_btn.pressed.connect(_on_settings)
	explore_btn.pressed.connect(_on_explore)
	gather_btn.pressed.connect(_on_gather)
	reset_map_btn.pressed.connect(_on_reset_map)
	intro_dismiss_btn.pressed.connect(_on_dismiss_intro)
	info_overlay_close.pressed.connect(func(): info_overlay.visible = false)

	_default_pending_tasks()
	_show_intro_if_first_week()
	_refresh_all()


func _build_tabs() -> void:
	for tab_name in TAB_NAMES:
		tabs.add_tab(tab_name)
	tabs.current_tab = TAB_MAP
	content.current_tab = TAB_MAP
	tabs.tab_changed.connect(_on_tab_changed)

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
	_calendar_active = false
	_last_main_tab = idx
	calendar_btn.modulate = Color.WHITE
	content.current_tab = idx
	if idx == TAB_MAP and _map_panzoom != null:
		_map_panzoom.center_on_town()


func _on_calendar_btn() -> void:
	_calendar_active = not _calendar_active
	if _calendar_active:
		content.current_tab = TAB_CALENDAR_IDX
		calendar_btn.modulate = Color(0.7, 1.0, 0.7)
	else:
		content.current_tab = _last_main_tab
		calendar_btn.modulate = Color.WHITE


func _default_pending_tasks() -> void:
	for u in GameState.roster:
		if u.is_on_expedition():
			continue
		if not _pending_tasks.has(u.id):
			_pending_tasks[u.id] = Unit.TASK_DEFEND


func _show_intro_if_first_week() -> void:
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
	_refresh_crafting_tab()
	_refresh_research_tab()
	_refresh_calendar_tab()


# ---------- Header ----------

func _refresh_header() -> void:
	var event_label: String = EventKind.label(GameState.current_event)
	if GameState.current_event == EventKind.BATTLE_EVENT and GameState.current_battle_event != "":
		event_label = "%s — %s" % [event_label, BattleEvent.label(GameState.current_battle_event)]
	context_lbl.text = "Year %d, Week %d (week %d / 48) — %s" % [
		GameState.current_year(), GameState.week,
		GameState.current_week_of_year(), event_label,
	]
	status_lbl.text = ""
	resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory))


# ---------- Overview tab ----------

func _refresh_overview_tab() -> void:
	for c in roster_cards.get_children():
		c.queue_free()

	# Cashflow panel
	var cashflow_rtl := RichTextLabel.new()
	cashflow_rtl.bbcode_enabled = true
	cashflow_rtl.fit_content = true
	cashflow_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cashflow_rtl.parse_bbcode(_cashflow_bbcode())
	roster_cards.add_child(cashflow_rtl)

	var sep := HSeparator.new()
	roster_cards.add_child(sep)

	# 2×2 grid for the four roster cards — no scroll needed at 1080p.
	var card_grid := GridContainer.new()
	card_grid.columns = 2
	card_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_grid.add_theme_constant_override("h_separation", 16)
	card_grid.add_theme_constant_override("v_separation", 12)
	roster_cards.add_child(card_grid)

	for u in GameState.roster:
		var card: Control = UnitCard.build(
			u, Callable(), "", _open_knight_overview.bind(u.id)
		)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_grid.add_child(card)


func _cashflow_bbcode() -> String:
	var income: int = GameState.total_gold_income()
	var upkeep: int = GameState.gold_maintenance_cost()
	var net: int = income - upkeep
	var projected_4: int = GameState.gold + (net * 4)
	var net_color: String = "#50E050" if net >= 0 else "#E05050"
	var lines: Array[String] = []
	lines.append("[color=#FFD61A]Gold: %d[/color]" % GameState.gold)
	lines.append("[color=#888888]─────────────────[/color]")
	for src in GameState.gold_income_sources:
		var v: int = int(GameState.gold_income_sources[src])
		if v != 0:
			var label: String = src.replace("_", " ").capitalize()
			lines.append("[color=#50E050]Income:   +%d/wk  (%s)[/color]" % [v, label])
	lines.append("[color=#E05050]Upkeep:   −%d/wk  (%d units × 5)[/color]" % [upkeep, GameState.roster.size()])
	lines.append("[color=%s]Net:      %s%d/wk[/color]" % [net_color, "+" if net >= 0 else "", net])
	lines.append("[color=#888888]─────────────────[/color]")
	lines.append("[color=#BBBBBB]Projected (4 wks): %d[/color]" % projected_4)
	return "\n".join(lines)


func _open_knight_overview(unit_id: int) -> void:
	GameState.focused_unit_id = unit_id
	get_tree().change_scene_to_file("res://scenes/screens/knight_overview.tscn")


# ---------- Tactics tab ----------

func _on_tactics_mode_changed(idx: int) -> void:
	_tactics_mode = idx
	_refresh_tactics_tab()


func _refresh_tactics_tab() -> void:
	_refresh_tactics_upcoming()

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


func _refresh_tactics_upcoming() -> void:
	for c in tactics_upcoming_list.get_children():
		c.queue_free()

	# This week
	_add_tactics_line(
		"This week: %s" % _current_event_full_label(),
		Color(1.0, 0.88, 0.55),
	)
	_add_tactics_line(_formation_advice(), Color(0.82, 0.78, 0.58))

	# Next tournament
	var next_t: int = _next_tournament_week()
	var weeks_away: int = next_t - GameState.week
	var t_text: String = "Tournament in %d week%s (Week %d)" % [
		weeks_away, "s" if weeks_away != 1 else "", next_t,
	]
	if GameState.tournament_streak >= 2:
		t_text += " — ★ GRAND TOURNAMENT"
	elif GameState.tournament_streak >= 1:
		t_text += " — streak %d" % GameState.tournament_streak
	_add_tactics_line(t_text, Color(0.65, 0.88, 0.65))

	# Nearby expedition returns
	for exped in GameState.expeditions:
		if exped.weeks_remaining <= 3:
			_add_tactics_line(
				"Expedition #%d returns in %dw" % [exped.id, exped.weeks_remaining],
				Color(0.65, 0.75, 0.95),
			)


func _current_event_full_label() -> String:
	var label: String = EventKind.label(GameState.current_event)
	if GameState.current_event == EventKind.BATTLE_EVENT and GameState.current_battle_event != "":
		label += " — " + BattleEvent.label(GameState.current_battle_event)
	return label


func _formation_advice() -> String:
	match GameState.current_event:
		EventKind.HOME_BATTLE:
			return "→ Use Defense formation — defeat means Game Over"
		EventKind.AWAY_BATTLE:
			return "→ Use Attack formation for your away party"
		EventKind.BATTLE_EVENT:
			match GameState.current_battle_event:
				"bandit_ambush": return "→ Use Defense formation"
				"champion_duel": return "→ Pick your strongest Str+Bra+Sword unit as champion"
				"bountiful_harvest": return "→ No combat — harvest arrives automatically"
				"merchant_caravan": return "→ No combat — pick a bundle on the summary screen"
		EventKind.TOURNAMENT:
			return "→ Select up to 4 units on the Pre-Battle screen"
		EventKind.GRAND_TOURNAMENT:
			return "→ GRAND TOURNAMENT — win this to complete the run!"
	return "→ No specific preparation needed"


func _add_tactics_line(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	tactics_upcoming_list.add_child(lbl)


# ---------- Map tab — assignments ----------

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
	task_picker.tooltip_text = "Defend: full combat power at home. Train: +1 to the chosen stat next Tick."
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


# ---------- Map tab — away-week options ----------

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


# ---------- Map tab — map + expedition launch ----------

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
		if res != "":
			var entry: Dictionary = ResourceDB.RESOURCES.get(res, {})
			bits.append("Yield: %s" % entry.get("name", res))
		else:
			bits.append("Yield: —")
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
	if _selected.x < 0 or _expedition_party.is_empty():
		return false
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	if tile == null or tile.active_expedition != null:
		return false
	return tile.knowledge == MapTile.Knowledge.UNKNOWN


func _can_gather() -> bool:
	if _selected.x < 0 or _expedition_party.is_empty():
		return false
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	if tile == null or tile.active_expedition != null:
		return false
	if tile.knowledge != MapTile.Knowledge.EXPLORED:
		return false
	return tile.gather_resource() != ""


func _on_explore() -> void:
	if not _can_explore():
		return
	var party_names: String = ", ".join(_expedition_party.map(func(uid: int) -> String:
		var u := GameState.find_unit(uid)
		return u.unit_name if u != null else "?"
	))
	ConfirmDialogUtil.ask(
		self, "launch_expedition",
		"Launch Explore expedition to (%d,%d)?\nParty: %s" % [_selected.x, _selected.y, party_names],
		func(): _launch(Expedition.Kind.EXPLORE),
	)


func _on_gather() -> void:
	if not _can_gather():
		return
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	var res_key: String = tile.gather_resource() if tile != null else ""
	var res_name: String = ResourceDB.RESOURCES.get(res_key, {}).get("name", res_key)
	var party_names: String = ", ".join(_expedition_party.map(func(uid: int) -> String:
		var u := GameState.find_unit(uid)
		return u.unit_name if u != null else "?"
	))
	ConfirmDialogUtil.ask(
		self, "launch_expedition",
		"Launch Gather expedition for %s at (%d,%d)?\nParty: %s" % [res_name, _selected.x, _selected.y, party_names],
		func(): _launch(Expedition.Kind.GATHER),
	)


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
	for exped in GameState.expeditions:
		var container := VBoxContainer.new()
		container.add_theme_constant_override("separation", 2)
		expedition_list.add_child(container)

		var header_lbl := Label.new()
		header_lbl.text = "  • #%d %s" % [exped.id, exped.describe()]
		container.add_child(header_lbl)

		# Return week forecast
		var return_week: int = GameState.week + exped.weeks_remaining
		var ret_lbl := Label.new()
		ret_lbl.text = "      Returns: Week %d" % return_week
		ret_lbl.modulate = Color(0.65, 0.75, 0.95)
		container.add_child(ret_lbl)

		# Yield preview for GATHER expeditions
		if exped.kind == Expedition.Kind.GATHER:
			var tile: MapTile = GameState.world.get_tile(exped.target_x, exped.target_y)
			if tile != null:
				var res_key: String = tile.gather_resource()
				if res_key != "":
					var party_strength: int = 0
					for uid in exped.unit_ids:
						var u: Unit = GameState.find_unit(uid)
						if u != null:
							party_strength += u.stats.strength
					var est_amount: int = roundi(
						float(Expedition.GATHER_BASE_YIELD) * (1.0 + float(party_strength) / 30.0)
					)
					var entry: Dictionary = ResourceDB.RESOURCES.get(res_key, {})
					var res_name: String = entry.get("name", res_key)
					var yield_lbl := Label.new()
					yield_lbl.text = "      Est. yield: ~%d %s" % [est_amount, res_name]
					yield_lbl.modulate = Color(0.70, 0.88, 0.60)
					container.add_child(yield_lbl)


func _find_expedition_for(unit: Unit) -> Expedition:
	for exped in GameState.expeditions:
		if exped.id == unit.expedition_id:
			return exped
	return null


# ---------- Crafting tab ----------

func _refresh_crafting_tab() -> void:
	for c in crafting_vbox.get_children():
		c.queue_free()

	# Raw materials stockpile — only show resources the player has actually gathered.
	var raw_header := Label.new()
	raw_header.text = "Raw Materials"
	raw_header.add_theme_font_size_override("font_size", 16)
	crafting_vbox.add_child(raw_header)

	var gathered: Array[String] = []
	for id: String in ResourceDB.RESOURCES:
		var entry: Dictionary = ResourceDB.RESOURCES[id]
		if not entry.has("type") and GameState.inventory.get(id, 0) > 0:
			gathered.append(id)

	if gathered.is_empty():
		var hint := Label.new()
		hint.text = "None gathered yet — send expeditions to collect raw materials."
		hint.modulate = Color(0.5, 0.5, 0.5)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		crafting_vbox.add_child(hint)
	else:
		var raw_grid := GridContainer.new()
		raw_grid.columns = 4
		raw_grid.add_theme_constant_override("h_separation", 20)
		raw_grid.add_theme_constant_override("v_separation", 2)
		crafting_vbox.add_child(raw_grid)
		for id in gathered:
			var entry: Dictionary = ResourceDB.RESOURCES[id]
			var lbl := Label.new()
			lbl.text = "%s: %d" % [entry["name"], GameState.inventory.get(id, 0)]
			raw_grid.add_child(lbl)

	var sep := HSeparator.new()
	crafting_vbox.add_child(sep)

	# Recipes grouped by type.
	var type_labels: Dictionary = {
		ResourceDB.ResType.FABRIC: "Fabric",
		ResourceDB.ResType.TIMBER: "Timber",
		ResourceDB.ResType.METAL:  "Metal",
	}
	for res_type: int in [ResourceDB.ResType.FABRIC, ResourceDB.ResType.TIMBER, ResourceDB.ResType.METAL]:
		var type_hdr := Label.new()
		type_hdr.text = type_labels[res_type]
		type_hdr.add_theme_font_size_override("font_size", 16)
		crafting_vbox.add_child(type_hdr)

		var any_shown: bool = false
		for id: String in ResourceDB.RESOURCES:
			var entry: Dictionary = ResourceDB.RESOURCES[id]
			if not entry.has("type") or entry["type"] != res_type:
				continue
			if not ResourceDB.is_craftable(id, GameState.researched):
				# Hidden if: research locked AND no inputs AND never crafted
				if not _recipe_should_be_visible(id, entry):
					continue
			any_shown = true

			var is_craftable_now: bool = ResourceDB.is_craftable(id, GameState.researched)
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			if not is_craftable_now:
				row.modulate = Color(0.50, 0.50, 0.50)
			crafting_vbox.add_child(row)

			# Clickable tier-coloured name → info popup.
			var name_btn := LinkButton.new()
			name_btn.text = entry["name"]
			name_btn.add_theme_color_override(
				"font_color",
				ResourceDB.color_for_tier(entry["tier"]) if is_craftable_now else Color(0.45, 0.45, 0.45),
			)
			name_btn.custom_minimum_size = Vector2(140, 0)
			name_btn.pressed.connect(_show_resource_popup.bind(id))
			row.add_child(name_btn)

			# Research gate indicator
			if not is_craftable_now:
				var gate = entry.get("research", "")
				var gate_str: String = str(gate).replace("_", " ").capitalize() if gate != null else ""
				var gate_lbl := Label.new()
				gate_lbl.text = "🔒 Requires: %s" % gate_str
				gate_lbl.modulate = Color(0.65, 0.55, 0.35)
				gate_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(gate_lbl)
			else:
				# Recipe inputs with current stock.
				var recipe: Dictionary = entry["recipe"]
				var recipe_parts: PackedStringArray = PackedStringArray()
				for input_id: String in recipe:
					var input_entry: Dictionary = ResourceDB.RESOURCES.get(input_id, {})
					var input_name: String = input_entry.get("name", input_id)
					var have: int = GameState.inventory.get(input_id, 0)
					recipe_parts.append("%s ×%d (have %d)" % [input_name, recipe[input_id], have])
				var recipe_lbl := Label.new()
				recipe_lbl.text = " + ".join(recipe_parts)
				recipe_lbl.modulate = Color(0.72, 0.72, 0.72)
				recipe_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(recipe_lbl)

				var craft_btn := Button.new()
				craft_btn.text = "Craft"
				craft_btn.disabled = not ResourceDB.can_afford(id, GameState.inventory)
				craft_btn.pressed.connect(_on_craft.bind(id))
				row.add_child(craft_btn)

		if not any_shown:
			var none_lbl := Label.new()
			none_lbl.text = "  No recipes available."
			none_lbl.modulate = Color(0.45, 0.45, 0.45)
			crafting_vbox.add_child(none_lbl)


# Returns true if a recipe should be visible even when not yet craftable.
# Visible when: player has any ingredient OR has crafted this before.
func _recipe_should_be_visible(id: String, entry: Dictionary) -> bool:
	if GameState.crafted_ids.has(id):
		return true
	var recipe = entry.get("recipe")   # untyped — may be null for gather-only resources
	if recipe == null or not recipe is Dictionary:
		return false
	for input_id: String in recipe:
		if GameState.inventory.get(input_id, 0) > 0:
			return true
	return false


func _on_craft(resource_id: String) -> void:
	if not ResourceDB.can_afford(resource_id, GameState.inventory):
		return
	var entry: Dictionary = ResourceDB.RESOURCES.get(resource_id, {})
	if entry.is_empty():
		return

	# Check if this would consume the last of any material.
	var last_material_warning: bool = false
	for input_id: String in entry.get("recipe", {}):
		var have: int = GameState.inventory.get(input_id, 0)
		var need: int = int(entry["recipe"][input_id])
		if have - need <= 0:
			last_material_warning = true
			break

	if last_material_warning:
		ConfirmDialogUtil.ask(
			self, "craft_last_material",
			"Crafting %s will use your last supply of an ingredient.\nProceed?" % entry["name"],
			func(): _do_craft(resource_id),
		)
	else:
		_do_craft(resource_id)


func _do_craft(resource_id: String) -> void:
	var entry: Dictionary = ResourceDB.RESOURCES.get(resource_id, {})
	for input_id: String in entry["recipe"]:
		GameState.inventory[input_id] = GameState.inventory.get(input_id, 0) - entry["recipe"][input_id]
	GameState.inventory[resource_id] = GameState.inventory.get(resource_id, 0) + 1
	if not GameState.crafted_ids.has(resource_id):
		GameState.crafted_ids.append(resource_id)
	status_lbl.text = "Crafted: %s" % entry["name"]
	_refresh_crafting_tab()
	_refresh_header()


# ---------- Research tab ----------

func _refresh_research_tab() -> void:
	for c in research_body.get_children():
		c.queue_free()

	var intro := Label.new()
	intro.text = "Spend gold to unlock new crafting recipes. Researched projects persist for the run."
	intro.modulate = Color(0.72, 0.68, 0.55)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD
	research_body.add_child(intro)
	research_body.add_child(HSeparator.new())

	var any_project: bool = false
	for project_id: String in ResourceDB.RESEARCH_PROJECTS:
		any_project = true
		var proj: Dictionary = ResourceDB.RESEARCH_PROJECTS[project_id]
		var is_done: bool = GameState.researched.has(project_id)

		var entry_box := VBoxContainer.new()
		entry_box.add_theme_constant_override("separation", 4)
		if is_done:
			entry_box.modulate = Color(0.55, 0.55, 0.55)
		research_body.add_child(entry_box)

		var name_row := HBoxContainer.new()
		name_row.add_theme_constant_override("separation", 10)
		entry_box.add_child(name_row)

		var name_lbl := Label.new()
		name_lbl.text = proj["name"] + (" ✓" if is_done else "")
		name_lbl.add_theme_font_size_override("font_size", 15)
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_row.add_child(name_lbl)

		if not is_done:
			var btn := Button.new()
			btn.text = "Research (%d gold)" % proj["cost_gold"]
			btn.disabled = GameState.gold < proj["cost_gold"]
			btn.pressed.connect(_on_research.bind(project_id))
			name_row.add_child(btn)

		var desc_lbl := Label.new()
		desc_lbl.text = proj["description"]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_lbl.modulate = Color(0.75, 0.72, 0.60)
		entry_box.add_child(desc_lbl)

		var unlock_names: Array[String] = []
		for rid: String in proj["unlocks"]:
			var rentry: Dictionary = ResourceDB.RESOURCES.get(rid, {})
			unlock_names.append(rentry.get("name", rid))
		var unlocks_lbl := Label.new()
		unlocks_lbl.text = "Unlocks: %s" % ", ".join(unlock_names)
		unlocks_lbl.modulate = Color(0.65, 0.88, 0.65)
		entry_box.add_child(unlocks_lbl)

		research_body.add_child(HSeparator.new())

	if not any_project:
		var none_lbl := Label.new()
		none_lbl.text = "No research projects available."
		none_lbl.modulate = Color(0.5, 0.5, 0.5)
		research_body.add_child(none_lbl)


func _on_research(project_id: String) -> void:
	var proj: Dictionary = ResourceDB.RESEARCH_PROJECTS.get(project_id, {})
	if proj.is_empty() or GameState.researched.has(project_id):
		return
	var cost: int = proj["cost_gold"]
	if GameState.gold < cost:
		status_lbl.text = "Not enough gold for %s." % proj["name"]
		return
	ConfirmDialogUtil.ask(
		self, "research_" + project_id,
		"Research %s for %d gold?\n\n%s" % [proj["name"], cost, proj["description"]],
		func():
			GameState.gold -= cost
			GameState.researched.append(project_id)
			status_lbl.text = "Researched: %s" % proj["name"]
			_refresh_research_tab()
			_refresh_crafting_tab()
			_refresh_header()
	)


# ---------- Resource info popup ----------

func _show_resource_popup(resource_id: String) -> void:
	var entry: Dictionary = ResourceDB.RESOURCES.get(resource_id, {})
	if entry.is_empty():
		return

	for c in info_overlay_body.get_children():
		c.queue_free()

	# Title with tier colour if applicable.
	if entry.has("tier"):
		info_overlay_title.text = entry["name"]
		info_overlay_title.add_theme_color_override("font_color", ResourceDB.color_for_tier(entry["tier"]))
	else:
		info_overlay_title.text = entry["name"]
		info_overlay_title.remove_theme_color_override("font_color")

	# Type + tier.
	if entry.has("type"):
		var type_names: Dictionary = {
			ResourceDB.ResType.FABRIC: "Fabric",
			ResourceDB.ResType.TIMBER: "Timber",
			ResourceDB.ResType.METAL:  "Metal",
		}
		_add_popup_line("Type: %s  ·  Tier %d" % [type_names.get(entry["type"], "?"), entry["tier"]], false)
	else:
		_add_popup_line("Raw Material", false)

	# Stock.
	var amt: int = GameState.inventory.get(resource_id, 0)
	_add_popup_line("In stock: %d" % amt, amt == 0)

	# Recipe or gather source.
	if entry.get("recipe") != null:
		var recipe: Dictionary = entry["recipe"]
		var parts: Array[String] = []
		for input_id: String in recipe:
			var ie: Dictionary = ResourceDB.RESOURCES.get(input_id, {})
			parts.append("%s ×%d" % [ie.get("name", input_id), recipe[input_id]])
		_add_popup_line("Craft: %s" % "  +  ".join(parts), false)

	var src = entry.get("map_source")
	if src != null and src != "":
		var src_str: String = str(src).replace("_", " ").capitalize()
		_add_popup_line("Source: %s" % src_str, false)

	# Research gate.
	var gate = entry.get("research")
	if gate != null and gate != "":
		var unlocked: bool = GameState.researched.has(gate)
		var gate_str: String = gate.replace("_", " ").capitalize()
		_add_popup_line("Requires: %s %s" % [gate_str, "✓" if unlocked else "(locked)"], not unlocked)

	# Position near cursor, clamped to screen.
	var mpos: Vector2 = get_local_mouse_position()
	info_overlay.position = Vector2(
		clampf(mpos.x + 12, 0.0, size.x - 320.0),
		clampf(mpos.y + 12, 0.0, size.y - 160.0),
	)
	info_overlay.visible = true


func _add_popup_line(text: String, faded: bool) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if faded:
		lbl.modulate = Color(0.5, 0.5, 0.5)
	info_overlay_body.add_child(lbl)


# ---------- Calendar pane ----------

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
		for exped in GameState.expeditions:
			var return_week: int = GameState.week + exped.weeks_remaining
			_add_upcoming_line("Expedition #%d (%s) returns Week %d (in %dw)" % [
				exped.id, exped.kind_label(), return_week, exped.weeks_remaining,
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


# ---------- Advance time + settings ----------

func _on_advance() -> void:
	ConfirmDialogUtil.ask(
		self, "advance_time",
		"Advance to next week?\n\nWeek %d — %s" % [GameState.week, _current_event_full_label()],
		_do_advance,
	)


func _do_advance() -> void:
	for u in GameState.roster:
		if u.is_on_expedition():
			continue
		if _pending_tasks.has(u.id):
			u.current_task = _pending_tasks[u.id]
		else:
			u.current_task = Unit.TASK_DEFEND

	SaveManager.save_game()

	GameState.phase_machine.transition(PhaseMachine.Phase.TICK)
	Tick.apply(GameState)
	get_tree().change_scene_to_file("res://scenes/screens/pre_battle_review.tscn")


func _on_settings() -> void:
	SettingsPopup.show_for(self)
