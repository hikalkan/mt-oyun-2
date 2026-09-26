extends Node3D

const FishScript := preload("res://scripts/fish.gd")
const Bounds := preload("res://scripts/sea_bounds.gd")

@onready var player = $Player
@onready var score_label: Label = $HUD/Root/Score
@onready var form_label: Label = $HUD/Root/Form
@onready var camera_label: Label = $HUD/Root/CameraMode

var score := 0
var _env: Environment
var _score_tween: Tween


func _ready() -> void:
	_build_sky()
	_build_sun()
	_build_water()
	_build_sand()
	player.ate_fish.connect(_on_ate)
	player.form_changed.connect(_on_form)
	player.camera_changed.connect(_on_camera)
	_style_form()
	camera_label.text = player.camera_name()
	for i in 32:
		var fish = FishScript.new()
		var pos: Vector3
		if i < 10:
			var ang := TAU * float(i) / 10.0
			pos = player.global_position + Vector3(cos(ang), randf_range(-1.5, 1.5), sin(ang)) * randf_range(7.0, 13.0)
			pos = Bounds.clamp_pos(pos, 2.0)
		else:
			pos = Bounds.random_water(player.global_position)
		fish.position = pos
		add_child(fish)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _env == null:
		return
	var depth := clampf(-cam.global_position.y / 32.0, 0.0, 1.0)
	if cam.global_position.y > 0.8:
		_env.fog_density = 0.002
		_env.fog_light_color = Color(0.55, 0.75, 0.92)
		_env.ambient_light_energy = 0.8
	else:
		_env.fog_density = lerpf(0.028, 0.06, depth)
		_env.fog_light_color = Color(0.07, 0.32, 0.55).lerp(Color(0.015, 0.06, 0.14), depth)
		_env.ambient_light_energy = lerpf(0.5, 0.18, depth)


func _on_ate(at: Vector3) -> void:
	score += 1
	score_label.text = "Yediğin balık: %d" % score
	var pop := PlusOne.new()
	pop.position = at + Vector3(0, 0.6, 0)
	add_child(pop)
	if _score_tween:
		_score_tween.kill()
	score_label.scale = Vector2(1.12, 1.12)
	_score_tween = create_tween()
	_score_tween.tween_property(score_label, "scale", Vector2.ONE, 0.16)


func _on_form(_form_label: String) -> void:
	_style_form()


func _on_camera(mode_label: String) -> void:
	camera_label.text = mode_label


func _style_form() -> void:
	form_label.text = player.form_name()
	if player.is_shark():
		form_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.96))
	else:
		form_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1))


func _build_sky() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.5, 0.92)
	sky_mat.sky_horizon_color = Color(0.64, 0.84, 0.97)
	sky_mat.ground_horizon_color = Color(0.12, 0.32, 0.5)
	sky_mat.ground_bottom_color = Color(0.02, 0.08, 0.18)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.5, 0.68, 0.82)
	_env.ambient_light_energy = 0.65
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.12, 0.4, 0.6)
	_env.fog_density = 0.018
	_env.fog_aerial_perspective = 0.4
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 28, 0)
	sun.light_color = Color(1.0, 0.97, 0.9)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 200, 0)
	fill.light_color = Color(0.45, 0.7, 0.9)
	fill.light_energy = 0.35
	add_child(fill)


func _build_water() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	plane.subdivide_width = 70
	plane.subdivide_depth = 70
	water.mesh = plane
	water.position = Vector3(0, Bounds.SURFACE_Y, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/sea.gdshader")
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)


func _build_sand() -> void:
	var bed := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(190, 190)
	bed.mesh = plane
	bed.position = Vector3(0, Bounds.BED_Y, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.62, 0.54, 0.36)
	mat.roughness = 1.0
	bed.material_override = mat
	add_child(bed)


class PlusOne extends Node3D:
	var life := 0.8

	func _ready() -> void:
		var label := Label3D.new()
		label.text = "+1"
		label.font_size = 72
		label.pixel_size = 0.012
		label.outline_size = 12
		label.modulate = Color(1, 0.95, 0.55)
		label.outline_modulate = Color(0.04, 0.12, 0.24)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		add_child(label)

	func _process(delta: float) -> void:
		position.y += 1.4 * delta
		life -= delta
		if life <= 0.0:
			queue_free()
