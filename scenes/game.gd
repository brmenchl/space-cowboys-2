extends Node2D

const PlayerScene := preload("res://scenes/player.tscn")

@export var config: GameConfig = preload("res://resources/game_config.tres")

@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var exit_button: Button = $PauseMenu/CenterContainer/VBoxContainer/ExitButton
@onready var player1_card: PlayerHudCard = $Hud/Player1Card
@onready var player2_card: PlayerHudCard = $Hud/Player2Card
@onready var win_popup: CanvasLayer = $WinPopup
@onready var win_label: Label = $WinPopup/CenterContainer/VBoxContainer/WinLabel
@onready var win_exit_button: Button = $WinPopup/CenterContainer/VBoxContainer/ExitButton


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	win_exit_button.pressed.connect(_on_exit_pressed)
	_spawn_players()


func _unhandled_input(event: InputEvent) -> void:
	if win_popup.visible:
		if event.is_action_pressed("ui_accept"):
			_on_exit_pressed()
	elif event.is_action_pressed("ui_cancel"):
		_toggle_pause()


func _toggle_pause() -> void:
	pause_menu.visible = not pause_menu.visible
	get_tree().paused = pause_menu.visible


func _on_exit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/title.tscn")


func _spawn_players() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var player1_position: Vector2 = _random_spawn_position(screen_size)
	var player2_position: Vector2 = _random_spawn_position(screen_size)

	var attempts := 0
	while player1_position.distance_to(player2_position) < config.spawn_buffer_between_players and attempts < 100:
		player2_position = _random_spawn_position(screen_size)
		attempts += 1

	var player1 := _spawn_player(player1_position, randf_range(0.0, TAU), config.player_one_color, "p1")
	var player2 := _spawn_player(player2_position, randf_range(0.0, TAU), config.player_two_color, "p2")

	player1_card.setup(player1, "Player 1")
	player2_card.setup(player2, "Player 2")

	player1.pilot_health_changed.connect(_on_player_pilot_health_changed.bind("Player 2"))
	player2.pilot_health_changed.connect(_on_player_pilot_health_changed.bind("Player 1"))


func _on_player_pilot_health_changed(new_health: int, winner_name: String) -> void:
	if new_health == 0:
		win_label.text = winner_name.to_upper() + " WINS"
		win_popup.visible = true
		get_tree().paused = true


func _random_spawn_position(screen_size: Vector2) -> Vector2:
	var buffer: float = config.spawn_buffer_from_edges
	return Vector2(
		randf_range(buffer, screen_size.x - buffer),
		randf_range(buffer, screen_size.y - buffer)
	)


func _spawn_player(spawn_position: Vector2, angle: float, color: Color, input_prefix: String) -> Player:
	var player: Player = PlayerScene.instantiate()
	player.color = color
	player.input_prefix = input_prefix
	add_child(player)
	player.position = spawn_position
	player.rotation = angle
	return player
