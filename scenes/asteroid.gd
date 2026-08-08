extends RigidBody2D
class_name Asteroid

@export var config: AsteroidConfig = preload("res://resources/asteroid_config.tres")
@export var visual_scene: PackedScene = preload("res://scenes/visuals/asteroid_visual.tscn")

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var health: int


func _ready() -> void:
	add_to_group("asteroids")
	gravity_scale = 0.0
	health = config.max_health

	var shape := CircleShape2D.new()
	shape.radius = config.radius
	collision_shape.shape = shape

	var visual := visual_scene.instantiate()
	visual.modulate = config.color
	visual.scale = Vector2.ONE * config.radius
	add_child(visual)

	var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	linear_velocity = direction * randf_range(0.0, config.max_speed)


func take_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	if health == 0:
		queue_free()


func is_boardable() -> bool:
	return false
