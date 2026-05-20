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
@onready var chronicle_slot: VBoxContainer = $Margin/VBox/ColumnsScroll/Columns/LeftCol/ChronicleSlot
@onready var stats_total_lbl: Label = $Margin/VBox/ColumnsScroll/Columns/MidCol/StatsTotal
@onready var stats_blocks: VBoxContainer = $Margin/VBox/ColumnsScroll/Columns/MidCol/StatsBlocks
@onready var task_info: VBoxContainer = $Margin/VBox/ColumnsScroll/Columns/RightCol/TaskInfo
@onready var history_info: VBoxContainer = $Margin/VBox/ColumnsScroll/Columns/RightCol/HistoryScroll/HistoryInfo
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
	ScreenFade.fade_in(self)


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
	_render_equipment(unit)
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
		name_lbl.custom_minimum_size = Vector2(120, 0)
		row.add_child(name_lbl)

		var value: int = unit.stats.get_value(key)
		var value_lbl := Label.new()
		value_lbl.text = "%d" % value
		value_lbl.custom_minimum_size = Vector2(30, 0)
		value_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_lbl.modulate = Color(0.78, 0.74, 0.60)
		row.add_child(value_lbl)

		# Coloured descriptor — same band system as the cards.
		var desc_lbl := Label.new()
		desc_lbl.text = Stats.descriptor(value)
		desc_lbl.add_theme_color_override("font_color", Stats.descriptor_color(value))
		desc_lbl.custom_minimum_size = Vector2(80, 0)
		row.add_child(desc_lbl)

		var blurb := Label.new()
		blurb.text = STAT_BLURBS.get(key, "")
		blurb.modulate = Color(0.6, 0.58, 0.46)
		blurb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		blurb.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(blurb)

		vbox.add_child(row)

	return panel


# ---------- Chronicle card (origin, banner, oath) ----------

func _render_chronicle_card(unit: Unit) -> void:
	# Lazy-fill for units created before these features landed (old saves).
	if unit.house_id == "":
		unit.house_id = HousePool.random_house_id()
	if unit.body_type == "":
		unit.body_type = BodyType.random_body_type()
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

	# Heraldic header: big crest + house name + motto + body silhouette.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	var banner := BannerIcon.new()
	banner.custom_minimum_size = Vector2(132, 168)
	banner.set_show_body(true)
	banner.set_unit(unit)
	header.add_child(banner)

	var house_block := VBoxContainer.new()
	house_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	house_block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	house_block.add_theme_constant_override("separation", 4)
	header.add_child(house_block)

	var house_name_lbl := Label.new()
	house_name_lbl.text = HousePool.name_for(unit.house_id)
	house_name_lbl.add_theme_font_size_override("font_size", 20)
	house_name_lbl.modulate = Color(0.92, 0.84, 0.55)
	house_block.add_child(house_name_lbl)

	var motto_lbl := Label.new()
	motto_lbl.text = "\" %s \"" % HousePool.motto_for(unit.house_id)
	motto_lbl.add_theme_font_size_override("font_size", 14)
	motto_lbl.modulate = Color(0.78, 0.70, 0.45)
	house_block.add_child(motto_lbl)

	var body_lbl := Label.new()
	body_lbl.text = "%s — %s" % [
		BodyType.label_for(unit.body_type),
		BodyType.flavour_for(unit.body_type),
	]
	body_lbl.add_theme_font_size_override("font_size", 13)
	body_lbl.modulate = Color(0.72, 0.66, 0.48)
	body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	house_block.add_child(body_lbl)

	# Trait — name + full prose description. The chronicle card is the place
	# the player goes when they want to know "who is this knight?"; the trait
	# blurb earns its space here even when it's truncated to a glyph on
	# smaller cards.
	if unit.trait_id != "" and TraitPool.is_valid(unit.trait_id):
		var trait_name := Label.new()
		trait_name.text = "❖ %s" % TraitPool.name_for(unit.trait_id)
		trait_name.add_theme_font_size_override("font_size", 14)
		trait_name.modulate = Color(0.95, 0.78, 0.45)
		house_block.add_child(trait_name)

		var trait_desc := Label.new()
		trait_desc.text = TraitPool.description_for(unit.trait_id)
		trait_desc.add_theme_font_size_override("font_size", 12)
		trait_desc.modulate = Color(0.78, 0.72, 0.55)
		trait_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		house_block.add_child(trait_desc)

	vbox.add_child(_fleuron_divider())

	# Origin
	if unit.origin_text != "":
		var origin_lbl := Label.new()
		origin_lbl.text = unit.origin_text
		origin_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		origin_lbl.modulate = Color(0.88, 0.82, 0.68)
		vbox.add_child(origin_lbl)

	# Banner & Oath in a two-row info strip
	if unit.banner_line != "" or unit.oath != "":
		vbox.add_child(_fleuron_divider())

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

	# Chronicle card now lives in its own left column.
	for c in chronicle_slot.get_children():
		c.queue_free()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chronicle_slot.add_child(panel)


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


# ---------- equipment ----------
#
# Sits in the RightCol below "Current Status". Each slot (weapon / armour)
# shows the current item with rarity-tinted name + stat-line + flavour, plus
# a Change… button that opens a popup of stockpile alternatives. Equipping
# from the stockpile swaps — the old item returns to stockpile so nothing is
# lost.

func _render_equipment(unit: Unit) -> void:
	for c in task_info.get_children():
		if c.has_meta("_eq_block"):
			c.queue_free()

	var header := Label.new()
	header.text = "❦  Equipment"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.92, 0.78, 0.42))
	header.set_meta("_eq_block", true)
	task_info.add_child(header)

	_render_equipment_row(unit, "weapon", unit.weapon_id)
	_render_equipment_row(unit, "armour", unit.armour_id)


func _render_equipment_row(unit: Unit, slot: String, item_id: String) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.set_meta("_eq_block", true)
	task_info.add_child(row)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	row.add_child(name_row)

	var slot_lbl := Label.new()
	slot_lbl.text = "%s:" % slot.capitalize()
	slot_lbl.custom_minimum_size = Vector2(60, 0)
	slot_lbl.modulate = Color(0.72, 0.62, 0.40)
	name_row.add_child(slot_lbl)

	var name_lbl := Label.new()
	var display: String = (
		Weapon.display_name(item_id) if slot == "weapon" else Armour.display_name(item_id)
	)
	var rarity_lbl: String = (
		Weapon.rarity_label(item_id) if slot == "weapon" else Armour.rarity_label(item_id)
	)
	var rarity_col: Color = (
		Weapon.rarity_color(item_id) if slot == "weapon" else Armour.rarity_color(item_id)
	)
	name_lbl.text = "%s (%s)" % [display, rarity_lbl]
	name_lbl.add_theme_color_override("font_color", rarity_col)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(name_lbl)

	var change_btn := Button.new()
	change_btn.text = "Change…"
	var available: int = _stockpile_count_for_slot(slot)
	if available == 0:
		change_btn.disabled = true
		change_btn.tooltip_text = "Armoury empty — win battles to pick up spare kit."
	else:
		change_btn.tooltip_text = "%d spare %s in the armoury" % [available, slot]
	change_btn.pressed.connect(_open_equip_popup.bind(unit, slot, change_btn))
	name_row.add_child(change_btn)

	# Stat summary line — concise, dimmer than the name.
	var detail_lbl := Label.new()
	detail_lbl.text = (
		Weapon.describe(item_id) if slot == "weapon" else Armour.describe(item_id)
	)
	detail_lbl.modulate = Color(0.78, 0.74, 0.60)
	detail_lbl.add_theme_font_size_override("font_size", 12)
	detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	row.add_child(detail_lbl)

	# Flavour blurb — italicised feel via colour, kept under name for tone.
	var flavour_text: String = (
		Weapon.flavour(item_id) if slot == "weapon" else Armour.flavour(item_id)
	)
	if flavour_text != "":
		var flavour_lbl := Label.new()
		flavour_lbl.text = "\"%s\"" % flavour_text
		flavour_lbl.modulate = Color(0.62, 0.56, 0.42)
		flavour_lbl.add_theme_font_size_override("font_size", 11)
		flavour_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(flavour_lbl)


func _stockpile_count_for_slot(slot: String) -> int:
	var n: int = 0
	for entry in GameState.item_stockpile:
		if str(entry.get("slot", "")) == slot:
			n += 1
	return n


func _open_equip_popup(unit: Unit, slot: String, anchor: Button) -> void:
	var popup := PopupMenu.new()
	popup.add_item("Available %s in the armoury" % slot.capitalize(), -1)
	popup.set_item_disabled(0, true)
	popup.add_separator()
	# Map: popup item id → stockpile index. Item ids run from 0 to size-1.
	var pairs: Array = []   # Array of [stockpile_index, label]
	for i in range(GameState.item_stockpile.size()):
		var entry: Dictionary = GameState.item_stockpile[i]
		if str(entry.get("slot", "")) != slot:
			continue
		var id: String = str(entry.get("id", ""))
		var label: String = (
			"%s — %s" % [Weapon.display_name(id), Weapon.rarity_label(id)]
			if slot == "weapon"
			else "%s — %s" % [Armour.display_name(id), Armour.rarity_label(id)]
		)
		pairs.append([i, label])
	for j in range(pairs.size()):
		popup.add_item(pairs[j][1], j)
	popup.id_pressed.connect(_on_equip_picked.bind(unit, pairs, popup))
	popup.close_requested.connect(func(): popup.queue_free())
	add_child(popup)
	var p: Vector2 = anchor.get_screen_position() + Vector2(0, anchor.size.y)
	popup.position = Vector2i(p)
	popup.popup()


func _on_equip_picked(picked: int, unit: Unit, pairs: Array, popup: PopupMenu) -> void:
	if picked >= 0 and picked < pairs.size():
		var stockpile_index: int = int(pairs[picked][0])
		if ItemDrops.equip_from_stockpile(GameState, unit, stockpile_index):
			MasterAudio.play_click()
			_render(unit)
	popup.queue_free()


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


# Same fleuron divider used on the chooser cards — centred glyph + faint rules.
func _fleuron_divider() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var left := HSeparator.new()
	left.modulate = Color(0.55, 0.45, 0.25, 0.45)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)

	var glyph := Label.new()
	glyph.text = "❦"
	glyph.modulate = Color(0.78, 0.62, 0.30)
	glyph.add_theme_font_size_override("font_size", 14)
	row.add_child(glyph)

	var right := HSeparator.new()
	right.modulate = Color(0.55, 0.45, 0.25, 0.45)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)

	return row


func _add_info_line(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	parent.add_child(lbl)


# ---------- nav ----------

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/screens/planning.tscn")


func _on_settings() -> void:
	SettingsPopup.show_for(self)


# Esc → back to Planning, matching the visible Back button.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		_on_back()
		accept_event()
