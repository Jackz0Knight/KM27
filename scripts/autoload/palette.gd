extends Node

# Centralised palette constants. Pulls the ~150 hard-coded `Color(...)`
# literals scattered across screens and widgets into one place so the
# medieval dress can be re-tinted in a single file. Names follow intent
# ("WARN", "INJURY") not appearance ("ORANGE_55"), so future re-skins keep
# the semantics intact.
#
# Autoload pattern: extends Node, no class_name (would conflict with the
# autoload singleton registration — see CLAUDE.md).
#
# Companion: `scripts/ui/ui_style.gd` builds StyleBoxFlat instances using
# these colours, so screens don't have to assemble corner radii + border
# widths inline.

# ── Foundation parchment / gold / ink ─────────────────────────────────────
const PARCHMENT: Color        = Color(0.78, 0.74, 0.60)
const PARCHMENT_DIM: Color    = Color(0.55, 0.50, 0.38)
const PARCHMENT_BRIGHT: Color = Color(0.86, 0.80, 0.65)
const PARCHMENT_DEEP: Color   = Color(0.92, 0.84, 0.55)
const GOLD_BRIGHT: Color      = Color(1.0, 0.84, 0.42)
const GOLD: Color             = Color(0.92, 0.78, 0.42)
const GOLD_DEEP: Color        = Color(0.78, 0.62, 0.30)
const GOLD_MUTED: Color       = Color(0.72, 0.58, 0.30)
const INK: Color              = Color(0.12, 0.08, 0.04)
const INK_BORDER: Color       = Color(0.15, 0.12, 0.08, 0.8)
const SHADOW_PANEL: Color     = Color(0.18, 0.14, 0.10, 0.75)
const SHADOW_DEEP: Color      = Color(0.16, 0.12, 0.08, 0.90)

# ── Semantic colours ──────────────────────────────────────────────────────
const SUCCESS: Color     = Color(0.55, 0.88, 0.55)
const SUCCESS_BRIGHT: Color = Color(0.70, 0.95, 0.70)
const WARN: Color        = Color(0.92, 0.62, 0.30)
const DANGER: Color      = Color(0.95, 0.55, 0.45)
const DANGER_BRIGHT: Color = Color(1.0, 0.66, 0.34)
const INJURY: Color      = Color(0.95, 0.55, 0.25)
const INFO: Color        = Color(0.65, 0.75, 0.95)
const FADED: Color       = Color(0.62, 0.56, 0.42)
const FADED_DIM: Color   = Color(0.45, 0.40, 0.30)
const FADED_BG: Color    = Color(0.45, 0.36, 0.20, 0.30)
const HEALING: Color     = Color(0.55, 0.80, 0.80)
const DEBT: Color        = Color(0.95, 0.38, 0.38)
const DISABLED_TEXT: Color = Color(0.5, 0.5, 0.5)

# Stat descriptor band tints — used by Stats.descriptor_color(). Mirrored
# here so other surfaces (knight overview blurbs, chronicle prose) can
# colour-match without reaching into the Stats helper.
const STAT_WRETCHED: Color = Color(0.65, 0.32, 0.28)
const STAT_POOR: Color     = Color(0.85, 0.55, 0.30)
const STAT_DECENT: Color   = Color(0.85, 0.78, 0.50)
const STAT_GOOD: Color     = Color(0.55, 0.88, 0.55)
const STAT_GREAT: Color    = Color(0.40, 0.85, 0.95)
const STAT_OUTSTANDING: Color = Color(1.0, 0.84, 0.42)

# ── Knight Icon class tints (KNIGHT vs SQUIRE) ────────────────────────────
const KNIGHT: Color = Color(0.95, 0.75, 0.35, 1.0)   # warm gold — knighted
const SQUIRE: Color = Color(0.62, 0.58, 0.50, 1.0)   # aged pewter — squire

# ── Slot drop zone styling ────────────────────────────────────────────────
const SLOT_BG_IDLE: Color        = Color(0.22, 0.22, 0.26, 1.0)
const SLOT_BORDER_IDLE: Color    = Color(0.45, 0.45, 0.5, 1.0)
const SLOT_BG_MATCHED: Color     = Color(0.20, 0.30, 0.22, 1.0)
const SLOT_BORDER_MATCHED: Color = Color(0.55, 0.95, 0.55, 1.0)
const SLOT_BG_PREVIEW: Color     = Color(0.32, 0.26, 0.14, 1.0)
const SLOT_BORDER_PREVIEW: Color = Color(0.98, 0.84, 0.34, 1.0)

# ── House motto + body labels on UnitCard ─────────────────────────────────
const HOUSE_MOTTO: Color = Color(0.70, 0.62, 0.40)
const TASK_TEXT: Color   = Color(0.78, 0.74, 0.62)
const NAME_DIM: Color    = Color(0.72, 0.70, 0.58)
const ORIGIN_PROSE: Color = Color(0.88, 0.82, 0.68)
const OATH_PROSE: Color  = Color(0.82, 0.78, 0.60)
const BANNER_PROSE: Color = Color(0.78, 0.72, 0.55)
const TRAIT_HIGHLIGHT: Color = Color(0.95, 0.78, 0.45)

# ── Tournament chip colour ramp ───────────────────────────────────────────
const CHIP_IMMINENT_BG: Color     = Color(0.36, 0.22, 0.08, 1.0)
const CHIP_IMMINENT_BORDER: Color = Color(1.0, 0.84, 0.30, 1.0)
const CHIP_IMMINENT_TEXT: Color   = Color(1.0, 0.86, 0.42)
const CHIP_SOON_BG: Color         = Color(0.28, 0.18, 0.08, 1.0)
const CHIP_SOON_BORDER: Color     = Color(0.92, 0.62, 0.30, 1.0)
const CHIP_SOON_TEXT: Color       = Color(0.95, 0.78, 0.45)
const CHIP_FAR_BG: Color          = Color(0.18, 0.14, 0.10, 1.0)
const CHIP_FAR_BORDER: Color      = Color(0.50, 0.40, 0.22, 1.0)
const CHIP_FAR_TEXT: Color        = Color(0.82, 0.74, 0.55)

# ── Castle card colour ramp (Map tab assault picker) ──────────────────────
const CASTLE_BG_IDLE: Color       = Color(0.16, 0.12, 0.08, 0.75)
const CASTLE_BG_TARGET: Color     = Color(0.28, 0.18, 0.08, 0.90)
const CASTLE_BORDER_IDLE: Color   = Color(0.50, 0.36, 0.20)
const CASTLE_BORDER_TARGET: Color = Color(0.95, 0.78, 0.30)

# ── Difficulty band colours (castle assault picker) ───────────────────────
const DIFF_LIGHT: Color   = Color(0.65, 0.88, 0.55)
const DIFF_MEDIUM: Color  = Color(0.92, 0.85, 0.45)
const DIFF_HEAVY: Color   = Color(0.95, 0.65, 0.35)
const DIFF_FORMIDABLE: Color = Color(0.95, 0.45, 0.40)

# ── Reward + outcome label tints used by Weekly Summary ───────────────────
const REWARD_GOLD: Color = Color(1.0, 0.85, 0.4)
const REWARD_LINE: Color = Color(0.7, 0.95, 0.7)
const OUTCOME_NEUTRAL: Color = Color(0.78, 0.78, 0.78)
const OUTCOME_LOST: Color    = Color(0.95, 0.6, 0.6)
const OUTCOME_WON: Color     = Color(0.6, 0.95, 0.6)
