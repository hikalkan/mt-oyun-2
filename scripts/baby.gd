extends Node3D

const Land := preload("res://scripts/land_bounds.gd")
const SkinShader := preload("res://assets/shaders/skin.gdshader")

var parent = null
var _biting := 0.0
var _bite_at := Vector3.ZERO
var _time := 0.0
var _jaw: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []


func setup(who) -> void:
	parent = who


func _ready() -> void:
	_build()
	scale = Vector3(0.08, 0.08, 0.08)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.46, 0.46, 0.46), 0.35)


func eat_with(at: Vector3) -> void:
	var snack = _nearest_prey(4.8)
	if snack != null and snack.call("got_eaten") == true:
		_bite_at = snack.global_position
		_biting = 0.6
		if parent != null and is_instance_valid(parent):
			parent.ate_fish.emit(snack.global_position)
		return
	_bite_at = at
	_biting = 0.55


func _physics_process(delta: float) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.alive:
		queue_free()
		return
	_time += delta
	if _biting > 0.0:
		_biting -= delta
	var back: Vector3 = parent.global_transform.basis.z
	var side: Vector3 = parent.global_transform.basis.x
	var goal: Vector3 = parent.global_position + back * 3.1 + side * 1.8
	var speed := 12.5
	if _biting > 0.0:
		goal = _bite_at
		speed = 18.0
	var pos := global_position
	var flat := Vector3(goal.x - pos.x, 0.0, goal.z - pos.z)
	var dist := flat.length()
	if dist > 7.0 and _biting <= 0.0:
		speed = 18.0
	if dist > 0.15:
		var step := flat.limit_length(speed * delta)
		pos.x += step.x
		pos.z += step.z
		look_at(Vector3(pos.x + flat.x, pos.y, pos.z + flat.z), Vector3.UP)
	pos = Land.clamp_xz(pos, 3.0)
	pos.y = Land.ground_y(pos.x, pos.z)
	global_position = pos
	var moving := dist > 0.4
	var pace := 8.0 if moving else 2.0
	for i in _legs.size():
		var swing := 0.65 if moving else 0.08
		_legs[i].rotation.x = sin(_time * pace + float(i) * PI) * swing
	if _tail:
		_tail.rotation.y = sin(_time * (5.0 if moving else 1.8)) * (0.28 if moving else 0.08)
	if _jaw:
		var open := 0.55 if _biting > 0.0 else 0.05
		_jaw.rotation.x = lerpf(_jaw.rotation.x, -open, 0.25)


func _nearest_prey(reach: float):
	var best = null
	var best_d := reach * reach
	for node in get_tree().get_nodes_in_group("prey"):
		if not is_instance_valid(node) or bool(node.get("_eating")):
			continue
		var dist: float = global_position.distance_squared_to(node.global_position)
		if dist < best_d:
			best_d = dist
			best = node
	return best


func _build() -> void:
	var skin := _skin(Color(0.48, 0.62, 0.28))
	var belly := _skin(Color(0.74, 0.68, 0.42))
	var dark := _skin(Color(0.28, 0.4, 0.16))
	_ball(self, 0.55, Vector3(0.9, 0.8, 1.4), Vector3(0.0, 1.15, 0.1), skin)
	_ball(self, 0.34, Vector3(0.7, 0.45, 1.0), Vector3(0.0, 0.85, 0.15), belly)
	_ball(self, 0.38, Vector3(0.85, 0.75, 1.2), Vector3(0.0, 1.45, -1.15), skin)
	_ball(self, 0.18, Vector3(0.7, 0.5, 1.2), Vector3(0.0, 1.28, -1.85), skin)
	_eye(Vector3(0.16, 1.62, -1.45))
	_eye(Vector3(-0.16, 1.62, -1.45))
	_jaw = Node3D.new()
	_jaw.position = Vector3(0.0, 1.22, -1.35)
	add_child(_jaw)
	_ball(_jaw, 0.14, Vector3(0.8, 0.45, 1.4), Vector3(0.0, -0.04, -0.45), belly)
	_add_leg(0.28, skin, dark)
	_add_leg(-0.28, skin, dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 1.1, 0.7)
	add_child(_tail)
	_ball(_tail, 0.22, Vector3(0.55, 0.45, 1.6), Vector3(0.0, 0.05, 0.45), skin)
	_ball(_tail, 0.12, Vector3(0.4, 0.35, 1.3), Vector3(0.0, 0.12, 1.05), dark)


func _add_leg(side: float, skin: Material, dark: Material) -> void:
	var hip := Node3D.new()
	hip.position = Vector3(side, 0.72, 0.1)
	add_child(hip)
	_legs.append(hip)
	_box(hip, Vector3(0.18, 0.42, 0.2), Vector3(0.0, -0.2, 0.0), skin)
	_box(hip, Vector3(0.2, 0.1, 0.36), Vector3(0.0, -0.42, -0.06), dark)


func _eye(pos: Vector3) -> void:
	_ball(self, 0.07, Vector3.ONE, pos, _plain(Color(0.95, 0.95, 0.9)))
	_ball(self, 0.035, Vector3.ONE, pos + Vector3(0.0, 0.0, -0.04), _plain(Color(0.08, 0.06, 0.04)))


func _ball(host: Node3D, radius: float, scl: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.scale = scl
	n.material_override = mat
	host.add_child(n)


func _box(host: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.material_override = mat
	host.add_child(n)


func _skin(color: Color) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = SkinShader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("roughness_amt", 0.5)
	return mat


func _plain(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.3
	return mat
