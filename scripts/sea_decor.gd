extends Node3D

const Bounds := preload("res://scripts/sea_bounds.gd")

var _kelps: Array[Node3D] = []
var _schools: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 260926
	_forest(rng)
	_reef(rng)
	_rocks(rng)
	_schools_build(rng)
	_bubbles()


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _kelps.size():
		var kelp := _kelps[i]
		kelp.rotation.z = sin(t * 0.7 + float(i) * 0.6) * 0.14
		kelp.rotation.x = cos(t * 0.55 + float(i) * 0.4) * 0.1
	for school in _schools:
		var pos: Vector3 = school.pos + school.vel * delta
		var vel: Vector3 = school.vel
		if absf(pos.x) > 70.0:
			vel.x = -vel.x
			pos.x = clampf(pos.x, -70.0, 70.0)
		if absf(pos.z) > 70.0:
			vel.z = -vel.z
			pos.z = clampf(pos.z, -70.0, 70.0)
		if pos.y < -8.0 or pos.y > -1.5:
			vel.y = -vel.y
			pos.y = clampf(pos.y, -8.0, -1.5)
		school.pos = pos
		school.vel = vel
		school.node.position = pos


func _forest(rng: RandomNumberGenerator) -> void:
	for i in 28:
		var x := rng.randf_range(-74.0, -22.0)
		var z := rng.randf_range(-70.0, 70.0)
		var h := rng.randf_range(5.0, 12.0)
		_kelps.append(_kelp(Vector3(x, Bounds.BED_Y, z), h, rng.randf_range(0.2, 0.38)))


func _reef(rng: RandomNumberGenerator) -> void:
	var colors: Array[Color] = [
		Color(0.95, 0.35, 0.48),
		Color(0.95, 0.55, 0.2),
		Color(0.72, 0.32, 0.78),
		Color(0.95, 0.75, 0.28),
	]
	for i in 16:
		var at := Vector3(rng.randf_range(24.0, 72.0), Bounds.BED_Y + 0.2, rng.randf_range(-68.0, 68.0))
		_coral(at, colors[i % colors.size()], rng)


func _rocks(rng: RandomNumberGenerator) -> void:
	var mat := _mat(Color(0.38, 0.4, 0.44), 0.9)
	for i in 14:
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.6, 1.5)
		mesh.height = mesh.radius * 2.0
		rock.mesh = mesh
		rock.material_override = mat
		rock.scale = Vector3(rng.randf_range(1.1, 1.8), rng.randf_range(0.45, 0.75), rng.randf_range(1.0, 1.6))
		rock.position = Vector3(
			rng.randf_range(-70.0, 70.0),
			Bounds.BED_Y + 0.3,
			rng.randf_range(-70.0, 70.0)
		)
		add_child(rock)


func _kelp(at: Vector3, height: float, radius: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	var stalk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.45
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	stalk.mesh = mesh
	stalk.position = Vector3(0, height * 0.5, 0)
	stalk.material_override = _mat(Color(0.08, 0.48, 0.28), 0.7)
	pivot.add_child(stalk)
	var tip := MeshInstance3D.new()
	var bulb := SphereMesh.new()
	bulb.radius = radius * 1.3
	bulb.height = bulb.radius * 2.0
	tip.mesh = bulb
	tip.position = Vector3(0, height, 0)
	tip.material_override = _mat(Color(0.15, 0.62, 0.32), 0.55)
	pivot.add_child(tip)
	return pivot


func _coral(at: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	var mat := _mat(color, 0.55)
	var root := Node3D.new()
	root.position = at
	add_child(root)
	for i in 5:
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.28, 0.6)
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 10
		mesh.rings = 6
		ball.mesh = mesh
		ball.material_override = mat
		ball.position = Vector3(rng.randf_range(-0.7, 0.7), rng.randf_range(0.2, 1.3), rng.randf_range(-0.7, 0.7))
		root.add_child(ball)


func _schools_build(rng: RandomNumberGenerator) -> void:
	var mat := _mat(Color(0.55, 0.78, 0.88), 0.4)
	for n in 3:
		var node := Node3D.new()
		var pos := Vector3(-20.0 + float(n) * 22.0, -3.5 - float(n), -15.0 + float(n) * 18.0)
		node.position = pos
		add_child(node)
		for i in 7:
			var fish := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.18
			mesh.height = 0.36
			fish.mesh = mesh
			fish.scale = Vector3(0.45, 0.32, 1.0)
			fish.position = Vector3(rng.randf_range(-1.6, 1.6), rng.randf_range(-0.5, 0.5), rng.randf_range(-1.2, 1.2))
			fish.material_override = mat
			node.add_child(fish)
		var school := School.new()
		school.node = node
		school.pos = pos
		school.vel = Vector3(rng.randf_range(1.2, 2.2) * (1.0 if n != 1 else -1.0), 0.0, rng.randf_range(-0.4, 0.4))
		_schools.append(school)


func _bubbles() -> void:
	var spots: Array[Vector3] = [
		Vector3(-20, -14, 0),
		Vector3(15, -18, 20),
		Vector3(0, -8, -25),
		Vector3(40, -12, -10),
		Vector3(-45, -20, 30),
	]
	for spot in spots:
		var p := CPUParticles3D.new()
		p.position = spot
		p.amount = 18
		p.lifetime = 6.0
		p.preprocess = 2.0
		p.direction = Vector3(0, 1, 0)
		p.spread = 12.0
		p.gravity = Vector3(0, 0.4, 0)
		p.initial_velocity_min = 0.4
		p.initial_velocity_max = 1.1
		p.explosiveness = 0.0
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(8, 4, 8)
		var mesh := SphereMesh.new()
		mesh.radius = 0.06
		mesh.height = 0.12
		mesh.material = _mat(Color(0.85, 0.95, 1.0, 0.4), 0.2, true)
		p.mesh = mesh
		add_child(p)


func _mat(color: Color, rough: float, transparent: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat


class School extends RefCounted:
	var node: Node3D
	var pos: Vector3
	var vel: Vector3
