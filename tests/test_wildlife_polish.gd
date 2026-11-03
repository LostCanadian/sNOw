extends SceneTree
const World=preload("res://scripts/ambient_world.gd")
const Motion=preload("res://scripts/wildlife_motion.gd")
const Sprites=preload("res://scripts/animal_sprites.gd")
const Main=preload("res://main.tscn")
const RootMeadow=preload("res://scripts/root_meadow.gd")
const Loop=preload("res://scripts/loop.gd")
const Campaign=preload("res://scripts/campaign.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var tree:Image=preload("res://assets/art/season_tree.png").get_image()
	var bark:=true
	for p:Vector2 in Motion.OWL_BARK+Motion.SQUIRREL_BARK+Motion.CLIMB_BARK:bark=bark and tree.get_pixel(int(p.x),int(p.y)).a>0.86
	check(bark,"all perches and climbing waypoints lie on the painted main tree")
	var candidates:=[Motion.OWL_BARK[0],Motion.OWL_BARK[-1]]
	var leaves:Array=[]
	for i in range(24):leaves.append({"leaf_id":i,"position":Motion.tree_point(candidates[0])-Vector2(0,12)})
	check(Motion.best_perch(candidates,leaves,-1)==Motion.tree_point(candidates[1]),"the owl selects the open branch instead of the leaf-covered one")
	var game=Loop.new();var before:Dictionary=Campaign.snapshot(game)
	var world=World.new();root.add_child(world);world.configure(game.run_id,6);world.set_canopy(game.slots)
	var perch:Vector2=world.motion.owl_perch
	for slot in game.slots:slot.leaf_id=-1
	world.set_canopy(game.slots)
	check(world.motion.owl_perch==perch,"later leaf loss cannot teleport an already perched owl")
	var other=Loop.new();var checkpoint:Dictionary=Campaign.snapshot(other)
	world.configure(other.run_id,6);world.set_canopy(other.slots);world.advance(0.2,false,false,false,false,0)
	check(Campaign.snapshot(other)==checkpoint,"perch selection, gaze and wildlife movement cannot mutate a campaign or its RNG")
	var motion=Motion.new();motion.reset(0)
	for step in range(8):motion.advance(0.1,step*.1,29,false,false,true)
	var left:Dictionary=motion.owl(0.8,false)
	for step in range(8):motion.advance(0.1,1+step*.1,331,false,false,true)
	var right:Dictionary=motion.owl(1.8,false)
	check(left.look<0 and right.look>0 and left.frame<right.frame,"the front-view owl turns its head toward the moving player")
	motion.next_flap=0;motion.advance(0.01,2,180,false,false,true)
	var flap_frames:={}
	for i in range(8):flap_frames[motion.owl(2+(i+.1)/8.0,false).frame]=true
	check(flap_frames.size()==8 and motion.owl(3.1,false).action!="flap","an occasional perched wing beat plays eight distinct frames then settles")
	var run_frames:={};var climb_frames:={};var jump_frames:={};var nibble_frames:={}
	for i in range(40):
		run_frames[motion.squirrel(i/20.0,false).frame]=true
		climb_frames[motion.squirrel(3.2+i/10.0,false).frame]=true
		jump_frames[motion.squirrel(10.0+i*.02,false).frame]=true
		nibble_frames[motion.squirrel(15+i*.1,false).frame]=true
	check(run_frames.size()==4 and climb_frames.size()==4 and jump_frames.size()==4,"squirrel locomotion uses authored running, climbing and jumping cycles")
	var settled:=true
	for i in range(110,3000):
		var pose:Dictionary=motion.squirrel(i/10.0,false)
		settled=settled and pose.position==motion.squirrel_perch and pose.action in ["perch","nibble"]
	check(settled and nibble_frames.size()>=3,"the squirrel stays on its branch and occasionally nibbles instead of restarting its climb")
	var continuity:=true;var previous:Vector2=motion.squirrel(0,false).position
	for i in range(1,1500):
		var p:Vector2=motion.squirrel(i/120.0,false).position
		continuity=continuity and p.distance_to(previous)<2;previous=p
	check(continuity,"run, climb, jump and landing positions join continuously")
	var rabbit_out:Dictionary=motion.rabbit(9.5,0,false)[0]
	var rabbit_back:Dictionary=motion.rabbit(15,0,false)[0]
	check(rabbit_out.position.x>380 and rabbit_back.direction==-1 and rabbit_back.position.x<360,"a rabbit that exits right returns into view facing left")
	var graze_frames:={}
	for i in range(36):graze_frames[motion.rabbit(i*.1,0,false)[0].frame]=true
	check(graze_frames.size()==4,"the rabbit alternates alert, nose-down, nibbling and head-raising poses")
	check(motion.rabbit(39.999,0,false)[0].position.distance_to(motion.rabbit(40,0,false)[0].position)<1,"the rabbit route closes without an on-screen position jump")
	var coats:Array=motion.rabbit(1,1.4,false)
	check(coats.size()==2 and coats[0].frame%8==coats[1].frame%8 and is_equal_approx(coats[0].alpha+coats[1].alpha,1),"seasonal coats crossfade the same animation phase")
	var wolf_frames:={};var bat_frames:={}
	for i in range(8):
		wolf_frames[motion.wolf(5+(i+.25)/8.0,false).frame]=true
		bat_frames[motion.bat((i+.25)/10.0,false).frame]=true
	check(wolf_frames.size()==6 and bat_frames.size()==8,"rare visitors have a six-frame trot and eight-frame wing cycle")
	check(motion.wolf(16,false).position.x>380 and motion.wolf(20,false).direction==-1,"the wolf also returns from its offscreen turnaround")
	var saved:Dictionary=World.Profile.choose("preview-isolation",6)
	world.configure("preview-isolation",6,true);world.preview_full_moon();world.advance(0.1,false,false,false,false,0)
	check(world.profile.rare and world.animal_poses().any(func(a):return a.kind=="bat"),"the night preview can explicitly show the rare visitors")
	world.configure("preview-isolation",6,false)
	check(world.profile==saved,"forcing a preview full moon cannot change the campaign's selected moon or wildlife")
	var assets:=true;var total:=0
	for name in Sprites.SHEETS:
		var image:Image=Sprites.SHEETS[name].get_image()
		assets=assets and image.get_mipmap_count()>0
		for rect:Rect2 in Sprites.RECTS[name]:assets=assets and rect.size.x>40 and rect.size.y>40 and Rect2(Vector2.ZERO,image.get_size()).encloses(rect)
		total+=Sprites.RECTS[name].size()
	check(assets and total==72,"all seventy-two complete paper poses have valid bounds and smooth mipmaps")
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false)
	var resident:Node2D=main.scenery_layers[1];var meadow:Node2D=main.scenery_layers[2]
	check(resident.plane=="tree" and resident.z_index==-2 and resident.get_index()<meadow.get_index() and main.scenery_layers[3].z_index>resident.z_index,"tree residents draw over bark, under the meadow, leaves and player")
	check(RootMeadow.cover_rect().end.y>=502 and RootMeadow.cover_rect().position.x<=20 and RootMeadow.cover_rect().end.x>=340,"the paper meadow covers the lower root fan across the tree base")
	world.queue_free();main.queue_free();await process_frame
	print("Wildlife polish: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
