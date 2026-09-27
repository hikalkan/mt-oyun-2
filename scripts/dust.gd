extends RefCounted

static func puff(host: Node, at: Vector3, power: float = 1.0) -> void:
	if host == null:
		return
	var dust := CPUParticles3D.new()
	dust.position = at
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = int(8.0 + power * 6.0)
	dust.lifetime = 0.48
	dust.direction = Vector3(0.0, 1.0, 0.0)
	dust.spread = 32.0
	dust.gravity = Vector3(0.0, -1.6, 0.0)
	dust.initial_velocity_min = 0.35
	dust.initial_velocity_max = 1.5 * power
	dust.scale_amount_min = 0.45
	dust.scale_amount_max = 1.05
	var blob := SphereMesh.new()
	blob.radius = 0.07
	blob.height = 0.14
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.58, 0.46, 0.3, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 1.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	blob.material = mat
	dust.mesh = blob
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.62, 0.5, 0.32, 0.0))
	ramp.add_point(0.12, Color(0.6, 0.48, 0.3, 0.5))
	ramp.set_color(1, Color(0.45, 0.38, 0.26, 0.0))
	dust.color_ramp = ramp
	host.add_child(dust)
	dust.emitting = true
	host.get_tree().create_timer(0.6).timeout.connect(dust.queue_free)
