# KM27 — Implementation Roadmap

The single source of truth for *what's built, what's in flight, and what's queued*.

## How to use this file

- **Phases** are vertical slices. Each one ends in something that runs and can be playtested.
- **Tick the `- [ ]` boxes** as deliverables land. Don't skip phases; each builds on the previous.
- **Update the Progress Log** at the bottom every session that ships code — newest entry first, ISO date prefix.
- **GDD refs** point to sections of `GDD.md`. If a phase contradicts the GDD, the GDD wins — update the GDD first, then the roadmap.
- **Tuning numbers** (enemy power, yields, etc.) are placeholders per the GDD. Don't re-balance until Phase 8 unless something is unplayable.

---

## Phase 0 — Godot scaffold

**Goal:** A Godot 4 project that opens, runs `Main.tscn`, and proves the autoloads are wired.

**Deliverables**
- [x] `project.godot` with name, main scene, autoloads, 1280×720 viewport, GL Compatibility renderer.
- [x] `icon.svg` placeholder ("KM" mark).
- [x] `scenes/Main.tscn` — minimal Control scene with a centred "booting…" label.
- [x] `scripts/main.gd` — prints week/year + starting resources on `_ready()`.
- [x] `scripts/autoload/game_state.gd` — stub with week, year, phase, resources, roster, world, tournament_streak.
- [x] `scripts/autoload/event_bus.gd` — empty signal hub with planned-signal comments.
- [x] `scripts/autoload/rng.gd` — seedable `RandomNumberGenerator` wrapper.
- [x] Folder layout (`scenes/`, `scripts/`, `scripts/autoload/`, `assets/textures/`, `assets/audio/`, `data/`).

**Done when:** opening `project.godot` in Godot 4.3+ loads without errors and the main scene prints `[KM27] Main scene ready. Year 1627, Week 1.` followed by the resource dictionary.

---

## Phase 1 — Data layer & World generation *(GDD §3, §4)*

**Goal:** Generate a deterministic 15×15 world that matches GDD §4 exactly, with no UI yet.

**Deliverables**
- [x] `Unit` class (`scripts/data/unit.gd`) — id, name, class (Squire/Knight), visible stats, hidden PA, current task/expedition state.
- [x] `Stats` resource — Strength, Speed, Technique, Bravery, Loyalty, Determination, Swordsmanship, Archery, Horsemanship, Leadership, Etiquette, Intimidation. Helpers for sum, clamp-on-set, PA-aware increment.
- [x] `ResourceBundle` helper — add/subtract dictionaries for wood/fibres/copper_ore.
- [x] `MapTile` class — coords, terrain, knowledge state, optional castle ref; resource type is derived from terrain.
- [x] `Castle` class — coords, difficulty (30–200 spread with ±10 jitter), pre-rolled reward bundle.
- [x] `World` class — 15×15 grid, town at (7,7), 9 starting Explored tiles, 8 castles placed with the "no castle within 2 tiles of town" rule (Chebyshev ≥ 3).
- [x] `WorldGenerator.generate(seed: int) -> World` static helper using `RNG.seed_run()`.
- [x] Debug scene `scenes/dev/world_dump.tscn` that prints the grid + castle list to the output panel and runs a battery of validation checks + a determinism re-roll.

**Done when:** running the debug scene with the same seed twice produces an identical world, castle difficulties span 30–200, and no castle sits within 2 tiles of (7,7).

**Notes**
- `Tile` was renamed `MapTile` to dodge any future clash with Godot built-ins.
- Terrain is uniformly random across 7 wilderness types (Village/Plains/Forest/Hills/Mountain/Beach/Ocean); per GDD §4 "MVP uses pure random distribution — tuning the placement formula is future work."
- Run the dev scene in Godot with **F6** while `scenes/dev/world_dump.tscn` is open.

---

## Phase 2 — Game state & weekly clock *(GDD §5, §6, §16)*

**Goal:** A headless week-advancer that loops Plan → Tick → Pre-Battle Review → Resolution and rolls events correctly.

**Deliverables**
- [x] `GameState` populated with `world`, `roster: Array[Unit]`, `resources: ResourceBundle`, `tournament_streak`, `current_event`, plus `current_year()` / `current_week_of_year()` / `is_tournament_week()` helpers and `start_run(seed)` / `advance_to_next_week()` / `roll_current_event()` lifecycle methods.
- [x] `PhaseMachine` (held on GameState, not a separate autoload) with explicit `Phase` enum, `transition()` / `advance()` and a `phase_changed` signal routed through EventBus.
- [x] `EventRoller` — uniform pick across Away / Home / Battle Event on normal weeks; Tournament on week-12N; Grand Tournament substitution when `tournament_streak >= 2`.
- [x] `Calendar` helpers (`year_for`, `week_of_year`, `is_tournament_week`, `tournament_number`).
- [x] `EventKind` constants + label helper.
- [x] Headless test scene `scenes/dev/event_roll_test.tscn` (F6) — runs 50 weeks with a pinned seed, simulates winning every tournament, tallies, and validates the override + Grand-substitution rules.

**Done when:** 50-week dry run produces ~33% each event type outside tournament weeks, a Tournament on every week-12N, and a Grand Tournament after winning 2 in a row.

**Notes**
- `EventBus` now declares the full set of signals we'll need across phases 2–7 (commented at the top of `event_bus.gd`).
- `GameState.roll_current_event()` is the single entry point for Planning to ask "what's happening this week?" — it stores on `current_event` and emits `event_rolled`.

---

## Phase 3 — Starting flow & Roster UI *(GDD §3, §9, §10)*

**Goal:** Player can start a run, pick a Knight, and see their 4-unit roster with correct stat ranges.

**Deliverables**
- [x] Title screen (`scenes/Main.tscn`) — randomised seed display + "Begin a New Run" button that hands off to the Knight chooser.
- [x] `scenes/screens/knight_chooser.tscn` — 3 randomly-rolled Knight candidates (stats 7–14 + flat +1, PA 100–180); each card has its own "Take into service" button.
- [x] Squire stat roller (4–10, PA 60–140, no bonus) inside `RosterGenerator.build_starting_roster()`.
- [x] `scenes/screens/roster_view.tscn` — 4 unit cards with visible stats, status line, and stat-total readout. PA hidden everywhere.
- [x] `scripts/systems/determination.gd` — `should_trigger(week)` + `roll_for_units(units)` honouring the PA cap and skipping expedition units. (Phase 5's Tick wires the call.)
- [x] Shared `UnitCard.build(unit, on_choose?, label?)` builder so the same card renders identically across chooser / roster / later screens.
- [x] `NamePool.random_name()` (32 first names × 25 surnames) for procedural Knight/Squire names.

**Done when:** new run produces 1 Knight + 3 Squires inside the documented stat ranges, the chosen Knight has the class bonus, and the roster view renders correctly.

**Notes**
- "Small flat bonus" for the Knight class (GDD §9) was implemented as `+1` to every visible stat, clamped at 20. Tunable via `RosterGenerator.KNIGHT_FLAT_BONUS`.
- The title screen seeds the run via `randi()`. World gen, Knight rolls, and Squire rolls all consume the same seeded `RNG` autoload so the whole starting roster is reproducible for a given seed.

---

## Phase 4 — Planning UI (at-home tasks + expeditions + map) *(GDD §4, §7, §8, §15)*

**Goal:** Player can plan a week — assign at-home tasks, launch expeditions, and on Away weeks choose Pillage or Assault.

**Deliverables**
- [x] `Expedition` data class (`scripts/data/expedition.gd`) + `active_expedition` field on `MapTile`.
- [x] `WorldMapView` (`scripts/ui/world_map_view.gd`) — reusable GridContainer-based 15×15 map. Tile colour by terrain, Unknown tiles greyed, castles overlaid in red, town in gold, active expeditions show "Xw" remaining; emits `tile_clicked(x,y)`.
- [x] `scenes/screens/planning.tscn` — event banner, resources line, per-unit Defend/Train picker (with current value shown), checkbox to add a unit to the next expedition party, clickable map + selected-tile info, separate Explore/Gather launch buttons with full validation, active-expedition list.
- [x] Away-week sub-section (visible only when current event = Away Battle): Pillage / Assault Castle buttons, castle dropdown filtered to Explored-tile castles only.
- [x] `GameState.launch_expedition()` + `complete_expedition()` (Phase 5 uses the latter) + away-week pending fields (`pending_away_party`, `pending_away_mode`, `pending_assault_castle`).
- [x] Advance Time button — commits each at-home unit's task, walks the phase machine through Tick → Pre-Battle → Resolution (stubs for now), advances the week counter, rolls the next event, and re-renders. Phases 5–7 will replace the stubs.
- [x] Roster-view Continue button wired to Planning.

**Done when:** player can place all 4 units onto tasks/expeditions, validation prevents impossible plans (e.g. assigning a unit on expedition), and clicking Advance Time hands off to the Tick phase.

**Notes / known limitations**
- Mountain → Copper Ore via adjacent-tile gather (GDD §4 footnote) is **deferred**. Gather currently requires the *selected* tile to yield its own resource. MVP copper comes from castle assaults and pillage instead.
- The Advance Time button currently walks all four phases in one click because Phases 5–7 are not yet wired. Once Phase 5 lands, Tick will pause for the Pre-Battle Review screen instead of running through.

---

## Phase 5 — Tick & Pre-Battle Review *(GDD §5, §8, §12)*

**Goal:** Plan commit → world state actually changes → player gets a review window before the battle.

**Deliverables**
- [x] Training resolver — `+1` to target stat (capped 20, capped by remaining PA); small Det-rolled bonus +1 chance to another stat.
- [x] Expedition timer tick — decrement, on hit-zero deliver yield (`base_tile_yield × (1 + Σstrength/30)`), reveal Explored tile + castle if any, return units to home pool.
- [x] `scenes/screens/pre_battle_review.tscn` — post-Tick roster snapshot.
- [x] Formation editor — 4-0-0 slot picker (Blue / Green / Yellow / Red), per-slot OptionButton picker with slot-match `[match]` marker, live forecast.
- [x] "To Battle" button → hands off to Phase 6's resolver.

**Done when:** training and expedition returns mutate `GameState` correctly during Tick, the review screen shows the post-Tick state, and the formation editor records assignments. ✓

**Notes**
- Implemented as OptionButton-per-slot (with single-unit-per-slot enforcement on pick), not drag-and-drop. Same outcome with less UI plumbing.
- The Pre-Battle Review's setup pane is event-aware: formation editor for Away / Home / Bandit Ambush, champion + target-stat picker for Champion's Duel, up-to-4 participant checkboxes for Tournaments, a note for Bountiful Harvest / Merchant Caravan.

---

## Phase 6 — Combat resolution + events *(GDD §6, §13)*

**Goal:** Every event type can resolve end-to-end and produce a Weekly Summary.

**Deliverables**
- [x] Formation-battle math — `unit_power = 5 + Str + Bra + skill + slot_bonus + leadership_buff`, intimidation reduction of enemy total, Defend=full / other-home-tasks=×0.75, expedition units absent.
- [x] Pillage (`20 + week×3`), Home (`25 + week×4`), Assault (castle's fixed difficulty); won-castle removal from the world.
- [x] Battle Event templates: Bandit Ambush, Travelling Champion's Duel (single-unit `Str + Bra + Sword` vs `20 + week×2`, +1 to a chosen stat on win), Bountiful Harvest, Merchant Caravan.
- [x] `scenes/screens/battle_log.tscn` — per-unit contribution + final totals.
- [x] `scenes/screens/weekly_summary.tscn` — stat deltas, returned expeditions, rewards, "Next Week" button.
- [x] `scenes/screens/game_over.tscn` — triggered by Home Battle loss with cause + run stats.

**Done when:** any rolled event can play out from Planning through Weekly Summary, rewards land in `GameState.resources`, and a Home Battle loss ends the run. ✓

**Notes**
- Resolution is split: `scripts/systems/combat.gd` (pure formulas + enemy-power constants), `scripts/systems/battle_event.gd` (sub-type roll, harvest/caravan/duel), `scripts/systems/resolution.gd` (orchestrator + reward delivery). Combat doesn't touch GameState — it takes participants in, gives a breakdown out. Resolution is the only mutator.
- Slot-match is binary per GDD §12's "MVP simplification: no 1-slot-away rule"; rules live in `Combat.is_slot_match` and are tunable in one place.
- Merchant Caravan picker fires on the Weekly Summary (3 randomised bundles); Next Week is disabled until the player commits.

---

## Phase 7 — Tournaments & endgame *(GDD §6, §13, §16)*

**Goal:** The win condition exists and can be reached.

**Deliverables**
- [x] Tournament override at week 12N (already routed by Phase 2; finalise UI).
- [x] Tournament resolution — `unit_power = 10 + Str + Tec + max(Sword, Arch)`, enemy `60 + tournament_number × 25`, up to 4 participants, no formation editor.
- [x] Etiquette reward modifier — `reward × (1 + highest_Etiquette/40)` on Tournament wins.
- [x] `tournament_streak` increments on win / resets on loss.
- [x] Grand Tournament substitution after 2 consecutive wins (enemy `200 + year × 50`).
- [x] `scenes/screens/run_win.tscn` and final-summary version of game_over for the Grand Tournament loss case.

**Done when:** a full playable line from week 1 → Grand Tournament outcome is reachable in a single run. ✓

**Notes**
- Grand Tournament uses `Calendar.run_year(week)` (1-based years-since-start, not 1627+) — matches GDD §13's sanity check (`200 + year×50 = 250` at week 36).
- A lost Grand Tournament resets the streak and continues the run, per GDD §6 ("Lose: counter resets to 0; continue playing"). Only Home Battle loss ends the run.

---

## Phase 8 — Tuning & polish

**Goal:** A playable MVP that lasts a satisfying number of weeks without being trivially won or impossible.

**Deliverables**
- [ ] Run at least one full playthrough (Knight pick → ending). Capture week reached + outcome.
- [ ] Adjust enemy power multipliers (`× 3`, `× 4`, castle difficulty curve) per GDD §13's sanity check.
- [ ] Adjust gather-yield base values + Strength scaling if resource scarcity is wrong.
- [ ] UI polish — readable battle log, clearer event preview, consistent panel theming.
- [ ] Bug-fix pass on any rough edges flagged during playtest.

**Done when:** a fresh tester can finish a run without confusion and outcomes feel earned rather than coin-flippy.

---

## Progress Log

*Newest entry first. Add a dated line each session that ships code.*

- **2026-05-19 (combat infrastructure)** — **Tactical layer wired into resolution.** `EnemyActor` — duck-typed enemy unit satisfying CombatUnit's interface (id, unit_name, stats, weapon_id, armour_id). `EnemyDB` rewritten: all 9 enemy types now carry full 12-stat ranges + default_weapon_id/armour_id; `roll_combat_party(event_key, week)` builds real CombatUnit parties (uses RNG); `preview_party(event_key, week)` builds midpoint-average parties with no RNG (safe for UI). `CombatUnit` made duck-typed (untyped `unit` field), `power_mult` parameter added for home-battle 0.75× rule. `CombatSim` updated: random target selection (not lowest-HP), `turns_taken` removed from result, `analyze()` static added for fast RNG-free UI forecasts. `Resolution._resolve_away/home/_resolve_bandit_ambush` now run `CombatSim.run()` as the authoritative source of `won`; `sim_result` added to battle result dict; injury bracket derived from HP margins. `pre_battle_review._update_forecast()` replaced with `CombatSim.analyze()` against `EnemyDB.preview_party()`. **Next up:** migrate Battle Log to display sim turn_log; wire tournaments through CombatSim; expose equipment on Planning/UnitCard.

- **2026-05-19** — **Tactical combat simulation foundation.** Four new files. `Weapon` — static catalogue of 9 weapon entries (unarmed, shortsword, longsword, axe, spear, dagger, shortbow, longbow, crossbow) with damage range, hit_bonus, crit_bonus, primary_skill, and range_type. `Armour` — static catalogue of 6 armour tiers (unarmoured through full_plate) with base_rating, dodge_penalty, block_chance. `CombatUnit` — bridge class that takes a Unit + weapon/armour IDs and derives all combat-layer stats from strategy stats: max_hp (Str×3+Bra×2), initiative (Spd×2+Tec+skill), hit_chance (Tec+skill+weapon.hit_bonus), dodge_chance (Spd+Swd−armour.dodge_penalty), block_chance (armour.block_chance+Swd), crit_chance (Tec+weapon.crit_bonus), damage range (weapon_base+Str scaling), armour_value (armour.base_rating+Str/6), morale_pool (Bra×3+Det×2). Every previously-dead strategy stat now has a combat role; reserved notes added for Leadership, Intimidation, Loyalty, Etiquette, Horsemanship. `CombatSim` — turn-based engine: initiative-ordered action sequence, focus-fire targeting (lowest HP), hit→dodge→block→damage resolution with armour reduction, turn-limit fallback winner by remaining HP. Returns `{winner, turns_taken, attacker/defender_hp_remaining, combatant_stats, turn_log, notes}` for future Battle Log display. `Unit` gains `weapon_id` and `armour_id` string fields. `RosterGenerator` assigns starting kit (Knight: longsword+leather, Squire: shortsword+unarmoured). `SaveManager` serializes/deserializes both fields. **Next up:** wire CombatSim into Resolution as a parallel resolution path, or surface equipment on UnitCard/Planning.

- **2026-05-18 (mechanics harmony)** — **16-step mechanics cohesion audit, all steps shipped.** P1 (critical bugs): (1) `Determination.CHANCE_PER_POINT = 0.5` constant extracted — `tick.gd` now references it instead of duplicating the literal. (2) `resource_bundle.gd` — warning comment block added documenting the `wood/fibres` ↔ `logs/plant_fibres` key asymmetry and the `to_inventory_dict()` contract. (3) `resolution.gd` — game-over guard added before `_apply_reward()`; was applying rewards to ended runs. (4) `chronicle.gd` — seven `TAG_*` string constants added for all epithet grant sites. (5) `resolution.gd` — all bare tag-string literals replaced with `Chronicle.TAG_*` constants. P2 (formula extraction): (6) `combat.gd` — `static func tournament_unit_power(unit) -> int` named helper extracted (10+Str+Tec+max(Sword,Arch)); `resolve_tournament()` now calls it. (7) `pre_battle_review.gd` — participant power display uses `Combat.tournament_unit_power(u)`. (8) `expedition.gd` — `static func estimate_yield(party_strength) -> int` extracted from the inline `GATHER_BASE_YIELD × (1 + strength/30)` formula. (9) `tick.gd` — gather yield calls `Expedition.estimate_yield()`. (10) `planning.gd` — expedition forecast calls `Expedition.estimate_yield()`. P3 (crafting system): (11) New `scripts/systems/crafting.gd` — `Crafting.craft(gs, id)` and `Crafting.accept_caravan_offer(gs, idx)` centralise all inventory-mutation for crafting and caravan rewards. (12) `planning.gd._do_craft()` delegates to `Crafting.craft()`. (13) `game_state.gd.purchase_research()` helper added; `planning.gd._on_research()` uses it. (14) `weekly_summary.gd._on_caravan_pick()` delegates to `Crafting.accept_caravan_offer()` — caravan reward delivery now routes through the same layer as all other rewards. P4 (design-gap docs): (15) `enemy_db.gd TIER2_TYPES` — comment noting Phase 8 week-threshold activation plan. (16) `enemy_db.gd loot_tags` — comment noting reserved-for-future-loot-system status. **Next up:** Phase 8 balance pass.

- **2026-05-18** — **Polish & systems flesh-out pass.** Six files, 211 lines net. (1) `resolution.gd` — `Chronicle.grant_epithet()` was defined but never called anywhere; now fires at all win conditions: away-pillage (`pillage_win`), away-assault (`assault_win`), home-battle (`home_battle_won`), bandit-ambush (`home_battle_won`), champion-duel (`duel_win`), tournament (`tournament_win`), grand-tournament (`grand_tournament_win`). Newly earned epithets append to `result["notes"]` so they surface in the Battle Log. (2) `resource_db.gd` — added `RESEARCH_PROJECTS` const with three entries (`cotton_cultivation` / `alloy_research` / `blast_furnace`), each carrying name, description, gold cost, and a list of recipe IDs they unlock; keys match the existing `"research"` gate strings in `RESOURCES`. (3) `planning.gd` — replaced the static Research-tab stub with a live `_refresh_research_tab()` that renders each project with a gold-cost button, description, and "Unlocks:" list; purchasing deducts gold, appends to `GameState.researched`, and refreshes both Research and Crafting tabs. (4) `pre_battle_review.gd` — added `_enemy_flavor_text()` that draws on EnemyDB naming bands (week ≤8: goblins/bandits, ≤20: goblin-warriors/orcs, 20+: orc-veterans) and renders one contextual flavor line below the enemy-strength number. (5) `combat.gd` — replaced flat home-win `(2,2,1)` and bandit-ambush `(1,1,1)` bundles with week-scaled rolling formulas matching the pillage pattern. (6) `map_tile.gd` — Hills terrain now returns `"iron_ore"` from `gather_resource()` (previously returned nothing); `resource_db.gd` `iron_ore.map_source` corrected to `"hills"`. **Next up:** Phase 8 balance pass, or wire raw-material sources deeper into the gather/loot flow.

- **2026-05-17** — **Houses & Body Types** — visual banner system. Four archetypal noble houses (Brann/warrior, Aldermere/scholar, Daven/scout, Faldur/cavalier) each with a motto, palette, ordinary (pale/chevron/bend/saltire), charge (swords/book/arrow/horseshoe), and an implicit stat lean (+1 on 3 preferred stats, −1 on 2 discouraged stats — net budget roughly preserved). Four body types (Lean/Burly/Tall/Wiry) roll independently of house — pure visual signal, no stat effect. New data classes `HousePool` and `BodyType`; new Control `BannerIcon` renders procedural heraldry via custom `_draw()` (no PNG assets, scales from 28×36 chip to 132×168 hero). `Unit` gains `house_id` + `body_type` fields, rolled by `RosterGenerator`. Crest appears on every `UnitCard`, large on the Knight Chooser, full hero card on the Knight Overview. Leans are intentionally implicit — motto + origin hint, no stat chips. `SaveManager` extended to persist the new fields and (fixes a pre-existing gap) the chronicle fields `epithet/banner_line/origin_text/oath`; lazy-fills house/body on old saves. GDD §9 expanded with the new section + dated changelog entry. **Next up:** Phase 8 tuning, or layer house-keyed origin pools onto `Chronicle.generate_origin()` so prose clusters by household.

- **2026-05-15** — Resource system foundation. New autoload `ResourceDB` (registered in `project.godot`) defines the full T1–T3 resource tree (18 processed resources + 14 raw materials) with tier→colour mapping and static helpers `best_for_type`, `is_craftable`, `can_afford`. `GameState` gains `gold` (starts at 100), `inventory: Dictionary` (unified raw + processed stockpile), `researched: Array[String]` (research gate stubs), `maintenance_debt: bool`, and `gold_maintenance_cost()` (roster size × 5). `Tick` now deducts weekly gold maintenance, clamping to 0 and flagging `maintenance_debt` if short. Planning screen tabs reordered to **Overview → Tactics → Map → Crafting → Research**; Calendar moved out of the tab bar into a toggle button beside Advance Time. New **Crafting tab** shows raw-material stockpile counts and per-type recipe rows with tier-colour-coded names and Craft buttons (manual, immediate — deducts inputs, adds output). Top-bar resource HUD replaced with a `RichTextLabel` showing Gold + best-held resource per type (Fabric/Timber/Metal) with tier colours (grey T1, green T2, blue T3, purple T4, gold T5). **Next up:** Phase 8 tuning, or wire raw material sources into the gather/expedition flow.

- **2026-05-14** — Phases 5, 6, 7 shipped together. The week is now a real loop end-to-end: Planning → Tick (training, expedition timers/returns, per-training Det-rolled bonus, every-4-weeks Determination) → Pre-Battle Review → Resolution → Battle Log (combat events only) → Weekly Summary → Next Week. New stateless systems: `Tick`, `Combat`, `BattleEvent`, `Resolution` — each one a static helper that takes GameState in and writes results to typed Dictionary buffers (`last_tick_results`, `last_battle_result`). New scenes: `pre_battle_review.tscn` (event-aware setup pane), `battle_log.tscn` (per-unit table), `weekly_summary.tscn` (deltas + returns + rewards + caravan picker + branching Next button), `game_over.tscn`, `run_win.tscn`. Formation editor enforces single-unit-per-slot; live forecast shows player total vs enemy. Every reward formula and enemy-power scaling lives in `Combat.gd` as named static helpers so Phase 8 tuning has one file to touch. **Next up:** Phase 8 — playthrough(s) to tune enemy multipliers, gather base yield, reward sizes; UI polish where the play surfaces it.
- **2026-05-15** — Large UX/systems pass (12 features shipped in one session): **EnemyDB** (9 enemy types with stat ranges + group-power helper); **OutcomeBracket** system (sigmoid win probability, green/orange/red colouring on Pre-Battle forecasts, per-fighter injury rolling on orange/red outcomes — injuries tracked on Unit.injuries, decremented by Tick); **expedition forecast** panel in Map tab (return week + estimated yield per active GATHER); **gold income system** (weekly_stipend + tournament prizes, Tick applies income, cashflow BBCode panel on Overview); **F1 dev toolbar** (debug-only CanvasLayer — inventory add, gold set, advance N weeks, force-queue event, per-unit stat editor with PA cap display); **SaveManager** autoload (full GameState serialisation to user://savegame.json, auto-save on Advance Time, run history persisted to user://run_history.json, save deleted on run end); **stat tooltips** on UnitCard (all 12 stats with hint_tooltip one-liners, injured stats highlighted orange-red); **ConfirmDialogUtil** (modal before Advance, expedition launch, last-ingredient craft — suppress-this-run option stored in GameState.suppressed_confirms); **animated weekly resolution** (sections fade in sequentially via Tween, Next disabled until done); **crafting filter** (recipes hidden when research-locked + no ingredients + never crafted; visible-but-locked shown greyed with lock icon); **weekly diff summary** BBCode RichTextLabel with ▲ arrows, colour-coded training/determination/gold/injury-recovery sections; **main menu rebuild** (left panel: title, seed, New Game, Continue, Options, Quit; right panel: scrollable run history with wins in gold/losses in grey; debug Quick Start button). Also fixed game_over.gd and run_win.gd crash on non-existent GameState.resources field. **Next up:** Phase 8 tuning (balance pass on enemy power, yields, injury rates) and any missing Phase 8 systems.
- **2026-05-14** — Phase 4 complete. `Expedition` class + `active_expedition` on `MapTile` give a clean model for parties in the field. `WorldMapView` is a reusable 15×15 grid widget that the Planning screen drops in; tiles are colour-coded by terrain, Unknown is greyed, castles are red, town is gold, active expeditions show weeks-remaining. The Planning screen wires it all together: event banner, per-unit task picker (Defend / Train *stat*), per-unit checkbox for the next expedition party, separate Explore/Gather launch buttons gated by validation, away-week sub-section with Pillage/Assault and an Explored-castle dropdown, Advance Time button that walks the phase machine (Phase-5/6/7 logic is stubbed for now) and bumps the week. Roster view's Continue button now jumps to Planning. **Next up:** Phase 5 (real Tick — training application, expedition timers/returns, Pre-Battle Review screen with the formation editor).
- **2026-05-14** — Phase 3 complete. Title screen → Knight chooser → Roster view is wired end-to-end. `RosterGenerator` rolls 3 Knight candidates (stats 7–14 +1 flat, PA 100–180) and 3 starting Squires (stats 4–10, PA 60–140) using the seeded RNG, so the whole starting roster is reproducible. `UnitCard.build` is a shared builder used by both chooser and roster; PA stays hidden per GDD §10. `NamePool` provides 32×25 = 800 unique procedural names. `Determination.roll_for_units` honours the PA cap and skips expedition units — Phase 5's Tick will call it on weeks divisible by 4. **Next up:** Phase 4 (TileMap world map + Planning screen for at-home tasks, expeditions, and Away-week choice).
- **2026-05-14** — Phase 2 complete. `GameState` now tracks the run end-to-end (world, roster, resources, tournament streak, current event). `PhaseMachine` (lightweight RefCounted held on GameState) drives the Planning → Tick → Pre-Battle → Resolution cycle and emits `phase_changed` through `EventBus`. `Calendar`, `EventKind`, and `EventRoller` carry the weekly-clock and event-pick logic. Dev scene `scenes/dev/event_roll_test.tscn` (F6) simulates 50 weeks against a pinned seed and validates the tournament + Grand override rules. `main.gd` now prints the phase label so booting the game shows the wiring is live. **Next up:** Phase 3 (Title screen + Knight chooser + Roster view, then the every-4-weeks Determination roll).
- **2026-05-14** — Phase 1 complete. Data classes landed under `scripts/data/`: `Stats`, `ResourceBundle`, `MapTile`, `Castle`, `Unit`, `World`, and the static `WorldGenerator`. `Stats.try_increment` enforces both the 20 cap and the hidden PA cap, so future Train/Determination/Champion's Duel rewards all route through one place. `WorldGenerator.generate(seed)` is deterministic — same seed in, identical world (terrain, knowledge mask, castles, reward bundles) out. Dev scene `scenes/dev/world_dump.tscn` (F6) renders both grids, lists castles, runs all GDD §3/§4 sanity checks, and re-rolls the same seed for a determinism diff. **Next up:** Phase 2 (GameState wiring, weekly phase machine, event roller with tournament override).
- **2026-05-14** — Repo scaffolded (`cd69208`). MVP GDD imported into `GDD.md`. Phase 0 complete: `project.godot`, autoloads (`GameState`, `EventBus`, `RNG`), `Main.tscn`, folder layout.
