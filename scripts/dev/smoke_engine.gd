class_name SmokeEngine
extends Node

# The smoke-harness engine — plays KM27 badly but completely, with no human,
# to catch script errors before a person ever rolls the broken week. Shared by
# two front ends:
#   • scripts/dev/smoke_runner.gd — headless CLI shell (tools/smoke.sh)
#   • the F1 Dev Toolbar's "Smoke Harness" section — in-game runs with
#     GameState snapshot/restore around the battery
#
# Must be inside the tree before run_battery() is called (the UI probe needs
# get_tree() to pump frames). Emits `progress` for every report line; the
# caller decides whether that means print() or a RichTextLabel.
#
# What it does per seed: GameState.start_run → roster from the first knight
# candidate → loop weeks driving the SAME calls the screens make (fill
# pending_tasks, commit, Tick.apply, Resolution.run, caravan pick, history,
# wrap_week, roll_current_event) with a naive policy:
#   • train the lowest stat; everyone Defends on Home Battle weeks
#   • Away weeks: pillage with all at-home units (assault the weakest known
#     castle every 8th week)
#   • Champion's Duel: best Str+Bra+Swd unit fights, targets its lowest stat
#   • Tournaments: everyone at home enters
#   • formation slots filled in roster order on formation weeks
#   • an Explore/Gather expedition launches every few quiet weeks
#
# It does NOT judge balance — it only fails: on runtime errors (Resolution
# returning non-Dictionary), on invariant breaches (week didn't advance,
# roster != 4, negative gold, orphaned expedition task), and on a determinism
# mismatch (the first seed is replayed and must produce an identical trace).
# Win/loss/survival are all PASSING outcomes.
#
# Deliberately NEVER calls SaveManager.save_game() — a smoke pass must not
# clobber a real save. (It DOES trash the live GameState; in-game callers
# snapshot/restore around it — see DevToolbar.)

signal progress(line: String)

const SLOT_ORDER: Array[String] = ["blue", "green", "yellow", "red"]


# Runs the full battery: `seeds` consecutive seeds from `start_seed`, `weeks`
# weeks each, then a determinism replay of the first seed, then (optionally)
# the UI screen probe. Returns {"failures": int, "passed": bool}.
func run_battery(seeds: int, weeks: int, start_seed: int, ui_probe: bool) -> Dictionary:
	_emit("[smoke] %d seed(s) from %d, %d week(s) each" % [seeds, start_seed, weeks])
	var failures: int = 0
	var first_trace: String = ""

	for i in range(seeds):
		var seed_value: int = start_seed + i
		var r: Dictionary = _play_run(seed_value, weeks)
		if i == 0:
			first_trace = r["trace"]
		_emit("[smoke] seed %-6d  %s" % [seed_value, _summary_line(r)])
		if not r["ok"]:
			failures += 1
			_emit("[smoke]   FAIL: %s" % r["fail"])
		# Let the caller's UI breathe between seeds (headless: harmless frame).
		await get_tree().process_frame

	# Determinism: the first seed replayed must yield an identical week trace.
	var replay: Dictionary = _play_run(start_seed, weeks)
	if replay["trace"] != first_trace:
		failures += 1
		_emit("[smoke] FAIL: determinism — seed %d produced a different trace on replay." % start_seed)
		_emit_trace_diff(first_trace, replay["trace"])
	else:
		_emit("[smoke] determinism OK (seed %d replayed identically)" % start_seed)

	# UI probe: replay one run instantiating the REAL screens at the matching
	# moments, so screen _ready crashes surface. Separate from the battery
	# because screens may legitimately consume RNG (forecasts, default
	# seeding) and would desync the determinism trace.
	if ui_probe:
		failures += await _ui_probe_run(start_seed, weeks)

	if failures > 0:
		_emit("[smoke] RESULT: FAIL (%d failure(s))" % failures)
	else:
		_emit("[smoke] RESULT: PASS")
	return {"failures": failures, "passed": failures == 0}


func _emit(line: String) -> void:
	progress.emit(line)


# ---------- one full run ----------

func _play_run(seed_value: int, max_weeks: int) -> Dictionary:
	var out: Dictionary = {
		"ok": true, "fail": "", "outcome": "survived", "weeks": 0,
		"wins": 0, "losses": 0, "growth": 0, "trace": "",
	}
	var trace: PackedStringArray = PackedStringArray()

	# Mirror main.gd _on_start's new-run sequence (minus the screen changes).
	GameState.start_run(seed_value)
	GameState.knight_candidates = RosterGenerator.roll_knight_candidates()
	GameState.starting_squires = RosterGenerator.roll_starting_squires()
	if GameState.knight_candidates.is_empty():
		return _fail(out, "no knight candidates rolled")
	GameState.roster = RosterGenerator.build_starting_roster(
		GameState.knight_candidates[0], GameState.starting_squires)
	GameState.roll_current_event()
	var stats_at_start: int = _roster_stat_sum()

	for _i in range(max_weeks):
		var week_before: int = GameState.week
		out["weeks"] = week_before
		out["growth"] = _roster_stat_sum() - stats_at_start

		_plan_week()

		# Commit tasks exactly as planning.gd does (sans SaveManager).
		for u in GameState.roster:
			if u.is_on_expedition():
				continue
			u.current_task = GameState.pending_tasks.get(u.id, Unit.TASK_DEFEND)

		GameState.phase_machine.transition(PhaseMachine.Phase.TICK)
		var tick_results = Tick.apply(GameState)
		if not tick_results is Dictionary:
			return _fail(out, "Tick.apply returned non-Dictionary at week %d" % week_before)

		GameState.phase_machine.transition(PhaseMachine.Phase.PRE_BATTLE)
		GameState.phase_machine.transition(PhaseMachine.Phase.RESOLUTION)
		var result = Resolution.run(GameState)
		if not result is Dictionary or result.is_empty():
			return _fail(out, "Resolution.run returned non-Dictionary at week %d (event %s)" % [
				week_before, EventKind.label(GameState.current_event)])

		if result.get("fought", false):
			if result.get("won", false):
				out["wins"] = int(out["wins"]) + 1
			else:
				out["losses"] = int(out["losses"]) + 1

		# Merchant Caravan blocks Next Week until an offer is taken — take the first.
		if not GameState.merchant_offers.is_empty() and GameState.merchant_pick < 0:
			Crafting.accept_caravan_offer(GameState, 0)

		trace.append("w%d e%d g%d r%d s%d" % [
			week_before, GameState.current_event, GameState.gold,
			GameState.reputation, _roster_stat_sum()])

		if result.get("is_game_over", false):
			out["outcome"] = "loss"
			break
		if result.get("is_run_win", false):
			out["outcome"] = "win"
			break

		GameState.append_history_entry()
		GameState.wrap_week()
		GameState.phase_machine.transition(PhaseMachine.Phase.PLANNING)
		GameState.roll_current_event()

		var breach: String = _check_invariants(week_before)
		if breach != "":
			out["trace"] = "\n".join(trace)
			return _fail(out, breach)

	out["trace"] = "\n".join(trace)
	return out


# ---------- weekly policy ----------

func _plan_week() -> void:
	# Expedition first — it shrinks the at-home pool everything else draws from.
	_maybe_launch_expedition()

	var at_home: Array[Unit] = GameState.at_home_units()
	GameState.pending_tasks.clear()

	match GameState.current_event:
		EventKind.AWAY_BATTLE:
			GameState.pending_away_party.clear()
			for u in at_home:
				GameState.pending_away_party.append(u.id)
			var castle: Castle = _weakest_known_castle()
			if castle != null and GameState.week % 8 == 0:
				GameState.pending_away_mode = "assault"
				GameState.pending_assault_castle = castle
			else:
				GameState.pending_away_mode = "pillage"
			for u in at_home:
				GameState.pending_tasks[u.id] = _training_task(u)
		EventKind.HOME_BATTLE:
			for u in at_home:
				GameState.pending_tasks[u.id] = Unit.TASK_DEFEND
		EventKind.BATTLE_EVENT:
			if GameState.current_battle_event == "champion_duel":
				var champ: Unit = _best_duelist(at_home)
				if champ != null:
					GameState.champion_unit_id = champ.id
					GameState.champion_target_stat = _lowest_stat(champ)
			# Mixed tasks so home-template events exercise both the Defend
			# and the 0.75× non-Defend multipliers.
			for i in range(at_home.size()):
				var u: Unit = at_home[i]
				GameState.pending_tasks[u.id] = Unit.TASK_DEFEND if i == 0 else _training_task(u)
		EventKind.TOURNAMENT, EventKind.GRAND_TOURNAMENT:
			GameState.tournament_participants.clear()
			for u in at_home:
				GameState.tournament_participants.append(u.id)
				GameState.pending_tasks[u.id] = _training_task(u)
		_:
			for u in at_home:
				GameState.pending_tasks[u.id] = _training_task(u)

	if GameState.current_event_uses_formation():
		var fighters: Array[Unit] = GameState.combat_participants()
		for i in range(mini(SLOT_ORDER.size(), fighters.size())):
			GameState.formation[SLOT_ORDER[i]] = fighters[i].id


func _maybe_launch_expedition() -> void:
	# Quiet-week heuristic: keep one expedition in flight every few weeks so
	# the Tick return path (regional gather, explore reveal) stays exercised,
	# while leaving enough bodies home that a surprise Home Battle isn't empty.
	if GameState.current_event in [EventKind.AWAY_BATTLE, EventKind.HOME_BATTLE]:
		return
	if not GameState.expeditions.is_empty() or GameState.week % 3 != 1:
		return
	var at_home: Array[Unit] = GameState.at_home_units()
	if at_home.size() < 4:
		return
	# Send the weakest squire — never the knight (index 0 of the roster).
	var pick: Unit = null
	for u in at_home:
		if u.unit_class == Unit.UnitClass.KNIGHT:
			continue
		if pick == null or u.stats.sum() < pick.stats.sum():
			pick = u
	if pick == null:
		return
	var ids: Array[int] = [pick.id]

	var explore_tile: MapTile = _nearest_unknown_frontier_tile()
	if explore_tile != null:
		GameState.launch_expedition(Expedition.Kind.EXPLORE, explore_tile.x, explore_tile.y, ids)
		return
	var gather_tile: MapTile = _nearest_gatherable_tile()
	if gather_tile != null:
		GameState.launch_expedition(Expedition.Kind.GATHER, gather_tile.x, gather_tile.y, ids)


# ---------- policy helpers ----------

func _training_task(u: Unit) -> String:
	return Unit.TASK_TRAIN_PREFIX + _lowest_stat(u)


func _lowest_stat(u: Unit) -> String:
	var best_key: String = Stats.STAT_KEYS[0]
	var best_val: int = u.stats.get_value(best_key)
	for k in Stats.STAT_KEYS:
		var v: int = u.stats.get_value(k)
		if v < best_val:
			best_val = v
			best_key = k
	return best_key


func _best_duelist(units: Array[Unit]) -> Unit:
	var best: Unit = null
	var best_score: int = -1
	for u in units:
		var score: int = u.stats.strength + u.stats.bravery + u.stats.swordsmanship
		if score > best_score:
			best_score = score
			best = u
	return best


func _weakest_known_castle() -> Castle:
	var best: Castle = null
	for c in GameState.world.castles:
		var tile: MapTile = GameState.world.get_tile(c.x, c.y)
		if tile == null or tile.knowledge != MapTile.Knowledge.EXPLORED:
			continue
		if best == null or c.difficulty < best.difficulty:
			best = c
	return best


# Passable UNKNOWN tile bordering an EXPLORED one (the fog frontier), nearest
# to town — same candidates the player sees greyed-in on the map.
func _nearest_unknown_frontier_tile() -> MapTile:
	return _nearest_tile(func(t: MapTile) -> bool:
		return t.knowledge == MapTile.Knowledge.UNKNOWN \
			and t.is_passable() \
			and MapTile.is_fogged_in(GameState.world, t.x, t.y))


func _nearest_gatherable_tile() -> MapTile:
	return _nearest_tile(func(t: MapTile) -> bool:
		return t.knowledge == MapTile.Knowledge.EXPLORED \
			and t.is_passable() \
			and t.gather_table_id() != "" \
			and t.active_expedition == null)


func _nearest_tile(predicate: Callable) -> MapTile:
	var best: MapTile = null
	var best_dist: int = 999
	for y in range(World.SIZE):
		for x in range(World.SIZE):
			var t: MapTile = GameState.world.get_tile(x, y)
			if t == null or not predicate.call(t):
				continue
			var dist: int = maxi(absi(x - 7), absi(y - 7))   # Chebyshev from town (7,7)
			if dist < best_dist:
				best_dist = dist
				best = t
	return best


# ---------- UI probe ----------

# Plays one run like _play_run, but instantiates the real screen scenes at the
# moments the player would see them: knight chooser at run start, planning /
# roster / knight overview at week start, pre-battle after the tick, weekly
# summary after resolution, game-over (or run-win) at the end. Instantiation
# runs each screen's _ready against live state — node-path breaks, renderer
# crashes, and bad assumptions print SCRIPT ERROR lines that tools/smoke.sh
# fails on (in-game, watch the console). Probes a subset of weeks to stay
# fast, but always the first three, tournament weeks, and the final week.
#
# NOTE for in-game use: probed screens are added as children of this node and
# WILL flash over whatever is on screen for a few frames. That's expected.
func _ui_probe_run(seed_value: int, max_weeks: int) -> int:
	_emit("[smoke] UI probe — instantiating real screens against a live run (seed %d)" % seed_value)
	var fails: int = 0

	GameState.start_run(seed_value)
	GameState.knight_candidates = RosterGenerator.roll_knight_candidates()
	GameState.starting_squires = RosterGenerator.roll_starting_squires()
	fails += await _probe_screen("res://scenes/screens/knight_chooser.tscn")
	GameState.roster = RosterGenerator.build_starting_roster(
		GameState.knight_candidates[0], GameState.starting_squires)
	GameState.roll_current_event()

	var probed: int = 0
	for _i in range(max_weeks):
		var probe_this_week: bool = GameState.week <= 3 \
			or GameState.week % 5 == 0 or GameState.week % 12 == 0

		_plan_week()
		if probe_this_week:
			fails += await _probe_screen("res://scenes/screens/planning.tscn")
			fails += await _probe_screen("res://scenes/screens/roster_view.tscn")
			GameState.focused_unit_id = GameState.roster[0].id
			fails += await _probe_screen("res://scenes/screens/knight_overview.tscn")

		for u in GameState.roster:
			if u.is_on_expedition():
				continue
			u.current_task = GameState.pending_tasks.get(u.id, Unit.TASK_DEFEND)
		GameState.phase_machine.transition(PhaseMachine.Phase.TICK)
		Tick.apply(GameState)

		if probe_this_week:
			fails += await _probe_screen("res://scenes/screens/pre_battle_review.tscn")

		GameState.phase_machine.transition(PhaseMachine.Phase.RESOLUTION)
		var result = Resolution.run(GameState)
		if not result is Dictionary:
			_emit("[smoke]   UI probe: Resolution failed at week %d" % GameState.week)
			return fails + 1
		if not GameState.merchant_offers.is_empty() and GameState.merchant_pick < 0:
			Crafting.accept_caravan_offer(GameState, 0)

		if result.get("is_game_over", false):
			fails += await _probe_screen("res://scenes/screens/game_over.tscn")
			# The naive policy never wins the Grand Tournament, so run_win
			# would otherwise have zero coverage. It only reads formatted
			# GameState fields (week, reputation, castles), all still valid
			# here — probe it for crash coverage even though the run was lost.
			fails += await _probe_screen("res://scenes/screens/run_win.tscn")
			break
		if result.get("is_run_win", false):
			fails += await _probe_screen("res://scenes/screens/run_win.tscn")
			break

		if probe_this_week:
			fails += await _probe_screen("res://scenes/screens/weekly_summary.tscn")
			probed += 1

		GameState.append_history_entry()
		GameState.wrap_week()
		GameState.phase_machine.transition(PhaseMachine.Phase.PLANNING)
		GameState.roll_current_event()

	if fails == 0:
		_emit("[smoke] UI probe OK — %d probe week(s), all screens instantiated cleanly" % probed)
	return fails


# Instantiate one screen scene, give it a few frames to run _ready, fades,
# and deferred work, then free it. Returns 1 on a hard failure (scene failed
# to load/instantiate); script errors inside the screen surface as SCRIPT
# ERROR lines for the wrapper's grep.
func _probe_screen(scene_path: String) -> int:
	var ps: PackedScene = load(scene_path)
	if ps == null:
		_emit("[smoke]   UI probe: could not load %s" % scene_path)
		return 1
	var node: Node = ps.instantiate()
	if node == null:
		_emit("[smoke]   UI probe: could not instantiate %s" % scene_path)
		return 1
	add_child(node)
	for _f in range(3):
		await get_tree().process_frame
	node.queue_free()
	await get_tree().process_frame
	return 0


# ---------- checks & reporting ----------

func _check_invariants(week_before: int) -> String:
	if GameState.week != week_before + 1:
		return "week did not advance (%d → %d)" % [week_before, GameState.week]
	if GameState.roster.size() != 4:
		return "roster size %d != 4 at week %d" % [GameState.roster.size(), GameState.week]
	if GameState.gold < 0:
		return "negative gold (%d) at week %d" % [GameState.gold, GameState.week]
	for u in GameState.roster:
		if u.current_task == Unit.TASK_EXPEDITION:
			var found: bool = false
			for e in GameState.expeditions:
				if e.id == u.expedition_id:
					found = true
					break
			if not found:
				return "%s stuck on expedition task with no live expedition (week %d)" % [
					u.unit_name, GameState.week]
	return ""


func _roster_stat_sum() -> int:
	var total: int = 0
	for u in GameState.roster:
		total += u.stats.sum()
	return total


func _fail(out: Dictionary, reason: String) -> Dictionary:
	out["ok"] = false
	out["fail"] = reason
	out["outcome"] = "error"
	return out


func _summary_line(r: Dictionary) -> String:
	# growth = visible stat points gained across the roster — cheap pacing
	# telemetry for the DEV_PACE knobs ahead of the 8c balance harness.
	return "%-8s  %2dw  W/L %d/%d  growth +%d" % [
		str(r["outcome"]), int(r["weeks"]), int(r["wins"]), int(r["losses"]),
		int(r["growth"])]


func _emit_trace_diff(a: String, b: String) -> void:
	var la: PackedStringArray = a.split("\n")
	var lb: PackedStringArray = b.split("\n")
	for i in range(mini(la.size(), lb.size())):
		if la[i] != lb[i]:
			_emit("[smoke]   first divergence at line %d:" % i)
			_emit("[smoke]     run A: %s" % la[i])
			_emit("[smoke]     run B: %s" % lb[i])
			return
	_emit("[smoke]   traces differ in length: %d vs %d lines" % [la.size(), lb.size()])
