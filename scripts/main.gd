extends Node2D

const FishScript := preload("res://scripts/fish.gd")
const Bounds := preload("res://scripts/sea_bounds.gd")

@onready var player = $Creatures/Player
@onready var score_label: Label = $HUD/Root/Score
@onready var form_label: Label = $HUD/Root/Form

var score := 0
var _bubble_tex: Texture2D
var _score_tween: Tween


func _ready() -> void:
	var mat := $Sea.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter("surface_y", Bounds.SURFACE_Y)
		mat.set_shader_parameter("sand_y", Bounds.SAND_Y)
	_bubble_tex = _make_bubble_texture()
	_add_ambient_bubbles()
	player.ate_fish.connect(_on_ate)
	player.form_changed.connect(_on_form)
	_style_form()
	for i in 34:
		var fish = FishScript.new()
		var pos: Vector2
		if i < 10:
			var ang := TAU * float(i) / 10.0
			pos = player.global_position + Vector2(cos(ang), sin(ang)) * randf_range(260.0, 500.0)
			pos.x = clampf(pos.x, 180.0, Bounds.WORLD_W - 180.0)
			pos.y = clampf(pos.y, Bounds.SURFACE_Y + 110.0, Bounds.SAND_Y - 130.0)
		else:
			pos = Bounds.random_water(player.global_position)
		fish.position = pos
		$Creatures.add_child(fish)


func _on_ate(at: Vector2) -> void:
	score += 1
	score_label.text = "Yediğin balık: %d" % score
	var pop := PlusOne.new()
	pop.position = at
	pop.z_index = 20
	add_child(pop)
	_spawn_bubbles(at, 12, true)
	if _score_tween:
		_score_tween.kill()
	score_label.scale = Vector2(1.12, 1.12)
	_score_tween = create_tween()
	_score_tween.tween_property(score_label, "scale", Vector2.ONE, 0.16)


func _on_form(_form_label: String) -> void:
	_style_form()
	_spawn_bubbles(player.global_position, 20, true)


func _style_form() -> void:
	form_label.text = player.form_name()
	if player.is_shark():
		form_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.96))
	else:
		form_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1))


func _add_ambient_bubbles() -> void:
	var spots: Array[Vector2] = [
		Vector2(700, 850),
		Vector2(1400, 1450),
		Vector2(2100, 1000),
		Vector2(2500, 1600),
		Vector2(3200, 900),
		Vector2(3700, 1400),
	]
	for spot in spots:
		_spawn_bubbles(spot, 26, false)


func _spawn_bubbles(at: Vector2, amount: int, one_shot: bool) -> void:
	var p := CPUParticles2D.new()
	p.texture = _bubble_tex
	p.position = at
	p.amount = amount
	p.lifetime = 0.9 if one_shot else 6.0
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.preprocess = 0.0 if one_shot else 2.5
	p.direction = Vector2(0, -1)
	p.spread = 50.0 if one_shot else 18.0
	p.gravity = Vector2(6, -24)
	p.initial_velocity_min = 40.0 if one_shot else 14.0
	p.initial_velocity_max = 110.0 if one_shot else 40.0
	p.scale_amount_min = 0.35
	p.scale_amount_max = 0.95 if one_shot else 1.15
	p.color_ramp = _fade_ramp()
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(30, 20) if one_shot else Vector2(460, 340)
	p.z_index = 15 if one_shot else 1
	p.local_coords = true
	add_child(p)
	p.emitting = true
	if one_shot:
		p.restart()
		get_tree().create_timer(1.6).timeout.connect(p.queue_free)


func _fade_ramp() -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.95, 1.0, 0.0))
	g.set_color(1, Color(0.85, 0.95, 1.0, 0.0))
	g.add_point(0.18, Color(0.92, 0.98, 1.0, 0.55))
	return g


func _make_bubble_texture() -> Texture2D:
	var size := 16
	var img := Image.create_empty(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(7.5, 7.5)
	for y in size:
		for x in size:
			var d := Vector2(float(x) + 0.5, float(y) + 0.5).distance_to(center)
			if d < 6.8 and d > 4.6:
				var a := clampf(1.0 - absf(d - 5.7) / 1.1, 0.0, 1.0)
				img.set_pixel(x, y, Color(0.92, 0.98, 1.0, a * 0.95))
			elif d < 2.2 and x < 7 and y < 7:
				img.set_pixel(x, y, Color(1, 1, 1, 0.55))
	return ImageTexture.create_from_image(img)


class PlusOne extends Node2D:
	var life := 0.75

	func _process(delta: float) -> void:
		position.y -= 48.0 * delta
		life -= delta
		queue_redraw()
		if life <= 0.0:
			queue_free()

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		var col := Color(1, 0.95, 0.55, clampf(life / 0.28, 0.0, 1.0))
		var pos := Vector2(-16, 0)
		draw_string_outline(font, pos, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, 5, Color(0.04, 0.12, 0.24, col.a))
		draw_string(font, pos, "+1", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, col)
