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


# Subtle hover lift — used by every UnitCard. Pure modulate tween so layout
# never shifts; the scale-pop reads as "this card is active" without elbowing
# its neighbours in the row.
const HOVER_BRIGHT: Color = Color(1.08, 1.06, 1.02, 1.0)
const HOVER_DURATION: float = 0.12


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
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Two short tweens — brighten on hover, snap back on exit. We stash them
	# as metadata so a fast mouse-over-and-off doesn't leave a dangling tween.
	panel.mouse_entered.connect(_on_card_hover.bind(panel, true))
	panel.mouse_exited.connect(_on_card_hover.bind(panel, false))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	# Header row: small crest (with body silhouette) + name block.
	# Chooser cards (show_chronicle=true) use a larger banner; regular cards
	# get a compact 28×36 chip that still reads at-a-glance.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	vbox.add_child(header_row)

	if unit.house_id != "":
		var banner_icon := BannerIcon.new()
		if show_chronicle:
			banner_icon.custom_minimum_size = Vector2(72, 92)
		else:
			banner_icon.custom_minimum_size = Vector2(44, 56)
		banner_icon.set_show_body(true)
		banner_icon.set_unit(unit)
		var banner_wrap := VBoxContainer.new()
		banner_wrap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		banner_wrap.add_child(banner_icon)
		header_row.add_child(banner_wrap)

	var name_block := VBoxContainer.new()
	name_block.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_block.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_block.add_theme_constant_override("separation", 2)
	header_row.add_child(name_block)

	# Chooser button is rendered on its own row right under the header so it
	# stays visible without scrolling past the chronicle, while not bloating
	# the header row's min-width (which would push the 3-across HBox past the
	# viewport — see commit history for the chooser overflow fix).
	if on_choose.is_valid() and choose_label != "":
		var choose_btn := Button.new()
		choose_btn.text = choose_label
		choose_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choose_btn.pressed.connect(on_choose)
		vbox.add_child(choose_btn)

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
		name_block.add_child(name_btn)
	else:
		var name_lbl := Label.new()
		name_lbl.text = name_text
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_block.add_child(name_lbl)

	# House + body line (implicit lean — motto only, no stat tags per design).
	if unit.house_id != "":
		var house_lbl := Label.new()
		var motto: String = HousePool.motto_for(unit.house_id)
		var body_label: String = BodyType.label_for(unit.body_type)
		var house_name: String = HousePool.name_for(unit.house_id)
		if motto != "" and body_label != "":
			house_lbl.text = "%s · %s · \"%s\"" % [house_name, body_label, motto]
		elif motto != "":
			house_lbl.text = "%s · \"%s\"" % [house_name, motto]
		else:
			house_lbl.text = house_name
		house_lbl.modulate = Color(0.70, 0.62, 0.40)
		house_lbl.add_theme_font_size_override("font_size", 12)
		name_block.add_child(house_lbl)

	# Personal trait — one short label below the house line so the eye reads
	# "house · body · motto" then "trait." Trait tooltip carries the prose
	# blurb so chooser players can see the personality before committing.
	if unit.trait_id != "" and TraitPool.is_valid(unit.trait_id):
		var trait_lbl := Label.new()
		trait_lbl.text = "❖ %s" % TraitPool.name_for(unit.trait_id)
		trait_lbl.modulate = Color(0.85, 0.72, 0.45)
		trait_lbl.add_theme_font_size_override("font_size", 12)
		trait_lbl.tooltip_text = TraitPool.description_for(unit.trait_id)
		name_block.add_child(trait_lbl)

	var task_lbl := Label.new()
	task_lbl.text = _status_line_for(unit)
	task_lbl.modulate = Color(0.78, 0.74, 0.62)
	vbox.add_child(task_lbl)

	# Equipment line — compact, rarity-tinted. Uses RichTextLabel so weapon
	# and armour can carry distinct colours without two stacked labels.
	# Heirlooms read gold; rares blue; uncommons green; commons parchment.
	if unit.weapon_id != "" or unit.armour_id != "":
		var eq_rtl := RichTextLabel.new()
		eq_rtl.bbcode_enabled = true
		eq_rtl.fit_content = true
		eq_rtl.scroll_active = false
		eq_rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		eq_rtl.parse_bbcode(_equipment_bbcode(unit))
		eq_rtl.tooltip_text = "%s\n%s" % [Weapon.describe(unit.weapon_id), Armour.describe(unit.armour_id)]
		vbox.add_child(eq_rtl)

	# Injury indicator.
	if unit.is_injured():
		var inj_lbl := Label.new()
		var inj_stats: Array[String] = unit.injured_stats()
		inj_lbl.text = "⚠ Injured: %s" % ", ".join(inj_stats.map(func(s: String) -> String: return s.capitalize()))
		inj_lbl.modulate = Color(0.95, 0.55, 0.25)
		vbox.add_child(inj_lbl)

	var injured_set: Array[String] = unit.injured_stats()

	# Stats grid uses DESCRIPTORS (Wretched/Poor/Decent/Good/...) instead of
	# numbers — cards are the "at a glance" surface. The full numeric value
	# is in the tooltip for players who need to verify. Knight Overview
	# (the detail screen) keeps the numbers visible.
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 2)
	for stat_key in Stats.STAT_KEYS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		# Tightened from 110 → 96 (still fits "Determination" / "Swordsmanship")
		# so three cards-across fit within the 1280-wide viewport on the chooser.
		var name_lbl := Label.new()
		name_lbl.text = "%s" % String(stat_key).capitalize()
		name_lbl.custom_minimum_size = Vector2(96, 0)
		name_lbl.modulate = Color(0.72, 0.70, 0.58)
		row.add_child(name_lbl)

		var value: int = unit.stats.get_value(stat_key)
		var desc_lbl := Label.new()
		desc_lbl.text = Stats.descriptor(value)
		desc_lbl.add_theme_color_override("font_color", Stats.descriptor_color(value))
		if injured_set.has(stat_key):
			desc_lbl.text = "%s (hurt)" % Stats.descriptor(value)
			desc_lbl.add_theme_color_override("font_color", Color(0.95, 0.45, 0.30))
		row.add_child(desc_lbl)

		# FM-style development arrow — show-not-tell. Small ▲ while a stat is
		# quietly developing, bright ▲ the weeks after it gains a point, ▼ while
		# an injury suppresses it. No numbers — the arrow is the whole message.
		var dev_state: int = unit.stats.development_state(stat_key, unit.potential_ability, injured_set.has(stat_key))
		if dev_state != Stats.DEV_NONE:
			var arrow := Label.new()
			arrow.text = Stats.development_glyph(dev_state)
			arrow.add_theme_color_override("font_color", Stats.development_color(dev_state))
			arrow.add_theme_font_size_override("font_size", 14 if dev_state == Stats.DEV_SURGING else 10)
			arrow.tooltip_text = Stats.development_tooltip(dev_state)
			row.add_child(arrow)

		# Tooltip on the whole row gives the numeric value + the gameplay blurb.
		var tip: String = "%s — value: %d / 20\n%s" % [
			String(stat_key).capitalize(),
			value,
			STAT_TOOLTIPS.get(stat_key, ""),
		]
		name_lbl.tooltip_text = tip
		desc_lbl.tooltip_text = tip

		grid.add_child(row)
	vbox.add_child(grid)

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
			vbox.add_child(_fleuron_divider())

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

	# (Choose button is now rendered in the header row so it stays visible
	# without scrolling past the chronicle.)

	return panel


# Hover lift handler. Cancels any prior tween on the panel so toggling on/off
# quickly never leaves the card stuck at a half-brightened modulate.
static func _on_card_hover(panel: Control, entered: bool) -> void:
	if not is_instance_valid(panel):
		return
	var prior: Tween = panel.get_meta("_hover_tween") if panel.has_meta("_hover_tween") else null
	if prior != null and prior.is_valid():
		prior.kill()
	var tween: Tween = panel.create_tween()
	var target: Color = HOVER_BRIGHT if entered else Color(1, 1, 1, 1)
	tween.tween_property(panel, "modulate", target, HOVER_DURATION)
	panel.set_meta("_hover_tween", tween)


# Compact equipment readout. "⚔ Longsword · 🛡 Leather Armour", each side
# tinted by its rarity colour. The glyph prefix reads at a glance, the prose
# carries the name. Empty when both ids are blank (won't render).
static func _equipment_bbcode(unit: Unit) -> String:
	var parts: Array[String] = []
	if unit.weapon_id != "":
		var wc: Color = Weapon.rarity_color(unit.weapon_id)
		parts.append("[color=#%s]⚔ %s%s[/color]" % [
			wc.to_html(false), Weapon.display_name(unit.weapon_id), Quality.suffix(unit.weapon_bracket)])
	if unit.armour_id != "":
		var ac: Color = Armour.rarity_color(unit.armour_id)
		parts.append("[color=#%s]🛡 %s%s[/color]" % [
			ac.to_html(false), Armour.display_name(unit.armour_id), Quality.suffix(unit.armour_bracket)])
	return "  ·  ".join(parts)


# A centred heraldic fleuron flanked by faint rules — used between the stats
# grid and the chronicle prose on chooser cards. Looks like a manuscript
# section break, not a generic horizontal line.
static func _fleuron_divider() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var left_rule := HSeparator.new()
	left_rule.modulate = Color(0.55, 0.45, 0.25, 0.45)
	left_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left_rule)

	var glyph := Label.new()
	glyph.text = "❦"
	glyph.modulate = Color(0.78, 0.62, 0.30)
	glyph.add_theme_font_size_override("font_size", 14)
	row.add_child(glyph)

	var right_rule := HSeparator.new()
	right_rule.modulate = Color(0.55, 0.45, 0.25, 0.45)
	right_rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right_rule)

	return row


# Status line with a small glyph prefix. The glyph reads at a glance — the
# text behind it carries the precise state for players who need it.
static func _status_line_for(unit: Unit) -> String:
	if unit.is_injured():
		# Injury takes priority over task because it visually affects stats too.
		return "✚  Recovering — at the surgeon"
	if unit.is_on_expedition():
		return "⚑  Abroad — expedition #%d" % unit.expedition_id
	if unit.is_training():
		var stat: String = unit.training_target().capitalize()
		return "✦  Training %s" % stat
	if unit.current_task == Unit.TASK_DEFEND:
		return "⛨  Defending the homestead"
	return "○  Idle — at home"
