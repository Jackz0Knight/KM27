class_name OathLedger
extends RefCounted

# Per-unit oath honour checks. Each Unit carries a sworn oath text plus an
# `oath_kind` string (the stat key the oath was drawn from at creation —
# see `Chronicle.derive_oath_kind`). At the end of every week, OathLedger
# inspects what each unit did and grants a hidden +3 PA bonus to those
# whose actions aligned with their oath sentence.
#
# Design choices for v1:
#   * Positive-only — no break penalties yet. Players see only "X honoured
#     his oath this week" lines on the Weekly Summary; missing the honour
#     trigger costs nothing. Break penalties are a future pass.
#   * PA bonus is hidden (GDD §10) — the chronicle note is the only visible
#     signal; the bonus accumulates and pays off later when stat-grow events
#     hit the PA ceiling.
#   * Checks lean on cheap, observable signals from the unit / GameState /
#     last_battle_result / last_tick_results — no new bookkeeping fields.
#
# Called from `Resolution.run()` after the event is fully resolved, so all
# the read-from sources are populated.

const HONOUR_PA_BONUS: int = 3


# Scan the roster, grant +3 PA to each unit who honoured their oath this
# week, and append a one-line chronicle note per honoured unit to
# result["notes"]. Returns the list of honoured units' names for caller
# debugging / extending.
static func check_roster(gs: Node, result: Dictionary) -> Array[String]:
	var honoured: Array[String] = []
	for u in gs.roster:
		if u.oath_kind == "":
			continue
		if not _check_oath_honoured(u, gs, result):
			continue
		u.potential_ability += HONOUR_PA_BONUS
		honoured.append(u.unit_name)
		result["notes"].append("⚜ %s honoured his oath this week." % u.unit_name)
	return honoured


# Dispatch table — match the unit's oath_kind against the cheap weekly
# signal that maps to its sentence. Returns true on honour, false on
# neither honour nor break (no break path in v1).
static func _check_oath_honoured(unit: Unit, gs: Node, result: Dictionary) -> bool:
	match unit.oath_kind:
		"loyalty":
			# "I will not break faith while my lord yet draws breath."
			# Defending the homestead while at home reads as kept faith.
			return unit.is_at_home() and unit.current_task == Unit.TASK_DEFEND
		"bravery":
			# "I will not turn my back on an enemy who stands."
			# Participated in a winning combat without taking an injury.
			return _was_in_combat(unit, result) and bool(result.get("won", false)) and not _was_injured(unit, result)
		"determination":
			# "I will rise from whatever floor I am put upon."
			# Trained a stat this week — even if the cap blocked it, the
			# attempt counts ("rise from the floor" = the effort, not the
			# success).
			return _trained_this_week(unit, gs)
		"swordsmanship":
			# "I will not draw without cause and will not sheathe without result."
			# In a winning formation combat AND slot-matched in a melee slot
			# (Yellow / Red).
			return _slot_matched_in_win(unit, gs, result, ["yellow", "red"])
		"archery":
			# "I will loose no arrow I am not prepared to answer for."
			# Slot-matched in Green during a winning formation combat.
			return _slot_matched_in_win(unit, gs, result, ["green"])
		"horsemanship":
			# "I will not ride harder than my horse can bear."
			# On expedition or away party this week (riding, not sitting).
			return unit.is_on_expedition() or _was_in_away_party(unit, gs)
		"leadership":
			# "I will see the men under me fed before I eat."
			# Held the Blue slot in a winning formation combat.
			return _slot_matched_in_win(unit, gs, result, ["blue"])
		"etiquette":
			# "I will conduct myself as if the chronicler watches, because he does."
			# Tournament participant in a winning tournament — the listed
			# context is the most chronicler-watched there is.
			return _tournament_won_with_unit(unit, result)
		"strength":
			# "I will carry what others cannot and ask no credit for it."
			# On a gather expedition this week (carrying things home is
			# the literal honour).
			return _on_gather_expedition(unit, gs)
		"speed":
			# "I will not be where danger expects me to be."
			# In any combat this week without taking an injury.
			return _was_in_combat(unit, result) and not _was_injured(unit, result)
		"technique":
			# "I will be precise, because precision is a form of mercy."
			# Trained AND the training actually applied (cap + PA didn't block).
			return _trained_successfully(unit, gs)
		"intimidation":
			# "I will not speak first when silence will serve."
			# Participated in any formation combat (intimidation contribution
			# applies automatically). The unit's mere presence honoured it.
			return _was_in_formation_combat(unit, result)
	return false


# ---------- signal helpers ----------

# True if the unit appears in the formation per_unit, the sim's combatant
# stats, tournament per_unit, or duel slot in the most recent battle result.
static func _was_in_combat(unit: Unit, result: Dictionary) -> bool:
	for entry in result.get("per_unit", []):
		if int(entry.get("unit_id", -1)) == unit.id:
			return true
	if _fought_in_sim(unit, result):
		return true
	for entry in result.get("tournament_per_unit", []):
		if int(entry.get("unit_id", -1)) == unit.id:
			return true
	if int(result.get("duel_unit_id", -1)) == unit.id:
		return true
	return false


static func _was_in_formation_combat(unit: Unit, result: Dictionary) -> bool:
	for entry in result.get("per_unit", []):
		if int(entry.get("unit_id", -1)) == unit.id:
			return true
	# Sim path: only formation battles store a sim_result, so fighting in the
	# sim IS formation combat (tournaments and duels never set it).
	return _fought_in_sim(unit, result)


# True if the unit took part in this week's CombatSim run on the player side.
# `_fill_from_sim` stores the whole sim result; combatant_stats carries one
# entry per fighter. This is the participation signal for formation battles —
# result["per_unit"] is deliberately empty on the sim path (the old
# strategy-layer breakdown was never migrated), which silently killed every
# oath that read it until the 2026-06-10 audit.
static func _fought_in_sim(unit: Unit, result: Dictionary) -> bool:
	var sim: Dictionary = result.get("sim_result", {})
	for entry in sim.get("combatant_stats", []):
		if str(entry.get("side", "")) == "player" and int(entry.get("unit_id", -1)) == unit.id:
			return true
	return false


# True if the unit took an injury during this week's resolution. Reads from
# result["injuries"], which Tick + Resolution both populate.
static func _was_injured(unit: Unit, result: Dictionary) -> bool:
	for inj in result.get("injuries", []):
		if int(inj.get("unit_id", -1)) == unit.id:
			return true
	return false


# True if the unit was slot-matched in a formation slot that won this week.
# `allowed_slots` is the list of slot keys that count for this oath
# (e.g. ["yellow", "red"] for swordsmanship).
#
# Two sources, because the sim path leaves per_unit empty (see _fought_in_sim):
#   1. per_unit entries with a fired slot_bonus (legacy strategy-layer shape,
#      kept for when the breakdown migrates back).
#   2. Sim fallback: the unit fought, the win landed, gs.formation assigned
#      them an allowed slot, and Combat.is_slot_match says they fit it. The
#      slot doesn't reach the sim's math yet (CLAUDE.md Known Issues), but the
#      oath is about keeping one's sworn role on a winning field — assignment
#      + fitness is the honest signal available today.
static func _slot_matched_in_win(unit: Unit, gs: Node, result: Dictionary, allowed_slots: Array) -> bool:
	if not bool(result.get("won", false)):
		return false
	for entry in result.get("per_unit", []):
		if int(entry.get("unit_id", -1)) != unit.id:
			continue
		if not allowed_slots.has(str(entry.get("slot", ""))):
			return false
		# Slot match means the slot_bonus contribution fired.
		return int(entry.get("slot_bonus", 0)) > 0
	if not _fought_in_sim(unit, result):
		return false
	for slot_key in allowed_slots:
		if int(gs.formation.get(slot_key, -1)) == unit.id:
			return Combat.is_slot_match(unit, str(slot_key))
	return false


# True if this unit was a tournament participant and the tournament was won.
static func _tournament_won_with_unit(unit: Unit, result: Dictionary) -> bool:
	if not bool(result.get("won", false)):
		return false
	for entry in result.get("tournament_per_unit", []):
		if int(entry.get("unit_id", -1)) == unit.id:
			return true
	return false


# True if the unit's task this week was a training task (TASK_TRAIN_*).
static func _trained_this_week(unit: Unit, _gs: Node) -> bool:
	return unit.is_training()


# True if the unit's training this week was productive — under staged
# development that means it gained a point OR made hidden progress (i.e. it
# wasn't blocked by a cap / potential). The oath honours the *act* of diligent
# training, not the rare week the integer happens to tick.
static func _trained_successfully(unit: Unit, gs: Node) -> bool:
	var tick: Dictionary = gs.last_tick_results
	for entry in tick.get("training", []):
		if int(entry.get("unit_id", -1)) == unit.id:
			return bool(entry.get("applied", false)) or bool(entry.get("developing", false))
	return false


# True if the unit is currently on a Gather expedition.
static func _on_gather_expedition(unit: Unit, gs: Node) -> bool:
	if not unit.is_on_expedition():
		return false
	for exped in gs.expeditions:
		if exped.id == unit.expedition_id:
			return exped.kind == Expedition.Kind.GATHER
	return false


# True if the unit was a member of the away party committed for an away
# battle this week.
static func _was_in_away_party(unit: Unit, gs: Node) -> bool:
	return gs.pending_away_party.has(unit.id)
