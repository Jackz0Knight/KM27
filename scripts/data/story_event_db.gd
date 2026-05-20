class_name StoryEventDB
extends RefCounted

# Data-driven story/chronicle events. Each entry is a self-contained beat
# with an intro line (for Pre-Battle Review), weighted outcomes, and a list
# of effect primitives that mutate GameState when the outcome fires.
#
# Adding a new event is a pure data change — drop a new key into EVENTS,
# pick a label + intro, list 2–4 outcomes, and you're done. The resolver
# below already handles all effect kinds; if you need a new one, add it to
# `_apply_effect()` and the EFFECT KINDS comment block below.
#
# How a story event fires:
#   1. EventRoller picks BATTLE_EVENT for the week.
#   2. BattleEvent.roll_sub_type() lands on "story_event" (weighted ~33% of
#      battle event weeks) and asks StoryEventDB to pick an eligible story
#      id for the current GameState.
#   3. GameState.current_battle_event becomes "story:<id>".
#   4. Pre-Battle Review pulls the intro via StoryEventDB.intro_for().
#   5. Resolution dispatches to StoryEventDB.resolve(); a weighted outcome
#      is rolled, effects applied, prose notes appended to the result.
#   6. Weekly Summary surfaces the notes alongside other rewards.
#
# Effect kinds (all keyed by `kind`):
#   {kind: "gold", amount: int}                      — flat gold delta
#   {kind: "gold_range", min: int, max: int}         — rolled gold delta
#   {kind: "random_unit_stat", stat, delta}          — applied to a random
#                                                       at-home unit; +deltas
#                                                       respect PA cap via
#                                                       try_increment, -deltas
#                                                       clamp at 1.
#   {kind: "all_units_stat", stat, delta}            — every at-home unit
#   {kind: "random_unit_injury"}                     — random at-home unit
#                                                       suffers a 1–2w injury
#   {kind: "reward_resources", min: int, max: int}   — rolls a ResourceBundle
#                                                       (legacy MVP triple) and
#                                                       sets result["reward"]
#   {kind: "inventory_add", id, min, max}            — adds N of a resource id
#   {kind: "inventory_remove", id, min, max}         — subtracts N (clamped 0)
#   {kind: "pa_delta", min, max}                     — PA shift on random unit
#   {kind: "clear_injury"}                           — heals the longest
#                                                       running injury on a
#                                                       random injured at-home
#                                                       unit; no-op if no
#                                                       injuries on the roster
#   {kind: "expedition_delay", min, max}             — adds N weeks to a
#                                                       random active
#                                                       expedition's
#                                                       weeks_remaining


# A note about gates:
#   min_week / max_week  : inclusive week range
#   min_gold             : event won't roll if gs.gold < this
#   min_roster_at_home   : requires at least N at-home units to fire
#
# These keep events from arriving at impossible moments (no "broken blade"
# event when the only knight is on expedition; no "tax demand" the player
# can't pay). When all eligible events fail the gates, the gateway falls
# back to a hard-coded sub-type — see BattleEvent.roll_sub_type().

const STORY_PREFIX: String = "story:"


const EVENTS: Dictionary = {
	"plague_year": {
		"label":  "A Sickly Year",
		"intro":  "A fever moves through the household. The cooks burn their hands lighting fires too early; the watch coughs through the small hours.",
		"weight": 4,
		"min_week": 6,
		"outcomes": [
			{
				"weight": 50,
				"note": "The fever passes without taking anyone. The chronicler notes the close call in a small hand and leaves it at that.",
				"effects": [],
			},
			{
				"weight": 30,
				"note": "The fever leaves one of yours weakened — a week abed, a stat dulled, a quiet recovery to come.",
				"effects": [{"kind": "random_unit_injury"}],
			},
			{
				"weight": 20,
				"note": "The fever is kept off the household by the steward's care with broth and shutters. Costs a fistful of coin in herbs.",
				"effects": [{"kind": "gold", "amount": -8}],
			},
		],
	},

	"traveling_minstrel": {
		"label":  "A Travelling Minstrel",
		"intro":  "A minstrel begs lodging at the gate, lute under one arm and a road's worth of dust under the other.",
		"weight": 5,
		"outcomes": [
			{
				"weight": 50,
				"note": "The minstrel sings well of houses he has never seen. The household sleeps easier for it; one of yours sleeps with a better word for the court.",
				"effects": [{"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "The minstrel sings poorly and leaves with more than he came with. The steward will not say what.",
				"effects": [{"kind": "gold", "amount": -6}],
			},
			{
				"weight": 20,
				"note": "He is no minstrel at all — he is a herald, bringing news of a friendly house. A small token is left.",
				"effects": [{"kind": "gold_range", "min": 6, "max": 14}],
			},
		],
	},

	"dispute_in_the_yard": {
		"label":  "A Dispute in the Yard",
		"intro":  "Two of yours come to words over a horse, a girl, or a debt — accounts differ.",
		"weight": 4,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 45,
				"note": "Words become hands; the marshal pulls them apart. No blood, but a bruise to discipline.",
				"effects": [{"kind": "random_unit_stat", "stat": "loyalty", "delta": -1}],
			},
			{
				"weight": 40,
				"note": "The marshal lets them swing. They tire faster than they wound; both come away with more respect for the other than before.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
			{
				"weight": 15,
				"note": "It goes too far. One of yours nurses a long arm and a short temper for a week.",
				"effects": [{"kind": "random_unit_injury"}],
			},
		],
	},

	"wandering_pilgrim": {
		"label":  "A Wandering Pilgrim",
		"intro":  "A robed pilgrim asks shelter, claims to be bound for a shrine no one in the household can place on a map.",
		"weight": 4,
		"outcomes": [
			{
				"weight": 40,
				"note": "He stays the night and is gone by lauds, leaving a blessing scratched into the chapel post in a hand the chaplain admires.",
				"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": 1}],
			},
			{
				"weight": 35,
				"note": "He stays the night and is gone by lauds, taking a silver candlestick with him.",
				"effects": [{"kind": "gold", "amount": -10}],
			},
			{
				"weight": 25,
				"note": "He stays a week. He is no pilgrim — he is an old soldier with nowhere left to go. He leaves with a small purse and a recommendation.",
				"effects": [{"kind": "gold", "amount": -6}, {"kind": "random_unit_stat", "stat": "bravery", "delta": 1}],
			},
		],
	},

	"midnight_messenger": {
		"label":  "A Midnight Messenger",
		"intro":  "A rider hammers at the gate after curfew. The watch lights torches; the steward is woken with a name on a sealed scroll.",
		"weight": 4,
		"min_week": 4,
		"outcomes": [
			{
				"weight": 40,
				"note": "Friendly news, well received. A trader's caravan was warned in time and a small share of the saved cargo finds its way to your steward's table.",
				"effects": [{"kind": "gold_range", "min": 10, "max": 22}],
			},
			{
				"weight": 35,
				"note": "Bad news, kindly meant. A neighbouring holding has fallen; one of yours stays up till dawn rewriting the marching map.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
			{
				"weight": 25,
				"note": "Bad news, badly meant. A debt called in years ago is called in again.",
				"effects": [{"kind": "gold", "amount": -14}],
			},
		],
	},

	"drinking_contest": {
		"label":  "A Drinking Contest",
		"intro":  "The garrison sergeant has produced a barrel of something that should not be drunk, and the company will not be dissuaded.",
		"weight": 3,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 40,
				"note": "One of yours stands at dawn with a head like a forge. The story improves with each telling; so, eventually, does the storyteller.",
				"effects": [{"kind": "random_unit_stat", "stat": "bravery", "delta": 1}],
			},
			{
				"weight": 35,
				"note": "The barrel is finished. Discipline takes a small holiday and pays for it in lost training.",
				"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": -1}],
			},
			{
				"weight": 25,
				"note": "A wager is struck and won — coin changes hands more times than the chronicler can follow. The house treasury comes out ahead.",
				"effects": [{"kind": "gold_range", "min": 4, "max": 10}],
			},
		],
	},

	"broken_blade": {
		"label":  "A Broken Blade",
		"intro":  "A favoured blade in the household racks gives way at the tang in practice, days from when it would have given way at worse.",
		"weight": 3,
		"min_week": 10,
		"outcomes": [
			{
				"weight": 60,
				"note": "The smith takes a long look, then a longer purse, then makes it as good as it was.",
				"effects": [{"kind": "gold", "amount": -12}],
			},
			{
				"weight": 25,
				"note": "The household armoury yields an older blade nobody had needed in years. It is wrapped, oiled, and good enough.",
				"effects": [{"kind": "inventory_add", "id": "iron_ore", "min": 1, "max": 2}],
			},
			{
				"weight": 15,
				"note": "The blade is mended and the wielder learns something about iron in the doing.",
				"effects": [{"kind": "random_unit_stat", "stat": "technique", "delta": 1}],
			},
		],
	},

	"lord_demands_tax": {
		"label":  "A Lord Demands Tax",
		"intro":  "A neighbouring lord's reeve calls at the gate with a writ of tribute. The seal is real; the demand is not.",
		"weight": 3,
		"min_week": 8,
		"min_gold": 10,
		"outcomes": [
			{
				"weight": 45,
				"note": "The household pays under protest. The chronicler files the writ where it can be cited later.",
				"effects": [{"kind": "gold_range", "min": -22, "max": -12}],
			},
			{
				"weight": 30,
				"note": "Your knight argues the writ down to a courtesy. The reeve leaves with less than he came for, and a polite note for his master.",
				"effects": [{"kind": "gold", "amount": -4}, {"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
			},
			{
				"weight": 25,
				"note": "Your knight refuses the writ outright. The reeve leaves furious; the chaplain will say prayers tonight.",
				"effects": [{"kind": "random_unit_stat", "stat": "intimidation", "delta": 1}],
			},
		],
	},

	"abandoned_armoury": {
		"label":  "An Abandoned Armoury",
		"intro":  "Scouts working a stretch of forgotten road find a strongbox under the floorboards of a ruined longhouse.",
		"weight": 2,
		"min_week": 14,
		"outcomes": [
			{
				"weight": 60,
				"note": "Old metal, well-kept. The household forge will know what to do with it.",
				"effects": [{"kind": "inventory_add", "id": "iron_ore", "min": 2, "max": 4}],
			},
			{
				"weight": 25,
				"note": "Coin, hidden in oilcloth. A long time since it was last counted.",
				"effects": [{"kind": "gold_range", "min": 14, "max": 28}],
			},
			{
				"weight": 15,
				"note": "Empty but for a brief written hand — a record of a household lost to plague twelve winters past. Nobody speaks on the ride home.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"old_rival": {
		"label":  "An Old Rival Calls",
		"intro":  "A knight from your knight's earlier career arrives unannounced, claiming an old quarrel and a current curiosity.",
		"weight": 2,
		"min_week": 12,
		"min_roster_at_home": 1,
		"outcomes": [
			{
				"weight": 45,
				"note": "They speak past dawn. Old slights are reconciled or, more likely, recategorised. Your knight rides into next week sharper.",
				"effects": [{"kind": "random_unit_stat", "stat": "technique", "delta": 1}],
			},
			{
				"weight": 35,
				"note": "They cross blades in the practice yard. No quarter, no blood. Both come away with their reputations intact and one fewer story to invent.",
				"effects": [{"kind": "random_unit_stat", "stat": "swordsmanship", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "The rival leaves with a parting cut that lands. Pride more than flesh.",
				"effects": [{"kind": "random_unit_injury"}],
			},
		],
	},

	"omen_of_battle": {
		"label":  "An Omen of Battle",
		"intro":  "A flock of ravens settles on the walls and stays past dusk. The chaplain calls it a sign; the marshal calls it ravens.",
		"weight": 2,
		"outcomes": [
			{
				"weight": 50,
				"note": "The chaplain says prayers; the marshal does drills. Somewhere between the two, the household sharpens itself.",
				"effects": [{"kind": "all_units_stat", "stat": "bravery", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "Sleep is poor and dreams are pointed. Even the dogs are restless.",
				"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": -1}],
			},
			{
				"weight": 20,
				"note": "By Thursday the ravens have moved on. The chronicler removes the entry.",
				"effects": [],
			},
		],
	},

	"runaway_squire": {
		"label":  "A Runaway Squire",
		"intro":  "A boy of fourteen arrives at the gate with a borrowed pony and a forged letter of introduction. He admits the forgery before being asked.",
		"weight": 2,
		"min_week": 6,
		"outcomes": [
			{
				"weight": 50,
				"note": "He stays a week, helps the marshal, learns three new ways to fall off a horse, and is sent home with a written recommendation that almost matches the forged one.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
			{
				"weight": 35,
				"note": "He stays a week and leaves on his own pony, which was not his when he arrived.",
				"effects": [{"kind": "gold", "amount": -8}],
			},
			{
				"weight": 15,
				"note": "He stays the night and rides on at dawn, leaving the household a careful little salute and a careful little theft of the kitchen's bread.",
				"effects": [],
			},
		],
	},

	"the_chronicler_speaks": {
		"label":  "The Chronicler Speaks",
		"intro":  "Your household chronicler asks for an evening of your knight's time over a glass of the better wine.",
		"weight": 2,
		"min_week": 12,
		"min_roster_at_home": 1,
		"outcomes": [
			{
				"weight": 60,
				"note": "He reads back the year's entries. Some are sharper than they felt at the time; the wine helps. Your knight rises with a clearer view of the road behind.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}, {"kind": "random_unit_stat", "stat": "loyalty", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "He pushes a sealed page across the table. \"Your father's hand,\" he says. \"Found in the binding of a ledger you have not yet read.\" Your knight does not say what it contained.",
				"effects": [{"kind": "pa_delta", "min": 4, "max": 10}],
			},
			{
				"weight": 10,
				"note": "He has been drinking before your knight arrived. The conversation goes nowhere worth recording, and the chronicler does not record it.",
				"effects": [],
			},
		],
	},

	"frost_in_spring": {
		"label":  "Frost in Spring",
		"intro":  "A late frost takes the new growth in the household garden and the outlying fields alike.",
		"weight": 2,
		"min_week": 4,
		"max_week": 20,
		"outcomes": [
			{
				"weight": 55,
				"note": "Half the spring planting is lost. The steward shortens the kitchen ration without raising his voice.",
				"effects": [{"kind": "gold", "amount": -9}],
			},
			{
				"weight": 25,
				"note": "The household forester knew the signs and covered the most prized rows in old sailcloth two days before. Most of the harvest comes through.",
				"effects": [{"kind": "inventory_add", "id": "plant_fibres", "min": 1, "max": 3}],
			},
			{
				"weight": 20,
				"note": "Your knight rides the boundary with the steward to assess. Nothing is saved by the ride; something is saved by the seeing.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
		],
	},

	"night_alarms": {
		"label":  "Alarms in the Night",
		"intro":  "The watch sounds the bell at the third hour. Nobody is there when the gates are opened, and nobody admits to having been.",
		"weight": 3,
		"outcomes": [
			{
				"weight": 50,
				"note": "False alarm — a fox or a courting cat. The watch is short on sleep but long on alertness for a week.",
				"effects": [{"kind": "random_unit_stat", "stat": "speed", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "Not false — bootprints under the orchard wall, and a sack of stolen apples left abandoned where the thief dropped it running.",
				"effects": [{"kind": "random_unit_stat", "stat": "bravery", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "The watch admits, hours later, to having sounded the bell to test the marshal. The marshal does not appreciate this. The watch will not test the marshal again.",
				"effects": [{"kind": "random_unit_stat", "stat": "loyalty", "delta": -1}],
			},
		],
	},

	"forge_master_visits": {
		"label":  "The Forge-Master Visits",
		"intro":  "A travelling forge-master offers a week's work at the household forge — for a fair price, he says, although fair varies.",
		"weight": 2,
		"min_week": 16,
		"min_gold": 25,
		"outcomes": [
			{
				"weight": 55,
				"note": "Coin for craft. The household kit is rehung and resharpened; the marshal finds himself standing straighter at inspection.",
				"effects": [{"kind": "gold_range", "min": -28, "max": -18}, {"kind": "random_unit_stat", "stat": "swordsmanship", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "He is no forge-master at all but a sharp-tongued smith who has run out of his own town. He leaves with a polite refusal and your knight's good opinion of his pride.",
				"effects": [{"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
			},
			{
				"weight": 15,
				"note": "He works for a week and disappears in the night with the household's best hammer. The chronicler omits this from the year's entry.",
				"effects": [{"kind": "gold", "amount": -8}],
			},
		],
	},

	"memorial_for_the_fallen": {
		"label":  "A Memorial for the Fallen",
		"intro":  "Your knight orders a small memorial set in the household yard. The stonecutter charges less than the chaplain expects.",
		"weight": 1,
		"min_week": 18,
		"outcomes": [
			{
				"weight": 70,
				"note": "The household stands at the dedication. Voices crack. Discipline holds. Something is set.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}, {"kind": "gold", "amount": -6}],
			},
			{
				"weight": 30,
				"note": "The memorial is set, paid for, and stood at. Your knight finds himself unable to write the inscription, and the chronicler writes it for him.",
				"effects": [{"kind": "gold", "amount": -6}, {"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
		],
	},

	"bardic_contest": {
		"label":  "A Bardic Contest",
		"intro":  "A small contest of bards passes through and stops a night under your household's hospitality. The audience is partly genuine.",
		"weight": 2,
		"outcomes": [
			{
				"weight": 50,
				"note": "Your knight is asked to judge a verse. He chooses well; the chosen verse turns out, by morning, to be about your house.",
				"effects": [{"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "Your knight is asked to judge a verse. He chooses the losing one and is told so, kindly, by the chaplain on the ride home.",
				"effects": [],
			},
			{
				"weight": 20,
				"note": "A bard sings of a household's loss. The audience grows quiet. The household coffers loosen for charity by morning.",
				"effects": [{"kind": "gold", "amount": -5}, {"kind": "random_unit_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	# ---- Batch 1 — events using clear_injury / inventory_remove / expedition_delay ----

	"hidden_springs": {
		"label":  "Hidden Springs",
		"intro":  "A scout returns with talk of a clear pool in a fold of land nobody had thought to map. The water tastes faintly of iron.",
		"weight": 3,
		"min_week": 5,
		"outcomes": [
			{
				"weight": 50,
				"note": "An injured household member is taken to bathe. The chaplain says little; the wound says less by the third day.",
				"effects": [{"kind": "clear_injury"}],
			},
			{
				"weight": 30,
				"note": "The pool is mapped, marked, and quietly added to the household's holdings. The chronicler is pleased; the steward will not say why he is more pleased.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "The spring is brackish on closer taste — useful only for the horses. They drink and walk straighter for it.",
				"effects": [{"kind": "random_unit_stat", "stat": "horsemanship", "delta": 1}],
			},
		],
	},

	"wandering_alchemist": {
		"label":  "A Wandering Alchemist",
		"intro":  "A stooped figure in stained robes asks lodging for two nights and offers his trade in payment. He smells faintly of camphor and something the chaplain cannot name.",
		"weight": 2,
		"min_week": 8,
		"outcomes": [
			{
				"weight": 45,
				"note": "He brews three vials of foul brown liquid. One of them works on whoever needed it most.",
				"effects": [{"kind": "clear_injury"}, {"kind": "gold", "amount": -6}],
			},
			{
				"weight": 30,
				"note": "He sells a tincture said to sharpen the mind. Whether the tincture works or the household merely sleeps better in expectation, your knight wakes the third morning a step clearer.",
				"effects": [{"kind": "gold_range", "min": -14, "max": -8}, {"kind": "pa_delta", "min": 3, "max": 8}],
			},
			{
				"weight": 25,
				"note": "He is a fraud. Pleasant company at table, but a fraud. He leaves on the third dawn lighter on coin than he ought to be; the household coffers are not heavier.",
				"effects": [],
			},
		],
	},

	"food_stores_spoil": {
		"label":  "Food Stores Spoil",
		"intro":  "The steward opens the back of the storeroom and his mouth tightens. Mice, damp, or both — too late to ask, too soon to laugh.",
		"weight": 4,
		"min_week": 6,
		"outcomes": [
			{
				"weight": 60,
				"note": "Half the spring stores are lost. The week's kitchen is short and the kitchen's temper is shorter.",
				"effects": [
					{"kind": "inventory_remove", "id": "plant_fibres", "min": 1, "max": 3},
					{"kind": "inventory_remove", "id": "logs", "min": 1, "max": 2},
				],
			},
			{
				"weight": 25,
				"note": "Most of the stores are saved. The steward writes a long memo on barrel-sealing technique. Nobody reads it; the next storeroom is properly sealed all the same.",
				"effects": [{"kind": "inventory_remove", "id": "plant_fibres", "min": 0, "max": 1}],
			},
			{
				"weight": 15,
				"note": "The loss is total. The household tightens belts and your knight notes the lesson — quietly, sharply.",
				"effects": [
					{"kind": "inventory_remove", "id": "plant_fibres", "min": 2, "max": 4},
					{"kind": "inventory_remove", "id": "logs", "min": 1, "max": 3},
					{"kind": "random_unit_stat", "stat": "leadership", "delta": 1},
				],
			},
		],
	},

	"goblin_sabotage": {
		"label":  "Goblin Sabotage",
		"intro":  "A patrol finds woodchips around the outer storehouse — fresh chips, small hands. Not bandits; smaller, meaner.",
		"weight": 2,
		"min_week": 10,
		"outcomes": [
			{
				"weight": 50,
				"note": "They got into the timber pile before the patrol arrived. Some of it is fouled; some is gone.",
				"effects": [{"kind": "inventory_remove", "id": "logs", "min": 2, "max": 4}],
			},
			{
				"weight": 30,
				"note": "The patrol drives them off. One of yours catches a thrown stone and walks crooked for a week.",
				"effects": [{"kind": "random_unit_injury"}],
			},
			{
				"weight": 20,
				"note": "The marshal sets a trap and catches three. They squeal whereabouts; your knight rides to the warren and returns with a small consolation of metal.",
				"effects": [{"kind": "inventory_add", "id": "iron_ore", "min": 1, "max": 2}],
			},
		],
	},

	"sudden_storm": {
		"label":  "A Sudden Storm",
		"intro":  "A spring storm lands without warning. The household roof holds; the roads do not.",
		"weight": 3,
		"min_week": 4,
		"max_week": 36,
		"outcomes": [
			{
				"weight": 45,
				"note": "Travel halts everywhere on the marches. The household's distant parties bed down where they are and wait it out.",
				"effects": [{"kind": "expedition_delay", "min": 1, "max": 2}],
			},
			{
				"weight": 30,
				"note": "The storm lasts three days. By the time it passes, the watch has caught up on a year of small repairs to the wall.",
				"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": 1}],
			},
			{
				"weight": 25,
				"note": "Lightning takes a stand of timber on the far rise. Once the storm is past, the household forester rides out and salvages what wasn't burned through.",
				"effects": [{"kind": "inventory_add", "id": "logs", "min": 1, "max": 3}],
			},
		],
	},

	"tax_collector": {
		"label":  "A Tax Collector",
		"intro":  "A pinched-faced man in a fine coat arrives unannounced with a tally-roll and a small armed escort. He claims authority your knight has never granted.",
		"weight": 3,
		"min_week": 10,
		"min_gold": 12,
		"outcomes": [
			{
				"weight": 45,
				"note": "The household pays the assessed sum. The tax collector leaves; the chronicler files the assessment for a future grievance.",
				"effects": [{"kind": "gold_range", "min": -22, "max": -14}],
			},
			{
				"weight": 35,
				"note": "Your knight reads the tally-roll carefully, finds three errors, and corrects them aloud. The collector leaves with less than his masters expect and your knight's standing the better for it.",
				"effects": [{"kind": "gold_range", "min": -10, "max": -5}, {"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "Your knight refuses the assessment outright. The collector leaves furious; the household sleeps lightly that night, and the marshal has the watch doubled.",
				"effects": [{"kind": "random_unit_stat", "stat": "intimidation", "delta": 1}, {"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"talking_crow": {
		"label":  "A Talking Crow",
		"intro":  "A black bird settles on the chapel post and addresses your knight by name. The chaplain says it's a parrot a knight once trained and lost. The crow disagrees.",
		"weight": 1,
		"min_week": 14,
		"outcomes": [
			{
				"weight": 50,
				"note": "It speaks three words that match nothing your knight remembers, and flies off. He sleeps well that night, oddly settled.",
				"effects": [{"kind": "pa_delta", "min": 4, "max": 9}],
			},
			{
				"weight": 30,
				"note": "It speaks a name your knight has been trying to forget. He does not sleep well; he rises sharper for it.",
				"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": 1}, {"kind": "pa_delta", "min": -6, "max": -2}],
			},
			{
				"weight": 20,
				"note": "It speaks nothing. The chaplain admits the parrot story was a guess. The bird is fed and stays through the week.",
				"effects": [],
			},
		],
	},

	"mimic_treasure_cart": {
		"label":  "A Treasure Cart on the Road",
		"intro":  "Scouts report an abandoned cart on the western track, ironbound, lock intact. Too good. Too quiet.",
		"weight": 1,
		"min_week": 16,
		"outcomes": [
			{
				"weight": 45,
				"note": "It is what it looks like — an abandoned merchant's cart, lock and all. The household pries it open and brings home a fair share.",
				"effects": [{"kind": "gold_range", "min": 14, "max": 28}, {"kind": "inventory_add", "id": "iron_ore", "min": 1, "max": 3}],
			},
			{
				"weight": 35,
				"note": "It is not what it looks like. The cart's lid hinges the wrong way; something inside has hinges of its own. One of yours nurses a bite that should not have come from a cart.",
				"effects": [{"kind": "random_unit_injury"}, {"kind": "gold_range", "min": 4, "max": 10}],
			},
			{
				"weight": 20,
				"note": "It is empty but for an old letter and a great deal of dust. The letter is read aloud in the hall that evening; the audience grows quiet.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"ghost_army": {
		"label":  "Ghost Army on the Horizon",
		"intro":  "The watch reports a line of distant banners on the southern horizon at dusk. By the time your knight arrives at the wall the banners are gone. The chaplain is uncomfortable.",
		"weight": 1,
		"min_week": 20,
		"outcomes": [
			{
				"weight": 50,
				"note": "The chaplain says prayers and the marshal says nothing. By morning the household is grimmer and a little harder to surprise.",
				"effects": [{"kind": "all_units_stat", "stat": "bravery", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "Two of yours did not sleep, and will not say what they saw. Their loyalty deepens; their good cheer does not.",
				"effects": [{"kind": "random_unit_stat", "stat": "loyalty", "delta": 1}, {"kind": "random_unit_stat", "stat": "bravery", "delta": -1}],
			},
			{
				"weight": 20,
				"note": "By dawn the chronicler has heard the story from three different watchers, each in different colours. He writes it down twice and keeps both.",
				"effects": [{"kind": "pa_delta", "min": 2, "max": 6}],
			},
		],
	},
}


# ---------- discovery / labelling ----------

static func is_story_sub_type(sub_type: String) -> bool:
	return sub_type.begins_with(STORY_PREFIX)


static func story_id_from_sub_type(sub_type: String) -> String:
	if not is_story_sub_type(sub_type):
		return ""
	return sub_type.substr(STORY_PREFIX.length())


static func label_for(story_id: String) -> String:
	return str(EVENTS.get(story_id, {}).get("label", "Battle Event"))


static func intro_for(story_id: String) -> String:
	return str(EVENTS.get(story_id, {}).get("intro", ""))


# ---------- rolling ----------

# Pick a story id eligible for the current week + gold + at-home roster.
# Returns "" when no event passes the gates — the gateway falls back to
# a hard-coded sub-type in that case (see BattleEvent.roll_sub_type).
static func roll_event_id(gs: Node) -> String:
	var pool: Array = []   # Array of [id, weight]
	var at_home_count: int = gs.at_home_units().size()

	for id: String in EVENTS:
		var event: Dictionary = EVENTS[id]
		if int(event.get("min_week", 0)) > gs.week:
			continue
		if int(event.get("max_week", 9999)) < gs.week:
			continue
		if int(event.get("min_gold", 0)) > gs.gold:
			continue
		if int(event.get("min_roster_at_home", 0)) > at_home_count:
			continue
		var w: int = int(event.get("weight", 1))
		if w > 0:
			pool.append([id, w])

	if pool.is_empty():
		return ""
	var total: int = 0
	for pair in pool:
		total += int(pair[1])
	var pick: int = RNG.randi_range(1, total)
	var acc: int = 0
	for pair in pool:
		acc += int(pair[1])
		if pick <= acc:
			return str(pair[0])
	return str(pool[pool.size() - 1][0])


# ---------- resolution ----------

# Runs the story event whose id is encoded in gs.current_battle_event.
# Mutates the result dict in place, appending notes + (optionally) setting
# result["reward"]. Called from Resolution._resolve_battle_event when the
# sub-type begins with "story:".
static func resolve(gs: Node, story_id: String, result: Dictionary) -> void:
	var event: Dictionary = EVENTS.get(story_id, {})
	if event.is_empty():
		result["notes"].append("Unknown story event: %s" % story_id)
		return

	result["fought"] = false
	result["won"] = true
	result["story_event_id"] = story_id

	var outcome: Dictionary = _pick_outcome(event)
	if outcome.is_empty():
		result["notes"].append("%s — the moment passed without incident." % str(event.get("label", "")))
		return

	result["story_outcome_index"] = int(outcome.get("_index", -1))
	if str(outcome.get("note", "")) != "":
		result["notes"].append(str(outcome["note"]))

	for effect in outcome.get("effects", []):
		_apply_effect(gs, effect, result)


static func _pick_outcome(event: Dictionary) -> Dictionary:
	var outcomes: Array = event.get("outcomes", [])
	if outcomes.is_empty():
		return {}
	var total: int = 0
	for o in outcomes:
		total += maxi(0, int(o.get("weight", 1)))
	if total <= 0:
		return {}
	var pick: int = RNG.randi_range(1, total)
	var acc: int = 0
	for i in range(outcomes.size()):
		acc += maxi(0, int(outcomes[i].get("weight", 1)))
		if pick <= acc:
			var picked: Dictionary = outcomes[i].duplicate(true)
			picked["_index"] = i
			return picked
	return outcomes[outcomes.size() - 1]


# ---------- effects ----------

static func _apply_effect(gs: Node, effect: Dictionary, result: Dictionary) -> void:
	var kind: String = str(effect.get("kind", ""))
	match kind:
		"gold":
			var amount: int = int(effect.get("amount", 0))
			gs.gold = maxi(0, gs.gold + amount)
			_log_gold_effect(result, amount)
		"gold_range":
			var amount: int = RNG.randi_range(int(effect.get("min", 0)), int(effect.get("max", 0)))
			gs.gold = maxi(0, gs.gold + amount)
			_log_gold_effect(result, amount)
		"random_unit_stat":
			_apply_random_unit_stat(gs, str(effect.get("stat", "")), int(effect.get("delta", 0)), result)
		"all_units_stat":
			_apply_all_units_stat(gs, str(effect.get("stat", "")), int(effect.get("delta", 0)), result)
		"random_unit_injury":
			_apply_random_unit_injury(gs, result)
		"reward_resources":
			_apply_reward_resources(int(effect.get("min", 1)), int(effect.get("max", 3)), result)
		"inventory_add":
			_apply_inventory_add(gs, str(effect.get("id", "")), int(effect.get("min", 1)), int(effect.get("max", 1)), result)
		"inventory_remove":
			_apply_inventory_remove(gs, str(effect.get("id", "")), int(effect.get("min", 1)), int(effect.get("max", 1)), result)
		"pa_delta":
			_apply_pa_delta(gs, int(effect.get("min", 0)), int(effect.get("max", 0)), result)
		"clear_injury":
			_apply_clear_injury(gs, result)
		"expedition_delay":
			_apply_expedition_delay(gs, int(effect.get("min", 1)), int(effect.get("max", 2)), result)
		_:
			result["notes"].append("(unhandled effect kind: %s)" % kind)


static func _log_gold_effect(result: Dictionary, amount: int) -> void:
	if amount > 0:
		result["notes"].append("+%d gold" % amount)
	elif amount < 0:
		result["notes"].append("−%d gold" % -amount)


static func _apply_random_unit_stat(gs: Node, stat: String, delta: int, result: Dictionary) -> void:
	if stat == "" or delta == 0:
		return
	var pool: Array[Unit] = gs.at_home_units()
	if pool.is_empty():
		return
	var unit: Unit = pool[RNG.randi_range(0, pool.size() - 1)]
	_apply_stat_delta(unit, stat, delta, result)


static func _apply_all_units_stat(gs: Node, stat: String, delta: int, result: Dictionary) -> void:
	if stat == "" or delta == 0:
		return
	for u in gs.at_home_units():
		_apply_stat_delta(u, stat, delta, result)


static func _apply_stat_delta(unit: Unit, stat: String, delta: int, result: Dictionary) -> void:
	if delta > 0:
		var applied_any: bool = false
		for _i in range(delta):
			if unit.stats.try_increment(stat, unit.potential_ability):
				applied_any = true
			else:
				break
		if applied_any:
			result["notes"].append("%s: +%d %s" % [unit.unit_name, delta, stat.capitalize()])
	else:
		# Negative deltas clamp at 1 (a stat shouldn't fall to 0 from flavour).
		var current: int = unit.stats.get_value(stat)
		var new_val: int = maxi(1, current + delta)
		if new_val < current:
			unit.stats.set_value(stat, new_val)
			result["notes"].append("%s: %d %s" % [unit.unit_name, delta, stat.capitalize()])


static func _apply_random_unit_injury(gs: Node, result: Dictionary) -> void:
	var pool: Array[Unit] = gs.at_home_units()
	if pool.is_empty():
		return
	var unit: Unit = pool[RNG.randi_range(0, pool.size() - 1)]
	var inj: Dictionary = unit.apply_random_injury()
	result["injuries"].append({"unit_id": unit.id, "stat": inj["stat"], "weeks_remaining": inj["weeks_remaining"]})
	result["notes"].append("%s injured: %s (%dw recovery)" % [
		unit.unit_name, str(inj["stat"]).capitalize(), int(inj["weeks_remaining"]),
	])


static func _apply_reward_resources(lo: int, hi: int, result: Dictionary) -> void:
	var bundle := ResourceBundle.new()
	for key in ResourceBundle.KEYS:
		bundle.set(key, RNG.randi_range(lo, hi))
	# Don't clobber an existing reward — some outcomes pair a story bundle
	# with a separate effect that already set one. ResourceBundle.add() mutates
	# in place, so we duplicate the existing one to avoid surprising callers.
	var existing: ResourceBundle = result.get("reward")
	if existing == null:
		result["reward"] = bundle
	else:
		var merged: ResourceBundle = existing.duplicate_bundle()
		merged.add(bundle)
		result["reward"] = merged


static func _apply_inventory_add(gs: Node, id: String, lo: int, hi: int, result: Dictionary) -> void:
	if id == "":
		return
	var amount: int = RNG.randi_range(lo, hi)
	if amount <= 0:
		return
	gs.inventory[id] = int(gs.inventory.get(id, 0)) + amount
	var entry: Dictionary = ResourceDB.RESOURCES.get(id, {})
	var name: String = str(entry.get("name", id))
	result["notes"].append("+%d %s" % [amount, name])


static func _apply_pa_delta(gs: Node, lo: int, hi: int, result: Dictionary) -> void:
	var pool: Array[Unit] = gs.at_home_units()
	if pool.is_empty():
		return
	var amount: int = RNG.randi_range(lo, hi)
	if amount == 0:
		return
	var unit: Unit = pool[RNG.randi_range(0, pool.size() - 1)]
	unit.potential_ability = maxi(20, unit.potential_ability + amount)
	# PA is hidden by design (GDD §10); we don't surface the number, only that
	# *something* shifted in the unit's quiet ledger.
	if amount > 0:
		result["notes"].append("%s sleeps better that night." % unit.unit_name)
	else:
		result["notes"].append("%s sleeps worse for it." % unit.unit_name)


# Remove up to a rolled amount of `id` from inventory. Clamps at zero so the
# household can't go into resource debt from a flavour event. Silent no-op
# when the household had none of the resource to begin with (no negative-amount
# bullet appears) — story prose carries the consequence in that case.
static func _apply_inventory_remove(gs: Node, id: String, lo: int, hi: int, result: Dictionary) -> void:
	if id == "":
		return
	var rolled: int = RNG.randi_range(lo, hi)
	if rolled <= 0:
		return
	var have: int = int(gs.inventory.get(id, 0))
	if have <= 0:
		return
	var removed: int = mini(have, rolled)
	gs.inventory[id] = have - removed
	var entry: Dictionary = ResourceDB.RESOURCES.get(id, {})
	var name: String = str(entry.get("name", id))
	result["notes"].append("−%d %s" % [removed, name])


# Clear the most-pressing injury from a random injured at-home unit. "Most
# pressing" = the one with the highest weeks_remaining, so the heal feels
# meaningful rather than shaving a tail-end recovery. No-op when nobody is
# injured; the resolver lets the outcome's note carry the prose either way.
static func _apply_clear_injury(gs: Node, result: Dictionary) -> void:
	var injured: Array[Unit] = []
	for u in gs.at_home_units():
		if u.is_injured():
			injured.append(u)
	if injured.is_empty():
		return
	var unit: Unit = injured[RNG.randi_range(0, injured.size() - 1)]
	# Find the injury with the longest remaining recovery.
	var best_idx: int = 0
	for i in range(1, unit.injuries.size()):
		if int(unit.injuries[i].get("weeks_remaining", 0)) > int(unit.injuries[best_idx].get("weeks_remaining", 0)):
			best_idx = i
	var stat: String = str(unit.injuries[best_idx].get("stat", ""))
	unit.injuries.remove_at(best_idx)
	result["notes"].append("%s healed: %s" % [unit.unit_name, stat.capitalize()])


# Push a random active expedition's clock back by 1–2 weeks. Negative effect
# from the household's perspective; the resolver assumes positive deltas only
# (we don't speed expeditions up via story events — that's a tuning lever
# better left to a future explicit "fast rider" event with its own primitive).
static func _apply_expedition_delay(gs: Node, lo: int, hi: int, result: Dictionary) -> void:
	if gs.expeditions.is_empty():
		return
	var rolled: int = maxi(0, RNG.randi_range(lo, hi))
	if rolled <= 0:
		return
	var exped = gs.expeditions[RNG.randi_range(0, gs.expeditions.size() - 1)]
	exped.weeks_remaining += rolled
	result["notes"].append("Expedition #%d delayed by %d week%s" % [
		exped.id, rolled, "s" if rolled != 1 else "",
	])
