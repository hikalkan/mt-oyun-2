extends Object

const HALF := 180.0
const CLEARANCE := 2.0


static func visual_span() -> float:
	return HALF * 2.0 + 80.0


static func ground_y(x: float, z: float) -> float:
	return sin(x * 0.02) * 2.2 + cos(z * 0.017) * 1.8 + sin((x + z) * 0.008) * 3.0


static func clamp_xz(p: Vector3, padding: float = CLEARANCE) -> Vector3:
	var limit := HALF - padding
	p.x = clampf(p.x, -limit, limit)
	p.z = clampf(p.z, -limit, limit)
	return p


static func stand(p: Vector3, padding: float = CLEARANCE) -> Vector3:
	p = clamp_xz(p, padding)
	p.y = ground_y(p.x, p.z)
	return p


static func above_ground(p: Vector3, gap: float) -> Vector3:
	var min_y := ground_y(p.x, p.z) + gap
	if p.y < min_y:
		p.y = min_y
	return p


static func nearby(around: Vector3, min_dist: float, max_dist: float) -> Vector3:
	for _i in 12:
		var ang := randf() * TAU
		var dist := randf_range(min_dist, max_dist)
		var x := clampf(around.x + cos(ang) * dist, -HALF + 12.0, HALF - 12.0)
		var z := clampf(around.z + sin(ang) * dist, -HALF + 12.0, HALF - 12.0)
		var p := Vector3(x, 0.0, z)
		if Vector2(p.x - around.x, p.z - around.z).length() >= min_dist * 0.75:
			return stand(p, 8.0)
	return stand(around + Vector3(min_dist, 0.0, 8.0), 8.0)
