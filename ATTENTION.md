# ATTENTION.md — Things That Need Attention

The triage register: every known decision, gap, red flag, and debt item in
one place. **Short-form list first; depth below** — each ID links down.
`ROADMAP.md` stays the source of truth for *status*; this file is the
source of truth for *what's unresolved and why it matters*. Update both in
the session that resolves an item.

Last full revision: 2026-06-12.

---

## Short form

**A — Decisions only Jack can make**

| ID | Item | Blocking |
|---|---|---|
| A1 | Approve/veto the stat overhaul proposal (8 stats, condition layer, morale, death, formations-as-research) | Steps 8a + 8b — the main line of development |
| A2 | Merge PR #14 (formation menu, fight rendering, QoL run) | Nothing, but main drifts while open |
| A3 | GDD.md split (728 lines, past the ~500 trigger) | Nothing — convenience call |
| A4 | Standing-orders training default (shipped in #14) — confirm or veto the behaviour change | Nothing — revert is one line |

**B — Design gaps & known issues (scheduled, don't piecemeal-fix)**

| ID | Item | Fix lands in |
|---|---|---|
| B1 | **Castle assault difficulty is decorative** — assaults roll the same enemy party as a pillage; difficulty only scales loot | 8b/8c (needs sim-side difficulty scaling + tuned numbers) |
| B2 | Formation slots have no combat effect (UI is honest about it now) | 8b (slots → sim effects) |
| B3 | Five of twelve stats do nothing in combat | 8a/8b (stat overhaul) |
| B4 | Squire PA (60–140) overlaps the ~84 starting stat-sum → some units can **never grow** | Stat overhaul, PA rescale (proposal decision #5) |
| B5 | Tournaments use a separate deterministic model (no sim) | Proposal decision #6 — keep split or fold in |
| B6 | Oath "break" side unwired (honour-only v1) | Post-overhaul content pass |

**C — Balance red flags (data-backed; frozen until the 8c harness)**

| ID | Item | Evidence |
|---|---|---|
| C1 | Home-battle wall kills every naive run around week 23–35 | Every smoke battery since the runner existed |
| C2 | Visible stat growth is near-zero (+0 to +13 per 20–37-week run) | Growth telemetry, 2026-06-12 battery |
| C3 | CombatSim turn cap (30 actions ≈ <4 rounds of 4v4) may decide many fights on HP comparison | Code reading; unmeasured |
| C4 | `CombatSim.analyze` forecast ignores armour and crit → systematic forecast bias | Code reading; unmeasured |

**D — Tech debt & cleanup**

| ID | Item | When |
|---|---|---|
| D1 | Split `planning.gd` (~2,000 lines) into per-tab controllers | 8e |
| D2 | Regression-test the `STAT_CAP + 5` save clamp | 8e |
| D3 | GDD §13 retired-formula section needs the real rewrite | With stat overhaul GDD pass |
| D4 | `CombatEventDB.enemy_power_for` + pillage/home/ambush power curves are now caller-less | Delete or repurpose in 8b |
| D5 | Save-format fragilities: castles persist as coords vs a seed-regenerated world; `upgrade_costs` stub unpersisted | Before any public build |
| D6 | 5 research projects unlock placeholder resources that don't exist yet | Content unfreeze |
| D7 | Weekly-summary tournament table still renders the old power-breakdown shape | Fine while B5 stands; revisit with it |

**E — Tooling next steps**

| ID | Item | When |
|---|---|---|
| E1 | Balance harness: scripted policies, metrics, Monte-Carlo win curves | 8c — after 8a/8b land |
| E2 | CI: GitHub Action running `tools/smoke.sh` on PRs | Deferred by agreement; cheap whenever |
| E3 | Smoke policy coverage gaps: never crafts, never buys research, never rests | Extend with 8c policies |

**F — Watch list (no action unless they bite)**

| ID | Item |
|---|---|
| F1 | SessionStart hook may warn on Windows if bash is missing |
| F2 | New `class_name` files need a class-cache rebuild (get_godot.sh handles Linux; desktop = open editor once) |
| F3 | Old saves break on worldgen/RNG changes — accepted pre-release policy, three precedents |

---

## In depth

### A1 — The stat overhaul proposal
The full proposal is in the session log (2026-06-12): two layers — eight
trainable stats (Strength, Speed, Arms, Bow, Heart, Presence, Horse,
Courtesy via merges) plus a volatile condition layer (Condition / Wounds /
Shaken, words not numbers); morale as trigger-based theatre (enemies rout,
player units falter and rally under the Blue captain); permadeath with
traceable causes and replacement squires; formations as research-driven
progression (yard → colour doctrines → role specialisations); tournaments
re-anchored on Horse/Arms/Courtesy ("the lists vs the mud"). Seven numbered
open decisions, most consequential: death rules (#2), PA rescale (#5),
tournament formula (#6). **Everything in 8a/8b queues behind this.** B4 and
C2 are the hard data that the current PA/growth model is broken regardless —
if the proposal is vetoed, those two still need an independent fix.

### A4 — Standing orders
Shipped in PR #14: units mid-training keep their task week to week instead
of resetting to Defend. Rationale: staged development needs ~4.5 weeks per
point; the weekly reset made the player re-pick four units every week and
silently traded training for Defend on any forgotten click. Risk: a player
who *wants* everyone defending after a scare must actively switch trainers
back. If that feels wrong in play, the revert is one line in
`planning.gd::_default_pending_tasks`.

### B1 — Castle assault difficulty is decorative ⚠ top design gap
`Resolution._resolve_away` rolls `EnemyDB.roll_combat_party("pillage", week)`
for **both** pillage and assault; `Castle.difficulty` (30–200) only scales
the pre-rolled reward. The old strategy formula used difficulty as the enemy
power; the CombatSim migration dropped that and nothing replaced it. So the
fearsome diff-200 castle is exactly as dangerous as a roadside camp, with
~2× loot — strictly optimal to assault early, no risk story at all. The
pre-battle scout report is *accurate* about this (it shows the real party),
which makes the gap visible to any player who reads it. Fix shape (8b):
either an `assault` template family in `EnemyDB` whose count/tier/week-bonus
scale with `difficulty`, or a difficulty→party-budget function. Numbers
belong to the 8c harness — that's why this is documented, not patched.

### B2/B3 — Slots and dead stats
Both fully documented in `CLAUDE.md` Known Issues. Current honest state:
one combat model exists (`CombatSim`), all previews share its math, no UI
claims effects that don't exist. What's missing is the *positive* half —
slots and the five parked stats gaining real sim effects — which is the
overhaul's core (proposal §2, §4, §5).

### B4 — Units born at their ceiling
With 12 stats and starting rolls of 4–10, a squire's stat-sum averages ~84;
squire PA rolls 60–140. Any unit whose PA ≤ its starting sum can never gain
a point — `Stats._headroom_factor` returns 0 forever, and the dev arrows
never light. Telemetry confirms it: seed 1628 played 33 weeks, four units,
zero visible growth. This also silently devalues Determination's every-4th-
week roll and oath PA bonuses (+3/week honoured) for affected units — the
oath bonus is currently the *only* thing that can unstick them, which is at
least narratively pleasing but surely unintended. Resolves with the PA
rescale (proposal #5); if the proposal stalls, the minimal patch is rolling
PA as `starting_sum + margin` instead of an absolute range.

### B5/B6, D7 — Tournament split and oath breaks
Intentional v1 boundaries, written down so they don't read as oversights.
The tournament model decision is proposal #6; oath break penalties are a
content-layer addition once stat kinds settle (8 oath kinds post-merge).

### C1 — The week ~25 wall
Under the naive policy, every run on every seed range dies to a Home Battle
between weeks 20 and 42, median ~28. Enemy week-scaling (`week_bonus =
week/10` tiers in EnemyDB) outpaces a roster that barely grows (C2/B4) —
the wall is the *combination*, so fixing growth may move it substantially.
Don't tune either knob in isolation; chart both in 8c first.

### C3 — Turn cap
`CombatSim.DEFAULT_MAX_TURNS = 30` counts individual actions: an 8-combatant
fight gets under 4 full rounds before resolving on HP-remaining comparison.
Unmeasured how often the cap fires; if it's frequent, "winner" is mostly
"who has the bigger HP pool", which mutes Speed/Technique. The 8c harness
should log cap-hit rate per week before anyone touches the constant.

### C4 — Forecast bias
`_side_score` (used by every forecast surface) values expected damage ×
effective HP but ignores enemy armour and crit chance. Heavily-armoured
enemies are under-feared; crit builds under-valued. Acceptable while it's a
relative heuristic; worth recalibrating in 8c when Monte-Carlo curves exist
to calibrate against (the analyze→actual win-rate gap is itself a metric
worth charting).

### D-items
- **D1**: `planning.gd` hosts five tabs plus the week-advance pipeline.
  Split risk is `@onready` paths and cross-tab refresh calls; the UI probe
  is the regression net that makes this safe to attempt. Scheduled 8e.
- **D4**: After the scout report change, `CombatEventDB.enemy_power_for`
  and the pillage/home/ambush curves have no callers. They encode tuning
  *intent* (week scaling), so the call is: delete them, or make EnemyDB
  consume them as the party-budget function — which would also solve B1.
  Decide in 8b, not before.
- **D5**: Saves regenerate the world from `world_seed` and overlay castles
  by coordinates — any worldgen change shifts the map under an old save
  (accepted pre-release, F3). Before anything public: persist castle
  difficulty/reward in the save, and version the save format.

### E-items
- **E1** is the gate for the content unfreeze and all balance work. Spec
  sketch lives in plan step 4 (CLAUDE.md) — policies × seeds × metrics
  (week reached, win rate by event, gold curve, injuries, growth vs
  DEV_PACE, cap-hit rate, forecast-vs-actual gap) + Monte-Carlo `CombatSim`
  win curves per week per template. The full battery already runs in ~1 s,
  so scale is free.
- **E3**: the smoke policy never crafts, researches, or rests, so those
  code paths only get UI-probe coverage, not loop coverage. Add a
  "builder" policy alongside the fighter policy in 8c.
