extends Control

# Planning screen per GDD §5. The player:
#   • Sees this week's rolled event (top banner).
#   • Assigns Defend / Train [stat] to each at-home unit.
#   • Picks a tile on the map, tags units as "send next expedition", and
#     launches Explore (Unknown tile) or Gather (Explored resource tile).
#   • On Away-Battle weeks, picks Pillage or Assault Castle and a party.
#   • Hits Advance Time, which commits tasks and runs the Tick (training,
#     expedition returns, Determination). The Pre-Battle Review screen
#     takes over from there.
#
# Validation lives in the launch_* helpers — buttons are enabled / disabled
# based on whether the action is currently legal.

@onready var header_lbl: Label = $Margin/VBox/Header
@onready var resources_lbl: Label = $Margin/VBox/Resources
@onready var unit_list: VBoxContainer = $Margin/VBox/MainRow/LeftPane/UnitScroll/UnitList
@onready var away_section: VBoxContainer = $Margin/VBox/MainRow/LeftPane/AwaySection
@onready var map_holder: PanelContainer = $Margin/VBox/MainRow/RightPane/MapHolder
@onready var selection_lbl: Label = $Margin/VBox/MainRow/RightPane/SelectionInfo
@onready var explore_btn: Button = $Margin/VBox/MainRow/RightPane/Actions/ExploreBtn
@onready var gather_btn: Button = $Margin/VBox/MainRow/RightPane/Actions/GatherBtn
@onready var expedition_list: VBoxContainer = $Margin/VBox/MainRow/RightPane/ExpeditionList
@onready var advance_btn: Button = $Margin/VBox/Bottom/AdvanceBtn
@onready var status_lbl: Label = $Margin/VBox/Bottom/StatusLabel

var _map: WorldMapView = null
var _selected: Vector2i = Vector2i(-1, -1)

# Pending plan, committed when Advance Time is pressed.
var _pending_tasks: Dictionary = {}             # unit_id -> task string ("defend" or "train:<stat>")
var _expedition_party: Array[int] = []          # unit ids selected for the next launch


func _ready() -> void:
	if not GameState.has_active_run():
		print("[Planning] No active run — bouncing to Title.")
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return

	if GameState.current_event < 0:
		GameState.roll_current_event()

	_map = WorldMapView.new()
	_map.tile_clicked.connect(_on_tile_clicked)
	map_holder.add_child(_map)

	explore_btn.pressed.connect(_on_explore)
	gather_btn.pressed.connect(_on_gather)
	advance_btn.pressed.connect(_on_advance)

	_default_pending_tasks()
	_refresh_all()


# Default each at-home unit to Defend so the plan is always valid.
func _default_pending_tasks() -> void:
	for u in GameState.roster:
		if u.is_on_expedition():
			continue
		if not _pending_tasks.has(u.id):
			_pending_tasks[u.id] = Unit.TASK_DEFEND


func _refresh_all() -> void:
	_refresh_header()
	_refresh_unit_list()
	_refresh_away_section()
	_refresh_map()
	_refresh_selection()
	_refresh_expeditions()
	_refresh_action_buttons()


func _refresh_header() -> void:
	var event_label: String = EventKind.label(GameState.current_event)
	if GameState.current_event == EventKind.BATTLE_EVENT and GameState.current_battle_event != "":
		event_label = "%s — %s" % [event_label, BattleEvent.label(GameState.current_battle_event)]
	header_lbl.text = "Year %d, Week %d (week %d / 48) — %s" % [
		GameState.current_year(),
		GameState.week,
		GameState.current_week_of_year(),
		event_label,
	]
	resources_lbl.text = "Stores — %s" % GameState.resources.describe()
	status_lbl.text = ""


func _refresh_map() -> void:
	_map.render(GameState.world, _selected)


func _refresh_selection() -> void:
	if _selected.x < 0:
		selection_lbl.text = "Click a tile on the map to select it."
		return
	var tile: MapTile = GameState.world.get_tile(_selected.x, _selected.y)
	var bits: PackedStringArray = PackedStringArray()
	bits.append("Tile (%d,%d):" % [tile.x, tile.y])
	if tile.knowledge == MapTile.Knowledge.EXPLORED:
		bits.append("  Terrain: %s" % MapTile.Terrain.keys()[tile.terrain])
		var res: String = tile.gather_resource()
		bits.append("  Yield: %s" % (res if res != "" else "—"))
		if tile.castle != null:
			bits.append("  Castle: difficulty %d, reward %s" % [
				tile.castle.difficulty, tile.castle.reward.describe(),
			])
	else:
		bits.append("  Knowledge: Unknown — Explore to reveal")
	if tile.active_expedition != null:
		bits.append("  Active: %s" % tile.active_expedition.describe())
	selection_lbl.text = "\n".join(bits)


# ---------- unit assignment ----------

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

	var name_lbl := Label.new()
	name_lbl.text = "%s — %s" % [u.unit_name, u.class_label()]
	vbox.add_child(name_lbl)

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
		pass   # Phase 7 hooks tournament participation here
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


# ---------- away-week options ----------

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


# ---------- map + expedition launch ----------

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
	# MVP: gather only directly from tiles whose own terrain yields a resource.
	# Mountain copper-from-adjacent rule (GDD §4) is deferred to future work.
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
	# Drop launched units from any pending task assignments or away-party
	# selections — they're no longer at home.
	for uid in party:
		_pending_tasks.erase(uid)
		GameState.pending_away_party.erase(uid)
	_refresh_unit_list()
	_refresh_away_section()
	_refresh_map()
	_refresh_selection()
	_refresh_expeditions()
	_refresh_action_buttons()


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


# ---------- expedition lookup ----------

func _find_expedition_for(unit: Unit) -> Expedition:
	for exp in GameState.expeditions:
		if exp.id == unit.expedition_id:
			return exp
	return null


# ---------- advance time ----------

# Commit pending tasks to at-home units, run the Tick (training, expedition
# returns, Determination), and hand off to the Pre-Battle Review screen.
# Resolution / Battle Log / Weekly Summary handle the rest of the week.
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
