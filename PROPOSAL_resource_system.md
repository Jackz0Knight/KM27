# Resource System — Proposal

**Status:** draft for Jack's review. Nothing shipped. Comment / push back / approve, then we act.

---

## 1. Where it is today (problems, concrete)

### 1.1 Two parallel representations for the same thing

`ResourceBundle` (`scripts/data/resource_bundle.gd`) and `ResourceDB.RESOURCES` + `GameState.inventory` are the same idea expressed twice.

- **ResourceBundle** holds a hardcoded triple — `wood`, `fibres`, `copper_ore`. The internal field names deliberately differ from the canonical inventory keys (`logs`, `plant_fibres`, `copper_ore`). The class header literally warns: *"ALL code that delivers a bundle into inventory MUST call `to_inventory_dict()` — never write `bundle.wood` directly into inventory."*
- **ResourceDB.RESOURCES** is the real model — 32 entries across the T1–T5 tree plus raw materials, keyed by snake_case ID, queried by tier / type / craftability.
- **`GameState.inventory: Dictionary`** is what's actually in the player's stockpile.

So every reward path goes: roll a `ResourceBundle` → call `.to_inventory_dict()` → merge into `gs.inventory`. The translation step is a maintenance liability and the warning in the class header is doing real work right now.

Sites holding the legacy triple, current count:

```
scripts/data/world_generator.gd          1   (castle reward pre-roll)
scripts/data/castle.gd                   1   (Castle.reward storage)
scripts/data/story_event_db.gd           1   (reward_resources effect)
scripts/data/resource_bundle.gd          —   (the class itself)
scripts/systems/combat.gd                4   (4 reward rollers)
scripts/systems/battle_event.gd          2   (harvest + caravan bundles)
scripts/systems/resolution.gd            5   (Combat-event rewards, gold_and_bundle paths)
scripts/systems/crafting.gd              1   (offer.to_inventory_dict for caravan)
```

13 call sites across 8 files. Every new combat / story reward keeps adding to that list.

### 1.2 No tier or category awareness in combat rewards

`Combat.roll_pillage_reward(week)` rolls the same `[lo, hi]` range for *each of the three triple keys*. It does not know the loot is coming from a forest, a mountain, or a goblin cave. Castle pre-rolls (in `world_generator.gd`) do the same. So:

- A castle in mountain country drops the same loot as a castle in the lowlands.
- A bandit ambush, a village raid, and a tavern riot give the same shape of triple, just at slightly different scales.
- Adding "feathers" from a harpy raid, "hides" from a goblin warband, or "strange relics" from a cultist incursion means either extending the triple (which fights its design) or hard-coding a one-off inventory write per resolver (which is what `_apply_combat_event_reward`'s `gold_and_bundle` branch already does — see `resolution.gd:419-430`).

### 1.3 Tile gather is single-resource per terrain

`MapTile.gather_resource()` returns one resource key based on terrain — Forest → `logs`, Mountain → `copper_ore`, etc. The player can't get plant fibres from a forest (which is what the **`plant_fibres`** raw is actually for). The richer T2/T3 raws (`spider_web`, `cow_hide`, `fungal_log`, `hardwood`) have no map source wired even though `RESOURCES[id].map_source` declares one.

The GDD §4 footnote for **Mountain → Copper Ore via adjacency gather** is explicitly deferred — current rule is "gather requires the selected tile to yield its own resource."

### 1.4 Mob drops don't exist as a data model

There's no slot in `CombatEventDB.EVENTS[id]`, in `AwayModeDB`, or in `EnemyDB` for "this enemy drops these T1 raws on a kill." Story events use the `inventory_add` effect primitive to give specific resources, but that's a chronicle-moment pattern, not a combat-loot pattern. The result is that the crafting tab's input pipeline only fills up via pillage / assault — the same channel that drops the legacy triple.

### 1.5 What's NOT broken (worth saying)

- `ResourceDB.RESOURCES` is the right shape. The tree, tiers, recipes, and research gates are clean.
- Story events using `inventory_add` / `inventory_remove` directly on `gs.inventory` are already correct — those don't go through ResourceBundle at all.
- The crafting tab UI is fine; it reads `GameState.inventory` directly.
- The HUD strip + `resource_hud_bbcode` is solid.

So the rot is on the **reward-rolling** side, not the storage / display / consumption side.

---

## 2. Target architecture

### 2.1 One representation: `Dictionary` keyed by ResourceDB id

Delete `ResourceBundle` as a `Resource` class. Replace its role with plain `Dictionary` literals keyed by the same IDs `GameState.inventory` uses. Every reward roller returns a `Dictionary`. Every delivery is one line: `_merge_into_inventory(gs, dict)`.

```gdscript
# Returns {String: int}
static func roll_pillage_reward(week: int) -> Dictionary: ...
```

No more `to_inventory_dict()`. No more dual key namespace.

Helpers that the old class did (subtract, scale, is_empty, describe) move to a small `ResourceDB` namespace:

```gdscript
ResourceDB.merge(target_dict, addition_dict)       # adds in place
ResourceDB.can_afford(inventory, cost_dict) -> bool
ResourceDB.subtract(inventory, cost_dict) -> bool  # false-if-short, atomic
ResourceDB.scale(dict, factor) -> Dictionary
ResourceDB.describe(dict, sorted_by_tier = true) -> String
```

### 2.2 A new `RewardTableDB` for category-aware combat loot

Pure data, mirrors the shape of `CombatEventDB` / `AwayModeDB`. Each entry is a *biased pool* — what kinds of raws are likely to drop, plus a weekly scaling curve.

```gdscript
# scripts/data/reward_table_db.gd
const TABLES: Dictionary = {
    "wilderness_loot": {
        "label": "Wilderness loot",
        # Each entry: (id, weight, lo_at_week_1, hi_at_week_1, lo_at_week_40, hi_at_week_40)
        "rolls": 2,  # how many resource lines we roll into the result
        "pool": [
            {"id": "logs",         "weight": 4, "amount": [1, 3, 3, 6]},
            {"id": "plant_fibres", "weight": 3, "amount": [1, 2, 2, 5]},
            {"id": "cow_hide",     "weight": 1, "amount": [0, 1, 1, 3]},
        ],
    },
    "mountain_loot":    { ... iron_ore-biased ... },
    "castle_loot":      { ... mixed, copper / cloth / iron ... },
    "bandit_pouch":     { ... small, plant_fibres + copper_ore-biased ... },
    "harpy_nest":       { "pool": [{"id": "feathers", ...}, ...], ... },
    "goblin_warband":   { "pool": [{"id": "hides", ...}, ...], ... },
    "cultist_relic":    { "pool": [{"id": "strange_relic", ...}, ...], ... },
}

static func roll(table_id: String, week: int) -> Dictionary
```

Adding a new loot kind is one dict entry. New T1 raws (feathers, hides, relic) get added to `ResourceDB.RESOURCES` as raw materials at the same time.

### 2.3 Combat rollers become table lookups

```gdscript
# Combat.gd (replacing the 4 roll_*_reward functions)
static func roll_pillage_reward(week: int) -> Dictionary:
    return RewardTableDB.roll("wilderness_loot", week)

static func roll_home_win_reward(week: int) -> Dictionary:
    return RewardTableDB.roll("homestead_defence", week)
```

CombatEventDB entries gain a `reward_table` key when their reward is bundle-shaped:

```gdscript
"harpy_raid": {
    ...
    "reward_kind": "table",
    "reward_table": "harpy_nest",
    ...
}
```

The `reward_kind` dispatch in `_apply_combat_event_reward` gains a `"table"` branch alongside the existing four kinds. The legacy `bandit_bundle` / `home_bundle` kinds become wrappers around `RewardTableDB.roll("bandit_pouch", week)` and `RewardTableDB.roll("homestead_defence", week)` — same data, new shape.

### 2.4 Castle pre-roll moves to a region-aware table

`WorldGenerator._roll_castle_reward(...)` currently rolls a `ResourceBundle`. Change to: pick a `reward_table` based on terrain context — castles in mountain terrain pull from `mountain_loot`, castles in forest from `wilderness_loot`, castles on hills from a new `hill_loot` (iron-biased). `Castle.reward` stores a `Dictionary`, not a `ResourceBundle`.

### 2.5 Tile gather: small loot table per terrain

Forest tile gather returns ~2 lines from a small forest table — `logs` dominant, `plant_fibres` secondary, occasional `hardwood` if the tile is "old growth" (a future per-tile flag, or just RNG). Mountain returns one of `{copper_ore, tin_ore, iron_ore, coal}` with weighted picks. Strength still scales total count.

Same `RewardTableDB.roll(terrain_table_id, week)` call. Tile data points at the table id.

### 2.6 Mountain adjacency for ore

Implement the GDD §4 footnote. On the Planning Map's gather launch, if the selected tile has a Mountain neighbour (Chebyshev distance 1), show a second button: **"Gather ore from adjacent mountain"** which launches as a Gather expedition with `target = the selected tile`, `loot_table = mountain_loot`. Mechanically just picks a different table; no new expedition shape needed.

### 2.7 Mob drops on combat-event wins

`CombatEventDB.EVENTS[id]` gains optional `mob_drops` — a small biased pool that rolls **in addition to** the bundle reward. Conceptually "loot from the kill" vs "loot from the cause." Resolution rolls it on win, merges into inventory, surfaces on the Weekly Summary as a separate "Spoils:" line so the player feels the kill matters.

```gdscript
"goblin_warband": {
    ...
    "mob_drops": {
        "table": "goblin_carcasses",  # references RewardTableDB
        "chance": 0.65,               # win-only roll
    },
}
```

### 2.8 Display

Weekly Summary's reward line gets two-level structure when both fire:

```
+12 gold
Reward:  3 logs · 2 plant fibres
Spoils:  4 goblin hides
```

`ResourceDB.describe(dict)` formats either line. Sorted by tier ascending so the eye reads the small stuff first; rare drops at the bottom in their tier colour.

---

## 3. Migration plan — three phases, each leaves the game playable

### Phase A — data-model unification (no behaviour change)

The goal is to delete `ResourceBundle` without changing what the player sees. Every roller still returns the same numerical distribution; the type just changes from `ResourceBundle` to `Dictionary`.

1. Add `ResourceDB.merge / can_afford / subtract / scale / describe / empty()` helpers.
2. Rewrite the 4 `Combat.roll_*_reward` functions to return `Dictionary` instead of `ResourceBundle`. Body of each is the same RNG calls into the same three keys — but the keys are now the canonical `logs / plant_fibres / copper_ore` (no more `wood / fibres`).
3. Same for the 2 `BattleEvent` rollers (harvest, caravan offers).
4. `WorldGenerator._roll_castle_reward(...)` returns `Dictionary`. `Castle.reward: Dictionary`.
5. `StoryEventDB`'s `reward_resources` effect — already builds a temp ResourceBundle (see line 2776); now builds a Dictionary directly.
6. `Resolution._apply_reward` (line 933) becomes a one-liner: merge result["reward"] into gs.inventory.
7. `crafting.gd:22` Caravan path swaps the conversion for direct merge.
8. **Delete `scripts/data/resource_bundle.gd`.**
9. Update `SaveManager` — the `merchant_offers` save key currently round-trips ResourceBundles; switch to round-tripping Dictionaries. Add a one-shot migration on load: if any entry has a `wood` key, rewrite it to `logs`.

After Phase A: zero behaviour change for the player, ResourceBundle is gone, every reward path is one type.

### Phase B — `RewardTableDB` introduction (small behaviour change: more variety)

10. Create `scripts/data/reward_table_db.gd` with the initial five tables: `wilderness_loot`, `mountain_loot`, `hill_loot`, `castle_loot`, `homestead_defence`, `bandit_pouch`.
11. Add 3–6 new T1 raw materials to `ResourceDB.RESOURCES` (e.g. `feathers`, `hide`, `bone_shard`, `strange_relic`) — keyed appropriately, no recipes yet (T1 raw stockpileables only).
12. Re-implement the Combat rollers as `RewardTableDB.roll(table_id, week)` calls.
13. `WorldGenerator` picks the castle's reward table based on the castle's terrain neighbours; castle stores the table id instead of pre-rolled loot. Resolve at win time (so a castle picked up late in the run gets late-week-scaled loot).
14. Tile gather routes through `RewardTableDB` per terrain.

After Phase B: combat loot meaningfully varies by region / context. Recipes don't consume the new raws yet, but they accumulate.

### Phase C — mob drops + Mountain adjacency + content

15. `CombatEventDB.EVENTS` gains `mob_drops`. Resolution rolls them on win, merges into inventory, surfaces on the Weekly Summary.
16. Mountain adjacency gather button on the Planning Map.
17. Add a couple of T2 recipes that consume the new T1 raws (e.g. `quilted_armour` = `plant_fibres × 2 + hide × 1`, `feather_arrow_quiver` = `feathers × 3 + logs × 1`) so the new raws have somewhere to land.
18. Update Weekly Summary's reward line to render Reward + Spoils separately.

After Phase C: the crafting tab actually has input flow. Adding more variety from then on is pure data.

---

## 4. Open design questions — your call

These are the points I want input on before doing the work.

### Q1. Delete `ResourceBundle` outright, or keep as a thin `Dictionary` wrapper?

I'd delete it. Every benefit of having a typed class is offset by the dual-key-namespace it forces, and Dictionary works fine for this. But you've kept it this long, so if there's a reason I'm missing — please flag it.

### Q2. Biased pool or fixed yield for combat loot?

I propose biased pools (table picks N entries from the pool by weight, each rolls an amount range). The alternative is fixed yields per kill ("a goblin always drops 1 hide"). Biased pools give every fight a touch of variety without making every fight stochastic. Fixed yields are more readable but flatter.

### Q3. How many new T1 raws to add in Phase B?

I'd target 4–6. Enough to make combat loot feel distinct, not so many that the inventory HUD's "best per type" model breaks. Specifically: `feathers`, `hide`, `bone_shard`, `strange_relic` (cultist drops, gates a future Sinister T2/T3 recipe).

### Q4. Mob drops on win — separate line or merged with reward?

I proposed separate ("Spoils:" line). The alternative is one merged "Reward" line. Separate is more legible and frames the drop as "you killed the thing." But it's another label the eye has to parse. Your call.

### Q5. Tile gather variety — table-driven or stay deterministic?

Forest tile: should it always yield logs (current) or roll from `{logs: 70%, plant_fibres: 25%, hardwood: 5%}`? The latter is more interesting and is the whole point of the table approach. The former is more predictable for strategic planning. I lean table-driven, but it changes how the player thinks about gather expeditions.

### Q6. Mountain adjacency gather — explicit button or automatic?

Two options:
- **Explicit**: player selects an Ocean / Plains tile next to a Mountain, sees an extra "Gather ore from adjacent mountain" button. Two intentional clicks.
- **Automatic**: when the selected tile has a mountain neighbour, the gather button shows both expected resources, and the expedition yields a mix.

Explicit is clearer. Automatic is less work to set up but the loot becomes less predictable.

### Q7. Migration order — strict A → B → C, or fold A into B?

Strict A → B → C is safer (each phase ships independently, each is reviewable). Folding A into B halves the diff churn but ships a bigger single change. I lean strict — Phase A is a mechanical rename with zero player-visible delta, perfect for shipping in isolation.

### Q8. Anything I haven't named?

You play this game and live in this codebase. If there's a resource-related friction I haven't surfaced — wage upkeep coupling to inventory, item-crafting consuming resources, future research costing them — say so before we draft scope.

---

## 5. Estimated cost

- **Phase A** — half a session. Pure mechanical refactor, every change has an obvious target shape. Risk: `merchant_offers` save round-trip is the only delicate bit; handle with a one-shot migration.
- **Phase B** — one full session. The `RewardTableDB` data needs care to keep current reward distributions close to today's numbers (don't accidentally re-balance the game in a refactor pass — Phase 8 should be the one and only balance pass).
- **Phase C** — half to one session, depending on how many `CombatEventDB` entries get `mob_drops` and how many new recipes we add to absorb the new T1 raws.

Roughly 2–2.5 focused sessions if we commit to the full arc. Each phase is independently mergeable / playable.

---

## 6. What I want from you now

A response to Q1–Q8, plus anything you want to add or push back on under §1, §2, or §3. Then I'll draft a tighter scoped plan for whichever phases you greenlight, and we ship.
