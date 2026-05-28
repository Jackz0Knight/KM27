extends Control

# Phase 6/7 Weekly Summary per GDD §5. Events reveal sequentially with
# short fade-in delays, grouped: Training → Expeditions → Battle → Resources → Gold.

@onready var header_lbl: Label = $Margin/VBox/Header
@onready var resources_lbl: RichTextLabel = $Margin/VBox/Resources
@onready var summary_body: VBoxContainer = $Margin/VBox/Scroll/Body
@onready var outcome_lbl: Label = $Margin/VBox/Scroll/Body/EventOutcome
@onready var battle_breakdown_header: Label = $Margin/VBox/Scroll/Body/BattleBreakdownHeader
@onready var battle_breakdown: VBoxContainer = $Margin/VBox/Scroll/Body/BattleBreakdown
@onready var rewards_list: VBoxContainer = $Margin/VBox/Scroll/Body/Rewards
@onready var caravan_pane: VBoxContainer = $Margin/VBox/Scroll/Body/CaravanPicker
@onready var deltas_list: VBoxContainer = $Margin/VBox/Scroll/Body/Deltas
@onready var returns_list: VBoxContainer = $Margin/VBox/Scroll/Body/Returns
@onready var streak_lbl: Label = $Margin/VBox/Scroll/Body/StreakLine
@onready var status_lbl: Label = $Margin/VBox/Bottom/StatusLabel
@onready var next_btn: Button = $Margin/VBox/Bottom/NextBtn
@onready var settings_btn: Button = $Margin/VBox/Bottom/SettingsBtn

const SettingsPopup = preload("res://scripts/ui/settings_popup.gd")

# Sections that animate in one by one.
var _anim_sections: Array[Control] = []
var _anim_timer: float = 0.0
var _anim_idx: int = 0
var _anim_done: bool = false
const SECTION_DELAY: float = 0.4


func _ready() -> void:
	if not GameState.has_active_run():
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return

	next_btn.pressed.connect(_on_next)
	settings_btn.pressed.connect(_on_settings)

	# Render content into the nodes first (hidden).
	_render_content()

	# Chronicle panel is the first child after render_content() inserts it.
	var chronicle_panel: Control = summary_body.get_child(0) if summary_body.get_child_count() > 0 else null

	# Collect the sections we'll animate in — Chronicle first, then ledger data.
	_anim_sections = []
	if chronicle_panel != null and chronicle_panel.name == "ChroniclePanel":
		_anim_sections.append(chronicle_panel)
	_anim_sections.append_array([
		outcome_lbl,
		battle_breakdown,
		rewards_list,
		deltas_list,
		returns_list,
		caravan_pane,
		streak_lbl,
	])

	# Hide all sections initially.
	for sec in _anim_sections:
		sec.modulate.a = 0.0

	# Disable Next until animation is done.
	next_btn.disabled = true
	_anim_timer = 0.3   # brief initial pause
	_anim_idx = 0
	_anim_done = false


func _process(delta: float) -> void:
	if _anim_done:
		return
	_anim_timer -= delta
	if _anim_timer > 0.0:
		return

	if _anim_idx < _anim_sections.size():
		var sec: Control = _anim_sections[_anim_idx]
		# Only animate sections that have content (skip invisible/empty ones).
		var tween: Tween = create_tween()
		tween.tween_property(sec, "modulate:a", 1.0, 0.25)
		_anim_idx += 1
		_anim_timer = SECTION_DELAY
	else:
		_anim_done = true
		set_process(false)
		# Re-enable Next now that everything is visible.
		_refresh_next_button(GameState.last_battle_result)
		resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory, GameState.reputation))


func _render_content() -> void:
	var r: Dictionary = GameState.last_battle_result
	var label: String = r.get("event_label", "—")
	if r.get("sub_event", "") != "":
		label = "%s — %s" % [label, BattleEvent.label(r["sub_event"])]
	elif int(r.get("event_kind", -1)) == EventKind.AWAY_BATTLE and AwayModeDB.has_mode(GameState.pending_away_mode):
		label = "%s — %s" % [label, AwayModeDB.label_for(GameState.pending_away_mode)]
	header_lbl.text = "Weekly Summary — Week %d  ·  %s  ·  %s" % [GameState.week, Calendar.season_chip(GameState.week), label]
	resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory, GameState.reputation))

	_render_chronicle()
	_render_outcome(r)
	_render_battle_breakdown(r)
	_render_rewards(r)
	_render_caravan(r)
	_render_deltas()
	_render_returns()
	_render_streak(r)
	# Next button state set after animation.
	next_btn.text = "Please wait…"


func _render_chronicle() -> void:
	# Remove any previously-rendered chronicle panel (re-render safety).
	for c in summary_body.get_children():
		if c.name == "ChroniclePanel":
			c.queue_free()
			break

	var prose: String = Chronicle.generate_week_entry(GameState)

	var panel := PanelContainer.new()
	panel.name = "ChroniclePanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Chronicle"
	title.add_theme_font_size_override("font_size", 14)
	title.modulate = Color(0.72, 0.62, 0.38)
	vbox.add_child(title)

	var prose_lbl := Label.new()
	prose_lbl.text = prose
	prose_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	prose_lbl.modulate = Color(0.86, 0.80, 0.65)
	prose_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(prose_lbl)

	summary_body.add_child(panel)
	summary_body.move_child(panel, 0)


func _render(r: Dictionary = GameState.last_battle_result) -> void:
	_render_content()
	_refresh_next_button(r)
	resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory, GameState.reputation))


func _render_outcome(r: Dictionary) -> void:
	if r.is_empty():
		outcome_lbl.text = "Nothing happened this week."
		outcome_lbl.modulate = Color(0.78, 0.78, 0.78, 0.0)
		return

	if r.get("is_game_over", false):
		outcome_lbl.text = "✗ Homestead breached — your run ends."
		outcome_lbl.modulate = Color(0.95, 0.5, 0.5, 0.0)
		return

	if r.get("is_run_win", false):
		outcome_lbl.text = "★ Grand Tournament won — the realm is yours!"
		outcome_lbl.modulate = Color(1.0, 0.85, 0.4, 0.0)
		return

	if not r.get("fought", false):
		# Story events get their full chronicle label here instead of the
		# generic "Battle Event — no battle this week." line; the prose notes
		# carry the rest of the meaning underneath.
		if StoryEventDB.is_story_sub_type(r.get("sub_event", "")):
			var sid: String = StoryEventDB.story_id_from_sub_type(r["sub_event"])
			outcome_lbl.text = "❦  %s" % StoryEventDB.label_for(sid)
			outcome_lbl.modulate = Color(0.92, 0.78, 0.42, 0.0)
		else:
			outcome_lbl.text = "%s — no battle this week." % EventKind.label(r["event_kind"])
			outcome_lbl.modulate = Color(0.78, 0.78, 0.78, 0.0)
		return

	if r["won"]:
		outcome_lbl.text = "✓ Won %s — %d vs %d enemy." % [label_for(r), r["player_total"], r["enemy_total"]]
		outcome_lbl.modulate = Color(0.6, 0.95, 0.6, 0.0)
	else:
		outcome_lbl.text = "✗ Lost %s — %d vs %d enemy." % [label_for(r), r["player_total"], r["enemy_total"]]
		outcome_lbl.modulate = Color(0.95, 0.6, 0.6, 0.0)


func label_for(r: Dictionary) -> String:
	if r.get("sub_event", "") != "":
		return BattleEvent.label(r["sub_event"])
	return EventKind.label(r["event_kind"])


# Inlined Battle Log content. We always route through the Weekly Summary now
# (see pre_battle_review._on_confirm), so the per-unit breakdown shows here as
# part of the animated reveal. Hidden when there's nothing combat-y to show.
func _render_battle_breakdown(r: Dictionary) -> void:
	for c in battle_breakdown.get_children():
		c.queue_free()

	var has_formation: bool = not r.get("per_unit", []).is_empty()
	var has_tourney: bool = not r.get("tournament_per_unit", []).is_empty()
	var is_duel: bool = r.get("sub_event", "") == "champion_duel"
	var fought: bool = r.get("fought", false)
	# Story events are non-combat but their chronicle notes are the point of
	# the event — surface them in this section so the player isn't scrolling
	# for the prose.
	var is_story: bool = StoryEventDB.is_story_sub_type(r.get("sub_event", ""))
	# Notes-only fallback: oath honour grants and similar chronicle beats
	# emit only into result["notes"] and would be silently swallowed on
	# non-combat / non-story weeks without this. When the week has anything
	# textual to surface, the section appears as a ❦ Chronicle block.
	var has_notes: bool = not r.get("notes", []).is_empty()

	# Hide the whole section (header + body) only when there is genuinely
	# nothing to display.
	if not (has_formation or has_tourney or is_duel or fought or is_story or has_notes):
		battle_breakdown_header.visible = false
		battle_breakdown.visible = false
		return
	battle_breakdown_header.visible = true
	battle_breakdown.visible = true
	if (is_story or has_notes) and not fought:
		battle_breakdown_header.text = "❦  Chronicle"
	else:
		battle_breakdown_header.text = "Battle Breakdown"

	if has_formation:
		_render_formation_rows(r)
	elif has_tourney:
		_render_tournament_rows(r)
	elif is_duel:
		_render_duel_summary(r)

	# Totals line — short, single string.
	if fought:
		var totals := Label.new()
		var intim: int = int(r.get("intimidation_reduction", 0))
		if intim > 0:
			totals.text = "Totals — %d vs %d (intimidation shaved %d)" % [
				r.get("player_total", 0), r.get("enemy_total", 0), intim,
			]
		else:
			totals.text = "Totals — %d vs %d" % [
				r.get("player_total", 0), r.get("enemy_total", 0),
			]
		totals.modulate = Color(0.78, 0.78, 0.72)
		battle_breakdown.add_child(totals)

	# Combat notes — sim flavour, epithet grants, special outcomes. These used
	# to live on the Battle Log; without them the player misses earned epithets.
	for note in r.get("notes", []):
		var note_lbl := Label.new()
		note_lbl.text = "• %s" % note
		note_lbl.modulate = Color(0.75, 0.70, 0.55)
		note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		battle_breakdown.add_child(note_lbl)


func _render_formation_rows(r: Dictionary) -> void:
	var hdr := _breakdown_row(
		["Unit", "Slot", "Power", "Total"], true,
	)
	battle_breakdown.add_child(hdr)
	for entry in r["per_unit"]:
		var u: Unit = GameState.find_unit(entry["unit_id"])
		var unit_name: String = u.unit_name if u != null else "?"
		var slot_label: String = entry["slot"] if entry["slot"] != "" else "—"
		var power_breakdown: String = "%d + %d str + %d bra + %d skl" % [
			entry["base"], entry["str"], entry["bra"], entry["skill"],
		]
		if entry["slot_bonus"] > 0:
			power_breakdown += " (+%d match)" % entry["slot_bonus"]
		if entry["leadership_buff"] > 0:
			power_breakdown += " (+%d lead)" % entry["leadership_buff"]
		var total_str: String = "%d" % entry["total"]
		if entry["mult"] != 1.0:
			total_str = "%d ×%.2f → %d" % [entry["raw"], entry["mult"], entry["total"]]
		battle_breakdown.add_child(_breakdown_row(
			[unit_name, slot_label, power_breakdown, total_str], false,
		))


func _render_tournament_rows(r: Dictionary) -> void:
	var hdr := _breakdown_row(["Unit", "Build", "Power"], true)
	battle_breakdown.add_child(hdr)
	for entry in r["tournament_per_unit"]:
		var u: Unit = GameState.find_unit(entry["unit_id"])
		var unit_name: String = u.unit_name if u != null else "?"
		var build_str: String = "%d + %d str + %d tec + %d skl" % [
			Combat.TOURNAMENT_BASE_POWER,
			entry["str"], entry["tec"], entry["skill"],
		]
		var weap_p: int = int(entry.get("weapon_power", 0))
		var arm_p: int = int(entry.get("armour_power", 0))
		if weap_p > 0 or arm_p > 0:
			build_str += "  (+%d kit)" % (weap_p + arm_p)
		battle_breakdown.add_child(_breakdown_row(
			[unit_name, build_str, "%d" % entry["total"]], false,
		))


func _render_duel_summary(r: Dictionary) -> void:
	var u: Unit = GameState.find_unit(r["duel_unit_id"])
	var champ_name: String = u.unit_name if u != null else "?"
	var line := Label.new()
	line.text = "Champion: %s — Str+Bra+Sword = %d  vs  %d" % [
		champ_name, r["duel_player_power"], r["duel_enemy_power"],
	]
	battle_breakdown.add_child(line)


func _breakdown_row(cells: Array, header: bool) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for i in range(cells.size()):
		var lbl := Label.new()
		lbl.text = str(cells[i])
		# First column is the unit name — wider so it doesn't wrap.
		lbl.custom_minimum_size = Vector2(140 if i == 0 else 0, 0)
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL if i > 0 else Control.SIZE_FILL
		if header:
			lbl.modulate = Color(0.85, 0.78, 0.55)
			lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(lbl)
	return row


func _render_rewards(r: Dictionary) -> void:
	for c in rewards_list.get_children():
		c.queue_free()

	# Encounter reward — pre-rolled bundle from RewardTableDB.
	# Untyped + `is Dictionary` guard so a null at the key doesn't crash;
	# the typed-Dictionary form would (Dictionary.get returns null when the
	# stored value is null, even with a default arg).
	var reward = r.get("reward", {})
	if reward is Dictionary and not reward.is_empty():
		var lbl := Label.new()
		lbl.text = "+ Reward: %s" % ResourceDB.describe(reward)
		lbl.modulate = Color(0.7, 0.95, 0.7)
		rewards_list.add_child(lbl)

	# Mob drops — per-kill spoils from each dead enemy's EnemyDB.drops table.
	# Surfaced as a distinct line so the player feels the kill itself paid out.
	var spoils = r.get("spoils", {})
	if spoils is Dictionary and not spoils.is_empty():
		var slbl := Label.new()
		slbl.text = "+ Spoils: %s" % ResourceDB.describe(spoils)
		slbl.modulate = Color(0.95, 0.78, 0.55)
		rewards_list.add_child(slbl)

	var tournament_gold: int = int(r.get("tournament_gold", 0))
	if tournament_gold > 0:
		var lbl := Label.new()
		lbl.text = "+ %d gold (tournament prize)" % tournament_gold
		lbl.modulate = Color(1.0, 0.85, 0.4)
		rewards_list.add_child(lbl)

	var castle: Castle = r.get("castle_taken")
	if castle != null:
		var lbl := Label.new()
		lbl.text = "Castle (%d,%d) seized — removed from the world." % [castle.x, castle.y]
		lbl.modulate = Color(0.85, 0.85, 0.6)
		rewards_list.add_child(lbl)

	# Item drop from ItemDrops loot roll — rarity-tinted so heirlooms read at
	# a glance against the rest of the rewards section.
	var drop: Dictionary = r.get("item_drop", {})
	if not drop.is_empty():
		var slot: String = str(drop.get("slot", ""))
		var id: String = str(drop.get("id", ""))
		var rarity_col: Color = (
			Weapon.rarity_color(id) if slot == "weapon" else Armour.rarity_color(id)
		)
		var rarity_lbl: String = (
			Weapon.rarity_label(id) if slot == "weapon" else Armour.rarity_label(id)
		)
		var item_name: String = (
			Weapon.display_name(id) if slot == "weapon" else Armour.display_name(id)
		)
		var glyph: String = "⚔" if slot == "weapon" else "🛡"
		var lbl := Label.new()
		lbl.text = "%s %s (%s) — added to the armoury" % [glyph, item_name, rarity_lbl]
		lbl.modulate = rarity_col
		rewards_list.add_child(lbl)

	if r.get("sub_event", "") == "champion_duel" and r.get("won", false):
		var champ: Unit = GameState.find_unit(r["duel_unit_id"])
		var stat: String = r.get("duel_stat", "")
		var lbl := Label.new()
		if champ != null and stat != "" and r.get("duel_stat_applied", false):
			lbl.text = "+1 %s applied to %s. ▲" % [stat.capitalize(), champ.unit_name]
			lbl.modulate = Color(0.7, 0.95, 0.7)
		elif champ != null and stat != "":
			lbl.text = "Duel won — its lessons deepen %s's %s over time." % [champ.unit_name, stat.capitalize()]
			lbl.modulate = Color(0.72, 0.9, 0.8)
		else:
			lbl.text = "Duel won but no target stat was chosen."
			lbl.modulate = Color(0.85, 0.85, 0.6)
		rewards_list.add_child(lbl)

	# Injury report
	for inj in r.get("injuries", []):
		var u: Unit = GameState.find_unit(inj["unit_id"])
		var uname: String = u.unit_name if u != null else "?"
		var lbl := Label.new()
		lbl.text = "⚠ %s — injured %s (%dw recovery)" % [uname, inj["stat"].capitalize(), inj["weeks_remaining"]]
		lbl.modulate = Color(0.95, 0.55, 0.25)
		rewards_list.add_child(lbl)

	if rewards_list.get_child_count() == 0:
		var none := Label.new()
		none.text = "Nothing carried home this week."
		none.modulate = Color(0.55, 0.50, 0.40)
		rewards_list.add_child(none)


func _render_caravan(r: Dictionary) -> void:
	for c in caravan_pane.get_children():
		c.queue_free()
	caravan_pane.visible = false

	if r.get("sub_event", "") != "merchant_caravan":
		return
	caravan_pane.visible = true

	if GameState.merchant_pick >= 0:
		var taken: Dictionary = GameState.merchant_offers[GameState.merchant_pick]
		var taken_lbl := Label.new()
		taken_lbl.text = "Took: %s" % ResourceDB.describe(taken)
		taken_lbl.modulate = Color(0.7, 0.95, 0.7)
		caravan_pane.add_child(taken_lbl)
		return

	var prompt := Label.new()
	prompt.text = "Merchant offers — pick one bundle:"
	caravan_pane.add_child(prompt)

	for i in range(GameState.merchant_offers.size()):
		var offer: Dictionary = GameState.merchant_offers[i]
		var btn := Button.new()
		btn.text = "Take: %s" % ResourceDB.describe(offer)
		btn.pressed.connect(_on_caravan_pick.bind(i))
		caravan_pane.add_child(btn)


func _on_caravan_pick(idx: int) -> void:
	Crafting.accept_caravan_offer(GameState, idx)
	_render()


func _render_deltas() -> void:
	for c in deltas_list.get_children():
		c.queue_free()

	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.parse_bbcode(_build_delta_bbcode())
	deltas_list.add_child(rtl)


func _build_delta_bbcode() -> String:
	var t: Dictionary = GameState.last_tick_results
	var lines: Array[String] = []
	const GREEN: String = "#50E050"
	const AMBER: String = "#D9B84C"
	const RED:   String = "#E05050"
	const CYAN:  String = "#55CCCC"
	const GREY:  String = "#888888"
	const DIV:   String = "[color=#555555]────────────────────────[/color]"

	# Training
	var training: Array = t.get("training", [])
	if not training.is_empty():
		lines.append("[color=%s]── TRAINING[/color]" % AMBER)
		for entry in training:
			var u: Unit = GameState.find_unit(entry["unit_id"])
			var uname: String = "%-14s" % (u.unit_name if u != null else "?")
			var stat_name: String = "%-14s" % String(entry["stat"]).capitalize()
			if int(entry.get("leveled", 0)) > 0:
				lines.append("[color=%s]%s %s %d → %d  ▲[/color]" % [GREEN, uname, stat_name, entry["before"], entry["after"]])
			elif entry.get("developing", false):
				lines.append("[color=%s]%s %s %d    (developing ▲)[/color]" % [AMBER, uname, stat_name, entry["after"]])
			else:
				lines.append("[color=%s]%s %s %d    (capped)[/color]" % [GREY, uname, stat_name, entry["after"]])
			if entry.get("bonus_stat", "") != "":
				if entry.get("bonus_leveled", false):
					lines.append("[color=%s]      ↳ +1 %s bonus (Determination)  ▲[/color]" % [GREEN, String(entry["bonus_stat"]).capitalize()])
				else:
					lines.append("[color=%s]      ↳ %s sharpening (Determination)[/color]" % [AMBER, String(entry["bonus_stat"]).capitalize()])
		lines.append(DIV)

	# Determination
	var det: Array = t.get("determination", [])
	if not det.is_empty():
		lines.append("[color=%s]── DETERMINATION[/color]" % AMBER)
		for entry in det:
			var u: Unit = entry["unit"]
			if int(entry.get("leveled", 0)) > 0:
				lines.append("[color=%s]%s  +1 %s  ▲[/color]" % [GREEN, u.unit_name, String(entry["stat"]).capitalize()])
			else:
				lines.append("[color=%s]%s  %s stirs (developing)[/color]" % [AMBER, u.unit_name, String(entry["stat"]).capitalize()])
		lines.append(DIV)

	# Expedition returns
	var returns: Array = t.get("expedition_returns", [])
	if not returns.is_empty():
		lines.append("[color=%s]── RESOURCES[/color]" % AMBER)
		for r in returns:
			if r["kind"] == Expedition.Kind.GATHER and r["yield_amount"] > 0:
				var entry: Dictionary = ResourceDB.RESOURCES.get(r["yield_resource"], {})
				var res_name: String = entry.get("name", r["yield_resource"])
				lines.append("[color=%s]%-16s +%d    (Expedition)[/color]" % [GREEN, res_name, r["yield_amount"]])
		lines.append(DIV)

	# Gold
	var gold_income: int = int(t.get("gold_income", 0))
	var gold_cost: int = int(t.get("gold_deducted", 0))
	var gold_net: int = gold_income - gold_cost
	var debt: bool = t.get("maintenance_debt", false)
	lines.append("[color=%s]── GOLD[/color]" % AMBER)
	if gold_income > 0:
		lines.append("[color=%s]%-16s +%d/wk  (Stipend & income)[/color]" % [GREEN, "Income:", gold_income])
	lines.append("[color=%s]%-16s −%d/wk  (%d units × 5)%s[/color]" % [
		RED, "Upkeep:", gold_cost, GameState.roster.size(), "  ⚠ DEBT" if debt else "",
	])
	var net_color: String = GREEN if gold_net >= 0 else RED
	lines.append("[color=%s]%-16s %s%d/wk[/color]" % [net_color, "Net:", "+" if gold_net >= 0 else "", gold_net])

	# Injury recoveries
	var recoveries: Array = t.get("injury_recoveries", [])
	if not recoveries.is_empty():
		lines.append(DIV)
		lines.append("[color=%s]── RECOVERIES[/color]" % AMBER)
		for entry in recoveries:
			var u: Unit = GameState.find_unit(entry["unit_id"])
			var uname: String = u.unit_name if u != null else "?"
			lines.append("[color=%s]%s  %s injury healed[/color]" % [CYAN, uname, entry["stat"].capitalize()])

	if lines.is_empty():
		return "[color=%s]—[/color]" % GREY

	return "\n".join(lines)


func _render_returns() -> void:
	for c in returns_list.get_children():
		c.queue_free()
	var t: Dictionary = GameState.last_tick_results
	var returns: Array = t.get("expedition_returns", [])
	if returns.is_empty():
		var none := Label.new()
		none.text = "No parties returned this week."
		none.modulate = Color(0.55, 0.50, 0.40)
		returns_list.add_child(none)
		return
	for r in returns:
		var bits: PackedStringArray = PackedStringArray()
		bits.append("%s at (%d,%d)" % [r["kind_label"], r["target_x"], r["target_y"]])
		if r["kind"] == Expedition.Kind.EXPLORE:
			var castle: Castle = r.get("revealed_castle")
			if castle != null:
				bits.append("revealed %s (Castle, diff %d)" % [r["revealed_terrain"], castle.difficulty])
			elif r["revealed_terrain"] != "":
				bits.append("revealed %s" % r["revealed_terrain"])
		elif r["kind"] == Expedition.Kind.GATHER and r["yield_amount"] > 0:
			var entry: Dictionary = ResourceDB.RESOURCES.get(r["yield_resource"], {})
			bits.append("+%d %s" % [r["yield_amount"], entry.get("name", r["yield_resource"])])
		var lbl := Label.new()
		lbl.text = "  • " + (" — ".join(bits))
		returns_list.add_child(lbl)


func _render_streak(r: Dictionary) -> void:
	if EventKind.is_tournament(r.get("event_kind", -1)):
		streak_lbl.text = "Tournament streak: %d" % GameState.tournament_streak
		streak_lbl.modulate = Color(1.0, 0.85, 0.4, 0.0) if GameState.tournament_streak > 0 else Color(0.85, 0.85, 0.85, 0.0)
	else:
		streak_lbl.text = ""
		streak_lbl.modulate.a = 0.0


# ---------- next button + routing ----------

func _refresh_next_button(r: Dictionary) -> void:
	if r.get("sub_event", "") == "merchant_caravan" and GameState.merchant_pick < 0:
		next_btn.disabled = true
		next_btn.text = "Pick a bundle first"
		return

	next_btn.disabled = false
	if r.get("is_game_over", false):
		next_btn.text = "View Game Over →"
	elif r.get("is_run_win", false):
		next_btn.text = "View Final Result →"
	else:
		next_btn.text = "Next Week →"


func _on_next() -> void:
	GameState.append_history_entry()

	var r: Dictionary = GameState.last_battle_result
	if r.get("is_game_over", false):
		_record_completed_run("lost")
		get_tree().change_scene_to_file("res://scenes/screens/game_over.tscn")
		return
	if r.get("is_run_win", false):
		_record_completed_run("won")
		get_tree().change_scene_to_file("res://scenes/screens/run_win.tscn")
		return

	GameState.wrap_week()
	GameState.phase_machine.transition(PhaseMachine.Phase.PLANNING)
	GameState.roll_current_event()
	get_tree().change_scene_to_file("res://scenes/screens/planning.tscn")


func _record_completed_run(outcome: String) -> void:
	var entry: Dictionary = {
		"run_number": SaveManager.run_history.size() + 1,
		"seed": 0,
		"weeks_survived": GameState.week,
		"outcome": outcome,
		"date": Time.get_date_string_from_system(),
		"tournament_streak": GameState.tournament_streak,
	}
	SaveManager.append_run_history(entry)
	SaveManager.delete_save()


func _on_settings() -> void:
	SettingsPopup.show_for(self)


# Spacebar / Enter both skip the staggered fade-in and advance to the next
# week; matches the visible Next Week button. Esc on a Merchant Caravan week
# is intentionally inert — the player must pick a bundle before continuing.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode != KEY_ENTER and event.keycode != KEY_KP_ENTER and event.keycode != KEY_SPACE:
		return
	if not _anim_done:
		# First press — skip the fade. Reveal every section instantly and
		# let the player press again to actually proceed.
		for sec in _anim_sections:
			sec.modulate.a = 1.0
		_anim_done = true
		set_process(false)
		_refresh_next_button(GameState.last_battle_result)
		resources_lbl.parse_bbcode(ResourceDB.resource_hud_bbcode(GameState.gold, GameState.inventory, GameState.reputation))
		accept_event()
		return
	if not next_btn.disabled:
		_on_next()
		accept_event()
