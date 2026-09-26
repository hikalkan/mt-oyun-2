extends Area2D

const Bounds := preload("res://scripts/sea_bounds.gd")
const COLORS: Array[Color] = [
	Color(1.0, 0.52, 0.16),
	Color(0.98, 0.78, 0.18),
	Color(0.78, 0.84, 0.9),
	Color(1.0, 0.45, 0.58),
	Color(0.15, 0.72, 0.78),
	Color(0.98, 0.42, 0.12),
]

var cruise_speed := 80.0
var wander := 0.0
var facing := 1.0
var velocity := Vector2.ZERO
var color := Color(1, 0.6, 0.2)
var pattern := 0
var base_scale := Vector2.ONE
var _eating := false
var player = null


func _ready() -> void:
	add_to_group("fish")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	cruise_speed = randf_range(58.0, 102.0)
	wander = randf() * TAU
	pattern = randi() % COLORS.size()
	color = COLORS[pattern]
	base_scale = Vector2.ONE * randf_range(0.82, 1.28)
	scale = base_scale
	var shape := CircleShape2D.new()
	shape.radius = 13.0
	var col := CollisionShape2D.new()
	col.shape = shape
	add_child(col)
	player = get_tree().get_first_node_in_group("player")


func _physics_process(delta: float) -> void:
	if _eating:
		return
	wander += randf_range(-1.3, 1.3) * delta
	var desired := Vector2.from_angle(wander) * cruise_speed
	if is_instance_valid(player):
		var offset: Vector2 = global_position - player.global_position
		var dist := offset.length()
		var radius: float = player.scare_radius()
		if dist < radius and dist > 0.5:
			var urgency := 1.0 - dist / radius
			var away := offset / dist
			var panic := sin(Time.get_ticks_msec() * 0.015) * 0.35 * urgency
			desired = away.rotated(panic) * (cruise_speed + player.scare_power() * urgency)
	velocity = velocity.move_toward(desired, 520.0 * delta)
	global_position += velocity * delta
	_clamp_pos()
	if velocity.x > 6.0:
		facing = 1.0
	elif velocity.x < -6.0:
		facing = -1.0


func _process(_delta: float) -> void:
	queue_redraw()


func _clamp_pos() -> void:
	var p := global_position
	var min_x := 100.0
	var max_x := Bounds.WORLD_W - 100.0
	var min_y := Bounds.SURFACE_Y + 70.0
	var max_y := Bounds.SAND_Y - 80.0
	if p.x < min_x:
		p.x = min_x
		velocity.x = absf(velocity.x)
		wander = 0.2
	elif p.x > max_x:
		p.x = max_x
		velocity.x = -absf(velocity.x)
		wander = PI
	if p.y < min_y:
		p.y = min_y
		velocity.y = absf(velocity.y)
	elif p.y > max_y:
		p.y = max_y
		velocity.y = -absf(velocity.y)
	global_position = p


func got_eaten() -> bool:
	if _eating:
		return false
	_eating = true
	set_deferred("monitorable", false)
	var tw := create_tween()
	tw.tween_property(self, "scale", base_scale * 0.05, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(_respawn)
	return true


func _respawn() -> void:
	var avoid := Vector2(-99999, -99999)
	if is_instance_valid(player):
		avoid = player.global_position
	global_position = Bounds.random_water(avoid)
	scale = base_scale
	velocity = Vector2.ZERO
	wander = randf() * TAU
	_eating = false
	monitorable = true


func _draw() -> void:
	var wag := sin(Time.get_ticks_msec() * 0.012 + wander) * 6.0
	var tilt := clampf(velocity.y / 180.0, -0.45, 0.45)
	if facing < 0.0:
		tilt = -tilt
	draw_set_transform(Vector2.ZERO, tilt, Vector2(facing, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-12, 0),
		Vector2(-24, -7 + wag * 0.45),
		Vector2(-24, 7 - wag * 0.45),
	]), color.darkened(0.22))
	draw_colored_polygon(_ellipse(Vector2.ZERO, 17.4, 9.1, 14), color.darkened(0.3))
	draw_colored_polygon(_ellipse(Vector2.ZERO, 15.6, 7.6, 14), color)
	draw_colored_polygon(_ellipse(Vector2(1, 2.6), 10.0, 4.0, 10), color.lightened(0.32))
	if pattern == 5:
		draw_line(Vector2(5, -7.4), Vector2(3, 7.4), Color(1, 1, 1, 0.95), 3.4)
		draw_line(Vector2(-5, -7.2), Vector2(-6, 7.2), Color(1, 1, 1, 0.95), 2.8)
	elif pattern == 1:
		draw_line(Vector2(2, -7), Vector2(0, 7), color.darkened(0.35), 2.4)
		draw_line(Vector2(-6, -6), Vector2(-7, 6), color.darkened(0.35), 2.0)
	elif pattern == 2:
		draw_line(Vector2(8, -3), Vector2(-4, 2), Color(1, 1, 1, 0.4), 2.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-2, -7), Vector2(2, -13), Vector2(6, -6),
	]), color.darkened(0.15))
	draw_circle(Vector2(8.2, -1.8), 2.3, Color(0.96, 0.96, 0.94))
	draw_circle(Vector2(9.0, -1.8), 1.15, Color(0.05, 0.06, 0.08))


func _ellipse(center: Vector2, rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts
