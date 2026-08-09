extends Damageable
class_name Pilot

const BulletScene := preload("res://scenes/bullet.tscn")

signal boarding_requested(ship: Ship)

@export var color: Color = Color.WHITE
@export var input_prefix: String = ""
@export var pilot_max_health: int = 15
@export var visual_scene: PackedScene = preload("res://scenes/visuals/pilot_visual.tscn")
@export var bullet_config: BulletConfig = preload("res://resources/pilot_bullet_config.tres")
@export var movement_config: ShipMovementConfig = preload("res://resources/pilot_movement_config.tres")
@export var recoil_force: float = 250.0
@export var lasso_config: LassoConfig = preload("res://resources/lasso_config.tres")

@onready var collision: CollisionPolygon2D = $CollisionPolygon2D
@onready var lasso: Lasso = $Lasso

var angular_velocity: float = 0.0

var _shoot_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("pilots")
	if health <= 0:
		health = pilot_max_health
	lasso.config = lasso_config
	var visual := visual_scene.instantiate()
	visual.modulate = color
	add_child(visual)


func _physics_process(delta: float) -> void:
	_process_turning(delta)
	_process_drift(delta)
	move_and_slide()
	if lasso.is_pulling():
		_process_lasso_swing()
	_process_shooting(delta)
	_process_lasso()


func _process_turning(delta: float) -> void:
	var turn_input := Input.get_action_strength(input_prefix + "_move_right") - Input.get_action_strength(input_prefix + "_move_left")
	angular_velocity += turn_input * movement_config.angular_acceleration * delta
	angular_velocity -= angular_velocity * movement_config.angular_friction * delta
	angular_velocity = clampf(angular_velocity, -movement_config.max_angular_speed, movement_config.max_angular_speed)
	rotation += angular_velocity * delta


func _process_drift(delta: float) -> void:
	velocity -= velocity * movement_config.linear_friction * delta


# Keeps the pilot on a taut, shrinking rope: any velocity component pulling
# away from the attach point is cancelled, but the tangential component
# survives, so residual sideways drift turns into a swing around the target
# as the rope reels in rather than a straight-line teleport toward it.
func _process_lasso_swing() -> void:
	var offset := global_position - lasso.attach_point
	var distance := offset.length()
	var rope_length := lasso.rope_length()

	if distance > rope_length and distance > 0.0:
		var radial := offset / distance
		global_position = lasso.attach_point + radial * rope_length
		velocity -= radial * velocity.dot(radial)
		distance = rope_length

	if distance <= lasso_config.arrival_distance:
		var target := lasso.attach_body
		if target is Ship and target.is_boardable():
			boarding_requested.emit(target)
		lasso.reset()


func _process_shooting(delta: float) -> void:
	_shoot_cooldown = maxf(_shoot_cooldown - delta, 0.0)
	if lasso.is_engaged():
		return
	if _shoot_cooldown > 0.0:
		return
	if Input.is_action_pressed(input_prefix + "_action1"):
		_shoot()
		_shoot_cooldown = 1.0 / bullet_config.fire_rate


func _process_lasso() -> void:
	if Input.is_action_just_pressed(input_prefix + "_action2"):
		lasso.handle_action_pressed()


func _shoot() -> void:
	var facing := Vector2.RIGHT.rotated(rotation)
	var bullet: Bullet = BulletScene.instantiate()
	bullet.config = bullet_config
	get_tree().current_scene.add_child(bullet)
	bullet.global_position = global_position + facing * bullet_config.muzzle_distance
	bullet.velocity = facing * bullet_config.speed
	bullet.shooter = self
	velocity -= facing * recoil_force


func _die() -> void:
	pass
