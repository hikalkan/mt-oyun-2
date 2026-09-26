extends Object

const HALF := 260.0
const SURFACE_Y := 0.0
const SHELF_Y := -78.0
const BED_Y := -170.0
const SHELF_START := 0.18
const SHELF_END := 0.9


static func floor_y(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z) / HALF
	var t := smoothstep(SHELF_START, SHELF_END, r)
	return lerpf(SHELF_Y, BED_Y, t)


static func clamp_pos(p: Vector3, padding: float = 2.6) -> Vector3:
	p.x = clampf(p.x, -HALF, HALF)
	p.z = clampf(p.z, -HALF, HALF)
	var floor := floor_y(p.x, p.z) + padding
	p.y = clampf(p.y, floor, SURFACE_Y + 2.4)
	return p


static func random_water(avoid: Vector3) -> Vector3:
	var p := Vector3.ZERO
	for _i in 10:
		var x := randf_range(-HALF + 14.0, HALF - 14.0)
		var z := randf_range(-HALF + 14.0, HALF - 14.0)
		var low := floor_y(x, z) + 8.0
		var high := -4.0
		if low > high - 2.0:
			high = low + 6.0
		p = Vector3(x, randf_range(low, high), z)
		if p.distance_to(avoid) >= 18.0:
			return p
	return clamp_pos(avoid + Vector3(30.0, -4.0, 10.0), 3.0)
