extends CharacterBody2D

signal form_changed(form_label: String)
signal ate_fish(at: Vector2)

enum Form { WHALE, SHARK }

const Bounds := preload("res://scripts/sea_bounds.gd")

var form := Form.WHALE
var facing := 1.0
var swim_speed := 320.0
var accel := 520.0
var drag := 160.0
var mouth_forward := 102.0
var mouth_down := 12.0
var draw_scale := 1.0
var eat_flash := 0.0

var _time := 0.0
var _tilt := 0.0
var _switch_lock := 0.0
var _scale_tween: Tween
var _trail: Array[Vector2] = []
var _trail_life: Array[float] = []
var _trail_r: Array[float] = []

@onready var _camera: Camera2D = $Camera2D
@onready var _mouth: Area2D = $Mouth
@onready var _mouth_shape: CircleShape2D = $Mouth/CollisionShape2D.shape as CircleShape2D


func _ready() -> void:
	add_to_group("player")
	motion_mode = MOTION_MODE_FLOATING
	_mouth.area_entered.connect(_on_mouth_area)
	_apply_stats()
	_camera.zoom = Vector2(0.85, 0.85)
	_camera.make_current()
	_camera.reset_smoothing()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_M or key.physical_keycode == KEY_M:
			_switch_form()


func _switch_form() -> void:
	if _switch_lock > 0.0:
		return
	_switch_lock = 0.35
	form = Form.SHARK if form == Form.WHALE else Form.WHALE
	_apply_stats()
	if _scale_tween:
		_scale_tween.kill()
	draw_scale = 0.72
	_scale_tween = create_tween()
	_scale_tween.tween_property(self, "draw_scale", 1.0, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	form_changed.emit(form_name())


func _apply_stats() -> void:
	if form == Form.WHALE:
		swim_speed = 320.0
		accel = 520.0
		drag = 160.0
		mouth_forward = 102.0
		mouth_down = 12.0
		_mouth_shape.radius = 62.0
	else:
		swim_speed = 560.0
		accel = 820.0
		drag = 300.0
		mouth_forward = 74.0
		mouth_down = 4.0
		_mouth_shape.radius = 28.0
	_place_mouth()


func _place_mouth() -> void:
	_mouth.position = Vector2(mouth_forward * facing, mouth_down)


func _physics_process(delta: float) -> void:
	_time += delta
	if _switch_lock > 0.0:
		_switch_lock -= delta
	eat_flash = maxf(eat_flash - delta * 28.0, 0.0)

	var dir := _input_dir()
	if dir.length_squared() > 0.001:
		velocity = velocity.move_toward(dir * swim_speed, accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, drag * delta)
	move_and_slide()
	_clamp_inside()

	if velocity.x > 12.0:
		facing = 1.0
	elif velocity.x < -12.0:
		facing = -1.0
	_place_mouth()

	var aim := clampf(velocity.y / swim_speed, -1.0, 1.0) * 0.22
	if facing < 0.0:
		aim = -aim
	_tilt = lerpf(_tilt, aim, 1.0 - exp(-4.0 * delta))

	var target_zoom := 0.85 if form == Form.WHALE else 1.12
	_camera.zoom = _camera.zoom.lerp(Vector2(target_zoom, target_zoom), 1.0 - exp(-2.2 * delta))
	var look := Vector2(facing * 110.0, clampf(velocity.y * 0.06, -50.0, 50.0))
	_camera.position = _camera.position.lerp(look, 1.0 - exp(-2.5 * delta))

	_tick_trail(delta)
	queue_redraw()


func _clamp_inside() -> void:
	var p := global_position
	var min_x := 120.0
	var max_x := Bounds.WORLD_W - 120.0
	var min_y := Bounds.SURFACE_Y + 46.0
	var max_y := Bounds.SAND_Y - 60.0
	if p.x < min_x:
		p.x = min_x
		velocity.x = maxf(velocity.x, 0.0)
	elif p.x > max_x:
		p.x = max_x
		velocity.x = minf(velocity.x, 0.0)
	if p.y < min_y:
		p.y = min_y
		velocity.y = maxf(velocity.y, 0.0)
	elif p.y > max_y:
		p.y = max_y
		velocity.y = minf(velocity.y, 0.0)
	global_position = p


func _tick_trail(delta: float) -> void:
	if velocity.length() > 45.0 and randf() < delta * 12.0:
		var back := 120.0 if form == Form.WHALE else 72.0
		_trail.append(global_position + Vector2(-facing * back, randf_range(-8.0, 12.0)))
		_trail_life.append(0.85)
		_trail_r.append(randf_range(2.2, 5.5))
	var i := 0
	while i < _trail.size():
		var bubble := _trail[i]
		bubble.y -= 34.0 * delta
		_trail[i] = bubble
		_trail_life[i] -= delta
		if _trail_life[i] <= 0.0:
			_trail.remove_at(i)
			_trail_life.remove_at(i)
			_trail_r.remove_at(i)
		else:
			i += 1
	while _trail.size() > 26:
		_trail.remove_at(0)
		_trail_life.remove_at(0)
		_trail_r.remove_at(0)


func _input_dir() -> Vector2:
	var d := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if Input.is_physical_key_pressed(KEY_A):
		d.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		d.x += 1.0
	if Input.is_physical_key_pressed(KEY_W):
		d.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S):
		d.y += 1.0
	return d.limit_length(1.0)


func _on_mouth_area(area: Area2D) -> void:
	if not area.is_in_group("fish"):
		return
	var rel := area.global_position - global_position
	if rel.x * facing < -30.0:
		return
	if area.call("got_eaten") == true:
		eat_flash = 14.0
		ate_fish.emit(area.global_position)


func form_name() -> String:
	if form == Form.WHALE:
		return "Mavi balina"
	return "Köpekbalığı"


func is_shark() -> bool:
	return form == Form.SHARK


func scare_radius() -> float:
	return 360.0 if is_shark() else 200.0


func scare_power() -> float:
	return 300.0 if is_shark() else 100.0


func _draw() -> void:
	for i in _trail.size():
		var lp := to_local(_trail[i])
		var life := _trail_life[i]
		draw_circle(lp, _trail_r[i], Color(0.9, 0.97, 1.0, life * 0.4))
	var bob := sin(_time * 1.6) * 3.0
	var wag_speed := 2.3 if form == Form.WHALE else 6.2
	if velocity.length() > 40.0:
		wag_speed *= 1.55
	var wag := sin(_time * wag_speed) * (16.0 if form == Form.WHALE else 11.0)
	draw_set_transform(Vector2(0.0, bob), _tilt, Vector2(facing * draw_scale, draw_scale))
	if form == Form.WHALE:
		_draw_whale(wag)
	else:
		_draw_shark(wag)


func _draw_whale(wag: float) -> void:
	var body := Color(0.18, 0.42, 0.8)
	var deep := Color(0.08, 0.24, 0.52)
	var belly := Color(0.88, 0.93, 0.97)
	draw_colored_polygon(_ellipse(Vector2(-8, 34), 96, 16, 14), Color(0, 0.04, 0.1, 0.16))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-78, -14), Vector2(-112, -6), Vector2(-112, 10), Vector2(-74, 16),
	]), deep)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-104, -2), Vector2(-162, -44 + wag), Vector2(-126, -4 + wag * 0.2),
	]), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-104, 6), Vector2(-128, 8 - wag * 0.2), Vector2(-166, 38 - wag),
	]), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(24, 16), Vector2(-12, 98), Vector2(48, 28),
	]), Color(0.12, 0.32, 0.66))
	draw_colored_polygon(_ellipse(Vector2(-6, 2), 118, 48, 24), deep)
	draw_colored_polygon(_ellipse(Vector2(-6, 2), 112, 44, 24), body)
	draw_colored_polygon(_ellipse(Vector2(-4, 16), 78, 26, 16), belly)
	for spot in [Vector2(24, -26), Vector2(-8, -30), Vector2(46, -16), Vector2(-28, -18), Vector2(8, -12)]:
		draw_circle(spot, 7.0, Color(0.42, 0.62, 0.84, 0.4))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-34, -38), Vector2(-18, -58), Vector2(-2, -34),
	]), deep)
	for i in 6:
		var gy := 16.0 + float(i) * 4.5
		draw_line(Vector2(52, gy), Vector2(-18, gy + 1.4), Color(0.62, 0.74, 0.86, 0.55), 1.5)
	draw_circle(Vector2(74, -10), 6.5, Color(0.96, 0.97, 0.95))
	draw_circle(Vector2(76, -10), 3.1, Color(0.06, 0.08, 0.12))
	draw_circle(Vector2(75, -11.5), 1.3, Color(1, 1, 1, 0.85))
	var open := eat_flash * 1.05
	if open > 1.0:
		draw_colored_polygon(PackedVector2Array([
			Vector2(106, 6), Vector2(46, 12), Vector2(62, 20 + open), Vector2(104, 14 + open * 0.25),
		]), Color(0.1, 0.14, 0.26, 0.92))
	else:
		draw_line(Vector2(104, 10), Vector2(52, 18), Color(0.08, 0.14, 0.28), 3.0)
	if global_position.y < Bounds.SURFACE_Y + 210.0:
		var tt := Time.get_ticks_msec() * 0.001
		for i in 5:
			var h := fmod(tt * 42.0 + float(i) * 16.0, 90.0)
			var a := (1.0 - h / 90.0) * 0.72
			draw_circle(Vector2(16, -54.0 - h), 7.0 + h * 0.16, Color(0.9, 0.97, 1.0, a))


func _draw_shark(wag: float) -> void:
	var body := Color(0.55, 0.58, 0.62)
	var top := Color(0.36, 0.4, 0.44)
	var belly := Color(0.94, 0.95, 0.93)
	draw_colored_polygon(_ellipse(Vector2(0, 18), 50, 8, 12), Color(0, 0.02, 0.05, 0.16))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-48, -4), Vector2(-78, 0), Vector2(-70, 8), Vector2(-46, 8),
	]), top)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-58, -4), Vector2(-108, -34 + wag), Vector2(-72, 0),
	]), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-54, 5), Vector2(-92, 20 - wag * 0.55), Vector2(-66, 6),
	]), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(16, 8), Vector2(4, 32), Vector2(34, 12),
	]), Color(0.46, 0.49, 0.53))
	draw_colored_polygon(_ellipse(Vector2(-2, 1), 62, 22, 18), top)
	draw_colored_polygon(_ellipse(Vector2(-2, 1), 58, 19, 18), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(36, -8), Vector2(88, 1), Vector2(36, 10),
	]), body)
	draw_colored_polygon(_ellipse(Vector2(2, 7), 36, 9, 12), belly)
	draw_colored_polygon(PackedVector2Array([
		Vector2(46, -4), Vector2(16, -18), Vector2(-28, -16), Vector2(-46, -6), Vector2(8, -2),
	]), top)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -16), Vector2(10, -48), Vector2(26, -12),
	]), top)
	for i in 4:
		var gx := 32.0 - float(i) * 6.0
		draw_line(Vector2(gx, -1), Vector2(gx - 2.4, 8), Color(0.25, 0.28, 0.32, 0.85), 1.6)
	draw_circle(Vector2(50, -5), 4.4, Color(0.96, 0.96, 0.94))
	draw_circle(Vector2(51.4, -5), 2.2, Color(0.05, 0.06, 0.08))
	draw_circle(Vector2(50.6, -6.2), 1.0, Color(1, 1, 1, 0.9))
	var open := eat_flash * 0.85
	if open > 1.2:
		draw_colored_polygon(PackedVector2Array([
			Vector2(82, 3), Vector2(58, 5), Vector2(66, 9 + open),
		]), Color(0.35, 0.12, 0.14, 0.9))
		for n in 3:
			var tx := 76.0 - float(n) * 6.0
			draw_colored_polygon(PackedVector2Array([
				Vector2(tx, 4.5), Vector2(tx - 1.6, 9.0 + open * 0.2), Vector2(tx + 1.6, 4.5),
			]), Color(0.96, 0.96, 0.92))
	else:
		draw_line(Vector2(80, 5), Vector2(58, 8), Color(0.25, 0.12, 0.14), 2.0)


func _ellipse(center: Vector2, rx: float, ry: float, n: int = 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
