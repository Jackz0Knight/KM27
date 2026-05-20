extends Control

# GDD §2 Win screen — reached only by winning a Grand Tournament. Shows run
# summary and offers a fresh start.

@onready var stats_pane: VBoxContainer = $Center/VBox/Stats
@onready var new_run_btn: Button = $Center/VBox/NewRunBtn


func _ready() -> void:
	new_run_btn.pressed.connect(_on_new_run)
	_render()
	ScreenFade.fade_in(self, 0.6)


func _render() -> void:
	for c in stats_pane.get_children():
		c.queue_free()
	_add("Year %d, Week %d (week %d/48)" % [
		GameState.current_year(), GameState.week, GameState.current_week_of_year(),
	])
	_add("Castles taken: %d / 8" % _castles_taken())
	_add("Stores at the close: Gold %d · %s" % [GameState.gold, _describe_inventory()])
	_add("Final roster:")
	for u in GameState.roster:
		_add("  • %s — %s, stat total %d" % [u.unit_name, u.class_label(), u.stats.sum()])

	EventBus.run_ended.emit("win")


func _castles_taken() -> int:
	if GameState.world == null:
		return 0
	return 8 - GameState.world.castles.size()


func _add(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_pane.add_child(lbl)


func _describe_inventory() -> String:
	var parts: Array[String] = []
	for id: String in GameState.inventory:
		var amt: int = GameState.inventory[id]
		if amt > 0:
			var entry: Dictionary = ResourceDB.RESOURCES.get(id, {})
			parts.append("%s×%d" % [entry.get("name", id), amt])
	if parts.is_empty():
		return "nothing"
	return ", ".join(parts)


func _on_new_run() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
