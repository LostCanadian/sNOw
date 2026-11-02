extends RefCounted
## Frozen-score ending. Only airborne leaves are simulated; landed leaves stay cached.
const Loop = preload("res://scripts/loop.gd")
const Piles = preload("res://scripts/leaf_piles.gd")
const TICK := 1.0/30.0
var records: Array[Dictionary] = []
var phase := "idle"
var time := 0.0
var cover_time := 0.0
var attached := 0
var airborne := 0
var grounded := 0
var surface = Piles.new()
var pending: Array[int] = []
var active: Array[int] = []
var pending_index := 0
var accumulator := 0.0
var revision := 0

func begin(game) -> void:
	records.clear();pending.clear();active.clear();surface.clear()
	phase="falling";time=0;cover_time=0;attached=0;airborne=0;grounded=0
	pending_index=0;accumulator=0;revision+=1
	for index in range(game.slots.size()):
		var slot: Dictionary=game.slots[index]
		if slot.leaf_id>=0:
			var pose: Dictionary=game.attachment_pose(index)
			add_leaf(slot.leaf_id,pose.position,Vector2.ZERO,pose.angle,game.leaf_colour(slot.leaf_id),1,index,pose.roll)
	for leaf in game.ground_leaves:
		add_leaf(leaf.id,leaf.position,Vector2.ZERO,leaf.angle,leaf.colour,3,leaf.id,leaf.get("roll",1.0))
		surface.seed(leaf)
	for leaf in game.leaves:
		if leaf.state=="air":add_leaf(leaf.id,leaf.position,leaf.velocity,leaf.angle,leaf.colour,2,leaf.id,leaf.get("roll",1.0))
	pending.sort_custom(func(a,b):return records[a].release_at<records[b].release_at)

func add_leaf(id: int, position: Vector2, velocity: Vector2, angle: float, colour: Color, state: int, order: int, roll := 1.0) -> void:
	var seed:=fposmod(id*0.754877666,1.0)
	var index:=records.size()
	records.append({"id":id,"position":position,"previous":position,"velocity":velocity,"angle":angle,"colour":colour,
		"state":state,"release_at":0.35+(1.0-Loop.Canopy.depth(id))*1.4,"flutter":seed*TAU,"roll":roll,"order":order,"render_dirty":true})
	if state==1:attached+=1;pending.append(index)
	elif state==2:airborne+=1;active.append(index)
	else:grounded+=1

func cover() -> float:return smoothstep(0,2.2,cover_time)
func finished() -> bool:return phase=="done"
func blend() -> float:return clampf(accumulator/TICK,0,1)

func step(dt: float) -> void:
	if phase in ["idle","done"]:return
	accumulator+=minf(dt,0.1)
	while accumulator>=TICK:
		accumulator-=TICK
		advance_tick(TICK)

func advance_tick(dt: float) -> void:
	time+=dt
	if phase=="snow":
		cover_time+=dt
		if cover_time>=2.2:phase="done"
		return
	while pending_index<pending.size() and records[pending[pending_index]].release_at<=time:
		var index:=pending[pending_index];pending_index+=1
		var leaf: Dictionary=records[index]
		leaf.state=2;leaf.velocity=Vector2(sin(leaf.flutter)*9,3)
		attached-=1;airborne+=1;active.append(index)
	for i in range(active.size()-1,-1,-1):
		var leaf: Dictionary=records[active[i]]
		leaf.previous=leaf.position
		var velocity: Vector2=leaf.velocity
		velocity.x=lerpf(velocity.x,sin(time*2.4+leaf.flutter)*27-9,dt*2.0)
		velocity.y=minf(190,velocity.y+105*dt)
		leaf.position+=velocity*dt
		leaf.position.x=clampf(leaf.position.x,5,355)
		leaf.velocity=velocity
		leaf.angle+=(sin(time*3+leaf.flutter)*1.1+0.4)*dt
		leaf.roll=move_toward(leaf.roll,0.72+0.28*absf(cos(time*2+leaf.flutter)),dt*0.8)
		leaf.render_dirty=true
		if leaf.position.y>=surface.surface(leaf.position.x,leaf.id):
			leaf.position.y=surface.deposit(leaf.position.x,leaf.id)
			leaf.previous=leaf.position
			leaf.state=3;leaf.velocity=Vector2.ZERO
			airborne-=1;grounded+=1
			active[i]=active[-1];active.pop_back()
	revision+=1
	if attached==0 and airborne==0:phase="snow"

func finish_preview() -> void:
	surface.clear();active.clear();pending_index=pending.size()
	for leaf in records:
		leaf.state=3;leaf.position.y=surface.deposit(leaf.position.x,leaf.id)
		leaf.previous=leaf.position;leaf.render_dirty=true
	attached=0;airborne=0;grounded=records.size();phase="done";cover_time=2.2;revision+=1
