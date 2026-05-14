class_name UnitCard
extends RefCounted

# Builds a PanelContainer-rooted card for one Unit. Reusable across the
# Knight chooser (Phase 3), the Roster view (Phase 3), and later the Planning
# / Pre-Battle Review screens. PA is intentionally never displayed — GDD §10.

const STAT_ABBREV: Dictionary = {
	"strength": "Str",
	"speed": "Spd",
	"technique": "Tec",
	"bravery": "Bra",
	"loyalty": "Loy",
	"determination": "Det",
	"swordsmanship": "Swd",
	"archery": "Arc",
	"horsemanship": "Hrs",
	"leadership": "Lea",
	"etiquette": "Etq",
	"intimidation": "Int",
}


static func build(
	unit: Unit,
	on_choose: Callable = Callable(),
	choose_label: String = "",
	on_name_clicked: Callable = Callable(),
) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Name is a LinkButton when a click handler is provided (opens the
	# Knight Overview screen); otherwise a plain Label.
	var name_text: String = "%s — %s" % [unit.unit_name, unit.class_label()]
	if on_name_clicked.is_valid():
		var name_btn := LinkButton.new()
		name_btn.text = name_text
		name_btn.add_theme_font_size_override("font_size", 18)
		name_btn.pressed.connect(on_name_clicked)
		vbox.add_child(name_btn)
	else:
		var name_lbl := Label.new()
		name_lbl.text = name_text
		name_lbl.add_theme_font_size_override("font_size", 18)
		vbox.add_child(name_lbl)

	var task_lbl := Label.new()
	var loc: String = "expedition #%d" % unit.expedition_id if unit.is_on_expedition() else "at home"
	task_lbl.text = "Status: %s · %s" % [unit.current_task, loc]
	task_lbl.modulate = Color(0.72, 0.72, 0.72)
	vbox.add_child(task_lbl)

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	for stat_key in Stats.STAT_KEYS:
		var stat_lbl := Label.new()
		var abbrev: String = STAT_ABBREV.get(stat_key, stat_key.substr(0, 3))
		stat_lbl.text = "%s: %d" % [abbrev, unit.stats.get_value(stat_key)]
		grid.add_child(stat_lbl)
	vbox.add_child(grid)

	var sum_lbl := Label.new()
	sum_lbl.text = "Stat total: %d" % unit.stats.sum()
	sum_lbl.modulate = Color(0.72, 0.72, 0.72)
	vbox.add_child(sum_lbl)

	if on_choose.is_valid() and choose_label != "":
		var btn := Button.new()
		btn.text = choose_label
		btn.pressed.connect(on_choose)
		vbox.add_child(btn)

	return panel
