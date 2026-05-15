class_name OutcomeBracket
extends RefCounted

# Outcome probability + colour bracket per the spec.
# Used by Pre-Battle Review, Tactics tab, and expedition forecast.

enum Bracket { GREEN, ORANGE, RED }

const COLOR_GREEN:  Color = Color(0.40, 0.90, 0.40)
const COLOR_ORANGE: Color = Color(0.95, 0.65, 0.20)
const COLOR_RED:    Color = Color(0.95, 0.35, 0.35)

const LABEL_GREEN:  String = "Safe — minor or no injury risk"
const LABEL_ORANGE: String = "Contested — likely success, injury possible"
const LABEL_RED:    String = "Dangerous — high injury/loss risk"


# Sigmoid-weighted win probability from the power ratio.
# ratio = player_power / (player_power + enemy_power)
static func outcome_probability(player_power: int, enemy_power: int) -> float:
	if player_power + enemy_power == 0:
		return 0.5
	var ratio: float = float(player_power) / float(player_power + enemy_power)
	var x: float = (ratio - 0.5) * 10.0
	return 1.0 / (1.0 + exp(-x))


static func bracket_for(player_power: int, enemy_power: int) -> int:
	var prob: float = outcome_probability(player_power, enemy_power)
	if prob >= 0.85:
		return Bracket.GREEN
	elif prob >= 0.50:
		return Bracket.ORANGE
	return Bracket.RED


static func color_for(player_power: int, enemy_power: int) -> Color:
	match bracket_for(player_power, enemy_power):
		Bracket.GREEN:  return COLOR_GREEN
		Bracket.ORANGE: return COLOR_ORANGE
		Bracket.RED:    return COLOR_RED
	return COLOR_RED


static func label_for(player_power: int, enemy_power: int) -> String:
	match bracket_for(player_power, enemy_power):
		Bracket.GREEN:  return LABEL_GREEN
		Bracket.ORANGE: return LABEL_ORANGE
		Bracket.RED:    return LABEL_RED
	return LABEL_RED


# Roll injuries for fighters after an orange/red outcome.
# Modifies units in place. Returns Array[{unit_id, stat, weeks_remaining}].
static func maybe_apply_injuries(fighters: Array, bracket: int) -> Array[Dictionary]:
	var applied: Array[Dictionary] = []
	if bracket == Bracket.GREEN:
		return applied
	# Orange: 35% chance per fighter. Red: 65% chance.
	var chance: float = 0.35 if bracket == Bracket.ORANGE else 0.65
	for u in fighters:
		if RNG.randf_range(0.0, 1.0) < chance:
			var inj: Dictionary = u.apply_random_injury()
			applied.append({"unit_id": u.id, "stat": inj["stat"], "weeks_remaining": inj["weeks_remaining"]})
	return applied
