extends Node3D

signal caught(who)

const Bounds := preload("res://scripts/sea_bounds.gd")

var heading := 0.0
var speed := 3.6
var reach := 16.0
var deep := -22.0
var _bob := 0.0
var _wander := 1.5
var _hook_pos := Vector3.ZERO
var _tip: Node3D
var _hook: Node3D
var _line: MeshInstance3D
var _bobber: MeshInstance3D


func _ready() -> void:
	add_to_group("fisher")
	_build()
	var tip := _tip.global_position
	_hook_pos = tip + Vector3(0, -8.0, 0)
	_hook.global_position = _hook_pos


func _physics_process(delta: float) -> void:
	var target = _prey()
	if target != null:
		var flat: Vector3 = target.global_position - global_position
		flat.y = 0.0
		if flat.length() > 5.0:
			var want := atan2(flat.x, -flat.z)
			heading = lerp_angle(heading, want, clampf(1.15 * delta, 0.0, 1.0))
		speed = 6.2
	else:
		speed = 3.6
		_wander -= delta
		if _wander <= 0.0:
			heading += randf_range(-0.7, 0.7)
			_wander = randf_range(2.2, 4.8)
	var edge := Bounds.HALF * 0.62
	var pos := global_position
	pos += Vector3(sin(heading), 0.0, -cos(heading)) * speed * delta
	if absf(pos.x) > edge or absf(pos.z) > edge:
		heading = atan2(-pos.x, pos.z)
		pos.x = clampf(pos.x, -edge, edge)
		pos.z = clampf(pos.z, -edge, edge)
	_bob += delta
	pos.y = 0.28 + sin(_bob * 1.2) * 0.12
	global_position = pos
	rotation = Vector3(cos(_bob * 1.05) * 0.03, heading, sin(_bob * 0.85) * 0.04)
	_move_hook(delta, target)


func _move_hook(delta: float, target) -> void:
	var tip := _tip.global_position
	var want := tip + Vector3(sin(heading) * 1.4, -9.0, -cos(heading) * 1.4)
	if target != null:
		var aim: Vector3 = target.global_position
		aim.y = clampf(aim.y, deep, -3.0)
		var flat := Vector2(aim.x - tip.x, aim.z - tip.z)
		if flat.length() > reach:
			flat = flat.normalized() * reach
		want = Vector3(tip.x + flat.x, aim.y, tip.z + flat.y)
	var weight := 1.0 - exp(-2.6 * delta)
	_hook_pos = _hook_pos.lerp(want, weight)
	_hook.global_position = _hook_pos
	_aim_cylinder(_line, tip, _hook_pos, 0.035)
	var drop := _hook_pos.y - tip.y
	var on_water := 0.15
	if absf(drop) > 0.2:
		on_water = clampf((0.15 - tip.y) / drop, 0.08, 0.92)
	_bobber.global_position = tip.lerp(_hook_pos, on_water)
	if target != null and _hook_pos.distance_to(target.global_position) < _catch_radius(target):
		caught.emit(target)


func _prey():
	var best = null
	var best_d := 90.0 * 90.0
	for who in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(who) or not who.alive:
			continue
		if who.global_position.y < deep:
			continue
		var flat: Vector3 = global_position - who.global_position
		flat.y = 0.0
		var dist: float = flat.length_squared()
		if dist < best_d:
			best_d = dist
			best = who
	return best


func _catch_radius(who) -> float:
	if who.is_shark():
		return 1.9
	return 3.2


func _build() -> void:
	var hull := _mat(Color(0.12, 0.42, 0.28))
	var belly := _mat(Color(0.06, 0.16, 0.12))
	var wood := _mat(Color(0.45, 0.28, 0.12))
	var white := _mat(Color(0.93, 0.94, 0.9))
	_part(self, _sphere(1.2), Vector3(0, 0.02, 0), Vector3(1.15, 0.38, 3.4), belly)
	_part(self, _sphere(1.1), Vector3(0, 0.36, 0), Vector3(1.02, 0.26, 3.1), hull)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(1.1, 0.7, 1.15)
	_part(self, cabin, Vector3(0, 0.85, 0.7), Vector3.ONE, white)
	var coil := TorusMesh.new()
	coil.inner_radius = 0.18
	coil.outer_radius = 0.38
	_part(self, coil, Vector3(-0.15, 0.62, -0.55), Vector3.ONE, wood)
	var base := Vector3(0.15, 0.7, -0.15)
	_tip = Node3D.new()
	_tip.position = Vector3(1.7, 2.7, -1.15)
	add_child(_tip)
	_rod(base, _tip.position, wood)
	_hook = Node3D.new()
	add_child(_hook)
	var metal := _mat(Color(0.75, 0.72, 0.4))
	_part(_hook, _box(Vector3(0.06, 0.34, 0.06)), Vector3(0, 0.12, 0), Vector3.ONE, metal)
	_part(_hook, _box(Vector3(0.22, 0.06, 0.06)), Vector3(0.08, -0.04, 0), Vector3.ONE, metal)
	_line = MeshInstance3D.new()
	var rope := CylinderMesh.new()
	rope.top_radius = 1.0
	rope.bottom_radius = 1.0
	rope.height = 1.0
	rope.radial_segments = 6
	_line.mesh = rope
	_line.material_override = _mat(Color(0.9, 0.9, 0.82))
	add_child(_line)
	_bobber = MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.22
	ball.height = 0.44
	_bobber.mesh = ball
	_bobber.material_override = _mat(Color(0.9, 0.12, 0.1))
	add_child(_bobber)


func _rod(a: Vector3, b: Vector3, mat: Material) -> void:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.03
	mesh.bottom_radius = 0.055
	mesh.height = 1.0
	n.mesh = mesh
	n.material_override = mat
	n.position = (a + b) * 0.5
	var dir := b - a
	n.basis = _along(dir)
	n.scale = Vector3(1, maxf(dir.length(), 0.1), 1)
	add_child(n)


func _aim_cylinder(line: MeshInstance3D, a: Vector3, b: Vector3, thick: float) -> void:
	var dir := b - a
	var length := dir.length()
	line.global_position = a + dir * 0.5
	line.global_basis = _along(dir)
	line.scale = Vector3(thick, maxf(length, 0.1), thick)


func _along(dir: Vector3) -> Basis:
	if dir.length_squared() < 0.0001:
		return Basis.IDENTITY
	return Basis.looking_at(dir.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, PI * 0.5)


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	return mesh


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, scl: Vector3, mat: Material) -> void:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.scale = scl
	n.material_override = mat
	parent.add_child(n)


func _mat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.48
	return mat
