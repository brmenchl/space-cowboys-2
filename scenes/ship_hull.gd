extends Damageable
class_name ShipHull

const HULL_COLOR := Color(0.5, 0.5, 0.5)

@export var ship_config: ShipConfig = preload("res://resources/ship_config_fighter.tres")

@onready var collision_shape: CollisionPolygon2D = $CollisionPolygon2D

var angular_velocity: float = 0.0


func _ready() -> void:
	add_to_group("ship_hulls")
	modulate = HULL_COLOR
	collision_shape.polygon = ship_config.collision_polygon
	add_child(ship_config.visual_scene.instantiate())
	if health <= 0:
		health = ship_config.max_health


func _physics_process(delta: float) -> void:
	angular_velocity -= angular_velocity * ship_config.movement_config.angular_friction * delta
	rotation += angular_velocity * delta

	velocity -= velocity * ship_config.movement_config.linear_friction * delta
	move_and_slide()


func is_boardable() -> bool:
	return true
