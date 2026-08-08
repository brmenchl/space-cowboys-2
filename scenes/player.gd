extends CharacterBody2D
class_name Player

const BulletScene := preload("res://scenes/bullet.tscn")
const ShipHullScene := preload("res://scenes/ship_hull.tscn")

signal ship_health_changed(new_health: int)
signal pilot_health_changed(new_health: int)
signal ejected
signal boarded
signal visual_changed(visual_scene: PackedScene)

@export var color: Color = Color.WHITE
@export var input_prefix: String = "p1"
@export var movement_config: ShipMovementConfig = preload("res://resources/ship_movement_config.tres")
@export var health_config: HealthConfig = preload("res://resources/health_config.tres")
@export var ship_visual_scene: PackedScene = preload("res://scenes/visuals/ship_visual.tscn")
@export var pilot_visual_scene: PackedScene = preload("res://scenes/visuals/pilot_visual.tscn")
@export var ship_bullet_config: BulletConfig = preload("res://resources/bullet_config.tres")
@export var pilot_bullet_config: BulletConfig = preload("res://resources/pilot_bullet_config.tres")
@export var pilot_recoil_force: float = 250.0
@export var grapple_config: GrappleConfig = preload("res://resources/grapple_config.tres")
@export var eject_force: float = 120.0

@onready var ship_collision: CollisionPolygon2D = $ShipCollision
@onready var pilot_collision: CollisionPolygon2D = $PilotCollision
@onready var grapple: Grapple = $Grapple

var angular_velocity: float = 0.0
var ship_health: int
var pilot_health: int
var is_ejected: bool = false
var active_visual_scene: PackedScene

var _visual: Node2D
var _shoot_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("players")
	ship_health = health_config.ship_max_health
	pilot_health = health_config.pilot_max_health
	modulate = color
	pilot_collision.disabled = true
	grapple.config = grapple_config
	_set_visual(ship_visual_scene)


func _physics_process(delta: float) -> void:
	_process_turning(delta)
	if is_ejected:
		_process_pilot_drift(delta)
	else:
		_process_thrust(delta)
	move_and_slide()
	_process_shooting(delta)
	_process_grapple()
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


func _process_pilot_drift(delta: float) -> void:
	if grapple.is_pulling():
		velocity = global_position.direction_to(grapple.attach_point) * grapple_config.pull_speed
		if global_position.distance_to(grapple.attach_point) <= grapple_config.arrival_distance:
			_board_ship(grapple.attach_body)
			grapple.reset()
	else:
		velocity -= velocity * movement_config.linear_friction * delta


func _process_shooting(delta: float) -> void:
	_shoot_cooldown = maxf(_shoot_cooldown - delta, 0.0)

	if is_ejected and grapple.is_engaged():
		return
	if _shoot_cooldown > 0.0:
		return
	if Input.is_action_pressed(input_prefix + "_action1"):
		var config: BulletConfig = pilot_bullet_config if is_ejected else ship_bullet_config
		_shoot(config)
		_shoot_cooldown = 1.0 / config.fire_rate


func _process_grapple() -> void:
	if is_ejected and Input.is_action_just_pressed(input_prefix + "_action2"):
		grapple.handle_action_pressed()


func _shoot(config: BulletConfig) -> void:
	var facing := Vector2.RIGHT.rotated(rotation)

	var bullet: Bullet = BulletScene.instantiate()
	bullet.config = config
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + facing * config.muzzle_distance
	bullet.velocity = facing * config.speed
	bullet.shooter = self

	if is_ejected:
		velocity -= facing * pilot_recoil_force


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


# Ejects a still-flying enemy so their ship can be boarded, returning the
# drifting hull left behind. No-op (returns null) if already ejected.
func force_eject() -> ShipHull:
	if is_ejected:
		return null
	var hull := _spawn_drifting_hull()
	_become_pilot()
	return hull


func _board_ship(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return

	var hull: ShipHull = target.force_eject() if target is Player else target
	if hull == null or not is_instance_valid(hull):
		return

	global_position = hull.global_position
	rotation = hull.rotation
	velocity = hull.velocity
	angular_velocity = hull.angular_velocity
	ship_health = hull.health
	hull.queue_free()

	is_ejected = false
	ship_collision.disabled = false
	pilot_collision.disabled = true
	_set_visual(ship_visual_scene)
	ship_health_changed.emit(ship_health)
	boarded.emit()


func _become_pilot() -> void:
	is_ejected = true
	velocity = Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * eject_force
	angular_velocity = 0.0

	ship_collision.disabled = true
	pilot_collision.disabled = false
	_set_visual(pilot_visual_scene)

	ejected.emit()


func _spawn_drifting_hull() -> ShipHull:
	var hull: ShipHull = ShipHullScene.instantiate()
	get_tree().current_scene.add_child(hull)
	hull.global_position = global_position
	hull.rotation = rotation
	hull.velocity = velocity
	hull.angular_velocity = angular_velocity
	hull.movement_config = movement_config
	hull.health = ship_health
	return hull


func _set_visual(visual_scene: PackedScene) -> void:
	if _visual:
		_visual.queue_free()
	_visual = visual_scene.instantiate()
	add_child(_visual)
	active_visual_scene = visual_scene
	visual_changed.emit(visual_scene)
