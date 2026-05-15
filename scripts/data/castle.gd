class_name Castle
extends Resource

# A castle placed on the world during gen (GDD §4). Difficulty and reward
# bundle are both rolled at world gen and never change afterward.

var x: int = 0
var y: int = 0
var difficulty: int = 100
var reward: ResourceBundle = null


func _init(p_x: int = 0, p_y: int = 0, p_difficulty: int = 100, p_reward: ResourceBundle = null) -> void:
	x = p_x
	y = p_y
	difficulty = p_difficulty
	reward = p_reward if p_reward != null else ResourceBundle.new()


func describe() -> String:
	return "Castle (%d,%d) diff=%d reward=[%s]" % [x, y, difficulty, reward.describe()]
