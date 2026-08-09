extends Node2D
class_name Grapple

enum State { IDLE, EXTENDING, ATTACHED, RETRACTING }

@export var config: GrappleConfig = preload("res://resources/grapple_config.tres")
@export var link_visual_scene: PackedScene = preload("res://scenes/visuals/grapple_link_visual.tscn")

@onready var hook_area: Area2D = $HookArea
@onready var hook_collision: CollisionShape2D = $HookArea/CollisionShape2D

var state: State = State.IDLE
var attach_point: Vector2 = Vector2.ZERO
var attach_body: Node2D = null

var _shooter: Node2D
var _current_length: float = 0.0
var _time_alive: float = 0.0
var _tip_local: Vector2 = Vector2.ZERO
var _links: Array[Node2D] = []
var _rope_length: float = 0.0


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


func rope_length() -> float:
	return _rope_length


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
	_rope_length = 0.0
	visible = false
	_clear_links()
	queue_redraw()


func _start_extending() -> void:
	state = State.EXTENDING
	_current_length = 0.0
	_time_alive = 0.0
	_tip_local = Vector2.ZERO
	attach_body = null
	_rope_length = 0.0
	visible = true
	_clear_links()


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
			_rope_length = maxf(_rope_length - config.pull_speed * delta, 0.0)
			_tip_local = to_local(attach_point)
			_current_length = _tip_local.length()

	if state != State.IDLE:
		hook_area.position = _tip_local
		_update_links()
		queue_redraw()

	if state == State.EXTENDING or state == State.ATTACHED:
		_check_rope_intersection()

	if state != State.IDLE and _is_tip_off_map():
		reset()


func _process_extending(delta: float) -> void:
	_time_alive += delta
	_current_length = minf(_current_length + config.extend_speed * delta, config.extend_speed * config.time_to_live)
	_tip_local = Vector2.RIGHT * _current_length
	if _time_alive >= config.time_to_live:
		_start_retracting()


func _is_tip_off_map() -> bool:
	var map_size := get_viewport().get_visible_rect().size
	var tip_global := to_global(_tip_local)
	return tip_global.x < 0.0 or tip_global.x > map_size.x or tip_global.y < 0.0 or tip_global.y > map_size.y


func _process_retracting(delta: float) -> void:
	_current_length = maxf(_current_length - config.retract_speed * delta, 0.0)
	_tip_local = _tip_local.normalized() * _current_length if _tip_local.length() > 0.0 else Vector2.ZERO
	if _current_length <= 0.0:
		state = State.IDLE
		visible = false
		_clear_links()
		queue_redraw()


# Attachment is decided by the near-tip circle check below, not here - this
# ray only asks whether the rope's own length, shooter to tip, has snagged
# on something along the way, so any hit at all (valid target or not) is a
# mid-rope obstruction and resets the grapple.
func _check_rope_intersection() -> void:
	if state == State.EXTENDING and _try_attach_near_tip():
		return

	var space_state := get_world_2d().direct_space_state
	var tip_global := to_global(_tip_local)
	var exclude: Array[RID] = [_shooter.get_rid()]
	if attach_body and is_instance_valid(attach_body):
		exclude.append(attach_body.get_rid())
	var query := PhysicsRayQueryParameters2D.create(global_position, tip_global)
	query.exclude = exclude

	if not space_state.intersect_ray(query).is_empty():
		reset()


func _try_attach_near_tip() -> bool:
	var tip_global := to_global(_tip_local)
	var space_state := get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hook_collision.shape
	query.transform = Transform2D(0.0, tip_global)
	query.exclude = [_shooter.get_rid()]
	query.collide_with_bodies = true
	query.collide_with_areas = false

	for overlap in space_state.intersect_shape(query):
		var body: Node2D = overlap.collider
		if _is_valid_target(body):
			_attach(body, tip_global)
			return true
	return false


func _on_hook_body_entered(body: Node2D) -> void:
	if state != State.EXTENDING or body == _shooter:
		return
	if _is_valid_target(body):
		_attach(body, hook_area.global_position)


func _attach(body: Node2D, point: Vector2) -> void:
	attach_point = point
	attach_body = body
	_rope_length = _current_length
	state = State.ATTACHED


func _is_valid_target(body: Node2D) -> bool:
	return body is Damageable


# Links spawn and grow out from the pilot as the rope extends, one segment
# per link_spacing of current length, rather than a single stretched line.
func _update_links() -> void:
	var link_count := int(_current_length / config.link_spacing)
	while _links.size() < link_count:
		var link: Node2D = link_visual_scene.instantiate()
		link.modulate = config.color
		add_child(link)
		_links.append(link)
	while _links.size() > link_count:
		_links.pop_back().queue_free()

	var direction := _tip_local.normalized() if _tip_local.length() > 0.0 else Vector2.RIGHT
	for i in range(_links.size()):
		var link: Node2D = _links[i]
		link.position = direction * config.link_spacing * i
		link.rotation = direction.angle()
		link.scale = Vector2(config.link_spacing, config.line_width)


func _clear_links() -> void:
	for link in _links:
		link.queue_free()
	_links.clear()


func _draw() -> void:
	if state == State.IDLE:
		return
	draw_circle(_tip_local, config.hook_radius, config.color)
