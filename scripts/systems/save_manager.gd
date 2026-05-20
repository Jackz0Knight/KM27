extends Node

# Save/load system. Serialises GameState to user://savegame.json.
# Also persists cross-run history in user://run_history.json.
#
# Auto-save is triggered by planning.gd before each Tick. Manual save is
# available via the dev toolbar.

const SAVE_PATH: String = "user://savegame.json"
const HISTORY_PATH: String = "user://run_history.json"

# Loaded once at startup; persists across runs.
var run_history: Array[Dictionary] = []


func _ready() -> void:
	_load_run_history()


# ---------- public API ----------

func save_game() -> void:
	if not GameState.has_active_run():
		return
	var data: Dictionary = _serialise_state()
	_write_json(SAVE_PATH, data)


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


# Lightweight metadata sniff for the Title-screen "Continue" confirm dialog
# and any future save-slot UI. Returns {} when no save exists. Reading the
# whole file is fine — saves are small.
func peek_save() -> Dictionary:
	if not has_save():
		return {}
	var data: Dictionary = _read_json(SAVE_PATH)
	if data.is_empty():
		return {}
	var week: int = int(data.get("week", 1))
	return {
		"week": week,
		"year": Calendar.year_for(week),
		"week_of_year": Calendar.week_of_year(week),
		"gold": int(data.get("gold", 0)),
		"tournament_streak": int(data.get("tournament_streak", 0)),
	}


func load_game() -> bool:
	if not has_save():
		return false
	var data: Dictionary = _read_json(SAVE_PATH)
	if data.is_empty():
		return false
	_restore_state(data)
	return true


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# Append a completed run entry and persist immediately.
func append_run_history(entry: Dictionary) -> void:
	run_history.append(entry)
	_write_json(HISTORY_PATH, {"history": run_history})


# ---------- serialisation ----------

func _serialise_state() -> Dictionary:
	var roster_data: Array = []
	for u in GameState.roster:
		var stats_data: Dictionary = {}
		for k in Stats.STAT_KEYS:
			stats_data[k] = u.stats.get_value(k)
		roster_data.append({
			"id": u.id,
			"unit_name": u.unit_name,
			"unit_class": int(u.unit_class),
			"stats": stats_data,
			"potential_ability": u.potential_ability,
			"current_task": u.current_task,
			"expedition_id": u.expedition_id,
			"injuries": u.injuries.duplicate(true),
			"house_id": u.house_id,
			"body_type": u.body_type,
			"epithet": u.epithet,
			"banner_line": u.banner_line,
			"origin_text": u.origin_text,
			"oath": u.oath,
			"weapon_id": u.weapon_id,
			"armour_id": u.armour_id,
			"trait_id": u.trait_id,
		})

	var expeditions_data: Array = []
	for exped in GameState.expeditions:
		expeditions_data.append({
			"id": exped.id,
			"kind": int(exped.kind),
			"target_x": exped.target_x,
			"target_y": exped.target_y,
			"weeks_remaining": exped.weeks_remaining,
			"unit_ids": exped.unit_ids.duplicate(),
		})

	# Serialise explored tiles (just which ones are known)
	var explored_tiles: Array = []
	if GameState.world != null:
		for x in range(15):
			for y in range(15):
				var tile: MapTile = GameState.world.get_tile(x, y)
				if tile != null and tile.knowledge == MapTile.Knowledge.EXPLORED:
					explored_tiles.append({"x": x, "y": y})

	# Serialise castles remaining
	var castles_data: Array = []
	if GameState.world != null:
		for castle in GameState.world.castles:
			castles_data.append({"x": castle.x, "y": castle.y})

	return {
		"version": 1,
		"week": GameState.week,
		"gold": GameState.gold,
		"tournament_streak": GameState.tournament_streak,
		"current_event": GameState.current_event,
		"current_battle_event": GameState.current_battle_event,
		"inventory": GameState.inventory.duplicate(),
		"researched": GameState.researched.duplicate(),
		"maintenance_debt": GameState.maintenance_debt,
		"gold_income_sources": GameState.gold_income_sources.duplicate(),
		"suppressed_confirms": GameState.suppressed_confirms.duplicate(),
		"crafted_ids": GameState.crafted_ids.duplicate(),
		"item_stockpile": GameState.item_stockpile.duplicate(true),
		"world_seed": _world_seed(),
		"explored_tiles": explored_tiles,
		"castles_remaining": castles_data,
		"roster": roster_data,
		"expeditions": expeditions_data,
		"default_defense_formation": GameState.default_defense_formation.duplicate(),
		"default_attack_formation": GameState.default_attack_formation.duplicate(),
		"run_history": GameState.run_history.duplicate(true),
		"intro_shown_for_run": GameState.intro_shown_for_run,
	}


func _world_seed() -> int:
	# WorldGenerator stamps the seed onto the World instance; pull it back out
	# so loading regenerates the same terrain (otherwise the saved explored
	# tiles and castles get re-applied on top of a brand-new random map).
	if GameState.world != null:
		return GameState.world.seed_value
	return 0


# ---------- restore ----------

func _restore_state(data: Dictionary) -> void:
	# Regenerate the world from the saved seed so terrain, castle layout, and
	# anything else WorldGenerator places end up identical to the run that was
	# saved. Pre-seed-fix saves stored 0 and lose their original world; in
	# that case we roll a fresh seed and rely on the saved explored/castle
	# state to patch what we can.
	var has_seed: bool = data.has("world_seed") and int(data.get("world_seed", 0)) != 0
	var seed_val: int = int(data.get("world_seed", 0)) if has_seed else randi()
	GameState.start_run(seed_val)

	GameState.week = int(data.get("week", 1))
	GameState.gold = int(data.get("gold", 100))
	GameState.tournament_streak = int(data.get("tournament_streak", 0))
	GameState.current_event = int(data.get("current_event", -1))
	GameState.current_battle_event = str(data.get("current_battle_event", ""))
	GameState.maintenance_debt = bool(data.get("maintenance_debt", false))
	GameState.intro_shown_for_run = bool(data.get("intro_shown_for_run", false))

	GameState.inventory = {}
	var inv = data.get("inventory", {})
	for k in inv:
		GameState.inventory[str(k)] = int(inv[k])

	GameState.researched.clear()
	for k in data.get("researched", []):
		GameState.researched.append(str(k))

	var gis = data.get("gold_income_sources", {})
	for k in gis:
		GameState.gold_income_sources[str(k)] = int(gis[k])

	GameState.suppressed_confirms.clear()
	for k in data.get("suppressed_confirms", []):
		GameState.suppressed_confirms.append(str(k))

	GameState.crafted_ids.clear()
	for k in data.get("crafted_ids", []):
		GameState.crafted_ids.append(str(k))

	GameState.item_stockpile.clear()
	for entry in data.get("item_stockpile", []):
		if not (entry is Dictionary):
			continue
		var slot: String = str(entry.get("slot", ""))
		var id: String = str(entry.get("id", ""))
		if slot == "" or id == "":
			continue
		GameState.item_stockpile.append({"slot": slot, "id": id})

	var def_d = data.get("default_defense_formation", {})
	for k in def_d:
		GameState.default_defense_formation[str(k)] = int(def_d[k])
	var def_a = data.get("default_attack_formation", {})
	for k in def_a:
		GameState.default_attack_formation[str(k)] = int(def_a[k])

	# Apply explored tiles
	var explored = data.get("explored_tiles", [])
	for et in explored:
		var tile: MapTile = GameState.world.get_tile(int(et["x"]), int(et["y"]))
		if tile != null:
			tile.knowledge = MapTile.Knowledge.EXPLORED

	# Trim castles to match what was saved
	var castles_remaining: Array = data.get("castles_remaining", [])
	var kept: Array = []
	for castle in GameState.world.castles:
		for cr in castles_remaining:
			if int(cr["x"]) == castle.x and int(cr["y"]) == castle.y:
				kept.append(castle)
				break
	GameState.world.castles = kept
	for c in GameState.world.castles:
		var tile: MapTile = GameState.world.get_tile(c.x, c.y)
		if tile != null:
			tile.castle = c

	# Restore roster
	GameState.roster.clear()
	for rd in data.get("roster", []):
		var u := Unit.new(
			int(rd["id"]),
			str(rd["unit_name"]),
			int(rd["unit_class"]) as Unit.UnitClass,
			null,
			int(rd["potential_ability"]),
		)
		var stats := Stats.new()
		for k in rd.get("stats", {}):
			stats.set_value(str(k), int(rd["stats"][k]))
		u.stats = stats
		u.current_task = str(rd.get("current_task", Unit.TASK_DEFEND))
		u.expedition_id = int(rd.get("expedition_id", -1))
		u.injuries = []
		for inj in rd.get("injuries", []):
			u.injuries.append({"stat": str(inj["stat"]), "weeks_remaining": int(inj["weeks_remaining"])})
		# Chronicle + heraldry fields. Lazy-fill house_id and body_type for
		# saves written before the banner system landed so old runs don't
		# show blank crests.
		u.house_id = str(rd.get("house_id", ""))
		if u.house_id == "":
			u.house_id = HousePool.random_house_id()
		u.body_type = str(rd.get("body_type", ""))
		if u.body_type == "":
			u.body_type = BodyType.random_body_type()
		u.epithet = str(rd.get("epithet", ""))
		u.banner_line = str(rd.get("banner_line", ""))
		u.origin_text = str(rd.get("origin_text", ""))
		u.oath      = str(rd.get("oath", ""))
		u.weapon_id = str(rd.get("weapon_id", ""))
		u.armour_id = str(rd.get("armour_id", ""))
		# Trait — only restore valid ids so a renamed/removed trait in a
		# newer build doesn't leave a broken descriptor on a loaded knight.
		var saved_trait: String = str(rd.get("trait_id", ""))
		if saved_trait != "" and TraitPool.is_valid(saved_trait):
			u.trait_id = saved_trait
		GameState.roster.append(u)

	# Restore expeditions
	GameState.expeditions.clear()
	GameState._next_expedition_id = 1
	for ed in data.get("expeditions", []):
		var uids: Array[int] = []
		for uid in ed.get("unit_ids", []):
			uids.append(int(uid))
		var exped := Expedition.new(
			int(ed["id"]),
			int(ed["kind"]) as Expedition.Kind,
			int(ed["target_x"]), int(ed["target_y"]),
			uids,
		)
		exped.weeks_remaining = int(ed["weeks_remaining"])
		GameState.expeditions.append(exped)
		GameState._next_expedition_id = maxi(GameState._next_expedition_id, exped.id + 1)
		var tile: MapTile = GameState.world.get_tile(exped.target_x, exped.target_y)
		if tile != null:
			tile.active_expedition = exped

	# Restore run history
	GameState.run_history.clear()
	for entry in data.get("run_history", []):
		GameState.run_history.append(entry.duplicate())


# ---------- run history ----------

func _load_run_history() -> void:
	run_history.clear()
	if not FileAccess.file_exists(HISTORY_PATH):
		return
	var data: Dictionary = _read_json(HISTORY_PATH)
	for entry in data.get("history", []):
		run_history.append(entry.duplicate())


# ---------- file I/O ----------

func _write_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("[SaveManager] Cannot write to %s" % path)
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var raw: String = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		return parsed
	return {}
