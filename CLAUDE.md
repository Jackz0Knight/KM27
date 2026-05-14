# CLAUDE.md

Persistent context for Claude Code sessions working on KM27.

## Project

**KM27 — Knight Manager 1627.** A football/medieval roguelike roster-management mashup. Players manage a roster of knights across runs, balancing tactics, progression, and roguelike risk.

## Current Phase

**MVP build.** GDD imported (`GDD.md`); implementation underway. See `ROADMAP.md` for the active phase, deliverable checklist, and Progress Log.

## Tech Stack

- **Engine:** Godot 4.x
- **Language:** GDScript (primary); C# only if a specific need arises.
- Engine skeleton deferred until the GDD stabilises.

## Repository Layout

```
README.md            Public landing page
GDD.md               Single-source Game Design Document (tiered headings)
ROADMAP.md           Phased implementation plan + Progress Log (living)
CLAUDE.md            This file
LICENSE              Proprietary, all rights reserved
.gitignore           Godot 4 + OS/IDE patterns
.editorconfig        Cross-editor formatting rules
project.godot        Godot 4 project config
icon.svg             Placeholder app icon ("KM" mark)
scenes/              Godot scenes (.tscn)
  Main.tscn          Entry-point handshake scene
scripts/             GDScript sources
  main.gd            Main scene controller
  autoload/          Singletons registered in project.godot
    game_state.gd    Run state (week, year, resources, roster, world)
    event_bus.gd     Cross-scene signal hub
    rng.gd           Seedable RandomNumberGenerator wrapper
assets/              Art and audio
  textures/
  audio/
data/                Static design data (CSV/JSON, future)
```

## GDD Conventions

- Single `GDD.md` at the repo root, tiered heading structure (`#` > `##` > `###`).
- Use existing top-level sections (Vision / Pitch, Core Pillars, Core Loop, Key Systems, MVP Scope, etc.). Add new `##` sections sparingly.
- **Always** add a dated entry to `## Changelog` when making substantive design changes (not for typo fixes).
- **Migration trigger:** when `GDD.md` exceeds ~500 lines, or navigation becomes painful (scrolling >10s to find a section, or `###` headings start needing `####` children), propose migrating to a `gdd/` folder with one file per current `##` section. Don't migrate silently — flag it and let the user decide.

## Branch Convention

- Claude-driven work: `claude/<short-slug>-<id>` (matches the active `claude/setup-km27-repo-KNvOG`).
- Human work: `feat/<slug>`, `fix/<slug>`, `docs/<slug>`.
- `main` is the integration branch.

## Commit Style

- Imperative mood, present tense ("add roster section", not "added").
- Reference the GDD section when relevant ("flesh out Core Loop section").
- Keep commits scoped — one logical change per commit.

## Implementation Status

`ROADMAP.md` is the single source of truth for **what's done, what's in progress, and what's queued.** Before starting work in a new session, read it. After shipping code, **update the Progress Log at the bottom** with a newest-first dated entry summarising what changed and what the next phase needs.

Phase ordering is deliberate — don't jump ahead without checking dependencies. If a phase needs to expand or split, edit the roadmap itself; don't track scope drift in commit messages alone.

## Working Agreements

- Plan before multi-file edits; prefer minimal diffs.
- Follow the phase order in `ROADMAP.md`; tick boxes as deliverables ship.
- Update `ROADMAP.md`'s Progress Log at the end of any session that ships code.
- Don't add CI, issue/PR templates, labels, or contributor docs yet — premature for early MVP build.
- Never push to `main` directly.

## Security Note

`export_presets.cfg` (once created by Godot's editor) can contain signing keys, store credentials, and API tokens. Audit it before the first export build; consider moving secrets to an untracked `export.cfg` overlay.
