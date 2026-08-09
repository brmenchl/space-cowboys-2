extends Node2D
class_name Bullet

@export var config: BulletConfig = preload("res://resources/bullet_config.tres")

@onready var area: Area2D = $Area2D
@onready var collision_shape: CollisionShape2D = $Area2D/CollisionShape2D

var velocity: Vector2 = Vector2.ZERO
var shooter: Node2D = null
var color: Color = Color.WHITE

var _time_alive: float = 0.0


func _ready() -> void:
	var visual := config.visual_scene.instantiate()
	visual.modulate = color
	add_child(visual)

	var shape := CircleShape2D.new()
	shape.radius = config.radius
	collision_shape.shape = shape

	area.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_time_alive += delta
	if _time_alive >= config.time_to_live:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if body == shooter:
		return
	if body is Damageable:
		body.take_damage(config.damage)
		queue_free()
