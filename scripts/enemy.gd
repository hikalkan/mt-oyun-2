extends Area3D

enum Kind { SHARK, DOG, FISH }

const Bounds := preload("res://scripts/sea_bounds.gd")

var kind := Kind.SHARK
var speed := 7.2
var bite_damage := 18.0
var bite_range := 2.5
var _bite_wait := 0.8
var _flee := 0.0
var _vel := Vector3.ZERO
var _tail: Node3D
var giant := false
var _voice: AudioStreamPlayer3D
var _call_wait := 3.0
const _snarl: AudioStream = preload("res://assets/audio/shark.ogg")


func setup(next_kind: Kind) -> void:
	kind = next_kind
	match kind:
		Kind.SHARK:
			speed = 7.2
			bite_damage = 18.0
			bite_range = 2.5
		Kind.DOG:
			speed = 6.4
			bite_damage = 14.0
			bite_range = 1.75
		_:
			speed = 8.3
			bite_damage = 10.0
			bite_range = 1.55


func make_giant() -> void:
	giant = true
	speed = 11.5
	bite_damage = 36.0
	bite_range = 15.0


func _ready() -> void:
	add_to_group("enemy")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	var shape := SphereShape3D.new()
	shape.radius = 1.35 if giant else (1.2 if kind == Kind.SHARK else 0.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	if kind == Kind.SHARK:
		_build_shark()
	elif kind == Kind.DOG:
		_build_dog()
	else:
		_build_fish()
	if giant:
		scale = Vector3(10.0, 10.0, 10.0)
		_voice = AudioStreamPlayer3D.new()
		_voice.stream = _snarl
		_voice.unit_size = 28.0
		_voice.max_distance = 180.0
		_voice.volume_db = 6.0
		add_child(_voice)


func _physics_process(delta: float) -> void:
	if _bite_wait > 0.0:
		_bite_wait -= delta
	if _flee > 0.0:
		_flee -= delta
	if _call_wait > 0.0:
		_call_wait -= delta
	var hunter = _nearest_player()
	var desired := Vector3.ZERO
	if hunter != null:
		var offset: Vector3 = hunter.global_position - global_position
		var dist := offset.length()
		if _flee > 0.0:
			offset = -offset
		if offset.length_squared() > 0.04:
			var rush := speed + (1.5 if _flee <= 0.0 and dist < (48.0 if giant else 14.0) else 0.0)
			desired = offset.normalized() * rush
		if _flee <= 0.0 and dist < bite_range and _bite_wait <= 0.0:
			if hunter.hurt(bite_damage, global_position):
				_bite_wait = 1.25
		if giant and dist < 55.0 and _call_wait <= 0.0 and _voice:
			_voice.pitch_scale = randf_range(0.48, 0.58)
			_voice.play()
			_call_wait = randf_range(7.0, 11.0)
	_vel = _vel.move_toward(desired, (3.4 if giant else 5.5) * delta)
	global_position += _vel * delta
	global_position = Bounds.clamp_pos(global_position, 20.0 if giant else 2.4)
	_face()
	if _tail:
		var wag := 0.005 if giant else 0.011
		_tail.rotation.y = sin(Time.get_ticks_msec() * wag) * 0.45


func bonk(from_pos: Vector3) -> bool:
	if _flee > 0.0:
		return false
	_flee = 3.2
	_bite_wait = 1.4
	var away := global_position - from_pos
	away.y *= 0.3
	if away.length_squared() < 0.04:
		away = Vector3(0, 0.2, 1)
	_vel = away.normalized() * (speed + 7.0)
	return true


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


func _face() -> void:
	if _vel.length() < 0.25:
		return
	var ahead := _vel.normalized()
	var up := Vector3.UP
	if absf(ahead.dot(Vector3.UP)) > 0.92:
		up = Vector3.FORWARD
	look_at(global_position + ahead, up)


func _build_shark() -> void:
	var gray := _mat(Color(0.1, 0.11, 0.14) if giant else Color(0.22, 0.24, 0.28))
	var dark := _mat(Color(0.05, 0.05, 0.07) if giant else Color(0.1, 0.11, 0.13))
	var belly := _mat(Color(0.72, 0.7, 0.66) if giant else Color(0.82, 0.8, 0.78))
	_body(self, 0.55, Vector3(0.9, 0.72, 2.05), Vector3(0, 0, 0.1), gray)
	_body(self, 0.34, Vector3(0.75, 0.42, 1.3), Vector3(0, -0.16, 0.15), belly)
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.34
	nose.height = 0.85
	nose.radial_segments = 14
	_place(self, nose, Vector3(0, 0, -1.15), Vector3(deg_to_rad(-90.0), 0, 0), Vector3.ONE, gray)
	_place(self, _box(Vector3(0.08, 0.7, 0.32)), Vector3(0, 0.52, 0.05), Vector3.ZERO, Vector3.ONE, dark)
	_place(self, _box(Vector3(0.08, 0.38, 0.26)), Vector3(-0.46, -0.12, 0.15), Vector3(0, 0, 0.55), Vector3.ONE, dark)
	_place(self, _box(Vector3(0.08, 0.38, 0.26)), Vector3(0.46, -0.12, 0.15), Vector3(0, 0, -0.55), Vector3.ONE, dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0, 1.05)
	add_child(_tail)
	_place(_tail, _box(Vector3(0.08, 0.7, 0.32)), Vector3(0, 0.22, 0.32), Vector3(0.35, 0, 0), Vector3.ONE, gray)
	_place(_tail, _box(Vector3(0.08, 0.34, 0.22)), Vector3(0, -0.1, 0.26), Vector3(-0.2, 0, 0), Vector3.ONE, gray)
	_eye(Vector3(0.24, 0.08, -0.62), Color(0.9, 0.08, 0.06))
	_eye(Vector3(-0.24, 0.08, -0.62), Color(0.9, 0.08, 0.06))
	if giant:
		var tooth := _mat(Color(0.95, 0.93, 0.86))
		for i in 6:
			_place(self, _box(Vector3(0.045, 0.2, 0.04)), Vector3(-0.16 + float(i) * 0.064, -0.28, -1.42), Vector3.ZERO, Vector3.ONE, tooth)


func _build_dog() -> void:
	var fur := _mat(Color(0.55, 0.32, 0.14))
	var dark := _mat(Color(0.28, 0.15, 0.08))
	var ear := _mat(Color(0.4, 0.2, 0.1))
	_body(self, 0.42, Vector3(0.85, 0.7, 1.35), Vector3(0, 0, 0.15), fur)
	_body(self, 0.28, Vector3(1, 0.9, 1), Vector3(0, 0.16, -0.55), fur)
	_body(self, 0.12, Vector3(0.7, 0.55, 1.3), Vector3(0, 0.05, -0.88), dark)
	_body(self, 0.1, Vector3(0.35, 1.15, 0.45), Vector3(-0.16, 0.42, -0.5), ear)
	_body(self, 0.1, Vector3(0.35, 1.15, 0.45), Vector3(0.16, 0.42, -0.5), ear)
	_place(self, _box(Vector3(0.46, 0.1, 0.12)), Vector3(0, 0.08, -0.42), Vector3.ZERO, Vector3.ONE, _mat(Color(0.82, 0.12, 0.1)))
	for side in [-1.0, 1.0]:
		_place(self, _box(Vector3(0.1, 0.12, 0.28)), Vector3(side * 0.28, -0.28, -0.15), Vector3.ZERO, Vector3.ONE, dark)
		_place(self, _box(Vector3(0.1, 0.12, 0.28)), Vector3(side * 0.28, -0.28, 0.4), Vector3.ZERO, Vector3.ONE, dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.12, 0.72)
	add_child(_tail)
	_place(_tail, _box(Vector3(0.08, 0.08, 0.42)), Vector3(0, 0.12, 0.18), Vector3(-0.6, 0, 0), Vector3.ONE, fur)
	_eye(Vector3(0.12, 0.22, -0.72), Color(0.08, 0.08, 0.08))
	_eye(Vector3(-0.12, 0.22, -0.72), Color(0.08, 0.08, 0.08))
	_body(self, 0.045, Vector3.ONE, Vector3(0, 0.06, -1.02), _mat(Color(0.08, 0.05, 0.04)))


func _build_fish() -> void:
	var body := _mat(Color(0.72, 0.12, 0.16))
	var dark := _mat(Color(0.35, 0.05, 0.08))
	var belly := _mat(Color(0.95, 0.45, 0.28))
	_body(self, 0.32, Vector3(0.7, 0.55, 2.4), Vector3(0, 0, 0.05), body)
	_body(self, 0.18, Vector3(0.55, 0.35, 1.5), Vector3(0, -0.1, 0.05), belly)
	_place(self, _box(Vector3(0.06, 0.42, 0.28)), Vector3(0, 0.32, -0.05), Vector3.ZERO, Vector3.ONE, dark)
	_place(self, _box(Vector3(0.22, 0.08, 0.16)), Vector3(0, -0.02, -0.72), Vector3.ZERO, Vector3.ONE, _mat(Color(0.95, 0.9, 0.85)))
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0, 0.72)
	add_child(_tail)
	_place(_tail, _box(Vector3(0.05, 0.42, 0.28)), Vector3(0, 0.08, 0.2), Vector3.ZERO, Vector3.ONE, dark)
	_eye(Vector3(0.14, 0.06, -0.42), Color(0.95, 0.85, 0.15))
	_eye(Vector3(-0.14, 0.06, -0.42), Color(0.95, 0.85, 0.15))


func _eye(pos: Vector3, color: Color) -> void:
	_body(self, 0.06, Vector3.ONE, pos, _mat(color))
	_body(self, 0.03, Vector3.ONE, pos + Vector3(0, 0, -0.035), _mat(Color(0.04, 0.02, 0.02)))


func _body(parent: Node3D, radius: float, scl: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
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
	mat.roughness = 0.45
	return mat
