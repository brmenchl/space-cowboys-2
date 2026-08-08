extends CharacterBody2D
class_name Player

const BulletScene := preload("res://scenes/bullet.tscn")

# Distance from the ship's center to its front tip, matching the Polygon2D/
# CollisionPolygon2D shape below; bullets spawn this far out plus the
# configurable muzzle_offset.
const TIP_LENGTH := 24.0

signal health_changed(new_health: int)

const MAX_HEALTH := 100

@export var color: Color = Color.WHITE
@export var input_prefix: String = "p1"
@export var movement_config: ShipMovementConfig = preload("res://resources/ship_movement_config.tres")

@onready var polygon: Polygon2D = $Polygon2D

var angular_velocity: float = 0.0
var health: int = MAX_HEALTH


func _ready() -> void:
	polygon.color = color


func _physics_process(delta: float) -> void:
	_process_turning(delta)
	_process_thrust(delta)
	move_and_slide()
	_process_shooting()


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
	if Input.is_action_just_pressed(input_prefix + "_action1"):
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
