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

# Build a short personalised ballad about the household, weighted toward the
# Knight's chronicle data: oath_kind shapes the opening line, earned epithet
# (or trait if none) shapes the middle, household reputation band shapes the
# close. Always returns at least one line. Used by the `bard_ballad` story
# event's special effect; could be reused by future "minstrel arrives" beats.
static func generate_household_ballad(gs: Node) -> String:
	var knight: Unit = null
	for u in gs.roster:
		if u.unit_class == Unit.UnitClass.KNIGHT:
			knight = u
			break
	if knight == null:
		return "The bard's song trails off — there is no knight in residence to write of."

	const OPENERS_BY_OATH: Dictionary = {
		"loyalty":       "Hear of {n}, who kept faith while the gate yet held —",
		"bravery":       "Hear of {n}, who in three campaigns did not turn his back —",
		"determination": "Hear of {n}, who rose from every floor he was put upon —",
		"leadership":    "Hear of {n}, who ate after his men and rode before them —",
		"swordsmanship": "Hear of {n}, whose blade was drawn for cause and sheathed for result —",
		"archery":       "Hear of {n}, whose every arrow could be answered for —",
		"strength":      "Hear of {n}, who carried what others could not and asked no credit —",
		"etiquette":     "Hear of {n}, who conducted himself as the chronicler watched —",
		"speed":         "Hear of {n}, who was never where the danger expected him —",
		"technique":     "Hear of {n}, whose precision was a quieter mercy —",
		"horsemanship":  "Hear of {n}, who never rode harder than his horse could bear —",
		"intimidation":  "Hear of {n}, who spoke when silence would not serve —",
	}
	var opener: String = str(OPENERS_BY_OATH.get(knight.oath_kind, "Hear of {n}, sworn knight of an unsung household —"))
	opener = opener.replace("{n}", knight.unit_name)

	# Middle line — earned epithet first, then trait, then a fallback that
	# leans on the household. Each pool offers two phrasings so repeated
	# ballads about the same knight read differently across runs.
	var middle: String = ""
	if knight.epithet != "":
		const EPITHET_MIDDLES: Array[String] = [
			"who the chroniclers call {ep}, and rightly so —",
			"who rode the lists till heralds called him {ep} —",
			"who is known in three valleys now as {ep} —",
		]
		middle = EPITHET_MIDDLES[RNG.randi_range(0, EPITHET_MIDDLES.size() - 1)].replace("{ep}", knight.epithet)
	elif knight.trait_id != "":
		# Trait-flavoured middles, indexed by the trait pool's id.
		const TRAIT_MIDDLES: Dictionary = {
			"veteran":         "whose veteran's hands knew the field before the ballad was written —",
			"hot_headed":      "whose hot blood made the village inn the longer for him —",
			"pious":           "whose small book of prayers travelled with him everywhere —",
			"tournament_brat": "whose lists-trained eye saw every herald's blind spot —",
			"scholar_knight":  "whose council was always the cooler for being last to speak —",
			"horse_born":      "who rode strange horses for the pleasure of the lesson —",
			"marked":          "whose long scar told its story before he did —",
			"lucky":           "whose coin came down the right way more than chance allowed —",
			"sworn_defender":  "whose oath was witnessed under a vow he will not name —",
			"reluctant":       "who came to arms by inheritance and stayed by choice —",
			"poacher":         "whose arrows had a way of finding what he chose to seek —",
			"stoic":           "whose silence under pressure tested the patience of his enemies —",
			"silver_tongue":   "whose words ended quarrels his sword would have made worse —",
			"haunted":         "whose dreams woke him before any horn ever did —",
		}
		middle = str(TRAIT_MIDDLES.get(knight.trait_id, "whose household closed around him through hard winters —"))
	else:
		middle = "whose household closed around him through hard winters —"

	# Close — reputation-band weighted. Plays as the verdict of the realm.
	var rep_label: String = ResourceDB.reputation_label(gs.reputation)
	const CLOSE_BY_BAND: Dictionary = {
		"Legendary":     "and his name is sung at the small fires of every village in the realm.",
		"Renowned":      "and three valleys over the smaller halls sing of him by name.",
		"Respected":     "and the neighbouring lords now write his name carefully in their books.",
		"Known":         "and the chronicler keeps a fresh quill near, for what is yet to come.",
		"Suspect":       "and the chronicler keeps the entry brief, for what may yet be undone.",
		"Disreputable":  "and the bard's voice trails off here, mid-verse, for politeness.",
		"Outcast":       "and the bard, on second thought, accepts only a smaller fee for the song.",
	}
	var close: String = str(CLOSE_BY_BAND.get(rep_label, "and what comes next, the chronicler will be the first to write."))

	return "%s\n%s\n%s" % [opener, middle, close]


# Closing reflection written by the chronicler at run-end. `outcome` is
# either "win" (Grand Tournament victory) or "loss" (Home Battle defeat).
# Composes 3 lines: tone-set, household summary, closing verdict. Drawn
# from oath_kind / reputation band / castles-taken / streak. Used by the
# game_over and run_win screens.
static func generate_run_epitaph(gs: Node, outcome: String) -> String:
	var knight: Unit = null
	for u in gs.roster:
		if u.unit_class == Unit.UnitClass.KNIGHT:
			knight = u
			break

	# Opener — tone differs sharply by outcome.
	var opener: String
	if outcome == "win":
		const WIN_OPENERS: Array[String] = [
			"The chronicler set down the final entry with care: the household had not just survived its year — it had earned the song they would write of it.",
			"The chronicler closed the year's book with a flourish he allowed only on rare occasions. The realm had been won; the household had been the winning.",
			"It is the chronicler's privilege to write rarely in the high style. He took it this evening.",
		]
		opener = WIN_OPENERS[RNG.randi_range(0, WIN_OPENERS.size() - 1)]
	else:
		const LOSS_OPENERS: Array[String] = [
			"The chronicler wrote with a quiet hand: the gate had fallen, but the household had not broken — only ended.",
			"The chronicler closed the book without a flourish. There would be other households, and other knights, and other chroniclers; this one was over.",
			"What the chronicler wrote that night, he wrote slowly. The household had given more than it took, and the household had been taken in turn.",
		]
		opener = LOSS_OPENERS[RNG.randi_range(0, LOSS_OPENERS.size() - 1)]

	# Middle — household summary keyed off the Knight's oath / standing.
	var middle: String
	if knight != null:
		var rep_label: String = ResourceDB.reputation_label(gs.reputation)
		var oath_clause: String = _oath_summary_clause(knight.oath_kind, outcome)
		middle = "%s rode under the chronicler's pen as %s, %s in the realm's accounting." % [
			knight.unit_name,
			oath_clause,
			rep_label,
		]
	else:
		middle = "The household closed the year without a knight in its name."

	# Close — final verdict, dependent on outcome + castles-taken / streak.
	var castles_taken: int = 8 - (gs.world.castles.size() if gs.world != null else 8)
	var close: String
	if outcome == "win":
		close = "Of the eight castles set against the realm, %d were taken. The Grand Tournament was won. The chronicler closes the book." % castles_taken
	else:
		var streak_note: String = ""
		if gs.tournament_streak > 0:
			streak_note = " The tournament streak stood at %d when the gate fell." % gs.tournament_streak
		close = "Of the eight castles set against the realm, %d were taken before the end.%s" % [castles_taken, streak_note]

	return "%s\n\n%s\n\n%s" % [opener, middle, close]


# Helper for generate_run_epitaph — turns the Knight's oath_kind into a
# short phrase the chronicler can drop mid-sentence ("...as the keeper of
# faith, Respected in the realm's accounting").
static func _oath_summary_clause(oath_kind: String, _outcome: String) -> String:
	const OATH_PHRASES: Dictionary = {
		"loyalty":       "the keeper of faith",
		"bravery":       "the unbroken-backed",
		"determination": "the riser-from-floors",
		"leadership":    "the man who ate after his men",
		"swordsmanship": "the careful blade",
		"archery":       "the answerable arrow",
		"strength":      "the unsung carrier",
		"etiquette":     "the watched-by-the-chronicler",
		"speed":         "the not-where-expected",
		"technique":     "the quiet precision",
		"horsemanship":  "the patient rider",
		"intimidation":  "the man who let silence serve",
	}
	return str(OATH_PHRASES.get(oath_kind, "a sworn knight of the household"))


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

	# Chronicler aside — a 22% chance per week of a short atmospheric
	# parenthetical that has nothing to do with the week's main events.
	# Builds the sense of a household with a life beyond the player's
	# direct attention. Pure flavour, no mechanical effect.
	if RNG.randf_range(0.0, 1.0) < 0.22:
		parts.append(_chronicler_aside())

	return " ".join(parts)


# A pool of one-line atmospheric beats the chronicler quietly inserts into
# a week's chronicle entry. Each is fragment-scaled to read inline with the
# rest of the prose. Players see them as the household having an interior
# life — the kitchen acquires a cat, the marshal receives a letter, the
# chaplain loses an argument about ale rationing.
static func _chronicler_aside() -> String:
	const ASIDES: Array[String] = [
		"(The kitchen acquired a new cat this week. The old one is unimpressed.)",
		"(The marshal received a letter he will not discuss.)",
		"(The chaplain lost an argument about ale rationing — narrowly, and with grace.)",
		"(The stable lad has begun writing poems. Reviews are mixed.)",
		"(The chronicler's quill split mid-entry on Thursday. He swore in three languages.)",
		"(The household acquired three barrels of an excellent vintage at an inexplicable price.)",
		"(A neighbouring lord's hound wandered through, ate three meals, and departed without comment.)",
		"(The orchard wall settled half an inch in the rain. The mason has been notified.)",
		"(The smith's apprentice produced a passable horseshoe. The smith is allowing himself a small pride.)",
		"(The chaplain has finished his commentary on a minor saint nobody had heard of. Self-published.)",
		"(The watch reported a comet, then admitted it was a lantern, then revised back to a comet.)",
		"(One of the household's two dogs has begun limping. He limps less when food is in question.)",
		"(The seneschal's daughter has returned from her cousin's. The household notes this without commenting on it.)",
		"(A barrel of pickled cabbage went missing from the storeroom. The chronicler suspects the chaplain.)",
		"(The marshal has shaved his beard. Reviews are mixed; the marshal is taking it well.)",
		"(The cat caught a mouse and was praised. The cat was unmoved.)",
		"(A travelling fiddler stopped one night and was paid in soup.)",
		"(The chronicler discovered an old map in a back drawer and has been distracted ever since.)",
		"(A pair of swallows have nested in the upper eaves. The marshal has forbidden anyone to disturb them.)",
		"(The blacksmith's mother visited for three days. The household was on its best behaviour.)",
	]
	return ASIDES[RNG.randi_range(0, ASIDES.size() - 1)]


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
		"{n} took his vows in a chapel his grandfather built and his father lost. The chapel is still there. The land around it is not.",
		"Twice promised, twice freed — {n}'s first engagement died of a fever and his second of a politics. He arrived here travelling light and travelling alone.",
		"{n} earned his spurs in a campaign nobody now remembers, against an enemy nobody now names. His commander died of old age. The lessons did not.",
		"A bastard acknowledged late but acknowledged in writing, {n} carries the household seal alongside his own. He uses both sparingly, and never together.",
		"{n} spent six years in a foreign court as a hostage-pageboy. Came home reading three languages, weighing his words in all of them, and trusting none of his audience.",
		"Lost his first lord at the Bone Ford, his second to plague, and his third to a quarrel he refuses to discuss. He is in no hurry to acquire a fourth.",
		"{n} returned from a pilgrimage four years late, wearing different armour and not explaining the difference. The household chronicler has stopped asking.",
		"Raised on a frontier estate where every passing year brought either fire or famine, {n} learned to fight before to read and reads now with the patience of a man who learned both late.",
		"{n} spent his youth in the lists and his manhood at the border. He still has the cheekbones of the lists and the hands of the border.",
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
		"A village reeve's clever boy, {n} keeps the household ledgers in his head and the household quarrels in his hand. So far the ledger is winning.",
		"{n} grew up on a tournament circuit, holding horses and counting purses. He knows the lists already; he is still learning the field.",
		"Sent in lieu of taxes by a holding too poor to pay them, {n} arrived with an absurdly polite letter and a slightly less polite mother behind him.",
		"A foundling raised in a hedge-knight's care, {n} learned the forms one summer at a time. The summers were never quite long enough.",
		"{n} talked his way past the gatekeeper, the steward, and the chamberlain before someone had the sense to put a sword in his hand and a roof over his head.",
		"A poacher's son with the eyes of a hawk and the reflexes of a hare, {n} has never missed a target he chose to aim at. Choosing is the hard part.",
		"{n} came down from the hill country with two letters of grievance, one of recommendation, and a knack for staying out of arguments he didn't start.",
		"The runt of a large fighting family, {n} has spent his childhood being beaten by his older brothers and is grateful, in retrospect, for the calibration.",
	]

	var pool: Array[String] = (
		ORIGINS_KNIGHT if unit.unit_class == Unit.UnitClass.KNIGHT else ORIGINS_SQUIRE
	)
	return pool[RNG.randi_range(0, pool.size() - 1)].replace("{n}", unit.unit_name)


static func generate_banner(unit: Unit) -> String:
	# Each charge is keyed by its tincture so we can enforce the rule of
	# tincture: a metal (or / argent) is never placed on a metal, and a
	# colour (gules / azure / sable / vert) is never placed on a colour.
	# `charge_template` substitutes the chosen tincture at "%s".
	const CHARGES: Dictionary = {
		"strength":      {"template": "a tower %s",          "metal_tincture": "argent", "colour_tincture": "sable"},
		"speed":         {"template": "a chevron %s",        "metal_tincture": "or",     "colour_tincture": "azure"},
		"technique":     {"template": "an arrow %s",         "metal_tincture": "or",     "colour_tincture": "sable"},
		"bravery":       {"template": "a lion rampant %s",   "metal_tincture": "or",     "colour_tincture": "gules"},
		"loyalty":       {"template": "a chain linked %s",   "metal_tincture": "or",     "colour_tincture": "sable"},
		"determination": {"template": "an anvil %s",         "metal_tincture": "argent", "colour_tincture": "sable"},
		"swordsmanship": {"template": "a sword in pale %s",  "metal_tincture": "argent", "colour_tincture": "gules"},
		"archery":       {"template": "a bow bent %s",       "metal_tincture": "or",     "colour_tincture": "sable"},
		"horsemanship":  {"template": "a horse passant %s",  "metal_tincture": "argent", "colour_tincture": "sable"},
		"leadership":    {"template": "a pennant %s",        "metal_tincture": "or",     "colour_tincture": "gules"},
		"etiquette":     {"template": "a cup %s",            "metal_tincture": "or",     "colour_tincture": "gules"},
		"intimidation":  {"template": "a gauntlet %s",       "metal_tincture": "argent", "colour_tincture": "sable"},
	}
	const FIELD_BY_STAT: Dictionary = {
		"strength":      "gules",
		"speed":         "azure",
		"technique":     "vert",
		"bravery":       "sable",
		"loyalty":       "argent",
		"determination": "sable",
		"swordsmanship": "gules",
		"archery":       "vert",
		"horsemanship":  "azure",
		"leadership":    "or",
		"etiquette":     "argent",
		"intimidation":  "sable",
	}
	const METALS: Array[String] = ["or", "argent"]

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

	# Field tincture comes from the SECOND stat (or the top one if there's only
	# one) — that's the background colour the charge sits on.
	var field_tincture: String = FIELD_BY_STAT.get(sec_stat if sec_stat != "" else top_stat, "sable")
	var field_is_metal: bool = METALS.has(field_tincture)

	# Pick the charge's tincture to CONTRAST with the field (rule of tincture).
	var charge1_def: Dictionary = CHARGES.get(top_stat, {"template": "a cross %s", "metal_tincture": "or", "colour_tincture": "sable"})
	var charge1_tinct: String = charge1_def["colour_tincture"] if field_is_metal else charge1_def["metal_tincture"]
	var charge1: String = (charge1_def["template"] as String) % charge1_tinct

	if sec_stat == "" or sec_stat == top_stat:
		return "%s on %s." % [charge1.capitalize(), field_tincture]

	# Second charge contrasts with the field too (same rule). It joins as
	# "and a ...", so it's read against the field, not against charge1.
	var charge2_def: Dictionary = CHARGES.get(sec_stat, charge1_def)
	var charge2_tinct: String = charge2_def["colour_tincture"] if field_is_metal else charge2_def["metal_tincture"]
	var charge2: String = (charge2_def["template"] as String) % charge2_tinct

	# Avoid repeating the same charge phrase when top_stat and sec_stat happen
	# to share both template and tincture pick.
	if charge2 == charge1:
		return "%s on %s." % [charge1.capitalize(), field_tincture]
	return "%s on %s, and %s." % [charge1.capitalize(), field_tincture, charge2]


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

	return OATHS.get(derive_oath_kind(unit), "I will serve as I have sworn, and in serving find my worth.")


# Oath kind = the stat key that drove oath text selection. Stored on
# `Unit.oath_kind` so `OathLedger` can check honour conditions without
# re-deriving (and without being thrown off when the unit's highest stat
# shifts during play — the oath you swore is the oath you keep).
static func derive_oath_kind(unit: Unit) -> String:
	var best_stat: String = ""
	var best_val: int = 0
	for key in Stats.STAT_KEYS:
		var v: int = unit.stats.get_value(key)
		if v > best_val:
			best_val = v
			best_stat = key
	return best_stat


# ---------- Epithet granting ----------

# Valid event tag keys for grant_epithet(). Resolution.gd references these
# constants so a typo is a compile error, not a silent no-op.
const TAG_TOURNAMENT_WIN:       String = "tournament_win"
const TAG_GRAND_TOURNAMENT_WIN: String = "grand_tournament_win"
const TAG_DUEL_WIN:             String = "duel_win"
const TAG_HOME_BATTLE_SURVIVED: String = "home_battle_survived"
const TAG_HOME_BATTLE_WON:      String = "home_battle_won"
const TAG_PILLAGE_WIN:          String = "pillage_win"
const TAG_ASSAULT_WIN:          String = "assault_win"

static func grant_epithet(unit: Unit, event_tag: String) -> void:
	# One epithet per unit; don't overwrite an earned one.
	if unit.epithet != "":
		return

	const EPITHETS: Dictionary = {
		"tournament_win":          [
			"the Steadfast", "the Lance", "the Day's Victor", "the Listed",
			"the Held-Field", "the Crested", "the Banner-Marshal",
		],
		"grand_tournament_win":    [
			"the Realm-Winner", "Victor of the Grand", "the Champion",
			"the Crowned-in-Steel", "the Sung-Of",
		],
		"duel_win":                [
			"the Duelist", "the Quiet Lance", "the Answerer",
			"the Counter-Strike", "the Sure-Hand",
		],
		"home_battle_survived":    [
			"the Bulwark", "the Wall", "the Unfleeing", "the Last-Standing",
		],
		"home_battle_won":         [
			"the Defender", "the Gate-Holder", "the Hearth-Keeper",
			"the Threshold-Won",
		],
		"pillage_win":             [
			"the Bold", "the Opportunist", "the Far-Rider", "the Tax-Taker",
		],
		"assault_win":             [
			"the Castle-Taker", "the Resolved", "the Breaker-of-Gates",
			"the Tower-Climber",
		],
	}

	var pool: Array = EPITHETS.get(event_tag, [])
	if pool.is_empty():
		return
	unit.epithet = pool[RNG.randi_range(0, pool.size() - 1)]
