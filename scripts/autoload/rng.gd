extends Node

# Seedable RNG wrapper so world gen and run-time rolls can be reproduced for
# debugging. Use this autoload instead of `randi()` / `randf()` directly.

var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


func seed_run(seed_value: int) -> void:
	rng.seed = seed_value


func randi_range(a: int, b: int) -> int:
	return rng.randi_range(a, b)


func randf_range(a: float, b: float) -> float:
	return rng.randf_range(a, b)
