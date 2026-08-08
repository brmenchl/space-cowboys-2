extends Node2D
class_name Bullet

const CIRCLE_SEGMENTS := 16

@export var config: BulletConfig = preload("res://resources/bullet_config.tres")

@onready var polygon: Polygon2D = $Polygon2D

var velocity: Vector2 = Vector2.ZERO

var _time_alive: float = 0.0


func _ready() -> void:
	polygon.polygon = _build_circle_points(config.radius)
	polygon.color = config.color


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_time_alive += delta
	if _time_alive >= config.time_to_live:
		queue_free()


func _build_circle_points(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(CIRCLE_SEGMENTS):
		var angle := TAU * i / CIRCLE_SEGMENTS
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	return points
