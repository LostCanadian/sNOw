extends RefCounted
## A bounded pool of empty catching spots, independent of foliage occupancy.
const LIMITS:=[64,60,56,52,48,44,40,36,32,28,24,20,16]
const CELL:=24.0
var limit:=64
var active:Dictionary={}
var gaps:Dictionary={}
var recent:Array[Vector2]=[]
static func level_limit(week:int) -> int:
	return LIMITS[clampi(week-1,0,LIMITS.size()-1)]
func rebuild(slots:Array,week:int) -> void:
	limit=level_limit(week);active.clear();gaps.clear();recent.clear()
	for i in range(slots.size()):
		slots[i].anchor_active=false
		if slots[i].leaf_id<0:add_gap(i,slots[i].position)
	refill(slots)
func add_gap(index:int,position:Vector2) -> void:
	var cell:=Vector2i(position/CELL)
	if not gaps.has(cell):gaps[cell]=[]
	if not gaps[cell].has(index):gaps[cell].append(index)
func detached(index:int,slots:Array) -> void:
	add_gap(index,slots[index].position)
	refill(slots)
func captured(index:int,slots:Array) -> void:
	active.erase(index);slots[index].anchor_active=false
	var cell:=Vector2i(slots[index].position/CELL)
	if gaps.has(cell):
		gaps[cell].erase(index)
		if gaps[cell].is_empty():gaps.erase(cell)
	recent.append(slots[index].position)
	if recent.size()>3:recent.pop_front()
	refill(slots)
func refill(slots:Array) -> void:
	while active.size()<limit:
		var best:=-1;var distance:=-INF
		# One candidate per occupied gap cell keeps refill work bounded by crown
		# area, rather than scanning every bare leaf position after each rescue.
		for cell in gaps:
			var candidate:=-1
			for index in gaps[cell]:
				if not active.has(index):candidate=index;break
			if candidate<0:continue
			var p:Vector2=slots[candidate].position
			var nearest:=INF
			for index in active:nearest=minf(nearest,p.distance_squared_to(slots[index].position))
			for previous in recent:nearest=minf(nearest,p.distance_squared_to(previous))
			if is_inf(nearest):nearest=-p.distance_squared_to(Vector2(180,270))
			if nearest>distance or (nearest==distance and (best<0 or candidate<best)):
				best=candidate;distance=nearest
		if best<0:return
		active[best]=true;slots[best].anchor_active=true
