extends RefCounted
## A season tree adapted from the user-attached reference. Tips are original-image pixel coordinates.
## Keep 48 stable slot identities so existing campaign checkpoints remain usable.
const TREE_RECT := Rect2(45, 78, 300, 424)
const IMAGE_SIZE := Vector2(1024, 1536)
const TWIG_TIPS := [
	Vector2(80, 288),
	Vector2(108, 368),
	Vector2(143, 425),
	Vector2(219, 329),
	Vector2(252, 241),
	Vector2(224, 190),
	Vector2(267, 117),
	Vector2(294, 67),
	Vector2(366, 47),
	Vector2(406, 32),
	Vector2(449, 82),
	Vector2(503, 55),
	Vector2(532, 99),
	Vector2(594, 138),
	Vector2(648, 158),
	Vector2(696, 186),
	Vector2(759, 230),
	Vector2(842, 273),
	Vector2(890, 300),
	Vector2(949, 326),
	Vector2(988, 540),
	Vector2(959, 557),
	Vector2(907, 636),
	Vector2(930, 707),
	Vector2(977, 789),
	Vector2(917, 806),
	Vector2(840, 873),
	Vector2(766, 939),
	Vector2(105, 501),
	Vector2(68, 550),
	Vector2(79, 592),
	Vector2(106, 690),
	Vector2(70, 725),
	Vector2(181, 758),
	Vector2(198, 732),
	Vector2(210, 669),
	Vector2(218, 609),
	Vector2(265, 573),
	Vector2(249, 477),
	Vector2(285, 431),
	Vector2(323, 279),
	Vector2(356, 198),
	Vector2(377, 135),
	Vector2(397, 190),
	Vector2(447, 237),
	Vector2(517, 270),
	Vector2(565, 340),
	Vector2(630, 330),
]


static func slot_layout() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for tip: Vector2 in TWIG_TIPS:
		var uv := tip / IMAGE_SIZE
		var stem := TREE_RECT.position + uv * TREE_RECT.size
		var outward := (uv - Vector2(0.38, 0.48)).normalized()
		var p := stem + outward * 9.0
		p.x = clampf(p.x, 28, 332)
		p.y = maxf(p.y, 92)
		var angle := (p - stem).angle() + PI / 2.0
		result.append({"position": p, "stem": stem, "angle": angle, "leaf_id": result.size(), "attached_at": -10.0})
	return result
