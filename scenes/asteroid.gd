extends Damageable
class_name Asteroid

@export var config: AsteroidConfig = preload("res://resources/asteroid_config.tres")
@export var visual_scene: PackedScene = preload("res://scenes/visuals/asteroid_visual.tscn")

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("asteroids")
	health = config.max_health

	var radius := randf_range(config.min_radius, config.max_radius)

	var shape := CircleShape2D.new()
	shape.radius = radius
	collision_shape.shape = shape

	var visual: Sprite2D = visual_scene.instantiate()
	visual.modulate = config.colors.pick_random()
	visual.scale = Vector2.ONE * radius / (visual.texture.get_size().x / 2.0)
	add_child(visual)

	var direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))
	velocity = direction * randf_range(0.0, config.max_speed)


func _physics_process(delta: float) -> void:
	position += velocity * delta
