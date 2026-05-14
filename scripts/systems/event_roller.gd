class_name EventRoller
extends RefCounted

# Picks the event kind for a given week per GDD §6:
#   • Tournament weeks (12, 24, 36, ...) → Tournament, or Grand Tournament when
#     the player is on a 2-win streak.
#   • Other weeks → uniform pick among Away Battle, Home Battle, Battle Event.
#
# All randomness routes through the RNG autoload so test scenes can pin a seed.

const BASE_KINDS: Array = [
	EventKind.AWAY_BATTLE,
	EventKind.HOME_BATTLE,
	EventKind.BATTLE_EVENT,
]


static func roll(week: int, tournament_streak: int) -> int:
	if Calendar.is_tournament_week(week):
		if tournament_streak >= 2:
			return EventKind.GRAND_TOURNAMENT
		return EventKind.TOURNAMENT
	return BASE_KINDS[RNG.randi_range(0, BASE_KINDS.size() - 1)]
