extends Node3D

const Land := preload("res://scripts/land_bounds.gd")

var _trees: Array[Node3D] = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 270927
	_trees_build(rng)
	_bushes(rng)
	_rocks(rng)
	_ferns(rng)


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for i in _trees.size():
		var tree := _trees[i]
		tree.rotation.z = sin(t * 0.6 + float(i) * 0.7) * 0.03
		tree.rotation.x = cos(t * 0.45 + float(i) * 0.5) * 0.02


func _trees_build(rng: RandomNumberGenerator) -> void:
	var paints: Array[Color] = [
		Color(0.16, 0.48, 0.2),
		Color(0.22, 0.55, 0.24),
		Color(0.12, 0.38, 0.18),
		Color(0.28, 0.5, 0.16),
	]
	for i in 48:
		var at := _spot(rng, 14.0)
		var h := rng.randf_range(4.2, 9.5)
		_trees.append(_tree(at, h, paints[i % paints.size()], rng))


func _bushes(rng: RandomNumberGenerator) -> void:
	var paints: Array[Color] = [
		Color(0.2, 0.5, 0.18),
		Color(0.34, 0.58, 0.16),
		Color(0.45, 0.62, 0.18),
	]
	for i in 32:
		var at := _spot(rng, 10.0)
		_bush(at, paints[i % paints.size()], rng)


func _rocks(rng: RandomNumberGenerator) -> void:
	var mat := _mat(Color(0.45, 0.44, 0.4), 0.9)
	for i in 24:
		var at := _spot(rng, 12.0)
		var rock := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.6, 1.8)
		mesh.height = mesh.radius * 2.0
		rock.mesh = mesh
		rock.material_override = mat
		rock.scale = Vector3(rng.randf_range(1.2, 2.2), rng.randf_range(0.45, 0.85), rng.randf_range(1.1, 1.9))
		rock.position = at + Vector3(0.0, mesh.radius * rock.scale.y * 0.35, 0.0)
		add_child(rock)


func _ferns(rng: RandomNumberGenerator) -> void:
	for i in 8:
		var at := _spot(rng, 16.0)
		_fern(at, rng)


func _spot(rng: RandomNumberGenerator, clear: float) -> Vector3:
	var x := rng.randf_range(-Land.HALF + 16.0, Land.HALF - 16.0)
	var z := rng.randf_range(-Land.HALF + 16.0, Land.HALF - 16.0)
	for _try in 8:
		x = rng.randf_range(-Land.HALF + 16.0, Land.HALF - 16.0)
		z = rng.randf_range(-Land.HALF + 16.0, Land.HALF - 16.0)
		if Vector2(x, z).length() >= clear:
			break
	return Vector3(x, Land.ground_y(x, z), z)


func _tree(at: Vector3, height: float, leaf: Color, rng: RandomNumberGenerator) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	add_child(pivot)
	var trunk := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = rng.randf_range(0.18, 0.32)
	mesh.bottom_radius = mesh.top_radius * 1.45
	mesh.height = height * 0.62
	mesh.radial_segments = 8
	trunk.mesh = mesh
	trunk.position = Vector3(0.0, mesh.height * 0.5, 0.0)
	trunk.material_override = _mat(Color(0.38, 0.26, 0.12), 0.85)
	pivot.add_child(trunk)
	var crown := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = rng.randf_range(1.3, 2.2)
	ball.height = ball.radius * 2.1
	crown.mesh = ball
	crown.position = Vector3(0.0, height * 0.72, 0.0)
	crown.scale = Vector3(1.0, 1.15, 1.0)
	crown.material_override = _mat(leaf, 0.7)
	pivot.add_child(crown)
	var puff := MeshInstance3D.new()
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = ball.radius * 0.72
	puff_mesh.height = puff_mesh.radius * 2.0
	puff.mesh = puff_mesh
	puff.position = Vector3(rng.randf_range(-0.6, 0.6), height * 0.84, rng.randf_range(-0.5, 0.5))
	puff.material_override = _mat(leaf.lightened(0.12), 0.65)
	pivot.add_child(puff)
	return pivot


func _bush(at: Vector3, color: Color, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	var mat := _mat(color, 0.75)
	for i in 4:
		var ball := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = rng.randf_range(0.35, 0.7)
		mesh.height = mesh.radius * 2.0
		ball.mesh = mesh
		ball.material_override = mat
		ball.position = Vector3(rng.randf_range(-0.55, 0.55), mesh.radius * 0.75, rng.randf_range(-0.55, 0.55))
		root.add_child(ball)


func _fern(at: Vector3, rng: RandomNumberGenerator) -> void:
	var root := Node3D.new()
	root.position = at
	root.rotation.y = rng.randf() * TAU
	add_child(root)
	var mat := _mat(Color(0.18, 0.55, 0.22), 0.6)
	for i in 5:
		var leaf := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.18, 0.04, 1.15)
		leaf.mesh = mesh
		leaf.material_override = mat
		leaf.position = Vector3(0.0, 0.35, 0.35)
		leaf.rotation = Vector3(rng.randf_range(-0.5, -0.15), float(i) * TAU / 5.0, 0.0)
		root.add_child(leaf)


func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat
