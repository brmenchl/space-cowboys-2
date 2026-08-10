@tool
class_name Wrap2D
extends Node

@export var target: Node2D:
	set(new_target):
		target = new_target
		update_configuration_warnings()

@export var wrap_horizontally: bool = true
@export var wrap_vertically: bool = false
@export var margin: float = 32.0

var screen_size: Vector2

var _shadow_dirs: Array[Vector2i] = []
var _shadows: Array[Node2D] = []


func _ready() -> void:
	if target == null:
		target = get_parent()
	_update_screen_size()
	get_viewport().size_changed.connect(_update_screen_size)
	if not Engine.is_editor_hint():
		call_deferred("_create_shadows")
		target.child_entered_tree.connect(_on_target_child_entered_tree)
		target.child_exiting_tree.connect(_on_target_child_exiting_tree)


func _exit_tree() -> void:
	for shadow in _shadows:
		if is_instance_valid(shadow):
			shadow.queue_free()


func _get_configuration_warnings() -> PackedStringArray:
	if not target or not target is Node2D:
		return ["No valid target set for the Wrap2D Component!"]
	else:
		return []


func _physics_process(_delta: float) -> void:
	if not target or Engine.is_editor_hint():
		return

	if target is RigidBody2D:
		_wrap_rigidbody(target)
	else:
		target.global_position = _calculate_wrap(target.global_position)

	_update_shadows()


func _update_screen_size() -> void:
	screen_size = get_viewport().get_visible_rect().size


func _calculate_wrap(pos: Vector2) -> Vector2:
	# Trigger the jump once the target is `margin` past the edge, but always
	# shift by exactly one screen_size so it lands where its peeking ghost
	# already was, instead of the "-margin, screen_size + margin" period
	# wrapf would use (which is 2*margin longer and causes a visible pop).
	if wrap_horizontally:
		while pos.x < -margin:
			pos.x += screen_size.x
		while pos.x > screen_size.x + margin:
			pos.x -= screen_size.x
	if wrap_vertically:
		while pos.y < -margin:
			pos.y += screen_size.y
		while pos.y > screen_size.y + margin:
			pos.y -= screen_size.y

	return pos


func _wrap_rigidbody(body: RigidBody2D) -> void:
	var body_rid = body.get_rid()
	var state = PhysicsServer2D.body_get_direct_state(body_rid)

	if state:
		var current_pos = state.transform.origin
		var new_pos = _calculate_wrap(current_pos)

		if new_pos != current_pos:
			var new_transform = state.transform
			new_transform.origin = new_pos
			state.transform = new_transform


# Peeking "ghost" duplicates make the target visible and collidable on the
# opposite edge while it straddles a screen boundary, rather than only
# popping into view once it has fully crossed over.
func _create_shadows() -> void:
	_shadow_dirs = _get_wrap_directions()
	for _dir in _shadow_dirs:
		var shadow: Node2D = target.duplicate()
		shadow.set_script(null)
		_strip_wrap_children(shadow)
		_clear_groups(shadow)
		shadow.visible = false
		_set_shadow_collision_enabled(shadow, false)
		target.get_parent().add_child(shadow)
		_shadows.append(shadow)


# The target's visual can be swapped at runtime after shadows are built
# (e.g. Player switching between its ship and cowboy visuals), so shadows
# must mirror child add/remove rather than being frozen at creation time.
func _on_target_child_entered_tree(node: Node) -> void:
	if node is Wrap2D:
		return
	for shadow in _shadows:
		var copy := node.duplicate()
		_clear_groups(copy)
		_strip_wrap_children(copy)
		_set_shadow_collision_enabled(copy, shadow.visible)
		shadow.add_child(copy)


func _on_target_child_exiting_tree(node: Node) -> void:
	for shadow in _shadows:
		var copy := shadow.get_node_or_null(NodePath(node.name))
		if copy:
			copy.queue_free()


func _get_wrap_directions() -> Array[Vector2i]:
	var xs: Array[int] = [0]
	var ys: Array[int] = [0]
	if wrap_horizontally:
		xs = [-1, 0, 1]
	if wrap_vertically:
		ys = [-1, 0, 1]
	var dirs: Array[Vector2i] = []
	for x in xs:
		for y in ys:
			if x == 0 and y == 0:
				continue
			dirs.append(Vector2i(x, y))
	return dirs


# duplicate() copies group membership, but a shadow is a stripped-down visual
# echo, not a real entity, so it must not show up in gameplay group queries.
func _clear_groups(node: Node) -> void:
	for group in node.get_groups():
		node.remove_from_group(group)
	for child in node.get_children():
		_clear_groups(child)


func _strip_wrap_children(node: Node) -> void:
	for child in node.get_children():
		if child is Wrap2D:
			child.free()
		else:
			_strip_wrap_children(child)


func _set_shadow_collision_enabled(node: Node, enabled: bool) -> void:
	for child in node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			child.disabled = not enabled
		else:
			_set_shadow_collision_enabled(child, enabled)


func _update_shadows() -> void:
	for i in range(_shadow_dirs.size()):
		var dir: Vector2i = _shadow_dirs[i]
		var shadow: Node2D = _shadows[i]
		var active := _is_direction_active(dir)
		shadow.visible = active
		_set_shadow_collision_enabled(shadow, active)
		if active:
			var offset := Vector2(dir.x * screen_size.x, dir.y * screen_size.y)
			shadow.global_position = target.global_position + offset
			shadow.global_rotation = target.global_rotation
			shadow.modulate = target.modulate


func _is_direction_active(dir: Vector2i) -> bool:
	if dir.x == 1 and target.global_position.x >= margin:
		return false
	if dir.x == -1 and target.global_position.x <= screen_size.x - margin:
		return false
	if dir.y == 1 and target.global_position.y >= margin:
		return false
	if dir.y == -1 and target.global_position.y <= screen_size.y - margin:
		return false
	return true
