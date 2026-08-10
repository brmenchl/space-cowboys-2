extends Node
class_name Spawner

const ShipScene := preload("res://scenes/ship.tscn")
const AsteroidScene := preload("res://scenes/asteroid.tscn")

@export var config: GameConfig = preload("res://resources/game_config.tres")
@export var ship_configs: Array[ShipConfig] = [
	preload("res://resources/ship_config_fighter.tres"),
	preload("res://resources/ship_config_bruiser.tres"),
]

var _ship_spawn_timer: Timer
var _asteroid_spawn_timer: Timer


func _ready() -> void:
	_ship_spawn_timer = _create_spawn_timer(_on_ship_spawn_timer_timeout)
	_asteroid_spawn_timer = _create_spawn_timer(_on_asteroid_spawn_timer_timeout)
	_restart_spawn_timer(_ship_spawn_timer, config.min_ship_spawn_interval, config.max_ship_spawn_interval)
	_restart_spawn_timer(_asteroid_spawn_timer, config.min_asteroid_spawn_interval, config.max_asteroid_spawn_interval)
	_spawn_asteroid()


func spawn_player(color: Color, input_prefix: String) -> PlayerController:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var ship: Ship = ShipScene.instantiate()
	add_child(ship)
	ship.global_position = _find_spawn_position(screen_size, _all_entity_positions())
	ship.rotation = randf_range(0.0, TAU)

	var controller := PlayerController.new()
	controller.color = color
	controller.input_prefix = input_prefix
	add_child(controller)
	controller.possess_ship(ship)
	return controller


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
	return get_tree().get_nodes_in_group("ships").size()


func _all_entity_positions() -> Array:
	var positions: Array = []
	for group in ["ships", "cowboys", "asteroids"]:
		for entity in get_tree().get_nodes_in_group(group):
			positions.append(entity.global_position)
	return positions


func _spawn_ship() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var ship: Ship = ShipScene.instantiate()
	ship.ship_config = _pick_ship_config()
	add_child(ship)
	ship.global_position = _find_spawn_position(screen_size, _all_entity_positions())
	ship.rotation = randf_range(0.0, TAU)


func _pick_ship_config() -> ShipConfig:
	var total_weight := 0.0
	for ship_config in ship_configs:
		total_weight += ship_config.spawn_weight

	var roll := randf_range(0.0, total_weight)
	var cumulative_weight := 0.0
	for ship_config in ship_configs:
		cumulative_weight += ship_config.spawn_weight
		if roll <= cumulative_weight:
			return ship_config
	return ship_configs[-1]


func _spawn_asteroid() -> void:
	var screen_size: Vector2 = get_viewport().get_visible_rect().size
	var asteroid: Asteroid = AsteroidScene.instantiate()
	add_child(asteroid)
	asteroid.global_position = _find_spawn_position(screen_size, _all_entity_positions())


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
