class_name UiStyle
extends RefCounted

# Centralised StyleBoxFlat builders. Every screen used to roll its own
# StyleBoxFlat with the same corner radii and similar border widths; this
# collapses those into named factory functions so future tinting / radius
# tweaks happen in one place.
#
# Companion: `scripts/autoload/palette.gd` holds the colours. UiStyle
# builders read Palette and assemble the StyleBoxFlat.
#
# Usage:
#   panel.add_theme_stylebox_override("panel", UiStyle.chip(
#       Palette.CHIP_SOON_BG, Palette.CHIP_SOON_BORDER,
#   ))

const CORNER: int = 6
const CORNER_SMALL: int = 4


# Generic chip — small rounded panel with a 2-px border. Used by the
# tournament countdown chip, the resource HUD bands, etc.
static func chip(bg: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = border_width
	sb.border_width_right = border_width
	sb.border_width_top = border_width
	sb.border_width_bottom = border_width
	sb.corner_radius_top_left = CORNER
	sb.corner_radius_top_right = CORNER
	sb.corner_radius_bottom_left = CORNER
	sb.corner_radius_bottom_right = CORNER
	return sb


# Card stylebox — chip + inner content margin baked in. Used by the
# castle picker cards, item drop notes, etc. The content margin matters
# because Button-rooted panels don't pass child margins through.
static func card(bg: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	var sb := chip(bg, border, border_width)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


# Slot panel — a chip with thicker default border (used when active state
# matters more than subtle decoration, e.g. formation slots with preview
# glow). Defaults to 3 px so the matched/preview style reads at a glance.
static func slot(bg: Color, border: Color, border_width: int = 2) -> StyleBoxFlat:
	return chip(bg, border, border_width)


# Knight icon background — chip with the standard 6 px radius and a hard
# ink border. Used by `KnightIcon` to tint the rounded square behind the
# initials.
static func knight_tile(class_color: Color) -> StyleBoxFlat:
	return chip(class_color, Palette.INK_BORDER, 2)


# A swatch panel — small inline icon background, smaller corner radius
# (4 px) so it reads as an icon, not a chip. Used by the crafting recipe
# row's tier-coloured glyph swatches.
static func swatch(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = CORNER_SMALL
	sb.corner_radius_top_right = CORNER_SMALL
	sb.corner_radius_bottom_left = CORNER_SMALL
	sb.corner_radius_bottom_right = CORNER_SMALL
	return sb


# Progress bar fill — used by the Pre-Battle Review win-prob gauge. Tints
# the fill with `colour`, and rounds all four corners.
static func progress_fill(colour: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = colour
	sb.corner_radius_top_left = CORNER_SMALL
	sb.corner_radius_top_right = CORNER_SMALL
	sb.corner_radius_bottom_left = CORNER_SMALL
	sb.corner_radius_bottom_right = CORNER_SMALL
	return sb


# Progress bar background — paired with progress_fill. Dark bed with a
# warm border so the empty bar still reads as part of the panel.
static func progress_bg() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.14, 0.10, 1.0)
	sb.border_color = Color(0.42, 0.32, 0.16, 1.0)
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = CORNER_SMALL
	sb.corner_radius_top_right = CORNER_SMALL
	sb.corner_radius_bottom_left = CORNER_SMALL
	sb.corner_radius_bottom_right = CORNER_SMALL
	return sb


# A faint divider line — used between Calendar rows. Subtle alpha so it
# reads as a flourish rather than a hard rule.
static func faint_divider() -> Color:
	return Palette.FADED_BG
