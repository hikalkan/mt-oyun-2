extends Area3D

enum Kind { TINY, DUCK, HORN }

const Land := preload("res://scripts/land_bounds.gd")

var kind := Kind.TINY
var cruise_speed := 3.4
var flee_speed := 11.0
var velocity := Vector3.ZERO
var wander := Vector3.FORWARD
var _eating := false
var _wander_wait := 0.0
var _tail: Node3D
var _legs: Array[Node3D] = []
var _bob: Node3D


func setup(next_kind: Kind) -> void:
	kind = next_kind
	match kind:
		Kind.TINY:
			cruise_speed = 4.4
			flee_speed = 13.2
		Kind.DUCK:
			cruise_speed = 3.1
			flee_speed = 10.4
		_:
			cruise_speed = 2.2
			flee_speed = 7.4


func _ready() -> void:
	add_to_group("prey")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	wander = _new_wander()
	_wander_wait = randf_range(0.8, 2.2)
	_bob = Node3D.new()
	add_child(_bob)
	match kind:
		Kind.TINY:
			_build_tiny()
		Kind.DUCK:
			_build_duck()
		_:
			_build_horn()
	var shape := SphereShape3D.new()
	shape.radius = 0.55 if kind == Kind.TINY else (0.9 if kind == Kind.DUCK else 1.2)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, shape.radius * 0.8, 0.0)
	add_child(col)
	global_position = Land.stand(global_position)


func _physics_process(delta: float) -> void:
	if _eating:
		_animate(delta, true)
		return
	_wander_wait -= delta
	if _wander_wait <= 0.0:
		wander = _new_wander()
		_wander_wait = randf_range(1.6, 3.4)
	var desired := wander * cruise_speed
	var accel := 7.0
	var hunter = _nearest_player()
	if hunter != null:
		var offset: Vector3 = global_position - hunter.global_position
		offset.y = 0.0
		var dist := offset.length()
		var radius: float = hunter.scare_radius()
		if dist < radius and dist > 0.35:
			var urgency := clampf(1.0 - dist / radius, 0.0, 1.0)
			desired = offset.normalized() * lerpf(cruise_speed, flee_speed, 0.4 + urgency * 0.6)
			accel = 12.0
	velocity = velocity.move_toward(desired, accel * delta)
	var pos := global_position + Vector3(velocity.x, 0.0, velocity.z) * delta
	var before := pos
	pos = Land.clamp_xz(pos, 3.0)
	if not is_equal_approx(pos.x, before.x):
		velocity.x = 0.0
		wander.x = -wander.x
	if not is_equal_approx(pos.z, before.z):
		velocity.z = 0.0
		wander.z = -wander.z
	pos.y = Land.ground_y(pos.x, pos.z)
	global_position = pos
	_face()
	_animate(delta, false)


func got_eaten() -> bool:
	if _eating:
		return false
	_eating = true
	set_deferred("monitorable", false)
	var tw := create_tween()
	tw.tween_property(_bob, "scale", Vector3(0.05, 0.05, 0.05), 0.16)
	tw.tween_callback(_respawn)
	return true


func _respawn() -> void:
	var hunter = _nearest_player()
	if hunter != null:
		global_position = Land.nearby(hunter.global_position, 30.0, 85.0)
	else:
		global_position = Land.stand(Vector3(randf_range(-90.0, 90.0), 0.0, randf_range(-90.0, 90.0)))
	_bob.scale = Vector3.ONE
	velocity = Vector3.ZERO
	wander = _new_wander()
	_eating = false
	monitorable = true


func _face() -> void:
	var ahead := Vector3(velocity.x, 0.0, velocity.z)
	if ahead.length() < 0.2:
		return
	look_at(global_position + ahead, Vector3.UP)


func _animate(_delta: float, eating: bool) -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.35 and not eating
	var pace := 9.0 if kind == Kind.TINY else 6.0
	if not moving:
		pace = 2.0
	for i in _legs.size():
		var swing := 0.7 if moving else 0.08
		_legs[i].rotation.x = sin(Time.get_ticks_msec() * 0.001 * pace + float(i) * PI) * swing
	if _tail:
		_tail.rotation.y = sin(Time.get_ticks_msec() * 0.01) * (0.4 if moving else 0.12)


func _nearest_player():
	var best = null
	var best_d := 1.0e20
	for who in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(who) or not who.alive:
			continue
		var dist := global_position.distance_squared_to(who.global_position)
		if dist < best_d:
			best_d = dist
			best = who
	return best


func _new_wander() -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()


func _build_tiny() -> void:
	var skin := _mat(Color(0.55, 0.78, 0.22))
	var dark := _mat(Color(0.28, 0.48, 0.12))
	_body(_bob, 0.22, Vector3(0.7, 0.75, 1.15), Vector3(0.0, 0.48, 0.05), skin)
	_body(_bob, 0.16, Vector3(0.85, 0.8, 1.05), Vector3(0.0, 0.62, -0.32), skin)
	_body(_bob, 0.07, Vector3(0.5, 0.35, 0.7), Vector3(0.0, 0.55, -0.52), dark)
	_eye(_bob, Vector3(0.08, 0.7, -0.42))
	_eye(_bob, Vector3(-0.08, 0.7, -0.42))
	_add_leg(_bob, 0.12, 0.28, skin)
	_add_leg(_bob, -0.12, 0.28, skin)
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 0.5, 0.28)
	_bob.add_child(_tail)
	_body(_tail, 0.08, Vector3(0.4, 0.35, 1.8), Vector3(0.0, 0.04, 0.22), dark)


func _build_duck() -> void:
	var skin := _mat(Color(0.42, 0.58, 0.24))
	var tan := _mat(Color(0.72, 0.58, 0.32))
	var bill := _mat(Color(0.86, 0.62, 0.22))
	_body(_bob, 0.48, Vector3(0.85, 0.7, 1.45), Vector3(0.0, 0.85, 0.1), skin)
	_body(_bob, 0.32, Vector3(0.7, 0.4, 1.1), Vector3(0.0, 0.62, 0.15), tan)
	_body(_bob, 0.28, Vector3(0.9, 0.85, 1.05), Vector3(0.0, 1.25, -0.7), skin)
	_place(_bob, _box(Vector3(0.22, 0.1, 0.55)), Vector3(0.0, 1.12, -1.15), Vector3(0.15, 0.0, 0.0), Vector3.ONE, bill)
	_body(_bob, 0.1, Vector3(0.45, 1.3, 0.35), Vector3(0.0, 1.7, -0.55), tan)
	_eye(_bob, Vector3(0.16, 1.38, -0.88))
	_eye(_bob, Vector3(-0.16, 1.38, -0.88))
	_add_leg(_bob, 0.22, 0.42, _mat(Color(0.3, 0.42, 0.16)))
	_add_leg(_bob, -0.22, 0.42, _mat(Color(0.3, 0.42, 0.16)))
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 0.95, 0.7)
	_bob.add_child(_tail)
	_body(_tail, 0.16, Vector3(0.4, 0.9, 0.7), Vector3(0.0, 0.2, 0.2), skin)


func _build_horn() -> void:
	var skin := _mat(Color(0.48, 0.55, 0.34))
	var dark := _mat(Color(0.28, 0.34, 0.2))
	var horn := _mat(Color(0.82, 0.74, 0.52))
	_body(_bob, 0.62, Vector3(1.15, 0.75, 1.35), Vector3(0.0, 0.85, 0.15), skin)
	_body(_bob, 0.4, Vector3(0.7, 0.4, 1.0), Vector3(0.0, 0.55, 0.2), _mat(Color(0.7, 0.66, 0.48)))
	_body(_bob, 0.38, Vector3(1.05, 0.9, 0.95), Vector3(0.0, 1.15, -0.75), skin)
	_place(_bob, _box(Vector3(1.15, 0.85, 0.12)), Vector3(0.0, 1.35, -0.95), Vector3(-0.35, 0.0, 0.0), Vector3.ONE, dark)
	var nose := CylinderMesh.new()
	nose.top_radius = 0.02
	nose.bottom_radius = 0.08
	nose.height = 0.42
	nose.radial_segments = 8
	_place(_bob, nose, Vector3(0.0, 1.2, -1.25), Vector3(deg_to_rad(-80.0), 0.0, 0.0), Vector3.ONE, horn)
	_place(_bob, nose, Vector3(0.28, 1.45, -1.05), Vector3(deg_to_rad(-40.0), 0.3, 0.4), Vector3(0.7, 0.7, 0.7), horn)
	_place(_bob, nose, Vector3(-0.28, 1.45, -1.05), Vector3(deg_to_rad(-40.0), -0.3, -0.4), Vector3(0.7, 0.7, 0.7), horn)
	_eye(_bob, Vector3(0.22, 1.28, -1.0))
	_eye(_bob, Vector3(-0.22, 1.28, -1.0))
	_add_leg(_bob, 0.38, 0.48, dark)
	_add_leg(_bob, -0.38, 0.48, dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 0.9, 0.85)
	_bob.add_child(_tail)
	_body(_tail, 0.16, Vector3(0.45, 0.4, 1.1), Vector3(0.0, 0.05, 0.2), dark)


func _add_leg(parent: Node3D, side: float, hip_y: float, mat: Material) -> void:
	var hip := Node3D.new()
	hip.position = Vector3(side, hip_y, 0.05)
	parent.add_child(hip)
	_legs.append(hip)
	_place(hip, _box(Vector3(0.1, hip_y * 0.85, 0.12)), Vector3(0.0, -hip_y * 0.4, 0.0), Vector3.ZERO, Vector3.ONE, mat)


func _eye(parent: Node3D, pos: Vector3) -> void:
	_body(parent, 0.045, Vector3.ONE, pos, _mat(Color(0.95, 0.95, 0.92)))
	_body(parent, 0.022, Vector3.ONE, pos + Vector3(0.0, 0.0, -0.03), _mat(Color(0.06, 0.05, 0.04)))


func _body(parent: Node3D, radius: float, scl: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	_place(parent, mesh, pos, Vector3.ZERO, scl, mat)


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _place(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, scl: Vector3, mat: Material) -> void:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.rotation = rot
	n.scale = scl
	n.material_override = mat
	parent.add_child(n)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.55
	return mat
