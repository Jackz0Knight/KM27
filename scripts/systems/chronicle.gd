class_name Chronicle
extends RefCounted

# Template-based prose generator for the Week Chronicle and unit enrichment.
# All generation routes through the RNG autoload so the same run state + seed
# always produces the same chronicle entry.
#
# PUBLIC API
#   generate_week_entry(gs)         → String   — full week's chronicle prose
#   generate_origin(unit)           → String   — backstory paragraph
#   generate_banner(unit)           → String   — two-line heraldic descriptor
#   generate_oath(unit)             → String   — single sworn sentence
#   grant_epithet(unit, event_tag)  → void     — one-time epithet on event


# ---------- Season / weather ----------

static func _season_clause(week_of_year: int) -> String:
	const EARLY_SPRING: Array[String] = [
		"The thaw came slow and cold.",
		"Rain filled the ruts and silenced the roads.",
		"The courtyard mud refused to dry.",
		"Ice still clung to the north eaves at noon.",
		"The horses were restless and no one could say why.",
	]
	const LATE_SPRING: Array[String] = [
		"The apple trees came into blossom overnight.",
		"Swallows returned to the eaves of the stable.",
		"A warm week settled over the valley.",
		"The roads firmed and the light came back.",
		"Pollen drifted through the open gate all week.",
	]
	const SUMMER: Array[String] = [
		"The days grew long and the men sweated at their drills.",
		"Dust hung over the roads.",
		"The fields stood green and full.",
		"Heat shimmered off the practice-yard stones by midday.",
		"The well ran low; the cook rationed accordingly.",
	]
	const HARVEST: Array[String] = [
		"The first carts of grain came down from the higher fields.",
		"The smell of cut hay reached even the armoury.",
		"Nights cooled faster now.",
		"The harvest was spoken of in the lower hall — guardedly.",
		"An amber light fell across the yard at evening.",
	]
	const AUTUMN: Array[String] = [
		"Leaves turned gold on the oak by the gatehouse.",
		"The geese flew south in long lines.",
		"Frost touched the well-bucket at dawn.",
		"The light failed earlier each evening.",
		"Mud returned; the yard never truly dried.",
	]
	const WINTER: Array[String] = [
		"Ice formed at the edges of the horse-trough.",
		"The household ate by candlelight before the evening service.",
		"A grey sky settled in and refused to lift.",
		"The fires were fed twice as often and half as warm.",
		"Three men complained of the cold; a fourth said nothing and looked worse.",
	]

	var pool: Array[String]
	if week_of_year <= 6:
		pool = EARLY_SPRING
	elif week_of_year <= 12:
		pool = LATE_SPRING
	elif week_of_year <= 24:
		pool = SUMMER
	elif week_of_year <= 32:
		pool = HARVEST
	elif week_of_year <= 40:
		pool = AUTUMN
	else:
		pool = WINTER

	return pool[RNG.randi_range(0, pool.size() - 1)]


# ---------- Per-unit task lines ----------

static func _unit_line(unit: Unit) -> String:
	var n: String = unit.unit_name

	if unit.is_on_expedition():
		var lines: Array[String] = [
			"%s was a day's ride east, sending no word." % n,
			"Word came that %s's party had not yet turned back." % n,
			"%s was abroad and not expected before the week was out." % n,
			"%s had not been seen since the eastern gate closed behind him." % n,
		]
		return lines[RNG.randi_range(0, lines.size() - 1)]

	if unit.is_training():
		return _training_line(n, unit.training_target())

	if unit.current_task == Unit.TASK_DEFEND:
		var lines: Array[String] = [
			"%s kept the gate." % n,
			"%s walked the walls." % n,
			"%s stood watch and was not tested." % n,
			"%s drilled the watch-rotation twice before breakfast." % n,
			"%s was at his post before the bell and long after it." % n,
		]
		return lines[RNG.randi_range(0, lines.size() - 1)]

	return ""


static func _training_line(n: String, stat: String) -> String:
	const LINES: Dictionary = {
		"strength": [
			"{n} carried stone from the quarry until the hands bled.",
			"{n} spent the week at the weights — stone against muscle.",
			"{n} loaded and unloaded the supply cart until the back refused.",
			"{n} fought the training dummy to splinters and found another one.",
		],
		"speed": [
			"{n} ran the circuit of the walls each morning before the bell.",
			"{n} drilled footwork in the yard until the dust rose waist-high.",
			"{n} did not walk anywhere this week if running was possible.",
			"{n} practised the step-and-lunge until the footing became instinct.",
		],
		"technique": [
			"{n} practised cuts in the far yard until the light failed.",
			"{n} spent the week at the targets, adjusting form after each release.",
			"{n} worked on range and elevation — precision over power.",
			"{n} was meticulous about the follow-through this week.",
		],
		"bravery": [
			"{n} slept without a fire, by choice.",
			"{n} drilled night encounters with the novices, playing the enemy.",
			"{n} ran the fear-exercises — dark spaces, sudden sounds, no warning.",
			"{n} stood in the path of the training charge twice before moving.",
		],
		"loyalty": [
			"{n} tended to the household's less celebrated duties without complaint.",
			"{n} spent the week learning names — stable hands, cooks, the armourer's daughter.",
			"{n} was seen in the lower hall more than usual, listening.",
			"{n} carried messages he was not required to carry and asked nothing for it.",
		],
		"determination": [
			"{n} began each morning with a cold bath and an hour of solitary drill.",
			"{n} failed at something new every day, deliberately, and noted it.",
			"{n} kept a tally of errors and did not share it.",
			"{n} fell three times in the mud and got up without wiping it off.",
		],
		"swordsmanship": [
			"{n} drilled the cut-and-parry until the form was carved into muscle.",
			"{n} fought the practice dummy to splinters and found a second one.",
			"{n} spent the week on the high-bind and the disengage.",
			"{n} sharpened his blade twice and needed to, both times.",
		],
		"archery": [
			"{n} put a hundred arrows into the butts and counted three misses.",
			"{n} drilled the war-draw — speed over accuracy, then accuracy recovered.",
			"{n} fletched arrows at night and shot them the next morning.",
			"{n} was still at the range when the others went to supper.",
		],
		"horsemanship": [
			"{n} schooled the grey on the long-rein for the fourth morning running.",
			"{n} rode before breakfast, after supper, and once in the dark for experience.",
			"{n} spent the week on mounted work — the horse is not yet convinced.",
			"{n} replaced two loose shoes and put twenty miles on the bay without asking permission.",
		],
		"leadership": [
			"{n} drilled the watch in formation changes until the shouting stopped.",
			"{n} ran after-action accounts with the men, asking what they would have done differently.",
			"{n} gave orders and then asked whether they had been clear.",
			"{n} positioned himself where the slowest men could see him and said nothing until they moved.",
		],
		"etiquette": [
			"{n} studied the forms of address for the coming tournament.",
			"{n} dined formally with the household and corrected no one.",
			"{n} wrote letters to three lords who had not written first.",
			"{n} practised the bow until the chamberlain could not fault it.",
		],
		"intimidation": [
			"{n} practised the stillness — neither threat nor submission, just presence.",
			"{n} stood at the gate for the morning count and said nothing.",
			"{n} worked on the bearing, not the voice.",
			"{n} was quieter than usual this week. The effect was noted.",
		],
	}

	var pool: Array = LINES.get(stat, ["{n} trained without remark."])
	var line: String = pool[RNG.randi_range(0, pool.size() - 1)]
	return line.replace("{n}", n)


# ---------- Event / outcome line ----------

static func _event_line(gs: Node) -> String:
	var r: Dictionary = gs.last_battle_result
	if r.is_empty():
		return "The ledger closed without incident."

	if r.get("is_game_over", false):
		return "The household's name was written in the wrong column of someone else's ledger."
	if r.get("is_run_win", false):
		return "The Grand Tournament was won. The chronicler set down his pen and did not know what to write next."

	var ev: int = r.get("event_kind", -1)
	var won: bool = r.get("won", false)
	var fought: bool = r.get("fought", false)
	var sub: String = r.get("sub_event", "")

	match ev:
		EventKind.HOME_BATTLE:
			if fought and won:
				var lines: Array[String] = [
					"The field was held. The household ate well that evening.",
					"They came and were turned. No word of it was sent south.",
					"The wall held. The decision to hold it will be reviewed later.",
				]
				return lines[RNG.randi_range(0, lines.size() - 1)]
			elif fought:
				var lines: Array[String] = [
					"The field was lost. No word of blame was spoken, but none was needed.",
					"They were not stopped. The household is quiet about this.",
					"The breach was brief but it was a breach. That is the word that matters.",
				]
				return lines[RNG.randi_range(0, lines.size() - 1)]
			else:
				return "The horn went unanswered. The eastern column passed unmolested and the household ate in silence."
		EventKind.AWAY_BATTLE:
			if fought and won:
				var lines: Array[String] = [
					"News came from the east before nightfall: a clean victory.",
					"The riders came back with more than they left with.",
					"Word arrived — the field was taken. Details were not provided.",
				]
				return lines[RNG.randi_range(0, lines.size() - 1)]
			elif fought:
				var lines: Array[String] = [
					"The riders came back lighter than they had left.",
					"The away action did not go as planned. The men are back; the ground is not.",
					"They returned before dark. That is something.",
				]
				return lines[RNG.randi_range(0, lines.size() - 1)]
			else:
				return "No orders were given for the away action. The opportunity passed unremarked."
		EventKind.TOURNAMENT:
			if won:
				var lines: Array[String] = [
					"The day was good. The pennant will fly another week.",
					"A tournament won. The household's name was spoken in better company.",
					"The lists went to the household. The streak grows.",
				]
				return lines[RNG.randi_range(0, lines.size() - 1)]
			else:
				var lines: Array[String] = [
					"The field was courteous. The result was not.",
					"The tournament was lost. The streak is broken.",
					"They rode well. It was not enough.",
				]
				return lines[RNG.randi_range(0, lines.size() - 1)]
		EventKind.GRAND_TOURNAMENT:
			if won:
				return "The Grand Tournament was won. The realm is yours."
			else:
				return "The Grand Tournament was lost. The run continues."
		EventKind.BATTLE_EVENT:
			match sub:
				"bandit_ambush":
					if won:
						return "Bandits tested the walls. They did not test them twice."
					else:
						return "Bandits came through. Some things were taken. The household is quiet about it."
				"champion_duel":
					if won:
						return "A duel was called and answered. The matter is settled, for now."
					else:
						return "A duel was called. The outcome will travel on faster horses than the household would prefer."
				"bountiful_harvest":
					return "The fields gave generously — more than could be easily stored."
				"merchant_caravan":
					return "A merchant's train passed through and would not be hurried."

	return "The week passed without particular remark."


# ---------- Full week entry ----------

static func generate_week_entry(gs: Node) -> String:
	var parts: Array[String] = []

	# Header
	var year: int = Calendar.year_for(gs.week)
	var woy: int = Calendar.week_of_year(gs.week)
	parts.append("Week %d, Year %d." % [gs.week, year])

	# Season
	parts.append(_season_clause(woy))

	# Per-unit lines (at most 4)
	var shown: int = 0
	for u in gs.roster:
		if shown >= 4:
			break
		var line: String = _unit_line(u)
		if line != "":
			parts.append(line)
			shown += 1

	# Event outcome
	parts.append(_event_line(gs))

	# Gold note
	if gs.maintenance_debt:
		parts.append("The ledger fell short this week. The household will feel it.")

	return " ".join(parts)


# ---------- Unit enrichment — called once at unit creation ----------

static func generate_origin(unit: Unit) -> String:
	const ORIGINS_KNIGHT: Array[String] = [
		"The third son of a border lord, {n} came to arms through necessity rather than ambition. His earliest campaigns were against hill clans rather than chivalric opponents — it shows in his footwork and his patience.",
		"Raised in a merchant city where every alley required quick feet and quicker thinking, {n} is not a natural knight. He is something rarer: a practised survivor who learned the forms late and the intent early.",
		"A household knight's second son, {n} spent twelve years in a great lord's retinue before circumstance brought him here. He knows the value of a well-placed word and the cost of a carelessly spoken one.",
		"{n} served under a blade-master for seven years and carries the habits — perfect posture, a preference for silence, and a cut that arrives before the decision to cut is made.",
		"Orphaned in a border skirmish, {n} was raised by the garrison that found him — rough men, straight men. He learned warfare as a trade before he learned it as an honour.",
		"The only surviving child of a family that once held more land, {n} carries the habit of ownership and the education of loss. He speaks of the old estate rarely and only when tired.",
		"A tournament knight by training, {n} has more wins in the lists than on the field. He arrived here because the lists grew too comfortable and he recognised the danger in that.",
		"{n} came highly recommended by a lord who could not afford to keep him. The recommendation was sincere; the inability to keep him was more informative.",
		"A younger son of a minor house, {n} holds no inheritance and expects none. What he holds is a sword and an instruction that said, in brief, make something of yourself.",
	]

	const ORIGINS_SQUIRE: Array[String] = [
		"{n} arrived at the household gate with a letter of introduction, a decent horse, and not much else. The letter was genuine.",
		"A miller's son who caught the eye of a passing knight and spent three years learning not to hold a sword like a broom handle — {n} is not yet there, but the direction is right.",
		"{n} was apprenticed briefly to a blacksmith before deciding that working metal was less interesting than carrying it. The blacksmith was not consulted.",
		"The fourth child in a family of modest landholders, {n} came to service because there was not enough inheritance to divide. He has not yet decided if this was fortune or misfortune.",
		"{n} won a novice bout at a regional faire three years ago and has been quietly trading on the reputation since. He is aware this cannot last.",
		"Quiet and technically minded, {n} spent his adolescence in a scriptorium before a priest recommended military service as a cure for excessive stillness. The cure is ongoing.",
		"From the eastern provinces, {n} rides differently than the western-trained knights expect and fights differently than they're ready for. He has stopped explaining this and started using it.",
		"{n} is the newest of the household's additions and the most earnest. The earnestness will either season into something useful or be trained out of him. Both outcomes are acceptable.",
	]

	var pool: Array[String] = (
		ORIGINS_KNIGHT if unit.unit_class == Unit.UnitClass.KNIGHT else ORIGINS_SQUIRE
	)
	return pool[RNG.randi_range(0, pool.size() - 1)].replace("{n}", unit.unit_name)


static func generate_banner(unit: Unit) -> String:
	const CHARGES: Dictionary = {
		"strength":      "a tower argent",
		"speed":         "a chevron azure",
		"technique":     "an arrow or",
		"bravery":       "a lion rampant gules",
		"loyalty":       "a chain linked or",
		"determination": "an anvil sable",
		"swordsmanship": "a sword in pale argent",
		"archery":       "a bow bent sable",
		"horsemanship":  "a horse passant argent",
		"leadership":    "a pennant or",
		"etiquette":     "a cup or",
		"intimidation":  "a gauntlet sable",
	}
	const FIELDS: Dictionary = {
		"strength":      "on gules",
		"speed":         "on azure",
		"technique":     "on vert",
		"bravery":       "on sable",
		"loyalty":       "on argent",
		"determination": "on sable",
		"swordsmanship": "on gules",
		"archery":       "on vert",
		"horsemanship":  "on azure",
		"leadership":    "on or",
		"etiquette":     "on argent",
		"intimidation":  "on sable",
	}

	# Find the two highest stats.
	var top_stat: String = ""
	var top_val: int = 0
	var sec_stat: String = ""
	var sec_val: int = 0
	for key in Stats.STAT_KEYS:
		var v: int = unit.stats.get_value(key)
		if v > top_val:
			sec_stat = top_stat
			sec_val = top_val
			top_stat = key
			top_val = v
		elif v > sec_val:
			sec_stat = key
			sec_val = v

	var charge1: String = CHARGES.get(top_stat, "a cross or")
	var field: String = FIELDS.get(sec_stat if sec_stat != "" else top_stat, "on sable")
	var charge2: String = CHARGES.get(sec_stat, "")

	if charge2 != "" and charge2 != charge1:
		return "%s %s, and %s." % [charge1.capitalize(), field, charge2]
	return "%s %s." % [charge1.capitalize(), field]


static func generate_oath(unit: Unit) -> String:
	const OATHS: Dictionary = {
		"loyalty":       "I will not break faith while my lord yet draws breath.",
		"bravery":       "I will not turn my back on an enemy who stands.",
		"determination": "I will rise from whatever floor I am put upon.",
		"leadership":    "I will see the men under me fed before I eat.",
		"swordsmanship": "I will not draw without cause and will not sheathe without result.",
		"archery":       "I will loose no arrow I am not prepared to answer for.",
		"strength":      "I will carry what others cannot and ask no credit for it.",
		"etiquette":     "I will conduct myself as if the chronicler watches, because he does.",
		"speed":         "I will not be where danger expects me to be.",
		"technique":     "I will be precise, because precision is a form of mercy.",
		"horsemanship":  "I will not ride harder than my horse can bear.",
		"intimidation":  "I will not speak first when silence will serve.",
	}

	# Oath follows the unit's highest stat.
	var best_stat: String = ""
	var best_val: int = 0
	for key in Stats.STAT_KEYS:
		var v: int = unit.stats.get_value(key)
		if v > best_val:
			best_val = v
			best_stat = key

	return OATHS.get(best_stat, "I will serve as I have sworn, and in serving find my worth.")


# ---------- Epithet granting ----------

static func grant_epithet(unit: Unit, event_tag: String) -> void:
	# One epithet per unit; don't overwrite an earned one.
	if unit.epithet != "":
		return

	const EPITHETS: Dictionary = {
		"tournament_win":          ["the Steadfast", "the Lance", "the Day's Victor", "the Listed"],
		"grand_tournament_win":    ["the Realm-Winner", "Victor of the Grand", "the Champion"],
		"duel_win":                ["the Duelist", "the Quiet Lance", "the Answerer"],
		"home_battle_survived":    ["the Bulwark", "the Wall", "the Unfleeing"],
		"home_battle_won":         ["the Defender", "the Gate-Holder"],
		"pillage_win":             ["the Bold", "the Opportunist"],
		"assault_win":             ["the Castle-Taker", "the Resolved"],
	}

	var pool: Array = EPITHETS.get(event_tag, [])
	if pool.is_empty():
		return
	unit.epithet = pool[RNG.randi_range(0, pool.size() - 1)]
