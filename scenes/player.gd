extends CharacterBody2D
class_name Player

const BulletScene := preload("res://scenes/bullet.tscn")
const ShipHullScene := preload("res://scenes/ship_hull.tscn")

# Distance from the ship's center to its front tip; bullets spawn this far
# out plus the configurable muzzle_offset. Independent of whatever visual
# asset is currently assigned to ship_visual_scene.
const TIP_LENGTH := 24.0

signal ship_health_changed(new_health: int)
signal pilot_health_changed(new_health: int)
signal ejected
signal visual_changed(visual_scene: PackedScene)

@export var color: Color = Color.WHITE
@export var input_prefix: String = "p1"
@export var movement_config: ShipMovementConfig = preload("res://resources/ship_movement_config.tres")
@export var health_config: HealthConfig = preload("res://resources/health_config.tres")
@export var ship_visual_scene: PackedScene = preload("res://scenes/visuals/ship_visual.tscn")
@export var pilot_visual_scene: PackedScene = preload("res://scenes/visuals/pilot_visual.tscn")

@onready var ship_collision: CollisionPolygon2D = $ShipCollision
@onready var pilot_collision: CollisionPolygon2D = $PilotCollision

var angular_velocity: float = 0.0
var ship_health: int
var pilot_health: int
var is_ejected: bool = false
var active_visual_scene: PackedScene

var _visual: Node2D


func _ready() -> void:
	ship_health = health_config.ship_max_health
	pilot_health = health_config.pilot_max_health
	modulate = color
	pilot_collision.disabled = true
	_set_visual(ship_visual_scene)


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
	if is_ejected:
		pilot_health = maxi(pilot_health - amount, 0)
		pilot_health_changed.emit(pilot_health)
	else:
		ship_health = maxi(ship_health - amount, 0)
		ship_health_changed.emit(ship_health)
		if ship_health == 0:
			_eject_destroyed()


func _process_ejecting() -> void:
	if not is_ejected and Input.is_action_just_pressed(input_prefix + "_action2"):
		_eject()


func _eject() -> void:
	_spawn_drifting_hull()
	_become_pilot()


func _eject_destroyed() -> void:
	_become_pilot()


func _become_pilot() -> void:
	is_ejected = true
	velocity = Vector2.ZERO
	angular_velocity = 0.0

	ship_collision.disabled = true
	pilot_collision.disabled = false
	_set_visual(pilot_visual_scene)

	ejected.emit()


func _spawn_drifting_hull() -> void:
	var hull: ShipHull = ShipHullScene.instantiate()
	get_tree().current_scene.add_child(hull)
	hull.global_position = global_position
	hull.rotation = rotation
	hull.velocity = velocity
	hull.angular_velocity = angular_velocity
	hull.movement_config = movement_config


func _set_visual(visual_scene: PackedScene) -> void:
	if _visual:
		_visual.queue_free()
	_visual = visual_scene.instantiate()
	add_child(_visual)
	active_visual_scene = visual_scene
	visual_changed.emit(visual_scene)
