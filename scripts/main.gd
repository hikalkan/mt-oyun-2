extends Node3D

const FishScript := preload("res://scripts/fish.gd")
const Bounds := preload("res://scripts/sea_bounds.gd")
const LEVELS := {
	"kolay": {"goal": 8, "hunger": 48.0, "bite": 18.0, "fish": 150, "title": "Kolay"},
	"orta": {"goal": 15, "hunger": 30.0, "bite": 12.0, "fish": 110, "title": "Orta"},
	"zor": {"goal": 25, "hunger": 16.0, "bite": 7.0, "fish": 72, "title": "Zor"},
}

@onready var player = $Player

var _player_count := 1
var _diff_key := "orta"
var _playing := false
var _finished := false
var _goal := 15
var _hunger_full := 30.0
var _bite_fill := 12.0
var _fish_count := 44
var _seats: Array[Seat] = []
var _env: Environment
var _menu: CanvasLayer
var _choice_buttons: Array[Button] = []
var _goal_label: Label
var _death_layer: Control
var _end_label: Label
var _divider: ColorRect
var _split_root: Control


func _ready() -> void:
	process_priority = -1
	_build_sky()
	_build_sun()
	_build_water()
	_build_sand()
	_add_seat(player, $HUD/Root/Score, $HUD/Root/Form, $HUD/Root/CameraMode, $HUD/Root/Hint)
	_build_goal_label()
	_build_death_ui()
	_build_menu()
	get_viewport().size_changed.connect(_layout_hud)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _process(delta: float) -> void:
	_update_fog()
	if not _playing or _finished:
		return
	for seat in _seats:
		if seat.dead:
			continue
		seat.hunger = maxf(seat.hunger - delta, 0.0)
		_paint_hunger(seat)
		if seat.hunger <= 0.0:
			_kill_seat(seat)
	if _living_count() == 0:
		_game_over()


func _unhandled_input(event: InputEvent) -> void:
	if _finished and event.is_action_pressed("ui_accept"):
		get_tree().reload_current_scene()


func _update_fog() -> void:
	var cam := _fog_camera()
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


func _fog_camera() -> Camera3D:
	var best: Camera3D = null
	var best_y := -9999.0
	for seat in _seats:
		if seat.who == null:
			continue
		var cam: Camera3D = seat.view_cam if seat.view_cam != null else seat.who.view_camera()
		if cam != null and cam.global_position.y > best_y:
			best = cam
			best_y = cam.global_position.y
	if best == null:
		best = get_viewport().get_camera_3d()
	return best


func _on_ate(at: Vector3, seat: Seat) -> void:
	if _finished or seat.dead:
		return
	seat.hunger = minf(_hunger_full, seat.hunger + _bite_fill)
	seat.score += 1
	_paint_hunger(seat)
	_refresh_score(seat)
	var pop := PlusOne.new()
	pop.position = at + Vector3(0, 0.6, 0)
	add_child(pop)
	if seat.score_tween:
		seat.score_tween.kill()
	seat.score_label.scale = Vector2(1.12, 1.12)
	seat.score_tween = create_tween()
	seat.score_tween.tween_property(seat.score_label, "scale", Vector2.ONE, 0.16)
	if _total_score() >= _goal:
		_win()


func _on_form(_form_label: String, seat: Seat) -> void:
	_style_form(seat)


func _on_camera(mode_label: String, seat: Seat) -> void:
	seat.camera_label.text = mode_label


func _add_seat(who, score_label: Label, form_label: Label, camera_label: Label, hint_label: Label) -> void:
	var seat := Seat.new()
	seat.who = who
	seat.score_label = score_label
	seat.form_label = form_label
	seat.camera_label = camera_label
	seat.hint_label = hint_label
	seat.hunger = _hunger_full
	_seats.append(seat)
	who.ate_fish.connect(_on_ate.bind(seat))
	who.form_changed.connect(_on_form.bind(seat))
	who.camera_changed.connect(_on_camera.bind(seat))
	_style_form(seat)
	seat.camera_label.text = who.camera_name()
	if hint_label:
		hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_hunger_bar(seat)
	_refresh_score(seat)


func _physics_process(_delta: float) -> void:
	if _playing:
		_sync_views()


func _start_game() -> void:
	if _playing:
		return
	_playing = true
	var level: Dictionary = LEVELS[_diff_key]
	_goal = int(level.goal)
	_hunger_full = float(level.hunger)
	_bite_fill = float(level.bite)
	_fish_count = int(level.fish)
	if _player_count == 2:
		_spawn_second()
		_setup_split()
	for seat in _seats:
		seat.hunger = _hunger_full
		_paint_hunger(seat)
	_spawn_fish()
	_layout_hud()
	_refresh_goal()
	_menu.hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _spawn_second() -> void:
	var body := CharacterBody3D.new()
	body.position = Vector3(18, -16, 14)
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_script(load("res://scripts/player.gd"))
	body.pad_id = 0
	body.body_layer = 16
	body.hood_layer = 8
	body.owns_screen = false
	add_child(body)
	body.begin_as_shark()
	body.yaw = PI
	var score_label := _hud_label("Yediğin balık: 0", 28)
	var form_label := _hud_label("Köpekbalığı", 24)
	var camera_label := _hud_label("Arkadan", 22)
	var hint := _hud_label("Kumanda    Sol çubuk: yüz    Sağ çubuk: bak\nA: yukarı    B: aşağı    X: değiş    Y: kamera\nRB: su fışkırt    LB: ses", 18)
	$HUD/Root.add_child(score_label)
	$HUD/Root.add_child(form_label)
	$HUD/Root.add_child(camera_label)
	$HUD/Root.add_child(hint)
	_add_seat(body, score_label, form_label, camera_label, hint)
	player.set_partner_body(body.body_layer)
	body.set_partner_body(player.body_layer)


func _setup_split() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	_split_root = Control.new()
	_split_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_split_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_split_root)
	for i in _seats.size():
		var seat := _seats[i]
		seat.who.set_owns_screen(false)
		var panel := SubViewportContainer.new()
		panel.stretch = true
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		if i == 0:
			panel.anchor_right = 0.5
		else:
			panel.anchor_left = 0.5
		var vp := SubViewport.new()
		vp.handle_input_locally = false
		vp.gui_disable_input = true
		vp.audio_listener_enable_3d = i == 0
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var cam := Camera3D.new()
		cam.fov = 58.0
		cam.near = 0.15
		cam.far = 1400.0
		cam.current = true
		vp.add_child(cam)
		panel.add_child(vp)
		_split_root.add_child(panel)
		vp.world_3d = get_world_3d()
		seat.panel = panel
		seat.view = vp
		seat.view_cam = cam
	_divider = ColorRect.new()
	_divider.color = Color(0.85, 0.95, 1, 0.85)
	_divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD/Root.add_child(_divider)


func _spawn_fish() -> void:
	var close_count := mini(28, _fish_count)
	var mid_count := mini(int(float(_fish_count) * 0.72), _fish_count)
	for i in _fish_count:
		var fish = FishScript.new()
		var around = _seats[i % _seats.size()].who.global_position
		var pos: Vector3
		if i < close_count:
			var ang := TAU * float(i) / float(close_count)
			pos = around + Vector3(cos(ang), randf_range(-8.0, 3.0), sin(ang)) * randf_range(8.0, 20.0)
			pos = Bounds.clamp_pos(pos, 2.0)
		elif i < mid_count:
			pos = Bounds.nearby_water(around, 14.0, 48.0)
		else:
			pos = Bounds.nearby_water(around, 36.0, 95.0)
		fish.position = pos
		add_child(fish)


func _kill_seat(seat: Seat) -> void:
	seat.dead = true
	seat.who.die()
	seat.hunger_label.text = "Açlıktan öldün"
	seat.hunger_label.add_theme_color_override("font_color", Color(1, 0.45, 0.32))
	_paint_hunger(seat)


func _win() -> void:
	_end(false)


func _game_over() -> void:
	_end(true)


func _end(lost: bool) -> void:
	if _finished:
		return
	_finished = true
	for seat in _seats:
		if not seat.dead:
			seat.who.die()
			seat.dead = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if lost:
		_end_label.text = "Açlıktan öldün\n\nSpace: yeniden başla" if _seats.size() == 1 else "Açlıktan öldünüz\n\nSpace: yeniden başla"
		_end_label.add_theme_color_override("font_color", Color(1, 0.9, 0.86))
	else:
		_end_label.text = "Kazandınız!\n\nSpace: yeniden başla"
		_end_label.add_theme_color_override("font_color", Color(0.75, 1, 0.7))
	_death_layer.visible = true


func _living_count() -> int:
	var count := 0
	for seat in _seats:
		if not seat.dead:
			count += 1
	return count


func _total_score() -> int:
	var total := 0
	for seat in _seats:
		total += seat.score
	return total


func _refresh_score(seat: Seat) -> void:
	seat.score_label.text = "Yediğin balık: %d" % seat.score
	_refresh_goal()


func _refresh_goal() -> void:
	if _goal_label:
		_goal_label.text = "Hedef: %d / %d" % [_total_score(), _goal]


func _sync_views() -> void:
	for seat in _seats:
		if seat.view_cam == null or seat.who == null:
			continue
		var src: Camera3D = seat.who.view_camera()
		seat.view_cam.global_transform = src.global_transform
		seat.view_cam.fov = src.fov
		seat.view_cam.near = src.near
		seat.view_cam.far = src.far
		seat.view_cam.cull_mask = src.cull_mask


func _layout_hud() -> void:
	var sz := get_viewport().get_visible_rect().size
	var count := _seats.size()
	if count == 0:
		return
	for i in count:
		var seat := _seats[i]
		var span := sz.x if count == 1 else sz.x * 0.5
		var left := span * float(i)
		_place_label(seat.score_label, left + 20.0, 12.0, left + span * 0.58, 50.0)
		_place_label(seat.form_label, left + 20.0, 50.0, left + span * 0.58, 84.0)
		_place_label(seat.camera_label, left + 20.0, 84.0, left + span * 0.58, 116.0)
		if seat.hint_label:
			_place_label(seat.hint_label, left + 20.0, 116.0, left + span - 16.0, 214.0)
		var bar_w := 220.0 if count > 1 else 300.0
		seat.bar_width = bar_w - 14.0
		seat.hunger_box.offset_left = left + span - bar_w - 16.0
		seat.hunger_box.offset_top = 14.0
		seat.hunger_box.offset_right = left + span - 16.0
		seat.hunger_box.offset_bottom = 78.0
		seat.hunger_back.size = Vector2(bar_w, 22.0)
		_paint_hunger(seat)
		if seat.view != null:
			var wanted := Vector2i(maxi(int(span), 2), maxi(int(sz.y), 2))
			if seat.view.size != wanted:
				seat.view.size = wanted
	if _goal_label:
		_goal_label.offset_left = sz.x * 0.5 - 160.0
		_goal_label.offset_right = sz.x * 0.5 + 160.0
	if _divider:
		_divider.offset_left = sz.x * 0.5 - 2.0
		_divider.offset_top = 0.0
		_divider.offset_right = sz.x * 0.5 + 2.0
		_divider.offset_bottom = sz.y


func _place_label(label: Label, left: float, top: float, right: float, bottom: float) -> void:
	label.offset_left = left
	label.offset_top = top
	label.offset_right = right
	label.offset_bottom = bottom


func _build_goal_label() -> void:
	_goal_label = _hud_label("Hedef: 0 / 15", 28)
	_goal_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$HUD/Root.add_child(_goal_label)
	_goal_label.offset_top = 10.0
	_goal_label.offset_bottom = 48.0


func _build_hunger_bar(seat: Seat) -> void:
	var box := Control.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	$HUD/Root.add_child(box)
	seat.hunger_box = box
	seat.hunger_label = _hud_label("Tokluk", 22)
	box.add_child(seat.hunger_label)
	var back := ColorRect.new()
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.color = Color(0.04, 0.08, 0.12, 0.8)
	back.position = Vector2(0, 32)
	back.size = Vector2(300, 22)
	box.add_child(back)
	seat.hunger_back = back
	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.position = Vector2(3, 35)
	fill.size = Vector2(286, 16)
	box.add_child(fill)
	seat.hunger_fill = fill
	seat.bar_width = 286.0
	_paint_hunger(seat)


func _paint_hunger(seat: Seat) -> void:
	if seat.hunger_fill == null:
		return
	var t := clampf(seat.hunger / _hunger_full, 0.0, 1.0)
	seat.hunger_fill.size.x = seat.bar_width * t
	if t > 0.5:
		seat.hunger_fill.color = Color(0.95, 0.78, 0.22).lerp(Color(0.3, 0.86, 0.4), (t - 0.5) * 2.0)
	else:
		seat.hunger_fill.color = Color(0.9, 0.22, 0.18).lerp(Color(0.95, 0.78, 0.22), t * 2.0)
	if seat.dead:
		return
	if t < 0.28:
		seat.hunger_label.text = "Acıktın!"
		seat.hunger_label.add_theme_color_override("font_color", Color(1, 0.45, 0.32))
	else:
		seat.hunger_label.text = "Tokluk"
		seat.hunger_label.add_theme_color_override("font_color", Color(1, 1, 1))


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
	_end_label = Label.new()
	_end_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_end_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_end_label.add_theme_font_size_override("font_size", 48)
	_end_label.add_theme_color_override("font_color", Color(1, 0.95, 0.9))
	_end_label.add_theme_color_override("font_outline_color", Color(0.05, 0.08, 0.14))
	_end_label.add_theme_constant_override("outline_size", 12)
	_death_layer.add_child(_end_label)


func _style_form(seat: Seat) -> void:
	seat.form_label.text = seat.who.form_name()
	if seat.who.is_shark():
		seat.form_label.add_theme_color_override("font_color", Color(0.9, 0.93, 0.96))
	else:
		seat.form_label.add_theme_color_override("font_color", Color(0.72, 0.9, 1))


func _build_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 40
	_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_menu)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.18, 0.34)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(center)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)
	var title := Label.new()
	title.text = "Deniz"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.85, 0.95, 1))
	box.add_child(title)
	box.add_child(_menu_caption("Kaç kişi?"))
	var people := HBoxContainer.new()
	people.alignment = BoxContainer.ALIGNMENT_CENTER
	people.add_theme_constant_override("separation", 16)
	box.add_child(people)
	people.add_child(_choice_button("1 kişi", "count", 1))
	people.add_child(_choice_button("2 kişi", "count", 2))
	var note := Label.new()
	note.text = "2. oyuncu kumandayı kullanır. Klavye 1. oyuncuda kalır."
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 20)
	note.add_theme_color_override("font_color", Color(0.8, 0.9, 1))
	box.add_child(note)
	box.add_child(_menu_caption("Zorluk"))
	var diffs := HBoxContainer.new()
	diffs.alignment = BoxContainer.ALIGNMENT_CENTER
	diffs.add_theme_constant_override("separation", 16)
	box.add_child(diffs)
	diffs.add_child(_choice_button("Kolay", "diff", "kolay"))
	diffs.add_child(_choice_button("Orta", "diff", "orta"))
	diffs.add_child(_choice_button("Zor", "diff", "zor"))
	var info := Label.new()
	info.name = "Info"
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_theme_font_size_override("font_size", 20)
	info.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	box.add_child(info)
	var start := Button.new()
	start.text = "Başla"
	start.custom_minimum_size = Vector2(280, 78)
	start.add_theme_font_size_override("font_size", 36)
	_style_choice(start, true)
	start.pressed.connect(_start_game)
	box.add_child(start)
	_refresh_menu()


func _menu_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	return label


func _choice_button(text: String, kind: String, value) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(180, 68)
	button.add_theme_font_size_override("font_size", 30)
	button.set_meta("kind", kind)
	button.set_meta("value", value)
	button.pressed.connect(_on_choice.bind(kind, value))
	_choice_buttons.append(button)
	return button


func _on_choice(kind: String, value) -> void:
	if kind == "count":
		_player_count = int(value)
	else:
		_diff_key = str(value)
	_refresh_menu()


func _refresh_menu() -> void:
	for button in _choice_buttons:
		var on := false
		if str(button.get_meta("kind")) == "count":
			on = int(button.get_meta("value")) == _player_count
		else:
			on = str(button.get_meta("value")) == _diff_key
		_style_choice(button, on)
	var info := _menu.find_child("Info", true, false) as Label
	if info:
		var level: Dictionary = LEVELS[_diff_key]
		info.text = "%d balık ye. Tokluk %d saniye sürer." % [int(level.goal), int(level.hunger)]


func _style_choice(button: Button, on: bool) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.95, 0.78, 0.22) if on else Color(0.1, 0.36, 0.56)
	box.set_corner_radius_all(14)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 8.0
	box.content_margin_bottom = 8.0
	button.add_theme_stylebox_override("normal", box)
	button.add_theme_stylebox_override("hover", box)
	button.add_theme_stylebox_override("pressed", box)
	button.add_theme_stylebox_override("focus", box)
	var font := Color(0.1, 0.14, 0.2) if on else Color(1, 1, 1)
	button.add_theme_color_override("font_color", font)
	button.add_theme_color_override("font_hover_color", font)
	button.add_theme_color_override("font_pressed_color", font)


func _hud_label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color(1, 1, 1))
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.1, 0.22, 0.9))
	label.add_theme_constant_override("outline_size", 8)
	return label


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


class Seat extends RefCounted:
	var who
	var hunger := 30.0
	var dead := false
	var score := 0
	var bar_width := 286.0
	var score_label: Label
	var form_label: Label
	var camera_label: Label
	var hint_label: Label
	var hunger_label: Label
	var hunger_fill: ColorRect
	var hunger_box: Control
	var hunger_back: ColorRect
	var view: SubViewport
	var view_cam: Camera3D
	var panel: SubViewportContainer
	var score_tween: Tween


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
