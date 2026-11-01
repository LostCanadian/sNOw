extends RefCounted
## Artist-authored attachment metadata for the complete bare_tree.png illustration.
## Coordinates are original-image pixels, never independently reconstructed branches.
const TREE_RECT := Rect2(-44, 78, 244, 426)
const IMAGE_SIZE := Vector2(1024, 1536)
const TWIG_TIPS := [
	Vector2(373, 77),
	Vector2(531, 83),
	Vector2(602, 149),
	Vector2(816, 200),
	Vector2(917, 280),
	Vector2(900, 368),
	Vector2(999, 505),
	Vector2(910, 602),
	Vector2(933, 739),
	Vector2(863, 828),
	Vector2(645, 802),
	Vector2(569, 820),
	Vector2(447, 830),
	Vector2(390, 740),
	Vector2(456, 656),
	Vector2(563, 584),
	Vector2(630, 542),
	Vector2(682, 444),
	Vector2(755, 345),
	Vector2(690, 260),
	Vector2(567, 318),
	Vector2(485, 398),
	Vector2(400, 265),
	Vector2(360, 183),
]


static func slot_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for side in range(2):
		for tip: Vector2 in TWIG_TIPS:
			var uv := tip / IMAGE_SIZE
			var stem := TREE_RECT.position + uv * TREE_RECT.size
			var outward := (uv - Vector2(0.30, 0.46)).normalized()
			var p := stem + outward * 9.0
			p.x = clampf(p.x, 28, 332)
			p.y = maxf(p.y, 92)
			if side == 1:
				stem.x = 360 - stem.x
				p.x = 360 - p.x
			var angle := (p - stem).angle() + PI / 2.0
			result.append({"position": p, "stem": stem, "angle": angle, "leaf_id": result.size(), "attached_at": -10.0})
	return result
