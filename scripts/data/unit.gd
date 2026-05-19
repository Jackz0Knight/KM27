class_name Unit
extends Resource

# A roster member per GDD §9. The MVP roster is fixed at 4 (1 Knight + 3 Squires)
# and never grows or shrinks. Task / expedition state lives here too — what the
# unit is doing this week.

enum UnitClass { SQUIRE, KNIGHT }

# Task strings used by Planning / Tick / Battle Resolution:
#   "idle"           - default; equivalent to "defend" if a home battle hits
#   "defend"         - full power in any home-resolving combat
#   "train:<stat>"   - training, +1 to the named stat on Tick (PA-capped)
#   "expedition"    - unit is on `expedition_id`; not at home
const TASK_IDLE: String = "idle"
const TASK_DEFEND: String = "defend"
const TASK_EXPEDITION: String = "expedition"
const TASK_TRAIN_PREFIX: String = "train:"

var id: int = 0
var unit_name: String = ""
var unit_class: UnitClass = UnitClass.SQUIRE
var stats: Stats = null
var potential_ability: int = 100
var current_task: String = TASK_IDLE
var expedition_id: int = -1
# Each entry: {"stat": String, "weeks_remaining": int}. Decremented by Tick.
var injuries: Array = []

# Chronicle enrichment — populated at unit creation by RosterGenerator.
# epithet: earned through events ("the Steadfast", "the Duelist", etc.)
# banner_line: heraldic descriptor derived from top 2 stats.
# origin_text: backstory paragraph shown on the Knight Overview screen.
# oath: a single sworn sentence; honoring/breaking has stat consequences.
var epithet: String = ""
var banner_line: String = ""
var origin_text: String = ""
var oath: String = ""

# Household + body type — rolled at unit creation by RosterGenerator. Drives
# the visual crest rendered by BannerIcon plus the implicit stat lean.
# Body type rolls independently of house (a Brann knight can still be Lean).
# See `scripts/data/house_pool.gd` and `scripts/data/body_type.gd`.
var house_id: String = ""
var body_type: String = ""

# Equipment — string IDs into Weapon.CATALOGUE and Armour.CATALOGUE.
# Defaults to "" (CombatUnit falls back to "unarmed" / "unarmoured").
var weapon_id: String = ""
var armour_id: String = ""


func _init(
	p_id: int = 0,
	p_name: String = "",
	p_class: UnitClass = UnitClass.SQUIRE,
	p_stats: Stats = null,
	p_pa: int = 100,
) -> void:
	id = p_id
	unit_name = p_name
	unit_class = p_class
	stats = p_stats if p_stats != null else Stats.new()
	potential_ability = p_pa


func is_on_expedition() -> bool:
	return expedition_id >= 0


func is_at_home() -> bool:
	return not is_on_expedition()


func is_training() -> bool:
	return current_task.begins_with(TASK_TRAIN_PREFIX)


# Returns the stat key the unit is training this week, or "" if not training.
func training_target() -> String:
	if not is_training():
		return ""
	return current_task.substr(TASK_TRAIN_PREFIX.length())


func class_label() -> String:
	match unit_class:
		UnitClass.KNIGHT: return "Knight"
		UnitClass.SQUIRE: return "Squire"
	return "Unit"


func is_injured() -> bool:
	return not injuries.is_empty()


func injured_stats() -> Array[String]:
	var out: Array[String] = []
	for inj in injuries:
		out.append(inj["stat"])
	return out


# Apply a temporary −1 injury to a random stat for 1–2 weeks.
func apply_random_injury() -> Dictionary:
	var roll: int = RNG.randi_range(0, Stats.STAT_KEYS.size() - 1)
	var stat: String = Stats.STAT_KEYS[roll]
	var duration: int = RNG.randi_range(1, 2)
	injuries.append({"stat": stat, "weeks_remaining": duration})
	return {"stat": stat, "weeks_remaining": duration}


func describe() -> String:
	var task_label: String = current_task
	if is_on_expedition():
		task_label = "expedition #%d" % expedition_id
	return "%s %s [%s] task=%s stats=[%s]" % [
		class_label(), unit_name, "PA?", task_label, stats.describe(),
	]
