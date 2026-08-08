extends CharacterBody2D
class_name ShipHull

const HULL_COLOR := Color(0.5, 0.5, 0.5)

@export var movement_config: ShipMovementConfig = preload("res://resources/ship_movement_config.tres")

@onready var polygon: Polygon2D = $Polygon2D

var angular_velocity: float = 0.0


func _ready() -> void:
	polygon.color = HULL_COLOR


func _physics_process(delta: float) -> void:
	angular_velocity -= angular_velocity * movement_config.angular_friction * delta
	rotation += angular_velocity * delta

	velocity -= velocity * movement_config.linear_friction * delta
	move_and_slide()
