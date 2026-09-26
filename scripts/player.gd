extends CharacterBody3D

signal form_changed(form_label: String)
signal ate_fish(at: Vector3)
signal camera_changed(mode_label: String)
signal got_hurt(left: float)
signal got_downed

enum Form { WHALE, SHARK }

const Bounds := preload("res://scripts/sea_bounds.gd")
var pad_id := -1
var body_layer := 2
var hood_layer := 4
var owns_screen := true

var form := Form.WHALE
var alive := true
var health := 100.0
var _hurt_lock := 0.0
const HEALTH_MAX := 100.0
var fps_mode := false
var swim_speed := 11.0
var accel := 7.0
var drag := 4.0
var yaw := 0.0
var pitch := 0.0

var _time := 0.0
var _switch_lock := 0.0
var _whale_fluke: Node3D
var _shark_tail: Node3D
var _jets: Array[MeshInstance3D] = []
var _spout: CPUParticles3D
var _mouth: Area3D
var _mouth_shape: SphereShape3D
var _pitch: Node3D
var _whale: Node3D
var _shark: Node3D
var _whale_hood: MeshInstance3D
var _shark_hood: MeshInstance3D
var _chase: Camera3D
var _fps: Camera3D
var _voice: AudioStreamPlayer3D
var _whale_call: AudioStreamWAV
var _shark_call: AudioStreamWAV


func _ready() -> void:
	add_to_group("player")
	motion_mode = MOTION_MODE_FLOATING
	_pitch = Node3D.new()
	add_child(_pitch)
	_build_whale()
	_build_shark()
	_build_cameras()
	_build_mouth()
	_build_spout()
	_build_jets()
	_apply_form()
	_show_camera()
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 14.0
	_voice.max_distance = 120.0
	_voice.volume_db = 2.0
	add_child(_voice)
	_whale_call = _make_call(true)
	_shark_call = _make_call(false)


func _unhandled_input(event: InputEvent) -> void:
	if not alive:
		return
	if pad_id >= 0:
		if event is InputEventJoypadButton and event.device == pad_id and event.pressed and not event.is_echo():
			var pad := event as InputEventJoypadButton
			if pad.button_index == JOY_BUTTON_X:
				_switch_form()
			elif pad.button_index == JOY_BUTTON_Y:
				_toggle_camera()
			elif pad.button_index == JOY_BUTTON_LEFT_SHOULDER:
				_speak()
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.003
		pitch -= event.relative.y * 0.0026
		pitch = clampf(pitch, -1.05, 1.05)
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_ESCAPE or key.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif key.keycode == KEY_M or key.physical_keycode == KEY_M:
			_switch_form()
		elif key.keycode == KEY_P or key.physical_keycode == KEY_P:
			_toggle_camera()
		elif key.keycode == KEY_K or key.physical_keycode == KEY_K:
			_speak()


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
	if form == Form.WHALE:
		amount *= 0.65
	health = maxf(health - amount, 0.0)
	_hurt_lock = 0.8
	var away := global_position - from_pos
	away.y *= 0.35
	if away.length_squared() < 0.01:
		away = Vector3(0, 0, 1)
	velocity += away.normalized() * 7.0
	got_hurt.emit(health)
	if health <= 0.0:
		die()
		got_downed.emit()
	return true


func die() -> void:
	alive = false
	velocity = Vector3.ZERO
	if _spout:
		_spout.emitting = false
	for jet in _jets:
		jet.visible = false


func begin_as_shark() -> void:
	form = Form.SHARK
	_apply_form()
	form_changed.emit(form_name())


func set_owns_screen(owns: bool) -> void:
	owns_screen = owns
	_show_camera()


func set_partner_body(layer: int) -> void:
	_fps.cull_mask = 1 | hood_layer | layer


func view_camera() -> Camera3D:
	if fps_mode:
		return _fps
	return _chase


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if pad_id >= 0:
		var look_x := _joy_axis(JOY_AXIS_RIGHT_X)
		var look_y := _joy_axis(JOY_AXIS_RIGHT_Y)
		yaw -= look_x * 2.5 * delta
		pitch -= look_y * 2.0 * delta
		pitch = clampf(pitch, -1.05, 1.05)
	_time += delta
	if _hurt_lock > 0.0:
		_hurt_lock -= delta
	if _switch_lock > 0.0:
		_switch_lock -= delta
	rotation.y = yaw
	_pitch.rotation.x = pitch

	var wish := _wish_dir()
	if wish.length_squared() > 0.001:
		velocity = velocity.move_toward(wish.normalized() * swim_speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, drag * delta)
	move_and_slide()
	_aim_chase()
	var clamped := Bounds.clamp_pos(global_position)
	if not is_equal_approx(clamped.x, global_position.x):
		velocity.x = 0.0
	if not is_equal_approx(clamped.y, global_position.y):
		velocity.y = 0.0
	if not is_equal_approx(clamped.z, global_position.z):
		velocity.z = 0.0
	global_position = clamped

	_animate()


func _wish_dir() -> Vector3:
	if pad_id >= 0:
		return _pad_dir()
	return _key_dir()


func _key_dir() -> Vector3:
	var forward := 0.0
	var strafe := 0.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		forward += 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		forward -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		strafe += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		strafe -= 1.0
	var dir := _pitch.global_transform.basis * Vector3(strafe, 0.0, -forward)
	if Input.is_physical_key_pressed(KEY_SPACE):
		dir += Vector3.UP
	if Input.is_physical_key_pressed(KEY_CTRL):
		dir += Vector3.DOWN
	return dir


func _pad_dir() -> Vector3:
	var forward := -_joy_axis(JOY_AXIS_LEFT_Y)
	var strafe := _joy_axis(JOY_AXIS_LEFT_X)
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
	var dir := _pitch.global_transform.basis * Vector3(strafe, 0.0, -forward)
	if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_A) or _joy_axis(JOY_AXIS_TRIGGER_RIGHT) > 0.45:
		dir += Vector3.UP
	if Input.is_joy_button_pressed(pad_id, JOY_BUTTON_B) or _joy_axis(JOY_AXIS_TRIGGER_LEFT) > 0.45:
		dir += Vector3.DOWN
	return dir


func _joy_axis(axis: JoyAxis) -> float:
	var value := Input.get_joy_axis(pad_id, axis)
	if absf(value) < 0.2:
		return 0.0
	return value


func _q_held() -> bool:
	if pad_id >= 0:
		return Input.is_joy_button_pressed(pad_id, JOY_BUTTON_RIGHT_SHOULDER)
	return Input.is_physical_key_pressed(KEY_Q)


func _speak() -> void:
	_voice.stream = _whale_call if form == Form.WHALE else _shark_call
	_voice.pitch_scale = randf_range(0.94, 1.06)
	_voice.play()


func _make_call(whale: bool) -> AudioStreamWAV:
	var rate := 22050
	var seconds := 1.4 if whale else 0.48
	var count := int(rate * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var phase := 0.0
	var noise := 246813
	for i in count:
		var t := float(i) / float(rate)
		var attack := 0.09 if whale else 0.02
		var release := 0.4 if whale else 0.1
		var env := 1.0
		if t < attack:
			env = t / attack
		elif t > seconds - release:
			env = clampf((seconds - t) / release, 0.0, 1.0)
		var sample := 0.0
		if whale:
			var freq := lerpf(155.0, 62.0, t / seconds) + sin(t * 13.0) * 7.0
			phase += TAU * freq / float(rate)
			sample = sin(phase) * 0.7 + sin(phase * 2.0) * 0.16 + sin(phase * 0.5) * 0.14
		else:
			var freq := lerpf(240.0, 85.0, t / seconds)
			phase += TAU * freq / float(rate)
			noise = (noise * 1103515245 + 12345) & 0x7fffffff
			var grit := float(noise % 20001) / 10000.0 - 1.0
			sample = sin(phase) * 0.45 + sin(phase * 2.4) * 0.22 + grit * 0.32 * absf(sin(phase))
		sample = clampf(sample * env, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


func _switch_form() -> void:
	if _switch_lock > 0.0:
		return
	_switch_lock = 0.35
	form = Form.SHARK if form == Form.WHALE else Form.WHALE
	_apply_form()
	form_changed.emit(form_name())


func _toggle_camera() -> void:
	fps_mode = not fps_mode
	_show_camera()
	camera_changed.emit(camera_name())


func _show_camera() -> void:
	_chase.current = owns_screen and not fps_mode
	_fps.current = owns_screen and fps_mode
	_whale_hood.visible = fps_mode and form == Form.WHALE
	_shark_hood.visible = fps_mode and form == Form.SHARK


func _apply_form() -> void:
	var whale := form == Form.WHALE
	_whale.visible = whale
	_shark.visible = not whale
	if whale:
		swim_speed = 11.0
		accel = 7.5
		drag = 3.5
		_mouth.position = Vector3(0.0, 0.1, -2.4)
		_mouth_shape.radius = 1.35
		_chase.position = Vector3(0.0, 2.4, 9.0)
		_fps.position = Vector3(0.0, 0.28, -2.05)
		_spout.position = Vector3(0.0, 0.85, -0.2)
	else:
		swim_speed = 20.0
		accel = 16.0
		drag = 7.0
		_mouth.position = Vector3(0.0, 0.0, -1.55)
		_mouth_shape.radius = 0.62
		_chase.position = Vector3(0.0, 1.5, 5.6)
		_fps.position = Vector3(0.0, 0.08, -1.25)
	_spout.emitting = false
	_show_camera()


func _aim_chase() -> void:
	var focus := _pitch.to_global(Vector3(0.0, 0.2, -1.0))
	if _chase.global_position.distance_to(focus) > 0.3:
		_chase.look_at(focus, Vector3.UP)


func _animate() -> void:
	var moving := velocity.length() > 0.4
	var wag := 0.55 if moving else 0.22
	if _whale_fluke:
		_whale_fluke.rotation.x = sin(_time * (2.2 if moving else 1.1)) * wag
	if _shark_tail:
		_shark_tail.rotation.y = sin(_time * (5.5 if moving else 2.4)) * (0.45 if moving else 0.18)
	var spray := form == Form.WHALE and _q_held()
	_spout.emitting = spray
	for i in _jets.size():
		var jet := _jets[i]
		jet.visible = spray
		if spray:
			var h := fmod(_time * 4.5 + float(i) * 0.38, 2.6)
			jet.position = Vector3(sin(float(i) * 1.7) * 0.06, 0.72 + h, -0.15)
			var s := 0.45 + h * 0.28
			jet.scale = Vector3(s, s, s)


func _on_mouth_area(area: Area3D) -> void:
	if not alive:
		return
	var rel := _pitch.to_local(area.global_position)
	if rel.z > 0.35:
		return
	if area.is_in_group("enemy"):
		if area.call("bonk", global_position) == true:
			heal(10.0)
		return
	if not area.is_in_group("fish"):
		return
	if area.call("got_eaten") == true:
		ate_fish.emit(area.global_position)


func form_name() -> String:
	if form == Form.WHALE:
		return "Mavi balina"
	return "Köpekbalığı"


func camera_name() -> String:
	if fps_mode:
		return "Gözünden"
	return "Arkadan"


func is_shark() -> bool:
	return form == Form.SHARK


func scare_radius() -> float:
	return 6.0 if is_shark() else 4.2


func scare_power() -> float:
	return 2.4 if is_shark() else 1.2


func _build_mouth() -> void:
	_mouth = Area3D.new()
	_mouth.collision_layer = 0
	_mouth.collision_mask = 1
	_mouth_shape = SphereShape3D.new()
	_mouth_shape.radius = 1.45
	var col := CollisionShape3D.new()
	col.shape = _mouth_shape
	_mouth.add_child(col)
	_pitch.add_child(_mouth)
	_mouth.area_entered.connect(_on_mouth_area)


func _build_spout() -> void:
	_spout = CPUParticles3D.new()
	_spout.amount = 48
	_spout.lifetime = 1.15
	_spout.explosiveness = 0.15
	_spout.direction = Vector3(0, 1, 0)
	_spout.spread = 16.0
	_spout.gravity = Vector3(0, 1.2, 0)
	_spout.initial_velocity_min = 5.0
	_spout.initial_velocity_max = 9.0
	_spout.scale_amount_min = 0.35
	_spout.scale_amount_max = 0.9
	_spout.emitting = false
	_spout.local_coords = false
	var drop := SphereMesh.new()
	drop.radius = 0.16
	drop.height = 0.32
	drop.material = _mat(Color(0.9, 0.97, 1.0, 0.55), 0.1, true)
	_spout.mesh = drop
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.set_color(1, Color(1, 1, 1, 0))
	ramp.add_point(0.15, Color(1, 1, 1, 0.85))
	_spout.color_ramp = ramp
	_whale.add_child(_spout)


func _build_jets() -> void:
	var mat := _mat(Color(0.88, 0.96, 1.0, 0.8), 0.05, true)
	for i in 8:
		var jet := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.16
		mesh.height = 0.32
		jet.mesh = mesh
		jet.material_override = mat
		jet.visible = false
		_whale.add_child(jet)
		_jets.append(jet)


func _build_cameras() -> void:
	_chase = Camera3D.new()
	_chase.fov = 58.0
	_chase.near = 0.15
	_chase.far = 1400.0
	_chase.cull_mask = 0xfffff & ~hood_layer
	_pitch.add_child(_chase)
	_fps = Camera3D.new()
	_fps.fov = 72.0
	_fps.near = 0.04
	_fps.far = 1400.0
	_fps.cull_mask = 1 | hood_layer
	_pitch.add_child(_fps)
	_whale_hood = _hood(Color(0.16, 0.4, 0.78), Vector3(0.9, 0.14, 0.35), Vector3(0, -0.42, -1.35))
	_shark_hood = _hood(Color(0.45, 0.48, 0.52), Vector3(0.28, 0.08, 0.55), Vector3(0, -0.28, -0.95))
	_fps.add_child(_whale_hood)
	_fps.add_child(_shark_hood)


func _hood(color: Color, scl: Vector3, pos: Vector3) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 0.45
	mesh.height = 0.9
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.scale = scl
	n.position = pos
	n.material_override = _mat(color, 0.35, false)
	n.layers = hood_layer
	n.visible = false
	return n


func _build_whale() -> void:
	_whale = Node3D.new()
	_whale.scale = Vector3(1.15, 1.15, 1.15)
	_pitch.add_child(_whale)
	var blue := _mat(Color(0.14, 0.38, 0.78), 0.28, false)
	var deep := _mat(Color(0.08, 0.22, 0.5), 0.35, false)
	var belly := _mat(Color(0.88, 0.92, 0.96), 0.4, false)
	_body(_whale, 0.85, Vector3(0.78, 0.5, 3.1), Vector3(0, 0, -0.15), blue)
	_body(_whale, 0.62, Vector3(0.62, 0.32, 1.7), Vector3(0, -0.28, -0.05), belly)
	_body(_whale, 0.28, Vector3(0.65, 0.5, 1.6), Vector3(0, 0.02, 1.55), deep)
	_whale_fluke = Node3D.new()
	_whale_fluke.position = Vector3(0, 0.02, 1.85)
	_whale.add_child(_whale_fluke)
	_body(_whale_fluke, 0.42, Vector3(2.5, 0.16, 0.8), Vector3(0, 0, 0.22), blue)
	_place(_whale, _box(Vector3(0.12, 0.95, 0.38)), Vector3(-0.72, -0.2, 0.15), Vector3(0, 0, 0.7), Vector3.ONE, deep)
	_place(_whale, _box(Vector3(0.12, 0.95, 0.38)), Vector3(0.72, -0.2, 0.15), Vector3(0, 0, -0.7), Vector3.ONE, deep)
	_place(_whale, _box(Vector3(0.12, 0.38, 0.28)), Vector3(0, 0.62, 0.25), Vector3.ZERO, Vector3.ONE, deep)
	_eye(_whale, Vector3(0.42, 0.12, -0.82))
	_eye(_whale, Vector3(-0.42, 0.12, -0.82))


func _build_shark() -> void:
	_shark = Node3D.new()
	_pitch.add_child(_shark)
	var gray := _mat(Color(0.52, 0.55, 0.6), 0.32, false)
	var dark := _mat(Color(0.32, 0.35, 0.4), 0.4, false)
	var belly := _mat(Color(0.9, 0.91, 0.9), 0.45, false)
	_body(_shark, 0.42, Vector3(0.85, 0.7, 1.85), Vector3(0, 0, 0.05), gray)
	_body(_shark, 0.28, Vector3(0.7, 0.45, 1.2), Vector3(0, -0.12, 0.1), belly)
	var nose := CylinderMesh.new()
	nose.top_radius = 0.0
	nose.bottom_radius = 0.28
	nose.height = 0.72
	nose.radial_segments = 16
	_place(_shark, nose, Vector3(0, 0, -0.95), Vector3(deg_to_rad(-90.0), 0, 0), Vector3.ONE, gray)
	_place(_shark, _box(Vector3(0.08, 0.55, 0.28)), Vector3(0, 0.42, 0.05), Vector3.ZERO, Vector3.ONE, dark)
	_place(_shark, _box(Vector3(0.08, 0.32, 0.22)), Vector3(-0.38, -0.12, 0.1), Vector3(0, 0, 0.6), Vector3.ONE, dark)
	_place(_shark, _box(Vector3(0.08, 0.32, 0.22)), Vector3(0.38, -0.12, 0.1), Vector3(0, 0, -0.6), Vector3.ONE, dark)
	_shark_tail = Node3D.new()
	_shark_tail.position = Vector3(0, 0, 0.85)
	_shark.add_child(_shark_tail)
	_place(_shark_tail, _box(Vector3(0.08, 0.55, 0.28)), Vector3(0, 0.18, 0.28), Vector3(0.4, 0, 0), Vector3.ONE, gray)
	_place(_shark_tail, _box(Vector3(0.08, 0.28, 0.2)), Vector3(0, -0.08, 0.22), Vector3(-0.2, 0, 0), Vector3.ONE, gray)
	_eye(_shark, Vector3(0.2, 0.06, -0.55))
	_eye(_shark, Vector3(-0.2, 0.06, -0.55))
	for i in 3:
		var gill := _box(Vector3(0.015, 0.12, 0.04))
		_place(_shark, gill, Vector3(0.22, 0.0, -0.15 - float(i) * 0.08), Vector3.ZERO, Vector3.ONE, dark)


func _eye(parent: Node3D, pos: Vector3) -> void:
	_body(parent, 0.07, Vector3.ONE, pos, _mat(Color(0.95, 0.95, 0.93), 0.2, false))
	_body(parent, 0.035, Vector3.ONE, pos + Vector3(0, 0, -0.04), _mat(Color(0.05, 0.06, 0.08), 0.4, false))


func _body(parent: Node3D, radius: float, scl: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 12
	_place(parent, mesh, pos, Vector3.ZERO, scl, mat)


func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _place(parent: Node3D, mesh: Mesh, pos: Vector3, rot: Vector3, scl: Vector3, mat: Material) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	n.mesh = mesh
	n.position = pos
	n.rotation = rot
	n.scale = scl
	n.material_override = mat
	n.layers = body_layer
	parent.add_child(n)
	return n


func _mat(color: Color, rough: float, transparent: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return mat
