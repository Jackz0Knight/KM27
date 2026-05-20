extends Node

# Central run state — populated as phases land. The GameState is an autoload
# (singleton), so scenes can read/write it without passing references around.
#
# Phase ownership:
#   Phase 1: World / WorldGenerator wiring (`world`).
#   Phase 2: PhaseMachine, calendar helpers, EventRoller (`current_event`,
#            `tournament_streak`, week/year helpers).
#   Phase 3: Roster population (1 Knight + 3 Squires).
#   Phase 4: Expedition tracking, pending-task buffer, away-week selections.
#   Phase 5+: Tick / Pre-Battle / battle resolution.

var week: int = 1
var phase_machine: PhaseMachine = null
var roster: Array[Unit] = []
var world: World = null
var tournament_streak: int = 0
var current_event: int = -1   # EventKind; -1 means "no event rolled yet".

# Transient: Knight candidates + pre-rolled Squires shown on the chooser
# screen. Cleared once the Knight is picked.
var knight_candidates: Array[Unit] = []
var starting_squires: Array[Unit] = []

# Phase 4: active expeditions. Each one removes its units from the home pool
# until weeks_remaining ticks to 0 (Phase 5).
var expeditions: Array[Expedition] = []
var _next_expedition_id: int = 1

# Phase 4: away-week selections — the player decides during Planning, the
# battle resolves during Resolution (Phase 6 wires that). Reset every week.
var pending_away_party: Array[int] = []
var pending_away_mode: String = ""             # "pillage" | "assault" | ""
var pending_assault_castle: Castle = null

# Phase 5/6/7 — week-transient buffers. Cleared by `wrap_week()` when the
# player hits "Next Week" on the Weekly Summary.
var last_tick_results: Dictionary = {}
var last_battle_result: Dictionary = {}

# Phase 6 — Battle Event sub-type. Rolled at the same time as `current_event`
# when it lands on a Battle Event week. One of:
#   "" (not a battle event)
#   "bandit_ambush"     — formation combat at home
#   "champion_duel"     — single-unit stat check, +1 stat reward on win
#   "bountiful_harvest" — automatic resource gift
#   "merchant_caravan"  — player picks 1 of 3 small bundles
var current_battle_event: String = ""
# Merchant Caravan offers, populated during Resolution. Array of ResourceBundle.
var merchant_offers: Array = []
# Merchant Caravan choice — index into `merchant_offers`, -1 = not yet picked.
var merchant_pick: int = -1

# Phase 6 — formation slots for combat events. slot key → unit_id (-1 if empty).
# Slots: "blue" (Camp Leader), "green" (Ranged), "yellow" (Heavy Melee),
#        "red" (Light Melee). Set by the Pre-Battle Review screen.
var formation: Dictionary = {"blue": -1, "green": -1, "yellow": -1, "red": -1}

# Persistent default formations set on the Tactics tab. Pre-Battle Review
# seeds the week's `formation` from one of these when entering the screen,
# so the player only configures slot picks once per run unless they want
# to override mid-week. Survives wrap_week() — cleared on start_run.
var default_defense_formation: Dictionary = {"blue": -1, "green": -1, "yellow": -1, "red": -1}
var default_attack_formation: Dictionary = {"blue": -1, "green": -1, "yellow": -1, "red": -1}

# Phase 6 — Champion's Duel selection.
var champion_unit_id: int = -1
var champion_target_stat: String = ""

# Phase 7 — Tournament participants (up to 4 at-home unit ids).
var tournament_participants: Array[int] = []

# Calendar tab — chronological log of resolved weeks. Each entry is a
# Dictionary; see `append_history_entry` for the shape. Cleared on start_run.
var run_history: Array[Dictionary] = []

# Knight Overview routing — set by whoever opens the detail screen, read by
# `knight_overview.gd` to know which unit to render.
var focused_unit_id: int = -1

# Planning shows a one-shot "Your Journey Begins…" panel on the very first
# week's Planning render. Cleared by start_run so the next run shows it again.
var intro_shown_for_run: bool = false

# Resource system (GDD §14 expansion).
# gold: weekly maintenance currency (each unit costs 5 gold / week).
# inventory: unified store for all resource IDs — raw materials and processed.
# researched: list of unlocked research keys (stub; expanded in Phase 8+).
# maintenance_debt: set true if a week's tick couldn't cover full gold cost.
var gold: int = 100
var inventory: Dictionary = {}
var researched: Array[String] = []
var maintenance_debt: bool = false

# Gold income sources. `weekly_stipend` is always active; others are set
# temporarily when an event grants a recurring bonus then reset to 0.
var gold_income_sources: Dictionary = {
	"tournament_prize": 0,
	"expedition_trade": 0,
	"weekly_stipend": 10,
}

# Stub for future building/research upgrade costs.
var upgrade_costs: Dictionary = {}

# Confirm dialogs suppressed for this run (Feature 8).
var suppressed_confirms: Array[String] = []

# Items crafted at least once this run — used by crafting visibility (Feature 10).
var crafted_ids: Array[String] = []

# Unequipped weapons + armours sitting in the household armoury. Each entry:
#   {"slot": "weapon"|"armour", "id": String}
# Items enter the stockpile through loot rolls (Resolution drops, tournament
# prizes) and leave through equip_item(). Cleared on start_run; persisted by
# SaveManager.
var item_stockpile: Array[Dictionary] = []


func gold_maintenance_cost() -> int:
	return roster.size() * 5


func purchase_research(project_id: String) -> void:
	var proj: Dictionary = ResourceDB.RESEARCH_PROJECTS.get(project_id, {})
	gold -= proj["cost_gold"]
	researched.append(project_id)


func total_gold_income() -> int:
	var total: int = 0
	for v in gold_income_sources.values():
		total += int(v)
	return total


func _ready() -> void:
	phase_machine = PhaseMachine.new()


# Global hotkeys. F11 toggles fullscreen — the project launches in fullscreen
# (project.godot window/size/mode=3) so this is the escape hatch during play.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			toggle_fullscreen()


func toggle_fullscreen() -> void:
	var mode := DisplayServer.window_get_mode()
	var fullscreen_modes: Array = [
		DisplayServer.WINDOW_MODE_FULLSCREEN,
		DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	]
	if fullscreen_modes.has(mode):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


# ---------- calendar passthroughs ----------

func current_year() -> int:
	return Calendar.year_for(week)


func current_week_of_year() -> int:
	return Calendar.week_of_year(week)


func is_tournament_week() -> bool:
	return Calendar.is_tournament_week(week)


# ---------- run lifecycle ----------

func has_active_run() -> bool:
	return world != null


func start_run(seed_value: int) -> void:
	world = WorldGenerator.generate(seed_value)
	week = 1
	tournament_streak = 0
	roster.clear()
	knight_candidates.clear()
	starting_squires.clear()
	current_event = -1
	current_battle_event = ""
	expeditions.clear()
	_next_expedition_id = 1
	run_history.clear()
	focused_unit_id = -1
	intro_shown_for_run = false
	gold = 100
	inventory = {}
	researched.clear()
	maintenance_debt = false
	gold_income_sources = {"tournament_prize": 0, "expedition_trade": 0, "weekly_stipend": 10}
	upgrade_costs = {}
	suppressed_confirms.clear()
	crafted_ids.clear()
	item_stockpile.clear()
	default_defense_formation = {"blue": -1, "green": -1, "yellow": -1, "red": -1}
	default_attack_formation = {"blue": -1, "green": -1, "yellow": -1, "red": -1}
	_clear_pending_away()
	_clear_week_buffers()
	if phase_machine != null:
		phase_machine.current = PhaseMachine.Phase.PLANNING
	EventBus.run_started.emit(seed_value)


# ---------- weekly clock ----------

# Rolls `current_event` (and `current_battle_event` if a Battle Event lands)
# for the current week. Called at Planning entry.
func roll_current_event() -> int:
	current_event = EventRoller.roll(week, tournament_streak)
	current_battle_event = ""
	if current_event == EventKind.BATTLE_EVENT:
		current_battle_event = BattleEvent.roll_sub_type(self)
	EventBus.event_rolled.emit(current_event)
	return current_event


# Wraps the week: bumps the counter, clears week-transient buffers (tick
# results, battle result, formation, sub-event), and rolls the next event.
# Called by the Weekly Summary screen's Next Week button.
func wrap_week() -> void:
	week += 1
	current_event = -1
	current_battle_event = ""
	_clear_pending_away()
	_clear_week_buffers()
	EventBus.week_advanced.emit(week)


# ---------- roster helpers ----------

func find_unit(unit_id: int) -> Unit:
	for u in roster:
		if u.id == unit_id:
			return u
	return null


func at_home_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for u in roster:
		if u.is_at_home():
			out.append(u)
	return out


# ---------- expeditions ----------

func launch_expedition(kind: Expedition.Kind, target_x: int, target_y: int, unit_ids: Array[int]) -> Expedition:
	var exped := Expedition.new(_next_expedition_id, kind, target_x, target_y, unit_ids)
	_next_expedition_id += 1
	expeditions.append(exped)

	for uid in unit_ids:
		var u: Unit = find_unit(uid)
		if u != null:
			u.current_task = Unit.TASK_EXPEDITION
			u.expedition_id = exped.id

	var tile: MapTile = world.get_tile(target_x, target_y)
	if tile != null:
		tile.active_expedition = exped

	return exped


# Removes an expedition from the active list and clears its tile + units.
# Phase 5's Tick will call this when weeks_remaining hits 0.
func complete_expedition(exped: Expedition) -> void:
	expeditions.erase(exped)
	var tile: MapTile = world.get_tile(exped.target_x, exped.target_y)
	if tile != null and tile.active_expedition == exped:
		tile.active_expedition = null
	for uid in exped.unit_ids:
		var u: Unit = find_unit(uid)
		if u != null:
			u.current_task = Unit.TASK_IDLE
			u.expedition_id = -1


# ---------- planning helpers ----------

func _clear_pending_away() -> void:
	pending_away_party.clear()
	pending_away_mode = ""
	pending_assault_castle = null


func _clear_week_buffers() -> void:
	last_tick_results = {}
	last_battle_result = {}
	merchant_offers = []
	merchant_pick = -1
	formation = {"blue": -1, "green": -1, "yellow": -1, "red": -1}
	champion_unit_id = -1
	champion_target_stat = ""
	tournament_participants = []


# Phase 5/6 — true if this week's event will resolve combat with a formation.
# Tournament + Grand Tournament don't use formations (GDD §12 / §13).
func current_event_uses_formation() -> bool:
	if current_event == EventKind.AWAY_BATTLE:
		return true
	if current_event == EventKind.HOME_BATTLE:
		return true
	if current_event == EventKind.BATTLE_EVENT:
		return current_battle_event == "bandit_ambush"
	return false


# Calendar tab — capture this week's outcome for the history log. Called by
# Weekly Summary just before wrap_week(), so the entry sees the resolved
# state (battle result, rewards, deltas) before the buffers clear.
func append_history_entry() -> void:
	var r: Dictionary = last_battle_result
	var outcome: String = "—"
	if r.get("is_game_over", false):
		outcome = "Defeat — homestead breached"
	elif r.get("is_run_win", false):
		outcome = "Victory — Grand Tournament won"
	elif r.get("fought", false):
		outcome = "Won" if r["won"] else "Lost"
	elif r.get("event_kind", -1) != -1:
		outcome = "Resolved"

	var reward_str: String = ""
	var reward: ResourceBundle = r.get("reward")
	if reward != null and not reward.is_empty():
		reward_str = reward.describe()

	var label: String = EventKind.label(r.get("event_kind", current_event))
	if r.get("sub_event", "") != "":
		label = "%s — %s" % [label, BattleEvent.label(r["sub_event"])]

	run_history.append({
		"week": week,
		"year": current_year(),
		"week_of_year": current_week_of_year(),
		"event_label": label,
		"outcome": outcome,
		"player_total": r.get("player_total", 0),
		"enemy_total": r.get("enemy_total", 0),
		"reward_str": reward_str,
	})


# Filtered helper — at-home units that can be slotted in a formation this week.
# For Away weeks, only the pending_away_party is fightable. For Home / Bandit
# Ambush, every at-home unit fights.
func combat_participants() -> Array[Unit]:
	var out: Array[Unit] = []
	if current_event == EventKind.AWAY_BATTLE:
		for uid in pending_away_party:
			var u: Unit = find_unit(uid)
			if u != null and u.is_at_home():
				out.append(u)
	else:
		for u in roster:
			if u.is_at_home():
				out.append(u)
	return out
