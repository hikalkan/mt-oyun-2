extends CharacterBody3D

signal form_changed(form_label: String)
signal ate_fish(at: Vector3)
signal ate_titan(at: Vector3)
signal camera_changed(mode_label: String)
signal got_hurt(left: float)
signal got_downed

const Land := preload("res://scripts/land_bounds.gd")
const BabyScript := preload("res://scripts/baby.gd")
const Dust := preload("res://scripts/dust.gd")

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
var _roar_call: AudioStream = preload("res://assets/audio/rex_roar.ogg")
var _gulps: Array[AudioStream] = [
	preload("res://assets/audio/gulp.ogg"),
	preload("res://assets/audio/gulp2.ogg"),
]
var _baby_call: AudioStream = preload("res://assets/audio/baby.ogg")
var _babies: Array = []
var _from_baby := false
const BABY_MAX := 10
var _avatar: Node3D
var _grown := 1.0
var _meals := 0
var _grow_tween: Tween
var _lag := 0.0
var _last_yaw := 0.0
var _dip := 0.0
var _blink := 0.0
var _blink_wait := 2.6
var _step_mark := 0.0
var _leg_home: Array[float] = []
var _eyes: Array[MeshInstance3D] = []
var _diplodocus := false
var _bulk := 1.0
var _switch_lock := 0.0
const DIPLO_BIG := 5.0
var _rex_root: Node3D
var _diplo_root: Node3D
var _diplo_neck: Node3D
var _diplo_hood: MeshInstance3D
var _rex_legs: Array[Node3D] = []
var _rex_leg_home: Array[float] = []
var _rex_eyes: Array[MeshInstance3D] = []
var _diplo_legs: Array[Node3D] = []
var _diplo_leg_home: Array[float] = []
var _diplo_eyes: Array[MeshInstance3D] = []
var _rex_tail: Node3D
var _rex_jaw: Node3D
var _diplo_tail: Node3D
var _diplo_jaw: Node3D
const MEALS_TO_HUNT := 6


func _ready() -> void:
	add_to_group("player")
	collision_layer = 0
	collision_mask = 0
	motion_mode = MOTION_MODE_FLOATING
	_avatar = Node3D.new()
	add_child(_avatar)
	_build_body()
	_build_diplo()
	_build_cameras()
	_build_mouth()
	_apply_dino()
	_show_camera()
	_voice = AudioStreamPlayer3D.new()
	_voice.unit_size = 18.0
	_voice.max_distance = 140.0
	_voice.volume_db = 3.0
	add_child(_voice)
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
			elif pad.button_index == JOY_BUTTON_X:
				_give_birth()
			elif pad.button_index == JOY_BUTTON_RIGHT_SHOULDER:
				_switch_dino()
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
		elif key.keycode == KEY_B or key.physical_keycode == KEY_B:
			_give_birth()
		elif key.keycode == KEY_M or key.physical_keycode == KEY_M:
			_switch_dino()


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
	for baby in _babies:
		if is_instance_valid(baby):
			baby.queue_free()
	_babies.clear()


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
	var name := "Dev Diplodocus" if _diplodocus else "T-Rex"
	if can_eat_big():
		name = "Kocaman " + name
	var babies := _live_babies()
	if babies.size() == 1:
		return name + " ve bebek"
	if babies.size() > 1:
		return name + " ve %d bebek" % babies.size()
	return name


func camera_name() -> String:
	if fps_mode:
		return "Gözünden"
	return "Arkadan"


func is_shark() -> bool:
	return false


func scare_radius() -> float:
	return 16.0 * _grown * (4.0 if _diplodocus else 1.0)


func scare_power() -> float:
	return 3.2 * _grown * (2.0 if _diplodocus else 1.0)


func body_size() -> float:
	return _grown


func follow_back(row: int) -> float:
	if _diplodocus:
		return (8.8 + float(row) * 1.2) * _bulk * _grown
	return (3.6 + float(row) * 2.3) * _grown


func follow_side() -> float:
	if _diplodocus:
		return 0.8 * _bulk * _grown
	return 1.7 * _grown


func can_eat_big() -> bool:
	return _meals >= MEALS_TO_HUNT


func grow_from_food(big: bool = false) -> void:
	var was_big := can_eat_big()
	_meals += 4 if big else 1
	_grown = minf(1.0 + float(_meals) * 0.1, 2.1)
	_refresh_speed()
	if _grow_tween:
		_grow_tween.kill()
	_grow_tween = create_tween()
	_grow_tween.tween_property(_avatar, "scale", Vector3.ONE * _grown, 0.25)
	if can_eat_big() and not was_big:
		form_changed.emit(form_name())


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
	if _switch_lock > 0.0:
		_switch_lock -= delta
	if _roar > 0.0:
		_roar -= delta
	rotation.y = yaw
	var spun := wrapf(yaw - _last_yaw, -PI, PI)
	_last_yaw = yaw
	_lag = clampf(_lag + spun, -0.28, 0.28)
	_lag = lerpf(_lag, 0.0, 1.0 - exp(-4.2 * delta))
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
		_vy = (16.0 if _diplodocus else 10.5) + (_grown - 1.0) * 3.0
		_grounded = false
	else:
		var gravity := 23.0 if _vy > 0.0 else 36.0
		_vy -= gravity * delta
	var pos := global_position
	var next := pos + Vector3(horiz.x, 0.0, horiz.z) * delta
	next = Land.clamp_xz(next, 6.5 * _bulk * _grown)
	if not is_equal_approx(next.x, pos.x + horiz.x * delta):
		horiz.x = 0.0
	if not is_equal_approx(next.z, pos.z + horiz.z * delta):
		horiz.z = 0.0
	var floor_y := Land.ground_y(next.x, next.z)
	next.y = pos.y + _vy * delta
	if next.y <= floor_y:
		if not _grounded and _vy < -7.0:
			_dip = 0.14 * _grown * _bulk
			if not Land.in_river(next.x, next.z):
				Dust.puff(get_parent(), Vector3(next.x, floor_y + 0.1, next.z), 1.4 * _bulk)
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
			_play(_gulps[randi() % _gulps.size()], randf_range(0.78, 0.94), -6.0)
	var want_bulk := DIPLO_BIG if _diplodocus else 1.0
	if _diplodocus:
		_bulk = lerpf(_bulk, want_bulk, 1.0 - exp(-4.5 * delta))
	else:
		_bulk = 1.0
	if _diplo_root:
		_diplo_root.scale = Vector3.ONE * _bulk
	if _diplodocus and _mouth:
		_mouth.position = Vector3(0.0, 1.45, -6.35) * _bulk
		_mouth_shape.radius = 1.45 * _bulk
	_seat_cameras()
	_animate()
	_bite_overlapped_titans()


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


func _live_babies() -> Array:
	var live: Array = []
	for baby in _babies:
		if is_instance_valid(baby):
			live.append(baby)
	_babies = live
	return _babies


func wants_parent_grow() -> bool:
	return not _from_baby


func baby_scored(at: Vector3) -> void:
	_from_baby = true
	ate_fish.emit(at)
	_from_baby = false


func _give_birth() -> void:
	if not alive:
		return
	var babies := _live_babies()
	if babies.size() >= BABY_MAX:
		return
	var slot := babies.size()
	var baby = BabyScript.new()
	var back: Vector3 = global_transform.basis.z
	var side: Vector3 = global_transform.basis.x
	var col := slot % 5
	var row := int(slot / 5)
	baby.position = Land.stand(global_position + back * (2.6 + float(row) * 1.8) + side * (float(col) - 2.0) * 1.5)
	baby.setup(self, slot)
	get_parent().add_child(baby)
	_babies.append(baby)
	form_changed.emit(form_name())
	_play(_baby_call, randf_range(0.62, 0.74), -5.0)


func chirp(index: int) -> void:
	_play(_baby_call, randf_range(1.18, 1.36) + float(index) * 0.02, -1.0)


func _roar_now() -> void:
	_roar = 2.15
	var deep := lerpf(1.0, 0.78, clampf((_grown - 1.0) / 1.1, 0.0, 1.0))
	if _diplodocus:
		deep *= 0.62
	_play(_roar_call, randf_range(0.96, 1.05) * deep, 3.0)


func _play(stream: AudioStream, pitch: float, db: float) -> void:
	_voice.stream = stream
	_voice.pitch_scale = pitch
	_voice.volume_db = db
	_voice.play()


func _toggle_camera() -> void:
	fps_mode = not fps_mode
	_show_camera()
	camera_changed.emit(camera_name())


func _show_camera() -> void:
	_chase.current = owns_screen and not fps_mode
	_fps.current = owns_screen and fps_mode
	if _hood:
		_hood.visible = fps_mode and not _diplodocus
	if _diplo_hood:
		_diplo_hood.visible = fps_mode and _diplodocus


func _seat_cameras() -> void:
	var bob := 0.0
	if Vector2(velocity.x, velocity.z).length() > 1.2 and _grounded:
		bob = sin(_time * 7.2) * 0.045 * _grown * _bulk
	if _diplodocus:
		_chase.position = Vector3(0.0, 6.4, 15.5) * _grown * _bulk + Vector3(0.0, bob, 0.0)
	else:
		_chase.position = Vector3(0.0, 4.8, 11.0) * _grown + Vector3(0.0, bob, 0.0)
	if _head:
		_head.position = (Vector3(0.0, 1.9, -5.45) * _bulk if _diplodocus else Vector3(0.0, 2.45, -1.7)) * _grown
	if _hood:
		_hood.scale = Vector3(0.7, 0.28, 1.15) * _grown
	if _diplo_hood:
		_diplo_hood.scale = Vector3(0.5, 0.2, 1.35) * _grown * _bulk
	var lifted := Land.above_ground(_chase.global_position, 1.5)
	if lifted.y > _chase.global_position.y:
		_chase.global_position = lifted
	var ahead := -global_transform.basis.z
	var focus_y := 3.1 * _bulk if _diplodocus else 2.3
	var look_ahead := 3.2 * _bulk if _diplodocus else 3.2
	var focus := global_position + Vector3(0.0, focus_y * _grown, 0.0) + ahead * look_ahead * _grown
	focus.y += sin(pitch) * 7.0
	if _chase.global_position.distance_to(focus) > 0.4:
		_chase.look_at(focus, Vector3.UP)
	var eye := Land.above_ground(_fps.global_position, 0.6)
	if eye.y > _fps.global_position.y:
		_fps.global_position = eye


func _animate() -> void:
	var speed := Vector2(velocity.x, velocity.z).length()
	var moving := speed > 0.8 and _grounded
	var pace := (5.2 if _diplodocus else 7.2) if moving else 1.6
	var swing := (0.32 if _diplodocus else 0.55) if moving else 0.06
	var phase := _time * pace
	if moving and not Land.in_river(global_position.x, global_position.z):
		var mark := floorf(phase / PI)
		if mark != _step_mark:
			_step_mark = mark
			var side := 1.0 if sin(phase) > 0.0 else -1.0
			var at := global_position + global_transform.basis.x * side * 0.82 * _grown * _bulk
			at.y = Land.ground_y(at.x, at.z) + 0.08
			Dust.puff(get_parent(), at, 0.7 * _bulk)
	for i in _legs.size():
		var offset := float(i) * PI
		if _diplodocus:
			offset = [0.0, PI, PI, 0.0][i % 4]
		var step := sin(phase + offset)
		_legs[i].rotation.x = step * swing
		if i < _leg_home.size():
			_legs[i].position.y = _leg_home[i] + maxf(step, 0.0) * (0.18 if moving else 0.0)
	if _avatar:
		var breath := sin(_time * 1.7) * 0.025 * _bulk
		var hop := absf(sin(phase)) * (0.07 if moving else 0.0) * _bulk
		_dip = lerpf(_dip, 0.0, 0.12)
		_avatar.position.y = breath + hop - _dip
		_avatar.rotation.y = -_lag * 0.85
		_avatar.rotation.z = lerpf(_avatar.rotation.z, -_lag * 0.45, 0.2)
		_avatar.rotation.x = lerpf(_avatar.rotation.x, clampf(-_vy * 0.02, -0.2, 0.16), 0.18)
	if _tail:
		var wag := 0.28 if moving else 0.07
		_tail.rotation.y = lerpf(_tail.rotation.y, sin(_time * (3.2 if moving else 1.3)) * wag - _lag * 0.6, 0.2)
		_tail.rotation.x = sin(_time * (6.0 if moving else 1.4)) * (0.05 if moving else 0.02)
	if _jaw:
		var open := 0.42 if _roar > 0.0 else (0.28 if drinking else 0.06)
		if _diplodocus:
			open *= 0.55
		_jaw.rotation.x = lerpf(_jaw.rotation.x, -open, 0.2)
	if _diplodocus and _diplo_neck:
		var sway := 0.1 if moving else 0.05
		_diplo_neck.rotation.y = sin(_time * 0.7) * sway
		_diplo_neck.rotation.x = sin(_time * 0.45) * 0.04
	if drinking and _head and _roar <= 0.0:
		_head.rotation.x = lerpf(_head.rotation.x, 0.62, 0.18)
	_blink_eyes()


func _blink_eyes() -> void:
	_blink_wait -= get_physics_process_delta_time()
	if _blink_wait <= 0.0:
		_blink = 0.09
		_blink_wait = randf_range(2.4, 5.2)
	var shut := _blink > 0.0
	if _blink > 0.0:
		_blink -= get_physics_process_delta_time()
	for eye in _eyes:
		eye.scale.y = 0.12 if shut else 1.0


func _bite_overlapped_titans() -> void:
	if not can_eat_big() or _mouth == null:
		return
	for area in _mouth.get_overlapping_areas():
		if not is_instance_valid(area) or not area.is_in_group("titan"):
			continue
		if area.call("got_eaten") == true:
			_play(_gulps[randi() % _gulps.size()], randf_range(0.62, 0.74), 1.0)
			ate_titan.emit(area.global_position)


func _on_mouth_area(area: Area3D) -> void:
	if not alive:
		return
	if area.is_in_group("titan"):
		if not can_eat_big():
			return
		if area.call("got_eaten") == true:
			_play(_gulps[randi() % _gulps.size()], randf_range(0.62, 0.74), 1.0)
			ate_titan.emit(area.global_position)
		return
	if not area.is_in_group("prey"):
		return
	var rel := to_local(area.global_position)
	if rel.z > -0.6:
		return
	if area.call("got_eaten") == true:
		var at: Vector3 = area.global_position
		if _roar <= 0.0:
			_play(_gulps[randi() % _gulps.size()], randf_range(0.82, 1.0), -3.0)
		ate_fish.emit(at)
		for baby in _live_babies():
			baby.eat_with(at)


func _build_mouth() -> void:
	_mouth = Area3D.new()
	_mouth.collision_layer = 0
	_mouth.collision_mask = 1
	_mouth_shape = SphereShape3D.new()
	_mouth_shape.radius = 1.45
	var col := CollisionShape3D.new()
	col.shape = _mouth_shape
	_mouth.add_child(col)
	_mouth.position = Vector3(0.0, 0.95, -2.85)
	_avatar.add_child(_mouth)
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
	_diplo_hood = _hood_mesh(Color(0.46, 0.48, 0.4), Vector3(0.5, 0.2, 1.35), Vector3(0.0, -0.16, -0.95))
	_fps.add_child(_diplo_hood)


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


func _switch_dino() -> void:
	if _switch_lock > 0.0:
		return
	_switch_lock = 0.35
	_diplodocus = not _diplodocus
	_apply_dino()
	form_changed.emit(form_name())


func _apply_dino() -> void:
	if _rex_root:
		_rex_root.visible = not _diplodocus
	if _diplo_root:
		_diplo_root.visible = _diplodocus
	if _diplodocus:
		_legs = _diplo_legs
		_leg_home = _diplo_leg_home
		_eyes = _diplo_eyes
		_tail = _diplo_tail
		_jaw = _diplo_jaw
		_mouth.position = Vector3(0.0, 1.45, -6.35) * _bulk
		_mouth_shape.radius = 1.45 * _bulk
	else:
		_legs = _rex_legs
		_leg_home = _rex_leg_home
		_eyes = _rex_eyes
		_tail = _rex_tail
		_jaw = _rex_jaw
		_mouth.position = Vector3(0.0, 0.95, -2.85)
		_mouth_shape.radius = 1.45
	if not _diplodocus:
		_bulk = 1.0
		if _diplo_root:
			_diplo_root.scale = Vector3.ONE
	_refresh_speed()
	_show_camera()


func _refresh_speed() -> void:
	if _diplodocus:
		run_speed = 26.0 + (_grown - 1.0) * 5.0
		accel = 16.0
	else:
		run_speed = 16.0 + (_grown - 1.0) * 4.0
		accel = 28.0


func _build_body() -> void:
	_rex_root = Node3D.new()
	_avatar.add_child(_rex_root)
	var skin := _mat(Color(0.36, 0.48, 0.2), 0.55)
	var dark := _mat(Color(0.2, 0.3, 0.12), 0.62)
	var belly := _mat(Color(0.66, 0.6, 0.38), 0.5)
	var tooth := _mat(Color(0.95, 0.93, 0.86), 0.28, true)
	_body(_rex_root, 0.78, Vector3(0.95, 0.82, 1.65), Vector3(0.0, 1.9, 0.2), skin)
	_body(_rex_root, 0.55, Vector3(0.72, 0.42, 1.25), Vector3(0.0, 1.5, 0.25), belly)
	_place(_rex_root, _box(Vector3(0.18, 0.16, 1.5)), Vector3(0.0, 2.45, 0.15), Vector3.ZERO, Vector3.ONE, dark)
	for i in 6:
		var scute := CylinderMesh.new()
		scute.top_radius = 0.0
		scute.bottom_radius = 0.09
		scute.height = 0.24
		scute.radial_segments = 5
		_place(_rex_root, scute, Vector3(0.0, 2.58, -0.5 + float(i) * 0.36), Vector3.ZERO, Vector3.ONE, dark)
	_body(_rex_root, 0.42, Vector3(0.8, 0.85, 1.05), Vector3(0.0, 2.15, -1.05), skin)
	_body(_rex_root, 0.52, Vector3(0.82, 0.7, 1.35), Vector3(0.0, 2.5, -2.15), skin)
	_body(_rex_root, 0.28, Vector3(0.7, 0.55, 1.35), Vector3(0.0, 2.28, -3.05), skin)
	_eye(_rex_root, Vector3(0.28, 2.72, -2.55))
	_eye(_rex_root, Vector3(-0.28, 2.72, -2.55))
	for i in 4:
		_place(_rex_root, _box(Vector3(0.06, 0.14, 0.06)), Vector3(-0.12 + float(i) * 0.08, 2.08, -3.45), Vector3.ZERO, Vector3.ONE, tooth)
	_jaw = Node3D.new()
	_jaw.position = Vector3(0.0, 2.12, -2.35)
	_rex_root.add_child(_jaw)
	_body(_jaw, 0.22, Vector3(0.85, 0.45, 1.7), Vector3(0.0, -0.08, -0.85), belly)
	for i in 4:
		_place(_jaw, _box(Vector3(0.05, 0.12, 0.05)), Vector3(-0.12 + float(i) * 0.08, 0.02, -1.15), Vector3.ZERO, Vector3.ONE, tooth)
	_arm(0.62)
	_arm(-0.62)
	_add_leg(0.48, skin, dark)
	_add_leg(-0.48, skin, dark)
	_tail = Node3D.new()
	_tail.position = Vector3(0.0, 1.85, 1.35)
	_rex_root.add_child(_tail)
	_body(_tail, 0.42, Vector3(0.7, 0.6, 1.5), Vector3(0.0, 0.05, 0.7), skin)
	_body(_tail, 0.28, Vector3(0.55, 0.45, 1.35), Vector3(0.0, 0.18, 1.7), dark)
	_body(_tail, 0.16, Vector3(0.45, 0.35, 1.2), Vector3(0.0, 0.28, 2.45), dark)
	_rex_legs = _legs.duplicate()
	_rex_leg_home = _leg_home.duplicate()
	_rex_eyes = _eyes.duplicate()
	_rex_tail = _tail
	_rex_jaw = _jaw


func _arm(side: float) -> void:
	var skin := _mat(Color(0.32, 0.42, 0.18), 0.55)
	_place(_rex_root, _box(Vector3(0.1, 0.28, 0.1)), Vector3(side, 1.85, -0.85), Vector3(0.4, 0.0, side * 0.3), Vector3.ONE, skin)
	_place(_rex_root, _box(Vector3(0.08, 0.16, 0.08)), Vector3(side * 1.05, 1.62, -1.05), Vector3.ZERO, Vector3.ONE, skin)


func _add_leg(side: float, skin: Material, dark: Material) -> void:
	var hip := Node3D.new()
	hip.position = Vector3(side, 1.45, 0.2)
	_rex_root.add_child(hip)
	_legs.append(hip)
	_leg_home.append(hip.position.y)
	_place(hip, _box(Vector3(0.32, 0.72, 0.36)), Vector3(0.0, -0.32, 0.0), Vector3.ZERO, Vector3.ONE, skin)
	_place(hip, _box(Vector3(0.26, 0.62, 0.3)), Vector3(0.0, -0.95, 0.06), Vector3.ZERO, Vector3.ONE, dark)
	_place(hip, _box(Vector3(0.36, 0.12, 0.7)), Vector3(0.0, -1.28, -0.16), Vector3.ZERO, Vector3.ONE, dark)


func _build_diplo() -> void:
	_diplo_root = Node3D.new()
	_diplo_root.visible = false
	_avatar.add_child(_diplo_root)
	var skin := _mat(Color(0.5, 0.52, 0.4), 0.5)
	var dark := _mat(Color(0.3, 0.33, 0.26), 0.58)
	var belly := _mat(Color(0.8, 0.74, 0.56), 0.46)
	_body(_diplo_root, 1.05, Vector3(1.2, 0.95, 2.35), Vector3(0.0, 2.35, 0.2), skin)
	_body(_diplo_root, 0.7, Vector3(0.95, 0.4, 1.85), Vector3(0.0, 1.75, 0.2), belly)
	_body(_diplo_root, 0.32, Vector3(1.15, 0.65, 1.1), Vector3(0.0, 3.15, 0.45), dark)
	_diplo_neck = Node3D.new()
	_diplo_neck.position = Vector3(0.0, 2.55, -1.05)
	_diplo_root.add_child(_diplo_neck)
	var curve: Array[Vector3] = [
		Vector3(0.0, 0.15, -0.25),
		Vector3(0.0, 0.55, -0.9),
		Vector3(0.0, 0.95, -1.6),
		Vector3(0.0, 1.1, -2.3),
		Vector3(0.0, 0.7, -3.05),
		Vector3(0.0, 0.1, -3.75),
		Vector3(0.0, -0.55, -4.4),
	]
	for i in curve.size():
		var fat := 0.42 - float(i) * 0.035
		_body(_diplo_neck, fat, Vector3(1.0, 1.05, 1.2), curve[i], skin if i % 2 == 0 else dark)
	var head := Vector3(0.0, -0.72, -4.95)
	_body(_diplo_neck, 0.28, Vector3(0.8, 0.7, 1.45), head, skin)
	_body(_diplo_neck, 0.14, Vector3(0.65, 0.5, 1.35), head + Vector3(0.0, -0.02, -0.5), belly)
	_add_eye(_diplo_neck, head + Vector3(0.14, 0.1, -0.28), _diplo_eyes)
	_add_eye(_diplo_neck, head + Vector3(-0.14, 0.1, -0.28), _diplo_eyes)
	_body(_diplo_neck, 0.055, Vector3.ONE, head + Vector3(0.07, 0.06, -0.95), dark)
	_body(_diplo_neck, 0.055, Vector3.ONE, head + Vector3(-0.07, 0.06, -0.95), dark)
	_diplo_jaw = Node3D.new()
	_diplo_jaw.position = head + Vector3(0.0, -0.1, -0.2)
	_diplo_neck.add_child(_diplo_jaw)
	_body(_diplo_jaw, 0.11, Vector3(0.7, 0.4, 1.55), Vector3(0.0, -0.04, -0.42), belly)
	_add_diplo_leg(0.82, -0.45, skin, dark)
	_add_diplo_leg(-0.82, -0.45, skin, dark)
	_add_diplo_leg(0.74, 1.15, skin, dark)
	_add_diplo_leg(-0.74, 1.15, skin, dark)
	_diplo_tail = Node3D.new()
	_diplo_tail.position = Vector3(0.0, 2.2, 1.85)
	_diplo_root.add_child(_diplo_tail)
	_body(_diplo_tail, 0.5, Vector3(0.75, 0.65, 1.7), Vector3(0.0, 0.02, 0.8), skin)
	_body(_diplo_tail, 0.32, Vector3(0.6, 0.5, 1.8), Vector3(0.0, 0.1, 2.25), dark)
	_body(_diplo_tail, 0.18, Vector3(0.5, 0.4, 1.9), Vector3(0.0, 0.18, 3.7), skin)
	_body(_diplo_tail, 0.09, Vector3(0.4, 0.32, 1.7), Vector3(0.0, 0.26, 5.05), dark)
	_body(_diplo_tail, 0.045, Vector3(0.35, 0.28, 1.5), Vector3(0.0, 0.32, 6.15), skin)


func _add_diplo_leg(x: float, z: float, skin: Material, dark: Material) -> void:
	var hip := Node3D.new()
	hip.position = Vector3(x, 1.7, z)
	_diplo_root.add_child(hip)
	_diplo_legs.append(hip)
	_diplo_leg_home.append(hip.position.y)
	_place(hip, _box(Vector3(0.4, 0.9, 0.42)), Vector3(0.0, -0.42, 0.0), Vector3.ZERO, Vector3.ONE, skin)
	_place(hip, _box(Vector3(0.34, 0.75, 0.36)), Vector3(0.0, -1.1, 0.04), Vector3.ZERO, Vector3.ONE, dark)
	_place(hip, _box(Vector3(0.48, 0.16, 0.78)), Vector3(0.0, -1.5, -0.06), Vector3.ZERO, Vector3.ONE, dark)


func _eye(parent: Node3D, pos: Vector3) -> void:
	_add_eye(parent, pos, _eyes)


func _add_eye(parent: Node3D, pos: Vector3, into: Array[MeshInstance3D]) -> void:
	into.append(_body(parent, 0.09, Vector3.ONE, pos, _mat(Color(0.95, 0.95, 0.9), 0.2, true)))
	into.append(_body(parent, 0.045, Vector3.ONE, pos + Vector3(0.0, 0.0, -0.06), _mat(Color(0.08, 0.06, 0.04), 0.35, true)))


func _body(parent: Node3D, radius: float, scl: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 22
	mesh.rings = 10
	return _place(parent, mesh, pos, Vector3.ZERO, scl, mat)


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


const SkinShader := preload("res://assets/shaders/skin.gdshader")

func _mat(color: Color, rough: float, flat: bool = false) -> Material:
	if flat:
		var plain := StandardMaterial3D.new()
		plain.albedo_color = color
		plain.roughness = rough
		plain.metallic_specular = 0.45
		return plain
	var mat := ShaderMaterial.new()
	mat.shader = SkinShader
	mat.set_shader_parameter("albedo", color)
	mat.set_shader_parameter("roughness_amt", rough)
	return mat
