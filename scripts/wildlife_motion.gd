extends RefCounted
## Cosmetic routines. Perches come from painted bark; occupancy is read-only.
const Canopy=preload("res://scripts/canopy.gd")
const OWL_BARK := [Vector2(500,547),Vector2(570,559),Vector2(640,583),Vector2(510,651),Vector2(658,649),Vector2(682,892),Vector2(658,950),Vector2(902,982),Vector2(730,873),Vector2(820,914)]
const SQUIRREL_BARK := [Vector2(510,651),Vector2(658,649),Vector2(658,950),Vector2(682,892)]
const CLIMB_BARK := [Vector2(335,1310),Vector2(280,1150),Vector2(270,1000),Vector2(300,900),Vector2(345,810)]
var owl_perch:=tree_point(OWL_BARK[1])
var squirrel_perch:=tree_point(SQUIRREL_BARK[0])
var perch_key:=""
var look:=0.0
var flap_start:=-10.0
var next_flap:=8.0
var reaction_ready:=0.0
var seed_value:=0
static func tree_point(pixel:Vector2) -> Vector2:
	return Canopy.TREE_RECT.position+pixel/Vector2(1024,1536)*Canopy.TREE_RECT.size
func reset(seed:int) -> void:
	seed_value=seed;perch_key="";look=0;flap_start=-10;next_flap=7+seed%6;reaction_ready=0
func select_perches(slots:Array,variant:float) -> void:
	var stamp:=str(variant)
	if perch_key==stamp:return
	perch_key=stamp
	owl_perch=best_perch(OWL_BARK,slots,variant)
	squirrel_perch=best_perch(SQUIRREL_BARK,slots,variant,Vector2(5,-13))
static func best_perch(candidates:Array,slots:Array,variant:float,face_offset:=Vector2(0,-19)) -> Vector2:
	var best:=tree_point(candidates[0]);var lowest:=INF
	for bark:Vector2 in candidates:
		var perch:=tree_point(bark);var face:=perch+face_offset
		var crowd:=0.0
		for index in range(slots.size()):
			if slots[index].leaf_id<0:continue
			if variant>=0 and fmod(index*0.61803398875,1.0)<variant*0.8:continue
			var distance:float=face.distance_squared_to(slots[index].position)
			var body_distance:float=(perch-Vector2(0,8)).distance_squared_to(slots[index].position)
			if distance<900:crowd+=exp(-distance/120.0)
			if body_distance<625:crowd+=0.25*exp(-body_distance/180.0)
		if crowd<lowest:lowest=crowd;best=perch
	return best
func advance(dt:float,clock:float,player_x:float,blowing:bool,soft:bool,night:bool) -> void:
	var target:=clampf(atan2(player_x-owl_perch.x,455-owl_perch.y)/0.7,-1,1)
	look=lerpf(look,target,1-exp(-dt*7))
	if not night or soft:return
	var startle:=blowing and absf(player_x-owl_perch.x)<25 and clock>=reaction_ready
	if (clock>=next_flap or startle) and clock-flap_start>=1.0:
		flap_start=clock;next_flap=clock+13+seed_value%7
		if startle:reaction_ready=clock+12
func owl(clock:float,soft:bool) -> Dictionary:
	var frame:=clampi(roundi((look+1)*2),0,4)
	var action:="watch"
	if frame==2 and not soft and fmod(clock,4)>2.8:frame=7
	if not soft and clock-flap_start>=0 and clock-flap_start<1:
		frame=8+clampi(int((clock-flap_start)*8),0,7);action="flap"
	elif not soft:
		var blink:=fmod(clock+seed_value%3,5.7)
		if blink>5.43 and absf(look)<0.3:frame=5 if blink<5.57 else 6;action="blink"
	return {"kind":"owl","sheet":"owl","frame":frame,"position":owl_perch,"height":25.0,"direction":1,"alpha":1.0,"plane":"tree","action":action,"look":look}
func squirrel(clock:float,soft:bool) -> Dictionary:
	var t:=18.0 if soft else clock
	var position:=Vector2(0,466);var frame:=0;var action:="run"
	if t<3:
		position=Vector2(lerpf(-24,tree_point(CLIMB_BARK[0]).x,t/3),466)
		frame=int(t*9)%4
	elif t<10:
		var path:Array[Vector2]=[Vector2(tree_point(CLIMB_BARK[0]).x,466)]
		for point:Vector2 in CLIMB_BARK:path.append(tree_point(point))
		var p:float=(t-3)/7*(path.size()-1)
		var segment:=mini(int(p),path.size()-2)
		position=path[segment].lerp(path[segment+1],p-segment)
		frame=4+int(t*9)%4;action="climb"
	elif t<10.9:
		var p:float=(t-10)/0.9
		position=tree_point(CLIMB_BARK[-1]).lerp(squirrel_perch,p)-Vector2(0,sin(p*PI)*29)
		frame=8+mini(3,int(p*4));action="jump"
	else:
		position=squirrel_perch;action="perch";frame=12
		var nibble:=fmod(t-10.9+seed_value%4,9)
		if nibble>4:frame=13+int(nibble*5)%3;action="nibble"
	return {"kind":"squirrel","sheet":"squirrel","frame":frame,"position":position,"height":20.0,"direction":1,"alpha":1.0,"plane":"tree","action":action}
func squirrel_climbs(visit: int) -> bool:
	# A cosmetic coin toss stays stable across redraws, retries and pause.
	return (str(seed_value)+":squirrel:"+str(visit)).sha256_text().substr(0,8).hex_to_int()%2==0

func squirrel_ground(clock: float, soft: bool) -> Dictionary:
	var t:=6.0 if soft else maxf(0,clock)
	var x:=-65.0;var direction:=1;var running:=true
	if t<4:x=lerpf(-65,90,t/4)
	elif t<7:x=90;running=false
	elif t<12:x=lerpf(90,280,(t-7)/5)
	elif t<15:x=280;running=false
	elif t<20:x=lerpf(280,90,(t-15)/5);direction=-1
	elif t<23:x=90;direction=-1;running=false
	elif t<27:x=lerpf(90,-65,(t-23)/4);direction=-1
	else:direction=-1;running=false
	var frame:=int(t*9)%4 if running else (12 if soft else 13+int(t*5)%3)
	return {"kind":"squirrel","sheet":"squirrel","frame":frame,"position":Vector2(x,443),
		"height":20.0,"direction":direction,"alpha":1.0,"plane":"ground","action":"run" if running else "nibble"}

func squirrel_arrival(t: float) -> Dictionary:
	var pose:=squirrel(t,false)
	if t<3:pose.position.x=lerpf(-65,tree_point(CLIMB_BARK[0]).x,t/3)
	return pose

func squirrel_depart(t: float, clock: float) -> Dictionary:
	var pose:=squirrel_arrival(t)
	if t<10:
		pose.sheet="travel"
		pose.frame=8+int(clock*9)%4 if t>=3 else 12+int(clock*9)%4
		pose.action="descend" if t>=3 else "leave"
	else:pose.action="jump_back";pose.direction=-1
	return pose

func squirrel_visit(clock: float, soft: bool) -> Dictionary:
	var visit:=0 if soft else floori(clock/45.0)
	var t:=18.0 if soft else fposmod(clock,45.0)
	if not squirrel_climbs(visit):return squirrel_ground(t,soft)
	return squirrel_arrival(t) if t<=30.9 else squirrel_depart(maxf(0,41.8-t),clock)

func rabbit(clock:float,coat:float,soft:bool) -> Array[Dictionary]:
	var t:=fmod((0.0 if soft else clock)+seed_value%4,40)
	var x:=255.0;var direction:=1;var running:=false
	if t<4:pass
	elif t<9:x=lerpf(255,390,(t-4)/5);running=true
	elif t<11:x=390;direction=-1
	elif t<21:x=lerpf(390,110,(t-11)/10);direction=-1;running=true
	elif t<25:x=110;direction=-1
	elif t<30:x=lerpf(110,-30,(t-25)/5);direction=-1;running=true
	elif t<32:x=-30
	else:x=lerpf(-30,255,(t-32)/8);running=true
	var frame:=int(clock*8)%4 if running else 4
	var action:="hop" if running else "graze"
	if not running and not soft:
		var feeding:=fmod(clock,3.8)
		frame=4 if feeding<1 else 5+mini(2,int((feeding-1)/0.7))
	var lift:=absf(sin(clock*PI*3))*3.2 if running else 0.0
	var first:=mini(1,floori(coat));var mix:=coat-first
	var poses:Array[Dictionary]=[]
	for layer in range(2):
		var alpha:=1-mix if layer==0 else mix
		if alpha<0.001:continue
		poses.append({"kind":"rabbit","sheet":"rabbit","frame":(first+layer)*8+frame,"position":Vector2(x,443-lift),"height":20.0,"direction":direction,"alpha":alpha,"plane":"ground","action":action,"coat":first+layer})
	return poses
func wolf(clock:float,soft:bool) -> Dictionary:
	var t:=fmod(0.0 if soft else clock,48)
	var x:=80.0;var direction:=1;var walking:=false
	if t<4:pass
	elif t<14:x=lerpf(80,395,(t-4)/10);walking=true
	elif t<17:x=395;direction=-1
	elif t<30:x=lerpf(395,80,(t-17)/13);direction=-1;walking=true
	elif t<35:x=80;direction=-1
	elif t<40:x=lerpf(80,-35,(t-35)/5);direction=-1;walking=true
	elif t<44:x=-35
	else:x=lerpf(-35,80,(t-44)/4);walking=true
	var frame:=int(clock*8)%6 if walking else (6+int(clock/2)%2)
	if soft:frame=6
	return {"kind":"wolf","sheet":"rare","frame":frame,"position":Vector2(x,444),"height":25.0,"direction":direction,"alpha":0.90,"plane":"ground","action":"trot" if walking else "sniff"}
func bat(clock:float,soft:bool) -> Dictionary:
	var t:=0.0 if soft else clock
	return {"kind":"bat","sheet":"rare","frame":8+int(t*10)%8,"position":Vector2(180+sin(t*.42)*150,112+sin(t*.83)*23),"height":16.0,"direction":1 if cos(t*.42)>=0 else -1,"alpha":0.85,"plane":"ground","action":"fly"}
