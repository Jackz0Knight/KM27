class_name BodyType
extends RefCounted

# Four body silhouettes. Rolled independently of `house_id` so a "warrior
# house" (Brann) knight can still be Lean — the two signals stack into a
# legible character read at a glance, not a deterministic look-up.
#
# Body type does NOT affect stat rolls. It's a pure visual + flavour signal
# the player learns to read alongside the heraldic crest.
#
# Silhouette is drawn by `BannerIcon` next to the crest as a 1-bit figure.

const TYPES: Array[String] = ["lean", "burly", "tall", "wiry"]

const LABELS: Dictionary = {
	"lean":  "Lean",
	"burly": "Burly",
	"tall":  "Tall",
	"wiry":  "Wiry",
}

const FLAVOUR: Dictionary = {
	"lean":  "long-limbed and economical of motion",
	"burly": "broad through the shoulder, slow to anger and slower to move",
	"tall":  "a full head above the other men in the courtyard",
	"wiry":  "small-framed but never the first to tire",
}


static func random_body_type() -> String:
	return TYPES[RNG.randi_range(0, TYPES.size() - 1)]


static func label_for(body_type: String) -> String:
	return LABELS.get(body_type, body_type.capitalize())


static func flavour_for(body_type: String) -> String:
	return FLAVOUR.get(body_type, "")


# Draw the 1-bit silhouette into a target Control via its CanvasItem RID.
# Caller passes the rect to fill (already sized + positioned in local coords).
# Each silhouette is drawn as a stack of simple polygons (head + torso +
# limbs) sized off `rect.size`. Kept tiny so the same renderer works for the
# 16×16 card chip and the 48×48 chooser hero.
static func draw_silhouette(ci: CanvasItem, rect: Rect2, body_type: String, color: Color) -> void:
	var w: float = rect.size.x
	var h: float = rect.size.y
	var ox: float = rect.position.x
	var oy: float = rect.position.y

	# Proportions per type — head radius, shoulder half-width, hip half-width,
	# overall height (as fraction of `h`).
	var head_r: float
	var shoulder_w: float
	var hip_w: float
	var height_frac: float
	match body_type:
		"burly":
			head_r = h * 0.16
			shoulder_w = w * 0.42
			hip_w = w * 0.34
			height_frac = 0.92
		"tall":
			head_r = h * 0.12
			shoulder_w = w * 0.24
			hip_w = w * 0.22
			height_frac = 1.0
		"wiry":
			head_r = h * 0.13
			shoulder_w = w * 0.22
			hip_w = w * 0.20
			height_frac = 0.78
		_:  # "lean"
			head_r = h * 0.13
			shoulder_w = w * 0.26
			hip_w = w * 0.22
			height_frac = 0.92

	var center_x: float = ox + w * 0.5
	var top: float = oy + h * (1.0 - height_frac) * 0.5
	var bottom: float = top + h * height_frac

	# Head — circle.
	var head_center := Vector2(center_x, top + head_r)
	ci.draw_circle(head_center, head_r, color)

	# Torso — trapezoid from shoulder line to hip line.
	var shoulder_y: float = top + head_r * 2.2
	var hip_y: float = bottom - h * 0.18
	var torso := PackedVector2Array([
		Vector2(center_x - shoulder_w, shoulder_y),
		Vector2(center_x + shoulder_w, shoulder_y),
		Vector2(center_x + hip_w, hip_y),
		Vector2(center_x - hip_w, hip_y),
	])
	ci.draw_colored_polygon(torso, color)

	# Legs — two narrow rectangles down to bottom.
	var leg_w: float = hip_w * 0.45
	var left_leg := PackedVector2Array([
		Vector2(center_x - hip_w * 0.85, hip_y),
		Vector2(center_x - hip_w * 0.85 + leg_w, hip_y),
		Vector2(center_x - hip_w * 0.15, bottom),
		Vector2(center_x - hip_w * 0.55, bottom),
	])
	var right_leg := PackedVector2Array([
		Vector2(center_x + hip_w * 0.85 - leg_w, hip_y),
		Vector2(center_x + hip_w * 0.85, hip_y),
		Vector2(center_x + hip_w * 0.55, bottom),
		Vector2(center_x + hip_w * 0.15, bottom),
	])
	ci.draw_colored_polygon(left_leg, color)
	ci.draw_colored_polygon(right_leg, color)
