extends Object

const WORLD_W := 4200.0
const WORLD_H := 2400.0
const SURFACE_Y := 280.0
const SAND_Y := 2100.0


static func random_water(avoid: Vector2) -> Vector2:
	var p := Vector2.ZERO
	for _i in 8:
		var y: float
		if randf() < 0.72:
			y = randf_range(SURFACE_Y + 180.0, SURFACE_Y + 1100.0)
		else:
			y = randf_range(SAND_Y - 600.0, SAND_Y - 150.0)
		p = Vector2(randf_range(180.0, WORLD_W - 180.0), y)
		if p.distance_to(avoid) >= 320.0:
			return p
	p.x = clampf(avoid.x + 700.0, 180.0, WORLD_W - 180.0)
	p.y = clampf(avoid.y + 280.0, SURFACE_Y + 160.0, SAND_Y - 160.0)
	return p
