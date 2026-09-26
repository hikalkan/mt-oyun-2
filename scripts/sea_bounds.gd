extends Object

const HALF := 500.0
const SURFACE_Y := 0.0
const FLOOR_Y := -96.0
const CEILING_Y := -1.4
const CLEARANCE := 4.6


static func visual_span() -> float:
	return HALF * 2.0 + 520.0


static func floor_y(_x: float, _z: float) -> float:
	return FLOOR_Y


static func clamp_pos(p: Vector3, padding: float = CLEARANCE) -> Vector3:
	p.x = clampf(p.x, -HALF, HALF)
	p.z = clampf(p.z, -HALF, HALF)
	var floor := FLOOR_Y + maxf(padding, CLEARANCE)
	p.y = clampf(p.y, floor, CEILING_Y)
	return p


static func above_floor(p: Vector3, gap: float) -> Vector3:
	var min_y := FLOOR_Y + gap
	if p.y < min_y:
		p.y = min_y
	return p


static func nearby_water(around: Vector3, min_dist: float, max_dist: float) -> Vector3:
	for _i in 12:
		var ang := randf() * TAU
		var dist := randf_range(min_dist, max_dist)
		var x := clampf(around.x + cos(ang) * dist, -HALF + 14.0, HALF - 14.0)
		var z := clampf(around.z + sin(ang) * dist, -HALF + 14.0, HALF - 14.0)
		var low := FLOOR_Y + 8.0
		var high := CEILING_Y - 2.0
		var p := Vector3(x, randf_range(low, high), z)
		if p.distance_to(around) >= min_dist * 0.8:
			return p
	return clamp_pos(around + Vector3(min_dist, -6.0, 8.0))


static func random_water(avoid: Vector3) -> Vector3:
	var p := Vector3.ZERO
	for _i in 10:
		var x := randf_range(-HALF + 14.0, HALF - 14.0)
		var z := randf_range(-HALF + 14.0, HALF - 14.0)
		p = Vector3(x, randf_range(FLOOR_Y + 10.0, CEILING_Y - 3.0), z)
		if p.distance_to(avoid) >= 18.0:
			return p
	return clamp_pos(avoid + Vector3(30.0, -4.0, 10.0))
