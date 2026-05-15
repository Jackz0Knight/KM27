class_name ResourceBundle
extends Resource

# T1 resource trio per GDD §14. Wraps the three counters so Pillage / Assault /
# Tournament / Gather / event rewards all add and subtract through one helper
# instead of duplicating field names.

const KEYS: Array[String] = ["wood", "fibres", "copper_ore"]

var wood: int = 0
var fibres: int = 0
var copper_ore: int = 0


func _init(p_wood: int = 0, p_fibres: int = 0, p_copper_ore: int = 0) -> void:
	wood = p_wood
	fibres = p_fibres
	copper_ore = p_copper_ore


func add(other: ResourceBundle) -> void:
	wood += other.wood
	fibres += other.fibres
	copper_ore += other.copper_ore


# Returns false (and leaves the bundle untouched) if the caller can't cover the cost.
func subtract(other: ResourceBundle) -> bool:
	if wood < other.wood or fibres < other.fibres or copper_ore < other.copper_ore:
		return false
	wood -= other.wood
	fibres -= other.fibres
	copper_ore -= other.copper_ore
	return true


func scaled(factor: float) -> ResourceBundle:
	return ResourceBundle.new(
		roundi(wood * factor),
		roundi(fibres * factor),
		roundi(copper_ore * factor),
	)


func is_empty() -> bool:
	return wood == 0 and fibres == 0 and copper_ore == 0


func to_dict() -> Dictionary:
	return {"wood": wood, "fibres": fibres, "copper_ore": copper_ore}


func duplicate_bundle() -> ResourceBundle:
	return ResourceBundle.new(wood, fibres, copper_ore)


func describe() -> String:
	return "Wood:%d Fibres:%d Copper:%d" % [wood, fibres, copper_ore]
