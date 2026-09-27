extends Area3D

const Land := preload("res://scripts/land_bounds.gd")
const SkinShader := preload("res://assets/shaders/skin.gdshader")
const AGGRO_DIST := 11.0
const LEASH_DIST := 15.0
const BITE_REACH := 4.0
const MOUTH_FORWARD := 7.6
const WANDER_SPEED := 2.6
const LUNGE_SPEED := 11.0

var bite_damage := 22.0
var _chasing := false
var _vel := Vector3.ZERO
var _wander := Vector3.FORWARD
var _wander_wait := 1.2
var _bite_wait := 0.5
var _tail: Node3D
var _legs: Array[Node3D] = []
var _voice: AudioStreamPlayer3D
var _snarl: AudioStreamWAV


func _ready() -> void:
	add_to_group("titan")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	_wander = _new_wander()
	_build()
	var shape := SphereShape3D.new()
	shape.radius = 3.2
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 3.2, -1.0)
	add_child(col)
	global_position = Land.stand(global_position, 10.0)
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 22.0
	_voice.max_distance = 80.0
	_voice.volume_db = 1.0
	add_child(_voice)
	_snarl = _make_snarl()


func _physics_process(delta: float) -> void:
	if _bite_wait > 0.0:
		_bite_wait -= delta
	if _wander_wait > 0.0:
		_wander_wait -= delta
	var hunter = _nearest_player()
	var desired := _wander * WANDER_SPEED
	var chasing_now := false
	if hunter != null:
		var offset: Vector3 = hunter.global_position - global_position
		offset.y = 0.0
		var dist := offset.length()
		if _chasing and dist > LEASH_DIST:
			_chasing = false
		elif not _chasing and dist < AGGRO_DIST and dist > 0.5:
			_chasing = true
			_voice.stream = _snarl
			_voice.pitch_scale = randf_range(0.94, 1.05)
			_voice.play()
		if _chasing and offset.length_squared() > 0.04:
			chasing_now = true
			desired = offset.normalized() * LUNGE_SPEED
			var mouth := global_position + (-global_transform.basis.z) * MOUTH_FORWARD
			mouth.y = hunter.global_position.y
			if mouth.distance_to(hunter.global_position) < BITE_REACH and _bite_wait <= 0.0:
				if hunter.hurt(bite_damage, global_position):
					_bite_wait = 1.35
	if not chasing_now:
		_chasing = false
		if _wander_wait <= 0.0:
			_wander = _new_wander()
			_wander_wait = randf_range(2.4, 4.8)
		desired = _wander * WANDER_SPEED
	_vel = _vel.move_toward(desired, (7.0 if chasing_now else 3.0) * delta)
	var pos := global_position + Vector3(_vel.x, 0.0, _vel.z) * delta
	var before := pos
	pos = Land.clamp_xz(pos, 12.0)
	if not is_equal_approx(pos.x, before.x):
		_vel.x = 0.0
		_wander.x = -_wander.x
	if not is_equal_approx(pos.z, before.z):
		_vel.z = 0.0
		_wander.z = -_wander.z
	pos.y = Land.ground_y(pos.x, pos.z)
	global_position = pos
	_face()
	_animate()


func _face() -> void:
	var ahead := Vector3(_vel.x, 0.0, _vel.z)
	if ahead.length() < 0.15:
		return
	look_at(global_position + ahead, Vector3.UP)


func _animate() -> void:
	var moving := Vector2(_vel.x, _vel.z).length() > 0.3
	var pace := 3.2 if _chasing else (1.8 if moving else 0.6)
	for i in _legs.size():
		var swing := 0.38 if moving else 0.04
		_legs[i].rotation.x = sin(Time.get_ticks_msec() * 0.001 * pace * 3.0 + float(i) * PI) * swing
	if _tail:
		_tail.rotation.y = sin(Time.get_ticks_msec() * 0.004) * (0.18 if moving else 0.06)


func _nearest_player():
	var best = null
	var best_d := 1.0e20
	for who in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(who) or not who.alive:
			continue
		var flat: Vector3 = global_position - who.global_position
		flat.y = 0.0
		var dist: float = flat.length_squared()
		if dist < best_d:
			best_d = dist
			best = who
	return best


func _new_wander() -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()


func _make_snarl() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.38
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var noise := 445566
	for i in count:
		var t := float(i) / float(rate)
		var env := 1.0
		if t < 0.03:
			env = t / 0.03
		elif t > seconds - 0.1:
			env = clampf((seconds - t) / 0.1, 0.0, 1.0)
		var freq := lerpf(70.0, 40.0, t / seconds)
		phase += TAU * freq / float(rate)
		noise = (noise * 1103515245 + 12345) & 0x7fffffff
		var grit := float(noise % 20001) / 10000.0 - 1.0
		var sample := sin(phase) * 0.5 + grit * 0.35 * absf(sin(phase * 1.7))
		sample = clampf(sample * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 28000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _build() -> void:
	var skin := _mat(Color(0.32, 0.16, 0.14))
	var dark := _mat(Color(0.14, 0.07, 0.07))
	var belly := _mat(Color(0.55, 0.4, 0.32))
	var tooth := _plain(Color(0.94, 0.9, 0.8))
	_body(self, 1.35, Vector3(1.15, 1.05, 2.15), Vector3(0.0, 3.4, 0.4), skin)
	_body(self, 0.9, Vector3(0.85, 0.45, 1.6), Vector3(0.0, 2.5, 0.5), belly)
	_place(self, _box(Vector3(0.35, 0.28, 3.2)), Vector3(0.0, 4.7, 0.2), Vector3.ZERO, Vector3.ONE, dark)
	_body(self, 0.85, Vector3(0.9, 0.95, 1.2), Vector3(0.0, 4.0, -2.4), skin)
	_body(self, 1.05, Vector3(0.95, 0.8, 1.55), Vector3(0.0, 4.5, -4.6), skin)
	_body(self, 0.62, Vector3(0.75, 0.6, 1.7), Vector3(0.0, 4.15, -6.5), dark)
	_eye(Vector3(0.55, 5.05, -5.3))
	_eye(Vector3(-0.55, 5.05, -5.3))
	for i in 5:
		var x := -0.36 + float(i) * 0.18
		_place(self, _box(Vector3(0.1, 0.32, 0.1)), Vector3(x, 3.7, -7.55), Vector3.ZERO, Vector3.ONE, tooth)
		_place(self, _box(Vector3(0.08, 0.28, 0.08)), Vector3(x, 3.35, -7.45), Vector3.ZERO, Vector3.ONE, tooth)
	_arm(1.35, skin)
	_arm(-1.35, skin)
	_add_leg(1.05, skin, dark)
	_add_leg(-1.05, skin, dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 3.5, 2.8)
	add_child(_tail)
	_body(_tail, 0.85, Vector3(0.8, 0.7, 1.8), Vector3(0.0, 0.15, 1.3), skin)
	_body(_tail, 0.55, Vector3(0.65, 0.55, 1.7), Vector3(0.0, 0.45, 3.1), dark)
	_body(_tail, 0.32, Vector3(0.5, 0.4, 1.5), Vector3(0.0, 0.7, 4.6), dark)


func _arm(side: float, skin: Material) -> void:
	_place(self, _box(Vector3(0.22, 0.7, 0.22)), Vector3(side, 3.3, -1.6), Vector3(0.5, 0.0, side * 0.2), Vector3.ONE, skin)
	_place(self, _box(Vector3(0.16, 0.4, 0.16)), Vector3(side * 1.15, 2.85, -2.05), Vector3.ZERO, Vector3.ONE, skin)


func _add_leg(side: float, skin: Material, dark: Material) -> void:
	var hip := Node3D.new()
	hip.position = Vector3(side, 2.6, 0.3)
	add_child(hip)
	_legs.append(hip)
	_place(hip, _box(Vector3(0.7, 1.35, 0.75)), Vector3(0.0, -0.6, 0.0), Vector3.ZERO, Vector3.ONE, skin)
	_place(hip, _box(Vector3(0.55, 1.15, 0.6)), Vector3(0.0, -1.7, 0.1), Vector3.ZERO, Vector3.ONE, dark)
	_place(hip, _box(Vector3(0.8, 0.22, 1.45)), Vector3(0.0, -2.35, -0.35), Vector3.ZERO, Vector3.ONE, dark)


func _eye(pos: Vector3) -> void:
	_body(self, 0.16, Vector3.ONE, pos, _plain(Color(0.72, 0.1, 0.08)))
	_body(self, 0.07, Vector3.ONE, pos + Vector3(0.0, 0.0, -0.1), _plain(Color(0.05, 0.02, 0.02)))


func _body(parent: Node3D, radius: float, scl: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
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


func _mat(color: Color) -> Material:
	var mat := ShaderMaterial.new()
	mat.shader = SkinShader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("roughness_amt", 0.58)
	return mat


func _plain(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.32
	mat.metallic_specular = 0.5
	return mat
