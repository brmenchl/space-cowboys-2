extends Control

@onready var play_button: Button = $CenterContainer/VBoxContainer/PlayButton


func _ready() -> void:
	play_button.pressed.connect(_on_play_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		_on_play_pressed()


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/waiting_room.tscn")
