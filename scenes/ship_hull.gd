extends CharacterBody2D
class_name ShipHull

const HULL_COLOR := Color(0.5, 0.5, 0.5)

@export var movement_config: ShipMovementConfig = preload("res://resources/ship_movement_config.tres")
@export var health_config: HealthConfig = preload("res://resources/health_config.tres")
@export var visual_scene: PackedScene = preload("res://scenes/visuals/ship_visual.tscn")

var angular_velocity: float = 0.0
var health: int = 0


func _ready() -> void:
	add_to_group("ship_hulls")
	modulate = HULL_COLOR
	add_child(visual_scene.instantiate())
	if health <= 0:
		health = health_config.ship_max_health


func _physics_process(delta: float) -> void:
	angular_velocity -= angular_velocity * movement_config.angular_friction * delta
	rotation += angular_velocity * delta

	velocity -= velocity * movement_config.linear_friction * delta
	move_and_slide()


func take_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	if health == 0:
		queue_free()


func is_boardable() -> bool:
	return true
