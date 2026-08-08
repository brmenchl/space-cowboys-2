extends Node2D
class_name Bullet

@export var config: BulletConfig = preload("res://resources/bullet_config.tres")

var velocity: Vector2 = Vector2.ZERO

var _time_alive: float = 0.0


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_time_alive += delta
	if _time_alive >= config.time_to_live:
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, config.radius, config.color)
