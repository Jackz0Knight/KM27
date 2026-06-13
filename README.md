# KM27 — Knight Manager 1627

A football-manager / medieval-roguelike mashup. Run a household of four —
one Knight, three Squires — through the year 1627, week by brutal week.
Train them, send them into the mud, parade them at the lists, and read what
the chronicler wrote about it afterwards. Only for the brave...

**Win:** the Grand Tournament. **Lose:** your homestead falls.

## What's in the build

- Full week loop: plan → the week unfolds (FM-style sweep) → pre-battle
  review with live win forecast → tactical combat simulation → weekly
  summary that tells the fight's story
- Tactical battles: initiative, hit/dodge/block/crit, armour — every blow
  recorded; tournaments resolve at the lists by their own rules
- A 15×15 procedurally generated realm: exploration, regional gathering,
  castle assaults, and a fog of war that scouts honestly
- Resources, crafting, and a research tree; weapons and armour with rarity
  and drop tables
- ~92 data-driven story events, away-mission variants, traits, noble houses
  with heraldry, sworn oaths with mechanical weight, and a chronicler who
  turns your run into prose
- Deterministic seeded runs, save/load, and a headless smoke harness that
  auto-plays the game to keep it honest

**Status:** systems-complete MVP, mid-overhaul — stats and combat are being
redesigned around an attrition-roguelike core. See [ROADMAP.md](./ROADMAP.md)
for live progress.
**Tech:** Godot 4.6, GDScript, zero art assets — every visual is procedural.
**Docs:** [GDD.md](./GDD.md) · [ROADMAP.md](./ROADMAP.md) · [CLAUDE.md](./CLAUDE.md)
