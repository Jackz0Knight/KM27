extends Control

# Phase 2 dev tool. Runs `weeks` Planning-phase event rolls with a pinned seed
# and reports the tally. Verifies:
#   • Tournament weeks (every 12th) always produce a Tournament or Grand
#     Tournament event.
#   • Non-tournament weeks split among the three base kinds.
#   • Streak >= 2 substitutes a Grand Tournament for the next Tournament slot.
#
# Run with F6 in the editor.

@export var test_seed: int = 1627
@export var weeks: int = 50

@onready var output: RichTextLabel = $Scroll/Output


func _ready() -> void:
	var report: String = _run_simulation()
	output.text = "[code]%s[/code]" % report
	print(report)


func _run_simulation() -> String:
	RNG.seed_run(test_seed)

	var lines: PackedStringArray = PackedStringArray()
	lines.append("KM27 — event_roll_test")
	lines.append("seed = %d, weeks = %d" % [test_seed, weeks])
	lines.append("")

	var tally: Dictionary = {
		EventKind.AWAY_BATTLE: 0,
		EventKind.HOME_BATTLE: 0,
		EventKind.BATTLE_EVENT: 0,
		EventKind.TOURNAMENT: 0,
		EventKind.GRAND_TOURNAMENT: 0,
	}

	# Simulate winning every tournament so the streak rises and we'll see a
	# Grand Tournament substitution at week 36 (after w12 + w24 wins).
	var streak: int = 0
	var streak_violations: Array = []

	for w in range(1, weeks + 1):
		var kind: int = EventRoller.roll(w, streak)
		tally[kind] += 1

		var marker: String = ""
		if Calendar.is_tournament_week(w):
			# The roll must be Tournament or Grand on these weeks.
			if not EventKind.is_tournament(kind):
				streak_violations.append("week %d is tournament-week but rolled %s" % [w, EventKind.label(kind)])
		if kind == EventKind.TOURNAMENT:
			streak += 1
			marker = " [win → streak=%d]" % streak
		elif kind == EventKind.GRAND_TOURNAMENT:
			marker = " [GRAND!]"

		lines.append("week %2d (year %d, w/y %2d): %s%s" % [
			w, Calendar.year_for(w), Calendar.week_of_year(w),
			EventKind.label(kind), marker,
		])

	lines.append("")
	lines.append("Tally:")
	for k in [
		EventKind.AWAY_BATTLE, EventKind.HOME_BATTLE, EventKind.BATTLE_EVENT,
		EventKind.TOURNAMENT, EventKind.GRAND_TOURNAMENT,
	]:
		lines.append("  %-18s %d" % [EventKind.label(k) + ":", tally[k]])

	lines.append("")
	var v: Array = _validate(tally, weeks, streak_violations)
	if v.is_empty():
		lines.append("[ok] All Phase 2 checks passed.")
	else:
		lines.append("[!! VIOLATIONS] (%d):" % v.size())
		for vv in v:
			lines.append("  - " + vv)

	return "\n".join(lines)


func _validate(tally: Dictionary, n_weeks: int, streak_violations: Array) -> Array:
	var v: Array = []

	var expected_tournament_weeks: int = n_weeks / Calendar.TOURNAMENT_INTERVAL
	var tournament_total: int = int(tally[EventKind.TOURNAMENT]) + int(tally[EventKind.GRAND_TOURNAMENT])
	if tournament_total != expected_tournament_weeks:
		v.append("Tournament+Grand total = %d, expected %d." % [tournament_total, expected_tournament_weeks])

	var non_tournament_total: int = (
		int(tally[EventKind.AWAY_BATTLE])
		+ int(tally[EventKind.HOME_BATTLE])
		+ int(tally[EventKind.BATTLE_EVENT])
	)
	if non_tournament_total != n_weeks - expected_tournament_weeks:
		v.append("Non-tournament total = %d, expected %d." % [non_tournament_total, n_weeks - expected_tournament_weeks])

	# With streak rising on each Tournament win, week 36 should be Grand.
	if n_weeks >= 36 and int(tally[EventKind.GRAND_TOURNAMENT]) < 1:
		v.append("Expected at least one Grand Tournament by week 36 (streak rises on simulated wins).")

	for sv in streak_violations:
		v.append(sv)

	return v
