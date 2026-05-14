extends Control


func _ready() -> void:
	print("[KM27] Main scene ready. Year %d, Week %d." % [GameState.year, GameState.week])
	print("[KM27] Starting resources: %s" % GameState.resources)
