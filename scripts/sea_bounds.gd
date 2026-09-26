extends Object

const HALF := 78.0
const SURFACE_Y := 0.0
const BED_Y := -32.0


static func clamp_pos(p: Vector3, padding: float = 1.2) -> Vector3:
	p.x = clampf(p.x, -HALF, HALF)
	p.z = clampf(p.z, -HALF, HALF)
	p.y = clampf(p.y, BED_Y + padding, SURFACE_Y + 1.5)
	return p


static func random_water(avoid: Vector3) -> Vector3:
	var p := Vector3.ZERO
	for _i in 8:
		p = Vector3(
			randf_range(-HALF + 6.0, HALF - 6.0),
			randf_range(BED_Y + 4.0, -2.5),
			randf_range(-HALF + 6.0, HALF - 6.0)
		)
		if p.distance_to(avoid) >= 9.0:
			return p
	return clamp_pos(avoid + Vector3(14.0, -1.0, 4.0), 2.0)
