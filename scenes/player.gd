extends CharacterBody2D
class_name Player

const BulletScene := preload("res://scenes/bullet.tscn")
const ShipHullScene := preload("res://scenes/ship_hull.tscn")

# Distance from the ship's center to its front tip, matching the Polygon2D/
# CollisionPolygon2D shape below; bullets spawn this far out plus the
# configurable muzzle_offset.
const TIP_LENGTH := 24.0

# Size and corner rounding of the pilot's polygon, used once ejected in
# place of the ship's Polygon2D/CollisionPolygon2D shape.
const PILOT_SIZE := Vector2(14.0, 10.0)
const PILOT_CORNER_RADIUS := 3.0
const PILOT_CORNER_SEGMENTS := 4

signal health_changed(new_health: int)

const MAX_HEALTH := 100

@export var color: Color = Color.WHITE
@export var input_prefix: String = "p1"
@export var movement_config: ShipMovementConfig = preload("res://resources/ship_movement_config.tres")

@onready var polygon: Polygon2D = $Polygon2D
@onready var collision_polygon: CollisionPolygon2D = $CollisionPolygon2D

var angular_velocity: float = 0.0
var health: int = MAX_HEALTH
var is_ejected: bool = false


func _ready() -> void:
	polygon.color = color


func _physics_process(delta: float) -> void:
	_process_turning(delta)
	if not is_ejected:
		_process_thrust(delta)
	move_and_slide()
	_process_shooting()
	_process_ejecting()


func _process_turning(delta: float) -> void:
	var turn_input := Input.get_action_strength(input_prefix + "_move_right") - Input.get_action_strength(input_prefix + "_move_left")
	angular_velocity += turn_input * movement_config.angular_acceleration * delta
	angular_velocity -= angular_velocity * movement_config.angular_friction * delta
	angular_velocity = clampf(angular_velocity, -movement_config.max_angular_speed, movement_config.max_angular_speed)
	rotation += angular_velocity * delta


func _process_thrust(delta: float) -> void:
	var thrust_input := Input.get_action_strength(input_prefix + "_move_up")
	var brake_input := Input.get_action_strength(input_prefix + "_move_down")
	var facing := Vector2.RIGHT.rotated(rotation)

	velocity += facing * thrust_input * movement_config.acceleration * delta
	velocity -= facing * brake_input * movement_config.deceleration * delta
	velocity -= velocity * movement_config.linear_friction * delta
	velocity = velocity.limit_length(movement_config.max_speed)


func _process_shooting() -> void:
	if not is_ejected and Input.is_action_just_pressed(input_prefix + "_action1"):
		_shoot()


func _shoot() -> void:
	var bullet: Bullet = BulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)

	var facing := Vector2.RIGHT.rotated(rotation)
	bullet.global_position = global_position + facing * (TIP_LENGTH + bullet.config.muzzle_offset)
	bullet.velocity = facing * bullet.config.speed
	bullet.shooter = self


func take_damage(amount: int) -> void:
	health = maxi(health - amount, 0)
	health_changed.emit(health)


func _process_ejecting() -> void:
	if not is_ejected and Input.is_action_just_pressed(input_prefix + "_action2"):
		_eject()


func _eject() -> void:
	is_ejected = true

	var hull: ShipHull = ShipHullScene.instantiate()
	get_tree().current_scene.add_child(hull)
	hull.global_position = global_position
	hull.rotation = rotation
	hull.velocity = velocity
	hull.angular_velocity = angular_velocity
	hull.movement_config = movement_config

	velocity = Vector2.ZERO
	angular_velocity = 0.0

	var pilot_points := _build_rounded_rect_points(PILOT_SIZE, PILOT_CORNER_RADIUS, PILOT_CORNER_SEGMENTS)
	polygon.polygon = pilot_points
	collision_polygon.polygon = pilot_points


func _build_rounded_rect_points(size: Vector2, corner_radius: float, corner_segments: int) -> PackedVector2Array:
	var half := size / 2.0
	var corner_centers := [
		Vector2(half.x - corner_radius, -half.y + corner_radius),
		Vector2(half.x - corner_radius, half.y - corner_radius),
		Vector2(-half.x + corner_radius, half.y - corner_radius),
		Vector2(-half.x + corner_radius, -half.y + corner_radius),
	]
	var start_angles := [-PI / 2.0, 0.0, PI / 2.0, PI]

	var points := PackedVector2Array()
	for i in range(corner_centers.size()):
		var center: Vector2 = corner_centers[i]
		var start_angle: float = start_angles[i]
		for j in range(corner_segments + 1):
			var angle: float = start_angle + (PI / 2.0) * (j / float(corner_segments))
			points.append(center + Vector2(cos(angle), sin(angle)) * corner_radius)
	return points
