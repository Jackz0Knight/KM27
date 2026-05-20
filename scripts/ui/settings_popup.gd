extends PopupPanel

# Reusable Settings popup. Instantiate via SettingsPopup.show_for(caller_node).
# Any screen with a Cog button can wire it in two lines:
#
#   func _on_cog():
#       SettingsPopup.show_for(self)
#
# Layout: fullscreen toggle, audio sliders (Master / Music / SFX wired to
# the MasterAudio autoload's buses), a "Save Now" button, and the navigation
# actions (Back / Main Menu / Quit). The latter two prompt a confirm so an
# in-progress run isn't lost on accident; the suppress-this-run toggle from
# `ConfirmDialogUtil` still applies if the player wants to skip the prompt.
#
# Esc closes the popup so the player doesn't have to fish for the Back button.

@onready var fullscreen_btn: Button = $Margin/VBox/FullscreenBtn
@onready var master_slider: HSlider = $Margin/VBox/MasterRow/MasterSlider
@onready var master_value: Label    = $Margin/VBox/MasterRow/MasterValue
@onready var music_slider: HSlider  = $Margin/VBox/MusicRow/MusicSlider
@onready var music_value: Label     = $Margin/VBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider    = $Margin/VBox/SfxRow/SfxSlider
@onready var sfx_value: Label       = $Margin/VBox/SfxRow/SfxValue
@onready var save_btn: Button       = $Margin/VBox/SaveBtn
@onready var back_btn: Button       = $Margin/VBox/BackBtn
@onready var main_menu_btn: Button  = $Margin/VBox/MainMenuBtn
@onready var quit_btn: Button       = $Margin/VBox/QuitBtn


func _ready() -> void:
	fullscreen_btn.pressed.connect(GameState.toggle_fullscreen)
	back_btn.pressed.connect(hide)
	main_menu_btn.pressed.connect(_on_main_menu)
	quit_btn.pressed.connect(_on_quit)
	save_btn.pressed.connect(_on_save)

	# Seed sliders from MasterAudio's current volumes so the popup reflects
	# whatever the player set last. Sliders persist via MasterAudio across
	# scene changes (autoload), not in this popup's lifecycle.
	master_slider.value = MasterAudio.get_bus_volume("Master")
	music_slider.value = MasterAudio.get_bus_volume("Music")
	sfx_slider.value = MasterAudio.get_bus_volume("SFX")
	_refresh_audio_values()

	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	# Test ping only fires when the player lets go of the SFX slider, so
	# scrubbing doesn't trigger 50 overlapping clicks.
	sfx_slider.drag_ended.connect(_on_sfx_drag_ended)

	# Save button is only useful during an active run.
	save_btn.disabled = not GameState.has_active_run()
	if save_btn.disabled:
		save_btn.tooltip_text = "No active run — start or continue a game first."
	else:
		save_btn.tooltip_text = "Write the current run to disk immediately."

	main_menu_btn.disabled = not GameState.has_active_run()
	if main_menu_btn.disabled:
		main_menu_btn.tooltip_text = "You're already on the main menu."


func _on_master_changed(v: float) -> void:
	MasterAudio.set_bus_volume("Master", v)
	_refresh_audio_values()


func _on_music_changed(v: float) -> void:
	MasterAudio.set_bus_volume("Music", v)
	_refresh_audio_values()


func _on_sfx_changed(v: float) -> void:
	MasterAudio.set_bus_volume("SFX", v)
	_refresh_audio_values()


func _on_sfx_drag_ended(_value_changed: bool) -> void:
	MasterAudio.play_click()


func _refresh_audio_values() -> void:
	master_value.text = "%d%%" % int(round(master_slider.value * 100.0))
	music_value.text = "%d%%" % int(round(music_slider.value * 100.0))
	sfx_value.text = "%d%%" % int(round(sfx_slider.value * 100.0))


func _on_save() -> void:
	if not GameState.has_active_run():
		return
	SaveManager.save_game()
	MasterAudio.play_click()
	save_btn.text = "Saved ✓"
	# Snap back to "Save Now" after a moment so the player can save again.
	var t: Tween = create_tween()
	t.tween_interval(1.4)
	t.tween_callback(func(): save_btn.text = "Save Now")


func _on_main_menu() -> void:
	if not GameState.has_active_run():
		hide()
		get_tree().change_scene_to_file("res://scenes/Main.tscn")
		return
	ConfirmDialogUtil.ask(
		self, "return_to_menu",
		"Return to the main menu?\nMid-week progress since the last Advance Time will be lost.",
		func():
			hide()
			get_tree().change_scene_to_file("res://scenes/Main.tscn"),
	)


func _on_quit() -> void:
	if not GameState.has_active_run():
		get_tree().quit()
		return
	ConfirmDialogUtil.ask(
		self, "quit_game",
		"Quit to desktop?\nMid-week progress since the last Advance Time will be lost.",
		func(): get_tree().quit(),
	)


# Esc closes the popup without firing any of the destructive paths. Hide is
# enough — popup_hide frees this instance, so the event chain ends naturally.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		hide()
		get_viewport().set_input_as_handled()


# Convenience: instance the popup, parent it to `caller`, and show it.
static func show_for(caller: Node) -> void:
	var scene: PackedScene = preload("res://scenes/ui/settings_popup.tscn")
	var instance: PopupPanel = scene.instantiate()
	caller.add_child(instance)
	instance.popup_centered()
	# Free the popup when it closes so we don't accumulate instances.
	instance.popup_hide.connect(instance.queue_free)
