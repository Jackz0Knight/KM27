# CLAUDE.md

Persistent context for Claude Code sessions working on KM27.

## Project

**KM27 — Knight Manager 1627.** A football-manager / medieval roguelike mashup. Players manage a fixed 4-unit roster (1 Knight + 3 Squires) across a single run, balancing training, expeditions, and combat events week by week. **Win:** the Grand Tournament. **Loss:** a Home Battle defeat.

## Current Phase

**Phases 0–7 are done — the full week loop is end-to-end playable.** Title → Knight chooser → Roster → Planning → Tick → Pre-Battle Review → Battle Log → Weekly Summary → next week, with Tournaments, Grand Tournament, and Game Over / Run Win endings all wired.

**Phase 8 (tuning + playthroughs) is the next official phase**, but the project has been in an extended **polish-and-systems-expansion sprint** ahead of formal balance work. Most recent layers:

- **Resource expansion** — `ResourceDB` autoload defines a T1–T5 tier tree (18 processed + 14 raw resources); Planning has a Crafting tab with tier-coloured recipes; gold + weekly maintenance applied via `Tick`.
- **Combat feedback** — `EnemyDB` (9 enemy types), `OutcomeBracket` (sigmoid win-probability, green/orange/red Pre-Battle forecasts), injury system on `Unit.injuries`.
- **Persistence + run shell** — `SaveManager` autoload (auto-save + cross-run history), rebuilt main menu with run history panel, Continue, and Quick Start.
- **UX layer** — drag-and-drop formation editor, map pan/zoom, tabbed Planning UI (Overview / Tactics / Map / Crafting / Research, with Calendar as a top-bar toggle), confirm dialogs with suppress-this-run, animated weekly summary, F1 dev toolbar, full stat tooltips, settings popup, medieval theme palette.
- **Chronicle layer (2026-05-17)** — `Chronicle` system generates seeded prose week entries, plus per-unit origins, heraldic banners, sworn oaths, and earned epithets. Surfaces on the Knight Chooser, Knight Overview, and Weekly Summary.
- **Houses & Body Types (2026-05-17, most recent)** — four archetypal noble houses (Brann/Aldermere/Daven/Faldur) with implicit stat leans + four independent body silhouettes. Procedural heraldry via `BannerIcon` custom `_draw()` (no PNG assets). Crests appear on every `UnitCard`, scaled larger on Knight Chooser and Knight Overview. Leans are deliberately implicit — motto + origin hint, no stat tooltips.

**See `ROADMAP.md` for the canonical checkbox status and Progress Log; that's the source of truth, this file is just the orientation.**

## Tech Stack

- **Engine:** Godot 4.6 (GL Compatibility renderer; launches in fullscreen, F11 to toggle).
- **Language:** GDScript. No C# in the project.
- **Resolution:** 1280×720 viewport, 1920×1080 window override, `canvas_items` stretch.

## Repository Layout

```
README.md            Public landing page
GDD.md               Single-source Game Design Document (~475 lines)
ROADMAP.md           Phased implementation plan + Progress Log (living)
CLAUDE.md            This file
LICENSE              Proprietary, all rights reserved
.gitignore, .editorconfig
project.godot        Godot config; autoload list lives here
icon.svg             Placeholder "KM" mark
theme/               main_theme.tres — medieval palette, applied via gui/theme/custom

scenes/
  Main.tscn                       Title / main menu (built in code by main.gd)
  screens/
    knight_chooser.tscn           Pick 1 of 3 Knights (shows full chronicle card)
    roster_view.tscn              Roster overview, Continue → Planning
    planning.tscn                 Weekly Planning (5 tabs + Calendar toggle)
    knight_overview.tscn          Per-unit detail screen (click a name on any card)
    pre_battle_review.tscn        Post-Tick roster + event-aware setup pane
    weekly_summary.tscn           Chronicle + per-unit battle breakdown + deltas + returns + rewards + caravan picker
    game_over.tscn                Home Battle loss
    run_win.tscn                  Grand Tournament victory
  ui/settings_popup.tscn          Shared in-game settings modal
  debug/dev_toolbar.tscn          F1 dev overlay (autoloaded)
  dev/
    world_dump.tscn               Phase 1 world-gen verifier (F6)
    event_roll_test.tscn          Phase 2 50-week event roller (F6)

scripts/
  main.gd                         Title-screen controller (builds menu in code)
  autoload/                       Registered in project.godot
    game_state.gd                 Run state — see header for owned fields
    event_bus.gd                  Cross-scene signal hub
    rng.gd                        Seedable RandomNumberGenerator wrapper
    resource_db.gd                T1–T5 resource tree + tier→colour + helpers
    enemy_db.gd                   9 enemy types, stat ranges, group-power helper
  data/                           class_name resources:
                                  Unit, Stats, ResourceBundle, MapTile, Castle,
                                  World, WorldGenerator, EventKind, NamePool,
                                  Expedition, HousePool, BodyType
  systems/                        Stateless rules (each is a single static helper
                                  unless noted):
                                  Calendar, EventRoller, PhaseMachine,
                                  RosterGenerator, Determination, Tick, Combat,
                                  BattleEvent, Resolution, OutcomeBracket,
                                  Chronicle, SaveManager (autoload Node)
  ui/                             Shared widgets / utils:
                                  UnitCard, WorldMapView, FormationEditor,
                                  KnightIcon, MapPanZoom, PoolDropZone,
                                  SlotDropZone, ConfirmDialogUtil,
                                  SettingsPopup, DevToolbar, BannerIcon
  screens/                        Scene controllers (one per .tscn under screens/)
  dev/                            Dev-only tooling (F6 in editor)

assets/textures/, assets/audio/   Currently empty / placeholder
data/                             Reserved for static CSV/JSON (future)
```

## What's Actually Wired vs. Stubbed

| Area | State |
|---|---|
| Core week loop | **Done** — Planning → Tick → Pre-Battle → Resolution end-to-end. |
| All 4 event types + Tournament + Grand Tournament | **Done.** |
| Crafting tab + recipes | **Manual craft works.** Most raw material *sources* (mobs, specific tile types) are still placeholders — MVP raw materials still come mostly from pillage/assault loot. |
| Research tab | **Stub** — exists as a tab, has no content yet. |
| Chronicle epithet grants | System exists; trigger points on events not yet fired everywhere. |
| Oath consequences | Oaths are generated and displayed; honour/break mechanic not wired. |
| Save / Load / Run History | **Done** (`user://savegame.json`, `user://run_history.json`). |
| Phase 8 balance tuning | **Not started.** Enemy multipliers, gather yields, injury rates all per-GDD placeholder. |

## Touch-Point Cheat Sheet

When the task is "tune X" or "add a new Y", these are the canonical files to open first. Resolution / Combat / BattleEvent never read `GameState` directly — they take inputs, return Dictionary breakdowns; `Resolution` is the only mutator.

| To change… | Edit… |
|---|---|
| Enemy power scaling | `scripts/systems/combat.gd` — all formulas live as named static helpers (`enemy_power_pillage`, `enemy_power_home`, etc.) |
| Per-unit combat math | `scripts/systems/combat.gd` (`BASE_POWER`, `SLOT_BONUS`, `LEADERSHIP_BUFF`, slot-skill rules) |
| Reward formulas | `scripts/systems/resolution.gd` + `scripts/systems/battle_event.gd` |
| Gather yield + training application | `scripts/systems/tick.gd` |
| Event probabilities + Tournament override | `scripts/systems/event_roller.gd` |
| Calendar / Tournament-week math | `scripts/systems/calendar.gd` |
| Stat caps + PA-aware increment | `scripts/data/stats.gd` (`try_increment`) |
| Crafting recipes / tier tree | `scripts/autoload/resource_db.gd` (`RESOURCES` dict) |
| Enemy stat ranges + group power | `scripts/autoload/enemy_db.gd` |
| Win-probability colour bands + injury rolls | `scripts/systems/outcome_bracket.gd` |
| Chronicle prose pools (seasons, origins, oaths, epithets) | `scripts/systems/chronicle.gd` |
| Add / re-tint / re-charge a noble house | `scripts/data/house_pool.gd` (`HOUSES` dict) — palette, ordinary, charge, stat lean live in one entry |
| Body type silhouette shape | `scripts/data/body_type.gd` (`draw_silhouette`) |
| Heraldry drawing primitives | `scripts/ui/banner_icon.gd` — pure custom `_draw()`, scales freely |
| Knight starting bonus, stat ranges, PA ranges | `scripts/systems/roster_generator.gd` |
| Personal trait roster + stat/PA modifiers | `scripts/data/trait_pool.gd` (`TRAITS` dict) |
| Body type implicit stat-cap bumps | `scripts/data/body_type.gd` (`CAP_BUMPS` dict; `cap_bump_for` / `cap_bumps` helpers) |
| Oath honour checks (per-week PA bonus on aligned action) | `scripts/systems/oath_ledger.gd` — wired from `Resolution.run` end |
| Origin / oath / epithet prose pools | `scripts/systems/chronicle.gd` |
| Battle event sub-types + non-combat resolution | `scripts/systems/battle_event.gd` + `scripts/systems/resolution.gd` |
| Random story events (chronicle moments + effect primitives) | `scripts/data/story_event_db.gd` (`EVENTS` dict — pure data; resolver dispatches kinds: gold, gold_range, random_unit_stat, all_units_stat, random_unit_injury, reward_resources, inventory_add, inventory_remove, pa_delta, clear_injury, expedition_delay, reputation, reputation_range) |
| Away mission variants (rescue / hunt / nest / convoy) | `scripts/data/away_mode_db.gd` (`MODES` dict — pure data; `Resolution._resolve_away_custom` reads combat_template + reward_kind + epithet_tag + rep_on_win) |
| Reputation HUD chip + band labels | `scripts/autoload/resource_db.gd` (`reputation_label`, `reputation_color`, chip prefix in `resource_hud_bbcode`) |
| Weapon catalog + rarity / power_rating | `scripts/data/weapon.gd` |
| Armour catalog + rarity / power_rating | `scripts/data/armour.gd` |
| Item drop probabilities / rarity pools | `scripts/systems/item_drops.gd` |
| Save format / serialisation | `scripts/systems/save_manager.gd` |
| Shared UI palette / semantic colours | `scripts/autoload/palette.gd` — gold, parchment, success/warn/danger, slot-zone tints, tournament-chip ramp, castle / difficulty / stat band tints |
| StyleBoxFlat builders (chip / card / slot / swatch / progress) | `scripts/ui/ui_style.gd` — reads Palette, returns styled `StyleBoxFlat`s; screens drop their inline radius/border boilerplate |
| Audio bus volumes + UI SFX | `scripts/autoload/master_audio.gd` — three buses, `play_click()` SFX synthesised on first use |
| Screen entry animation | `scripts/ui/screen_fade.gd` — `ScreenFade.fade_in(self)` from any screen `_ready()` |

## EventBus Signals

Declared in `scripts/autoload/event_bus.gd`. Listeners attach at `_ready()`; emitters live in `GameState`, `PhaseMachine`, `Tick`, `Resolution`.

- `run_started(seed_value: int)`
- `run_ended(outcome: String)` — `"win"` | `"loss"`
- `week_advanced(week: int)`
- `phase_changed(phase: int)` — `PhaseMachine.Phase` enum
- `event_rolled(kind: int)` — `EventKind` enum
- `battle_resolved(result: Dictionary)`
- `expedition_returned(expedition: Resource)`

Add new signals here as new phases need them — don't proliferate ad-hoc signal definitions across scenes.

## Local Validation (headless Godot)

You can validate code changes without launching the editor by running the project headless. This catches parse errors, missing class references, and autoload wiring issues in seconds.

**Godot binary** (machine-specific, lives on Jack's Desktop):
```powershell
& 'C:\Users\zoom3\Desktop\Godot_v4.6.1-stable_win64.exe' --headless --path . --quit-after 30
```

A clean run prints `[KM27] Title ready.` and exits with no `SCRIPT ERROR` / `Parse Error` lines. If you see `Could not find type "Unit"` (or any other `class_name`'d type) errors, it usually means the **class cache is missing** — the registry that maps `class_name` declarations to script paths. Build it once by running the editor headless:

```powershell
& 'C:\Users\zoom3\Desktop\Godot_v4.6.1-stable_win64.exe' --headless --path . --editor --quit
```

That populates `.godot/global_script_class_cache.cfg`. Re-run the first command and errors should clear. The `.godot/` directory is gitignored, so a fresh worktree or CI runner will need this step.

**Other useful invocations:**
- `--script res://path/to/dev_scene.gd` — run a single script headless (good for the `scripts/dev/` validators).
- `--check-only` — pure GDScript parse check, no autoload bring-up.

The binary path is whitelisted in `.claude/settings.local.json` (gitignored — machine-specific). If the binary moves, update the wildcard there.

## Dev Hotkeys & Debug Entry Points

| Key / button | What it does |
|---|---|
| **F1** | Toggle dev toolbar overlay. `DevToolbar` is autoloaded but `queue_free()`s itself in non-debug builds, so this is debug-only. Add resources, set gold, advance N weeks, force-queue an event, edit unit stats live. |
| **F6** (in Godot editor) | Run the focused dev scene. `scenes/dev/world_dump.tscn` validates Phase 1 world gen + determinism; `scenes/dev/event_roll_test.tscn` runs the 50-week event roller test. |
| **F11** | Toggle windowed/fullscreen. Handled in `GameState._input` so it works on every screen. |
| **1–5** (Planning) | Switch main tabs (Overview / Tactics / Map / Crafting / Research). |
| **C** (Planning) | Toggle the Calendar pane. |
| **Enter** (Planning / Pre-Battle / Weekly Summary) | Trigger the screen's primary action (Advance Time / To Battle / Next Week). On Weekly Summary's first press, skips the staggered fade. |
| **Esc** | Close the settings popup, dismiss the intro splash, close the resource info overlay, or return from Knight Overview. Also cancels Confirm dialogs. |
| **Right-click on a knight icon** (formation editor) | Opens an "Assign to slot…" popup — keyboard / touchpad alternative to drag-drop. |
| **Title → Continue** | Appears when `user://savegame.json` exists. Opens a confirm dialog showing the saved year/week/gold/streak via `SaveManager.peek_save()` before loading. |
| **Title → Quick Start (Dev)** | Debug-only. Jumps to week 10, gold 200, all stats 8, T1 stock — bypasses the Knight chooser. |

## Codebase Pitfalls

The non-obvious things that have bitten previous sessions:

- **Resource ID overlap (active migration).** `ResourceBundle` (the legacy MVP triple used by Pillage/Assault/Tournament/Gather rewards) carries fields `wood / fibres / copper_ore`. The new `ResourceDB` inventory uses keys `logs / plant_fibres / copper_ore`. `ResourceBundle.to_inventory_dict()` is the translator, and `describe()` already prints the new display names ("Logs:X Plant Fibres:X"). When you touch either side, decide which system you're on and route through the translator — don't grep-replace.
- **Autoload `class_name` conflict.** Singletons under `scripts/autoload/` must `extends Node` and **must not** declare `class_name` — doing so causes Godot to register two singletons of the same name. Pure data classes under `scripts/data/` do use `class_name` (e.g. `Unit`, `Stats`); autoloads don't. See commit `7c823d2`.
- **Autoload methods are instance methods.** Marking a method `static` on an autoload triggers "called from instance" warnings — see commit `4295d9b`. Helpers that need to be `static` belong on a non-autoload class (e.g. `Combat`, `Calendar`).
- **Scene-node names lag tab labels.** Planning's Map tab is still node `TownMap` in the .tscn (`$Margin/VBox/Content/TownMap/...`). Don't rename the node without sweeping every `@onready` path.
- **PA is invisible to the player by design** (GDD §10). The dev toolbar shows it; `UnitCard.build` and `knight_overview.gd` must not.
- **Two duplicate-message chronicle commits** (`a3fb26d`/`64b0be3` and `dcae5a8`/`ba7a20f`) are merge artefacts, not bugs — same change, different branches.

## Likely Future Directions (in rough priority order)

These aren't committed scope — they're the threads Jack tends to pull. Use as hints, not a plan.

1. **Phase 8 balance pass** — first real playthroughs to ground-truth enemy power curves, gather yields, injury frequency, gold cashflow.
2. **Wire raw-material sources into gather/expedition flow** — so the Crafting tab has a sensible input pipeline beyond castle loot.
3. **Research tab content** — gate higher-tier recipes behind unlock keys (the `researched: Array[String]` field on GameState already exists).
4. **Epithet trigger coverage** — fire `Chronicle.grant_epithet()` from the right Resolution points (duel win, tournament win, etc.).
5. **Oath honour/break mechanic** — stat consequences when behaviour matches or violates the oath.
6. **More variety** — additional Battle Event templates, more enemy types in `EnemyDB`, possibly more formations beyond 4-0-0 (per GDD §17 these are future scope).
7. **Squire promotion / recruitment / morale** — explicitly excluded from MVP (GDD §17) but the most likely post-MVP expansion.

## How Jack Likes to Work

- **Numbered feedback batches** — when Jack drops a list ("minor tweaks: 1. X, 2. Y, 3. Z…"), implement the whole batch in one go, commit + push, then give a brief 2-line summary. Don't half-ship.
- **FM-style information density, medieval dress.** Default to more data, then dress it with the theme.
- **Tabs always flat** — `clip_tabs=false`, `scrolling_enabled=false`. He hates overflow arrows.
- **Map controls** — middle-mouse-drag pan + scroll-wheel zoom. There's a `MapPanZoom` widget; use it.
- **"Bloated" means collapse, not enlarge** — sub-tabs and toggles over taller screens.

## GDD Conventions

- Single `GDD.md` at the repo root, tiered headings (`#` > `##` > `###`).
- Use existing top-level sections; add `##` sections sparingly.
- **Always** add a dated entry to `## Changelog` when making substantive design changes.
- **Migration trigger:** if `GDD.md` exceeds ~500 lines or `###` headings start needing `####` children, propose splitting to a `gdd/` folder. Don't migrate silently — flag and let Jack decide.

## Branch Convention

- Claude-driven work: `claude/<short-slug>-<id>` (this worktree is `claude/agitated-chaum-ba4385`).
- Human work: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`.
- `main` is the integration branch. **Never push to `main` directly.**

## Commit Style

- Imperative mood, present tense ("add roster section", not "added").
- Reference the GDD section when relevant ("flesh out §13 Etiquette reward modifier").
- Conventional prefixes are used loosely: `feat(scope):`, `fix:`, `docs(scope):`, `feat(ux):`, `feat(chronicle):`. Match existing style for the area you're editing.
- Scope each commit to one logical change.

## Working Agreements

- Plan before multi-file edits; prefer minimal diffs.
- Follow phase order in `ROADMAP.md`; tick boxes as deliverables ship.
- **Update `ROADMAP.md`'s Progress Log at the end of any session that ships code** (newest entry first, ISO date prefix).
- Don't add CI, issue/PR templates, labels, or contributor docs yet — premature for early MVP.
- **All gameplay randomness MUST route through the `RNG` autoload** — that's what makes seeds reproducible (world gen, roster rolls, event rolls, chronicle prose all share the same seeded stream).
- New autoloads must be registered in `project.godot` under `[autoload]`. New singletons inside `RES://scripts/autoload/` should `extends Node` (NOT use `class_name` — that conflicts with the autoload registration, see commit `7c823d2`).

## Implementation Status

`ROADMAP.md` is the **single source of truth** for what's done, in progress, and queued. Read it at the start of every session. After shipping code, append a newest-first dated entry to the Progress Log.

Phase ordering is deliberate — don't jump ahead without checking dependencies. If a phase needs to expand or split, edit the roadmap itself; don't track scope drift in commit messages alone.

## Security Note

`export_presets.cfg` (once Godot's editor creates one) can contain signing keys, store credentials, and API tokens. Audit before the first export build; consider moving secrets to an untracked `export.cfg` overlay.
