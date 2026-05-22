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
#   {kind: "reputation", amount: int}                 — flat reputation delta
#                                                       on GameState.reputation
#   {kind: "reputation_range", min: int, max: int}    — rolled reputation
#                                                       delta in the range


# A note about gates:
#   min_week / max_week  : inclusive week range
#   min_gold             : event won't roll if gs.gold < this
#   min_roster_at_home   : requires at least N at-home units to fire
#
# These keep events from arriving at impossible moments (no "broken blade"
# event when the only knight is on expedition; no "tax demand" the player
# can't pay). When all eligible events fail the gates, the gateway falls
# back to a hard-coded sub-type — see BattleEvent.roll_sub_type().
#
# Outcome stat-check (opt-in, new):
#   An outcome can carry a `stat_check` block instead of (or alongside) its
#   own `note` + `effects`. When present, the resolver evaluates the check
#   against the at-home roster's stats and substitutes the on_pass / on_fail
#   branch's note + effects in place of the outcome's own. Outcomes without
#   `stat_check` resolve as before — fully backwards-compatible.
#
#   stat_check: {
#     stat:       <stat key, e.g. "leadership">,
#     scope:      "best" (default) | "knight" | "all_avg",
#     threshold:  int — the value the chosen scope's number must meet,
#     on_pass:    {note, effects}
#     on_fail:    {note, effects}
#   }
#
#   The resolver also appends a small "(Best Leadership carried the test —
#   14 vs 12.)" line so the player feels the check land rather than guessing
#   why an outcome happened.

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

	# ---- Batch 2 — Tier-A events on existing primitives ----

	"wandering_swordsman": {
		"label":  "A Wandering Swordsman",
		"intro":  "A man with three scars and a careful walk appears at the practice yard at dawn. He asks to spar; he does not ask twice.",
		"weight": 3,
		"min_week": 4,
		"outcomes": [
			{
				"weight": 55,
				"note": "He spars with each of yours, takes payment in bread and warm beer, and rides on at dusk. One of yours hits harder for the meeting.",
				"effects": [{"kind": "random_unit_stat", "stat": "swordsmanship", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "He spars an hour with the marshal alone. The marshal writes nothing down but moves differently the next day.",
				"effects": [{"kind": "random_unit_stat", "stat": "technique", "delta": 1}],
			},
			{
				"weight": 15,
				"note": "He is more than he seems and less than he claims. A bout goes farther than intended; one of yours wears a bruise for a week.",
				"effects": [{"kind": "random_unit_injury"}],
			},
		],
	},

	"retired_veteran": {
		"label":  "A Retired Veteran",
		"intro":  "An old man arrives at the gate with a long stick, a longer history, and a request only that he be allowed to watch the marshal drill the company.",
		"weight": 2,
		"min_week": 6,
		"outcomes": [
			{
				"weight": 50,
				"note": "He watches an afternoon, then offers three small corrections in the dialect of an army your knight has only read about. The corrections work.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "He stays a week. The garrison comes off the drill yard sharper than they went on, with an old man's notes folded in their kit.",
				"effects": [{"kind": "all_units_stat", "stat": "technique", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "He stays two days, says little, and is buried on the third. The household sees him off proper, and one of yours stands the watch in his stead.",
				"effects": [{"kind": "gold", "amount": -5}, {"kind": "random_unit_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"forgotten_battlefield": {
		"label":  "A Forgotten Battlefield",
		"intro":  "Outriders cross a stretch of grass that gives way too easily underfoot. The chaplain knows the year and the army; the chronicler has heard of neither.",
		"weight": 2,
		"min_week": 12,
		"outcomes": [
			{
				"weight": 50,
				"note": "Old iron under the turf. The household forge will know what to do with it; the chronicler will know what not to ask.",
				"effects": [{"kind": "inventory_add", "id": "iron_ore", "min": 2, "max": 4}],
			},
			{
				"weight": 30,
				"note": "Your knight rides the line of the old fight alone, returns at dusk, and speaks of it once. The household sleeps quieter that night.",
				"effects": [{"kind": "random_unit_stat", "stat": "bravery", "delta": 1}, {"kind": "pa_delta", "min": 3, "max": 7}],
			},
			{
				"weight": 20,
				"note": "Nothing useful is dug. The chronicler writes a long entry anyway. The chaplain says a small word over what was found.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"captured_beast_escapes": {
		"label":  "A Captured Beast Escapes",
		"intro":  "A travelling menagerie passes the road and pauses too long at the spring. Something with claws gets free.",
		"weight": 2,
		"min_week": 8,
		"outcomes": [
			{
				"weight": 45,
				"note": "The marshal forms a hunt. By evening it is over; one of yours bears a wound the chaplain will need to clean twice.",
				"effects": [{"kind": "random_unit_injury"}],
			},
			{
				"weight": 35,
				"note": "Your knight rides it down personally. The menagerie's owner pays in coin to avoid the writ. The household is the heavier and the braver for it.",
				"effects": [{"kind": "gold_range", "min": 10, "max": 20}, {"kind": "all_units_stat", "stat": "bravery", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "It vanishes into the marches. The chronicler files three rumours, two of them probably true.",
				"effects": [{"kind": "pa_delta", "min": -4, "max": 4}],
			},
		],
	},

	"lost_caravan_cache": {
		"label":  "A Lost Caravan's Cache",
		"intro":  "A scout returns with the description of a small mound — packs and tent canvas under a stand of birch, untouched for what looks like a year.",
		"weight": 2,
		"min_week": 8,
		"outcomes": [
			{
				"weight": 55,
				"note": "Cloth, coin, and small ironwork. Enough to be worth the wagon-ride; enough to make the steward smile twice in one evening.",
				"effects": [{"kind": "gold_range", "min": 10, "max": 22}, {"kind": "reward_resources", "min": 1, "max": 3}],
			},
			{
				"weight": 30,
				"note": "Mostly cloth — but good cloth, the kind a steward folds carefully and a chaplain blesses without sarcasm.",
				"effects": [{"kind": "inventory_add", "id": "plant_fibres", "min": 2, "max": 4}],
			},
			{
				"weight": 15,
				"note": "Bones, and a small written hand explaining how they came to be there. The household buries them proper and rides home a measure heavier.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"travelling_merchant": {
		"label":  "A Travelling Merchant",
		"intro":  "A wagon with two patient mules and a man with three different pricing voices arrives at the gate.",
		"weight": 3,
		"min_week": 4,
		"min_gold": 10,
		"outcomes": [
			{
				"weight": 45,
				"note": "He sells the household a small bundle at his second voice. The kitchen and the forge are both quiet pleased.",
				"effects": [{"kind": "gold_range", "min": -16, "max": -10}, {"kind": "reward_resources", "min": 2, "max": 4}],
			},
			{
				"weight": 30,
				"note": "He sells a quantity of raw metal at a price your knight can argue down to fair. The forge takes delivery within the hour.",
				"effects": [{"kind": "gold_range", "min": -12, "max": -6}, {"kind": "inventory_add", "id": "iron_ore", "min": 2, "max": 4}],
			},
			{
				"weight": 25,
				"note": "He sells nothing and leaves with three of your knight's small coins for his trouble. Your knight calls it a fair lesson; the steward calls it three coins.",
				"effects": [{"kind": "gold", "amount": -3}],
			},
		],
	},

	"desertion_in_the_night": {
		"label":  "Desertion in the Night",
		"intro":  "A bunk is empty at dawn. The marshal makes a careful enquiry; the household makes a careful pretence of carrying on.",
		"weight": 2,
		"min_week": 10,
		"outcomes": [
			{
				"weight": 50,
				"note": "He is found in the next village, drinking and ashamed. He is brought home; he is set to two weeks of yard work. Discipline holds.",
				"effects": [{"kind": "random_unit_stat", "stat": "loyalty", "delta": -1}],
			},
			{
				"weight": 30,
				"note": "He is not found. The household closes ranks around the marshal's grief and your knight's silence.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": -1}, {"kind": "random_unit_stat", "stat": "determination", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "He returns on his own at sundown. He says nothing. The marshal accepts the silence. Loyalty is, after all, a long ledger.",
				"effects": [],
			},
		],
	},

	"plague_rats": {
		"label":  "Plague Rats Sighted",
		"intro":  "Three large rats are killed in the yard before noon. The chaplain knows the colour of their tails and is not pleased.",
		"weight": 2,
		"min_week": 8,
		"outcomes": [
			{
				"weight": 50,
				"note": "The household sets traps and burns the grain stores' outer sacks. The threat passes; some stores do not.",
				"effects": [{"kind": "inventory_remove", "id": "plant_fibres", "min": 1, "max": 2}],
			},
			{
				"weight": 30,
				"note": "Two of yours take sick. They will recover. The chaplain knows the words; the herbs know the rest.",
				"effects": [{"kind": "random_unit_injury"}, {"kind": "random_unit_injury"}],
			},
			{
				"weight": 20,
				"note": "The chaplain hires a ratter for two days. The rats are gone by the fourth. The kitchen is the cleaner for the lesson.",
				"effects": [{"kind": "gold", "amount": -8}],
			},
		],
	},

	"drunken_brawl": {
		"label":  "A Drunken Brawl",
		"intro":  "The smith's birthday goes longer than the smith expected. By the small hours the company is at words; before lauds, at hands.",
		"weight": 3,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 45,
				"note": "Minor damage to the table, the wall, and one of yours. He limps for a week and learns a useful caution.",
				"effects": [{"kind": "random_unit_injury"}],
			},
			{
				"weight": 35,
				"note": "The marshal arrives in time. Discipline holds; the offenders pay for the table out of pocket.",
				"effects": [{"kind": "gold", "amount": -4}, {"kind": "random_unit_stat", "stat": "loyalty", "delta": -1}],
			},
			{
				"weight": 20,
				"note": "It ends in laughter, somehow. Old quarrels are settled in the way old quarrels settle — at four in the morning, both parties bruised.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"fire_in_the_supply_wagon": {
		"label":  "Fire in the Supply Wagon",
		"intro":  "An ember from the kitchen takes hold in a wagon parked too close. The yard is awake faster than the watch expected.",
		"weight": 2,
		"min_week": 6,
		"outcomes": [
			{
				"weight": 50,
				"note": "Most of the wagon's load is saved. The losses sting more than they cost.",
				"effects": [{"kind": "inventory_remove", "id": "plant_fibres", "min": 1, "max": 2}, {"kind": "gold_range", "min": -6, "max": -3}],
			},
			{
				"weight": 30,
				"note": "The wagon is lost. The watch responds well; one of yours runs into the smoke and earns the chaplain's quiet respect.",
				"effects": [{"kind": "gold_range", "min": -14, "max": -8}, {"kind": "random_unit_stat", "stat": "bravery", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "The fire is caught in the first minute by a sleepless watchman. The household praises him on the spot and pretends not to know why he was awake.",
				"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": 1}],
			},
		],
	},

	"bandits_steal_livestock": {
		"label":  "Bandits Steal Livestock",
		"intro":  "Outliers find a gap in the south paddock and three cattle gone with it. The marshal forms a posse before the dew is off.",
		"weight": 2,
		"min_week": 8,
		"outcomes": [
			{
				"weight": 45,
				"note": "The cattle are gone for good. The household tightens belts, your knight tightens the watch roster, and life goes on.",
				"effects": [{"kind": "gold_range", "min": -12, "max": -6}],
			},
			{
				"weight": 35,
				"note": "The cattle are recovered, the bandits scattered. Your knight returns at evening dusty and the heavier for a small purse he chose not to mention to the chronicler.",
				"effects": [{"kind": "gold_range", "min": 4, "max": 12}, {"kind": "random_unit_stat", "stat": "horsemanship", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "The bandits are caught and put to work in the yard for a fortnight. The cattle are returned, sour-tempered. The household chronicler writes a long entry.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
		],
	},

	"reality_tear": {
		"label":  "A Reality Tear",
		"intro":  "A patch of air in the south orchard ripples like heat over a forge and is gone. The chaplain saw it; the marshal did not, and resents the asymmetry.",
		"weight": 1,
		"min_week": 24,
		"outcomes": [
			{
				"weight": 45,
				"note": "Whatever brushed through left a trace. One of yours dreams differently for a week and wakes the seventh morning sharper.",
				"effects": [{"kind": "pa_delta", "min": 6, "max": 14}],
			},
			{
				"weight": 35,
				"note": "Whatever brushed through left a chill. One of yours is rattled for days; another is steadier than before.",
				"effects": [{"kind": "random_unit_stat", "stat": "bravery", "delta": -1}, {"kind": "random_unit_stat", "stat": "determination", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "Nothing further happens. The chronicler records it twice in different ink, in case the second telling looks different to him a year from now.",
				"effects": [{"kind": "pa_delta", "min": 2, "max": 6}],
			},
		],
	},

	"dice_dealer": {
		"label":  "A Dice Dealer's Bargain",
		"intro":  "A travelling man with a polished cup and a thin smile sets up at the gate. He offers an unusual wager: throw against him, win a fate; lose, owe a coin.",
		"weight": 1,
		"min_week": 12,
		"min_gold": 12,
		"outcomes": [
			{
				"weight": 35,
				"note": "Your knight throws. Your knight wins. The dealer pays in a glance that lingers, and the household sleeps the better for it.",
				"effects": [{"kind": "gold_range", "min": 6, "max": 16}, {"kind": "pa_delta", "min": 4, "max": 10}],
			},
			{
				"weight": 35,
				"note": "Your knight throws. Your knight loses. A small sum, a smaller story. The dealer rides on, unburdened.",
				"effects": [{"kind": "gold_range", "min": -14, "max": -8}],
			},
			{
				"weight": 30,
				"note": "Your knight refuses. The dealer smiles wider, leaves a wooden token on the table, and is gone.",
				"effects": [{"kind": "pa_delta", "min": -3, "max": 6}],
			},
		],
	},

	# ---- Batch 3 — reputation-touching events ----

	"local_festival": {
		"label":  "A Local Festival",
		"intro":  "The nearest village holds its midsummer festival and sends a polite delegation hoping for your household's sponsorship.",
		"weight": 3,
		"min_week": 6,
		"min_gold": 10,
		"outcomes": [
			{
				"weight": 50,
				"note": "Your household pays for the ale and three ribbons of the largest prize. The chronicler is invited to read; the village remembers it.",
				"effects": [{"kind": "gold_range", "min": -14, "max": -8}, {"kind": "reputation_range", "min": 3, "max": 6}],
			},
			{
				"weight": 30,
				"note": "Your knight attends in person, judges a wrestling bout, and rides home with the village's quiet approval.",
				"effects": [{"kind": "reputation_range", "min": 2, "max": 4}, {"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "The household declines. The festival happens without you; the village remembers that too.",
				"effects": [{"kind": "reputation", "amount": -2}],
			},
		],
	},

	"travelling_bard": {
		"label":  "A Travelling Bard Spreads Tales",
		"intro":  "A bard with an ear for whose silver buys best stops three nights in your hall. The third night he asks, politely, for stories he can use.",
		"weight": 3,
		"min_week": 12,
		"outcomes": [
			{
				"weight": 50,
				"note": "Your knight obliges with the most flattering version of a recent campaign. The bard rides on; his ballad arrives in two villages within the fortnight.",
				"effects": [{"kind": "reputation_range", "min": 3, "max": 7}],
			},
			{
				"weight": 30,
				"note": "Your knight tells a story straight. The bard frowns once and writes it twice. It does well in the smaller halls.",
				"effects": [{"kind": "reputation", "amount": 2}, {"kind": "random_unit_stat", "stat": "loyalty", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "Your knight pays him to write nothing. He takes the coin and writes a worse story anyway, in a different region.",
				"effects": [{"kind": "gold", "amount": -10}, {"kind": "reputation", "amount": -1}],
			},
		],
	},

	"rival_rumours": {
		"label":  "Rival Mercenaries Spread Rumours",
		"intro":  "A free company that lost a contract last spring has been muttering in three taverns this month — all about your household, none of it true.",
		"weight": 3,
		"min_week": 14,
		"outcomes": [
			{
				"weight": 45,
				"note": "The rumours stick where they're heard. The household closes ranks and answers questions politely for a fortnight.",
				"effects": [{"kind": "reputation_range", "min": -6, "max": -3}],
			},
			{
				"weight": 35,
				"note": "Your knight rides to the taverns in question, sits long enough to be seen, and says little. The rumours thin.",
				"effects": [{"kind": "reputation", "amount": -1}, {"kind": "random_unit_stat", "stat": "intimidation", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "The household chronicler writes three concise letters to the right ears. By the next week the rumours have new targets.",
				"effects": [{"kind": "gold_range", "min": -8, "max": -4}, {"kind": "reputation", "amount": 1}],
			},
		],
	},

	"village_attacked": {
		"label":  "A Nearby Village Attacked",
		"intro":  "Smoke on the southern road at dawn. The household marshal is mounted before the bell finishes ringing.",
		"weight": 3,
		"min_week": 8,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 50,
				"note": "Your knight leads the relief. The raiders break before contact; the village is grateful in the small ways that compound.",
				"effects": [{"kind": "reputation_range", "min": 4, "max": 8}, {"kind": "reward_resources", "min": 1, "max": 3}],
			},
			{
				"weight": 30,
				"note": "Your knight arrives in time to fight. A small skirmish, a worthwhile result. One of yours bears a bruise; the village bears a grain debt.",
				"effects": [{"kind": "reputation_range", "min": 2, "max": 5}, {"kind": "random_unit_injury"}, {"kind": "gold_range", "min": 4, "max": 10}],
			},
			{
				"weight": 20,
				"note": "Your knight arrives after the worst is done. The household helps rebuild; the village remembers the help, not the timing.",
				"effects": [{"kind": "reputation_range", "min": 1, "max": 3}, {"kind": "gold_range", "min": -10, "max": -5}, {"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"train_local_militia": {
		"label":  "Training the Local Militia",
		"intro":  "The nearest village's headman asks if your marshal might spend a week with their farmhands and a stand of practice spears.",
		"weight": 2,
		"min_week": 10,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 55,
				"note": "The marshal goes for the week and comes home tired. The village's drill improves; word travels.",
				"effects": [{"kind": "reputation_range", "min": 2, "max": 5}, {"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "Your knight goes in the marshal's stead. He drills the farmhands himself; the chronicler enjoys the irony.",
				"effects": [{"kind": "reputation_range", "min": 3, "max": 6}, {"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
			},
			{
				"weight": 15,
				"note": "The household declines, politely. The village finds the refusal less polite than the wording suggested.",
				"effects": [{"kind": "reputation", "amount": -2}],
			},
		],
	},

	"protect_harvest_festival": {
		"label":  "Protect the Harvest Festival",
		"intro":  "The harvest fair runs three days; the road through the marches has been thin on patrols. Someone has to walk it.",
		"weight": 2,
		"min_week": 18,
		"max_week": 42,
		"outcomes": [
			{
				"weight": 50,
				"note": "Your knight rides the road and stations a presence at the fair. Nothing bad happens; the chronicler will not be allowed to forget that this is the result the household paid for.",
				"effects": [{"kind": "reputation_range", "min": 2, "max": 5}, {"kind": "gold_range", "min": 4, "max": 10}],
			},
			{
				"weight": 30,
				"note": "A small ambush is broken on the second night. One of yours earns a bruise and a longer story.",
				"effects": [{"kind": "reputation_range", "min": 3, "max": 7}, {"kind": "random_unit_injury"}, {"kind": "gold_range", "min": 8, "max": 16}],
			},
			{
				"weight": 20,
				"note": "Your knight is too late to a small incident. The fair carries on; the village's gratitude is shorter than it would have been.",
				"effects": [{"kind": "reputation", "amount": -1}, {"kind": "gold_range", "min": 4, "max": 8}],
			},
		],
	},

	"defend_trade_caravan": {
		"label":  "Defend a Trade Caravan",
		"intro":  "A merchants' caravan asks safe passage through the household's stretch of road, paying handsomely up front.",
		"weight": 3,
		"min_week": 6,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 50,
				"note": "The caravan rides through under your colours. No incident. The merchants pay the rest of their fee and recommend the household further down the road.",
				"effects": [{"kind": "gold_range", "min": 12, "max": 22}, {"kind": "reputation_range", "min": 1, "max": 3}],
			},
			{
				"weight": 30,
				"note": "A brace of bandits tries the column at dusk. Your party drives them off; a small bonus is paid for the inconvenience.",
				"effects": [{"kind": "gold_range", "min": 16, "max": 28}, {"kind": "reputation_range", "min": 2, "max": 4}, {"kind": "random_unit_injury"}],
			},
			{
				"weight": 20,
				"note": "A cart is lost on the road; the merchants pay the agreed fee but no more. The chronicler files it as a quiet lesson on bridge maintenance.",
				"effects": [{"kind": "gold_range", "min": 6, "max": 12}, {"kind": "reputation", "amount": -1}],
			},
		],
	},

	"rescue_lost_pilgrim": {
		"label":  "Rescue a Lost Pilgrim",
		"intro":  "A villager comes to the gate at dusk: an old pilgrim of some local note is missing on the moor, two nights now, and the moor takes longer than two nights.",
		"weight": 2,
		"min_week": 8,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 55,
				"note": "Your knight rides out at moonrise and finds him before dawn. Cold, weak, alive. The village's gratitude is the kind that lasts.",
				"effects": [{"kind": "reputation_range", "min": 3, "max": 6}, {"kind": "all_units_stat", "stat": "determination", "delta": 1}],
			},
			{
				"weight": 25,
				"note": "The pilgrim is found at dawn beside a small fire of his own making, cheerful about it. The household carries him home; the village sends bread for a week.",
				"effects": [{"kind": "reputation_range", "min": 1, "max": 3}, {"kind": "inventory_add", "id": "plant_fibres", "min": 1, "max": 2}],
			},
			{
				"weight": 20,
				"note": "The pilgrim is found too late. The household holds the wake; the chaplain reads. The village remembers it was your knight who rode out at all.",
				"effects": [{"kind": "reputation_range", "min": 1, "max": 2}, {"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	# ---- Batch 4 — broader sweep over the user's remaining list ----

	"ambushed_on_the_road": {
		"label":  "Ambushed on the Road",
		"intro":  "A small patrol returns at dusk lighter than it set out — three bow shots from the treeline, two riders' worth of luck, and a story that no one tells the same way twice.",
		"weight": 3,
		"min_week": 8,
		"outcomes": [
			{
				"weight": 45,
				"note": "They lose a saddle's worth of coin and the better part of an afternoon. The patrol comes home in formation; one of yours limps a week.",
				"effects": [{"kind": "gold_range", "min": -12, "max": -6}, {"kind": "random_unit_injury"}],
			},
			{
				"weight": 35,
				"note": "They turn and ride the ambushers off the road. The chronicler sells the story to a bard within the fortnight.",
				"effects": [{"kind": "random_unit_stat", "stat": "swordsmanship", "delta": 1}, {"kind": "reputation_range", "min": 1, "max": 3}],
			},
			{
				"weight": 20,
				"note": "An ill-judged charge breaks the patrol. Loss of coin and longer loss of nerve.",
				"effects": [{"kind": "gold_range", "min": -16, "max": -10}, {"kind": "random_unit_stat", "stat": "bravery", "delta": -1}],
			},
		],
	},

	"equipment_rusts_in_rain": {
		"label":  "Equipment Rusts in the Rain",
		"intro":  "A long wet spell finds three weeks of inattention in the armoury. The smith opens the racks and breathes through his teeth.",
		"weight": 2,
		"min_week": 8,
		"min_gold": 8,
		"outcomes": [
			{
				"weight": 55,
				"note": "Repairs are made before any kit is lost. The smith charges fair for the rush; the marshal sets a new oiling rota.",
				"effects": [{"kind": "gold_range", "min": -12, "max": -8}],
			},
			{
				"weight": 30,
				"note": "Two helms and a hauberk are too far gone. The smith reforges what he can.",
				"effects": [{"kind": "gold_range", "min": -16, "max": -10}, {"kind": "inventory_remove", "id": "iron_ore", "min": 1, "max": 2}],
			},
			{
				"weight": 15,
				"note": "The marshal handles it himself with three apprentices and a single barrel of oil. The household pays only in time.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
		],
	},

	"missing_scout": {
		"label":  "A Missing Scout",
		"intro":  "A scout assigned to the far ridge has not come back at the third watch. The marshal is too composed about it; the chaplain is not.",
		"weight": 2,
		"min_week": 10,
		"outcomes": [
			{
				"weight": 50,
				"note": "He walks in three days later, sheepish and footsore, with a long story and a longer apology. The marshal does not accept either.",
				"effects": [{"kind": "random_unit_stat", "stat": "loyalty", "delta": -1}],
			},
			{
				"weight": 30,
				"note": "He is found by a search party at the bottom of a ravine. The wound is bad; the will is intact.",
				"effects": [{"kind": "random_unit_injury"}],
			},
			{
				"weight": 20,
				"note": "He returns with intelligence the marshal asked for and did not expect — a small camp on the far ridge, badly defended.",
				"effects": [{"kind": "pa_delta", "min": 3, "max": 6}, {"kind": "random_unit_stat", "stat": "speed", "delta": 1}],
			},
		],
	},

	"corrupted_well": {
		"label":  "A Corrupted Well",
		"intro":  "The east well goes brackish on a Tuesday. The chaplain calls a verdict before the smith finishes his test; the smith confirms it by Wednesday.",
		"weight": 2,
		"min_week": 10,
		"outcomes": [
			{
				"weight": 50,
				"note": "Two of yours take ill before the household realises. The well is sealed, a deeper one dug. Recovery takes the week it ought.",
				"effects": [{"kind": "random_unit_injury"}, {"kind": "random_unit_injury"}],
			},
			{
				"weight": 30,
				"note": "The chaplain catches it early; the household uses the south well exclusively for a fortnight. Inconvenience, not illness.",
				"effects": [{"kind": "gold", "amount": -6}, {"kind": "random_unit_stat", "stat": "determination", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "It is not natural. The chaplain says little; the marshal doubles the watch on the well-head. By the third night the source is caught and dealt with.",
				"effects": [{"kind": "random_unit_stat", "stat": "intimidation", "delta": 1}, {"kind": "reputation", "amount": 1}],
			},
		],
	},

	"cave_in_blocks_route": {
		"label":  "A Cave-In Blocks the Route",
		"intro":  "An older road through the hills is suddenly a longer road through the hills. The chronicler asks the road-master what happened; the road-master shrugs.",
		"weight": 2,
		"min_week": 8,
		"outcomes": [
			{
				"weight": 60,
				"note": "Active parties on the far side detour. They will arrive later than the marshal would prefer; they will arrive.",
				"effects": [{"kind": "expedition_delay", "min": 1, "max": 2}],
			},
			{
				"weight": 25,
				"note": "A clearing crew is hired in the village. The route is open again by the end of the week; the household coffers are lighter.",
				"effects": [{"kind": "gold_range", "min": -14, "max": -8}],
			},
			{
				"weight": 15,
				"note": "Old worked stone is found beneath the slip. The chronicler is happier than the marshal. A small amount of dressed timber and iron is salvaged.",
				"effects": [{"kind": "inventory_add", "id": "iron_ore", "min": 1, "max": 2}, {"kind": "inventory_add", "id": "logs", "min": 1, "max": 2}],
			},
		],
	},

	"strange_whispers_in_camp": {
		"label":  "Strange Whispers in Camp",
		"intro":  "The watch reports talking in the lower stable at the second hour. The marshal investigates; finds nobody, and is the more uneasy for it.",
		"weight": 2,
		"min_week": 12,
		"outcomes": [
			{
				"weight": 50,
				"note": "Two of yours sleep poorly for a week. The chaplain says prayers; one of yours stops listening for the voice and starts listening past it.",
				"effects": [{"kind": "random_unit_stat", "stat": "loyalty", "delta": -1}, {"kind": "random_unit_stat", "stat": "determination", "delta": -1}],
			},
			{
				"weight": 30,
				"note": "Your knight stands the watch personally on the third night. The whispers do not return. The chronicler writes a careful entry on the subject.",
				"effects": [{"kind": "random_unit_stat", "stat": "bravery", "delta": 1}, {"kind": "pa_delta", "min": 2, "max": 5}],
			},
			{
				"weight": 20,
				"note": "The whispers are pinned, eventually, to a draught and an old beam. The household laughs the longer for it.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"enemy_scouts_observed": {
		"label":  "Enemy Scouts Observed Nearby",
		"intro":  "The watch reports two riders on the south ridge at moonrise, unmarked, unsmoked. They were gone before a sortie could be raised.",
		"weight": 2,
		"min_week": 10,
		"outcomes": [
			{
				"weight": 50,
				"note": "The marshal sets a routine. Three nights of doubled watch; nothing returns. The household sleeps lighter and rises sharper.",
				"effects": [{"kind": "random_unit_stat", "stat": "speed", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "A counter-scout returns with a sketch and a rough count. Useful intelligence, badly drawn.",
				"effects": [{"kind": "pa_delta", "min": 3, "max": 7}],
			},
			{
				"weight": 20,
				"note": "The household errs on the side of fortification. The smith bills the marshal for a week's work on the gate hinges.",
				"effects": [{"kind": "gold_range", "min": -8, "max": -4}, {"kind": "all_units_stat", "stat": "bravery", "delta": 1}],
			},
		],
	},

	"ancient_curse_unearthed": {
		"label":  "An Ancient Curse Unearthed",
		"intro":  "Diggers in the back orchard turn up a flat stone with markings the chaplain refuses to translate aloud.",
		"weight": 1,
		"min_week": 20,
		"outcomes": [
			{
				"weight": 50,
				"note": "The stone is reburied with a proper word said over it. One of yours sleeps badly for the week; the household pretends not to notice.",
				"effects": [{"kind": "random_unit_stat", "stat": "bravery", "delta": -1}, {"kind": "random_unit_injury"}],
			},
			{
				"weight": 30,
				"note": "The chronicler copies the markings carefully and sends them to a scholar three valleys away. The reply, when it comes, is not reassuring; the household closes ranks.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}, {"kind": "pa_delta", "min": -4, "max": -2}],
			},
			{
				"weight": 20,
				"note": "The stone is broken with a hammer at noon by a chaplain who has had quite enough of it. Nothing further happens.",
				"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": 1}],
			},
		],
	},

	"ancient_shrine": {
		"label":  "An Ancient Shrine",
		"intro":  "Outriders find a small stone shrine in a clearing nobody had thought to map. The carvings are old; the offerings are recent.",
		"weight": 2,
		"min_week": 14,
		"outcomes": [
			{
				"weight": 50,
				"note": "Your knight leaves a small token and rides on. He sleeps well that night, oddly settled.",
				"effects": [{"kind": "gold", "amount": -3}, {"kind": "pa_delta", "min": 4, "max": 9}],
			},
			{
				"weight": 30,
				"note": "The chaplain holds a small ceremony at the shrine. The household rides home in a more measured silence than it set out with.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "A pilgrim is camped at the shrine and shares a useful piece of road-lore in exchange for bread.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
			},
		],
	},

	"time_moves_strangely": {
		"label":  "Time Moves Strangely Here",
		"intro":  "A patrol returns from the eastern marshes insisting they were gone three days. The chronicler's tally says one. Both parties become quiet, then change subject.",
		"weight": 1,
		"min_week": 24,
		"outcomes": [
			{
				"weight": 50,
				"note": "Nothing further happens. The chronicler writes the entry in two voices and underlines the disagreement.",
				"effects": [{"kind": "pa_delta", "min": 4, "max": 8}],
			},
			{
				"weight": 30,
				"note": "One of yours arrives home a fortnight after the rest of the patrol, swearing he rode straight through. He is shaken, and faster.",
				"effects": [{"kind": "random_unit_stat", "stat": "speed", "delta": 1}, {"kind": "random_unit_stat", "stat": "bravery", "delta": -1}],
			},
			{
				"weight": 20,
				"note": "Active parties on the road feel the wrinkle. They arrive a week late, and cannot quite say why.",
				"effects": [{"kind": "expedition_delay", "min": 1, "max": 2}, {"kind": "pa_delta", "min": 2, "max": 5}],
			},
		],
	},

	"merchant_cursed_relics": {
		"label":  "A Merchant Sells \"Definitely Not Cursed\" Relics",
		"intro":  "A merchant whose papers are too clean offers three items at three prices, each promising luck of the kind he is happy to discuss.",
		"weight": 1,
		"min_week": 16,
		"min_gold": 15,
		"outcomes": [
			{
				"weight": 40,
				"note": "Your knight buys one. It is not cursed; it is a perfectly ordinary silver pendant. The merchant rides on whistling.",
				"effects": [{"kind": "gold_range", "min": -14, "max": -8}, {"kind": "pa_delta", "min": 2, "max": 5}],
			},
			{
				"weight": 35,
				"note": "Your knight buys one. It is cursed. One of yours wears it for two days before the chaplain insists it be buried in salt.",
				"effects": [{"kind": "gold_range", "min": -18, "max": -12}, {"kind": "random_unit_injury"}],
			},
			{
				"weight": 25,
				"note": "Your knight haggles the merchant down to a story instead of a sale. The merchant is the poorer; the household, marginally, the wiser.",
				"effects": [{"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
			},
		],
	},

	"dragon_overhead": {
		"label":  "A Dragon Flies Overhead",
		"intro":  "On a clear day in the eighth month a dragon — actually a dragon — passes over the household at the height of a low cloud. It is gone before any horn can be raised.",
		"weight": 1,
		"min_week": 24,
		"outcomes": [
			{
				"weight": 50,
				"note": "It does not return. The household speaks of nothing else for a fortnight; the chronicler refuses to write down where it was last seen.",
				"effects": [{"kind": "all_units_stat", "stat": "bravery", "delta": 1}, {"kind": "pa_delta", "min": 3, "max": 7}],
			},
			{
				"weight": 30,
				"note": "Two of yours wake with the same dream three nights running. They will not say what it was. They are sharper for it.",
				"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": 1}, {"kind": "random_unit_stat", "stat": "technique", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "Word of the sighting carries. Houses three valleys over write polite letters of enquiry; the household chronicler writes back at length and the household's standing rises a measure.",
				"effects": [{"kind": "reputation_range", "min": 2, "max": 5}],
			},
		],
	},

	"eclipse_darkens_the_region": {
		"label":  "An Eclipse Darkens the Region",
		"intro":  "A noon eclipse falls without warning the almanac had thought to issue. The chaplain says a long word; the marshal says nothing.",
		"weight": 1,
		"min_week": 18,
		"outcomes": [
			{
				"weight": 50,
				"note": "The household weathers it. Lamps lit, prayers said, eyes carefully on the work in hand. Confidence holds.",
				"effects": [{"kind": "all_units_stat", "stat": "bravery", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "Two of yours admit, days later, that the dark unsettled them. The chaplain says little; the marshal moves a drill earlier in the morning.",
				"effects": [{"kind": "random_unit_stat", "stat": "loyalty", "delta": -1}, {"kind": "random_unit_stat", "stat": "determination", "delta": -1}],
			},
			{
				"weight": 20,
				"note": "An old book is consulted; an old promise is renewed. The household sleeps differently for a week, and somebody in it sleeps the deeper for it.",
				"effects": [{"kind": "pa_delta", "min": 3, "max": 8}],
			},
		],
	},

	"strange_obelisk": {
		"label":  "A Strange Obelisk",
		"intro":  "Scouts report a black stone standing alone in a clearing where no stone of that kind has any business being.",
		"weight": 1,
		"min_week": 22,
		"outcomes": [
			{
				"weight": 50,
				"note": "It is approached carefully and inspected at distance. Nothing happens; the chronicler writes it up; the marshal stops mentioning it.",
				"effects": [{"kind": "pa_delta", "min": 3, "max": 6}],
			},
			{
				"weight": 30,
				"note": "One of yours places a hand on it. The handprint stays. He sleeps strangely for a week, dreams well, wakes sharper.",
				"effects": [{"kind": "random_unit_stat", "stat": "technique", "delta": 1}, {"kind": "pa_delta", "min": 4, "max": 9}],
			},
			{
				"weight": 20,
				"note": "The chaplain insists it be left alone, and the marshal complies for once. The patrol rides home in silence.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	# ---- Batch 5 — home-mission flavour events (story-resolved, no new combat path) ----

	"hunt_forest_beast": {
		"label":  "Hunt a Forest Beast",
		"intro":  "Three villages on the western edge report a wolf-pack with a leader the size of a yearling pony. The chronicler suspects exaggeration; the chaplain suspects worse.",
		"weight": 2,
		"min_week": 6,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 50,
				"note": "Your knight leads the hunt and ends it before dusk. The villages take it as their gift; the household takes the hide.",
				"effects": [{"kind": "reputation_range", "min": 2, "max": 4}, {"kind": "inventory_add", "id": "plant_fibres", "min": 1, "max": 3}],
			},
			{
				"weight": 30,
				"note": "The hunt is hard; the beast was no exaggeration. One of yours bears a long bite home.",
				"effects": [{"kind": "reputation_range", "min": 3, "max": 5}, {"kind": "random_unit_injury"}, {"kind": "inventory_add", "id": "iron_ore", "min": 1, "max": 2}],
			},
			{
				"weight": 20,
				"note": "The beast slips the noose. The villages take the gesture as enough; the chronicler does not.",
				"effects": [{"kind": "reputation", "amount": 1}, {"kind": "random_unit_stat", "stat": "loyalty", "delta": 1}],
			},
		],
	},

	"missing_child_in_woods": {
		"label":  "A Missing Child in the Woods",
		"intro":  "A miller's daughter, six years old, did not come back at sundown. The miller is at the gate before the watch finishes its evening report.",
		"weight": 2,
		"min_week": 5,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 55,
				"note": "She is found by dawn under a hawthorn, cold and stubborn and alive. The village remembers it for a year.",
				"effects": [{"kind": "reputation_range", "min": 4, "max": 7}, {"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
			{
				"weight": 25,
				"note": "She is found at noon by the river — wet, frightened, fine. The household carries her home. The miller will not be made to forget.",
				"effects": [{"kind": "reputation_range", "min": 2, "max": 4}],
			},
			{
				"weight": 20,
				"note": "She is not found. The household holds the wake; the chaplain reads. The village remembers it was your knight who rode out at all.",
				"effects": [{"kind": "reputation", "amount": 1}, {"kind": "all_units_stat", "stat": "determination", "delta": 1}],
			},
		],
	},

	"repair_village_defences": {
		"label":  "Repair the Village Defences",
		"intro":  "The headman of the nearest village comes with a request and a small cap in his hand: the palisade is weak in three places and the spring is bad for raiders.",
		"weight": 2,
		"min_week": 10,
		"min_gold": 20,
		"outcomes": [
			{
				"weight": 60,
				"note": "Your household funds the work and lends two pairs of hands. The palisade goes up straight; the village goes home thankful.",
				"effects": [{"kind": "gold_range", "min": -22, "max": -14}, {"kind": "reputation_range", "min": 3, "max": 6}],
			},
			{
				"weight": 25,
				"note": "The marshal goes for a week with timber and instruction. The wall comes up cheaper than the headman expected.",
				"effects": [{"kind": "gold_range", "min": -10, "max": -6}, {"kind": "inventory_remove", "id": "logs", "min": 2, "max": 3}, {"kind": "reputation_range", "min": 2, "max": 4}],
			},
			{
				"weight": 15,
				"note": "The household declines for now. The headman is polite. The village is less so by the next month.",
				"effects": [{"kind": "reputation", "amount": -2}],
			},
		],
	},

	"investigate_haunted_mill": {
		"label":  "Investigate the Haunted Mill",
		"intro":  "Two coopers and a herald insist the old mill on the river bend is haunted. The chronicler asks if they were drunk. The chronicler is told it does not matter.",
		"weight": 2,
		"min_week": 12,
		"outcomes": [
			{
				"weight": 50,
				"note": "The mill is occupied by a family of squatters and a clever badger. The household sees them moved on; the village laughs the louder for the story.",
				"effects": [{"kind": "reputation_range", "min": 1, "max": 3}],
			},
			{
				"weight": 30,
				"note": "The mill is genuinely strange. Your knight stands the watch personally and returns at dawn with little to say. The household sleeps better and the chaplain sleeps worse.",
				"effects": [{"kind": "pa_delta", "min": 4, "max": 9}, {"kind": "random_unit_stat", "stat": "bravery", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "Three of yours spend the night in the mill on a dare. By morning, two of them are sharper; one of them is shaken.",
				"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": 1}, {"kind": "random_unit_stat", "stat": "bravery", "delta": -1}],
			},
		],
	},

	"clear_infested_mine": {
		"label":  "Clear an Infested Mine",
		"intro":  "A mining outpost on the lower hills has been abandoned for two months — the foreman blames goblins; the herald blames worse; the steward blames the foreman.",
		"weight": 2,
		"min_week": 16,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 50,
				"note": "Your knight leads a sortie and clears the workings in a single afternoon. The mine reopens within the fortnight; the household takes a small cut.",
				"effects": [{"kind": "reputation_range", "min": 2, "max": 4}, {"kind": "inventory_add", "id": "iron_ore", "min": 3, "max": 6}],
			},
			{
				"weight": 30,
				"note": "The workings are harder than expected. One of yours pays the cost of the lesson. The mine reopens with a smaller share.",
				"effects": [{"kind": "reputation_range", "min": 1, "max": 3}, {"kind": "random_unit_injury"}, {"kind": "inventory_add", "id": "iron_ore", "min": 1, "max": 3}],
			},
			{
				"weight": 20,
				"note": "The sortie is repulsed. The mine remains shut; your knight sleeps poorly for a week and writes a careful letter to the foreman.",
				"effects": [{"kind": "reputation", "amount": -1}, {"kind": "random_unit_stat", "stat": "determination", "delta": 1}],
			},
		],
	},

	"deliver_urgent_medicine": {
		"label":  "Deliver Urgent Medicine",
		"intro":  "A small village three days' ride out has the kind of illness the chaplain has read about and the village has not. A box of green-glass bottles needs a fast rider.",
		"weight": 2,
		"min_week": 8,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 55,
				"note": "Your knight rides the box to the village in two days and a forced night. The village rises again; word travels.",
				"effects": [{"kind": "reputation_range", "min": 3, "max": 6}, {"kind": "random_unit_stat", "stat": "horsemanship", "delta": 1}],
			},
			{
				"weight": 30,
				"note": "The ride is delayed by weather. The medicine arrives in time for some and too late for others. The village remembers your knight rode.",
				"effects": [{"kind": "reputation_range", "min": 1, "max": 3}, {"kind": "expedition_delay", "min": 1, "max": 2}],
			},
			{
				"weight": 15,
				"note": "Bandits attempt the rider on the third day. Your knight rides through; the box arrives unbroken. Word of the rider travels further than the medicine.",
				"effects": [{"kind": "reputation_range", "min": 4, "max": 7}, {"kind": "random_unit_injury"}],
			},
		],
	},

	# ---- Batch 6 — events with stat_check decision branches ----

	"mutiny_brewing": {
		"label":  "Mutiny Brewing",
		"intro":  "Two of yours have been talking in low voices near the back of the stable for three nights running. The marshal has noticed; the marshal will not say so aloud.",
		"weight": 2,
		"min_week": 12,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "leadership",
					"scope": "best",
					"threshold": 12,
					"on_pass": {
						"note": "Your knight walks the bunks himself at the small hours, speaks to each of them by name, and asks a question apiece. By dawn the talk is gone and the household closes on something steadier than discipline.",
						"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
					},
					"on_fail": {
						"note": "Discipline holds only so far as habit carries it. The talkers slip away on a quiet morning; the marshal blames himself and the chronicler blames the weather.",
						"effects": [{"kind": "random_unit_stat", "stat": "loyalty", "delta": -2}, {"kind": "gold_range", "min": -10, "max": -4}],
					},
				},
			},
		],
	},

	"negotiate_dispute": {
		"label":  "Negotiate Between Rival Villages",
		"intro":  "Two villages on the household's stretch of road have spent the spring escalating a grievance about a mill weir. The headmen ride to the gate within an hour of each other.",
		"weight": 2,
		"min_week": 10,
		"min_roster_at_home": 1,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "etiquette",
					"scope": "best",
					"threshold": 12,
					"on_pass": {
						"note": "Your knight seats them at one table, speaks for an evening of careful nothing, and by the second jug the weir is half-settled and the chronicler is taking notes for the deed.",
						"effects": [{"kind": "reputation_range", "min": 3, "max": 6}, {"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
					},
					"on_fail": {
						"note": "The negotiation goes long, and longer, and worse. By the third day one headman rides off in the small hours; the other will not speak to your knight again before harvest.",
						"effects": [{"kind": "reputation_range", "min": -4, "max": -2}, {"kind": "random_unit_stat", "stat": "loyalty", "delta": -1}],
					},
				},
			},
		],
	},

	"stare_down_rival": {
		"label":  "A Rival House Calls",
		"intro":  "A neighbouring lord's banner rides the boundary road in a strength that is not by accident. They will not knock at the gate; they will not turn around without one.",
		"weight": 2,
		"min_week": 14,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "intimidation",
					"scope": "best",
					"threshold": 11,
					"on_pass": {
						"note": "Your knight rides out alone to meet them, says less than they expected, and stands on the road long enough that the banner turns. The household watches from the wall; the chronicler watches the road for an hour after.",
						"effects": [{"kind": "reputation_range", "min": 2, "max": 5}, {"kind": "random_unit_stat", "stat": "intimidation", "delta": 1}],
					},
					"on_fail": {
						"note": "Your knight rides out and finds the standoff longer than it ought to be. By dusk a token tribute is paid for safe passage; the rival rides on smiling.",
						"effects": [{"kind": "gold_range", "min": -16, "max": -8}, {"kind": "reputation", "amount": -2}],
					},
				},
			},
		],
	},

	"endure_long_march": {
		"label":  "Endure a Long March",
		"intro":  "An old debt asks the household to ride three days at speed to attend a vassal swearing — not the knight, but a banner, and a banner needs men behind it.",
		"weight": 2,
		"min_week": 16,
		"min_roster_at_home": 3,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "determination",
					"scope": "all_avg",
					"threshold": 9,
					"on_pass": {
						"note": "The march holds. The household arrives on the third day in good order, stands the witness, and rides home heavier with the patron's quiet pleasure than with anything else.",
						"effects": [{"kind": "all_units_stat", "stat": "determination", "delta": 1}, {"kind": "reputation_range", "min": 2, "max": 4}],
					},
					"on_fail": {
						"note": "The march does not. By the second day two of yours are walking lame and the chaplain rides back for them. The witnessing is honoured in absence; the patron writes a polite letter.",
						"effects": [{"kind": "random_unit_injury"}, {"kind": "reputation", "amount": 1}],
					},
				},
			},
		],
	},

	"read_the_forged_letter": {
		"label":  "A Forged Letter",
		"intro":  "A sealed parchment arrives by hand, neither rider quite saying where it came from. The seal looks right. Something about the hand on the address is not.",
		"weight": 2,
		"min_week": 12,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "technique",
					"scope": "best",
					"threshold": 12,
					"on_pass": {
						"note": "Your knight reads it twice, then once more with the chronicler at his elbow. The forgery is named, the trap unsprung; a small gain is taken from the would-be deceiver in turn.",
						"effects": [{"kind": "gold_range", "min": 8, "max": 18}, {"kind": "reputation", "amount": 2}],
					},
					"on_fail": {
						"note": "The letter is acted on. By the time the forgery is plain, a small sum has gone where it shouldn't and the chronicler has a long entry to write.",
						"effects": [{"kind": "gold_range", "min": -18, "max": -10}, {"kind": "random_unit_stat", "stat": "technique", "delta": 1}],
					},
				},
			},
		],
	},

	"read_the_room": {
		"label":  "A Polite Dinner",
		"intro":  "A neighbouring lord's eldest daughter, lately knighted in her own right, calls for an evening's hospitality. The conversation will be entirely about something other than what it is about.",
		"weight": 2,
		"min_week": 10,
		"min_gold": 6,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "etiquette",
					"scope": "knight",
					"threshold": 11,
					"on_pass": {
						"note": "Your knight reads the room the way the chronicler reads a deed. By the third course the matter is half-settled, by the fifth it is fully settled, and at dawn the household is gifted a small barrel and a recommendation.",
						"effects": [{"kind": "reputation_range", "min": 2, "max": 4}, {"kind": "gold_range", "min": 6, "max": 14}, {"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
					},
					"on_fail": {
						"note": "Your knight reads the room poorly. The lady rides home before lauds, polite enough. By the next week the chronicler notes a cooling that will take time to thaw.",
						"effects": [{"kind": "gold_range", "min": -8, "max": -4}, {"kind": "reputation", "amount": -2}],
					},
				},
			},
		],
	},

	# ---- Batch 7 — more stat_check events across less-used stat axes ----

	"calm_spooked_horse": {
		"label":  "A Spooked Horse",
		"intro":  "The household's best riding horse takes against the morning, refuses the bit, and threatens to break a leg in the yard. Someone has to set it right before the smith arrives.",
		"weight": 2,
		"min_week": 6,
		"min_roster_at_home": 1,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "horsemanship",
					"scope": "best",
					"threshold": 9,
					"on_pass": {
						"note": "Your best horseman walks it down — slow steps, low voice, a slow turn against the wind. By noon the horse is back in the stable and asleep on its feet.",
						"effects": [{"kind": "random_unit_stat", "stat": "horsemanship", "delta": 1}],
					},
					"on_fail": {
						"note": "The horse goes through three handlers before the marshal admits it must be brought down. Someone catches a hoof in the doing.",
						"effects": [{"kind": "random_unit_injury"}, {"kind": "gold_range", "min": -10, "max": -6}],
					},
				},
			},
		],
	},

	"lead_the_charge": {
		"label":  "Lead the Charge",
		"intro":  "A neighbouring lord asks the household to ride at the head of a small relief — they have the numbers; they need the banner.",
		"weight": 2,
		"min_week": 16,
		"min_roster_at_home": 2,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "bravery",
					"scope": "best",
					"threshold": 12,
					"on_pass": {
						"note": "Your knight rides at the front. The line forms behind him; the relief arrives on time and in order. The chronicler will not stop talking about it.",
						"effects": [{"kind": "reputation_range", "min": 4, "max": 7}, {"kind": "random_unit_stat", "stat": "bravery", "delta": 1}],
					},
					"on_fail": {
						"note": "The line wavers, then turns. The relief gets through, but late. One of yours bears a cut more from the chronicler's eyes than the field.",
						"effects": [{"kind": "reputation", "amount": -3}, {"kind": "random_unit_injury"}],
					},
				},
			},
		],
	},

	"outguess_card_player": {
		"label":  "Cards With a Stranger",
		"intro":  "A passing scholar with a deck of unusual cards proposes a hand at the household's table. The stakes are friendly; the cards are not.",
		"weight": 1,
		"min_week": 12,
		"min_gold": 12,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "technique",
					"scope": "knight",
					"threshold": 10,
					"on_pass": {
						"note": "Your knight watches the second hand more than the first, and calls the third on a feeling that has nothing to do with cards. The scholar pays the wager and stays to be taught a thing or two.",
						"effects": [{"kind": "gold_range", "min": 8, "max": 18}, {"kind": "pa_delta", "min": 3, "max": 7}],
					},
					"on_fail": {
						"note": "The scholar is patient, and pleasant, and very good. By the fourth hand the household coffers are lighter and your knight is teaching the marshal a polite phrase he learned that evening.",
						"effects": [{"kind": "gold_range", "min": -16, "max": -10}],
					},
				},
			},
		],
	},

	"hold_line_at_drill": {
		"label":  "Hold the Line at Drill",
		"intro":  "The marshal sets a long drill on a hot afternoon — the kind that finds the breaking point of whoever was thinking of breaking.",
		"weight": 2,
		"min_week": 8,
		"min_roster_at_home": 3,
		"outcomes": [
			{
				"weight": 100,
				"stat_check": {
					"stat": "loyalty",
					"scope": "all_avg",
					"threshold": 8,
					"on_pass": {
						"note": "Nobody falls out. The marshal makes a small thing of it at dusk — bread on the line, one cup of the better wine, a few words said quietly. Something is set.",
						"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}, {"kind": "random_unit_stat", "stat": "determination", "delta": 1}],
					},
					"on_fail": {
						"note": "Two of yours drop out before noon. The marshal does not punish; he just walks away and lets the silence do it. Resentment ferments quietly across the week.",
						"effects": [{"kind": "random_unit_stat", "stat": "determination", "delta": -1}, {"kind": "random_unit_stat", "stat": "loyalty", "delta": -1}],
					},
				},
			},
		],
	},

	# ---- Batch 8 — more chronicle variety ----

	"sworn_sister_arrives": {
		"label":  "A Sworn Sister Arrives",
		"intro":  "A knight in another household's colours rides for the gate, her own seal in hand. She and your knight took a sworn-sibling oath a decade ago in a tournament neither will discuss aloud.",
		"weight": 2,
		"min_week": 14,
		"min_roster_at_home": 1,
		"outcomes": [
			{
				"weight": 55,
				"note": "They spar at dusk, drink past matins, and your knight rides into next week the steadier for an old friend's quiet attention.",
				"effects": [{"kind": "random_unit_stat", "stat": "swordsmanship", "delta": 1}, {"kind": "pa_delta", "min": 4, "max": 9}],
			},
			{
				"weight": 30,
				"note": "She has news of an old enemy. The household coffers loosen for a small purse pressed into her hand; the chronicler will not write what was traded for it.",
				"effects": [{"kind": "gold_range", "min": -14, "max": -8}, {"kind": "reputation_range", "min": 1, "max": 3}],
			},
			{
				"weight": 15,
				"note": "She rides on at first light without explanation. Your knight stands at the gate longer than usual that morning.",
				"effects": [{"kind": "pa_delta", "min": -4, "max": 2}],
			},
		],
	},

	"quiet_anniversary": {
		"label":  "A Quiet Anniversary",
		"intro":  "The household chronicler reminds your knight, at breakfast, that today is the anniversary of a campaign or a vow or a loss the knight remembers well enough.",
		"weight": 2,
		"min_week": 18,
		"outcomes": [
			{
				"weight": 60,
				"note": "Your knight spends the morning at the chapel, the afternoon in the garden, and the evening with the chronicler. Nothing is said that needs writing down; everything is set the firmer for the saying.",
				"effects": [{"kind": "random_unit_stat", "stat": "loyalty", "delta": 1}, {"kind": "pa_delta", "min": 3, "max": 7}],
			},
			{
				"weight": 25,
				"note": "Your knight will not mark it, but the household marks it for him. By dusk the staff has set a small table with the better wine and a single empty chair.",
				"effects": [{"kind": "all_units_stat", "stat": "loyalty", "delta": 1}],
			},
			{
				"weight": 15,
				"note": "It goes badly. The wine is finished early; the chronicler closes his book without writing. By dawn the marshal has the day's drill ready and no one mentions it again.",
				"effects": [{"kind": "random_unit_stat", "stat": "bravery", "delta": -1}, {"kind": "pa_delta", "min": -5, "max": -1}],
			},
		],
	},

	"borrowed_book_returns": {
		"label":  "A Borrowed Book Returns",
		"intro":  "A volume your knight lent out three winters ago is delivered to the gate by a careful porter with a careful note. The book has been read, used, and respected.",
		"weight": 1,
		"min_week": 12,
		"outcomes": [
			{
				"weight": 60,
				"note": "Your knight reads the marginalia the borrower left. He learns something he did not know about a campaign he thought he understood.",
				"effects": [{"kind": "random_unit_stat", "stat": "technique", "delta": 1}, {"kind": "pa_delta", "min": 2, "max": 6}],
			},
			{
				"weight": 25,
				"note": "The chronicler reads the marginalia first, and writes a long entry on the borrower's handwriting alone. The library is the richer for it.",
				"effects": [{"kind": "pa_delta", "min": 3, "max": 7}],
			},
			{
				"weight": 15,
				"note": "The book is returned damaged. The borrower's note is apologetic; your knight reads the note twice, the book once, and writes a polite letter.",
				"effects": [{"kind": "random_unit_stat", "stat": "etiquette", "delta": 1}],
			},
		],
	},

	"long_winter_warning": {
		"label":  "A Long-Winter Warning",
		"intro":  "An old neighbour comes to the gate at noon with bad news in three voices: an early frost in the south, a late lambing in the west, and the river running shallow.",
		"weight": 2,
		"min_week": 28,
		"max_week": 44,
		"outcomes": [
			{
				"weight": 50,
				"note": "Your knight buys grain at the day's prices, not next month's. The chronicler files the receipt with quiet pleasure.",
				"effects": [{"kind": "gold_range", "min": -14, "max": -8}, {"kind": "inventory_add", "id": "plant_fibres", "min": 2, "max": 4}],
			},
			{
				"weight": 30,
				"note": "Your knight orders the household to dig deeper on the back well and chop more timber than the marshal thinks is needed. The marshal is wrong this week; the marshal will write the inventory longer next month.",
				"effects": [{"kind": "inventory_add", "id": "logs", "min": 2, "max": 4}, {"kind": "all_units_stat", "stat": "determination", "delta": 1}],
			},
			{
				"weight": 20,
				"note": "Your knight thanks the neighbour, doubles the watch on the kitchen stores, and asks the chaplain to say a longer word at supper.",
				"effects": [{"kind": "random_unit_stat", "stat": "leadership", "delta": 1}],
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

	# stat_check resolution: if the outcome carries a `stat_check` block, we
	# evaluate it now and substitute the pass / fail branch's note + effects
	# in place of the outcome's own. Outcomes without `stat_check` resolve
	# normally — the field is opt-in so the 68 existing events are unaffected.
	var note_to_emit: String = str(outcome.get("note", ""))
	var effects_to_apply: Array = outcome.get("effects", [])
	if outcome.has("stat_check"):
		var branch: Dictionary = _resolve_stat_check(gs, outcome["stat_check"], result)
		if not branch.is_empty():
			note_to_emit = str(branch.get("note", note_to_emit))
			effects_to_apply = branch.get("effects", effects_to_apply)

	if note_to_emit != "":
		result["notes"].append(note_to_emit)

	for effect in effects_to_apply:
		_apply_effect(gs, effect, result)


# Resolve a stat_check block, returning the appropriate {note, effects}
# branch. Adds a small chronicle line announcing which stat was rolled and
# whether it passed — gives the player a tactile sense of "the household's
# Leadership carried this" rather than the result feeling arbitrary.
#
# Schema:
#   stat_check: {
#     stat:       <stat key, e.g. "leadership">,
#     scope:      "best" (default) | "knight" | "all_avg",
#     threshold:  int — the value the chosen scope's number must meet,
#     on_pass:    {note, effects}
#     on_fail:    {note, effects}
#   }
#
# Returns the picked branch or {} if the block is malformed (defensive —
# falls back to the outcome's own note/effects in that case).
static func _resolve_stat_check(gs: Node, check: Dictionary, result: Dictionary) -> Dictionary:
	var stat: String = str(check.get("stat", ""))
	var threshold: int = int(check.get("threshold", 10))
	var scope: String = str(check.get("scope", "best"))
	if stat == "":
		return {}

	var value: int = _gather_stat_value(gs, stat, scope)
	var passed: bool = value >= threshold

	# Small visible chronicle line — players see what was checked and how it
	# landed without having to count stats themselves.
	var verb: String = "carried" if passed else "fell short of"
	var scope_label: String = _scope_label(scope, stat)
	result["notes"].append("(%s %s the test — %d vs %d.)" % [scope_label, verb, value, threshold])

	if passed:
		return check.get("on_pass", {})
	return check.get("on_fail", {})


# Read the relevant stat off the right unit(s) per the check's scope.
# "best" → max stat among at-home units (the most natural for one-knight-
#   decides events).
# "knight" → the household's Knight (class KNIGHT). Falls back to "best"
#   if the knight is on expedition.
# "all_avg" → integer average of the stat across at-home units. Used for
#   household-wide tests like "Endure a Long March."
static func _gather_stat_value(gs: Node, stat: String, scope: String) -> int:
	var pool: Array[Unit] = gs.at_home_units()
	if pool.is_empty():
		return 0
	match scope:
		"knight":
			for u in pool:
				if u.unit_class == Unit.UnitClass.KNIGHT:
					return u.stats.get_value(stat)
			return _best_stat(pool, stat)   # knight away, fall back
		"all_avg":
			var total: int = 0
			for u in pool:
				total += u.stats.get_value(stat)
			return total / pool.size()
		_:
			return _best_stat(pool, stat)


static func _best_stat(pool: Array[Unit], stat: String) -> int:
	var best: int = 0
	for u in pool:
		var v: int = u.stats.get_value(stat)
		if v > best:
			best = v
	return best


# Short human label for the scope, used in the "(X carried the test — N vs T.)"
# chronicle line. Falls back to the stat name when the scope is unknown.
static func _scope_label(scope: String, stat: String) -> String:
	match scope:
		"knight":  return "The Knight's %s" % stat.capitalize()
		"all_avg": return "The household's %s average" % stat.capitalize()
		_:         return "Best %s" % stat.capitalize()


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
		"reputation":
			_apply_reputation_delta(gs, int(effect.get("amount", 0)), result)
		"reputation_range":
			_apply_reputation_delta(gs, RNG.randi_range(int(effect.get("min", 0)), int(effect.get("max", 0))), result)
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
		var body_bump: int = BodyType.cap_bump_for(unit.body_type, stat)
		for _i in range(delta):
			if unit.stats.try_increment(stat, unit.potential_ability, body_bump):
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


# Shift the household's reputation by a signed amount via GameState's
# band-aware helper. When the delta crosses a band boundary the helper
# returns the new band label, which we surface as a one-line chronicle note
# beneath the numeric delta.
static func _apply_reputation_delta(gs: Node, amount: int, result: Dictionary) -> void:
	if amount == 0:
		return
	var crossed: String = gs.adjust_reputation(amount)
	if amount > 0:
		result["notes"].append("+%d Reputation" % amount)
	else:
		result["notes"].append("%d Reputation" % amount)
	if crossed != "":
		if amount > 0:
			result["notes"].append("→ The realm now calls you %s." % crossed)
		else:
			result["notes"].append("→ Your standing slips to %s." % crossed)
