extends Damageable
class_name Ship

const HULL_COLOR := Color(0.5, 0.5, 0.5)
const BulletScene := preload("res://scenes/bullet.tscn")
const CowboyScene := preload("res://scenes/cowboy.tscn")

signal cowboy_ejected(cowboy: Cowboy)

@export var ship_config: ShipConfig = preload("res://resources/ship_config_fighter.tres")
@export var eject_force: float = 120.0
@export var eject_distance: float = 40.0

var is_piloted: bool = false
var color: Color = HULL_COLOR
var input_prefix: String = ""

var _visual: Node2D
var _shoot_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("ships")
	if health <= 0:
		health = ship_config.max_health
	modulate = HULL_COLOR
	_set_visual(ship_config.visual_scene)

	mass = ship_config.mass
	inertia = mass
	gravity_scale = 0.0
	linear_damp = ship_config.movement_config.linear_friction
	angular_damp = ship_config.movement_config.angular_friction
	var physics_material := PhysicsMaterial.new()
	physics_material.bounce = ship_config.bounce
	physics_material_override = physics_material


func _physics_process(_delta: float) -> void:
	_process_turning()
	_process_thrust()
	if is_piloted:
		_process_shooting(_delta)
		_process_ejecting()


func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	state.linear_velocity = state.linear_velocity.limit_length(ship_config.movement_config.max_speed)
	state.angular_velocity = clampf(state.angular_velocity, -ship_config.movement_config.max_angular_speed, ship_config.movement_config.max_angular_speed)


func _process_turning() -> void:
	var turn_input := 0.0
	if is_piloted:
		turn_input = Input.get_action_strength(input_prefix + "_move_right") - Input.get_action_strength(input_prefix + "_move_left")
	apply_torque(turn_input * ship_config.movement_config.angular_acceleration)


func _process_thrust() -> void:
	if not is_piloted:
		return
	var thrust_input := Input.get_action_strength(input_prefix + "_move_up")
	var brake_input := Input.get_action_strength(input_prefix + "_move_down")
	var facing := Vector2.RIGHT.rotated(rotation)
	apply_central_force(facing * thrust_input * ship_config.movement_config.acceleration)
	apply_central_force(-facing * brake_input * ship_config.movement_config.deceleration)


func _process_shooting(delta: float) -> void:
	_shoot_cooldown = maxf(_shoot_cooldown - delta, 0.0)
	if _shoot_cooldown > 0.0:
		return
	if Input.is_action_pressed(input_prefix + "_action1"):
		_shoot(ship_config.bullet_config)
		_shoot_cooldown = 1.0 / ship_config.bullet_config.fire_rate


func _shoot(config: BulletConfig) -> void:
	var facing := Vector2.RIGHT.rotated(rotation)
	var bullet: Bullet = BulletScene.instantiate()
	bullet.config = config
	bullet.color = color
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + facing * config.muzzle_distance
	bullet.rotation = facing.angle() + PI / 2.0
	bullet.velocity = facing * config.speed
	bullet.shooter = self


func _process_ejecting() -> void:
	if Input.is_action_just_pressed(input_prefix + "_action2"):
		_eject()


func is_boardable() -> bool:
	return true


func possess(new_color: Color, new_input_prefix: String) -> void:
	color = new_color
	input_prefix = new_input_prefix
	is_piloted = true
	modulate = color


func _die() -> void:
	if is_piloted:
		_eject()
	queue_free()


# Launches the cowboy out to the side with a kick while the ship itself keeps
# its current position/rotation/velocity, so it's left drifting exactly where
# it was rather than being reset or replaced by a separate wreck object.
func _eject() -> void:
	var eject_direction := Vector2.RIGHT.rotated(randf_range(0.0, TAU))

	var cowboy: Cowboy = CowboyScene.instantiate()
	cowboy.color = color
	cowboy.input_prefix = input_prefix
	get_tree().current_scene.add_child(cowboy)
	cowboy.global_position = global_position + eject_direction * eject_distance
	cowboy.rotation = rotation
	cowboy.linear_velocity = eject_direction * eject_force

	is_piloted = false
	input_prefix = ""
	color = HULL_COLOR
	modulate = HULL_COLOR

	cowboy_ejected.emit(cowboy)


func _set_visual(visual_scene: PackedScene) -> void:
	if _visual:
		_visual.queue_free()
	_visual = visual_scene.instantiate()
	add_child(_visual)
