extends Resource
class_name GameConfig

@export var spawn_buffer_between_entities: float = 200.0
@export var spawn_buffer_from_edges: float = 80.0
@export var player_one_color: Color = Color(0.2, 0.4, 1.0)
@export var player_two_color: Color = Color(1.0, 0.2, 0.2)

@export var max_ships: int = 4
@export var min_ship_spawn_interval: float = 30.0
@export var max_ship_spawn_interval: float = 90.0

@export var max_asteroids: int = 2
@export var min_asteroid_spawn_interval: float = 30.0
@export var max_asteroid_spawn_interval: float = 90.0
