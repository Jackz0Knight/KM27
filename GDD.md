# Knight Manager — GDD (MVP)

> **Genre:** Survival management with a tournament win condition. Defeat is inevitable; the question is whether you win the Grand Tournament before you fall in a Home Battle.
>
> **Setting:** Fantasy 1627. Procedurally generated map. Player runs a knightly household.
>
> **Scope:** Anything not in this doc lives in `FutureFeatures.md`. Don't add from there until MVP is playable.

---

## 1. Core Loop

```
Start (auto-placed town in centre, choose Knight from 3)
  ↓
[ Week N planning → tick → pre-battle review → battle resolves → Week N+1 ]
  ↓
Continue until: win Grand Tournament (WIN) | lose Home Battle (LOSS)
```

Each week the player plans, time advances, then they get a final review window to react to what happened during the tick before any battle resolves.

---

## 2. Win & Loss Conditions

### Win
- Win **2 tournaments in a row** → invite to **Grand Tournament**.
- Win the Grand Tournament → **game won**.

### Loss
- **Lose a Home Battle** — homestead breached. Immediate game over.

Without morale or recruitment in MVP, the roster does not shrink and there are no other loss paths. The survival pressure is purely **enemy power scaling vs. your training pace**.

---

## 3. Starting Setup

1. Generate world (**15×15 grid**).
2. Player's **town is auto-placed in the centre tile** (position 7,7).
3. Player receives **3 random Squires**.
4. Player picks **1 of 3 random Knights**. Each Knight gets a random name from a fantasy name pool and an independent roll of stats and Potential Ability within the Knight ranges (§10). The three candidates are mechanically equivalent — the choice is between three different stat rolls.
5. Player starts with a **fixed bundle of resources**:
   - **Wood: 5**
   - **Fibres: 5**
   - **Copper Ore: 2**
6. Game begins **Week 1 of 1627 AD**.

Total starting roster: **4 units (1 Knight + 3 Squires)** for the entire game.

---

## 4. Map & Tile Knowledge

The map is **not navigable** by the player. There is no unit movement on the grid — units are either **at home** or **away on an expedition**. The map is a strategic overview of what could be explored, gathered from, or assaulted.

### World Generation Order
1. Place the **town** on the centre tile.
2. The **town tile + all 8 adjacent tiles** are revealed as **Explored** at start (9 tiles total).
3. All other tiles (216 of them) are **Unknown**.
4. After placement, **randomly assign hidden information** to every tile: terrain type, optional resource, optional castle. *(MVP uses pure random distribution — tuning the placement formula is future work.)*

### Tile Knowledge States

| State | What Player Sees |
|---|---|
| **Explored** | Terrain + resource (if any) + castle (if any) + estimated yield. |
| **Unknown** | Nothing. A blank/grey tile. |
| **Expedition Active** | Highlighted; shows party and weeks remaining. |

A tile becomes Explored when an **Explore expedition** completes there.
A tile must be Explored before a **Gather expedition** can target it.

### Tile Types

| Tile | Passable | Gather Resource |
|---|---|---|
| Village / Town / City | Yes | — *(trade hub placeholder)* |
| Plains | Yes | Fibres |
| Forest | Yes | Wood |
| Hills | Yes | — |
| Mountain | No | Copper Ore *(targeted from adjacent tile)* |
| Beach | Yes | Fibres |
| Ocean | No | — |

"Passable" affects whether an expedition can target the tile directly. Mountains are targeted from an adjacent tile (the party works the slopes from a base).

### Castles
- World generation places **8 castles** randomly across the map. Castles cannot appear within 2 tiles of the player's town.
- Each castle gets a **fixed difficulty**, rolled at world gen. Spread the 8 castles across the 30–200 range: e.g. one each near 30, 55, 80, 105, 130, 155, 180, 205 (clamped to 200) with a small ±10 jitter. *(Tune from play.)*
- Each castle gets a **fixed reward bundle** rolled at world gen, scaled to difficulty:
  ```
  for each of Wood, Fibres, Copper Ore:
      amount = round(difficulty / 15) ± small random jitter
  ```
  So a difficulty-30 castle gives ~2 of each, a difficulty-200 castle gives ~13 of each. *(Placeholder — tune from play.)*
- Castles are **visible on the map** once their tile is Explored. Their difficulty and reward are displayed.
- An assaulted-and-won castle is **removed from the map**.
- An assaulted-and-lost castle remains and can be re-attempted.

---

## 5. Weekly Flow

```
┌─ 1. Planning Phase ─────────────────────────────┐
│   • Event preview shown (Home / Away / Event /  │
│     Tournament — see §6)                         │
│   • Player assigns at-home tasks (§7)            │
│   • Player launches expeditions (§8)             │
│   • For Away weeks: player chooses Pillage or    │
│     Assault and which castle (if Assault)        │
│   • Player commits and hits Advance Time         │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─ 2. Tick Phase (automatic) ─────────────────────┐
│   • Training applied                             │
│   • Expedition timers decrement                  │
│   • Returning expeditions deliver resources,     │
│     update tile knowledge, return units to pool  │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─ 3. Pre-Battle Review Phase ────────────────────┐
│   • Roster state shown post-tick                 │
│   • Player can: assign formation slots for       │
│     Home / Away / Battle Event combat,           │
│     reconfirm Away participants, pick units      │
│     for Tournaments. Future systems plug here    │
│     (equip new items, treat injuries).           │
│   • Player hits "To Battle"                      │
└──────────────────┬──────────────────────────────┘
                   ↓
┌─ 4. Resolution Phase (automatic) ───────────────┐
│   • Event/battle resolves                        │
│   • Rewards applied                              │
│   • Weekly summary shown                         │
└─────────────────────────────────────────────────┘
```

**Why the Pre-Battle Review exists:** during Tick, things change — expeditions return mid-week, training results come in. Future systems (crafting, injuries) will produce mid-week changes the player needs to react to. The phase is the seam where they react.

---

## 6. Weekly Events

At the start of the Planning Phase, one of three event types is rolled and shown to the player:

| Event | Probability | Stakes |
|---|---|---|
| **Away Battle** | ~33% | Win = reward (Pillage random / Assault fixed); Lose = no reward |
| **Home Battle** | ~33% | Win = small resource reward; **Lose = GAME OVER** |
| **Battle Event** | ~33% | Variable outcome per template |

**Override:** Every 12 weeks (12, 24, 36, 48…) the rolled event is replaced by a scheduled **Tournament**.

### Away Battle
On an Away Battle week, the player chooses one of two options during planning:

#### Option A: Pillage Nearby Camp
- Generic combat encounter at scaling difficulty.
- Player picks which at-home units to send.
- **Enemy power:** `20 + (week × 3)`.
- **Win:** Random T1 resource bundle. For each of Wood, Fibres, and Copper Ore, roll an integer in `[1 + floor(week/10), 3 + floor(week/5)]`. *(Placeholder formula — tune from play.)*
- **Lose:** No reward.
- Always available — never runs out.

#### Option B: Assault Castle
- Player picks a known castle from the map (must be on an Explored tile).
- Player picks which at-home units to send.
- **Enemy power:** the castle's fixed difficulty (set at world gen, see §4).
- **Win:** The castle's fixed reward bundle (larger than equivalent-difficulty Pillage; rolled at world gen and visible on the castle's info panel). The castle is removed from the map.
- **Lose:** No reward; castle remains and can be re-attempted in a future Away week.

**If no castles are currently known (none on Explored tiles), the Assault option is disabled.** Pillage is the fallback and is always available.

### Reward Delivery
All battle rewards (Pillage, Assault, Home, Bandit Ambush loot, Bountiful Harvest, Merchant Caravan picks, Tournament prizes) are added to the player's resource pool **immediately during the Resolution Phase**, then shown in the Weekly Summary. They are available for the next week's planning.

Units on expedition cannot participate in either Away option.

### Home Battle
The enemy comes to the homestead. **Only at-home units can defend.** Units on expedition are absent.
- All at-home units defend regardless of their assigned task. Units on **Defend** = full power; units on other home tasks = 75% power.
- **Enemy power:** `25 + (week × 4)`.
- **Win:** Small resource reward.
- **Lose:** Game over.

### Battle Event
Smaller encounter. MVP ships with four templates:

- **Bandit Ambush** — small skirmish; at-home units fight (Defend = full, others = 75%). Enemy power: `15 + (week × 2)`. Win = small resource loot. Lose = nothing.
- **Travelling Champion's Duel** — player picks one at-home unit to fight alone. Stat check (Strength + Bravery + Swordsmanship) vs scaling duel target `20 + (week × 2)`. Win = **+1 permanent to a chosen visible stat** of that unit. Lose = nothing.
- **Bountiful Harvest** — no battle. A random T1 resource bundle arrives. *(Replaces the morale-dependent Plague Rumour from earlier drafts.)*
- **Merchant Caravan** — no battle. Player picks from a small bundle of T1 resources.

### Tournament (Every 12 Weeks)
Player picks up to 4 at-home units to send.
- **No formation in Tournaments** — the resolution uses a simpler model (see §13).
- **Enemy power:** `60 + (tournament_number × 25)`.
- **Win:** Tournament victory counter +1. Small resource bundle.
- **Lose:** Counter resets to 0.

### Grand Tournament
Triggered when the player wins 2 tournaments in a row. Replaces the next scheduled tournament slot.
- **Enemy power:** `200 + (year × 50)`.
- **Win:** Game won.
- **Lose:** Counter resets to 0; continue playing.

---

## 7. At-Home Tasks

Each at-home unit must be assigned to one task per week:

| Task | Effect |
|---|---|
| **Train** | Choose target stat. +1 to that stat (capped at 20, capped by remaining Potential Ability). Small Determination-rolled chance of bonus +1 to a random other stat. |
| **Defend** | Stand by. Full effectiveness in any home-resolving combat (Home Battle, Bandit Ambush). |

No Rest task in MVP. Units on **expedition** are not at home and cannot be assigned at-home tasks.

The Train vs. Defend tension is the only at-home decision: train aggressively (riskier if a Home Battle hits) or hold defenders back (slower stat growth).

---

## 8. Expeditions

Expeditions are how units interact with the map. They remove units from the home pool for several weeks.

### Expedition Types

| Type | Duration | Target | Effect on Completion |
|---|---|---|---|
| **Explore** | 2 weeks | Any Unknown tile | Tile's Knowledge state → Explored. Reveals terrain, resource, and castle (if any). |
| **Gather** | 3 weeks | An Explored tile with a resource | Returns a bundle of that tile's resource. Yield scaled by participating units' Strength. |

### Rules
- **Minimum 1 unit, maximum any number** of units may join a single expedition.
- **Multiple expeditions can run in parallel** with separate parties.
- **Cannot be recalled.** Once launched, the expedition runs to completion.
- **Units away on expedition cannot:** defend, fight in Away Battles, train, or participate in tournaments.
- **Returning expeditions** drop their units back into the home pool **during Phase 2 (Tick)** the week they complete. Those units are then available for the Pre-Battle Review and any battle that week.
- **Gather yield formula (MVP baseline, tune from play):**
  ```
  yield = base_tile_yield × (1 + (sum_of_party_strength / 30))
  ```

Expeditions are the only source of new resources. They expose you to home risk.

---

## 9. Units & Classes

### Classes
- **Squire** — base class for the 3 starting Squires.
- **Knight** — the one starting Knight chosen at world gen. Has a small flat bonus to all visible stats.

### No Promotion in MVP
Squires do not promote to Knight in MVP. The starting roster is permanent.

### No Recruitment in MVP
The roster is fixed at the 4 starting units.

### Households & Body Types

Every unit is rolled into one of **four noble houses** and one of **four body types**. Together they give the player an at-a-glance read on a character before reading the stat block.

#### Houses (4)

| House | Archetype | Motto | Visual | Stat Lean (implicit) |
|---|---|---|---|---|
| **Brann** | Warrior | "Steel before words." | Crimson + black; pale; crossed swords | +Strength / +Swordsmanship / +Bravery; −Etiquette / −Technique |
| **Aldermere** | Scholar | "By measure and by mind." | Deep blue + silver; chevron; book | +Etiquette / +Leadership / +Loyalty; −Strength / −Intimidation |
| **Daven** | Scout | "First to the tide." | Sea green + bone; bend; arrow | +Speed / +Archery / +Technique; −Bravery / −Leadership |
| **Faldur** | Cavalier | "Higher than the throne." | Forest green + ochre; saltire; horseshoe | +Horsemanship / +Bravery / +Leadership; −Archery / −Determination |

The lean is **+1 to each preferred stat, −1 to each discouraged stat**, applied after the base roll and before clamping. Net stat budget is roughly preserved — house shifts the curve rather than growing it. **Leans are not displayed to the player** (no chips, no tooltips); the motto and origin paragraph hint at them. Players learn the leans by playing.

#### Body Types (4, rolled independently)

| Body | Silhouette feel |
|---|---|
| **Lean** | Long-limbed and economical of motion. |
| **Burly** | Broad through the shoulder, slow to anger and slower to move. |
| **Tall** | A full head above the other men in the courtyard. |
| **Wiry** | Small-framed but never the first to tire. |

Body type does **not** affect stats. It's a pure visual + flavour signal that stacks with the heraldic crest so the player can read two independent dimensions of a character at a glance. Body type rolls uniformly and independently of house — a Brann (warrior house) knight can still be Lean, which creates outlier characters worth picking.

#### Visual surface

- **Knight Chooser** — large crest (~72×92) + house name + motto + body silhouette appear on every candidate card. The pick feels like recruiting a person, not selecting a stat array.
- **Knight Overview** — full crest (~132×168) anchors the chronicle card; house name, motto, and body type flavour fill the right column.
- **UnitCard (everywhere else)** — compact 44×56 crest + body silhouette + a single muted line `House Name · Body · "Motto"` above the stat grid.

All heraldry is rendered procedurally via `scripts/ui/banner_icon.gd` (custom `_draw()` with `Polygon2D`-style primitives). No PNG assets, scales freely from 32px chips to full hero cards.

---

## 10. Stats

Scale: **1–20** for visible stats.

### Physical
| Stat | Effect |
|---|---|
| **Strength** | Melee combat power; Gather expedition yield. |
| **Speed** | Dodge contribution; reduces enemy hit power. |
| **Technique** | Ranged combat power; crit modifier. |

### Mental
| Stat | Effect |
|---|---|
| **Bravery** | Combat power contribution; resists Home Battle panic penalty. |
| **Loyalty** | Reserved for future morale system. Has no effect in MVP. |
| **Determination** | At the start of every 4th week (weeks 4, 8, 12, 16…), every unit rolls. Chance of success = `(Determination × 0.5)%` (so Det 10 = 5%, Det 20 = 10%). On success: +1 to a randomly chosen non-maxed visible stat. Honors the PA cap. |

### Technical
| Stat | Effect |
|---|---|
| **Swordsmanship** | Combat power; bonus in Yellow (Heavy Melee) or Red (Light Melee) formation slots. |
| **Archery** | Combat power; bonus in Green (Ranged) formation slots. |
| **Horsemanship** | Cosmetic in MVP; reserved for mounted combat. |

### Social
| Stat | Effect |
|---|---|
| **Leadership** | **Battle effect:** when a unit is slotted in Blue (Camp Leader) during a formation battle, every *other* unit in the formation gets +1 to their `unit_power` calculation. The Blue-slotted unit does not get this bonus themselves (they're giving it). **Training effect:** deferred to future — has no effect in MVP. |
| **Etiquette** | When the player wins a Tournament, take the **highest Etiquette** among participating units. Multiply the resource reward by `1 + (highest_Etiquette / 40)` (so Etiquette 20 = +50% rewards, Etiquette 10 = +25%, Etiquette 0 = no bonus). |
| **Intimidation** | For each unit on the field, subtract `Intimidation / 4` (rounded down) from the enemy power total. Applies in all formation battles. Stacks across units. |

### Hidden
| Stat | Effect |
|---|---|
| **Potential Ability (PA)** | Scale 1–200. Hidden from player. Caps the **sum** of a unit's visible stats. When PA total is reached, training yields nothing further. Squires roll PA 60–140. Chosen Knight rolls PA 100–180. |

**Starting visible stat rolls:**
- Squires: 4–10 per stat.
- Chosen Knight: 7–14 per stat.

---

## 11. Morale

**Not in MVP.** Morale, leave-checks, and unit retention are deferred to future. See `FutureFeatures.md`.

Loyalty stat exists for future use; it does nothing in MVP.

---

## 12. Formations (Battles Only)

Formations are used for **Home Battles, Away Battles (Pillage and Assault), and combat-type Battle Events**. **Tournaments do NOT use formations.**

MVP ships with a single 4-slot formation: **4-0-0**.

| Slot | Color | Role | Best Stats |
|---|---|---|---|
| 1 | 🟦 Blue | Camp Leader | Leadership, Bravery |
| 2 | 🟩 Green | Ranged | Archery, Technique |
| 3 | 🟨 Yellow | Heavy Melee | Strength, Swordsmanship |
| 4 | 🟥 Red | Light Melee | Speed, Swordsmanship |

**Slot match bonus:** A unit in their best-fit slot gets **+2** to the relevant combat stat. Mismatched assignments work without the bonus.

The formation editor lives in the Pre-Battle Review Phase. For battles where fewer than 4 units fight (Away with a smaller party, or fewer at-home units in a Home Battle), unused slots are simply empty — no penalty beyond fewer fighters.

**MVP simplification:** No "1 slot away from ideal" rule yet.

---

## 13. Battle Resolution

### Formation Battles (Home, Away-Pillage, Away-Assault, combat Battle Events)
For each unit fighting:
```
unit_power = 5
           + Strength
           + Bravery
           + relevant_skill            # Swordsmanship or Archery, slot-dependent (see below)
           + slot_bonus                # +2 if unit is in their matched slot color
           + leadership_buff           # +1, but ONLY if Blue slot is occupied by ANOTHER unit
           + weapon_damage             # floor(avg(damage_min, damage_max)) — see §18.3
```

**Armour is resistance, not power.** Each defender's armour value subtracts from enemy power before the comparison (sum across the party, mirroring the Intimidation reduction below). Net mathematical effect on the win check is identical to the old "+armour to player_total" model, so balance on the armour axis is preserved — only the weapon axis shifted when this landed. See §18.3 for the full kit integration design.

**Intimidation reduces enemy power separately:** before comparing totals, subtract `sum of (Intimidation / 4, rounded down)` across all participating player units from the enemy power.

**`relevant_skill` rule per slot:**
- Blue slot: use the higher of Swordsmanship and Archery.
- Green slot: use Archery.
- Yellow slot: use Swordsmanship.
- Red slot: use Swordsmanship.
- Units not in any slot (e.g. Home Battle reinforcements on other tasks): use the higher of Swordsmanship and Archery.

**`leadership_buff` clarification:** the unit currently in the Blue slot does NOT get this +1 (they're providing it, not receiving it). Every other participating unit gets +1. If the Blue slot is empty, nobody gets the buff.

**Home Battle special rule:** units on Defend = full power. At-home units on other tasks = 75% power (multiply their final `unit_power` by 0.75, round down). Units on expedition contribute nothing.

### Tournament Resolution (no formation)
For each participating unit:
```
unit_power = 10
           + Strength
           + Technique
           + max(Swordsmanship, Archery)
```

No Leadership buff in tournaments (no formation, no Blue slot). This is intentionally a simpler model than formation battles — tournaments are a pure stat contest, not tactical positioning.

### Enemy Power Scaling

| Event | Enemy Power |
|---|---|
| Pillage | `20 + (week × 3)` |
| Assault Castle | castle's fixed difficulty (30–200) |
| Home Battle | `25 + (week × 4)` |
| Bandit Ambush | `15 + (week × 2)` |
| Travelling Champion's Duel | `20 + (week × 2)` *(single-unit check)* |
| Tournament | `60 + (tournament_number × 25)` |
| Grand Tournament | `200 + (year × 50)` |

Highest total wins. Ties go to the player.

**All enemy power numbers are placeholder — tune from play.** Rough sanity check: 4 starting units with avg stats 7 have ~120 combined power at week 1. By tournament 1 (week 12), training has added maybe 30–50 power; enemy = 85. By the Grand Tournament (earliest week 36) the player needs 250+ to win. If playtesting shows the game is too easy or impossibly hard, adjust the multipliers (e.g. `× 3` → `× 4`) before rebalancing stats.

### Casualties
MVP has no death, no injuries, no morale damage. Losses just mean no reward.

---

## 14. Resources

Only **T1** in MVP. No depletion — tiles can be Gathered indefinitely.

| Material | Family | Gathered From |
|---|---|---|
| Wood | Timber | Forest |
| Fibres | Fabric | Plains, Beach |
| Copper Ore | Metal | Mountain (from adjacent tile) |

Resources accumulate. **Crafting is deferred to future.** MVP uses resources in three small ways:
- Battle rewards (visible measure of progress).
- Etiquette stat slightly modifies Tournament resource rewards.
- *(Future: crafting consumes them.)*

---

## 15. Required UI / Screens

Text-based or simple 2D both fine. Required:

1. **Title / Start** — generate world, choose Knight.
2. **World Map** — 15×15 grid showing terrain, knowledge state per tile, town, castles, active expeditions with weeks remaining.
3. **Roster View** — all units (home and on expedition), class, visible stats, current task / expedition status.
4. **Planning Phase Screen** — assign at-home tasks; launch expeditions; on Away weeks choose Pillage or Assault and pick castle if Assault.
5. **Event Preview Banner** — what's happening this week.
6. **Pre-Battle Review Screen** — formation editor for combat events; participant confirmation; "To Battle" button.
7. **Battle / Event Log** — what happened, per-unit contribution, final result.
8. **Weekly Summary** — stat changes, returned expeditions, rewards; "Next Week" button.
9. **Game Over / Win Screen** — cause, week reached, tournaments won, castles taken, summary.

No animations, no sound, no art beyond tile icons and stat bars.

---

## 16. Calendar

- 1 year = 48 weeks (4-week months × 12 months).
- Tournament weeks: 12, 24, 36, 48, 60…
- Grand Tournament fires on the next scheduled tournament slot **after** the player wins two in a row.

---

## 17. What MVP Deliberately Excludes

> Some items below have since shipped or moved into a post-MVP design pass — see §18 (item & crafting design pass) and the Changelog. The list is kept here as the original MVP boundary.

- **Morale, leave-checks, retention** (whole system → future)
- **Rest task** (was a morale recovery; no longer needed)
- **Squire promotion**
- **Recruitment**
- **Death / injuries / disease / limb system**
- Magic
- Tile depletion
- Resource placement formulas *(random in MVP)*
- Scoundrel / Engineer classes
- Staff (Scout, Coach)
- Builds (Tall/Short/Average)
- Custom or larger formations
- Aging / Youth stage
- 40-game season structure
- Hidden resource spawns
- Mounted combat
- Expedition encounters during travel
- Expedition recall
- Most stat side-effects beyond what's in §10
- Choosing the starting tile (auto-placed in centre)

All in `FutureFeatures.md`.

---

## 18. Item & Crafting Systems — Design Pass

This section is the **design pass** before implementation. It locks the conceptual model across **Resources & Economy**, **Damage ↔ Stat integration**, **Crafting & Research**, and **Item Modifiers & Quality Brackets**. Open questions are flagged inline with `> **Open Q…**` blocks — Jack answers; once locked, the spec migrates into §13 / §14 and implementation follows bottom-up.

### 18.1 Layering

These four layers are intentionally bottom-up dependent — each pins the constraints for the next:

1. **Resources & Economy** — what materials exist, how they're gathered, how gold flows. Sets the inputs.
2. **Damage ↔ Stat integration** — how weapons and armours fold into the §13 power formula. Sets what modifiers *mean*.
3. **Crafting & Research** — how materials become items, and what gates unlock what. Sets scarcity.
4. **Item Modifiers & Quality Brackets** — the 7-bracket quality system, with material-driven roll ranges. The flavour layer on top.

Designing modifiers before the damage model is set means re-tuning twice.

### 18.2 Resources & Economy

**Resource catalogue** lives in `ResourceDB.RESOURCES` — currently 18 processed + 14 raw across three families (Fabric, Timber, Metal) and tiers T1–T5. Each entry carries `name`, `type`, `tier`, an optional `recipe` (resource-to-resource processing — *not* item crafting; see §18.4), and an optional `research` gate.

**Resource sources.** Today raw materials come mostly from castle assault loot — gather expeditions exist but the raw-material drop pipeline is incomplete. The design pass commits to **three** named channels:

- **Gather expeditions** are the primary **T1 raw** source. Yield = `base × Strength × tile_richness × weeks`, where:
  - `tile_richness ∈ {Poor, Average, Rich}` — set at world-gen per tile, biased by terrain (Forest leans Timber, Mountain leans Metal, Plains/Beach lean Fabric).
  - Tile yield-rate is **T1 only**; higher tiers do not drop from Gather.
- **Castle assault loot** is the primary **T2–T3** source — rich but rare bags, weighted to the assaulted castle's difficulty band.
- **Story-event rewards** are the trickle for **T3+** specialty mats (e.g. an "old armoury" event delivers a Steel Ingot, an "abandoned forge" delivers Mythril traces). Curated, not RNG-spammed.

Mob drops were originally scoped out of this pass. **Correction (2026-06-03):** the resource-system overhaul shipped enemy mob drops ahead of this design pass — `EnemyDB` entries carry a `drops` array and `Resolution._roll_spoils_from_enemies` aggregates kill-spoils on a win, surfaced as a separate "Spoils:" line. So mob drops are now a **fourth live channel** (kill loot, distinct from the encounter reward). Treat the three named channels above as the *bulk/tunable* sources and mob drops as the *variety/flavour* trickle. The Phase-8 scarcity-band tuning should account for all four.

**Scarcity bands** — every resource gets a *design-target* weekly supply estimate based on its source channel. Used as a balance yardstick, not a runtime mechanic:

| Band | Per week (target) | Examples |
|---|---|---|
| Plentiful | 4–8 | Logs, Plant Fibres, Copper Ore |
| Common | 1–3 | Cloth, Tin |
| Uncommon | 0–1 | Bronze Ingot, Leather |
| Rare | every few weeks | Iron Ingot, Spidersilk |
| Epic | once per run | Mythril, Wyrm Hide |
| Legendary | Grand-Tournament tier | T5 mats |

**Gold** flows on these named edges. Each beat is visible — fixed formulas, no abstract "income/expense" buckets. Numbers are *proposed* targets; current ones in parens:

| Source | Proposed formula | Current |
|---|---|---|
| Weekly stipend | `8 + (year × 2)` | flat 10 |
| Holdings income | `castles_held × 6` per week | not wired |
| Tournament purse | `40 + (tournament_number × 25) + rep_bonus` | shipped (rep cap +25) |
| Pillage purse | `8–18 × bandit_strength` | shipped (rough) |
| Assault loot | `40 + castle_difficulty × 0.4` | shipped (rough) |
| Story events | per-event ranges | shipped |

| Sink | Proposed formula | Current |
|---|---|---|
| Weekly upkeep | `4 + (knights × 3) + (squires × 2)` | flat `roster.size() × 5` (= 20/week at 4 units) |
| Research project | `proj.cost_gold` (paid up front) | shipped |
| Crafting cost | `recipe.base_gold` + material values | not wired (resource recipes use mats only today) |

> **Open Q (resources):**
> 1. Lock the **gather formula** (Strength × tile_richness × weeks) as the canonical T1 source? Or do you want **mob drops** as a parallel channel later?
> 2. Promote the **scarcity bands** to a `band` field on each `ResourceDB.RESOURCES` entry so balance work has a yardstick in code, not just docs?
> 3. **Holdings income** — keep it flat (boring but predictable), or scale with castles held (rewards expansion, makes losing a castle bite)?
> 4. **Upkeep formula** — flat-per-unit (current), or differentiate by class (Knight costs more than Squire)?

### 18.3 Damage ↔ Stat Integration

Today, §13's `unit_power` formula does **not** include weapon damage — weapons add a flat `power_rating` (0–5) separate from the stat math. That's two parallel axes, so modifiers like "+2 Strength" and "+1 power_rating" don't compose cleanly, and the weapon card's `damage 5–9` line has no strategy-layer meaning.

The design pass folds weapon damage and armour resistance **into** the §13 formula:

```
unit_power = 5                                  # base
           + Strength                           # body
           + Bravery                            # mind
           + relevant_skill                     # Swd or Arc per slot
           + slot_bonus                         # +2 matched slot
           + leadership_buff                    # +1 if Blue occupied
           + weapon_damage                      # NEW — replaces power_rating
                                                #   weapon_damage = floor(avg(damage_min, damage_max))
                                                #   modifiers shift damage_min/max in the catalogue,
                                                #   the formula re-derives. One source of truth.
```

Enemy power is reduced by armour, paired with Intimidation:

```
enemy_power -= sum(Intimidation / 4)            # existing, GDD §13
            -= sum(armour_resistance)           # NEW — armour absorbs
```

**Note (implementation correction).** The original design pass wrote `armour_resistance / 4` to mirror Intimidation's scale. But Armour's `power_rating` is already 0–4, so `/4` floors to zero on most kit. Direct subtraction (no `/4`) is mathematically equivalent to the old `+armour` on player_total, so the change preserves balance on the armour axis with zero rebalancing required. When dedicated `armour_resistance` modifier rolls land in §18.5, the field can grow without re-deriving this scale.

Result: a `5–9 damage` weapon means avg 7 contribution to `unit_power`; a +2 quality modifier on `damage_max` bumps the formula by +1 (avg shift). Armour at `power_rating 3` shaves 3 off enemy power per defender.

> **Open Q (damage):**
> 1. **`weapon_damage = avg(min,max)`** is the simplest derivation. Want to add **stat scaling** (e.g. `+ Strength × 0.25` for melee, `+ Technique × 0.25` for ranged)? More growth feel, more tuning surface.
> 2. Should **Swordsmanship / Archery** keep contributing as flat stats in `unit_power` (current §13), or only via weapon `hit_bonus`/`crit_bonus`? I'd lean **keep both** — the stat is the *skill*, the weapon is the *tool*.
> 3. **Deprecate `power_rating`?** Cleanest is yes — fold it into derived `weapon_damage`. Alternative: keep it as a `+0` legacy field for old saves.

### 18.4 Crafting & Research

**Today.** `ResourceDB.RECIPES` (embedded in each `RESOURCES` entry) describes **resource-to-resource processing** (Cloth ← Plant Fibres ×2), not item crafting. Items today only enter the stockpile via loot drops. The design pass introduces a **separate `ITEM_RECIPES` catalogue** that consumes resources and gold and produces a crafted item:

```
"iron_longsword": {
    "output_item":   "iron_longsword",    # id in Weapon.CATALOGUE
    "inputs":        {"iron_ingot": 3, "hardwood_planks": 2},
    "base_gold":     12,
    "bracket_bias":  3,                   # centre of the quality roll (Good)
    "research_gate": "blacksmithing",
}
```

- **Bracket bias** = the centre of the quality roll (§18.5). Derived from the highest-tier input by default (T1 → Ok, T3 → Good, T5 → Excellent), overridable per recipe for hand-tuned showpieces.
- **Craft action** is **instant** at the Planning Crafting tab — one click consumes the inputs, rolls a quality bracket, and adds a crafted item instance to the stockpile. Matches the manager pacing (no in-week production timer).
- **One craft per recipe per Planning week** — cap. Stops the player from chain-crafting away their week. Multiple *different* recipes can craft in the same week.

**Research** gates which item recipes appear. Tech tree already exists in `ResourceDB.RESEARCH_PROJECTS`. The design pass extends it minimally:

- A project's `cost_gold` is paid up front (already shipped).
- A project **completes instantly** — no weeks-long timer. Rationale: research is *a decision* (which branch?), not *a wait*. Pacing comes from gold scarcity and recipe gates downstream.
- A project unlocks one or more item recipes (and may unlock higher-tier resource recipes too — same gate field).

**Item scarcity** is bounded by:
- Recipe **research gates** (which exist).
- Material **cost** (T3 recipes need T2 ingots, which need T1 ore — multi-step pipeline).
- Quality **bracket roll** (Masterwork+ are tail events; see §18.5 weights).

> **Open Q (crafting):**
> 1. **One craft per recipe per week** — or unlimited per week (only material-gated)? Affects scarcity sharply.
> 2. **Research = instant on payment** — or does it take N weeks? Instant keeps decision/cost clean; timed adds opportunity cost.
> 3. Show **material lineage** on the crafted item's tooltip ("Iron Longsword — forged from Iron Ingot ×3, Hardwood Planks ×2")? Show-not-tell of why the modifiers rolled where they did.
> 4. **Resource recipes vs item recipes** — keep them as two distinct dicts (proposed: `RESOURCES[id].recipe` for processing, `ITEM_RECIPES[id]` for items), or unify under a single recipe table with a `kind` field?

### 18.5 Item Modifiers & Quality Brackets

A crafted item rolls a **quality bracket** at craft time — a single roll on this 7-step scale (low → high):

| Bracket | Label | Effect on modifier ranges | Roll weight (centred on Ok) |
|---|---|---|---|
| 0 | Terrible | `-30%` of base mod values | tail |
| 1 | Poor | `-15%` | common |
| 2 | Ok | `±0%` | common |
| 3 | Good | `+15%` | common |
| 4 | Excellent | `+30%` | uncommon |
| 5 | Masterwork | `+50%`, +1 rolled modifier slot | rare |
| 6 | Legendary | `+75%`, +2 rolled modifier slots, named | tail |

**Bracket roll** is biased by the recipe:
- **Centre** = `recipe.bracket_bias` (default = highest-input-tier mapping).
- **Spread** = ±2 brackets via weighted RNG (peak at centre, dropping off).
- **"The forge sang" crit** = 2% chance to bump the rolled bracket up one step — flavour for the rare big day.

**Modifiers** are integer/percentage offsets layered on the catalogue baseline. Each item type has **1–3 primary** modifier slots (rolled within ranges) and an **optional bonus** slot unlocked at Excellent+.

**Weapon primary modifiers** (range *at Ok bracket* — other brackets scale by the % above):

| Modifier | Range at Ok | Note |
|---|---|---|
| `+damage_max` | +0 to +2 | Top-end power; rolls into the `unit_power` formula via §18.3. |
| `+hit_bonus` | -1 to +3 | Accuracy in the combat sim layer. |
| `+crit_bonus` | +0.00 to +0.04 | Crit chance. |

**Armour primary modifiers**:

| Modifier | Range at Ok | Note |
|---|---|---|
| `+armour_resistance` | +0 to +2 | Subtracted from enemy power via §18.3. |
| `+dmg_absorb` | +0 to +2 | Combat-sim layer per-hit absorb. |

**Material-driven bias** — the **highest-tier material** in the recipe biases *which* primary modifier rolls high. The bias is `+1 to the rolled value` within the modifier's range, not a flat replacement — so material matters but the bracket dominates the headline number:

| Material (highest tier) | Bias toward | Flavour |
|---|---|---|
| Hardwood Planks (T2) | `+hit_bonus` | lighter, balanced |
| Iron Ingot (T2) | `+damage_max` | heavy, hits hard |
| Steel Ingot (T3) | `+damage_max` and `+armour_resistance` | best of both |
| Mythril Ingot (T3) | `+crit_bonus` | ethereal edge |
| Wyrm Hide (T3) | `+armour_resistance` | drake scales |
| Shadow Weave (T3) | `+hit_bonus` and `+crit_bonus` | hard to see coming |

**Quality vs. Rarity — independent axes.** This is the headline of the system:

- **Rarity** (Common / Uncommon / Rare / Heirloom) → *where the item came from* (loot pool). Already shipped on weapons + armours.
- **Quality bracket** (Terrible … Legendary) → *how well it was crafted*. New.

A Common Iron Longsword can roll **Legendary** quality and outclass a Rare loot drop. A Heirloom loot drop comes in at a fixed quality (proposal: Heirloom drops = Excellent; Grand-Tournament Heirlooms = Masterwork; hand-authored uniques can specify).

**Surface** — bracket label + colour on every item line, plus a small **▲** marker above Ok and **▼** below (same show-not-tell motif as the stat arrows in §10):

```
⚔ Iron Longsword · Excellent ▲▲     # green tint
⚔ Iron Longsword · Ok               # no marker
⚔ Iron Longsword · Poor ▼           # orange tint
```

The exact numeric modifiers stay visible on the tooltip — bracket on the chip, numbers on hover.

> **Open Q (modifiers):**
> 1. **7 brackets** as listed, or fold Terrible/Legendary into Poor/Masterwork (**5 brackets** — tamer tails, simpler curve)?
> 2. Material bias as **+1 to the rolled value** (subtle), or **shift the centre of the modifier range** (loud)?
> 3. Brackets **visible on the card** (label + ▲/▼) as proposed, or **hidden behind a descriptor only** (just the word, like stats)?
> 4. **Legendary names** — auto-generated from a pool (`Wyrmsbane`, `The Tournament's Edge`), or only for hand-authored Heirlooms?
> 5. Should the **"forge sang" crit** be visible on the Weekly Summary as a small chronicle line ("The forge sang at midnight — Aldric drew Wyrmsbane from the embers")? Big show-not-tell moment if so.

### 18.6 Implementation order (once design locks)

Each item is its own commit / PR. Bottom-up by intent — every layer pins the next layer's tuning surface:

**Status (2026-06-03):** steps 1, 2, 3, 5 shipped; step 4 partial. Open Qs were adopted at their proposal defaults (one-craft-per-week cap; instant research; 7 brackets; bracket visible on the card; material bias deferred to the modifier-roll pass). See the ROADMAP Progress Log for per-step detail.

1. **Resources & economy pass** — ✅ `Economy` tuning surface (gold formulas as named constants), scarcity bands as a derived `ResourceDB.scarcity_band` helper. (Channels were already wired in the 2026-05-28 overhaul.)
2. **Damage formula** — ✅ `weapon_damage` / `armour_resistance` folded into `Combat.unit_power` (2026-06-02).
3. **Crafting pipeline** — ✅ `ItemRecipeDB` + `Crafting.craft_item`; Crafting tab "Smithing" section; the forge rolls a quality bracket and stamps it on the new instance.
4. **Item modifiers** — ⏳ *partial.* Per-instance `bracket` + `mods` now live on item instances (stockpile entries + equipped `Unit` fields), persist in saves, and the bracket scales weapon damage / armour in both combat layers via `Quality`. The **rolled modifier tables** (§18.5 primary mods + material bias) are not generated yet — `mods` is reserved and lightly applied. *Next.*
5. **Quality brackets surface** — ✅ bracket label + ▲/▼ marker on the UnitCard equipment line, Knight Overview's Equipment block, the equip popup, and the forge result (incl. the "forge sang" moment). `Quality.color` exists for a future colour-tint pass.

---

## Changelog

- 2026-06-03 — §18 implementation kickoff: shipped §18.6 steps 1 (economy tuning surface + scarcity bands), 3 (item crafting via `ItemRecipeDB`/`Crafting.craft_item`), and 5 (quality surface), plus the bracket half of step 4 (per-instance `Quality` brackets scaling combat in both layers; rolled modifier tables still pending). Adopted the Open Qs at proposal defaults (one-craft-per-week, instant research, 7 brackets, brackets visible on the card). Updated §18.6 with a status block.
- 2026-06-03 — §18.2 correction: mob drops, originally scoped out of the §18 pass, had already shipped in the 2026-05-28 resource overhaul; reframed them as a fourth live loot channel (kill-spoils) so the design doc matches the code. No other design change.
- 2026-05-27 — Added §18 *Item & Crafting Systems — Design Pass* covering Resources & Economy, Damage ↔ Stat integration, Crafting & Research, and Item Modifiers & Quality Brackets (7-bracket Terrible→Legendary scale, material-driven bias, quality as a separate axis from rarity). Each subsection ships with `> **Open Q…**` blocks for Jack to resolve before the spec migrates into §13/§14 and implementation begins. Also pruned §17 *Excludes* of items now shipped (resource T2–T5, traits, research, economy) or moved to §18 (crafting & item modifiers); kept the original list framed as the MVP boundary for posterity.

- 2026-05-17 — Added §9 *Households & Body Types* (4 archetypal houses with implicit stat leans + 4 independent body silhouettes). Drives the visual banner system; not in original MVP scope but additive — doesn't change any existing rule, just biases starting stat rolls.
- 2026-05-14 — MVP GDD imported from external draft (Core Loop, Win/Loss, Map & Tile Knowledge, Weekly Flow, Events, At-Home Tasks, Expeditions, Stats, Formations, Battle Resolution, Resources, UI, Calendar, MVP Exclusions).
- 2026-05-14 — Initial GDD skeleton (superseded by MVP import).
