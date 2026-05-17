extends Control

# Focused detail view for one Unit. Reached by clicking the unit's name on
# any roster card (Planning's Overview tab, Town & Map task list). Routing
# is via `GameState.focused_unit_id`. Back returns to Planning.
#
# Lays the 12 visible stats out in the four GDD §10 groupings — Physical,
# Mental, Technical, Social — instead of the flat 4×3 grid the small cards
# use, so the player has more context than the planning UI can show. PA
# stays hidden per GDD §10.

const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")

const STAT_GROUPS: Array = [
	{
		"label": "Physical",
		"stats": ["strength", "speed", "technique"],
	},
	{
		"label": "Mental",
		"stats": ["bravery", "loyalty", "determination"],
	},
	{
		"label": "Technical",
		"stats": ["swordsmanship", "archery", "horsemanship"],
	},
	{
		"label": "Social",
		"stats": ["leadership", "etiquette", "intimidation"],
	},
]

const STAT_BLURBS: Dictionary = {
	"strength": "melee power + gather yield",
	"speed": "dodge contribution",
	"technique": "ranged power + crit",
	"bravery": "combat contribution + Home Battle resilience",
	"loyalty": "reserved for future morale",
	"determination": "weekly +1 roll + training bonus chance",
	"swordsmanship": "Yellow/Red slot bonus + duel power",
	"archery": "Green slot bonus + ranged power",
	"horsemanship": "reserved for mounted combat",
	"leadership": "Blue-slot buffs the rest of the formation by +1",
	"etiquette": "scales Tournament rewards",
	"intimidation": "reduces enemy total by Σ(Int/4)",
}

@onready var header_lbl: Label = $Margin/VBox/Header
@onready var sub_header_lbl: Label = $Margin/VBox/SubHeader
@onready var stats_total_lbl: Label = $Margin/VBox/Scroll/Body/StatsTotal
@onready var stats_blocks: VBoxContainer = $Margin/VBox/Scroll/Body/StatsBlocks
@onready var task_info: VBoxContainer = $Margin/VBox/Scroll/Body/TaskInfo
@onready var history_info: VBoxContainer = $Margin/VBox/Scroll/Body/HistoryInfo
@onready var overview_body: VBoxContainer = $Margin/VBox/Scroll/Body
@onready var back_btn: Button = $Margin/VBox/TopBar/BackBtn
@onready var settings_btn: Button = $Margin/VBox/TopBar/SettingsBtn


func _ready() -> void:
	if not GameState.has_active_run():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return
	var unit: Unit = GameState.find_unit(GameState.focused_unit_id)
	if unit == null:
		print("[KnightOverview] No focused unit — back to Planning.")
		get_tree().change_scene_to_file("res://scenes/screens/planning.tscn")
		return

	back_btn.pressed.connect(_on_back)
	settings_btn.pressed.connect(_on_settings)

	_render(unit)


func _render(unit: Unit) -> void:
	var name_parts: String = "%s %s" % [_honorific(unit), unit.unit_name]
	if unit.epithet != "":
		name_parts += ", %s" % unit.epithet
	header_lbl.text = name_parts
	sub_header_lbl.text = "%s · %s" % [unit.class_label(), _status_line(unit)]
	stats_total_lbl.text = "Stat total: %d" % unit.stats.sum()
	_render_stats(unit)
	_render_chronicle_card(unit)
	_render_task(unit)
	_render_history(unit)


func _honorific(unit: Unit) -> String:
	return "Sir" if unit.unit_class == Unit.UnitClass.KNIGHT else "Squire"


func _status_line(unit: Unit) -> String:
	if unit.is_on_expedition():
		var exp: Expedition = _find_expedition_for(unit)
		if exp != null:
			return "On expedition #%d (%s, %dw remaining)" % [
				exp.id, exp.kind_label(), exp.weeks_remaining,
			]
		return "On expedition"
	if unit.is_training():
		return "Training %s" % unit.training_target().capitalize()
	if unit.current_task == Unit.TASK_DEFEND:
		return "Defending the homestead"
	return "Idle"


func _find_expedition_for(unit: Unit) -> Expedition:
	for exped in GameState.expeditions:
		if exped.id == unit.expedition_id:
			return exped
	return null


# ---------- stats blocks ----------

func _render_stats(unit: Unit) -> void:
	for c in stats_blocks.get_children():
		c.queue_free()
	for group in STAT_GROUPS:
		stats_blocks.add_child(_build_stat_group(unit, group["label"], group["stats"]))


func _build_stat_group(unit: Unit, group_label: String, stat_keys: Array) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var label := Label.new()
	label.text = group_label
	label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(label)

	for key in stat_keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)

		var name_lbl := Label.new()
		name_lbl.text = String(key).capitalize()
		name_lbl.custom_minimum_size = Vector2(160, 0)
		row.add_child(name_lbl)

		var value_lbl := Label.new()
		value_lbl.text = "%d / 20" % unit.stats.get_value(key)
		value_lbl.custom_minimum_size = Vector2(70, 0)
		row.add_child(value_lbl)

		var blurb := Label.new()
		blurb.text = STAT_BLURBS.get(key, "")
		blurb.modulate = Color(0.7, 0.7, 0.7)
		blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(blurb)

		vbox.add_child(row)

	return panel


# ---------- Chronicle card (origin, banner, oath) ----------

func _render_chronicle_card(unit: Unit) -> void:
	# Lazy-generate fields for units created before this feature (old saves).
	if unit.banner_line == "":
		unit.banner_line = Chronicle.generate_banner(unit)
	if unit.origin_text == "":
		unit.origin_text = Chronicle.generate_origin(unit)
	if unit.oath == "":
		unit.oath = Chronicle.generate_oath(unit)

	# Insert a bordered amber card between stats and task info.
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	# Origin
	if unit.origin_text != "":
		var origin_lbl := Label.new()
		origin_lbl.text = unit.origin_text
		origin_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		origin_lbl.modulate = Color(0.88, 0.82, 0.68)
		vbox.add_child(origin_lbl)

	# Banner & Oath in a two-row info strip
	if unit.banner_line != "" or unit.oath != "":
		var sep := HSeparator.new()
		sep.modulate = Color(0.5, 0.42, 0.25, 0.5)
		vbox.add_child(sep)

	if unit.banner_line != "":
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var label_lbl := Label.new()
		label_lbl.text = "Arms:"
		label_lbl.modulate = Color(0.72, 0.62, 0.40)
		label_lbl.custom_minimum_size = Vector2(56, 0)
		hbox.add_child(label_lbl)
		var val_lbl := Label.new()
		val_lbl.text = unit.banner_line
		val_lbl.modulate = Color(0.78, 0.72, 0.55)
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		hbox.add_child(val_lbl)
		vbox.add_child(hbox)

	if unit.oath != "":
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 8)
		var label_lbl := Label.new()
		label_lbl.text = "Oath:"
		label_lbl.modulate = Color(0.72, 0.62, 0.40)
		label_lbl.custom_minimum_size = Vector2(56, 0)
		hbox.add_child(label_lbl)
		var val_lbl := Label.new()
		val_lbl.text = "\" %s \"" % unit.oath
		val_lbl.modulate = Color(0.82, 0.78, 0.60)
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		hbox.add_child(val_lbl)
		vbox.add_child(hbox)

	# Insert after stats_blocks (before task_info) by getting its index.
	var insert_idx: int = stats_blocks.get_index() + 1
	overview_body.add_child(panel)
	overview_body.move_child(panel, insert_idx)


# ---------- task info ----------

func _render_task(unit: Unit) -> void:
	for c in task_info.get_children():
		c.queue_free()
	_add_info_line(task_info, "Class: %s" % unit.class_label())
	_add_info_line(task_info, "Status: %s" % _status_line(unit))
	if unit.is_on_expedition():
		var exp: Expedition = _find_expedition_for(unit)
		if exp != null:
			_add_info_line(task_info, "  Target: (%d,%d)" % [exp.target_x, exp.target_y])
			_add_info_line(task_info, "  Party size: %d unit(s)" % exp.unit_ids.size())


# ---------- per-unit history ----------

# Scan the run-history log for entries that involved this unit. The log
# doesn't yet track unit participation explicitly; for MVP we surface the
# top-line outcomes so the player has a rough trace.
func _render_history(unit: Unit) -> void:
	for c in history_info.get_children():
		c.queue_free()
	if GameState.run_history.is_empty():
		_add_info_line(history_info, "Nothing recorded yet.")
		return
	var entries: Array = GameState.run_history.duplicate()
	entries.reverse()
	var shown: int = 0
	for entry in entries:
		var line := "W%d (%s) — %s" % [entry["week"], entry["event_label"], entry["outcome"]]
		_add_info_line(history_info, line)
		shown += 1
		if shown >= 12:
			break


func _add_info_line(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	parent.add_child(lbl)


# ---------- nav ----------

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/planning.tscn")


func _on_settings() -> void:
	SettingsPopup.show_for(self)
