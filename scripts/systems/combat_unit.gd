class_name CombatUnit
extends RefCounted

# The bridge between the strategy layer (Unit.stats) and the tactical combat
# simulation. All combat-layer stats are derived once at construction from the
# unit's current strategy stats plus their equipped weapon and armour.
#
# Only current_hp and current_morale change during a combat run. Everything
# else is read-only after _derive() so a combat can be safely re-run from a
# fresh CombatUnit without mutating the source Unit.
#
# Strategy stat → combat role (every stat has a purpose):
#
#   Strength     → max_hp, damage bonus, armour_value (wearing heavy gear)
#   Speed        → initiative order, dodge_chance
#   Technique    → hit_chance, crit_chance
#   Bravery      → max_hp, morale_pool
#   Swordsmanship → melee hit_chance, block_chance (parry)
#   Archery      → ranged hit_chance
#   Determination → morale_pool
#
# Reserved for future expansion:
#   Leadership   → ally morale aura
#   Intimidation → enemy morale pressure
#   Loyalty      → morale break resistance
#   Etiquette    → post-combat terms / reward modifier
#   Horsemanship → mounted combat speed and charge bonus


var unit:   Unit
var weapon: Dictionary   # entry from Weapon.CATALOGUE
var armour: Dictionary   # entry from Armour.CATALOGUE

# --- Derived at construction (read-only during combat) ---

var max_hp:          int
var initiative:      int     # determines turn order; higher goes first
var hit_chance:      float   # 0–1 probability to land a blow
var dodge_chance:    float   # 0–1 probability to avoid a landed blow
var block_chance:    float   # 0–1 probability to stop a non-dodged hit
var crit_chance:     float   # 0–1 probability to deal a critical hit
var crit_multiplier: float   # damage multiplier on a critical hit
var damage_min:      int     # minimum raw damage roll
var damage_max:      int     # maximum raw damage roll
var armour_value:    int     # flat damage reduction per hit (after dodge/block)
var morale_pool:     int     # morale HP — future system

# --- Mutable during combat ---

var current_hp:     int
var current_morale: int


func _init(p_unit: Unit, weapon_id: String = "", armour_id: String = "") -> void:
	unit = p_unit
	var wid: String = weapon_id if weapon_id != "" else p_unit.weapon_id
	var aid: String = armour_id if armour_id != "" else p_unit.armour_id
	weapon = Weapon.get_entry(wid if wid != "" else "unarmed")
	armour = Armour.get_entry(aid if aid != "" else "unarmoured")
	_derive()


func _derive() -> void:
	var s: Stats = unit.stats
	var skill: int = s.get_value(weapon.get("primary_skill", "swordsmanship"))

	# Health pool: Strength for body, Bravery for fighting spirit / pain tolerance.
	max_hp = s.strength * 3 + s.bravery * 2
	current_hp = max_hp

	# Initiative: Speed is the primary driver; Technique and weapon skill add
	# precision that also translates to reaction time.
	initiative = s.speed * 2 + s.technique + skill

	# Hit chance: a flat base + Technique (accuracy) + weapon primary skill +
	# the weapon's own hit_bonus (reach, balance, etc.).
	hit_chance = clampf(
		0.50
		+ float(s.technique) * 0.010
		+ float(skill)        * 0.015
		+ float(weapon.get("hit_bonus", 0)) * 0.01,
		0.20, 0.95
	)

	# Dodge: Speed for raw movement; Swordsmanship contributes because knowing
	# how strikes land helps you avoid them. Heavy armour impairs movement.
	dodge_chance = clampf(
		0.05
		+ float(s.speed)          * 0.018
		+ float(s.swordsmanship)  * 0.004
		- float(armour.get("dodge_penalty", 0)) * 0.010,
		0.02, 0.60
	)

	# Block: armour's passive guard + Swordsmanship (active parry / shield use).
	block_chance = clampf(
		float(armour.get("block_chance", 0.0))
		+ float(s.swordsmanship) * 0.005,
		0.00, 0.40
	)

	# Crit: Technique for precision strikes + weapon's own crit profile.
	crit_chance = clampf(
		0.03
		+ float(s.technique) * 0.008
		+ float(weapon.get("crit_bonus", 0.0)),
		0.01, 0.40
	)
	crit_multiplier = 1.5

	# Damage: weapon base + Strength bonus (raw power behind the swing).
	var str_bonus: int = floori(float(s.strength) / 3.5)
	damage_min = weapon.get("damage_min", 1) + floori(float(str_bonus) * 0.7)
	damage_max = weapon.get("damage_max", 2) + str_bonus

	# Armour value: base protection + Strength contribution (wearing heavy gear
	# effectively requires physical ability).
	armour_value = armour.get("base_rating", 0) + floori(float(s.strength) / 6.0)

	morale_pool    = s.bravery * 3 + s.determination * 2
	current_morale = morale_pool


func is_alive() -> bool:
	return current_hp > 0


func hp_percent() -> float:
	if max_hp <= 0:
		return 0.0
	return float(current_hp) / float(max_hp)


func roll_damage() -> int:
	return RNG.randi_range(damage_min, max(damage_min, damage_max))


func describe() -> String:
	return (
		"%s [%s / %s]  HP:%d/%d  Init:%d  Hit:%.0f%%  Dodge:%.0f%%  Block:%.0f%%  Crit:%.0f%%  Arm:%d  Dmg:%d-%d"
		% [
			unit.unit_name,
			weapon.get("name", "?"),
			armour.get("name", "?"),
			current_hp, max_hp,
			initiative,
			hit_chance   * 100.0,
			dodge_chance * 100.0,
			block_chance * 100.0,
			crit_chance  * 100.0,
			armour_value,
			damage_min, damage_max,
		]
	)
