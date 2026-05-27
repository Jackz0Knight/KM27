class_name WeekProcessor
extends CanvasLayer

# FM-style "processing the week" overlay. Sits on top of Planning after the
# Tick has been applied but before the jump to Pre-Battle Review, and walks the
# player through what just happened one beat at a time — upkeep, the training
# yard, returning expeditions, the infirmary, and finally the week ahead.
#
# A procedurally-drawn spinner (no PNG assets, matching BannerIcon's ethos)
# turns while steps auto-reveal on a timer. "Notable" beats — unpaid wages, a
# discovered castle, the battle ahead — set `pause = true`, which halts the
# sweep and waits for a click / Enter, just like FM stops the schedule for
# news. A click during the auto-sweep skips ahead to the next beat.
#
# Usage (see planning.gd `_do_advance`):
#   var processor := WeekProcessor.new()
#   add_child(processor)
#   processor.begin(header, steps, func(): get_tree().change_scene_to_file(...))
#
# Step shape:
#   { "title": String, "icon": String, "lines": Array[String],
#     "tone": String, "pause": bool }

const REVEAL_DELAY: float = 0.55

var _steps: Array = []
var _on_finished: Callable = Callable()
var _idx: int = -1
var _paused: bool = false
var _finished: bool = false

# Untyped: holds a `_Spinner` (inner class), whose `spinning` member a
# `Control`-typed var would reject at parse time.
var _spinner = null
var _progress: ProgressBar = null
var _log: VBoxContainer = null
var _log_scroll: ScrollContainer = null
var _footer: Label = null
var _tick_timer: Timer = null


func begin(header_text: String, steps: Array, on_finished: Callable) -> void:
	_steps = steps
	_on_finished = on_finished
	layer = 100
	_build_ui(header_text)

	_tick_timer = Timer.new()
	_tick_timer.one_shot = true
	_tick_timer.timeout.connect(_advance_step)
	add_child(_tick_timer)

	_advance_step()


# ── Layout ────────────────────────────────────────────────────────────────

func _build_ui(header_text: String) -> void:
	var veil := Control.new()
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.02, 0.78)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720, 560)
	panel.add_theme_stylebox_override("panel", UiStyle.card(
		Color(0.14, 0.11, 0.07, 0.98), Palette.GOLD_DEEP, 2,
	))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	# Header row — spinner + title.
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 14)
	vbox.add_child(header_row)

	_spinner = _Spinner.new()
	_spinner.custom_minimum_size = Vector2(40, 40)
	header_row.add_child(_spinner)

	var title := Label.new()
	title.text = header_text
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Palette.PARCHMENT_DEEP)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(title)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = float(maxi(_steps.size(), 1))
	_progress.value = 0.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 10)
	_progress.add_theme_stylebox_override("background", UiStyle.progress_bg())
	_progress.add_theme_stylebox_override("fill", UiStyle.progress_fill(Palette.GOLD))
	vbox.add_child(_progress)

	vbox.add_child(HSeparator.new())

	_log_scroll = ScrollContainer.new()
	_log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_log_scroll)

	_log = VBoxContainer.new()
	_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log.add_theme_constant_override("separation", 8)
	_log_scroll.add_child(_log)

	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_color_override("font_color", Palette.FADED)
	_footer.text = "Processing the week…"
	vbox.add_child(_footer)

	# Transparent full-rect catcher on top of everything so a click anywhere —
	# including over the panel — advances the sweep. Added last → topmost for
	# input, regardless of the panel children's own mouse filters.
	var catcher := Control.new()
	catcher.set_anchors_preset(Control.PRESET_FULL_RECT)
	catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	catcher.gui_input.connect(_on_veil_gui_input)
	veil.add_child(catcher)


# ── Step driver ─────────────────────────────────────────────────────────────

func _advance_step() -> void:
	_idx += 1
	if _idx >= _steps.size():
		_finish()
		return

	var step: Dictionary = _steps[_idx]
	_reveal_step(step)
	_progress.value = float(_idx + 1)

	if bool(step.get("pause", false)):
		_paused = true
		_spinner.spinning = false
		_spinner.queue_redraw()
		_footer.text = ("▸ Click or press Enter — to battle!" if _idx == _steps.size() - 1
			else "▸ Click or press Enter to continue")
		_footer.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	else:
		_paused = false
		_spinner.spinning = true
		_footer.text = "Processing the week…  (click to skip ahead)"
		_footer.add_theme_color_override("font_color", Palette.FADED)
		_tick_timer.start(REVEAL_DELAY)


func _reveal_step(step: Dictionary) -> void:
	var tone_color: Color = _tone_color(str(step.get("tone", "neutral")))

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.card(
		Color(0.10, 0.08, 0.05, 0.85), tone_color.darkened(0.35), 1,
	))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	card.add_child(inner)

	var head := Label.new()
	head.text = "%s  %s" % [str(step.get("icon", "•")), str(step.get("title", ""))]
	head.add_theme_font_size_override("font_size", 16)
	head.add_theme_color_override("font_color", tone_color)
	inner.add_child(head)

	for line in step.get("lines", []):
		var lbl := Label.new()
		lbl.text = "   " + str(line)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_color_override("font_color", Palette.PARCHMENT_BRIGHT)
		inner.add_child(lbl)

	_log.add_child(card)

	# Quick fade-in so each beat reads as it lands.
	card.modulate.a = 0.0
	card.create_tween().tween_property(card, "modulate:a", 1.0, 0.2)

	# Keep the newest beat in view.
	_log_scroll.set_deferred("scroll_vertical", 1 << 20)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if _on_finished.is_valid():
		_on_finished.call()


# ── Input ─────────────────────────────────────────────────────────────────

func _on_veil_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_advance_input()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		_handle_advance_input()
		get_viewport().set_input_as_handled()


func _handle_advance_input() -> void:
	if _finished:
		return
	MasterAudio.play_click()
	if _paused:
		_advance_step()
	else:
		# Skip the auto-reveal wait and jump straight to the next beat.
		_tick_timer.stop()
		_advance_step()


func _tone_color(tone: String) -> Color:
	match tone:
		"good": return Palette.SUCCESS
		"bad": return Palette.DANGER
		"heal": return Palette.HEALING
		"info": return Palette.INFO
		"gold": return Palette.GOLD_BRIGHT
		_: return Palette.PARCHMENT_DEEP


# ── Procedural spinner (asset-free, mirrors BannerIcon's custom _draw) ───────

class _Spinner extends Control:
	var angle: float = 0.0
	var spinning: bool = true

	func _process(delta: float) -> void:
		if spinning:
			angle += delta * 4.2
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 4.0
		# Faint full ring as a bed.
		draw_arc(c, r, 0.0, TAU, 48, Color(0.42, 0.32, 0.16, 0.6), 3.0, true)
		if spinning:
			# Bright sweeping arc.
			draw_arc(c, r, angle, angle + TAU * 0.30, 24, Palette.GOLD_BRIGHT, 4.0, true)
		else:
			# Paused — a steady gold ring + a small centre mark.
			draw_arc(c, r, 0.0, TAU, 48, Palette.GOLD_BRIGHT, 3.5, true)
			draw_circle(c, 3.0, Palette.GOLD_BRIGHT)
