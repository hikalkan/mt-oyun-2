extends Node3D

const Bounds := preload("res://scripts/sea_bounds.gd")

var _kelps: Array[Node3D] = []
var _schools: Array = []
var _boats: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 260926
	_forest(rng)
	_reef(rng)
	_rocks(rng)
	_schools_build(rng)
	_bubbles()
	_boats_build(rng)


func _process(delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _kelps.size():
		var kelp := _kelps[i]
		kelp.rotation.z = sin(t * 0.7 + float(i) * 0.6) * 0.14
		kelp.rotation.x = cos(t * 0.55 + float(i) * 0.4) * 0.1
	for school in _schools:
		var pos: Vector3 = school.pos + school.vel * delta
		var vel: Vector3 = school.vel
		var edge := Bounds.HALF * 0.82
		if absf(pos.x) > edge:
			vel.x = -vel.x
			pos.x = clampf(pos.x, -edge, edge)
		if absf(pos.z) > edge:
			vel.z = -vel.z
			pos.z = clampf(pos.z, -edge, edge)
		if pos.y < -28.0 or pos.y > -3.0:
			vel.y = -vel.y
			pos.y = clampf(pos.y, -28.0, -3.0)
		school.pos = pos
		school.vel = vel
		school.node.position = pos
	var edge := Bounds.HALF * 0.72
	for boat in _boats:
		var heading: float = boat.heading
		var pos: Vector3 = boat.pos + Vector3(sin(heading), 0.0, -cos(heading)) * boat.speed * delta
		if absf(pos.x) > edge or absf(pos.z) > edge:
			heading = atan2(-pos.x, pos.z)
			pos.x = clampf(pos.x, -edge, edge)
			pos.z = clampf(pos.z, -edge, edge)
		var bob: float = boat.bob + delta
		boat.heading = heading
		boat.pos = pos
		boat.bob = bob
		boat.node.position = Vector3(pos.x, 0.25 + sin(bob * 1.25) * 0.16, pos.z)
		boat.node.rotation = Vector3(cos(bob * 1.05) * 0.03, heading, sin(bob * 0.85) * 0.045)


func _forest(rng: RandomNumberGenerator) -> void:
	for i in 110:
		var x := rng.randf_range(-Bounds.HALF * 0.72, -Bounds.HALF * 0.08)
		var z := rng.randf_range(-Bounds.HALF * 0.55, Bounds.HALF * 0.55)
		var h := rng.randf_range(10.0, 26.0)
		_kelps.append(_kelp(Vector3(x, Bounds.floor_y(x, z), z), h, rng.randf_range(0.28, 0.5)))


func _reef(rng: RandomNumberGenerator) -> void:
	var colors: Array[Color] = [
		Color(0.95, 0.35, 0.48),
		Color(0.95, 0.55, 0.2),
		Color(0.72, 0.32, 0.78),
		Color(0.95, 0.75, 0.28),
	]
	for i in 60:
		var x := rng.randf_range(Bounds.HALF * 0.08, Bounds.HALF * 0.72)
		var z := rng.randf_range(-Bounds.HALF * 0.55, Bounds.HALF * 0.55)
		var at := Vector3(x, Bounds.floor_y(x, z) + 0.3, z)
		_coral(at, colors[i % colors.size()], rng)


func _rocks(rng: RandomNumberGenerator) -> void:
	var mat := _mat(Color(0.38, 0.4, 0.44), 0.9)
	for i in 80:
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var x := rng.randf_range(-Bounds.HALF * 0.9, Bounds.HALF * 0.9)
		var z := rng.randf_range(-Bounds.HALF * 0.9, Bounds.HALF * 0.9)
		var deep := clampf((-Bounds.floor_y(x, z) - 70.0) / 100.0, 0.0, 1.0)
		mesh.radius = rng.randf_range(0.8, 1.6) + deep * 2.2
		mesh.height = mesh.radius * 2.0
		rock.mesh = mesh
		rock.material_override = mat
		rock.scale = Vector3(rng.randf_range(1.2, 2.1), rng.randf_range(0.4, 0.7), rng.randf_range(1.1, 1.9))
		rock.position = Vector3(x, Bounds.floor_y(x, z) + mesh.radius * 0.25, z)
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
	for n in 14:
		var node := Node3D.new()
		var pos := Vector3(rng.randf_range(-Bounds.HALF * 0.7, Bounds.HALF * 0.7), rng.randf_range(-18.0, -4.0), rng.randf_range(-Bounds.HALF * 0.7, Bounds.HALF * 0.7))
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
		Vector3(-30, -40, 10),
		Vector3(20, -55, 30),
		Vector3(0, -22, -40),
		Vector3(70, -48, -20),
		Vector3(-80, -70, 40),
		Vector3(140, -120, -80),
		Vector3(-150, -130, -60),
		Vector3(40, -90, 120),
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


func _boats_build(rng: RandomNumberGenerator) -> void:
	var paints: Array[Color] = [
		Color(0.78, 0.16, 0.14),
		Color(0.14, 0.34, 0.7),
		Color(0.86, 0.7, 0.16),
		Color(0.18, 0.52, 0.32),
		Color(0.9, 0.9, 0.92),
	]
	for i in paints.size():
		_launch(_small_boat(paints[i]), rng, rng.randf_range(4.0, 6.0), rng.randf_range(0.85, 1.15))
	for i in 3:
		_launch(_ship(i == 0), rng, rng.randf_range(2.1, 3.1), rng.randf_range(0.9, 1.12))
	for i in 2:
		_launch(_sailboat(), rng, rng.randf_range(3.3, 4.6), rng.randf_range(0.9, 1.1))


func _launch(node: Node3D, rng: RandomNumberGenerator, speed: float, scl: float) -> void:
	var boat := Boat.new()
	boat.node = node
	boat.pos = Vector3(rng.randf_range(-Bounds.HALF * 0.6, Bounds.HALF * 0.6), 0.0, rng.randf_range(-Bounds.HALF * 0.6, Bounds.HALF * 0.6))
	boat.heading = rng.randf_range(-PI, PI)
	boat.speed = speed
	boat.bob = rng.randf() * TAU
	node.scale = Vector3.ONE * scl
	node.position = boat.pos
	add_child(node)
	_boats.append(boat)


func _small_boat(color: Color) -> Node3D:
	var root := Node3D.new()
	var hull := _mat(color, 0.42)
	var belly := _mat(color.darkened(0.38), 0.58)
	var white := _mat(Color(0.93, 0.94, 0.92), 0.38)
	var wood := _mat(Color(0.42, 0.28, 0.14), 0.65)
	_part(root, _sphere(1.15), Vector3(0, 0.05, 0), Vector3(1.2, 0.4, 3.3), belly)
	_part(root, _sphere(1.05), Vector3(0, 0.38, 0), Vector3(1.08, 0.28, 3.0), hull)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(1.15, 0.75, 1.25)
	_part(root, cabin, Vector3(0, 0.9, 0.85), Vector3.ONE, white)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.05
	mast.bottom_radius = 0.08
	mast.height = 2.2
	_part(root, mast, Vector3(0, 1.7, -0.35), Vector3.ONE, wood)
	_foam(root, 3.3)
	return root


func _ship(red_hull: bool) -> Node3D:
	var root := Node3D.new()
	var hull_col := Color(0.62, 0.14, 0.13) if red_hull else Color(0.1, 0.14, 0.2)
	var hull := _mat(hull_col, 0.38)
	var belly := _mat(hull_col.darkened(0.28), 0.55)
	var white := _mat(Color(0.9, 0.91, 0.88), 0.34)
	var stripe := _mat(Color(0.9, 0.72, 0.18), 0.4)
	var metal := _mat(Color(0.28, 0.3, 0.33), 0.45)
	_part(root, _sphere(2.3), Vector3(0, -0.2, 0), Vector3(1.7, 0.42, 7.4), belly)
	_part(root, _sphere(2.15), Vector3(0, 0.4, 0), Vector3(1.55, 0.34, 6.9), hull)
	_part(root, _sphere(2.05), Vector3(0, 0.72, 0), Vector3(1.58, 0.07, 6.6), stripe)
	var cabin := BoxMesh.new()
	cabin.size = Vector3(2.6, 1.7, 3.4)
	_part(root, cabin, Vector3(0, 1.7, 5.2), Vector3.ONE, white)
	var bridge := BoxMesh.new()
	bridge.size = Vector3(2.0, 1.05, 1.7)
	_part(root, bridge, Vector3(0, 2.9, 5.6), Vector3.ONE, white)
	var stack := CylinderMesh.new()
	stack.top_radius = 0.28
	stack.bottom_radius = 0.38
	stack.height = 1.8
	_part(root, stack, Vector3(0.85, 2.5, 2.6), Vector3.ONE, metal)
	_part(root, stack, Vector3(-0.85, 2.3, 2.4), Vector3(0.85, 0.85, 0.85), metal)
	_foam(root, 15.5)
	return root


func _sailboat() -> Node3D:
	var root := Node3D.new()
	var hull := _mat(Color(0.94, 0.95, 0.96), 0.28)
	var belly := _mat(Color(0.12, 0.26, 0.48), 0.45)
	var sail := _mat(Color(0.97, 0.97, 0.94), 0.55)
	var wood := _mat(Color(0.4, 0.26, 0.14), 0.6)
	_part(root, _sphere(1.05), Vector3(0, 0.0, 0), Vector3(1.05, 0.38, 3.8), belly)
	_part(root, _sphere(1.0), Vector3(0, 0.32, 0), Vector3(0.98, 0.24, 3.5), hull)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.05
	mast.bottom_radius = 0.09
	mast.height = 6.0
	_part(root, mast, Vector3(0, 3.2, -0.4), Vector3.ONE, wood)
	var main_sail := BoxMesh.new()
	main_sail.size = Vector3(0.06, 3.6, 2.0)
	_part(root, main_sail, Vector3(0.55, 3.6, -0.35), Vector3.ONE, sail)
	var front_sail := BoxMesh.new()
	front_sail.size = Vector3(0.06, 2.4, 1.4)
	_part(root, front_sail, Vector3(-0.4, 2.4, -1.5), Vector3.ONE, sail)
	_foam(root, 3.6)
	return root


func _foam(parent: Node3D, z: float) -> void:
	var mat := _mat(Color(0.92, 0.96, 1.0, 0.6), 0.15, true)
	for i in 3:
		var drop := SphereMesh.new()
		drop.radius = 0.28
		drop.height = 0.56
		_part(parent, drop, Vector3((float(i) - 1.0) * 0.4, -0.05, z), Vector3(1.3, 0.32, 0.7), mat)


func _sphere(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	return mesh


func _part(parent: Node3D, mesh: Mesh, pos: Vector3, scl: Vector3, mat: Material) -> void:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.scale = scl
	n.material_override = mat
	parent.add_child(n)


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


class Boat extends RefCounted:
	var node: Node3D
	var pos: Vector3
	var heading: float
	var speed: float
	var bob: float
