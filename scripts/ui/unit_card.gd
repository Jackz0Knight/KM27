class_name UnitCard
extends RefCounted

# Builds a PanelContainer-rooted card for one Unit. Reusable across the
# Knight chooser (Phase 3), the Roster view (Phase 3), and later the Planning
# / Pre-Battle Review screens. PA is intentionally never displayed — GDD §10.

const STAT_ABBREV: Dictionary = {
	"strength":     "Str",
	"speed":        "Spd",
	"technique":    "Tec",
	"bravery":      "Bra",
	"loyalty":      "Loy",
	"determination":"Det",
	"swordsmanship":"Swd",
	"archery":      "Arc",
	"horsemanship": "Hrs",
	"leadership":   "Lea",
	"etiquette":    "Etq",
	"intimidation": "Int",
}

const STAT_TOOLTIPS: Dictionary = {
	"strength":      "Strength — raw power; used in formation combat and expedition yield",
	"speed":         "Speed — affects flanking, ranged approach, and Light Melee (Red slot)",
	"technique":     "Technique — improves training efficiency and tournament performance",
	"bravery":       "Bravery — contributes to formation combat power",
	"loyalty":       "Loyalty — resilience against morale events; underpins Determination",
	"determination": "Determination — chance of a bonus +1 to a random stat each training week",
	"swordsmanship": "Swordsmanship — primary skill for Heavy Melee (Yellow) and Light Melee (Red) slots",
	"archery":       "Archery — primary skill for the Ranged (Green) slot",
	"horsemanship":  "Horsemanship — boosts mounted scouting and expedition efficiency",
	"leadership":    "Leadership — enables Camp Leader (Blue) slot, granting +1 power to all other fighters",
	"etiquette":     "Etiquette — increases tournament reward quality",
	"intimidation":  "Intimidation — reduces effective enemy power in formation combat",
}


# show_chronicle: when true, render the unit's origin paragraph and oath below
# the stats (used on the Knight Chooser so recruitment feels like hiring a person).
static func build(
	unit: Unit,
	on_choose: Callable = Callable(),
	choose_label: String = "",
	on_name_clicked: Callable = Callable(),
	show_chronicle: bool = false,
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

	# Name — include earned epithet when set.
	var display_name: String = unit.unit_name
	if unit.epithet != "":
		display_name += ", %s" % unit.epithet
	var name_text: String = "%s — %s" % [display_name, unit.class_label()]
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

	# Injury indicator.
	if unit.is_injured():
		var inj_lbl := Label.new()
		var inj_stats: Array[String] = unit.injured_stats()
		inj_lbl.text = "⚠ Injured: %s" % ", ".join(inj_stats.map(func(s: String) -> String: return s.capitalize()))
		inj_lbl.modulate = Color(0.95, 0.55, 0.25)
		vbox.add_child(inj_lbl)

	var injured_set: Array[String] = unit.injured_stats()

	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 2)
	for stat_key in Stats.STAT_KEYS:
		var stat_lbl := Label.new()
		var abbrev: String = STAT_ABBREV.get(stat_key, stat_key.substr(0, 3))
		stat_lbl.text = "%s: %d" % [abbrev, unit.stats.get_value(stat_key)]
		stat_lbl.tooltip_text = STAT_TOOLTIPS.get(stat_key, stat_key.capitalize())
		if injured_set.has(stat_key):
			stat_lbl.modulate = Color(0.95, 0.45, 0.30)
		grid.add_child(stat_lbl)
	vbox.add_child(grid)

	var sum_lbl := Label.new()
	sum_lbl.text = "Stat total: %d" % unit.stats.sum()
	sum_lbl.modulate = Color(0.72, 0.72, 0.72)
	vbox.add_child(sum_lbl)

	# Heraldic banner — one subtle line on every card when the unit has one.
	var banner: String = unit.banner_line
	if banner == "":
		banner = Chronicle.generate_banner(unit)
	if banner != "":
		var banner_lbl := Label.new()
		banner_lbl.text = banner
		banner_lbl.modulate = Color(0.60, 0.54, 0.36)
		banner_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(banner_lbl)

	# Chronicle section — origin paragraph + oath, shown when requested.
	if show_chronicle:
		var origin: String = unit.origin_text
		if origin == "":
			origin = Chronicle.generate_origin(unit)
		var oath: String = unit.oath
		if oath == "":
			oath = Chronicle.generate_oath(unit)

		if origin != "" or oath != "":
			var sep := HSeparator.new()
			sep.modulate = Color(0.5, 0.42, 0.25, 0.4)
			vbox.add_child(sep)

		if origin != "":
			var origin_lbl := Label.new()
			origin_lbl.text = origin
			origin_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			origin_lbl.modulate = Color(0.82, 0.76, 0.60)
			vbox.add_child(origin_lbl)

		if oath != "":
			var oath_lbl := Label.new()
			oath_lbl.text = "\" %s \"" % oath
			oath_lbl.modulate = Color(0.80, 0.70, 0.40)
			oath_lbl.add_theme_font_size_override("font_size", 13)
			oath_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
			vbox.add_child(oath_lbl)

	if on_choose.is_valid() and choose_label != "":
		var btn := Button.new()
		btn.text = choose_label
		btn.pressed.connect(on_choose)
		vbox.add_child(btn)

	return panel
