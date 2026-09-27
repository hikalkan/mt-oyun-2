extends RefCounted

static func spill(host: Node, at: Vector3, power: float = 1.0) -> void:
	if host == null:
		return
	var root := Node3D.new()
	root.position = at
	host.add_child(root)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.76, 0.05, 0.06)
	mat.roughness = 0.42
	var count := int(7.0 + power * 5.0)
	for i in count:
		var drop := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		var radius := randf_range(0.05, 0.13) * power
		mesh.radius = radius
		mesh.height = radius * 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		drop.mesh = mesh
		drop.material_override = mat
		root.add_child(drop)
		var dir := Vector3(randf_range(-1.0, 1.0), randf_range(0.35, 1.15), randf_range(-1.0, 1.0)).normalized()
		var hop := dir * randf_range(0.55, 1.6) * power
		hop.y = absf(hop.y) + randf_range(0.25, 0.7) * power
		var tw := drop.create_tween()
		tw.tween_property(drop, "position", hop, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(drop, "position", hop + Vector3(0.0, -1.15 * power, 0.0), 0.28)
		var fade := drop.create_tween()
		fade.tween_property(drop, "scale", Vector3(0.15, 0.15, 0.15), 0.42)
	var spray := CPUParticles3D.new()
	spray.one_shot = true
	spray.explosiveness = 1.0
	spray.amount = int(22.0 * power)
	spray.lifetime = 0.42
	spray.direction = Vector3(0.0, 1.0, 0.0)
	spray.spread = 78.0
	spray.gravity = Vector3(0.0, -14.0, 0.0)
	spray.initial_velocity_min = 2.2 * power
	spray.initial_velocity_max = 6.4 * power
	spray.scale_amount_min = 0.25
	spray.scale_amount_max = 0.7
	var blob := SphereMesh.new()
	blob.radius = 0.045 * power
	blob.height = 0.09 * power
	blob.material = mat
	spray.mesh = blob
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.9, 0.08, 0.07, 1.0))
	ramp.add_point(0.55, Color(0.55, 0.02, 0.03, 0.85))
	ramp.set_color(1, Color(0.4, 0.0, 0.02, 0.0))
	spray.color_ramp = ramp
	root.add_child(spray)
	spray.emitting = true
	host.get_tree().create_timer(0.62).timeout.connect(root.queue_free)
