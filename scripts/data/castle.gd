class_name Castle
extends Resource

# A castle placed on the world during gen (GDD §4). Difficulty and the reward
# bundle are both rolled at world gen and never change afterward — so the
# player can see what's on offer when planning an assault.
#
# `reward` is a Dictionary keyed by ResourceDB ids (e.g. {"logs": 3,
# "iron_ore": 2}). WorldGenerator pre-rolls it from a terrain-aware
# `RewardTableDB` table scaled by `difficulty / 100` so a difficulty-200
# castle pays twice a difficulty-100 castle, and a mountain castle drops
# ore instead of cloth.
#
# `reward_table` records which table the reward was rolled from. Used for
# display ("Mountain loot") and for save round-tripping if we later want
# to re-roll on load.

var x: int = 0
var y: int = 0
var difficulty: int = 100
var reward: Dictionary = {}
var reward_table: String = ""


func _init(
	p_x: int = 0,
	p_y: int = 0,
	p_difficulty: int = 100,
	p_reward: Dictionary = {},
	p_reward_table: String = "",
) -> void:
	x = p_x
	y = p_y
	difficulty = p_difficulty
	reward = p_reward.duplicate(true) if not p_reward.is_empty() else {}
	reward_table = p_reward_table


func describe() -> String:
	return "Castle (%d,%d) diff=%d reward=[%s]" % [x, y, difficulty, ResourceDB.describe(reward)]
