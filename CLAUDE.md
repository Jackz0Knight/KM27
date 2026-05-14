# CLAUDE.md

Persistent context for Claude Code sessions working on KM27.

## Project

**KM27 — Knight Manager 1627.** A football/medieval roguelike roster-management mashup. Players manage a roster of knights across runs, balancing tactics, progression, and roguelike risk.

## Current Phase

**Pre-production.** Focus is the Game Design Document. No engine code yet — do not scaffold a Godot project, scenes, or scripts unless explicitly requested.

## Tech Stack

- **Engine:** Godot 4.x
- **Language:** GDScript (primary); C# only if a specific need arises.
- Engine skeleton deferred until the GDD stabilises.

## Repository Layout

```
README.md       Public landing page
GDD.md          Single-source Game Design Document (tiered headings)
CLAUDE.md       This file
LICENSE         Proprietary, all rights reserved
.gitignore      Godot 4 + OS/IDE patterns
.editorconfig   Cross-editor formatting rules
```

No `/src`, `/scenes`, `/scripts`, or `project.godot` yet — intentional.

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

## Working Agreements

- Plan before multi-file edits; prefer minimal diffs.
- Don't add Godot engine files (`project.godot`, scenes, scripts) without explicit instruction.
- Don't add CI, issue/PR templates, labels, or contributor docs yet — premature for pre-production.
- Never push to `main` directly.

## Security Note

`export_presets.cfg` (once created by Godot's editor) can contain signing keys, store credentials, and API tokens. Audit it before the first export build; consider moving secrets to an untracked `export.cfg` overlay.
