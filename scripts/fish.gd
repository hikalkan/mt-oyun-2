extends Area3D

const Bounds := preload("res://scripts/sea_bounds.gd")
const Blood := preload("res://scripts/blood.gd")
const COLORS: Array[Color] = [
	Color(1.0, 0.52, 0.16),
	Color(0.98, 0.78, 0.18),
	Color(0.78, 0.84, 0.9),
	Color(1.0, 0.45, 0.58),
	Color(0.15, 0.72, 0.78),
	Color(0.98, 0.42, 0.12),
]

var cruise_speed := 3.0
var wander := Vector3.FORWARD
var velocity := Vector3.ZERO
var base_scale := Vector3.ONE
var _eating := false
var _wander_wait := 0.0
var _tail: Node3D


func _ready() -> void:
	add_to_group("fish")
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	monitorable = true
	cruise_speed = randf_range(2.4, 4.2)
	wander = _new_wander()
	_wander_wait = randf_range(1.0, 2.5)
	var pattern := randi() % COLORS.size()
	base_scale = Vector3.ONE * randf_range(0.85, 1.35)
	scale = base_scale
	_build(COLORS[pattern], pattern == 5)
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)


func _physics_process(delta: float) -> void:
	if _eating:
		_wag(delta)
		return
	_wander_wait -= delta
	if _wander_wait <= 0.0:
		wander = _new_wander()
		_wander_wait = randf_range(1.4, 3.2)
	var desired := wander * cruise_speed
	var accel := 5.0
	var hunter = _nearest_player()
	if hunter != null:
		var offset: Vector3 = global_position - hunter.global_position
		var dist := offset.length()
		var radius: float = hunter.scare_radius()
		if dist < radius and dist > 0.2:
			var urgency := 1.0 - dist / radius
			desired = offset.normalized() * (cruise_speed * 0.85 + hunter.scare_power() * urgency)
			accel = 2.2
	velocity = velocity.move_toward(desired, accel * delta)
	global_position += velocity * delta
	global_position = Bounds.clamp_pos(global_position, 2.8)
	_face()
	_wag(delta)


func got_eaten() -> bool:
	if _eating:
		return false
	_eating = true
	set_deferred("monitorable", false)
	Blood.spill(get_parent(), global_position, 0.75)
	var tw := create_tween()
	tw.tween_property(self, "scale", base_scale * 0.05, 0.16)
	tw.tween_callback(_respawn)
	return true


func _respawn() -> void:
	var hunter = _nearest_player()
	if hunter != null:
		global_position = Bounds.nearby_water(hunter.global_position, 20.0, 62.0)
	else:
		global_position = Bounds.random_water(Vector3(9999, 9999, 9999))
	scale = base_scale
	velocity = Vector3.ZERO
	wander = _new_wander()
	_eating = false
	monitorable = true


func _face() -> void:
	if velocity.length() < 0.2:
		return
	var ahead := velocity.normalized()
	var up := Vector3.UP
	if absf(ahead.dot(Vector3.UP)) > 0.92:
		up = Vector3.FORWARD
	look_at(global_position + velocity, up)


func _wag(delta: float) -> void:
	if _tail:
		_tail.rotation.y = sin(Time.get_ticks_msec() * 0.012) * 0.45
	else:
		rotation.y += 0.0 * delta


func _nearest_player():
	var best = null
	var best_d := 1.0e20
	for who in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(who) or not who.alive:
			continue
		var dist := global_position.distance_squared_to(who.global_position)
		if dist < best_d:
			best_d = dist
			best = who
	return best


func _new_wander() -> Vector3:
	return Vector3(randf_range(-1.0, 1.0), randf_range(-0.35, 0.35), randf_range(-1.0, 1.0)).normalized()


func _build(color: Color, clown: bool) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.4
	var body := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.radial_segments = 12
	sphere.rings = 8
	body.mesh = sphere
	body.scale = Vector3(0.55, 0.42, 1.0)
	body.material_override = mat
	add_child(body)
	if clown:
		var band := MeshInstance3D.new()
		var band_mesh := SphereMesh.new()
		band_mesh.radius = 0.3
		band_mesh.height = 0.6
		band.mesh = band_mesh
		band.scale = Vector3(0.62, 0.48, 0.12)
		band.position = Vector3(0, 0, -0.05)
		var white := StandardMaterial3D.new()
		white.albedo_color = Color(0.98, 0.98, 0.96)
		band.material_override = white
		add_child(band)
	_tail = Node3D.new()
	_tail.position = Vector3(0, 0, 0.32)
	add_child(_tail)
	var tail := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.02, 0.28, 0.22)
	tail.mesh = box
	tail.position = Vector3(0, 0, 0.08)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = color.darkened(0.2)
	tail.material_override = dark
	_tail.add_child(tail)
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.045
	em.height = 0.09
	eye.mesh = em
	eye.position = Vector3(0.12, 0.06, -0.18)
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color(0.05, 0.05, 0.08)
	eye.material_override = emat
	add_child(eye)
