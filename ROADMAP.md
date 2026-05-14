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
- [ ] Training resolver — `+1` to target stat (capped 20, capped by remaining PA); small Det-rolled bonus +1 chance to another stat.
- [ ] Expedition timer tick — decrement, on hit-zero deliver yield (`base_tile_yield × (1 + Σstrength/30)`), reveal Explored tile + castle if any, return units to home pool.
- [ ] `scenes/screens/pre_battle_review.tscn` — post-Tick roster snapshot.
- [ ] Formation editor — 4-0-0 slot picker (Blue / Green / Yellow / Red), unit drag-and-drop, slot-match `+2` highlighting.
- [ ] "To Battle" button → hands off to Phase 6's resolver.

**Done when:** training and expedition returns mutate `GameState` correctly during Tick, the review screen shows the post-Tick state, and the formation editor records assignments.

---

## Phase 6 — Combat resolution + events *(GDD §6, §13)*

**Goal:** Every event type can resolve end-to-end and produce a Weekly Summary.

**Deliverables**
- [ ] Formation-battle math — `unit_power = 5 + Str + Bra + skill + slot_bonus + leadership_buff`, intimidation reduction of enemy total, Defend=full / other-home-tasks=×0.75, expedition units absent.
- [ ] Pillage (`20 + week×3`), Home (`25 + week×4`), Assault (castle's fixed difficulty); won-castle removal from the world.
- [ ] Battle Event templates: Bandit Ambush, Travelling Champion's Duel (single-unit `Str + Bra + Sword` vs `20 + week×2`, +1 to a chosen stat on win), Bountiful Harvest, Merchant Caravan.
- [ ] `scenes/screens/battle_log.tscn` — per-unit contribution + final totals.
- [ ] `scenes/screens/weekly_summary.tscn` — stat deltas, returned expeditions, rewards, "Next Week" button.
- [ ] `scenes/screens/game_over.tscn` — triggered by Home Battle loss with cause + run stats.

**Done when:** any rolled event can play out from Planning through Weekly Summary, rewards land in `GameState.resources`, and a Home Battle loss ends the run.

---

## Phase 7 — Tournaments & endgame *(GDD §6, §13, §16)*

**Goal:** The win condition exists and can be reached.

**Deliverables**
- [ ] Tournament override at week 12N (already routed by Phase 2; finalise UI).
- [ ] Tournament resolution — `unit_power = 10 + Str + Tec + max(Sword, Arch)`, enemy `60 + tournament_number × 25`, up to 4 participants, no formation editor.
- [ ] Etiquette reward modifier — `reward × (1 + highest_Etiquette/40)` on Tournament wins.
- [ ] `tournament_streak` increments on win / resets on loss.
- [ ] Grand Tournament substitution after 2 consecutive wins (enemy `200 + year × 50`).
- [ ] `scenes/screens/run_win.tscn` and final-summary version of game_over for the Grand Tournament loss case.

**Done when:** a full playable line from week 1 → Grand Tournament outcome is reachable in a single run.

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

- **2026-05-14** — Phase 4 complete. `Expedition` class + `active_expedition` on `MapTile` give a clean model for parties in the field. `WorldMapView` is a reusable 15×15 grid widget that the Planning screen drops in; tiles are colour-coded by terrain, Unknown is greyed, castles are red, town is gold, active expeditions show weeks-remaining. The Planning screen wires it all together: event banner, per-unit task picker (Defend / Train *stat*), per-unit checkbox for the next expedition party, separate Explore/Gather launch buttons gated by validation, away-week sub-section with Pillage/Assault and an Explored-castle dropdown, Advance Time button that walks the phase machine (Phase-5/6/7 logic is stubbed for now) and bumps the week. Roster view's Continue button now jumps to Planning. **Next up:** Phase 5 (real Tick — training application, expedition timers/returns, Pre-Battle Review screen with the formation editor).
- **2026-05-14** — Phase 3 complete. Title screen → Knight chooser → Roster view is wired end-to-end. `RosterGenerator` rolls 3 Knight candidates (stats 7–14 +1 flat, PA 100–180) and 3 starting Squires (stats 4–10, PA 60–140) using the seeded RNG, so the whole starting roster is reproducible. `UnitCard.build` is a shared builder used by both chooser and roster; PA stays hidden per GDD §10. `NamePool` provides 32×25 = 800 unique procedural names. `Determination.roll_for_units` honours the PA cap and skips expedition units — Phase 5's Tick will call it on weeks divisible by 4. **Next up:** Phase 4 (TileMap world map + Planning screen for at-home tasks, expeditions, and Away-week choice).
- **2026-05-14** — Phase 2 complete. `GameState` now tracks the run end-to-end (world, roster, resources, tournament streak, current event). `PhaseMachine` (lightweight RefCounted held on GameState) drives the Planning → Tick → Pre-Battle → Resolution cycle and emits `phase_changed` through `EventBus`. `Calendar`, `EventKind`, and `EventRoller` carry the weekly-clock and event-pick logic. Dev scene `scenes/dev/event_roll_test.tscn` (F6) simulates 50 weeks against a pinned seed and validates the tournament + Grand override rules. `main.gd` now prints the phase label so booting the game shows the wiring is live. **Next up:** Phase 3 (Title screen + Knight chooser + Roster view, then the every-4-weeks Determination roll).
- **2026-05-14** — Phase 1 complete. Data classes landed under `scripts/data/`: `Stats`, `ResourceBundle`, `MapTile`, `Castle`, `Unit`, `World`, and the static `WorldGenerator`. `Stats.try_increment` enforces both the 20 cap and the hidden PA cap, so future Train/Determination/Champion's Duel rewards all route through one place. `WorldGenerator.generate(seed)` is deterministic — same seed in, identical world (terrain, knowledge mask, castles, reward bundles) out. Dev scene `scenes/dev/world_dump.tscn` (F6) renders both grids, lists castles, runs all GDD §3/§4 sanity checks, and re-rolls the same seed for a determinism diff. **Next up:** Phase 2 (GameState wiring, weekly phase machine, event roller with tournament override).
- **2026-05-14** — Repo scaffolded (`cd69208`). MVP GDD imported into `GDD.md`. Phase 0 complete: `project.godot`, autoloads (`GameState`, `EventBus`, `RNG`), `Main.tscn`, folder layout.
