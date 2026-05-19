class_name TileIcon
extends Control

# Procedural tile decoration. Sits as a child of WorldMapView's per-tile
# Button, IGNORES mouse so clicks pass through, and draws an icon
# appropriate to the tile state (terrain hint for wilderness, tower for
# castle, keep for town, "?" fog for unknown). Pure custom _draw() — no
# image assets.

enum Kind { TERRAIN, CASTLE, TOWN, UNKNOWN, FOGGED }

var _kind: int = Kind.TERRAIN
var _terrain: int = 0
var _color: Color = Color.WHITE
var _expedition_weeks: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func configure(kind: int, terrain: int, color: Color, expedition_weeks: int = -1) -> void:
	_kind = kind
	_terrain = terrain
	_color = color
	_expedition_weeks = expedition_weeks
	queue_redraw()


func _draw() -> void:
	var sz: Vector2 = size
	match _kind:
		Kind.UNKNOWN:
			_draw_unknown(sz)
		Kind.FOGGED:
			_draw_fogged(sz)
		Kind.TOWN:
			_draw_keep(sz)
		Kind.CASTLE:
			_draw_tower(sz)
		Kind.TERRAIN:
			_draw_terrain_hint(sz, _terrain)

	if _expedition_weeks >= 0:
		_draw_expedition_flag(sz, _expedition_weeks)


# ── Special tiles ─────────────────────────────────────────────────────────

func _draw_unknown(sz: Vector2) -> void:
	# Deep unknown — a faint, ghostly "?" on a near-black tile.
	_draw_question_mark(sz, Color(0.45, 0.40, 0.32, 0.55), 0.18)


func _draw_fogged(sz: Vector2) -> void:
	# Fog-of-war — adjacent to an explored tile, still hidden but visibly
	# reachable. Brighter, slightly larger "?" plus a subtle hint dot
	# pattern so it reads as "you could send scouts here."
	var hint := Color(0.85, 0.74, 0.42, 0.85)
	_draw_question_mark(sz, hint, 0.22)


# Shared question-mark renderer — used by both unknown and fogged so the
# silhouette stays consistent and only the colour/size differs.
func _draw_question_mark(sz: Vector2, col: Color, radius_frac: float) -> void:
	var cx: float = sz.x * 0.5
	var cy: float = sz.y * 0.5
	var r: float = sz.y * radius_frac
	draw_arc(Vector2(cx, cy - r * 0.4), r, PI * 1.2, TAU * 0.95, 14, col, maxf(sz.y * 0.06, 1.5), true)
	draw_line(Vector2(cx, cy + r * 0.1), Vector2(cx, cy + r * 0.5), col, maxf(sz.y * 0.06, 1.5), true)
	draw_circle(Vector2(cx, cy + r * 0.85), maxf(sz.y * 0.05, 1.5), col)


func _draw_keep(sz: Vector2) -> void:
	# Player's town — a stylised keep with a banner. Drawn in deep gold so
	# it's the most visually weighted thing on the map.
	var cx: float = sz.x * 0.5
	var bottom: float = sz.y * 0.85
	var top: float = sz.y * 0.30
	var half_w: float = sz.x * 0.22
	var gold := Color(0.95, 0.78, 0.30)
	var dark := Color(0.30, 0.20, 0.08)

	# Keep body (rectangle).
	var body := PackedVector2Array([
		Vector2(cx - half_w, bottom),
		Vector2(cx - half_w, top),
		Vector2(cx + half_w, top),
		Vector2(cx + half_w, bottom),
	])
	draw_colored_polygon(body, gold)

	# Crenellations along the top.
	var ch_w: float = half_w * 2.0 / 5.0
	for i in range(5):
		if i % 2 == 0:
			var x0: float = cx - half_w + i * ch_w
			draw_rect(Rect2(x0, top - sz.y * 0.06, ch_w, sz.y * 0.06), gold, true)

	# Door (dark slot).
	draw_rect(Rect2(cx - half_w * 0.25, bottom - sz.y * 0.18, half_w * 0.5, sz.y * 0.18), dark, true)

	# Flag pole + small banner above the keep.
	var pole_top: float = sz.y * 0.10
	draw_line(Vector2(cx, top), Vector2(cx, pole_top), dark, 1.5, true)
	var flag := PackedVector2Array([
		Vector2(cx, pole_top),
		Vector2(cx + sz.x * 0.15, pole_top + sz.y * 0.05),
		Vector2(cx, pole_top + sz.y * 0.10),
	])
	draw_colored_polygon(flag, Color(0.85, 0.20, 0.20))


func _draw_tower(sz: Vector2) -> void:
	# Enemy castle — a single crenellated tower in red, smaller than the keep.
	var cx: float = sz.x * 0.5
	var bottom: float = sz.y * 0.82
	var top: float = sz.y * 0.32
	var half_w: float = sz.x * 0.18
	var red := Color(0.78, 0.22, 0.22)
	var dark := Color(0.25, 0.10, 0.08)

	# Tower body.
	var body := PackedVector2Array([
		Vector2(cx - half_w, bottom),
		Vector2(cx - half_w, top),
		Vector2(cx + half_w, top),
		Vector2(cx + half_w, bottom),
	])
	draw_colored_polygon(body, red)

	# 3 crenellations.
	var ch_w: float = half_w * 2.0 / 3.0
	for i in range(3):
		if i % 2 == 0:
			var x0: float = cx - half_w + i * ch_w
			draw_rect(Rect2(x0, top - sz.y * 0.06, ch_w, sz.y * 0.06), red, true)

	# Slit window.
	draw_rect(Rect2(cx - sz.x * 0.025, top + sz.y * 0.10, sz.x * 0.05, sz.y * 0.15), dark, true)


# ── Terrain hints ─────────────────────────────────────────────────────────

func _draw_terrain_hint(sz: Vector2, terrain: int) -> void:
	# Subtle ink mark over the terrain tint. Stylised, monochrome ink in a
	# slightly darker shade of the underlying tile so it reads as texture
	# rather than competing with castles/town.
	var ink: Color = _color.darkened(0.40)
	ink.a = 0.85
	var cx: float = sz.x * 0.5
	var cy: float = sz.y * 0.55

	match terrain:
		MapTile.Terrain.FOREST:
			# Three small triangle "trees".
			for i in range(3):
				var x: float = sz.x * (0.25 + i * 0.25)
				_draw_tree(Vector2(x, cy), sz.y * 0.20, ink)
		MapTile.Terrain.MOUNTAIN:
			# Two stacked peak triangles.
			_draw_peak(Vector2(cx - sz.x * 0.15, cy + sz.y * 0.05), sz.y * 0.30, ink)
			_draw_peak(Vector2(cx + sz.x * 0.10, cy - sz.y * 0.05), sz.y * 0.36, ink)
		MapTile.Terrain.HILLS:
			# Two soft arcs (bumps).
			draw_arc(Vector2(cx - sz.x * 0.16, cy + sz.y * 0.05), sz.x * 0.15, PI, TAU, 10, ink, maxf(sz.y * 0.05, 1.0), true)
			draw_arc(Vector2(cx + sz.x * 0.16, cy + sz.y * 0.05), sz.x * 0.13, PI, TAU, 10, ink, maxf(sz.y * 0.05, 1.0), true)
		MapTile.Terrain.PLAINS:
			# Three short verticals (grass tufts).
			for i in range(3):
				var x: float = sz.x * (0.30 + i * 0.20)
				draw_line(Vector2(x, cy + sz.y * 0.10), Vector2(x, cy - sz.y * 0.08), ink, 1.5, true)
		MapTile.Terrain.BEACH:
			# A single shallow wavy line.
			_draw_wave(Vector2(sz.x * 0.20, cy), sz.x * 0.60, sz.y * 0.06, ink)
		MapTile.Terrain.OCEAN:
			# Two stacked wavy lines.
			_draw_wave(Vector2(sz.x * 0.15, cy - sz.y * 0.10), sz.x * 0.70, sz.y * 0.06, ink)
			_draw_wave(Vector2(sz.x * 0.15, cy + sz.y * 0.10), sz.x * 0.70, sz.y * 0.06, ink)
		MapTile.Terrain.VILLAGE:
			# Small hut (triangle on a rectangle).
			var hx: float = cx
			var hy: float = cy
			var roof := PackedVector2Array([
				Vector2(hx - sz.x * 0.14, hy),
				Vector2(hx + sz.x * 0.14, hy),
				Vector2(hx, hy - sz.y * 0.16),
			])
			draw_colored_polygon(roof, ink)
			draw_rect(Rect2(hx - sz.x * 0.10, hy, sz.x * 0.20, sz.y * 0.14), ink, true)


func _draw_tree(centre: Vector2, height: float, col: Color) -> void:
	var tri := PackedVector2Array([
		Vector2(centre.x, centre.y - height * 0.5),
		Vector2(centre.x + height * 0.45, centre.y + height * 0.4),
		Vector2(centre.x - height * 0.45, centre.y + height * 0.4),
	])
	draw_colored_polygon(tri, col)


func _draw_peak(centre: Vector2, height: float, col: Color) -> void:
	var tri := PackedVector2Array([
		Vector2(centre.x, centre.y - height * 0.5),
		Vector2(centre.x + height * 0.55, centre.y + height * 0.5),
		Vector2(centre.x - height * 0.55, centre.y + height * 0.5),
	])
	draw_colored_polygon(tri, col)


func _draw_wave(start: Vector2, width: float, amplitude: float, col: Color) -> void:
	# Approximate a sine wave with a polyline.
	var points := PackedVector2Array()
	var segs: int = 10
	for i in range(segs + 1):
		var t: float = float(i) / float(segs)
		var x: float = start.x + width * t
		var y: float = start.y - sin(t * TAU) * amplitude
		points.append(Vector2(x, y))
	draw_polyline(points, col, 1.5, true)


# ── Expedition flag overlay ───────────────────────────────────────────────

func _draw_expedition_flag(sz: Vector2, weeks: int) -> void:
	# Top-right pennant + week count tucked inside the tile.
	var pole_x: float = sz.x * 0.78
	var pole_top: float = sz.y * 0.08
	var pole_bot: float = sz.y * 0.38
	var dark := Color(0.10, 0.08, 0.06)
	var pennant := Color(0.95, 0.78, 0.30)

	draw_line(Vector2(pole_x, pole_top), Vector2(pole_x, pole_bot), dark, 1.5, true)
	var flag := PackedVector2Array([
		Vector2(pole_x, pole_top),
		Vector2(pole_x + sz.x * 0.14, pole_top + sz.y * 0.06),
		Vector2(pole_x, pole_top + sz.y * 0.12),
	])
	draw_colored_polygon(flag, pennant)

	# Week count below the flag.
	var font: Font = ThemeDB.fallback_font
	var fsize: int = maxi(int(sz.y * 0.22), 9)
	var text: String = "%dw" % weeks
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize)
	var tx: float = pole_x - text_size.x * 0.5 + sz.x * 0.06
	var ty: float = pole_bot + text_size.y * 0.5
	draw_string(font, Vector2(tx, ty), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, Color(1, 1, 1, 0.95))
