extends SceneTree

const Actor = preload("res://scripts/paper_actor.gd")
const Loop = preload("res://scripts/loop.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	var actor = Actor.new()
	actor.advance(Actor.STRIDE, 1.0, false)
	check(is_zero_approx(actor.phase()), "one ground stride completes exactly one gait cycle")
	actor.reset()
	actor.advance(10, 0.2, false)
	var forward: float = actor.phase()
	actor.advance(-10, 0.2, false)
	check(actor.gait_distance == 20 and actor.phase() > forward, "turning keeps the gait advancing with actual ground distance")
	var stopped_phase: float = actor.phase()
	actor.advance(0, 2.0, false)
	check(actor.phase() == stopped_phase and actor.movement == 0, "standing or pushing a boundary cannot march in place")
	actor.reset()
	actor.advance(2, 0.2, false)
	var planted: Vector2 = actor.foot_target(0) + Vector2(2, 0)
	actor.advance(3, 0.01, false)
	check(planted.is_equal_approx(actor.foot_target(0) + Vector2(5, 0)), "stance foot stays planted in world space during forward travel")
	actor.reset()
	actor.advance(-2, 0.2, false)
	planted = actor.foot_target(0) * Vector2(-1, 1) + Vector2(-2, 0)
	actor.advance(-3, 0.01, false)
	check(planted.is_equal_approx(actor.foot_target(0) * Vector2(-1, 1) + Vector2(-5, 0)), "mirrored stance foot stays planted while running left")
	check(actor.motor_offset() == Vector2.ZERO, "blower is still while switched off")
	actor.advance(0, 0.13, true)
	var vibration: float = actor.motor_offset().length()
	check(vibration > 0 and vibration < 0.5, "running blower has a bounded local vibration")
	actor.advance(0, 0, true, true)
	check(actor.motor_offset().length() < vibration, "soft effects reduces motor vibration")
	check(Loop.new().nozzle().is_equal_approx(Vector2(180, Loop.GROUND) + Actor.NOZZLE_OFFSET), "physics nozzle uses the rig's rest nozzle")
	var finite := true
	for stride in range(84):
		actor.advance(1, 1.0 / 60, true)
		for uv in [Vector2(0.2, 0.8), Vector2(0.5, 0.9), Vector2(0.4, 1), Actor.NOZZLE_UV]:
			finite = finite and actor.point(uv).is_finite()
	check(finite, "two-bone skin stays finite throughout two strides")
	var forward_knees:=true
	for facing in [-1,1]:
		for frame in range(120):
			actor.advance(facing*1.2,1.0/60,false,false,facing)
			for joint in actor.joints:
				var direction:Vector2=(joint.ankle-joint.hip).normalized()
				# Screen-space mirror reverses both the facing and the knee offset.
				forward_knees=forward_knees and (joint.knee-joint.hip).dot(direction.orthogonal())>=0
	check(forward_knees,"both knees bend toward the toes through full strides in both directions")
	# Compare seeded flutter coefficients, lateral reversal and gravity through real steps.
	var game = Loop.new(77)
	game.spawn_leaf()
	var leaf: Dictionary = game.leaves[0]
	game.spawn_timer = 999
	leaf.position = Vector2(180, 100)
	leaf.velocity = Vector2.ZERO
	var positive := false
	var negative := false
	var falling := false
	var turned := false
	var initial_angle: float = leaf.angle
	for frame in range(240):
		game.step(1.0 / 60, 0, false)
		positive = positive or leaf.velocity.x > 2
		negative = negative or leaf.velocity.x < -2
		falling = falling or leaf.velocity.y > 20
		turned = turned or absf(leaf.angle - initial_angle) > 0.3
	check(positive and negative, "a falling leaf drifts in both lateral directions")
	check(falling, "gravity accelerates a free leaf downward")
	check(turned and leaf.roll >= 0.62 and leaf.roll <= 1.0, "flutter tumbles and foreshortens the paper leaf")
	game.spawn_leaf()
	check(game.leaves[0].flutter_phase != game.leaves[1].flutter_phase and game.leaves[0].drag != game.leaves[1].drag, "individual leaves receive different seeded aerodynamic properties")
	actor.rebuild(Actor.LIMBS,Rect2(0,0,256,256))
	check(actor.limb_mesh.get_surface_count() == 1 and actor.mesh.get_surface_count() == 1 and actor.limb_regions.size() == 18, "body and eighteen separate limb sprites have independent rendering surfaces")
	check(actor.limb_regions.all(func(rect): return rect.size.x > 80 and rect.size.y > 100), "limb bounds retain complete solid artwork instead of sampling transparent cell padding")
	print("Cutout animation and flutter: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
