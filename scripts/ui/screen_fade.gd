class_name ScreenFade
extends RefCounted

# Tiny shared helper so every screen can fade in on _ready with one call:
#
#   func _ready() -> void:
#       ScreenFade.fade_in(self)
#
# Matches the staggered fade aesthetic that weekly_summary already uses,
# but applied as a single quick wash on screen entry rather than section
# by section. Keep the duration short (~0.22s) so input feel stays snappy.

const DEFAULT_DURATION: float = 0.22


static func fade_in(target: CanvasItem, duration: float = DEFAULT_DURATION) -> Tween:
	target.modulate.a = 0.0
	var tween: Tween = target.create_tween()
	tween.tween_property(target, "modulate:a", 1.0, duration)
	return tween
