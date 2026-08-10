extends Resource
class_name AsteroidConfig

@export var max_health: int = 30
@export var min_radius: float = 20.0
@export var max_radius: float = 40.0
@export var max_speed: float = 150.0
@export var mass_per_radius_squared: float = 0.0125
@export var angular_damp: float = 1.0
@export var bounce: float = 0.2
@export var colors: Array[Color] = [
	Color(0.5, 0.2, 0.7), # purple
	Color(0.7, 0.6, 0.9), # lavender
	Color(0.2, 0.6, 0.6), # teal
	Color(0.3, 0.4, 0.8), # blue
]
