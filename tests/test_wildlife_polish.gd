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
	check(settled and nibble_frames.size()>=3,"the climbing pose helper holds its branch until the visitor controller starts departure")
	var continuity:=true;var previous:Vector2=motion.squirrel(0,false).position
	for i in range(1,1500):
		var p:Vector2=motion.squirrel(i/120.0,false).position
		continuity=continuity and p.distance_to(previous)<2;previous=p
	check(continuity,"run, climb, jump and landing positions join continuously")
	var climbs:=0
	for visit in range(1000):climbs+=int(motion.squirrel_climbs(visit))
	check(climbs>=450 and climbs<=550,"about half of squirrel visits choose the tree")
	var again=Motion.new();again.reset(0)
	check(range(100).all(func(visit):return motion.squirrel_climbs(visit)==again.squirrel_climbs(visit)),"cosmetic route choices reproduce after resetting the same saved scene seed")
	var near_visits:=0;var ground_visits:=0
	for visit in range(1000):
		if not motion.squirrel_climbs(visit):
			ground_visits+=1;near_visits+=int(motion.squirrel_near_ground(visit))
	check(near_visits>ground_visits*0.4 and near_visits<ground_visits*0.6 and range(100).all(func(visit):return motion.squirrel_near_ground(visit)==again.squirrel_near_ground(visit)),"ground visits reproducibly choose both distant and foreground crossings")
	var ground_only:=true;var ground_smooth:=true;var directions:={};var ground_actions:={}
	var ground_previous:Vector2=motion.squirrel_ground(0,false).position
	for frame in range(1,3601):
		var pose:Dictionary=motion.squirrel_ground(frame/120.0,false)
		ground_only=ground_only and pose.plane=="ground" and pose.position.y==443 and pose.frame>=0 and pose.frame<16
		ground_smooth=ground_smooth and pose.position.distance_to(ground_previous)<1
		directions[pose.direction]=true;ground_actions[pose.action]=true;ground_previous=pose.position
	check(ground_only and ground_smooth and directions.size()==2 and ground_actions.has("run") and ground_actions.has("nibble"),"ground visits roam in both directions and nibble continuously without climbing")
	check(motion.squirrel_ground(0,false).position.x< -40 and motion.squirrel_ground(30,false).position.x< -40,"ground visits start and finish fully offscreen")
	check(motion.squirrel_visit(18,false).plane=="tree" and motion.squirrel_visit(45+18,false).plane in ["ground","near_ground"],"successive campaign visits actually use both selected routes")
	var near_smooth:=true;var near_previous:Vector2=motion.squirrel_ground(0,false,true).position
	for frame in range(1,3601):
		var pose:Dictionary=motion.squirrel_ground(frame/120.0,false,true)
		near_smooth=near_smooth and pose.plane=="near_ground" and pose.position.y==Motion.NEAR_GROUND_Y and pose.position.distance_to(near_previous)<1
		near_previous=pose.position
	check(near_smooth,"foreground crossings retain their depth throughout running, nibbling and departure")
	var far_squirrel:Dictionary=motion.squirrel_ground(8,false)
	var near_squirrel:Dictionary=motion.squirrel_ground(8,false,true)
	check(far_squirrel.height<near_squirrel.height and near_squirrel.height<motion.rabbit(8,0,false)[0].height*0.85,"a squirrel stays smaller than a rabbit, with a slight increase closer to the viewer")
	check(motion.rabbit(8,0,false)[0].height==20 and motion.rabbit(8.1,0,false)[0].height==20 and absf(motion.wolf(8,false).height-25)<0.25,"rabbit hops keep the existing body size and wolf scaling stays subtle")
	check(absf(motion.squirrel(3.001,false).height-motion.squirrel(2.999,false).height)<0.01 and motion.squirrel(6,false).height==20,"squirrel scale changes smoothly from the ground approach to the established branch size")
	var visit_continuous:=true;var visit_previous:Vector2=motion.squirrel_visit(0,false).position
	for frame in range(1,10801):
		var pose:Dictionary=motion.squirrel_visit(frame/120.0,false)
		visit_continuous=visit_continuous and (pose.position.distance_to(visit_previous)<2 or (pose.position.x< -40 and visit_previous.x< -40));visit_previous=pose.position
	check(visit_continuous,"campaign arrivals, descents, ground visits and route changes join offscreen without teleporting")
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
	check(assets and total==88,"all eighty-eight complete paper poses have valid bounds and smooth mipmaps")
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false)
	var resident:Node2D=main.scenery_layers[1];var meadow:Node2D=main.scenery_layers[2]
	check(resident.planes==["tree","near_ground"] and main.world.animals.planes==["ground"] and resident.z_index==-2 and resident.get_index()>main.scenery_layers[0].get_index() and resident.get_index()<meadow.get_index() and main.scenery_layers[3].z_index>resident.z_index,"near squirrels and tree residents draw over bark, under the meadow, leaves and player; distant animals stay behind bark")
	check(RootMeadow.cover_rect().end.y>=502 and RootMeadow.cover_rect().position.x<0 and RootMeadow.cover_rect().end.x>360,"the paper meadow extends beyond both screen edges to cover the side roots")
	world.queue_free();main.queue_free();await process_frame
	print("Wildlife polish: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
