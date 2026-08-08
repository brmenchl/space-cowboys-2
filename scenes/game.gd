extends Node2D

const PlayerScene := preload("res://scenes/player.tscn")
const ShipHullScene := preload("res://scenes/ship_hull.tscn")
const AsteroidScene := preload("res://scenes/asteroid.tscn")

@export var config: GameConfig = preload("res://resources/game_config.tres")
@export var ship_movement_config: ShipMovementConfig = preload("res://resources/ship_movement_config.tres")

@onready var pause_menu: CanvasLayer = $PauseMenu
@onready var exit_button: Button = $PauseMenu/CenterContainer/VBoxContainer/ExitButton
@onready var player1_card: PlayerHudCard = $Hud/Player1Card
@onready var player2_card: PlayerHudCard = $Hud/Player2Card
@onready var win_popup: CanvasLayer = $WinPopup
@onready var win_label: Label = $WinPopup/CenterContainer/VBoxContainer/WinLabel
@onready var win_exit_button: Button = $WinPopup/CenterContainer/VBoxContainer/ExitButton

var _ship_spawn_timer: Timer
var _asteroid_spawn_timer: Timer


func _ready() -> void:
	exit_button.pressed.connect(_on_exit_pressed)
	win_exit_button.pressed.connect(_on_exit_pressed)
	_spawn_players()
	_ship_spawn_timer = _create_spawn_timer(_on_ship_spawn_timer_timeout)
	_asteroid_spawn_timer = _create_spawn_timer(_on_asteroid_spawn_timer_timeout)
	_restart_spawn_timer(_ship_spawn_timer, config.min_ship_spawn_interval, config.max_ship_spawn_interval)
	_restart_spawn_timer(_asteroid_spawn_timer, config.min_asteroid_spawn_interval, config.max_asteroid_spawn_interval)


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
	var player1_position: Vector2 = _find_spawn_position(screen_size, [])
	var player2_position: Vector2 = _find_spawn_position(screen_size, [player1_position])

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


func _find_spawn_position(screen_size: Vector2, existing_positions: Array) -> Vector2:
	var spawn_position := _random_spawn_position(screen_size)
	var attempts := 0
	while _is_too_close(spawn_position, existing_positions) and attempts < 100:
		spawn_position = _random_spawn_position(screen_size)
		attempts += 1
	return spawn_position


func _is_too_close(spawn_position: Vector2, existing_positions: Array) -> bool:
	for other_position in existing_positions:
		if spawn_position.distance_to(other_position) < config.spawn_buffer_between_entities:
			return true
	return false


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


func _create_spawn_timer(on_timeout: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(on_timeout)
	add_child(timer)
	return timer


func _restart_spawn_timer(timer: Timer, min_interval: float, max_interval: float) -> void:
	timer.start(randf_range(min_interval, max_interval))


func _on_ship_spawn_timer_timeout() -> void:
	if _count_ships() < config.max_ships:
		_spawn_ship()
	_restart_spawn_timer(_ship_spawn_timer, config.min_ship_spawn_interval, config.max_ship_spawn_interval)


func _on_asteroid_spawn_timer_timeout() -> void:
	if get_tree().get_nodes_in_group("asteroids").size() < config.max_asteroids:
		_spawn_asteroid()
	_restart_spawn_timer(_asteroid_spawn_timer, config.min_asteroid_spawn_interval, config.max_asteroid_spawn_interval)


func _count_ships() -> int:
	var count := get_tree().get_nodes_in_group("ship_hulls").size()
	for player in get_tree().get_nodes_in_group("players"):
		if not player.is_ejected:
			count += 1
	return count


func _all_entity_positions() -> Array:
	var positions: Array = []
	for group in ["players", "ship_hulls", "asteroids"]:
		for entity in get_tree().get_nodes_in_group(group):
			positions.append(entity.global_position)
	return positions


func _spawn_ship() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var hull: ShipHull = ShipHullScene.instantiate()
	hull.movement_config = ship_movement_config
	add_child(hull)
	hull.global_position = _find_spawn_position(screen_size, _all_entity_positions())
	hull.rotation = randf_range(0.0, TAU)


func _spawn_asteroid() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var asteroid: Asteroid = AsteroidScene.instantiate()
	add_child(asteroid)
	asteroid.global_position = _find_spawn_position(screen_size, _all_entity_positions())
