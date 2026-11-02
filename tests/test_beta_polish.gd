extends SceneTree
const Loop=preload("res://scripts/loop.gd")
const Campaign=preload("res://scripts/campaign.gd")
const Piles=preload("res://scripts/leaf_piles.gd")
const Main=preload("res://main.tscn")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	check(Loop.Canopy.SLOT_COUNT==2160 and is_equal_approx(Loop.LEAF_RADIUS,7.8),"25 percent fewer leaves, 30 percent larger")
	var piles=Piles.new()
	var first:=piles.deposit(180,0)
	var last:=first
	for i in range(40):last=piles.deposit(180,i*2)
	check(last<first-40,"overlapping leaves create a growing pile, without a shallow height cap")
	check(piles.surface(180,1)>last+35,"front and rear piles have independent support surfaces")
	var game=Loop.new(77)
	var old:Dictionary=Campaign.snapshot(game)
	old.rules=6
	for id in range(2160,2880):old.leaf_ids.append(id)
	for i in range(80):old.leaf_ids[i]=-1
	old.missed=80;old.order=old.order.filter(func(id):return id>=80)
	var loaded=Campaign.restore(old)
	check(loaded!=null and loaded.missed==60 and loaded.attached_count()==2100,"dense previous saves migrate gaps proportionally")
	check(Campaign.valid_checkpoint(Campaign.snapshot(loaded)),"migrated saves remain valid and conserve unique identities")
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false)
	main.leaf_renderer.clear()
	var id:int=game.shedding_order[0]
	var slot:Dictionary=game.slots[game.find_attached_leaf(id)]
	main.leaf_renderer.leaf(id,slot.position,slot.angle,game.leaf_colour(id))
	main.leaf_renderer.upload()
	var rank:int=main.leaf_renderer.rank[id]
	var pose:PackedFloat32Array=main.leaf_renderer.buffers[0].slice(rank*12,rank*12+12)
	game.spawn_leaf()
	var leaf:Dictionary=game.leaves[0]
	main.leaf_renderer.leaf(leaf.id,leaf.position,leaf.angle,leaf.colour)
	main.leaf_renderer.upload()
	check(main.leaf_renderer.buffers[0].slice(rank*12,rank*12+12)==pose,"detachment preserves the same instance, depth, scale and pose")
	main.leaf_renderer.leaf(0,Vector2(180,495),0,Color.WHITE,1,true)
	main.leaf_renderer.leaf(1,Vector2(180,495),0,Color.WHITE,1,true)
	main.leaf_renderer.upload()
	check(main.leaf_renderer.buffers[2][main.leaf_renderer.rank[0]*12]>0 and main.leaf_renderer.buffers[0][main.leaf_renderer.rank[0]*12]==0,"front ground leaves transfer to the pass after the player")
	check(main.leaf_renderer.buffers[0][main.leaf_renderer.rank[1]*12]>0 and main.leaf_renderer.buffers[2][main.leaf_renderer.rank[1]*12]==0,"rear ground leaves remain in the pass before the player")
	main.preview_mode=true;main.preview_weather=1
	for flake in main.snow:flake.active=false
	main.snow_clock=1;main.advance_snow(0.01)
	check(main.snow.filter(func(f):return f.active).all(func(f):return f.y<0),"first warning snow starts above the screen")
	for i in range(80):main.advance_snow(0.1)
	var existing:Array=main.snow.filter(func(f):return f.active)
	main.snow_clock=1;main.advance_snow(0.01)
	check(main.snow.filter(func(f):return f.active and not existing.has(f)).all(func(f):return f.y<0),"increasing snow density never spawns a flake mid-screen")
	main.queue_free();await process_frame
	print("Beta polish: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
