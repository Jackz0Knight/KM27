# CLAUDE.md

Orientation for Claude Code sessions on KM27. **`ROADMAP.md` is the source of truth for status** — read its Progress Log first. This file is the map of *how the code is laid out and where to edit things*; it does not track per-feature history.

## Project

**KM27 — Knight Manager 1627.** A football-manager / medieval roguelike mashup. Manage a fixed 4-unit roster (1 Knight + 3 Squires) across one run, balancing training, expeditions, and combat week by week. **Win:** the Grand Tournament. **Loss:** a Home Battle defeat.

## Where the project is

Phases 0–7 are done — the full week loop is end-to-end playable (Title → Knight chooser → Roster → Planning → Tick → Week Processor → Pre-Battle → Battle → Weekly Summary → next week, with Tournaments, Grand Tournament, and both endings wired). Since Phase 7 the project has been in a long polish + systems-expansion sprint: data-driven event/away/combat catalogs, items + rarity, traits, reputation, oaths, chronicle prose, houses, staged stat development, an FM week-processor overlay, a tactical combat sim, and a unified resource/loot model.

**Two active threads going forward:**
- **Phase 8 — balance.** Almost every number is a placeholder. Needs real playthroughs (only runnable on Jack's machine). This is the most-flagged next push.
- **GDD §18 — Item & Crafting arc.** A design pass that locks Resources/Economy → Damage↔Stat → Crafting → Item Modifiers. §18.6 step 2 (fold weapon damage into `unit_power`) has shipped; steps 1, 3, 4, 5 (band field + gold tuning constants, `ITEM_RECIPES`, per-instance item modifiers, quality brackets) are pending.

## Tech Stack

- **Engine:** Godot 4.6, GL Compatibility renderer. Launches fullscreen, F11 toggles.
- **Language:** GDScript only. No C#.
- **Resolution:** 1280×720 viewport, 1920×1080 window override, `canvas_items` stretch. UI scale is user-adjustable via `UserPrefs`.

## Architecture in one screen

```
scripts/
  autoload/      Singletons (extends Node, NO class_name — see Pitfalls).
                 Registered in project.godot [autoload].
    game_state   Run state + lifecycle (start_run / advance_to_next_week / roll_current_event)
    event_bus    Cross-scene signal hub (see EventBus Signals below)
    rng          Seedable RNG — ALL gameplay randomness routes through this
    resource_db  T1–T5 resource tree + loot helpers (merge/scale/subtract_from/describe) + reputation labels
    enemy_db     9 enemy types, stat ranges, group power, per-enemy mob drops
    palette      Semantic colour constants
    master_audio 3 buses + procedural SFX library — play(id): click/hover/page/coin/forge/sword/levelup/success/denied
    music        Procedural medieval music (Karplus-Strong lute + open-fifth drone): menu / gameplay / battle loops + victory/defeat stings (run_ended-driven)
    user_prefs   Per-machine prefs (UI scale, volumes) → user://prefs.cfg, outside the run save
  data/          Pure data classes (DO use class_name):
                 Unit, Stats, MapTile, Castle, World, WorldGenerator, EventKind,
                 NamePool, Expedition, HousePool, BodyType, TraitPool, Weapon, Armour,
                 EnemyActor, RewardTableDB, StoryEventDB, AwayModeDB, CombatEventDB
  systems/       Stateless rules (static helpers; classes where noted):
                 Calendar, EventRoller, PhaseMachine, RosterGenerator, Determination,
                 Tick, Combat, CombatSim, CombatUnit, BattleEvent, Resolution,
                 OutcomeBracket, Chronicle, OathLedger, ItemDrops, Crafting,
                 SaveManager (autoload Node)
  screens/       One controller per scenes/screens/*.tscn
  ui/            Shared widgets: UnitCard, WorldMapView, FormationEditor, KnightIcon,
                 MapPanZoom, PoolDropZone, SlotDropZone, ConfirmDialogUtil, SettingsPopup,
                 DevToolbar, BannerIcon, UiStyle, ScreenFade, WeekProcessor
  dev/           F6-in-editor validators (world_dump, event_roll_test)
scenes/          Title (Main, built in code) + screens/ + ui/ + debug/ + dev/
theme/           main_theme.tres — medieval palette
GDD.md ROADMAP.md README.md   Design / status / landing
```

### How a week resolves

`Planning` commits tasks → `Tick.apply` (training, expedition returns, gold upkeep, stat development decay) → `WeekProcessor` overlay narrates the beats → `Pre-Battle Review` (event-aware setup + forecast) → `Resolution.run` orchestrates the battle and is **the only system that mutates GameState during combat** → `Weekly Summary`.

**Combat is two layers, on purpose:**
- `Combat` (combat.gd) — pure power *estimates* and enemy-power constants. Drives Pre-Battle forecasts and `OutcomeBracket` win-probability bands. `unit_power = 5 + Str + Bra + skill + slot_bonus + leadership_buff + weapon_damage`.
- `CombatSim` + `CombatUnit` + `EnemyActor` — the actual **HP-based, turn-based blow-by-blow simulation** that decides wins/losses and injuries. `CombatUnit._derive()` maps every strategy stat to a combat role (Str→HP/damage/armour, Speed→initiative/dodge, Technique→hit/crit, Bravery→HP/morale, Swd→melee hit/parry, Arc→ranged hit, Det→morale, Lea→…). Pure — no GameState access. Deterministic given a seed (initiative jitter is rolled once per combatant, not inside the sort comparator).

`Combat`, `CombatSim`, `BattleEvent`, and `OutcomeBracket` take inputs and return Dictionaries. `Resolution` reads those and mutates. Keep it that way.

### Resources & loot (post-migration — `ResourceBundle` is GONE)

One representation everywhere: a plain `Dictionary` keyed by `ResourceDB.RESOURCES` ids, same keys as `GameState.inventory`. No more legacy `wood/fibres` triple, no `to_inventory_dict()` translator.

- **Reward rollers** (`Combat`, `BattleEvent`, `StoryEventDB`, castle pre-roll, Resolution combat-event kinds) return Dictionaries.
- **`RewardTableDB`** holds the data-driven loot pools (`roll(table_id, week, difficulty_mult)` / `roll_blended(...)`). Each pool entry's `amount: [w1_lo, w1_hi, w40_lo, w40_hi]` interpolates by week, so retuning loot is one number on one entry.
- **`ResourceDB.merge / scale / subtract_from / bundle_is_empty / describe`** do what the old class wrapped; `describe()` sorts tier-ascending for stable display.
- **Mob drops:** `EnemyDB` entries carry a `drops` array; `EnemyDB.roll_drops_for(type_id)` + `Resolution._roll_spoils_from_enemies` aggregate spoils across dead enemies on a win and surface them as a separate "Spoils:" line. (Note: GDD §18.2 says mob drops are "out of scope for this pass" — that line is stale; mob drops shipped in the resource overhaul. Reconcile §18 before doing more §18 work.)
- **Regional gather:** `Tick._complete_one` for GATHER blends the target tile's table at full weight + each Chebyshev-1 neighbour at `GATHER_NEIGHBOUR_WEIGHT`. Mountain is passable for gather; the old adjacency special-case was scrapped.

## What's wired vs. stubbed

| Area | State |
|---|---|
| Core week loop, all event types, Tournaments, Grand Tournament, endings | **Done.** |
| Tactical combat sim (HP/initiative/dodge/crit/morale) | **Done** — `CombatSim`/`CombatUnit`/`EnemyActor`. |
| Resource model + loot tables + mob drops + regional gather | **Done** — unified Dictionary, `RewardTableDB`. |
| Items (weapons/armour/drops/equip) | **Done** — catalog + rarity + `power_rating` (now folded into `unit_power` as `weapon_damage`), `ItemDrops`, equip/swap UI, saved stockpile. |
| Crafting tab | **Resource→resource processing works** (`Crafting.craft`). **Item crafting (`ITEM_RECIPES`) NOT built** — §18.4. |
| Research tab | **Done** — gates higher-tier recipes via `GameState.researched`. |
| Traits, Reputation | **Done** — `TraitPool`, `GameState.reputation` (HUD chip, combat hooks, purse scaling). |
| Staged stat development + dev arrows | **Done.** `DEV_PACE` etc. are Phase-8 tuning knobs. |
| Oaths | **Honour side wired** (`OathLedger`, hidden +PA on aligned action). **Break/penalty side NOT wired.** |
| Epithets | Most trigger points fire; not every event grants one — sweep pending. |
| Save / Load / Run History | **Done**, back-compatible (items, rep, traits, leans, staged dev, oath_kind, spoils). |
| Item modifiers / quality brackets | **NOT built** — §18.5. |
| Dead income keys (`tournament_prize`, `expedition_trade`) | Declared + saved but never written — wire or delete. |
| Phase 8 balance | **Not started.** All multipliers/yields/rates/`DEV_PACE`/loot amounts placeholder. |

## Touch-Point Cheat Sheet

"Tune X / add a Y" → open this first.

| To change… | Edit… |
|---|---|
| Enemy power scaling (forecast layer) | `scripts/systems/combat.gd` — named static helpers (`enemy_power_pillage`, `enemy_power_home`, …) |
| Per-unit power estimate | `scripts/systems/combat.gd` (`BASE_POWER`, `SLOT_BONUS`, `LEADERSHIP_BUFF`, slot-skill rules, `weapon_damage` fold) |
| Blow-by-blow combat (HP, hit/dodge/block/crit, initiative) | `scripts/systems/combat_sim.gd` (the loop) + `scripts/systems/combat_unit.gd` (`_derive()` stat→combat mapping) |
| Enemy stat ranges, group power, mob drops | `scripts/autoload/enemy_db.gd` (`ENEMY_TYPES`, `drops`, `roll_drops_for`) |
| Win-probability colour bands + injury rolls | `scripts/systems/outcome_bracket.gd` |
| Loot pools / per-table amounts / scaling | `scripts/data/reward_table_db.gd` (`TABLES`; `roll` / `roll_blended`) |
| Reward orchestration + spoils aggregation | `scripts/systems/resolution.gd` (`_fill_from_sim`, `_roll_spoils_from_enemies`, `_apply_reward`) + `scripts/systems/battle_event.gd` |
| Gather yield + training application + upkeep | `scripts/systems/tick.gd` (`GATHER_NEIGHBOUR_WEIGHT`, `_apply_training`, `_apply_gold_maintenance`) |
| Resource tree / processing recipes | `scripts/autoload/resource_db.gd` (`RESOURCES`); craft action in `scripts/systems/crafting.gd` |
| Resource dict helpers (merge/scale/subtract/describe) | `scripts/autoload/resource_db.gd` |
| Event probabilities + Tournament override | `scripts/systems/event_roller.gd` |
| Calendar / Tournament-week / season math | `scripts/systems/calendar.gd` |
| Stat caps + PA-aware increment (roster gen only) | `scripts/data/stats.gd` (`try_increment`) |
| Staged development + dev-arrow pace | `scripts/data/stats.gd` (`add_progress`; `DEV_PACE` / `DEV_HEADROOM_RANGE` / `MOMENTUM_WEEKS` / `DEV_ACTIVE_WEEKS`; `development_state/glyph/color/tooltip`; `decay_development`). All in-run gains feed `add_progress`, NOT `try_increment`. |
| Week-processor overlay | `scripts/ui/week_processor.gd`; beats built in `planning.gd::_build_week_steps`, launched from `_do_advance` |
| Knight starting bonus, stat/PA ranges | `scripts/systems/roster_generator.gd` |
| Personal traits + stat/PA modifiers | `scripts/data/trait_pool.gd` (`TRAITS`) |
| Noble houses (palette/charge/lean) | `scripts/data/house_pool.gd` (`HOUSES`); per-run slants in `LEAN_PLUS/MINUS_POOL_BY_ARCHETYPE` (`roll_per_run_leans`) |
| Body type silhouette + cap bumps | `scripts/data/body_type.gd` (`draw_silhouette`, `CAP_BUMPS`) |
| Heraldry drawing | `scripts/ui/banner_icon.gd` (pure `_draw()`) |
| Oath honour checks | `scripts/systems/oath_ledger.gd` (run from `Resolution.run` end) |
| Chronicle prose (seasons/origins/oaths/epithets/asides/ballad/epitaph) | `scripts/systems/chronicle.gd` |
| Random story events | `scripts/data/story_event_db.gd` (`EVENTS`; effect primitives + `stat_check` + gates) |
| Away mission variants | `scripts/data/away_mode_db.gd` (`MODES`) |
| Combat battle-event variants | `scripts/data/combat_event_db.gd` (`EVENTS`) |
| Weapon / Armour catalog + rarity / power_rating | `scripts/data/weapon.gd` / `scripts/data/armour.gd` |
| Item drop probabilities / rarity pools | `scripts/systems/item_drops.gd` |
| Reputation HUD chip + band labels | `scripts/autoload/resource_db.gd` (`reputation_label/color`, `resource_hud_bbcode`) |
| Save format / serialisation | `scripts/systems/save_manager.gd` |
| UI palette / semantic colours | `scripts/autoload/palette.gd` |
| StyleBoxFlat builders (chip/card/slot/swatch/progress) | `scripts/ui/ui_style.gd` |
| Audio buses + SFX library (procedural — add a sound = a `_gen_*` + an `SFX_IDS`/dispatch entry) | `scripts/autoload/master_audio.gd` (`play(id)`, `_build_sfx`) |
| Menu / gameplay / battle music + win/loss stings (procedural — tempo, mode, note lists, voice mix) | `scripts/autoload/music.gd` (`_render_menu` / `_render_gameplay` / `_render_battle` / `_render_sting`) |
| UI scale + per-machine prefs | `scripts/autoload/user_prefs.gd` + `scripts/ui/settings_popup.gd` |
| Screen entry animation | `scripts/ui/screen_fade.gd` |

## EventBus Signals

Declared in `scripts/autoload/event_bus.gd`. Emitters: `GameState`, `PhaseMachine`, `Tick`, `Resolution`. Add new signals here, not ad-hoc across scenes.

`run_started(seed)` · `run_ended(outcome)` ("win"|"loss") · `week_advanced(week)` · `phase_changed(phase)` · `event_rolled(kind)` · `battle_resolved(result)` · `expedition_returned(expedition)`

## Local Validation (headless Godot)

No Godot binary exists in the Claude-on-the-web sandbox — code changes from a web session **must be validated by Jack** on his Windows host:

```powershell
& 'C:\Users\zoom3\Desktop\Godot_v4.6.1-stable_win64.exe' --headless --path . --quit-after 30
```

Clean run prints `[KM27] Title ready.` with no `SCRIPT ERROR` / `Parse Error`. If you see `Could not find type "Unit"` (etc.), the class cache is missing — rebuild once with the editor:

```powershell
& 'C:\Users\zoom3\Desktop\Godot_v4.6.1-stable_win64.exe' --headless --path . --editor --quit
```

`.godot/` is gitignored, so a fresh worktree / CI runner needs that step. Also: `--check-only` for a pure parse check; `--script res://…` to run a dev validator.

## Dev Hotkeys

| Key | Effect |
|---|---|
| **F1** | Toggle dev toolbar (debug builds only). Add resources, set gold/reputation, advance N weeks, force-queue an event, jump to an event, spawn an item, edit unit stats live. |
| **F6** (editor) | Run focused dev scene (`world_dump` = Phase 1 gen + determinism; `event_roll_test` = 50-week roller). |
| **F11** | Windowed/fullscreen (handled in `GameState._input`, works everywhere). |
| **1–5** (Planning) | Switch main tabs (Overview / Tactics / Map / Crafting / Research). |
| **C** (Planning) | Toggle Calendar pane. |
| **Enter** | Primary action on Planning / Pre-Battle / Weekly Summary. |
| **Esc** | Close settings / dismiss splash / close overlays / return from Knight Overview / cancel confirms. |
| **Right-click knight icon** | "Assign to slot…" popup (keyboard/touchpad alt to drag-drop). |
| **Title → Continue** | Appears when a save exists; confirm dialog shows year/week/gold/streak via `SaveManager.peek_save()`. |
| **Title → Quick Start (Dev)** | Debug-only jump to week 10 / gold 200 / stats 8 / T1 stock, bypasses chooser. |

## Codebase Pitfalls

- **Autoload `class_name` conflict.** Singletons under `scripts/autoload/` must `extends Node` and **must NOT** declare `class_name` (double-registers the singleton — commit `7c823d2`). Data classes under `scripts/data/` *do* use `class_name`.
- **Autoload methods are instance methods.** `static` on an autoload triggers "called from instance" warnings (commit `4295d9b`). Static helpers belong on non-autoload classes (`Combat`, `Calendar`, …).
- **Resource keys are unified now.** Everything is `logs / plant_fibres / copper_ore` etc., keyed to `ResourceDB.RESOURCES`. The old `wood / fibres` triple and `ResourceBundle` are gone — don't reintroduce them. Reward rollers return Dictionaries; deliver via `ResourceDB.merge` (or `Resolution._apply_reward` / `Crafting`).
- **Scene-node names lag tab labels.** Planning's Map tab is still node `TownMap` (`$Margin/VBox/Content/TownMap/...`). Don't rename without sweeping every `@onready` path.
- **PA is invisible to the player by design** (GDD §10). Dev toolbar shows it; `UnitCard.build` / `knight_overview.gd` must not. Same show-not-tell rule for stat caps, house leans, body bumps, and dev arrows.
- **Combat determinism.** `CombatSim` must keep its sort comparator pure — roll any jitter once per combatant *before* sorting (`CombatUnit._init_jitter`), never inside the comparator.

## Conventions & Working Agreements

- **GDD:** single `GDD.md`, tiered headings. Add a dated `## Changelog` entry for substantive design changes. If it exceeds ~500 lines or `###` needs `####` children, flag a `gdd/` split — don't migrate silently. (It's already at ~728 lines with §18 — a split is overdue; raise it with Jack.)
- **ROADMAP:** the single source of truth. Append a newest-first dated Progress Log entry every session that ships code. Tick boxes as deliverables land. Follow phase order; edit the roadmap rather than tracking scope drift in commits.
- **Branches:** Claude work `claude/<slug>-<id>`; human work `feat/`, `fix/`, `docs/`. `main` is integration — **never push to `main` directly.**
- **Commits:** imperative mood, scoped to one logical change, conventional-ish prefixes (`feat(scope):`, `fix:`, `docs(scope):`). Reference GDD sections where relevant.
- **Randomness:** ALL gameplay RNG routes through the `RNG` autoload — that's what makes seeds reproducible.
- **New autoloads:** register in `project.godot [autoload]`; `extends Node`, no `class_name`.
- **Minimal diffs, plan before multi-file edits.** Don't add CI / PR templates / contributor docs yet — premature for MVP.

## How Jack likes to work

- **Numbered feedback batches** — implement the whole batch in one go, commit + push, then a brief 2-line summary. Don't half-ship.
- **FM-style information density, medieval dress.** More data, then theme it.
- **Tabs always flat** (`clip_tabs=false`, `scrolling_enabled=false`) — no overflow arrows.
- **Map controls:** middle-drag pan + scroll-wheel zoom (`MapPanZoom`).
- **"Bloated" means collapse, not enlarge** — sub-tabs and toggles over taller screens.

## Security Note

`export_presets.cfg` (once Godot creates one) can hold signing keys / store credentials / API tokens. Audit before the first export build; consider an untracked `export.cfg` overlay for secrets.
