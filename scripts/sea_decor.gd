extends Node2D

const Bounds := preload("res://scripts/sea_bounds.gd")

@export var foreground: bool = false

var kelps: Array = []
var rocks: Array = []
var corals: Array = []
var schools: Array = []
var clouds: Array = []
var birds: Array = []


func _ready() -> void:
	_build()


func _process(delta: float) -> void:
	if not foreground:
		_move_life(delta)
	queue_redraw()


func _build() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 260926
	kelps = []
	rocks = []
	corals = []
	schools = []
	clouds = []
	birds = []

	var x := 180.0
	var index := 0
	while x < 1520.0:
		kelps.append(_kelp(rng, x, rng.randf_range(240.0, 480.0), index % 4 == 0))
		x += rng.randf_range(72.0, 112.0)
		index += 1
	x = 1680.0
	while x < 2680.0:
		kelps.append(_kelp(rng, x, rng.randf_range(70.0, 150.0), false))
		x += rng.randf_range(130.0, 210.0)
	x = 3000.0
	while x < 4000.0:
		kelps.append(_kelp(rng, x, rng.randf_range(90.0, 190.0), false))
		x += rng.randf_range(170.0, 280.0)

	for n in 16:
		var rock := Rock.new()
		rock.center = Vector2(rng.randf_range(140.0, 4060.0), Bounds.SAND_Y + rng.randf_range(-6.0, 28.0))
		rock.rx = rng.randf_range(26.0, 74.0)
		rock.ry = rng.randf_range(16.0, 34.0)
		rock.seed = rng.randf() * 10.0
		rock.color = Color(rng.randf_range(0.32, 0.48), rng.randf_range(0.34, 0.46), rng.randf_range(0.38, 0.5))
		rocks.append(rock)

	var coral_colors: Array[Color] = [
		Color(0.95, 0.35, 0.45),
		Color(0.95, 0.5, 0.25),
		Color(0.72, 0.35, 0.75),
		Color(0.95, 0.72, 0.3),
		Color(0.85, 0.28, 0.42),
	]
	for n in 18:
		var coral := Coral.new()
		coral.at = Vector2(rng.randf_range(2760.0, 4060.0), Bounds.SAND_Y - rng.randf_range(0.0, 18.0))
		coral.color = coral_colors[n % coral_colors.size()]
		coral.scale = rng.randf_range(0.75, 1.3)
		corals.append(coral)

	for n in 3:
		var school := School.new()
		school.members = []
		school.phases = []
		school.pos = Vector2(640.0 + float(n) * 1150.0, Bounds.SURFACE_Y + 200.0 + float(n) * 140.0)
		var dir := 1.0 if n != 1 else -1.0
		school.vel = Vector2(rng.randf_range(26.0, 46.0) * dir, rng.randf_range(-8.0, 8.0))
		for m in 8:
			school.members.append(Vector2(rng.randf_range(-80.0, 80.0), rng.randf_range(-30.0, 30.0)))
			school.phases.append(rng.randf() * TAU)
		schools.append(school)

	for i in 7:
		var cloud := Cloud.new()
		cloud.pos = Vector2(rng.randf_range(-40.0, Bounds.WORLD_W), rng.randf_range(28.0, 190.0))
		cloud.r = rng.randf_range(30.0, 64.0)
		cloud.speed = rng.randf_range(8.0, 18.0)
		clouds.append(cloud)

	for i in 5:
		var bird := Bird.new()
		bird.home_y = rng.randf_range(64.0, 190.0)
		bird.pos = Vector2(rng.randf_range(0.0, Bounds.WORLD_W), bird.home_y)
		bird.speed = rng.randf_range(34.0, 60.0)
		bird.phase = rng.randf() * TAU
		birds.append(bird)


func _kelp(rng: RandomNumberGenerator, x: float, height: float, front: bool) -> Kelp:
	var kelp := Kelp.new()
	kelp.x = x + rng.randf_range(-10.0, 10.0)
	kelp.base_y = Bounds.SAND_Y + 6.0
	kelp.height = height
	kelp.width = rng.randf_range(16.0, 28.0)
	kelp.phase = rng.randf_range(0.0, TAU)
	kelp.color = Color(0.05, rng.randf_range(0.38, 0.56), rng.randf_range(0.2, 0.34))
	kelp.front = front
	return kelp


func _move_life(delta: float) -> void:
	for cloud in clouds:
		var p: Vector2 = cloud.pos
		p.x += cloud.speed * delta
		if p.x > Bounds.WORLD_W + 80.0:
			p.x = -100.0
		cloud.pos = p
	var tick := Time.get_ticks_msec() * 0.002
	for bird in birds:
		var p: Vector2 = bird.pos
		p.x += bird.speed * delta
		if p.x > Bounds.WORLD_W + 30.0:
			p.x = -30.0
		p.y = bird.home_y + sin(tick + bird.phase) * 12.0
		bird.pos = p
	var min_y := Bounds.SURFACE_Y + 90.0
	var max_y := Bounds.SURFACE_Y + 820.0
	for school in schools:
		var pos: Vector2 = school.pos + school.vel * delta
		var vel: Vector2 = school.vel
		if pos.x < 200.0 or pos.x > Bounds.WORLD_W - 200.0:
			vel.x = -vel.x
			pos.x = clampf(pos.x, 200.0, Bounds.WORLD_W - 200.0)
		if pos.y < min_y or pos.y > max_y:
			vel.y = -vel.y
			pos.y = clampf(pos.y, min_y, max_y)
		school.pos = pos
		school.vel = vel


func _draw() -> void:
	if foreground:
		for kelp in kelps:
			if kelp.front:
				_draw_kelp(kelp)
		return
	for cloud in clouds:
		_draw_cloud(cloud)
	for bird in birds:
		_draw_bird(bird)
	for school in schools:
		_draw_school(school)
	_draw_ripples()
	for rock in rocks:
		_draw_rock(rock)
	for coral in corals:
		_draw_coral(coral)
	for kelp in kelps:
		if not kelp.front:
			_draw_kelp(kelp)


func _draw_kelp(kelp: Kelp) -> void:
	var tsec := Time.get_ticks_msec() * 0.001
	var segments := 7
	var prev := Vector2(kelp.x, kelp.base_y)
	var prev_w := kelp.width
	for i in segments:
		var t := float(i + 1) / float(segments)
		var sway := sin(tsec * 0.95 + kelp.phase + t * 2.4) * (62.0 if kelp.front else 46.0) * t * t
		var p := Vector2(kelp.x + sway, kelp.base_y - kelp.height * t)
		var w := lerpf(kelp.width, kelp.width * 0.25, t)
		var dir := p - prev
		if dir.length_squared() < 0.001:
			dir = Vector2.UP
		dir = dir.normalized()
		var n := Vector2(-dir.y, dir.x)
		var col: Color = kelp.color.lerp(kelp.color.lightened(0.2), t)
		draw_colored_polygon(PackedVector2Array([
			prev + n * prev_w * 0.5,
			prev - n * prev_w * 0.5,
			p - n * w * 0.5,
			p + n * w * 0.5,
		]), col)
		draw_line(prev, p, kelp.color.lightened(0.35), 1.5)
		prev = p
		prev_w = w
	draw_circle(prev, prev_w * 0.55, kelp.color.lightened(0.12))


func _draw_rock(rock: Rock) -> void:
	var pts := PackedVector2Array()
	var count := 8
	for i in count:
		var a := TAU * float(i) / float(count)
		var jag := 0.82 + 0.18 * sin(float(i) * 1.7 + rock.seed)
		pts.append(rock.center + Vector2(cos(a) * rock.rx * jag, sin(a) * rock.ry * jag))
	draw_colored_polygon(pts, rock.color.darkened(0.12))
	draw_circle(rock.center + Vector2(-rock.rx * 0.18, -rock.ry * 0.22), rock.rx * 0.2, rock.color.lightened(0.22))


func _draw_coral(coral: Coral) -> void:
	var s: float = coral.scale
	var at: Vector2 = coral.at
	var col: Color = coral.color
	draw_circle(at, 16.0 * s, col.darkened(0.1))
	draw_circle(at + Vector2(-18, -28) * s, 13.0 * s, col)
	draw_circle(at + Vector2(16, -36) * s, 11.0 * s, col.lightened(0.08))
	draw_circle(at + Vector2(2, -58) * s, 9.0 * s, col)
	draw_circle(at + Vector2(-8, -46) * s, 6.0 * s, col.lightened(0.16))
	draw_circle(at + Vector2(22, -16) * s, 8.0 * s, col.darkened(0.05))


func _draw_cloud(cloud: Cloud) -> void:
	var col := Color(1, 1, 1, 0.88)
	draw_circle(cloud.pos, cloud.r, col)
	draw_circle(cloud.pos + Vector2(cloud.r * 0.8, 6), cloud.r * 0.72, col)
	draw_circle(cloud.pos + Vector2(-cloud.r * 0.7, 8), cloud.r * 0.62, col)


func _draw_bird(bird: Bird) -> void:
	var flap := sin(Time.get_ticks_msec() * 0.01 + bird.phase) * 6.0
	var p: Vector2 = bird.pos
	var ink := Color(0.15, 0.16, 0.2, 0.85)
	draw_line(p, p + Vector2(-12, flap), ink, 2.2)
	draw_line(p, p + Vector2(12, flap), ink, 2.2)


func _draw_school(school: School) -> void:
	var dir := 1.0 if school.vel.x >= 0.0 else -1.0
	var t := Time.get_ticks_msec() * 0.001
	for i in school.members.size():
		var phase: float = school.phases[i]
		var wob := Vector2(sin(t * 1.4 + phase), cos(t * 1.1 + phase)) * 5.0
		_draw_far_fish(school.pos + school.members[i] + wob, dir, phase)


func _draw_far_fish(p: Vector2, dir: float, phase: float) -> void:
	var wag := sin(Time.get_ticks_msec() * 0.004 + phase) * 3.0
	var fx := 1.0 if dir >= 0.0 else -1.0
	var nose := p + Vector2(8.0 * fx, 0.0)
	var back := p + Vector2(-6.0 * fx, 0.0)
	draw_colored_polygon(PackedVector2Array([
		nose,
		p + Vector2(0.0, -3.4),
		back,
		p + Vector2(0.0, 3.4),
	]), Color(0.62, 0.82, 0.9, 0.38))
	draw_colored_polygon(PackedVector2Array([
		back,
		back + Vector2(-6.0 * fx, -3.5 + wag),
		back + Vector2(-6.0 * fx, 3.5 - wag),
	]), Color(0.5, 0.74, 0.84, 0.32))


func _draw_ripples() -> void:
	var col := Color(0.55, 0.45, 0.28, 0.22)
	for i in 24:
		var y := Bounds.SAND_Y + 18.0 + float(i % 9) * 20.0
		var x := 90.0 + float(i) * 175.0
		draw_line(Vector2(x, y), Vector2(x + 64.0, y + 3.0), col, 2.0)


class Kelp extends RefCounted:
	var x: float
	var base_y: float
	var height: float
	var width: float
	var phase: float
	var color: Color
	var front: bool


class Rock extends RefCounted:
	var center: Vector2
	var rx: float
	var ry: float
	var seed: float
	var color: Color


class Coral extends RefCounted:
	var at: Vector2
	var color: Color
	var scale: float


class School extends RefCounted:
	var pos: Vector2
	var vel: Vector2
	var members: Array
	var phases: Array


class Cloud extends RefCounted:
	var pos: Vector2
	var r: float
	var speed: float


class Bird extends RefCounted:
	var pos: Vector2
	var home_y: float
	var speed: float
	var phase: float
