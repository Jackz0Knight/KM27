class_name BannerIcon
extends Control

# Procedural heraldry renderer. One Control per unit; sized by the caller
# (a 28×36 chip on UnitCard, a 96×120 hero on the Knight Chooser). All
# rendering is custom _draw() — no PNG assets, scales freely.
#
# Composition (bottom → top):
#   1. Shield outline (heater shape) filled with the house's field tincture.
#   2. Ordinary band (pale | chevron | bend | saltire) in its own tincture.
#   3. Charge (swords | book | arrow | horseshoe) in its own tincture.
#   4. A 1px outline in the accent tincture.
#   5. Optional body silhouette beside the shield (when show_body=true).
#
# Public API:
#   set_unit(unit)          configure from a Unit; redraws.
#   set_show_body(bool)     toggle the body silhouette beside the shield.

var _house_id: String = ""
var _body_type: String = ""
var _show_body: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(28, 36)


func set_unit(unit: Unit) -> void:
	if unit == null:
		_house_id = ""
		_body_type = ""
	else:
		_house_id = unit.house_id
		_body_type = unit.body_type
	queue_redraw()


# Decorative entry point — render a house's crest without needing a Unit.
# Used by the title screen frieze. Pass body_type="" to suppress the silhouette
# (set_show_body still gates whether the silhouette renders at all).
func set_house(house_id: String, body_type: String = "") -> void:
	_house_id = house_id
	_body_type = body_type
	queue_redraw()


func set_show_body(show: bool) -> void:
	_show_body = show
	queue_redraw()


func _draw() -> void:
	if _house_id == "":
		return

	var house: Dictionary = HousePool.get_house(_house_id)
	if house.is_empty():
		return

	# Layout: shield occupies left portion if showing body, else full width.
	var sz: Vector2 = size
	var shield_w: float = sz.x if not _show_body else sz.x * 0.60
	var shield_rect := Rect2(Vector2.ZERO, Vector2(shield_w, sz.y))
	_draw_shield(shield_rect, house)

	if _show_body and _body_type != "":
		var body_rect := Rect2(
			Vector2(shield_w + sz.x * 0.05, 0.0),
			Vector2(sz.x * 0.35, sz.y),
		)
		BodyType.draw_silhouette(self, body_rect, _body_type, house.get("accent", Color.WHITE))


func _draw_shield(rect: Rect2, house: Dictionary) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var ox: float = rect.position.x
	var oy: float = rect.position.y

	# Heater shield outline — 7 points around the edge.
	var outline := PackedVector2Array([
		Vector2(ox + w * 0.05, oy),
		Vector2(ox + w * 0.95, oy),
		Vector2(ox + w * 0.95, oy + h * 0.50),
		Vector2(ox + w * 0.85, oy + h * 0.78),
		Vector2(ox + w * 0.50, oy + h),
		Vector2(ox + w * 0.15, oy + h * 0.78),
		Vector2(ox + w * 0.05, oy + h * 0.50),
	])

	# Field (background tincture).
	draw_colored_polygon(outline, house.get("field", Color(0.3, 0.3, 0.3)))

	# Ordinary on top of the field.
	_draw_ordinary(rect, house)

	# Charge over the ordinary.
	_draw_charge(rect, house)

	# Outline.
	var closed := PackedVector2Array(outline)
	closed.append(outline[0])
	draw_polyline(closed, house.get("accent", Color.WHITE), 1.5, true)


func _draw_ordinary(rect: Rect2, house: Dictionary) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var ox: float = rect.position.x
	var oy: float = rect.position.y
	var col: Color = house.get("ordinary_color", Color.WHITE)

	match house.get("ordinary", ""):
		"pale":
			# Vertical band down the centre.
			var poly := PackedVector2Array([
				Vector2(ox + w * 0.40, oy),
				Vector2(ox + w * 0.60, oy),
				Vector2(ox + w * 0.60, oy + h),
				Vector2(ox + w * 0.40, oy + h),
			])
			draw_colored_polygon(poly, col)
		"chevron":
			# Inverted V across the lower half.
			var poly := PackedVector2Array([
				Vector2(ox + w * 0.05, oy + h * 0.70),
				Vector2(ox + w * 0.50, oy + h * 0.40),
				Vector2(ox + w * 0.95, oy + h * 0.70),
				Vector2(ox + w * 0.95, oy + h * 0.82),
				Vector2(ox + w * 0.50, oy + h * 0.52),
				Vector2(ox + w * 0.05, oy + h * 0.82),
			])
			draw_colored_polygon(poly, col)
		"bend":
			# Diagonal band, top-left to bottom-right.
			var poly := PackedVector2Array([
				Vector2(ox + w * 0.05, oy + h * 0.05),
				Vector2(ox + w * 0.30, oy + h * 0.05),
				Vector2(ox + w * 0.95, oy + h * 0.80),
				Vector2(ox + w * 0.95, oy + h * 0.95),
				Vector2(ox + w * 0.70, oy + h * 0.95),
				Vector2(ox + w * 0.05, oy + h * 0.30),
			])
			draw_colored_polygon(poly, col)
		"saltire":
			# Two crossing diagonals — thick polylines clipped roughly to shield.
			var p1: Vector2 = Vector2(ox + w * 0.10, oy + h * 0.10)
			var p2: Vector2 = Vector2(ox + w * 0.90, oy + h * 0.85)
			var p3: Vector2 = Vector2(ox + w * 0.90, oy + h * 0.10)
			var p4: Vector2 = Vector2(ox + w * 0.10, oy + h * 0.85)
			draw_line(p1, p2, col, maxf(h * 0.08, 2.0), true)
			draw_line(p3, p4, col, maxf(h * 0.08, 2.0), true)


func _draw_charge(rect: Rect2, house: Dictionary) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var ox: float = rect.position.x
	var oy: float = rect.position.y
	var col: Color = house.get("charge_color", Color.WHITE)
	var cx: float = ox + w * 0.50
	var cy: float = oy + h * 0.45

	match house.get("charge", ""):
		"swords":
			# Two crossed blades + small pommel circles.
			var blade_w: float = maxf(h * 0.06, 1.5)
			var len: float = h * 0.34
			var p1a: Vector2 = Vector2(cx - len * 0.6, cy - len * 0.6)
			var p1b: Vector2 = Vector2(cx + len * 0.6, cy + len * 0.6)
			var p2a: Vector2 = Vector2(cx + len * 0.6, cy - len * 0.6)
			var p2b: Vector2 = Vector2(cx - len * 0.6, cy + len * 0.6)
			draw_line(p1a, p1b, col, blade_w, true)
			draw_line(p2a, p2b, col, blade_w, true)
			draw_circle(p1a, blade_w * 1.4, col)
			draw_circle(p2a, blade_w * 1.4, col)
		"book":
			# Closed book rectangle with a vertical spine line.
			var bw: float = w * 0.30
			var bh: float = h * 0.22
			var poly := PackedVector2Array([
				Vector2(cx - bw, cy - bh),
				Vector2(cx + bw, cy - bh),
				Vector2(cx + bw, cy + bh),
				Vector2(cx - bw, cy + bh),
			])
			draw_colored_polygon(poly, col)
			draw_line(Vector2(cx, cy - bh), Vector2(cx, cy + bh),
				house.get("field", Color.BLACK), maxf(h * 0.025, 1.0), true)
		"arrow":
			# Stem + head pointing up.
			var stem_h: float = h * 0.30
			var head_w: float = w * 0.22
			var head_h: float = h * 0.14
			draw_line(
				Vector2(cx, cy + stem_h * 0.5),
				Vector2(cx, cy - stem_h * 0.5 + head_h * 0.5),
				col, maxf(h * 0.05, 1.5), true,
			)
			var head := PackedVector2Array([
				Vector2(cx, cy - stem_h * 0.5 - head_h * 0.5),
				Vector2(cx + head_w, cy - stem_h * 0.5 + head_h * 0.5),
				Vector2(cx - head_w, cy - stem_h * 0.5 + head_h * 0.5),
			])
			draw_colored_polygon(head, col)
			# Fletching at the tail.
			var tail_w: float = w * 0.10
			var tail := PackedVector2Array([
				Vector2(cx, cy + stem_h * 0.5),
				Vector2(cx + tail_w, cy + stem_h * 0.5 + tail_w),
				Vector2(cx - tail_w, cy + stem_h * 0.5 + tail_w),
			])
			draw_colored_polygon(tail, col)
		"horseshoe":
			# Thick arc opening downward.
			var radius: float = h * 0.18
			var thickness: float = maxf(h * 0.07, 2.0)
			draw_arc(Vector2(cx, cy + radius * 0.2), radius, PI, TAU, 16, col, thickness, true)
			# Two small nail dots at the open ends.
			var nail_r: float = thickness * 0.5
			draw_circle(Vector2(cx - radius, cy + radius * 0.2), nail_r, col)
			draw_circle(Vector2(cx + radius, cy + radius * 0.2), nail_r, col)
