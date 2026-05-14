class_name EventKind
extends RefCounted

# Identifies a weekly event per GDD §6. Kept as plain int constants so they
# survive across Resource serialisation and can be compared with `==` cheaply.

const AWAY_BATTLE: int = 0
const HOME_BATTLE: int = 1
const BATTLE_EVENT: int = 2
const TOURNAMENT: int = 3
const GRAND_TOURNAMENT: int = 4


static func label(kind: int) -> String:
	match kind:
		AWAY_BATTLE: return "Away Battle"
		HOME_BATTLE: return "Home Battle"
		BATTLE_EVENT: return "Battle Event"
		TOURNAMENT: return "Tournament"
		GRAND_TOURNAMENT: return "Grand Tournament"
	return "Unknown"


static func is_tournament(kind: int) -> bool:
	return kind == TOURNAMENT or kind == GRAND_TOURNAMENT
