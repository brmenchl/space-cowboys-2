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

# Extra collision shapes added directly to the target's own RigidBody2D so a
# hit on the wrapped-around "ghost" side is a contact on the one real body
# (and so applies force/torque to it), instead of on a separate duplicate
# body that would have to somehow forward the impulse back.
var _ghost_shapes: Array[Dictionary] = []

# Keeps a strong reference to any Shape2D resources built for ghost shapes
# (e.g. from a CollisionPolygon2D). PhysicsServer2D RIDs don't keep their
# resource alive, so without this the shape gets freed and its RID goes
# dead as soon as it falls out of scope.
var _owned_shapes: Array[Shape2D] = []


func _ready() -> void:
	if target == null:
		target = get_parent()
	_update_screen_size()
	# Scene preview/thumbnail generation runs @tool scripts without a live
	# Viewport in the tree, so get_viewport() can be null there.
	var viewport := get_viewport()
	if viewport:
		viewport.size_changed.connect(_update_screen_size)
	if not Engine.is_editor_hint():
		call_deferred("_create_shadows")
		if target is RigidBody2D:
			call_deferred("_create_ghost_shapes")
		target.child_entered_tree.connect(_on_target_child_entered_tree)
		target.child_exiting_tree.connect(_on_target_child_exiting_tree)


func _exit_tree() -> void:
	for shadow in _shadows:
		if is_instance_valid(shadow):
			shadow.queue_free()
	_remove_ghost_shapes()


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
		_update_ghost_shapes()
	else:
		target.global_position = _calculate_wrap(target.global_position)

	_update_shadows()


func _update_screen_size() -> void:
	var viewport := get_viewport()
	if viewport:
		screen_size = viewport.get_visible_rect().size


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


# Peeking "ghost" duplicates make the target visible on the opposite edge
# while it straddles a screen boundary, rather than only popping into view
# once it has fully crossed over. Collision for RigidBody2D targets is
# handled separately by _create_ghost_shapes, so these duplicates are purely
# visual for them and never need their own collision enabled.
func _create_shadows() -> void:
	_shadow_dirs = _get_wrap_directions()
	for _dir in _shadow_dirs:
		var shadow: Node2D = target.duplicate()
		shadow.set_script(null)
		_strip_wrap_children(shadow)
		_clear_groups(shadow)
		shadow.visible = false
		_set_shadow_collision_enabled(shadow, false)
		if shadow is RigidBody2D:
			shadow.freeze = true
			shadow.freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
		target.get_parent().add_child(shadow)
		_shadows.append(shadow)


# Adds one extra collision shape per (collision shape, wrap direction) pair
# directly onto the target's own physics body, disabled until the target
# nears that edge. Their local transforms are kept screen-aligned (see
# _update_ghost_shapes) so the ghost shape doesn't spin around the body's
# origin as the body rotates.
func _create_ghost_shapes() -> void:
	# RigidBody2D defaults to CENTER_OF_MASS_MODE_AUTO, which recomputes the
	# center of mass from whichever shapes are currently enabled. Ghost shapes
	# are real shapes on this same body and sit a full screen away when active,
	# so left on AUTO the center of mass would jump off the body the moment a
	# ghost activates near an edge, turning torque (e.g. from turning input)
	# into a visible translation instead of a clean rotation. Locking it to
	# its real (pre-ghost) value keeps it fixed regardless of ghost state.
	target.center_of_mass_mode = RigidBody2D.CENTER_OF_MASS_MODE_CUSTOM
	target.center_of_mass = target.center_of_mass

	var body_rid: RID = target.get_rid()
	for shape_def in _collect_shape_defs(target):
		for dir in _shadow_dirs:
			var shape_index := PhysicsServer2D.body_get_shape_count(body_rid)
			PhysicsServer2D.body_add_shape(body_rid, shape_def.shape_rid, shape_def.local_transform, true)
			_ghost_shapes.append({
				"dir": dir,
				"shape_index": shape_index,
				"base_transform": shape_def.local_transform,
			})


func _remove_ghost_shapes() -> void:
	if not target or not is_instance_valid(target) or not target is RigidBody2D:
		return
	var body_rid: RID = target.get_rid()
	var indices: Array = []
	for ghost in _ghost_shapes:
		indices.append(ghost.shape_index)
	indices.sort()
	indices.reverse()
	for shape_index in indices:
		PhysicsServer2D.body_remove_shape(body_rid, shape_index)
	_ghost_shapes.clear()
	_owned_shapes.clear()


# Collects the target's own collision shapes as reusable Shape2D RIDs. A
# CollisionPolygon2D doesn't expose the Shape2D(s) it builds internally, so
# equivalent ConvexPolygonShape2D(s) are created from its polygon. The
# polygon may be concave, so it's decomposed into convex pieces the same way
# CollisionPolygon2D's own BUILD_SOLIDS mode does, rather than handing the
# raw points to ConvexPolygonShape2D (which would silently hull them).
func _collect_shape_defs(node: Node) -> Array[Dictionary]:
	var defs: Array[Dictionary] = []
	for child in node.get_children():
		if child is CollisionShape2D and child.shape:
			defs.append({"shape_rid": child.shape.get_rid(), "local_transform": child.transform})
		elif child is CollisionPolygon2D:
			for convex_points in Geometry2D.decompose_polygon_in_convex(child.polygon):
				var shape := ConvexPolygonShape2D.new()
				shape.points = convex_points
				_owned_shapes.append(shape)
				defs.append({"shape_rid": shape.get_rid(), "local_transform": child.transform})
		else:
			defs.append_array(_collect_shape_defs(child))
	return defs


func _update_ghost_shapes() -> void:
	var body_rid: RID = target.get_rid()
	var rotation := target.global_rotation
	for ghost in _ghost_shapes:
		var dir: Vector2i = ghost.dir
		var active := _is_direction_active(dir)
		PhysicsServer2D.body_set_shape_disabled(body_rid, ghost.shape_index, not active)
		if active:
			var offset := Vector2(dir.x * screen_size.x, dir.y * screen_size.y)
			var local_offset := offset.rotated(-rotation)
			var base_transform: Transform2D = ghost.base_transform
			var ghost_transform := base_transform
			ghost_transform.origin = base_transform.origin + local_offset
			PhysicsServer2D.body_set_shape_transform(body_rid, ghost.shape_index, ghost_transform)


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
		_set_shadow_collision_enabled(copy, false)
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
		if not (target is RigidBody2D):
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
