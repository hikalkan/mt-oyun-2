extends CharacterBody3D

signal form_changed(form_label: String)
signal ate_fish(at: Vector3)
signal camera_changed(mode_label: String)
signal got_hurt(left: float)
signal got_downed

const Land := preload("res://scripts/land_bounds.gd")

var pad_id := -1
var body_layer := 2
var hood_layer := 4
var owns_screen := true

var alive := true
var health := 100.0
var _hurt_lock := 0.0
const HEALTH_MAX := 100.0
var fps_mode := false
var run_speed := 16.0
var accel := 28.0
var drag := 18.0
var yaw := 0.0
var pitch := 0.0

var _time := 0.0
var _vy := 0.0
var _grounded := true
var _jump_was := false
var _roar := 0.0
var drinking := false
var _gulp_wait := 0.0
var _jaw: Node3D
var _tail: Node3D
var _legs: Array[Node3D] = []
var _mouth: Area3D
var _mouth_shape: SphereShape3D
var _head: Node3D
var _chase: Camera3D
var _fps: Camera3D
var _hood: MeshInstance3D
var _voice: AudioStreamPlayer3D
var _roar_call: AudioStreamWAV
var _gulp: AudioStreamWAV


func _ready() -> void:
	add_to_group("player")
	collision_layer = 0
	collision_mask = 0
	motion_mode = MOTION_MODE_FLOATING
	_build_body()
	_build_cameras()
	_build_mouth()
	_show_camera()
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 18.0
	_voice.max_distance = 140.0
	_voice.volume_db = 3.0
	add_child(_voice)
	_roar_call = _make_roar()
	_gulp = _make_gulp()
	rotation.y = yaw
	form_changed.emit(form_name())


func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if pad_id >= 0:
		if event is InputEventJoypadButton and event.device == pad_id and event.pressed and not event.is_echo():
			var pad := event as InputEventJoypadButton
			if pad.button_index == JOY_BUTTON_Y:
				_toggle_camera()
			elif pad.button_index == JOY_BUTTON_LEFT_SHOULDER:
				_roar_now()
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch -= event.relative.y * 0.0022
		pitch = clampf(pitch, -0.55, 0.85)
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif key.keycode == KEY_P or key.physical_keycode == KEY_P:
			_toggle_camera()
		elif key.keycode == KEY_K or key.physical_keycode == KEY_K:
			_roar_now()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func heal(amount: float) -> void:
	if not alive:
		return
	health = minf(HEALTH_MAX, health + amount)
	got_hurt.emit(health)


func hurt(amount: float, from_pos: Vector3) -> bool:
	if not alive or _hurt_lock > 0.0:
		return false
	health = maxf(health - amount, 0.0)
	_hurt_lock = 0.85
	var away := global_position - from_pos
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(0, 0, 1)
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	horiz += away.normalized() * 11.0
	velocity.x = horiz.x
	velocity.z = horiz.z
	_vy = 5.0
	_grounded = false
	got_hurt.emit(health)
	if health <= 0.0:
		die()
		got_downed.emit()
	return true


func die() -> void:
	alive = false
	velocity = Vector3.ZERO
	_vy = 0.0


func set_owns_screen(owns: bool) -> void:
	owns_screen = owns
	_show_camera()


func set_partner_body(layer: int) -> void:
	_fps.cull_mask = 1 | hood_layer | layer


func view_camera() -> Camera3D:
	if fps_mode:
		return _fps
	return _chase


func form_name() -> String:
	return "T-Rex"


func camera_name() -> String:
	if fps_mode:
		return "Gözünden"
	return "Arkadan"


func is_shark() -> bool:
	return false


func scare_radius() -> float:
	return 16.0


func scare_power() -> float:
	return 3.2


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if pad_id >= 0:
		var look_x := _joy_axis(JOY_AXIS_RIGHT_X)
		var look_y := _joy_axis(JOY_AXIS_RIGHT_Y)
		yaw -= look_x * 2.4 * delta
		pitch -= look_y * 1.8 * delta
		pitch = clampf(pitch, -0.55, 0.85)
	_time += delta
	if _hurt_lock > 0.0:
		_hurt_lock -= delta
	if _roar > 0.0:
		_roar -= delta
	rotation.y = yaw
	if _head:
		_head.rotation.x = pitch

	var wish := _wish_dir()
	var horiz := Vector3(velocity.x, 0.0, velocity.z)
	drinking = _grounded and Land.in_river(global_position.x, global_position.z)
	var speed := run_speed * (0.68 if drinking else 1.0)
	if wish.length_squared() > 0.001:
		horiz = horiz.move_toward(wish.normalized() * speed, accel * delta)
	else:
		horiz = horiz.move_toward(Vector3.ZERO, drag * delta)
	var jumping := _jump_edge()
	if _grounded and jumping:
		_vy = 10.5
		_grounded = false
	else:
		_vy -= 24.0 * delta
	var pos := global_position
	var next := pos + Vector3(horiz.x, 0.0, horiz.z) * delta
	next = Land.clamp_xz(next, 4.0)
	if not is_equal_approx(next.x, pos.x + horiz.x * delta):
		horiz.x = 0.0
	if not is_equal_approx(next.z, pos.z + horiz.z * delta):
		horiz.z = 0.0
	var floor_y := Land.ground_y(next.x, next.z)
	next.y = pos.y + _vy * delta
	if next.y <= floor_y:
		next.y = floor_y
		if _vy < 0.0:
			_vy = 0.0
		_grounded = true
	global_position = next
	velocity.x = horiz.x
	velocity.z = horiz.z
	drinking = alive and _grounded and Land.in_river(global_position.x, global_position.z)
	if drinking and _roar <= 0.0:
		_gulp_wait -= delta
		if _gulp_wait <= 0.0:
			_gulp_wait = 0.9
			_voice.stream = _gulp
			_voice.pitch_scale = randf_range(0.92, 1.08)
			_voice.volume_db = -6.0
			_voice.play()
	_seat_cameras()
	_animate()


func _wish_dir() -> Vector3:
	var forward := 0.0
	var strafe := 0.0
	if pad_id >= 0:
		forward = -_joy_axis(JOY_AXIS_LEFT_Y)
		strafe = _joy_axis(JOY_AXIS_LEFT_X)
		if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_DPAD_UP):
			forward += 1.0
		if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_DPAD_DOWN):
			forward -= 1.0
		if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_DPAD_RIGHT):
			strafe += 1.0
		if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_DPAD_LEFT):
			strafe -= 1.0
		forward = clampf(forward, -1.0, 1.0)
		strafe = clampf(strafe, -1.0, 1.0)
	else:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			forward += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			forward -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			strafe += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			strafe -= 1.0
	return Basis(Vector3.UP, yaw) * Vector3(strafe, 0.0, -forward)


func _jump_edge() -> bool:
	var held := false
	if pad_id >= 0:
		held = Input.is_joy_button_pressed(pad_id, JOY_BUTTON_A)
	else:
		held = Input.is_physical_key_pressed(KEY_SPACE)
	var edge := held and not _jump_was
	_jump_was = held
	return edge


func _joy_axis(axis: JoyAxis) -> float:
	var value := Input.get_joy_axis(pad_id, axis)
	if absf(value) < 0.2:
		return 0.0
	return value


func _roar_now() -> void:
	_roar = 0.55
	_voice.stream = _roar_call
	_voice.pitch_scale = randf_range(0.92, 1.06)
	_voice.volume_db = 3.0
	_voice.play()


func _make_roar() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.72
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var noise := 918273
	for i in count:
		var t := float(i) / float(rate)
		var env := 1.0
		if t < 0.04:
			env = t / 0.04
		elif t > seconds - 0.22:
			env = clampf((seconds - t) / 0.22, 0.0, 1.0)
		var freq := lerpf(92.0, 48.0, t / seconds) + sin(t * 28.0) * 6.0
		phase += TAU * freq / float(rate)
		noise = (noise * 1103515245 + 12345) & 0x7fffffff
		var grit := float(noise % 20001) / 10000.0 - 1.0
		var sample := sin(phase) * 0.55 + sin(phase * 0.5) * 0.22 + grit * 0.28 * absf(sin(phase))
		sample = clampf(sample * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _make_gulp() -> AudioStreamWAV:
	var rate := 22050
	var seconds := 0.18
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var noise := 135790
	for i in count:
		var t := float(i) / float(rate)
		var env := 1.0
		if t < 0.02:
			env = t / 0.02
		elif t > seconds - 0.06:
			env = clampf((seconds - t) / 0.06, 0.0, 1.0)
		var freq := lerpf(180.0, 90.0, t / seconds)
		phase += TAU * freq / float(rate)
		noise = (noise * 1103515245 + 12345) & 0x7fffffff
		var grit := float(noise % 20001) / 10000.0 - 1.0
		var sample := sin(phase) * 0.25 + grit * 0.55 * env
		sample = clampf(sample * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 22000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _toggle_camera() -> void:
	fps_mode = not fps_mode
	_show_camera()
	camera_changed.emit(camera_name())


func _show_camera() -> void:
	_chase.current = owns_screen and not fps_mode
	_fps.current = owns_screen and fps_mode
	_hood.visible = fps_mode


func _seat_cameras() -> void:
	_chase.position = Vector3(0.0, 4.8, 11.0)
	var lifted := Land.above_ground(_chase.global_position, 1.5)
	if lifted.y > _chase.global_position.y:
		_chase.global_position = lifted
	var ahead := -global_transform.basis.z
	var focus := global_position + Vector3(0.0, 2.3, 0.0) + ahead * 3.2
	focus.y += sin(pitch) * 7.0
	if _chase.global_position.distance_to(focus) > 0.4:
		_chase.look_at(focus, Vector3.UP)
	var eye := Land.above_ground(_fps.global_position, 0.6)
	if eye.y > _fps.global_position.y:
		_fps.global_position = eye


func _animate() -> void:
	var moving := Vector2(velocity.x, velocity.z).length() > 0.8
	var pace := 7.2 if moving else 1.6
	var swing := 0.55 if moving else 0.06
	for i in _legs.size():
		_legs[i].rotation.x = sin(_time * pace + float(i) * PI) * swing
	if _tail:
		var wag := 0.22 if moving else 0.08
		_tail.rotation.y = sin(_time * (4.0 if moving else 1.5)) * wag
		_tail.rotation.x = sin(_time * 8.0) * (0.06 if moving else 0.02)
	if _jaw:
		var open := 0.42 if _roar > 0.0 else (0.28 if drinking else 0.06)
		_jaw.rotation.x = lerpf(_jaw.rotation.x, -open, 0.2)
	if drinking and _head and _roar <= 0.0:
		_head.rotation.x = lerpf(_head.rotation.x, 0.62, 0.18)


func _on_mouth_area(area: Area3D) -> void:
	if not alive or not area.is_in_group("prey"):
		return
	var rel := to_local(area.global_position)
	if rel.z > -0.6:
		return
	if area.call("got_eaten") == true:
		ate_fish.emit(area.global_position)


func _build_mouth() -> void:
	_mouth = Area3D.new()
	_mouth.collision_layer = 0
	_mouth.collision_mask = 1
	_mouth_shape = SphereShape3D.new()
	_mouth_shape.radius = 1.85
	var col := CollisionShape3D.new()
	col.shape = _mouth_shape
	_mouth.add_child(col)
	_mouth.position = Vector3(0.0, 0.95, -2.85)
	add_child(_mouth)
	_mouth.area_entered.connect(_on_mouth_area)


func _build_cameras() -> void:
	_chase = Camera3D.new()
	_chase.fov = 58.0
	_chase.near = 0.15
	_chase.far = 1400.0
	_chase.cull_mask = 0xfffff & ~hood_layer
	add_child(_chase)
	_head = Node3D.new()
	_head.position = Vector3(0.0, 2.45, -1.7)
	add_child(_head)
	_fps = Camera3D.new()
	_fps.fov = 72.0
	_fps.near = 0.05
	_fps.far = 1400.0
	_fps.cull_mask = 1 | hood_layer
	_fps.position = Vector3(0.0, 0.12, -0.7)
	_head.add_child(_fps)
	_hood = _hood_mesh(Color(0.3, 0.42, 0.16), Vector3(0.7, 0.28, 1.15), Vector3(0.0, -0.22, -0.85))
	_fps.add_child(_hood)


func _hood_mesh(color: Color, scl: Vector3, pos: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.scale = scl
	n.position = pos
	n.material_override = _mat(color, 0.45)
	n.layers = hood_layer
	n.visible = false
	return n


func _build_body() -> void:
	var skin := _mat(Color(0.36, 0.48, 0.2), 0.55)
	var dark := _mat(Color(0.2, 0.3, 0.12), 0.62)
	var belly := _mat(Color(0.66, 0.6, 0.38), 0.5)
	var tooth := _mat(Color(0.95, 0.93, 0.86), 0.3)
	_body(self, 0.78, Vector3(0.95, 0.82, 1.65), Vector3(0.0, 1.9, 0.2), skin)
	_body(self, 0.55, Vector3(0.72, 0.42, 1.25), Vector3(0.0, 1.5, 0.25), belly)
	_place(self, _box(Vector3(0.18, 0.16, 1.5)), Vector3(0.0, 2.45, 0.15), Vector3.ZERO, Vector3.ONE, dark)
	_body(self, 0.42, Vector3(0.8, 0.85, 1.05), Vector3(0.0, 2.15, -1.05), skin)
	_body(self, 0.52, Vector3(0.82, 0.7, 1.35), Vector3(0.0, 2.5, -2.15), skin)
	_body(self, 0.28, Vector3(0.7, 0.55, 1.35), Vector3(0.0, 2.28, -3.05), skin)
	_eye(self, Vector3(0.28, 2.72, -2.55))
	_eye(self, Vector3(-0.28, 2.72, -2.55))
	for i in 4:
		_place(self, _box(Vector3(0.06, 0.14, 0.06)), Vector3(-0.12 + float(i) * 0.08, 2.08, -3.45), Vector3.ZERO, Vector3.ONE, tooth)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0.0, 2.12, -2.35)
	add_child(_jaw)
	_body(_jaw, 0.22, Vector3(0.85, 0.45, 1.7), Vector3(0.0, -0.08, -0.85), belly)
	for i in 4:
		_place(_jaw, _box(Vector3(0.05, 0.12, 0.05)), Vector3(-0.12 + float(i) * 0.08, 0.02, -1.15), Vector3.ZERO, Vector3.ONE, tooth)
	_arm(0.62)
	_arm(-0.62)
	_add_leg(0.48, skin, dark)
	_add_leg(-0.48, skin, dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 1.85, 1.35)
	add_child(_tail)
	_body(_tail, 0.42, Vector3(0.7, 0.6, 1.5), Vector3(0.0, 0.05, 0.7), skin)
	_body(_tail, 0.28, Vector3(0.55, 0.45, 1.35), Vector3(0.0, 0.18, 1.7), dark)
	_body(_tail, 0.16, Vector3(0.45, 0.35, 1.2), Vector3(0.0, 0.28, 2.45), dark)


func _arm(side: float) -> void:
	var skin := _mat(Color(0.32, 0.42, 0.18), 0.55)
	_place(self, _box(Vector3(0.1, 0.28, 0.1)), Vector3(side, 1.85, -0.85), Vector3(0.4, 0.0, side * 0.3), Vector3.ONE, skin)
	_place(self, _box(Vector3(0.08, 0.16, 0.08)), Vector3(side * 1.05, 1.62, -1.05), Vector3.ZERO, Vector3.ONE, skin)


func _add_leg(side: float, skin: Material, dark: Material) -> void:
	var hip := Node3D.new()
	hip.position = Vector3(side, 1.45, 0.2)
	add_child(hip)
	_legs.append(hip)
	_place(hip, _box(Vector3(0.32, 0.72, 0.36)), Vector3(0.0, -0.32, 0.0), Vector3.ZERO, Vector3.ONE, skin)
	_place(hip, _box(Vector3(0.26, 0.62, 0.3)), Vector3(0.0, -0.95, 0.06), Vector3.ZERO, Vector3.ONE, dark)
	_place(hip, _box(Vector3(0.36, 0.12, 0.7)), Vector3(0.0, -1.28, -0.16), Vector3.ZERO, Vector3.ONE, dark)


func _eye(parent: Node3D, pos: Vector3) -> void:
	_body(parent, 0.09, Vector3.ONE, pos, _mat(Color(0.95, 0.95, 0.9), 0.25))
	_body(parent, 0.045, Vector3.ONE, pos + Vector3(0.0, 0.0, -0.06), _mat(Color(0.08, 0.06, 0.04), 0.4))


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
	n.layers = body_layer
	parent.add_child(n)


func _mat(color: Color, rough: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	return mat
