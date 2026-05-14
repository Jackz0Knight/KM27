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
```

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

- **Morale, leave-checks, retention** (whole system → future)
- **Rest task** (was a morale recovery; no longer needed)
- **Squire promotion**
- **Recruitment**
- **Death / injuries / disease / limb system**
- Magic
- Crafting & item modifiers
- Resource tiers T2–T5
- Tile depletion
- Resource placement formulas *(random in MVP)*
- Scoundrel / Engineer classes
- Staff (Scout, Coach)
- Builds (Tall/Short/Average)
- Traits
- Research / Squad Hub buildings
- Custom or larger formations
- Aging / Youth stage
- Economy (gold income/expenses)
- 40-game season structure
- Hidden resource spawns
- Mounted combat
- Expedition encounters during travel
- Expedition recall
- Most stat side-effects beyond what's in §10
- Choosing the starting tile (auto-placed in centre)

All in `FutureFeatures.md`.

---

## Changelog

- 2026-05-14 — MVP GDD imported from external draft (Core Loop, Win/Loss, Map & Tile Knowledge, Weekly Flow, Events, At-Home Tasks, Expeditions, Stats, Formations, Battle Resolution, Resources, UI, Calendar, MVP Exclusions).
- 2026-05-14 — Initial GDD skeleton (superseded by MVP import).
