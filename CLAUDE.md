# CLAUDE.md

Persistent context for Claude Code sessions working on KM27. Rewritten 2026-06-10
to match the codebase as it actually is — if this file and the code disagree,
the code wins; fix this file in the same session.

## Project

**KM27 — Knight Manager 1627.** A football-manager / medieval roguelike mashup.
Players manage a fixed 4-unit roster (1 Knight + 3 Squires) across a single run,
balancing training, expeditions, and combat events week by week.
**Win:** the Grand Tournament. **Loss:** a Home Battle defeat.

## Current State & Development Plan

Phases 0–7 are done — the full week loop is end-to-end playable (Title → Knight
chooser → Roster → Planning → Tick → Week Processor sweep → Pre-Battle Review →
Battle → Weekly Summary → next week, with Tournaments, Grand Tournament, and both
endings wired). A long polish-and-systems sprint then layered on: resources +
crafting + research, items, traits, reputation, oaths, chronicle prose, houses,
heraldry, staged stat development, a tactical combat simulation, data-driven
event catalogs (~92 story events, 10 away modes, 5 combat events), save/load,
and a rebuilt main menu.

**The agreed plan from here (2026-06-10 review, in order):**

1. ~~Rewrite CLAUDE.md~~ — this document.
2. **Stats & UI overhaul.** Condense per-unit stats into an at-a-glance FM-style
   grid; decide the final stat list with the rule that **every stat must do
   something** (five currently don't — see Known Issues). Update the strategy
   layer to match.
3. **Sim alignment.** Wire the new stats and the formation layer into
   `CombatUnit` / `CombatSim` so there is **one** combat model: slot effects,
   Blue-slot leadership aura, Intimidation vs the (already stubbed) morale pool.
   ~~Retire `Combat.resolve_formation` / repoint the editor's preview at
   `CombatSim.analyze`~~ — done 2026-06-12; one combat model exists, slots
   just don't feed it yet.
4. **Headless autonomy harness.** ~~First a cheap *smoke runner*~~ — shipped
   2026-06-10 (`tools/smoke.sh`, see Local Validation below); run it after
   every change during steps 2–3. Still to come once those land: the full
   *balance harness* — scripted policies, Monte-Carlo `CombatSim` win curves
   per week, metrics for week-reached / gold / injuries / `DEV_PACE`. That
   opens Phase 8d proper and an autonomous tune-test-commit loop. (The full
   10-seed × 60-week smoke battery runs in ~1 s, so the Monte-Carlo harness
   is computationally trivial.)
5. **Minor-notes cleanup.** Split `planning.gd` (~2,000 lines) into per-tab
   controllers; regression-test the `STAT_CAP + 5` save clamp; unfreeze content
   additions once balance numbers exist.

**Content is frozen until step 4 produces numbers** — new events/items/modes
added before balance exists get retuned twice.

`ROADMAP.md` remains the canonical checkbox status + Progress Log.

## Known Issues (read before touching combat)

These are the traps the 2026-06-10 review found. They are *scheduled* fixes
(steps 2–3 above), not surprises — don't "fix" them piecemeal mid-task without
checking the plan.

- **Formation slots still have no combat effect** (the UI is honest about it
  now). All real formation battles resolve through `CombatSim.run` on
  `CombatUnit`s (stats + weapon + armour only). `Combat.resolve_formation` and
  the dual-formula trap were **deleted 2026-06-12** — the formation editor's
  readout and the Tactics-tab forecast now run on `CombatUnit`/`CombatSim.
  analyze`, the same math as the fight. What remains pending (plan step 3):
  making slots DO something, as sim-level effects. `Combat.is_slot_match`
  survives for the editor's ★ markers and the oath-ledger fallback.
- **Five of twelve stats have no combat effect.** `CombatUnit._derive` consumes
  Strength, Speed, Technique, Bravery, Swordsmanship, Archery, Determination.
  Leadership, Intimidation, Loyalty, Etiquette, Horsemanship are "reserved"
  (Etiquette still scales tournament purses; Leadership/Intimidation still gate
  `is_slot_match`, which itself doesn't reach the sim). Don't build UI that
  oversells them before step 2 resolves this.
- **Tournaments use a different model** — deterministic power totals via
  `Combat.resolve_tournament` (`10 + Str + Tec + max(Swd,Arc)` + tournament-legal
  kit), no sim, no formation. This split is intentional for now.
- **GDD.md is 728 lines**, past the ~500-line migration trigger below. Flagged;
  Jack decides when to split — don't migrate it unprompted.

## Tech Stack

- **Engine:** Godot 4.6 (GL Compatibility renderer; launches fullscreen, F11 toggles).
- **Language:** GDScript only. No C#.
- **Resolution:** 1280×720 viewport, 1920×1080 window override, `canvas_items`
  stretch. Player-adjustable UI scale (0.75–1.40) via `UserPrefs`.

## Architecture in One Paragraph

`GameState` (autoload) owns all run state and the `PhaseMachine`; screens are
thin controllers over it. Systems under `scripts/systems/` are stateless static
helpers: `Tick` applies the week (training via `Stats.add_progress`, expedition
timers, maintenance), then `Resolution.run` orchestrates the event — it builds
`CombatUnit`s, calls `CombatSim.run` (or `Combat.resolve_tournament`), derives
an `OutcomeBracket` from the sim result for injuries, rolls rewards through
`RewardTableDB`, and is **the only mutator** of `GameState` on the combat path
(`Crafting` is the analogue for inventory mutation from the Crafting/Caravan
UIs). Content lives in pure-data catalogs (`StoryEventDB`, `AwayModeDB`,
`CombatEventDB`, `RewardTableDB`, `Weapon`, `Armour`, `TraitPool`, `HousePool`).
All gameplay randomness routes through the seeded `RNG` autoload, which is what
makes runs reproducible.

## Repository Layout

```
README.md            Public landing page
GDD.md               Game Design Document (§1–§18 + Changelog; 728 lines)
ROADMAP.md           Phased plan + Progress Log (living; source of truth)
CLAUDE.md            This file
LICENSE              Proprietary, all rights reserved
project.godot        Godot config; autoload list lives here
theme/               main_theme.tres — medieval palette

scenes/
  Main.tscn                       Title / main menu (built in code by main.gd)
  screens/                        One .tscn per screen: knight_chooser,
                                  roster_view, planning, knight_overview,
                                  pre_battle_review, weekly_summary,
                                  game_over, run_win
  ui/settings_popup.tscn          Shared settings modal
  debug/dev_toolbar.tscn          F1 dev overlay (autoloaded scene)
  dev/                            world_dump.tscn, event_roll_test.tscn (F6)

scripts/
  main.gd                         Title-screen controller
  autoload/                       GameState, EventBus, RNG, ResourceDB,
                                  EnemyDB, Palette, MasterAudio, UserPrefs
                                  (SaveManager + DevToolbar are autoloads too,
                                  registered from systems/ and scenes/debug/)
  data/                           class_name data classes + catalogs:
                                  Unit, Stats, MapTile, Castle, World,
                                  WorldGenerator, EventKind, NamePool,
                                  Expedition, HousePool, BodyType, TraitPool,
                                  Weapon, Armour, EnemyActor, RewardTableDB,
                                  StoryEventDB, AwayModeDB, CombatEventDB
  systems/                        Stateless rules: Calendar, EventRoller,
                                  PhaseMachine, RosterGenerator, Determination,
                                  Tick, Combat, CombatSim, CombatUnit,
                                  BattleEvent, Resolution, OutcomeBracket,
                                  Chronicle, OathLedger, ItemDrops, Crafting,
                                  SaveManager (autoload Node)
  ui/                             UnitCard, WorldMapView, FormationEditor,
                                  KnightIcon, TileIcon, MapPanZoom,
                                  PoolDropZone, SlotDropZone, ConfirmDialogUtil,
                                  SettingsPopup, DevToolbar, BannerIcon,
                                  UiStyle, ScreenFade, WeekProcessor
  screens/                        One controller per scenes/screens/*.tscn
  dev/                            Dev-only tooling (F6 in editor)

assets/textures/, assets/audio/   Empty — all visuals are procedural _draw()
data/                             Reserved for static CSV/JSON (future)
```

## How a Battle Actually Resolves

The canonical path, because it's the part this file used to get wrong:

1. Planning commits tasks → `Tick.apply` (decays dev arrows, applies training
   progress, ticks expeditions, charges maintenance).
2. `WeekProcessor` overlay plays the FM-style sweep; Pre-Battle Review shows a
   forecast from **`CombatSim.analyze`** (not the old sigmoid directly).
3. `Resolution.run` dispatches on event kind:
   - **Formation battles** (home / pillage / assault / ambush / away variants /
     combat events): `_player_cus(party)` builds `CombatUnit`s (home battles use
     `_player_cus_home` for the 0.75× non-Defend mult) → `EnemyDB.
     roll_combat_party` → `CombatSim.run` (initiative order, hit/dodge/block/
     crit/armour per action, turn cap) → `_fill_from_sim` → bracket from
     remaining HP → `OutcomeBracket.maybe_apply_injuries`.
   - **Tournaments / Grand**: `Combat.resolve_tournament` deterministic totals.
   - **Non-combat** (harvest, caravan, story events): resolved from catalog data.
4. Rewards: every roller is a thin wrapper over `RewardTableDB.roll(table_id,
   week, difficulty_mult)` — Dictionary keyed by `ResourceDB` ids. Items via
   `ItemDrops`. Reputation/oath/epithet beats fire at the end of `Resolution.run`.

## Touch-Point Cheat Sheet

| To change… | Edit… |
|---|---|
| Tactical combat (hit/dodge/block/crit/damage, turn cap) | `scripts/systems/combat_sim.gd` |
| Stat → combat-derivation (HP, initiative, chances) | `scripts/systems/combat_unit.gd` (`_derive`) |
| Enemy parties, types, stat ranges | `scripts/autoload/enemy_db.gd` (`roll_combat_party`) |
| Tournament math + enemy-power curves + reward wrappers | `scripts/systems/combat.gd` |
| Formation editor readout / Tactics forecast | `scripts/ui/formation_editor.gd` (`_unit_rating`, `set_forecast_context`) — sim-derived via `CombatUnit` + `CombatSim.analyze` |
| Weekly Summary fight table + highlight beats | `scripts/screens/weekly_summary.gd` (`_render_sim_rows`, `_sim_highlights`) — reads `result["sim_result"]` |
| Loot quantities / pools / week scaling | `scripts/data/reward_table_db.gd` — one dict entry per loot category |
| Item drop chances / rarity pools | `scripts/systems/item_drops.gd` |
| Weapon / armour catalogs | `scripts/data/weapon.gd` / `scripts/data/armour.gd` |
| Injury rolls + win-probability bands | `scripts/systems/outcome_bracket.gd` |
| Gather yield, training application, maintenance | `scripts/systems/tick.gd` |
| Staged development pace + dev arrows | `scripts/data/stats.gd` (`add_progress`, `DEV_PACE` / `DEV_HEADROOM_RANGE` / `MOMENTUM_WEEKS` knobs). All **in-run** gains feed `add_progress`; only start-of-run roster gen sets integers directly. `Stats.decay_development()` runs once per week at the top of `Tick.apply`. |
| Stat caps + PA-aware increment | `scripts/data/stats.gd` (`try_increment`; descriptor bands in `DESCRIPTORS`) |
| Event probabilities + Tournament override | `scripts/systems/event_roller.gd` |
| Calendar / seasons / tournament-week math | `scripts/systems/calendar.gd` |
| Random story events (effect primitives + gates) | `scripts/data/story_event_db.gd` (`EVENTS` — pure data; kinds: gold, gold_range, random_unit_stat, all_units_stat, random_unit_injury, reward_resources, inventory_add/remove, pa_delta, clear_injury, expedition_delay, reputation, reputation_range, stat_check outcomes) |
| Away mission variants | `scripts/data/away_mode_db.gd` (`MODES` — pure data) |
| Combat battle-event variants | `scripts/data/combat_event_db.gd` (`EVENTS` — pure data) |
| Crafting recipes / tier tree / research projects | `scripts/autoload/resource_db.gd` (`RESOURCES`, `RESEARCH_PROJECTS`) |
| Crafting / caravan inventory mutation | `scripts/systems/crafting.gd` |
| Knight/Squire starting rolls, PA ranges, class bonus | `scripts/systems/roster_generator.gd` |
| Traits | `scripts/data/trait_pool.gd` (`TRAITS`) |
| Houses (palette, charge, motto, lean pools) | `scripts/data/house_pool.gd` (`HOUSES`, `LEAN_*_POOL_BY_ARCHETYPE`; per-run leans via `roll_per_run_leans`, saved on `GameState.house_leans`) |
| Body silhouettes + implicit cap bumps | `scripts/data/body_type.gd` (`draw_silhouette`, `CAP_BUMPS`) |
| Oath honour (per-week hidden-PA bonus) | `scripts/systems/oath_ledger.gd` — wired from `Resolution.run` end; the *break* side is still unwired |
| Chronicle prose (weeks, origins, oaths, epithets, ballads, epitaphs) | `scripts/systems/chronicle.gd` |
| Reputation labels / HUD chip | `scripts/autoload/resource_db.gd` (`reputation_label/color`, `resource_hud_bbcode`) |
| Save format | `scripts/systems/save_manager.gd` (`user://savegame.json`, `user://run_history.json`) |
| Per-machine prefs (UI scale, audio volumes) | `scripts/autoload/user_prefs.gd` (`user://prefs.cfg`) |
| Semantic colours / StyleBox builders | `scripts/autoload/palette.gd` / `scripts/ui/ui_style.gd` |
| Audio buses + procedural UI click | `scripts/autoload/master_audio.gd` |
| Screen entry fade | `scripts/ui/screen_fade.gd` (`ScreenFade.fade_in(self)`) |
| "Processing the week" overlay beats | `scripts/ui/week_processor.gd`; beats built by `planning.gd::_build_week_steps` |

## EventBus Signals

Declared in `scripts/autoload/event_bus.gd`; emitters live in `GameState`,
`PhaseMachine`, `Tick`, `Resolution`. Add new cross-scene signals here, not
ad-hoc per scene.

- `run_started(seed_value: int)`
- `run_ended(outcome: String)` — `"win"` | `"loss"`
- `week_advanced(week: int)`
- `phase_changed(phase: int)` — `PhaseMachine.Phase`
- `event_rolled(kind: int)` — `EventKind`
- `battle_resolved(result: Dictionary)`
- `expedition_returned(expedition: Resource)`

## Local Validation (headless Godot)

Headless runs catch parse errors, missing class references, and autoload wiring
in seconds. **Both environments can run Godot:**

- **Cloud/Linux sessions:** `tools/get_godot.sh` downloads + caches the official
  4.6.1 Linux binary in `~/.cache/godot` and rebuilds the class cache on fresh
  clones. The committed SessionStart hook (`.claude/settings.json`) runs it
  automatically, so the binary is usually already there.
- **Jack's desktop (Windows):** `C:\Users\zoom3\Desktop\Godot_v4.6.1-stable_win64.exe`,
  whitelisted in `.claude/settings.local.json` (gitignored, machine-specific).

**The smoke runner is the primary validation tool** — run it after every change:

```bash
tools/smoke.sh                       # 10 seeds × 60 weeks + determinism replay (~1 s)
tools/smoke.sh --seeds=3 --weeks=12  # quick pass while iterating
```

It auto-plays full runs with a naive policy. The engine is
`scripts/dev/smoke_engine.gd` (`SmokeEngine`, shared by the headless shell
`smoke_runner.gd`/`smoke_run.tscn` AND the F1 toolbar's Smoke Harness
section), failing on any
`SCRIPT ERROR`/`Parse Error` line, invariant breach (week stuck, roster ≠ 4,
negative gold, orphaned expedition), or determinism mismatch (the first seed is
replayed and must trace identically). Win/loss/survival are all PASSING
outcomes — it checks correctness, not balance. It never calls
`SaveManager.save_game()`, so it can't clobber a real save.

Raw boot check (either OS — substitute the binary):

```bash
<godot> --headless --path . --quit-after 30
```

A clean run prints `[KM27] Title ready.` with no `SCRIPT ERROR` / `Parse Error`
lines. `Could not find type "Unit"`-style errors mean the class cache is
missing (`.godot/` is gitignored); rebuild it once with `<godot> --headless
--path . --editor --quit` (get_godot.sh does this automatically).

**Gotcha:** `--script <file>.gd` mode can't be used for anything that touches
game code — the project's scripts reference autoload globals, which don't
exist at `--script` compile time, so the whole dependency graph fails to load.
Dev tooling that needs the game must be a scene (like `smoke_run.tscn` /
the F6 scenes), run via `<godot> --headless --path . res://scenes/dev/<x>.tscn`.

## Dev Hotkeys & Debug Entry Points

| Key / button | What it does |
|---|---|
| **F1** | Dev toolbar overlay (debug builds only — it `queue_free()`s itself otherwise). Add resources, set gold/reputation, advance N weeks, force-queue events, spawn items, edit unit stats live, **run the smoke battery in-game** (Smoke Harness section — snapshots the live run via `SaveManager.snapshot_state()`, runs `SmokeEngine`, restores, reloads the scene). |
| **F6** (editor) | Run focused dev scene: `world_dump.tscn` (world-gen + determinism), `event_roll_test.tscn` (50-week event roller). |
| **F11** | Fullscreen toggle (handled in `GameState._input`, works everywhere). |
| **1–5 / C** (Planning) | Switch main tabs / toggle Calendar pane. |
| **Enter** | Primary action on Planning / Pre-Battle / Weekly Summary. |
| **Esc** | Close popups / overlays, back out of Knight Overview, cancel confirms. |
| **Right-click knight icon** (formation editor) | "Assign to slot…" popup — non-drag alternative. |
| **Title → Continue** | Shown when a save exists; confirm dialog previews via `SaveManager.peek_save()`. |
| **Title → Quick Start (Dev)** | Debug-only: week 10, gold 200, all stats 8, T1 stock, skips chooser. |

## Codebase Pitfalls

Hard-won; check before "fixing":

- **Autoloads must not declare `class_name`** — singletons under
  `scripts/autoload/` (plus `SaveManager`) `extends Node` only; a `class_name`
  double-registers the singleton (commit `7c823d2`). Pure data/system classes
  elsewhere DO use `class_name`.
- **No `static` methods on autoloads** — triggers "called from instance"
  warnings (commit `4295d9b`). Static helpers belong on non-autoload classes.
- **PA is invisible to the player by design** (GDD §10). Dev toolbar may show
  it; `UnitCard` and `knight_overview.gd` must not — and nothing player-facing
  may leak it indirectly (the dev-arrow fade near PA is the approved tell).
- **`Stats.set_value` clamps to `STAT_CAP + 5`, not `STAT_CAP`** — deliberate,
  so body-type cap bumps survive save/load. Don't "fix" the clamp; it's
  load-bearing for `BodyType.CAP_BUMPS`.
- **Scene-node names lag tab labels** — Planning's Map tab is still node
  `TownMap` in the .tscn. Don't rename nodes without sweeping `@onready` paths.
- **`RNG` inside sort comparators breaks sort invariants** — see
  `CombatUnit.init_jitter`: stamp randomness onto objects first, compare pure
  keys in the lambda.
- **Cross-run `static var` state desyncs seeds.** Any static mutable state
  that survives `start_run()` can change how many RNG draws a code path makes,
  silently breaking same-seed reproducibility within an app session.
  `RosterGenerator._taken_names` did exactly this (found by the smoke runner's
  determinism replay, 2026-06-10; now reset from `start_run`). New per-run
  state must be reset in `GameState.start_run()` — and the smoke runner's
  replay check is the regression net.
- **Old duplicate-message commits** (`a3fb26d`/`64b0be3`, `dcae5a8`/`ba7a20f`)
  are merge artefacts, not bugs.
- *(Removed 2026-06-10: the `ResourceBundle` migration pitfall — `ResourceBundle`
  was deleted in the 2026-05-28 resource overhaul; everything is Dictionaries
  keyed by `ResourceDB` ids now.)*

## How Jack Likes to Work

- **Numbered feedback batches** — implement the whole batch in one go, commit +
  push, then a brief 2-line summary. Don't half-ship.
- **FM-style information density, medieval dress** — more data first, then theme it.
- **Tabs always flat** — `clip_tabs=false`, `scrolling_enabled=false`; no overflow arrows.
- **Map controls** — middle-mouse-drag pan + scroll-wheel zoom (`MapPanZoom`).
- **"Bloated" means collapse, not enlarge** — sub-tabs and toggles over taller screens.
- **Show, don't tell** — hidden PA, descriptor words, implicit house leans, dev
  arrows. New systems should follow this register, not print numbers.

## GDD Conventions

- Single `GDD.md`, tiered headings; add `##` sections sparingly.
- **Always** add a dated `## Changelog` entry for substantive design changes.
- Migration trigger (~500 lines) **has been hit** (728 lines). Proposed to Jack;
  don't split until he says so.

## Branch & Commit Conventions

- Claude work: `claude/<short-slug>-<id>`. Human work: `feat/`, `fix/`, `docs/`.
- `main` is the integration branch — **never push to it directly**.
- Imperative mood, present tense; loose conventional prefixes (`feat(scope):`,
  `fix:`, `docs(gdd):` …) — match the area's existing style.
- Reference GDD sections when relevant. One logical change per commit.

## Working Agreements

- Plan before multi-file edits; prefer minimal diffs.
- `ROADMAP.md` is the single source of truth for status — read it at session
  start, tick boxes as deliverables ship, and **append a newest-first dated
  Progress Log entry every session that ships code**.
- **All gameplay randomness routes through the `RNG` autoload** — seeds must
  stay reproducible across world gen, rosters, events, combat, and prose.
- New autoloads: register in `project.godot` `[autoload]`; `extends Node`, no
  `class_name`.
- No CI, issue/PR templates, or contributor docs yet — premature for MVP.
- Keep this file truthful: if a session makes any section above stale
  (especially Known Issues and the cheat sheet), update it in that session.

## Security Note

`export_presets.cfg` (once the editor creates one) can contain signing keys and
store credentials. Audit before the first export build; consider an untracked
`export.cfg` overlay for secrets.
