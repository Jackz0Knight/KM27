class_name EnemyActor
extends RefCounted

# A combat-layer enemy unit, duck-typed to satisfy CombatUnit's interface.
# CombatUnit reads .id, .unit_name, .stats, .weapon_id, .armour_id — this
# class provides exactly those fields so enemies and player Units are
# interchangeable inside the simulation.

var id: int = 0
var unit_name: String = ""
var stats: Stats = null
var weapon_id: String = "unarmed"
var armour_id: String = "unarmoured"
var type_id: String = ""


func _init(
	p_id: int,
	p_name: String,
	p_type_id: String,
	p_stats: Stats,
	p_weapon_id: String = "unarmed",
	p_armour_id: String = "unarmoured",
) -> void:
	id        = p_id
	unit_name = p_name
	type_id   = p_type_id
	stats     = p_stats
	weapon_id = p_weapon_id
	armour_id = p_armour_id
