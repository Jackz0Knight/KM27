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
@onready var tournament_chip: PanelContainer = $Margin/VBox/TopBar/TournamentChip
@onready var tournament_chip_lbl: Label   = $Margin/VBox/TopBar/TournamentChip/TournamentChipMargin/TournamentChipLabel
@onready var calendar_btn: Button         = $Margin/VBox/TopBar/CalendarBtn
@onready var advance_btn: Button          = $Margin/VBox/TopBar/AdvanceBtn
@onready var settings_btn: Button         = $Margin/VBox/TopBar/SettingsBtn
@onready var context_lbl: Label           = $Margin/VBox/ContextLabel
@onready var resources_lbl: RichTextLabel = $Margin/VBox/ResourcesLabel
@onready var intro_panel: PanelContainer  = $IntroPanel
@onready var intro_dismiss_btn: Button    = $IntroPanel/IntroCenter/IntroCard/IntroMargin/IntroVBox/IntroDismiss
@onready var content: TabContainer        = $Margin/VBox/Content
@onready var status_lbl: Label            = $Margin/VBox/StatusLabel

# Overview tab.
@onready var roster_cards: VBoxContainer = $Margin/VBox/Content/Overview/OverviewScroll/RosterCards
@onready var event_chip_lbl: Label = $Margin/VBox/Content/Overview/HeaderRow/EventChip/EventChipMargin/EventChipLabel

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

# Per-unit task assignments for the current week now live on GameState
# (`GameState.pending_tasks`) so they survive any scene change inside the
# week — opening Knight Overview and coming back used to wipe them because
# the local dict re-initialised on scene reload. Cleared by GameState's
# `_clear_week_buffers()` so each new week starts from a clean slate.
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
	advance_btn.tooltip_text = "Lock in this week's plans and resolve the Tick. (Enter)"
	ScreenFade.fade_in(self)


func _build_tabs() -> void:
	for tab_name in TAB_NAMES:
		tabs.add_tab(tab_name)
	tabs.current_tab = TAB_MAP
	content.current_tab = TAB_MAP
	# `tab_clicked` (not `tab_changed`) so re-clicking the already-selected tab
	# still routes through — that's what lets you leave the Calendar overlay,
	# which lives on content index 5 but isn't a real entry in this TabBar.
	tabs.tab_clicked.connect(_select_main_tab)

	tactics_mode_tabs.add_tab("Defense")
	tactics_mode_tabs.add_tab("Attack")
	tactics_mode_tabs.current_tab = _tactics_mode
	tactics_mode_tabs.tab_changed.connect(_on_tactics_mode_changed)


func _build_map_panzoom() -> void:
	_map_panzoom = MapPanZoom.new()
	_map_panzoom.tile_clicked.connect(_on_tile_clicked)
	map_canvas.add_child(_map_panzoom)
	_map_panzoom.set_world(GameState.world)


func _select_main_tab(idx: int) -> void:
	# Always clears the Calendar overlay and re-syncs the TabBar highlight, so
	# selecting a main tab works whether or not Calendar is currently showing
	# and even when the clicked tab was already the highlighted one.
	_calendar_active = false
	_last_main_tab = idx
	calendar_btn.modulate = Color.WHITE
	if tabs.current_tab != idx:
		tabs.current_tab = idx
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
		if not GameState.pending_tasks.has(u.id):
			GameState.pending_tasks[u.id] = Unit.TASK_DEFEND


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
	# Event has its own chip on the Overview tab — keep the year/week line clean.
	# Season chip rides on the end so the player feels the year pass without
	# stealing the calendar's spotlight.
	context_lbl.text = "Year %d, Week %d (week %d / 48)  ·  %s" % [
		GameState.current_year(), GameState.week, GameState.current_week_of_year(),
		Calendar.season_chip(GameState.week),
	]
	status_lbl.text = ""
	resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory, GameState.reputation))
	_refresh_event_chip()
	_refresh_tournament_chip()


# Persistent countdown in the top bar so the tournament is always at the
# player's elbow, not buried two tabs deep on Tactics. Goes warm-amber by
# default and bright gold + bigger text when a Grand Tournament is imminent.
func _refresh_tournament_chip() -> void:
	if tournament_chip == null:
		return
	var next_t: int = _next_tournament_week()
	if next_t <= 0:
		tournament_chip.visible = false
		return
	tournament_chip.visible = true
	var weeks_away: int = next_t - GameState.week
	var is_grand: bool = GameState.tournament_streak >= 2
	var prefix: String = "★ GRAND TOURNAMENT" if is_grand else "Tournament"
	if weeks_away <= 0:
		tournament_chip_lbl.text = "%s — THIS WEEK" % prefix
	elif weeks_away == 1:
		tournament_chip_lbl.text = "%s — next week (W%d)" % [prefix, next_t]
	else:
		tournament_chip_lbl.text = "%s in %d weeks (W%d)" % [prefix, weeks_away, next_t]

	# Colour ramp: Grand-imminent → bright gold; ≤2 weeks → warm amber;
	# otherwise → muted parchment. Same chip shape across all bands —
	# UiStyle.chip() builds the StyleBoxFlat; we just pick palette pairs.
	var sb: StyleBoxFlat
	if is_grand or weeks_away <= 0:
		sb = UiStyle.chip(Palette.CHIP_IMMINENT_BG, Palette.CHIP_IMMINENT_BORDER)
		tournament_chip_lbl.add_theme_color_override("font_color", Palette.CHIP_IMMINENT_TEXT)
		tournament_chip_lbl.add_theme_font_size_override("font_size", 15)
	elif weeks_away <= 2:
		sb = UiStyle.chip(Palette.CHIP_SOON_BG, Palette.CHIP_SOON_BORDER)
		tournament_chip_lbl.add_theme_color_override("font_color", Palette.CHIP_SOON_TEXT)
		tournament_chip_lbl.add_theme_font_size_override("font_size", 14)
	else:
		sb = UiStyle.chip(Palette.CHIP_FAR_BG, Palette.CHIP_FAR_BORDER)
		tournament_chip_lbl.add_theme_color_override("font_color", Palette.CHIP_FAR_TEXT)
		tournament_chip_lbl.add_theme_font_size_override("font_size", 13)
	tournament_chip.add_theme_stylebox_override("panel", sb)


func _refresh_event_chip() -> void:
	var event_label: String = EventKind.label(GameState.current_event)
	if GameState.current_event == EventKind.BATTLE_EVENT and GameState.current_battle_event != "":
		event_label = "%s — %s" % [event_label, BattleEvent.label(GameState.current_battle_event)]
	event_chip_lbl.text = "Upcoming · %s" % event_label


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
	# Live forecast vs this week's typical enemy for the formation's purpose:
	# the Defense default is judged against a home raid, the Attack default
	# against a pillage camp. Same math as Pre-Battle (CombatSim.analyze).
	editor.set_forecast_context("home_battle" if _tactics_mode == TACTICS_DEFENSE else "pillage")


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
			if StoryEventDB.is_story_sub_type(GameState.current_battle_event):
				return "→ A chronicle moment — no combat, no setup required"
			if CombatEventDB.has_mode(GameState.current_battle_event):
				return "→ " + CombatEventDB.tactics_advice_for(GameState.current_battle_event)
			match GameState.current_battle_event:
				"bandit_ambush": return "→ Use Defense formation"
				"champion_duel": return "→ Pick your strongest Str+Bra+Sword unit as champion"
				"bountiful_harvest": return "→ No combat — harvest arrives automatically"
				"merchant_caravan": return "→ No combat — pick a bundle on the summary screen"
				"refugee_caravan": return "→ No combat — the household's response plays out automatically"
				"noble_petition": return "→ No combat — court courtesy, resolved on the summary"
				"village_raid": return "→ Use Attack formation — riding out to defend a village"
				"tavern_riot": return "→ Use Defense formation — light combat near the village inn"
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

	# Assignment chip — single button that reads the current task at a glance.
	# Click opens a PopupMenu with Defend + one row per trainable stat. No
	# OptionButton arrow eating real estate on every unit row.
	var task_btn := Button.new()
	task_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var saved_task: String = GameState.pending_tasks.get(u.id, Unit.TASK_DEFEND)
	_style_task_btn(task_btn, u, saved_task)
	task_btn.pressed.connect(_open_task_popup.bind(u.id, task_btn))
	vbox.add_child(task_btn)

	var party_btn := Button.new()
	party_btn.toggle_mode = true
	party_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	party_btn.button_pressed = _expedition_party.has(u.id)
	_style_party_btn(party_btn, party_btn.button_pressed)
	party_btn.toggled.connect(_on_party_toggled.bind(u.id, party_btn))
	vbox.add_child(party_btn)

	if EventKind.is_tournament(GameState.current_event):
		var hint := Label.new()
		hint.text = "Tournament participants picked on Pre-Battle Review."
		hint.modulate = Color(0.65, 0.65, 0.65)
		vbox.add_child(hint)
	elif GameState.current_event == EventKind.AWAY_BATTLE:
		# Same toggle-button styling as the expedition-party row — keeps the
		# unit row free of checkboxes.
		var away_btn := Button.new()
		away_btn.toggle_mode = true
		away_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		away_btn.button_pressed = GameState.pending_away_party.has(u.id)
		_style_away_btn(away_btn, away_btn.button_pressed)
		away_btn.toggled.connect(_on_away_party_toggled.bind(u.id, away_btn))
		vbox.add_child(away_btn)

	return panel


# Set the visible text on the assignment chip based on the current task.
func _style_task_btn(btn: Button, u: Unit, task: String) -> void:
	if task == Unit.TASK_DEFEND:
		btn.text = "⛨  Defend the homestead"
		btn.add_theme_color_override("font_color", Color(0.82, 0.78, 0.62))
	elif task.begins_with(Unit.TASK_TRAIN_PREFIX):
		var stat: String = task.substr(Unit.TASK_TRAIN_PREFIX.length())
		var current: int = u.stats.get_value(stat)
		btn.text = "✦  Training %s  (now %d)" % [stat.capitalize(), current]
		btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	else:
		btn.text = "○  Idle"
		btn.add_theme_color_override("font_color", Color(0.62, 0.58, 0.45))
	btn.tooltip_text = "Click to change this week's assignment."


# Open a PopupMenu at the chip button's bottom edge. Defending first, a
# separator, then one entry per stat with the unit's current value.
func _open_task_popup(unit_id: int, anchor: Button) -> void:
	var u: Unit = GameState.find_unit(unit_id)
	if u == null:
		return
	var popup := PopupMenu.new()
	popup.add_item("⛨  Defend the homestead", 0)
	popup.add_separator()
	for i in range(Stats.STAT_KEYS.size()):
		var stat: String = Stats.STAT_KEYS[i]
		popup.add_item("✦  Train %s  (now %d)" % [stat.capitalize(), u.stats.get_value(stat)], i + 1)
	popup.id_pressed.connect(_on_task_popup_picked.bind(unit_id, anchor, popup))
	popup.close_requested.connect(func(): popup.queue_free())
	add_child(popup)
	var p := anchor.get_screen_position() + Vector2(0, anchor.size.y)
	popup.position = Vector2i(p)
	popup.popup()


func _on_task_popup_picked(id: int, unit_id: int, anchor: Button, popup: PopupMenu) -> void:
	if id == 0:
		GameState.pending_tasks[unit_id] = Unit.TASK_DEFEND
	else:
		var stat_idx: int = id - 1
		if stat_idx >= 0 and stat_idx < Stats.STAT_KEYS.size():
			GameState.pending_tasks[unit_id] = Unit.TASK_TRAIN_PREFIX + Stats.STAT_KEYS[stat_idx]
	var u: Unit = GameState.find_unit(unit_id)
	if u != null:
		_style_task_btn(anchor, u, GameState.pending_tasks[unit_id])
	popup.queue_free()


func _style_away_btn(btn: Button, in_party: bool) -> void:
	if in_party:
		btn.text = "⚔  Riding to the Away Battle"
		btn.add_theme_color_override("font_color", Color(1.0, 0.66, 0.34))
	else:
		btn.text = "＋  Add to Away Battle"
		btn.add_theme_color_override("font_color", Color(0.78, 0.74, 0.60))


func _on_party_toggled(pressed: bool, unit_id: int, btn: Button) -> void:
	if pressed:
		if not _expedition_party.has(unit_id):
			_expedition_party.append(unit_id)
	else:
		_expedition_party.erase(unit_id)
	_style_party_btn(btn, pressed)
	_refresh_action_buttons()


# Toggle styling: gold checkmark when in party, subdued plus when not.
func _style_party_btn(btn: Button, in_party: bool) -> void:
	if in_party:
		btn.text = "✓ In Expedition Party"
		btn.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	else:
		btn.text = "＋ Send on Expedition"
		btn.add_theme_color_override("font_color", Color(0.78, 0.74, 0.60))


func _on_away_party_toggled(pressed: bool, unit_id: int, btn: Button) -> void:
	if pressed:
		if not GameState.pending_away_party.has(unit_id):
			GameState.pending_away_party.append(unit_id)
	else:
		GameState.pending_away_party.erase(unit_id)
	_style_away_btn(btn, pressed)
	_refresh_away_section()


# ---------- Map tab — away-week options ----------

func _refresh_away_section() -> void:
	for child in away_section.get_children():
		child.queue_free()

	if GameState.current_event != EventKind.AWAY_BATTLE:
		away_section.visible = false
		return
	away_section.visible = true

	away_section.add_child(_styled_section_header("Away Battle this week", 18))

	var party_size: int = GameState.pending_away_party.size()
	var party_lbl := Label.new()
	party_lbl.text = "Party: %d riding" % party_size
	party_lbl.modulate = Color(0.78, 0.74, 0.60)
	away_section.add_child(party_lbl)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	away_section.add_child(actions)

	var pillage_btn := Button.new()
	pillage_btn.text = "⚒  Pillage Camp"
	pillage_btn.disabled = party_size == 0
	pillage_btn.pressed.connect(_on_pick_pillage)
	if GameState.pending_away_mode == "pillage":
		pillage_btn.modulate = Color(0.7, 1.0, 0.7)
	actions.add_child(pillage_btn)

	var explored_castles: Array = _explored_castles()

	var assault_btn := Button.new()
	assault_btn.text = "🏰  Assault Castle"
	assault_btn.disabled = party_size == 0 or explored_castles.is_empty()
	assault_btn.pressed.connect(_on_pick_assault)
	if GameState.pending_away_mode == "assault":
		assault_btn.modulate = Color(0.7, 1.0, 0.7)
	actions.add_child(assault_btn)

	if GameState.pending_away_mode == "assault":
		# Inline list of castle cards — no dropdown. Each card shows
		# coordinates, difficulty band, reward bundle; the highlighted card is
		# the current pending target.
		var castles_label := Label.new()
		castles_label.text = "Pick a target — known castles within the realm:"
		castles_label.modulate = Color(0.78, 0.74, 0.60)
		castles_label.add_theme_font_size_override("font_size", 13)
		away_section.add_child(castles_label)
		for castle in explored_castles:
			away_section.add_child(_build_castle_card(castle))

	# Away Mission Variants — data-driven modes from AwayModeDB. Gated by
	# min_week so early-game weeks see only pillage/assault. Each available
	# mode renders as a labelled button under a small subhead.
	var unlocked_modes: Array[String] = AwayModeDB.available_at_week(GameState.week)
	if not unlocked_modes.is_empty():
		var variants_hint := Label.new()
		variants_hint.text = "Other targets in the marches:"
		variants_hint.modulate = Color(0.78, 0.74, 0.60)
		variants_hint.add_theme_font_size_override("font_size", 13)
		away_section.add_child(variants_hint)

		# Wrapping container — 8+ unlocked variants at endgame would overflow
		# a single HBox at 1280-wide. HFlowContainer wraps to a new line as
		# needed and keeps each button at its natural width.
		var variants_row := HFlowContainer.new()
		variants_row.add_theme_constant_override("h_separation", 8)
		variants_row.add_theme_constant_override("v_separation", 6)
		variants_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		away_section.add_child(variants_row)

		for mode_id in unlocked_modes:
			var btn := Button.new()
			btn.text = AwayModeDB.label_for(mode_id)
			btn.disabled = party_size == 0
			btn.tooltip_text = AwayModeDB.tooltip_for(mode_id)
			btn.pressed.connect(_on_pick_away_variant.bind(mode_id))
			if GameState.pending_away_mode == mode_id:
				btn.modulate = Color(0.7, 1.0, 0.7)
			variants_row.add_child(btn)


func _on_pick_away_variant(mode_id: String) -> void:
	GameState.pending_away_mode = mode_id
	GameState.pending_assault_castle = null
	_refresh_away_section()


func _on_pick_pillage() -> void:
	GameState.pending_away_mode = "pillage"
	GameState.pending_assault_castle = null
	_refresh_away_section()


func _on_pick_assault() -> void:
	GameState.pending_away_mode = "assault"
	_refresh_away_section()


func _on_castle_card_picked(castle: Castle) -> void:
	GameState.pending_assault_castle = castle
	_refresh_away_section()


# A clickable card for one castle. Highlighted when it's the current pending
# target. Replaces the OptionButton picker entirely.
func _build_castle_card(castle: Castle) -> Control:
	var is_target: bool = GameState.pending_assault_castle == castle
	var diff_band: String = _castle_difficulty_band(castle.difficulty)
	var diff_color: Color = _castle_difficulty_color(castle.difficulty)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 64)
	btn.toggle_mode = true
	btn.button_pressed = is_target
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(_on_castle_card_picked.bind(castle))

	# Card stylebox — idle vs target colour pair from Palette.
	var sb := UiStyle.card(
		Palette.CASTLE_BG_TARGET if is_target else Palette.CASTLE_BG_IDLE,
		Palette.CASTLE_BORDER_TARGET if is_target else Palette.CASTLE_BORDER_IDLE,
	)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)

	# Pad the card contents away from the button border. MarginContainer is
	# the cleanest way to do this — the stylebox's content_margin only affects
	# the Button's own text label, not arbitrary children we add inside.
	var pad := MarginContainer.new()
	pad.set_anchors_preset(Control.PRESET_FULL_RECT)
	pad.add_theme_constant_override("margin_left", 14)
	pad.add_theme_constant_override("margin_right", 14)
	pad.add_theme_constant_override("margin_top", 10)
	pad.add_theme_constant_override("margin_bottom", 10)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(pad)

	var content := HBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(content)

	# Left column — castle coords + difficulty band.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	left.add_theme_constant_override("separation", 2)
	content.add_child(left)

	var coord_lbl := Label.new()
	coord_lbl.text = "🏰  (%d, %d)" % [castle.x, castle.y]
	coord_lbl.add_theme_font_size_override("font_size", 15)
	coord_lbl.add_theme_color_override("font_color", Color(0.95, 0.78, 0.30))
	left.add_child(coord_lbl)

	var diff_lbl := Label.new()
	diff_lbl.text = "%s · diff %d" % [diff_band, castle.difficulty]
	diff_lbl.add_theme_font_size_override("font_size", 12)
	diff_lbl.add_theme_color_override("font_color", diff_color)
	left.add_child(diff_lbl)

	# Right column — reward bundle (Dictionary keyed by ResourceDB ids).
	var reward_lbl := Label.new()
	reward_lbl.text = ResourceDB.describe(castle.reward)
	reward_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reward_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reward_lbl.add_theme_font_size_override("font_size", 13)
	reward_lbl.add_theme_color_override("font_color", Color(0.70, 0.88, 0.60))
	content.add_child(reward_lbl)

	# Target marker on the right when this is the selected castle.
	var status_lbl := Label.new()
	if is_target:
		status_lbl.text = "✓ Target"
		status_lbl.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	else:
		status_lbl.text = "Pick"
		status_lbl.add_theme_color_override("font_color", Color(0.62, 0.56, 0.42))
	status_lbl.add_theme_font_size_override("font_size", 13)
	status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(status_lbl)

	return btn


func _castle_difficulty_band(d: int) -> String:
	if d < 60:    return "Lightly held"
	if d < 110:   return "Garrisoned"
	if d < 160:   return "Well-defended"
	return "A formidable seat"


func _castle_difficulty_color(d: int) -> Color:
	if d < 60:    return Palette.DIFF_LIGHT
	if d < 110:   return Palette.DIFF_MEDIUM
	if d < 160:   return Palette.DIFF_HEAVY
	return Palette.DIFF_FORMIDABLE


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
				tile.castle.difficulty, ResourceDB.describe(tile.castle.reward),
			])
	else:
		if MapTile.is_fogged_in(GameState.world, tile.x, tile.y):
			bits.append("Knowledge: Fogged — within scouting reach")
		else:
			bits.append("Knowledge: Unknown — too distant to scout yet")
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
	explore_btn.tooltip_text = _explore_disabled_reason() if explore_btn.disabled else "Send the selected party to scout this tile."
	gather_btn.tooltip_text = _gather_disabled_reason() if gather_btn.disabled else "Send the selected party to gather here."


func _explore_disabled_reason() -> String:
	if _expedition_party.is_empty():
		return "Pick at least one unit with ＋ Send on Expedition first."
	if _selected.x < 0:
		return "Click a tile on the map to choose where to scout."
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	if tile == null:
		return "Invalid tile."
	if tile.active_expedition != null:
		return "Another expedition is already at this tile."
	if tile.knowledge == MapTile.Knowledge.EXPLORED:
		return "This tile is already known — pick an unexplored one."
	if not MapTile.is_fogged_in(GameState.world, tile.x, tile.y):
		return "Too distant — scouts can only step into a tile next to one they already know."
	return ""


func _gather_disabled_reason() -> String:
	if _expedition_party.is_empty():
		return "Pick at least one unit with ＋ Send on Expedition first."
	if _selected.x < 0:
		return "Click a tile on the map to choose where to gather."
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	if tile == null:
		return "Invalid tile."
	if tile.active_expedition != null:
		return "Another expedition is already at this tile."
	if tile.knowledge != MapTile.Knowledge.EXPLORED:
		return "Send scouts here first — you don't yet know what this tile yields."
	if tile.gather_resource() == "":
		return "This terrain yields nothing the household can gather."
	return ""


func _can_explore() -> bool:
	if _selected.x < 0 or _expedition_party.is_empty():
		return false
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	if tile == null or tile.active_expedition != null:
		return false
	# Only fogged tiles (adjacent to a known one) are scoutable. This makes
	# the map develop outward in a ring rather than letting scouts teleport
	# to the far edge on day one.
	return MapTile.is_fogged_in(GameState.world, tile.x, tile.y)


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
		GameState.pending_tasks.erase(uid)
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
		none_lbl.text = "The grounds are quiet — no parties in the field."
		none_lbl.modulate = Color(0.62, 0.56, 0.42)
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
					var est_amount: int = Expedition.estimate_yield(party_strength)
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
	crafting_vbox.add_child(_styled_section_header("Raw Materials"))

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

	# Recipes grouped by type. We show only recipes the player can craft right
	# now — research unlocked AND ingredients in hand. The Research tab is the
	# place to see what's coming; this tab is the place to do something with
	# what you've got.
	var type_labels: Dictionary = {
		ResourceDB.ResType.FABRIC: "Fabric",
		ResourceDB.ResType.TIMBER: "Timber",
		ResourceDB.ResType.METAL:  "Metal",
	}
	var any_recipe_anywhere: bool = false
	for res_type: int in [ResourceDB.ResType.FABRIC, ResourceDB.ResType.TIMBER, ResourceDB.ResType.METAL]:
		var rows_for_type: Array[Control] = []
		for id: String in ResourceDB.RESOURCES:
			var entry: Dictionary = ResourceDB.RESOURCES[id]
			if not entry.has("type") or entry["type"] != res_type:
				continue
			if not ResourceDB.is_craftable(id, GameState.researched):
				continue
			# Show ALL unlocked recipes — affordable or not. The Craft button
			# disables itself for short-on-materials recipes with a tooltip
			# explaining which input is short, so the player learns the recipe
			# without needing the Research tab to remind them.
			rows_for_type.append(_build_recipe_row(id, entry, res_type))

		if rows_for_type.is_empty():
			continue
		any_recipe_anywhere = true
		crafting_vbox.add_child(_styled_section_header(type_labels[res_type]))
		for row in rows_for_type:
			crafting_vbox.add_child(row)

	if not any_recipe_anywhere:
		var none_lbl := Label.new()
		none_lbl.text = "The workshop stands idle — no recipes are unlocked. Visit the Research tab to learn your first craft."
		none_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		none_lbl.modulate = Color(0.58, 0.52, 0.40)
		crafting_vbox.add_child(none_lbl)


func _build_recipe_row(id: String, entry: Dictionary, res_type: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Tier-colored swatch icon — small visual anchor next to the name.
	row.add_child(_make_recipe_icon(entry["tier"], res_type))

	# Clickable tier-coloured name → info popup. Hover also shows the same
	# detail body as a quick-reference tooltip so players don't need to click
	# every recipe to see what it does.
	var name_btn := LinkButton.new()
	name_btn.text = entry["name"]
	name_btn.add_theme_color_override("font_color", ResourceDB.color_for_tier(entry["tier"]))
	name_btn.custom_minimum_size = Vector2(140, 0)
	name_btn.pressed.connect(_show_resource_popup.bind(id))
	var name_tip: String = _recipe_tooltip(id, entry)
	name_btn.tooltip_text = name_tip
	row.add_child(name_btn)

	# Recipe inputs with current stock — shortfall coloured red so the eye
	# lands on the missing material instantly.
	var recipe: Dictionary = entry["recipe"]
	var recipe_parts: PackedStringArray = PackedStringArray()
	for input_id: String in recipe:
		var input_entry: Dictionary = ResourceDB.RESOURCES.get(input_id, {})
		var input_name: String = input_entry.get("name", input_id)
		var have: int = GameState.inventory.get(input_id, 0)
		var need: int = int(recipe[input_id])
		if have < need:
			recipe_parts.append("[color=#E07050]%s ×%d (have %d)[/color]" % [input_name, need, have])
		else:
			recipe_parts.append("%s ×%d (have %d)" % [input_name, need, have])
	var recipe_rtl := RichTextLabel.new()
	recipe_rtl.bbcode_enabled = true
	recipe_rtl.fit_content = true
	recipe_rtl.scroll_active = false
	recipe_rtl.parse_bbcode(" + ".join(recipe_parts))
	recipe_rtl.modulate = Color(0.82, 0.78, 0.62)
	recipe_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipe_rtl.tooltip_text = name_tip
	row.add_child(recipe_rtl)

	var craft_btn := Button.new()
	craft_btn.text = "Craft"
	var affordable: bool = ResourceDB.can_afford(id, GameState.inventory)
	craft_btn.disabled = not affordable
	if affordable:
		craft_btn.tooltip_text = "Craft 1 × %s." % entry["name"]
		craft_btn.pressed.connect(_on_craft.bind(id))
	else:
		craft_btn.tooltip_text = _recipe_shortfall_text(id, entry)
	row.add_child(craft_btn)

	return row


# Tooltip body shared by the recipe name and the inputs row — answers
# "what does this make and what does it need?" without opening the popup.
func _recipe_tooltip(id: String, entry: Dictionary) -> String:
	var bits: Array[String] = []
	bits.append("%s — Tier %d" % [entry["name"], int(entry["tier"])])
	var recipe: Dictionary = entry.get("recipe", {})
	if not recipe.is_empty():
		var input_parts: Array[String] = []
		for input_id: String in recipe:
			var ie: Dictionary = ResourceDB.RESOURCES.get(input_id, {})
			input_parts.append("%s ×%d" % [ie.get("name", input_id), int(recipe[input_id])])
		bits.append("Needs: " + " + ".join(input_parts))
	bits.append("Click name for full details.")
	return "\n".join(bits)


# "Short by N Plant Fibres" — the exact list of what's missing, ordered by
# how short you are so the player can prioritise which material to gather.
func _recipe_shortfall_text(id: String, entry: Dictionary) -> String:
	var shortfalls: Array[String] = []
	for input_id: String in entry.get("recipe", {}):
		var need: int = int(entry["recipe"][input_id])
		var have: int = GameState.inventory.get(input_id, 0)
		if have < need:
			var ie: Dictionary = ResourceDB.RESOURCES.get(input_id, {})
			shortfalls.append("%s ×%d more" % [ie.get("name", input_id), need - have])
	if shortfalls.is_empty():
		return ""
	return "Need: " + ", ".join(shortfalls)


# Shared styling for runtime-built section headers. Same fleuron prefix +
# warm-gold colour we use on the tscn-defined headers, so dynamic and static
# sections read with one voice.
func _styled_section_header(text: String, font_size: int = 16) -> Label:
	var lbl := Label.new()
	lbl.text = "❦  %s" % text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42))
	return lbl


# Small tier-coloured swatch with a one-glyph type hint. Drawn as a Label
# inside a tinted background — cheap "icon" placeholder until real art lands.
func _make_recipe_icon(tier: int, res_type: int) -> Control:
	const TYPE_GLYPH: Dictionary = {
		ResourceDB.ResType.FABRIC: "◆",
		ResourceDB.ResType.TIMBER: "▲",
		ResourceDB.ResType.METAL:  "■",
	}
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(28, 28)
	# Tier-coloured swatch — UiStyle handles the small-corner rounding +
	# 1-px border; we just pass the darkened bg and the tier accent.
	var tier_color: Color = ResourceDB.color_for_tier(tier)
	panel.add_theme_stylebox_override("panel", UiStyle.swatch(
		tier_color.darkened(0.45), tier_color,
	))

	var lbl := Label.new()
	lbl.text = TYPE_GLYPH.get(res_type, "·")
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", ResourceDB.color_for_tier(tier))
	lbl.add_theme_font_size_override("font_size", 14)
	panel.add_child(lbl)
	return panel


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
	Crafting.craft(GameState, resource_id)
	status_lbl.text = "Crafted: %s" % entry["name"]
	_refresh_crafting_tab()
	_refresh_header()


# ---------- Research tab ----------
#
# Layout intent: swimlane tree — each ResourceDB.RESEARCH_CATEGORIES key gets
# its own horizontal row; tier columns grow rightward. Empty cells stay empty
# so the structure of the tree reads at a glance. Detail panel on the right
# fills in when an icon is selected.

const RESEARCH_CATEGORY_COLOR: Dictionary = {
	"cultivation": Color(0.55, 0.82, 0.45),
	"forestry":    Color(0.45, 0.70, 0.32),
	"metallurgy":  Color(0.62, 0.72, 0.92),
	"husbandry":   Color(0.86, 0.62, 0.36),
	"lore":        Color(0.82, 0.72, 0.40),
}
const RESEARCH_TIER_MIN: int = 1
const RESEARCH_TIER_MAX: int = 4
const RESEARCH_CELL_SIZE: Vector2 = Vector2(108, 108)
const RESEARCH_CELL_GAP_H: int = 14
const RESEARCH_CELL_GAP_V: int = 8

var _selected_research_id: String = ""


func _refresh_research_tab() -> void:
	for c in research_body.get_children():
		c.queue_free()

	# Progress strip — answers "how far along is the household's learning,
	# and what can it afford?" before the player reads a single cell.
	var total_projects: int = ResourceDB.RESEARCH_PROJECTS.size()
	var affordable_now: int = 0
	for pid: String in ResourceDB.RESEARCH_PROJECTS:
		var proj: Dictionary = ResourceDB.RESEARCH_PROJECTS[pid]
		if GameState.researched.has(pid):
			continue
		if _research_prereqs_met(proj) and GameState.gold >= int(proj.get("cost_gold", 0)):
			affordable_now += 1
	var strip := Label.new()
	strip.text = "Studied %d of %d  ·  %d within the treasury's reach (gold-rimmed below)" % [
		GameState.researched.size(), total_projects, affordable_now,
	]
	strip.modulate = Color(0.82, 0.76, 0.58)
	research_body.add_child(strip)

	# Two-column body: swimlane grid on the left, detail card on the right.
	# Wrap the whole split in a ScrollContainer so a growing tier count can't
	# push the tab container past the viewport width — otherwise the Research
	# tab "locks" the screen, hiding the tab bar and surrounding chrome.
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	research_body.add_child(scroll)

	var split := HBoxContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	scroll.add_child(split)

	split.add_child(_build_research_grid())
	# Detail panel gets a fixed width on the right so the swimlane grid takes
	# whatever's left — keeps the layout predictable as the tree grows.
	var detail: Control = _build_research_detail()
	detail.custom_minimum_size = Vector2(300, 0)
	detail.size_flags_horizontal = 0  # do not expand — fixed width
	split.add_child(detail)


func _build_research_grid() -> Control:
	var grid_panel := PanelContainer.new()
	grid_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	grid_panel.add_child(margin)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)
	margin.add_child(outer)

	# Determine which tier columns to show — the lowest tier in the data, up
	# through the highest. Keeps the grid compact as the tree grows.
	var min_tier: int = RESEARCH_TIER_MAX
	var max_tier: int = RESEARCH_TIER_MIN
	for pid: String in ResourceDB.RESEARCH_PROJECTS:
		var t: int = int(ResourceDB.RESEARCH_PROJECTS[pid].get("tier", 1))
		min_tier = mini(min_tier, t)
		max_tier = maxi(max_tier, t)

	# Tier header row — sits above the swimlanes.
	var tier_header_row := HBoxContainer.new()
	tier_header_row.add_theme_constant_override("separation", RESEARCH_CELL_GAP_H)
	outer.add_child(tier_header_row)

	# Empty label cell for the category-name column to align with the swimlanes.
	var cat_col_spacer := Control.new()
	cat_col_spacer.custom_minimum_size = Vector2(96, 0)
	tier_header_row.add_child(cat_col_spacer)

	for t in range(min_tier, max_tier + 1):
		var tier_lbl := Label.new()
		tier_lbl.text = "❦  Tier %d" % t
		tier_lbl.custom_minimum_size = Vector2(RESEARCH_CELL_SIZE.x, 0)
		tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tier_lbl.add_theme_font_size_override("font_size", 13)
		tier_lbl.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42))
		tier_header_row.add_child(tier_lbl)

	# One row per category — empty cells for tiers with no project in that lane.
	for category in ResourceDB.RESEARCH_CATEGORIES:
		outer.add_child(_build_research_swimlane(category, min_tier, max_tier))

	return grid_panel


func _build_research_swimlane(category: String, min_tier: int, max_tier: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", RESEARCH_CELL_GAP_H)

	# Category name on the left — tier-coloured to match its lane.
	var color: Color = RESEARCH_CATEGORY_COLOR.get(category, Color(0.7, 0.7, 0.7))
	var cat_lbl := Label.new()
	cat_lbl.text = ResourceDB.RESEARCH_CATEGORY_LABELS.get(category, category.capitalize())
	cat_lbl.custom_minimum_size = Vector2(96, RESEARCH_CELL_SIZE.y)
	cat_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cat_lbl.add_theme_font_size_override("font_size", 13)
	cat_lbl.add_theme_color_override("font_color", color)
	row.add_child(cat_lbl)

	# Bucket projects in this category by tier so we can fill cells in order.
	var by_tier: Dictionary = {}
	for pid: String in ResourceDB.RESEARCH_PROJECTS:
		var p: Dictionary = ResourceDB.RESEARCH_PROJECTS[pid]
		if str(p.get("category", "")) != category:
			continue
		var t: int = int(p.get("tier", 1))
		if not by_tier.has(t):
			by_tier[t] = []
		by_tier[t].append(pid)

	for t in range(min_tier, max_tier + 1):
		var cell_list: Array = by_tier.get(t, [])
		if cell_list.is_empty():
			row.add_child(_research_empty_cell(color))
			continue
		# Multiple projects in one (category, tier) slot stack vertically.
		var cell_vbox := VBoxContainer.new()
		cell_vbox.add_theme_constant_override("separation", RESEARCH_CELL_GAP_V)
		cell_vbox.custom_minimum_size = Vector2(RESEARCH_CELL_SIZE.x, 0)
		for pid in cell_list:
			cell_vbox.add_child(_make_research_icon(pid))
		row.add_child(cell_vbox)

	return row


func _research_empty_cell(category_color: Color) -> Control:
	# Faint dotted placeholder so empty cells read as "nothing here yet" rather
	# than "missing element." A dim ◦ glyph sits centred in the cell.
	var c := PanelContainer.new()
	c.custom_minimum_size = RESEARCH_CELL_SIZE
	c.add_theme_stylebox_override("panel", UiStyle.chip(
		Color(0, 0, 0, 0), category_color.darkened(0.65), 1,
	))
	var dot := Label.new()
	dot.text = "◦"
	dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dot.add_theme_color_override("font_color", category_color.darkened(0.55))
	dot.add_theme_font_size_override("font_size", 22)
	dot.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(dot)
	return c


func _make_research_icon(project_id: String) -> Control:
	var proj: Dictionary = ResourceDB.RESEARCH_PROJECTS[project_id]
	var is_done: bool = GameState.researched.has(project_id)
	var prereqs_met: bool = _research_prereqs_met(proj)
	var category: String = str(proj.get("category", ""))
	var color: Color = RESEARCH_CATEGORY_COLOR.get(category, Color(0.7, 0.7, 0.7))

	var cost: int = int(proj.get("cost_gold", 0))
	var affordable: bool = prereqs_met and not is_done and GameState.gold >= cost

	var btn := Button.new()
	btn.custom_minimum_size = RESEARCH_CELL_SIZE
	btn.toggle_mode = true
	btn.button_pressed = (_selected_research_id == project_id)
	if is_done:
		btn.tooltip_text = "%s  ✓ studied" % proj["name"]
	elif not prereqs_met:
		btn.tooltip_text = "%s — %d gold (locked)" % [proj["name"], cost]
	else:
		btn.tooltip_text = "%s — %d gold%s" % [
			proj["name"], cost, "" if affordable else " (short of coin)",
		]

	# Border carries the state: category colour when reachable, dimmed when
	# locked — and gold when it could be bought THIS week, so the tab answers
	# "what can I afford right now?" at a glance.
	var border: Color = color if prereqs_met or is_done else color.darkened(0.4)
	if affordable:
		border = Color(1.0, 0.84, 0.42)
	var sb := UiStyle.chip(
		color.darkened(0.55 if not is_done else 0.30),
		border,
	)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.add_theme_stylebox_override("focus", sb)
	if not prereqs_met and not is_done:
		btn.modulate = Color(0.55, 0.55, 0.55)

	# Glyph inside the icon — checkmark if done, lock if gated, plus otherwise.
	var glyph: String = "✓" if is_done else ("🔒" if not prereqs_met else "✚")
	var glyph_lbl := Label.new()
	glyph_lbl.text = glyph
	glyph_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	glyph_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glyph_lbl.add_theme_color_override("font_color", color.lightened(0.15))
	glyph_lbl.add_theme_font_size_override("font_size", 32)
	glyph_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	glyph_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(glyph_lbl)

	btn.pressed.connect(_on_research_icon_clicked.bind(project_id))
	return btn


func _on_research_icon_clicked(project_id: String) -> void:
	_selected_research_id = project_id
	_refresh_research_tab()


func _research_prereqs_met(proj: Dictionary) -> bool:
	for prereq in proj.get("prerequisites", []):
		if not GameState.researched.has(prereq):
			return false
	return true


func _build_research_detail() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 0)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	if _selected_research_id == "" or not ResourceDB.RESEARCH_PROJECTS.has(_selected_research_id):
		var hint := Label.new()
		hint.text = "Pick a project to see its details."
		hint.modulate = Color(0.65, 0.60, 0.45)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(hint)
		return panel

	var proj: Dictionary = ResourceDB.RESEARCH_PROJECTS[_selected_research_id]
	var is_done: bool = GameState.researched.has(_selected_research_id)
	var prereqs_met: bool = _research_prereqs_met(proj)

	var title := Label.new()
	title.text = proj["name"] + ("  ✓" if is_done else "")
	title.add_theme_font_size_override("font_size", 18)
	title.modulate = Color(1.0, 0.84, 0.42)
	vbox.add_child(title)

	var desc := Label.new()
	desc.text = proj["description"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc.modulate = Color(0.82, 0.76, 0.58)
	vbox.add_child(desc)

	var prereqs: Array = proj.get("prerequisites", [])
	if not prereqs.is_empty():
		var prereq_names: Array[String] = []
		for pid in prereqs:
			var pproj: Dictionary = ResourceDB.RESEARCH_PROJECTS.get(pid, {})
			prereq_names.append(pproj.get("name", pid))
		var prereq_lbl := Label.new()
		prereq_lbl.text = "Requires: %s" % ", ".join(prereq_names)
		prereq_lbl.modulate = Color(0.85, 0.55, 0.30) if not prereqs_met else Color(0.6, 0.85, 0.6)
		prereq_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		vbox.add_child(prereq_lbl)

	var unlock_names: Array[String] = []
	for rid: String in proj["unlocks"]:
		var rentry: Dictionary = ResourceDB.RESOURCES.get(rid, {})
		# Real recipes have a "name" — placeholder/future unlocks fall back to
		# the snake_case ID, prettified to title case so it still reads cleanly.
		var pretty: String = rid.replace("_", " ")
		# Capitalise the first letter of each word for a cleaner display.
		var words: PackedStringArray = pretty.split(" ")
		var titled: Array[String] = []
		for w in words:
			if w.length() > 0:
				titled.append(w[0].to_upper() + w.substr(1))
		unlock_names.append(rentry.get("name", " ".join(titled)))
	var unlocks_lbl := Label.new()
	unlocks_lbl.text = "Unlocks: %s" % ", ".join(unlock_names)
	unlocks_lbl.modulate = Color(0.65, 0.88, 0.65)
	unlocks_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(unlocks_lbl)

	vbox.add_child(HSeparator.new())

	if is_done:
		var done_lbl := Label.new()
		done_lbl.text = "Already researched."
		done_lbl.modulate = Color(0.55, 0.55, 0.55)
		vbox.add_child(done_lbl)
	else:
		var cost: int = int(proj["cost_gold"])
		var btn := Button.new()
		btn.text = "Research — %d gold" % cost
		btn.disabled = (not prereqs_met) or GameState.gold < cost
		btn.pressed.connect(_on_research.bind(_selected_research_id))
		vbox.add_child(btn)
		# A disabled button without a reason is a riddle — name the blocker.
		if btn.disabled:
			var why := Label.new()
			if not prereqs_met:
				why.text = "Locked — study what it requires first."
			else:
				why.text = "The treasury is %d gold short." % (cost - GameState.gold)
			why.modulate = Color(0.85, 0.55, 0.30)
			why.autowrap_mode = TextServer.AUTOWRAP_WORD
			vbox.add_child(why)

	return panel


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
			GameState.purchase_research(project_id)
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
		_add_upcoming_line("No parties in the field.", true)
	else:
		for exped in GameState.expeditions:
			var return_week: int = GameState.week + exped.weeks_remaining
			_add_upcoming_line("Expedition #%d (%s) returns Week %d (in %dw)" % [
				exped.id, exped.kind_label(), return_week, exped.weeks_remaining,
			], false)

	if GameState.run_history.is_empty():
		var none := Label.new()
		none.text = "The chronicle is unwritten — your first week is still to come."
		none.modulate = Color(0.65, 0.65, 0.65)
		history_list.add_child(none)
		return

	var entries: Array = GameState.run_history.duplicate()
	entries.reverse()
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		history_list.add_child(_build_history_row(entry))
		# Subtle separator between weeks — fades to nothing at the edges, sits
		# at low alpha so it reads as a flourish rather than a hard line.
		if i < entries.size() - 1:
			var sep := HSeparator.new()
			sep.modulate = Color(0.45, 0.36, 0.20, 0.30)
			history_list.add_child(sep)


func _build_history_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Heraldic bullet — gold dot at left.
	var bullet := Label.new()
	bullet.text = "❦"
	bullet.modulate = Color(0.72, 0.58, 0.30)
	bullet.custom_minimum_size = Vector2(20, 0)
	row.add_child(bullet)

	# Year/week chip — small fixed-width column.
	var when_lbl := Label.new()
	when_lbl.text = "Y%d W%d  (%d/48)" % [entry["year"], entry["week"], entry["week_of_year"]]
	when_lbl.custom_minimum_size = Vector2(150, 0)
	when_lbl.modulate = Color(0.78, 0.72, 0.55)
	row.add_child(when_lbl)

	# Event label.
	var event_lbl := Label.new()
	event_lbl.text = str(entry["event_label"])
	event_lbl.custom_minimum_size = Vector2(220, 0)
	event_lbl.modulate = Color(0.88, 0.82, 0.65)
	row.add_child(event_lbl)

	# Outcome chip — colour-coded.
	var outcome: String = str(entry["outcome"])
	var outcome_lbl := Label.new()
	outcome_lbl.text = outcome
	outcome_lbl.custom_minimum_size = Vector2(220, 0)
	outcome_lbl.modulate = _outcome_color(outcome)
	row.add_child(outcome_lbl)

	# Tail — score + reward, dim.
	var tail_bits: PackedStringArray = PackedStringArray()
	if int(entry.get("player_total", 0)) > 0 or int(entry.get("enemy_total", 0)) > 0:
		tail_bits.append("%d vs %d" % [entry["player_total"], entry["enemy_total"]])
	if entry.get("reward_str", "") != "":
		tail_bits.append("+ %s" % entry["reward_str"])
	var tail_lbl := Label.new()
	tail_lbl.text = " · ".join(tail_bits) if not tail_bits.is_empty() else ""
	tail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tail_lbl.modulate = Color(0.60, 0.55, 0.42)
	row.add_child(tail_lbl)

	return row


func _outcome_color(outcome: String) -> Color:
	if outcome.begins_with("Won") or outcome.begins_with("Victory"):
		return Color(0.55, 0.88, 0.55)
	if outcome.begins_with("Lost") or outcome.begins_with("Defeat"):
		return Color(0.92, 0.55, 0.45)
	return Color(0.78, 0.74, 0.60)


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
		if GameState.pending_tasks.has(u.id):
			u.current_task = GameState.pending_tasks[u.id]
		else:
			u.current_task = Unit.TASK_DEFEND

	SaveManager.save_game()

	GameState.phase_machine.transition(PhaseMachine.Phase.TICK)
	var results: Dictionary = Tick.apply(GameState)

	# FM-style "processing the week" sweep: hand the tick results to the
	# WeekProcessor overlay, which reveals each beat and pauses on notable
	# ones before jumping to Pre-Battle. Planning stops handling hotkeys while
	# the overlay owns input.
	set_process_unhandled_input(false)
	var header: String = "Year %d, Week %d — the week unfolds" % [
		GameState.current_year(), GameState.week,
	]
	var processor := WeekProcessor.new()
	add_child(processor)
	processor.begin(header, _build_week_steps(results), func() -> void:
		get_tree().change_scene_to_file("res://scenes/screens/pre_battle_review.tscn")
	)


# Translate the raw Tick result Dictionary into the ordered list of FM-style
# beats the WeekProcessor reveals. Only beats with something to say are
# included; the closing "week ahead" beat always pauses, mirroring how FM
# stops the schedule before a match.
func _build_week_steps(results: Dictionary) -> Array:
	var steps: Array = []

	# 1 — Upkeep & coffers. Always shown; pauses only if wages went unpaid.
	var coffer_lines: Array[String] = []
	var income: int = int(results.get("gold_income", 0))
	var upkeep: int = int(results.get("gold_deducted", 0))
	if income > 0:
		coffer_lines.append("Holdings yield +%d gold." % income)
	if upkeep > 0:
		coffer_lines.append("Weekly upkeep costs %d gold." % upkeep)
	var debt: bool = bool(results.get("maintenance_debt", false))
	if debt:
		coffer_lines.append("⚠ The coffers ran dry — wages went unpaid this week!")
	else:
		coffer_lines.append("The treasury holds %d gold." % GameState.gold)
	steps.append({
		"title": "Upkeep & Coffers", "icon": "⚖", "lines": coffer_lines,
		"tone": "bad" if debt else "gold", "pause": debt,
	})

	# 2 — Training yard.
	var train_lines: Array[String] = []
	for entry in results.get("training", []):
		var u: Unit = GameState.find_unit(int(entry.get("unit_id", -1)))
		var who: String = u.unit_name if u != null else "A unit"
		var stat: String = str(entry.get("stat", "")).capitalize()
		if int(entry.get("leveled", 0)) > 0:
			var line: String = "%s drilled %s → %d.  ▲" % [who, stat, int(entry.get("after", 0))]
			if entry.get("bonus_leveled", false) and str(entry.get("bonus_stat", "")) != "":
				line += "  A spark of %s, too!" % str(entry.get("bonus_stat", "")).capitalize()
			train_lines.append(line)
		elif bool(entry.get("developing", false)):
			train_lines.append("%s works at %s — coming along." % [who, stat])
		else:
			train_lines.append("%s trained %s, but it holds firm at %d." % [
				who, stat, int(entry.get("after", 0)),
			])
	if not train_lines.is_empty():
		steps.append({
			"title": "The Training Yard", "icon": "⚔", "lines": train_lines,
			"tone": "good", "pause": false,
		})

	# 3 — Determination stirrings (every 4th week). Entries carry the Unit
	# object directly (see Determination.roll_for_units).
	var det_lines: Array[String] = []
	for entry in results.get("determination", []):
		var du: Unit = entry.get("unit", null)
		var who: String = du.unit_name if du != null else "A unit"
		det_lines.append("%s feels something stir within — %s sharpens." % [
			who, str(entry.get("stat", "")).capitalize(),
		])
	if not det_lines.is_empty():
		steps.append({
			"title": "A Stirring of Resolve", "icon": "✶", "lines": det_lines,
			"tone": "info", "pause": false,
		})

	# 4 — Returning expeditions. Pauses if a castle is uncovered.
	var exp_lines: Array[String] = []
	var castle_found: bool = false
	for ret in results.get("expedition_returns", []):
		var tx: int = int(ret.get("target_x", 0))
		var ty: int = int(ret.get("target_y", 0))
		if int(ret.get("kind", -1)) == Expedition.Kind.GATHER and int(ret.get("yield_amount", 0)) > 0:
			var rkey: String = str(ret.get("yield_resource", ""))
			var rname: String = ResourceDB.RESOURCES.get(rkey, {}).get("name", rkey.capitalize())
			exp_lines.append("A gathering party returns from (%d, %d) bearing %d %s." % [
				tx, ty, int(ret.get("yield_amount", 0)), rname,
			])
		elif str(ret.get("revealed_terrain", "")) != "":
			var terr: String = str(ret.get("revealed_terrain", "")).capitalize()
			if ret.get("revealed_castle", null) != null:
				castle_found = true
				exp_lines.append("Scouts chart the %s at (%d, %d) — and a castle looms there!" % [terr, tx, ty])
			else:
				exp_lines.append("Scouts chart the %s at (%d, %d)." % [terr, tx, ty])
		else:
			exp_lines.append("An expedition returns from (%d, %d)." % [tx, ty])
	if not exp_lines.is_empty():
		steps.append({
			"title": "Expeditions Return", "icon": "🧭", "lines": exp_lines,
			"tone": "good", "pause": castle_found,
		})

	# 5 — Infirmary recoveries.
	var heal_lines: Array[String] = []
	for entry in results.get("injury_recoveries", []):
		var u: Unit = GameState.find_unit(int(entry.get("unit_id", -1)))
		var who: String = u.unit_name if u != null else "A unit"
		heal_lines.append("%s has recovered — %s is whole again." % [
			who, str(entry.get("stat", "")).capitalize(),
		])
	if not heal_lines.is_empty():
		steps.append({
			"title": "The Infirmary", "icon": "✚", "lines": heal_lines,
			"tone": "heal", "pause": false,
		})

	# 6 — The week ahead. Always last, always pauses — the FM "stop for the match".
	steps.append({
		"title": "The Week Ahead", "icon": "❦",
		"lines": [_current_event_full_label(), _formation_advice()],
		"tone": "neutral", "pause": true,
	})

	return steps


func _on_settings() -> void:
	SettingsPopup.show_for(self)


# Keyboard shortcuts:
#   1-5         switch main tabs (Overview / Tactics / Map / Crafting / Research)
#   C           toggle Calendar pane
#   Esc         close intro splash or info overlay
#   Enter       advance time (matches the primary action of the screen)
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# When any modal is up the underlying screen ignores hotkeys — the modal
	# owns the keys (intro splash has its own dismiss button, info overlay
	# closes on Esc below).
	if intro_panel != null and intro_panel.visible:
		if event.keycode == KEY_ESCAPE:
			_on_dismiss_intro()
			accept_event()
		return
	if info_overlay != null and info_overlay.visible:
		if event.keycode == KEY_ESCAPE:
			info_overlay.visible = false
			accept_event()
		return

	# Route through the same selector the TabBar uses so Calendar state resets
	# and the highlight stays in sync (see `_select_main_tab`).
	match event.keycode:
		KEY_1:
			_select_main_tab(TAB_OVERVIEW); accept_event()
		KEY_2:
			_select_main_tab(TAB_TACTICS); accept_event()
		KEY_3:
			_select_main_tab(TAB_MAP); accept_event()
		KEY_4:
			_select_main_tab(TAB_CRAFTING); accept_event()
		KEY_5:
			_select_main_tab(TAB_RESEARCH); accept_event()
		KEY_C:
			_on_calendar_btn(); accept_event()
		KEY_ENTER, KEY_KP_ENTER:
			if not advance_btn.disabled:
				_on_advance(); accept_event()
