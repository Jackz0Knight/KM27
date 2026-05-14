extends PopupPanel

# Reusable Settings popup. Instantiate via SettingsPopup.show_for(caller_node).
# Any screen with a Cog button can wire it in two lines:
#
#   func _on_cog():
#       SettingsPopup.show_for(self)
#
# "Return to Main Menu" hides the popup if there's no active run (we're already
# on the Title screen). Fullscreen toggle delegates to GameState so the same
# behaviour lives in one place.

@onready var fullscreen_btn: Button = $Margin/VBox/FullscreenBtn
@onready var back_btn: Button = $Margin/VBox/BackBtn
@onready var main_menu_btn: Button = $Margin/VBox/MainMenuBtn
@onready var quit_btn: Button = $Margin/VBox/QuitBtn


func _ready() -> void:
	fullscreen_btn.pressed.connect(GameState.toggle_fullscreen)
	back_btn.pressed.connect(hide)
	main_menu_btn.pressed.connect(_on_main_menu)
	quit_btn.pressed.connect(_on_quit)


func _on_main_menu() -> void:
	hide()
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _on_quit() -> void:
	get_tree().quit()


# Convenience: instance the popup, parent it to `caller`, and show it.
static func show_for(caller: Node) -> void:
	var scene: PackedScene = preload("res://scenes/ui/settings_popup.tscn")
	var popup: PopupPanel = scene.instantiate()
	caller.add_child(popup)
	popup.popup_centered()
	# Free the popup when it closes so we don't accumulate instances.
	popup.popup_hide.connect(popup.queue_free)
