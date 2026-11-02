extends SceneTree
const Loop = preload("res://scripts/loop.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	var game = Loop.new(55)
	var coverers := Loop.Canopy.foreground_coverers(game.slots)
	var released := {}
	var visible := true
	for id in game.shedding_order:
		var index: int = game.find_attached_leaf(id)
		for front in coverers[index]: visible = visible and released.has(front)
		released[index] = true
	check(visible, "each scheduled leaf is exposed before its turn, using the renderer's actual draw order")
	var velocities := []
	for across in [-36, 0, 36]:
		game = Loop.new(77)
		game.spawn_leaf()
		game.spawn_timer = 999
		game.leaves[0].position = game.nozzle() + Vector2(across, -60)
		game.leaves[0].velocity = Vector2.ZERO
		game.step(1.0 / 60, 0, true)
		velocities.append(game.leaves[0].velocity.x)
	check(velocities[0] < velocities[1] - 1 and velocities[2] > velocities[1] + 1, "left, center and right cone positions produce progressively rightward forces")
	game = Loop.new(9)
	game.spawn_leaf()
	game.spawn_leaf()
	game.spawn_timer = 999
	for leaf in game.leaves:
		leaf.position = game.nozzle() + Vector2(0,-60)
		leaf.velocity = Vector2.ZERO
	game.step(1.0/60,0,true)
	check(absf(game.leaves[0].velocity.x-game.leaves[1].velocity.x) > 0.05, "overlapping leaves receive independent turbulence rather than one shared horizontal lane")
	check(game.attached_count() + game.leaves.size() == Loop.Canopy.SLOT_COUNT, "new detachment and airflow preserve actual leaf identities")
	print("Leaf polish: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
