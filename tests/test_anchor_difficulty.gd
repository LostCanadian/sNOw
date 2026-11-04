extends SceneTree
const Loop=preload("res://scripts/loop.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Anchors=preload("res://scripts/attachment_anchors.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func finale() -> RefCounted:
	var game=Loop.new(55);game.week=13;game.earned_points=24;game.points=24
	game.retire_seasonal_foliage();game.prepare_shedding()
	return game
func _initialize() -> void:
	var previous:=1000
	for week in range(1,14):
		var limit:=Anchors.level_limit(week)
		check(limit<previous and limit>=16,"week %d has a smaller, nonzero anchor limit"%week)
		previous=limit
	var game=finale()
	var count:int=game.attached_count()
	var before:Dictionary=Campaign.snapshot(game)
	game.anchors.rebuild(game.slots,game.week)
	check(game.attached_count()==960 and count==game.attached_count() and Campaign.snapshot(game)==before,"limiting anchors cannot remove foliage, change counters or consume physics RNG")
	check(game.anchors.active.size()==game.anchors.limit and game.anchors.limit==16,"the final stage exposes a bounded pool despite its many empty slots")
	var left:=INF;var right:=-INF;var high:=INF;var low:=-INF
	for index in game.anchors.active:
		var p:Vector2=game.slots[index].position
		left=minf(left,p.x);right=maxf(right,p.x);high=minf(high,p.y);low=maxf(low,p.y)
	check(right-left>160 and low-high>150,"active targets span the crown instead of clustering on one twig")
	var inactive:=-1
	for i in range(game.slots.size()):
		if game.slots[i].leaf_id>=0 or game.anchors.active.has(i):continue
		var nearest:=INF
		for target in game.anchors.active:nearest=minf(nearest,game.slots[i].position.distance_to(game.slots[target].position))
		if nearest>Loop.CAPTURE_RADIUS+2:inactive=i;break
	check(inactive>=0 and game.capture_slot(game.slots[inactive].position,game.slots[inactive].position)==-1,"a bare inactive branch does not accept a leaf")
	game.spawn_leaf();var leaf:Dictionary=game.leaves[-1];var home:int=leaf.home_slot
	game.week_time=6
	check(not game.anchors.active.has(home) and game.slots[home].leaf_id<0 and game.anchors.active.size()==16,"a newly vacated spot stays inactive when the pool is full, even after its branch cooldown")
	var held:Array=game.anchors.active.keys()
	var target:int=held[0];var p:Vector2=game.slots[target].position
	check(game.capture_slot(p,p,leaf)==target,"an eligible leaf can reach an older active target")
	leaf.position=p;game.resolve_leaf(leaf,true,target)
	var stable:=true
	for index in held:
		if index!=target:stable=stable and game.anchors.active.has(index)
	check(stable and not game.anchors.active.has(target) and game.anchors.active.size()==16,"filling an anchor replenishes one target and leaves all other targets fixed")
	game=finale();game.spawn_leaf();leaf=game.leaves[-1]
	target=game.anchors.active.keys()[0];p=game.slots[target].position
	check(game.capture_slot(p,p)==target and game.capture_slot(p,p,leaf)==-1,"the leaf cooldown blocks even an older ready anchor")
	game.week_time=Loop.LEAF_ATTACH_DELAY-0.01
	check(game.capture_slot(p,p,leaf)==-1,"the leaf stays unattached throughout its complete cooldown")
	game.week_time=Loop.LEAF_ATTACH_DELAY+0.01
	check(game.capture_slot(p,p,leaf)==target,"the same leaf can attach after its cooldown without waiting for its home spot")
	game=finale();game.spawn_leaf();leaf=game.leaves[-1];game.spawn_timer=999
	target=game.anchors.active.keys()[0];p=game.slots[target].position
	game.x=p.x-Loop.NOZZLE_OFFSET.x
	leaf.position=p+Vector2(0,2);leaf.velocity=Vector2(0,-25);leaf.lifted=true
	game.step(1.0/60,0,true)
	check(leaf.state=="air" and game.rescued==0,"real blower physics cannot immediately snap a newly knocked-off leaf into another ready branch")
	game.week_time=Loop.LEAF_ATTACH_DELAY+.01
	leaf.position=p+Vector2(0,2);leaf.velocity=Vector2(0,-25);leaf.lifted=true
	game.step(1.0/60,0,true)
	check(leaf.state=="rescued" and game.rescued==1,"real blower physics still rescues a settled leaf through the limited pool")
	game=finale()
	for i in range(20):game.spawn_leaf()
	game.spawn_timer=999;target=game.anchors.active.keys()[0];p=game.slots[target].position
	game.x=p.x-Loop.NOZZLE_OFFSET.x
	for falling in game.leaves:falling.position=p+Vector2(0,2);falling.velocity=Vector2(0,-25);falling.lifted=true
	game.step(1.0/60,0,true)
	check(game.rescued==0 and game.leaves.size()==20,"following a gust cannot instantly return a clump into older anchors")
	game.week_time=6
	leaf=game.leaves[0];leaf.age=0
	check(game.capture_slot(p,p,leaf)==target,"resetting animation age on a later ground recovery does not restart the original detachment cooldown")
	game=finale();before=Campaign.snapshot(game)
	var restored=Campaign.restore(before)
	check(restored!=null and restored.anchors.active==game.anchors.active and restored.rng.state==game.rng.state,"retry restores the same initial anchor pool without altering the leaf sequence")
	before.rules=10;restored=Campaign.restore(before)
	check(restored!=null and restored.anchors.limit==16 and restored.attached_count()==960,"older saves adopt the new anchor limits without losing their leaves")
	print("Anchor difficulty: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
