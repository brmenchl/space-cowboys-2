extends Control

@onready var back_button: Button = $BackButton
@onready var player1_label: Label = $Player1Card/MarginContainer/Label
@onready var player2_label: Label = $Player2Card/MarginContainer/Label
@onready var start_button: Button = $StartButton

var player1_ready := false
var player2_ready := false


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	start_button.pressed.connect(_on_start_pressed)
	_update_labels()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()
	elif event.is_action_pressed("p1_action1") and not player1_ready:
		player1_ready = true
		_update_labels()
	elif event.is_action_pressed("p2_action1") and not player2_ready:
		player2_ready = true
		_update_labels()


func _update_labels() -> void:
	player1_label.text = "Ready!" if player1_ready else "Press F to join!"
	player2_label.text = "Ready!" if player2_ready else "Press / to join!"
	start_button.visible = int(player1_ready) + int(player2_ready) >= 2


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")
