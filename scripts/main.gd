extends Node3D

const FishScript := preload("res://scripts/fish.gd")
const Bounds := preload("res://scripts/sea_bounds.gd")

@onready var player = $Player
@onready var score_label: Label = $HUD/Root/Score
@onready var form_label: Label = $HUD/Root/Form
@onready var camera_label: Label = $HUD/Root/CameraMode

const HUNGER_FULL := 30.0
const BITE_FILL := 12.0

var score := 0
var hunger := HUNGER_FULL
var dead := false
var _env: Environment
var _score_tween: Tween
var _hunger_label: Label
var _hunger_fill: ColorRect
var _death_layer: Control


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
	_build_hunger_ui()
	_build_death_ui()
	for i in 44:
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


func _process(delta: float) -> void:
	_update_fog()
	if dead:
		return
	hunger = maxf(hunger - delta, 0.0)
	_paint_hunger()
	if hunger <= 0.0:
		_die()


func _unhandled_input(event: InputEvent) -> void:
	if dead and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()


func _update_fog() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or _env == null:
		return
	var depth := clampf(-cam.global_position.y / absf(Bounds.BED_Y), 0.0, 1.0)
	if cam.global_position.y > 0.6:
		_env.fog_density = 0.0012
		_env.fog_light_color = Color(0.62, 0.78, 0.9)
		_env.ambient_light_energy = 0.85
		_env.ambient_light_color = Color(0.62, 0.74, 0.86)
	else:
		_env.fog_density = lerpf(0.0065, 0.02, depth)
		_env.fog_light_color = Color(0.1, 0.38, 0.55).lerp(Color(0.012, 0.04, 0.09), depth)
		_env.ambient_light_energy = lerpf(0.55, 0.12, depth)
		_env.ambient_light_color = Color(0.45, 0.62, 0.74).lerp(Color(0.05, 0.12, 0.2), depth)


func _on_ate(at: Vector3) -> void:
	if dead:
		return
	hunger = minf(HUNGER_FULL, hunger + BITE_FILL)
	_paint_hunger()
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


func _die() -> void:
	dead = true
	player.die()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_death_layer.visible = true


func _build_hunger_ui() -> void:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	box.offset_left = -330.0
	box.offset_top = 16.0
	box.offset_right = -24.0
	box.offset_bottom = 78.0
	$HUD/Root.add_child(box)
	_hunger_label = Label.new()
	_hunger_label.text = "Tokluk"
	_hunger_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hunger_label.add_theme_font_size_override("font_size", 24)
	_hunger_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_hunger_label.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.22, 0.9))
	_hunger_label.add_theme_constant_override("outline_size", 8)
	box.add_child(_hunger_label)
	var back := ColorRect.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.color = Color(0.04, 0.08, 0.12, 0.8)
	back.position = Vector2(0, 34)
	back.size = Vector2(306, 24)
	box.add_child(back)
	_hunger_fill = ColorRect.new()
	_hunger_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hunger_fill.position = Vector2(4, 38)
	_hunger_fill.size = Vector2(298, 16)
	box.add_child(_hunger_fill)
	_paint_hunger()


func _paint_hunger() -> void:
	var t := clampf(hunger / HUNGER_FULL, 0.0, 1.0)
	_hunger_fill.size.x = 298.0 * t
	if t > 0.5:
		_hunger_fill.color = Color(0.95, 0.78, 0.22).lerp(Color(0.3, 0.86, 0.4), (t - 0.5) * 2.0)
	else:
		_hunger_fill.color = Color(0.9, 0.22, 0.18).lerp(Color(0.95, 0.78, 0.22), t * 2.0)
	if t < 0.28:
		_hunger_label.text = "Acıktın!"
		_hunger_label.add_theme_color_override("font_color", Color(1, 0.45, 0.32))
	else:
		_hunger_label.text = "Tokluk"
		_hunger_label.add_theme_color_override("font_color", Color(1, 1, 1))


func _build_death_ui() -> void:
	_death_layer = Control.new()
	_death_layer.visible = false
	_death_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	$HUD/Root.add_child(_death_layer)
	var dim := ColorRect.new()
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.color = Color(0.02, 0.04, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_layer.add_child(dim)
	var msg := Label.new()
	msg.text = "Açlıktan öldün\n\nSpace: yeniden başla"
	msg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg.add_theme_font_size_override("font_size", 48)
	msg.add_theme_color_override("font_color", Color(1, 0.95, 0.9))
	msg.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.14))
	msg.add_theme_constant_override("outline_size", 12)
	_death_layer.add_child(msg)


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
	sky_mat.sky_top_color = Color(0.12, 0.32, 0.72)
	sky_mat.sky_horizon_color = Color(0.78, 0.88, 0.95)
	sky_mat.sky_curve = 0.12
	sky_mat.ground_horizon_color = Color(0.05, 0.2, 0.34)
	sky_mat.ground_bottom_color = Color(0.01, 0.04, 0.1)
	sky_mat.ground_curve = 0.08
	sky_mat.sun_angle_max = 22.0
	sky_mat.energy_multiplier = 1.15
	var sky := Sky.new()
	sky.sky_material = sky_mat
	_env.sky = sky
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.tonemap_exposure = 1.05
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.45, 0.62, 0.74)
	_env.ambient_light_energy = 0.55
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_env.fog_light_color = Color(0.1, 0.36, 0.52)
	_env.fog_density = 0.008
	_env.fog_aerial_perspective = 0.72
	_env.fog_sky_affect = 0.35
	_env.glow_enabled = true
	_env.glow_intensity = 0.22
	_env.glow_strength = 0.55
	_env.glow_bloom = 0.08
	var world := WorldEnvironment.new()
	world.environment = _env
	add_child(world)


func _build_sun() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-46, 34, 0)
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18, 210, 0)
	fill.light_color = Color(0.35, 0.58, 0.78)
	fill.light_energy = 0.28
	add_child(fill)


func _build_water() -> void:
	var water := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1200, 1200)
	plane.subdivide_width = 96
	plane.subdivide_depth = 96
	water.mesh = plane
	water.position = Vector3(0, Bounds.SURFACE_Y, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/sea.gdshader")
	var sun := get_node_or_null("Sun")
	if sun is DirectionalLight3D:
		mat.set_shader_parameter("sun_dir", -(sun as DirectionalLight3D).global_transform.basis.z)
	water.material_override = mat
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	_build_rays()


func _build_sand() -> void:
	var bed := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	var span := Bounds.HALF * 2.0 + 40.0
	plane.size = Vector2(span, span)
	plane.subdivide_width = 56
	plane.subdivide_depth = 56
	bed.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/sand.gdshader")
	mat.set_shader_parameter("half_extent", Bounds.HALF)
	mat.set_shader_parameter("shelf_y", Bounds.SHELF_Y)
	mat.set_shader_parameter("bed_y", Bounds.BED_Y)
	mat.set_shader_parameter("shelf_start", Bounds.SHELF_START)
	mat.set_shader_parameter("shelf_end", Bounds.SHELF_END)
	bed.material_override = mat
	bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bed)


func _build_rays() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(0.72, 0.88, 1.0, 0.04)
	var rng := RandomNumberGenerator.new()
	rng.seed = 260926
	for i in 11:
		var ray := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = rng.randf_range(4.0, 8.0)
		mesh.bottom_radius = mesh.top_radius * 1.4
		mesh.height = 95.0
		mesh.radial_segments = 8
		ray.mesh = mesh
		ray.material_override = mat
		ray.position = Vector3(rng.randf_range(-110.0, 110.0), -36.0, rng.randf_range(-110.0, 110.0))
		ray.rotation_degrees = Vector3(7.0, float(i) * 18.0, -5.0)
		ray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ray)


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
