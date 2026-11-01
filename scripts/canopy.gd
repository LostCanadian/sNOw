extends RefCounted
## Shared branch geometry: rendered paper twigs and simulation anchors cannot drift apart.

const LEFT_PATHS := [
	[Vector2(12, 502), Vector2(18, 390), Vector2(24, 290), Vector2(36, 220), Vector2(54, 166), Vector2(80, 123), Vector2(106, 86)],
	[Vector2(36, 220), Vector2(72, 198), Vector2(111, 173), Vector2(157, 155), Vector2(176, 129)],
	[Vector2(24, 290), Vector2(60, 270), Vector2(98, 251), Vector2(141, 234), Vector2(171, 211)],
	[Vector2(54, 166), Vector2(30, 135), Vector2(14, 102)],
	[Vector2(80, 123), Vector2(125, 116), Vector2(155, 97)],
	[Vector2(60, 270), Vector2(44, 235), Vector2(18, 207)],
	[Vector2(111, 173), Vector2(123, 137), Vector2(119, 119)],
	[Vector2(98, 251), Vector2(103, 218), Vector2(94, 200)],
	[Vector2(141, 234), Vector2(147, 204), Vector2(158, 183)],
]
const LEFT_LEAVES := [
	Vector2(18, 101), Vector2(31, 130), Vector2(45, 148), Vector2(60, 143),
	Vector2(76, 124), Vector2(93, 102), Vector2(109, 85), Vector2(126, 115),
	Vector2(144, 102), Vector2(158, 92), Vector2(60, 202), Vector2(77, 189),
	Vector2(96, 180), Vector2(113, 170), Vector2(132, 162), Vector2(152, 150),
	Vector2(171, 130), Vector2(120, 133), Vector2(45, 266), Vector2(64, 260),
	Vector2(85, 252), Vector2(108, 243), Vector2(135, 235), Vector2(163, 212),
]


static func tree_paths() -> Array[PackedVector2Array]:
	var paths: Array[PackedVector2Array] = []
	for side in range(2):
		for original in LEFT_PATHS:
			var path := PackedVector2Array()
			for p: Vector2 in original:
				path.append(Vector2(360 - p.x, p.y) if side == 1 else p)
			paths.append(path)
	return paths


static func slot_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var paths := tree_paths()
	for side in range(2):
		for i in range(LEFT_LEAVES.size()):
			var p: Vector2 = LEFT_LEAVES[i]
			if side == 1: p.x = 360 - p.x
			var closest := Vector2.ZERO
			var distance := INF
			for path in paths:
				for segment in range(path.size() - 1):
					var point := Geometry2D.get_closest_point_to_segment(p + Vector2(0, 10), path[segment], path[segment + 1])
					var d := point.distance_squared_to(p + Vector2(0, 10))
					if d < distance:
						distance = d
						closest = point
			result.append({"position": p, "stem": closest, "angle": sin(i * 2.3 + side) * 0.55, "leaf_id": result.size(), "attached_at": -10.0})
	return result
