class_name ConfirmDialogUtil
extends RefCounted

# Lightweight confirm dialog helper.
#
# Usage:
#   ConfirmDialogUtil.ask(parent_node, "advance_time", "Advance to next week?",
#       func(): _do_advance(),
#   )
#
# If action_id is in GameState.suppressed_confirms the callback fires immediately.
# "Don't show again this run" adds action_id to suppressed_confirms.


static func ask(
	parent: Node,
	action_id: String,
	message: String,
	on_confirm: Callable,
) -> void:
	if not GameState.has_active_run():
		on_confirm.call()
		return

	# Skip dialog if player suppressed it this run.
	if GameState.suppressed_confirms.has(action_id):
		on_confirm.call()
		return

	var dialog := _build_dialog(parent, action_id, message, on_confirm)
	parent.add_child(dialog)
	dialog.popup_centered(Vector2(400, 180))


static func _build_dialog(
	parent: Node,
	action_id: String,
	message: String,
	on_confirm: Callable,
) -> Window:
	var win := Window.new()
	win.title = "Confirm"
	win.size = Vector2i(420, 190)
	win.unresizable = true
	win.exclusive = true
	win.transient = true

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	win.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var msg_lbl := Label.new()
	msg_lbl.text = message
	msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(msg_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	vbox.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(100, 36)
	btn_row.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.custom_minimum_size = Vector2(80, 36)
	btn_row.add_child(cancel_btn)

	var suppress_btn := Button.new()
	suppress_btn.text = "Don't show again this run"
	suppress_btn.custom_minimum_size = Vector2(0, 36)
	vbox.add_child(suppress_btn)

	var _close_dialog: Callable = func():
		win.queue_free()

	confirm_btn.pressed.connect(func():
		win.queue_free()
		on_confirm.call()
	)

	cancel_btn.pressed.connect(func():
		win.queue_free()
	)

	suppress_btn.pressed.connect(func():
		if not GameState.suppressed_confirms.has(action_id):
			GameState.suppressed_confirms.append(action_id)
		win.queue_free()
		on_confirm.call()
	)

	win.close_requested.connect(func():
		win.queue_free()
	)

	return win
