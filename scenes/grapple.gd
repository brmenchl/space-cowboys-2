extends Node2D
class_name Grapple

enum State { IDLE, EXTENDING, ATTACHED, RETRACTING }

@export var config: GrappleConfig = preload("res://resources/grapple_config.tres")

@onready var hook_area: Area2D = $HookArea
@onready var hook_collision: CollisionShape2D = $HookArea/CollisionShape2D

var state: State = State.IDLE
var attach_point: Vector2 = Vector2.ZERO
var attach_body: Node2D = null

var _shooter: Node2D
var _current_length: float = 0.0
var _time_alive: float = 0.0
var _tip_local: Vector2 = Vector2.ZERO


func _ready() -> void:
	_shooter = get_parent()
	var shape := CircleShape2D.new()
	shape.radius = config.hook_radius
	hook_collision.shape = shape
	hook_area.body_entered.connect(_on_hook_body_entered)
	visible = false


func is_engaged() -> bool:
	return state != State.IDLE


func is_pulling() -> bool:
	return state == State.ATTACHED


func handle_action_pressed() -> void:
	match state:
		State.IDLE:
			_start_extending()
		State.EXTENDING, State.ATTACHED:
			_start_retracting()
		State.RETRACTING:
			pass


func release() -> void:
	if state == State.ATTACHED:
		_start_retracting()


func reset() -> void:
	state = State.IDLE
	_current_length = 0.0
	_tip_local = Vector2.ZERO
	attach_body = null
	visible = false
	queue_redraw()


func _start_extending() -> void:
	state = State.EXTENDING
	_current_length = 0.0
	_time_alive = 0.0
	_tip_local = Vector2.ZERO
	attach_body = null
	visible = true


func _start_retracting() -> void:
	state = State.RETRACTING


func _physics_process(delta: float) -> void:
	match state:
		State.EXTENDING:
			_process_extending(delta)
		State.RETRACTING:
			_process_retracting(delta)
		State.ATTACHED:
			if attach_body and is_instance_valid(attach_body):
				attach_point = attach_body.global_position
			_tip_local = to_local(attach_point)

	if state != State.IDLE:
		hook_area.position = _tip_local
		queue_redraw()


func _process_extending(delta: float) -> void:
	_time_alive += delta
	_current_length = minf(_current_length + config.extend_speed * delta, config.extend_speed * config.time_to_live)
	_tip_local = Vector2.RIGHT * _current_length
	if _time_alive >= config.time_to_live:
		_start_retracting()


func _process_retracting(delta: float) -> void:
	_current_length = maxf(_current_length - config.retract_speed * delta, 0.0)
	_tip_local = _tip_local.normalized() * _current_length if _tip_local.length() > 0.0 else Vector2.ZERO
	if _current_length <= 0.0:
		state = State.IDLE
		visible = false
		queue_redraw()


func _on_hook_body_entered(body: Node2D) -> void:
	if state != State.EXTENDING or body == _shooter:
		return
	if _is_valid_target(body):
		attach_point = hook_area.global_position
		attach_body = body
		state = State.ATTACHED


func _is_valid_target(body: Node2D) -> bool:
	if body is ShipHull:
		return true
	if body is Player:
		return not body.is_ejected
	return false


func _draw() -> void:
	if state == State.IDLE:
		return
	draw_line(Vector2.ZERO, _tip_local, config.color, config.line_width)
	draw_circle(_tip_local, config.hook_radius, config.color)
