extends Node

# Centralised palette constants. Pulls the ~150 hard-coded `Color(...)`
# literals scattered across screens and widgets into one place so the
# medieval dress can be re-tinted in a single file. Names follow intent
# ("WARN", "INJURY") not appearance ("ORANGE_55"), so future re-skins keep
# the semantics intact.
#
# Autoload pattern: extends Node, no class_name (would conflict with the
# autoload singleton registration — see CLAUDE.md).

# ── Foundation parchment / gold / ink ─────────────────────────────────────
const PARCHMENT: Color        = Color(0.78, 0.74, 0.60)
const PARCHMENT_DIM: Color    = Color(0.55, 0.50, 0.38)
const PARCHMENT_BRIGHT: Color = Color(0.86, 0.80, 0.65)
const GOLD_BRIGHT: Color      = Color(1.0, 0.84, 0.42)
const GOLD: Color             = Color(0.92, 0.78, 0.42)
const GOLD_DEEP: Color        = Color(0.78, 0.62, 0.30)
const GOLD_MUTED: Color       = Color(0.72, 0.58, 0.30)
const INK: Color              = Color(0.12, 0.08, 0.04)
const INK_BORDER: Color       = Color(0.15, 0.12, 0.08, 0.8)

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
const HEALING: Color     = Color(0.55, 0.80, 0.80)

# ── Knight Icon class tints (KNIGHT vs SQUIRE) ────────────────────────────
const KNIGHT: Color = Color(0.95, 0.75, 0.35, 1.0)   # warm gold — knighted
const SQUIRE: Color = Color(0.62, 0.58, 0.50, 1.0)   # aged pewter — squire

# ── Slot drop zone styling ────────────────────────────────────────────────
const SLOT_BG_IDLE: Color       = Color(0.22, 0.22, 0.26, 1.0)
const SLOT_BORDER_IDLE: Color   = Color(0.45, 0.45, 0.5, 1.0)
const SLOT_BG_MATCHED: Color    = Color(0.20, 0.30, 0.22, 1.0)
const SLOT_BORDER_MATCHED: Color = Color(0.55, 0.95, 0.55, 1.0)
const SLOT_BG_PREVIEW: Color    = Color(0.32, 0.26, 0.14, 1.0)
const SLOT_BORDER_PREVIEW: Color = Color(0.98, 0.84, 0.34, 1.0)

# ── House motto + body labels on UnitCard ─────────────────────────────────
const HOUSE_MOTTO: Color = Color(0.70, 0.62, 0.40)
const TASK_TEXT: Color   = Color(0.78, 0.74, 0.62)
const NAME_DIM: Color    = Color(0.72, 0.70, 0.58)

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
