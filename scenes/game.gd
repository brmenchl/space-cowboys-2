extends Node2D

@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var exit_button: Button = $PauseMenu/CenterContainer/VBoxContainer/ExitButton


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	get_tree().paused = pause_menu.visible


func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")
