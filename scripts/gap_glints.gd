extends RefCounted
## Five fading suggestions. This cosmetic scheduler cannot reserve a branch.
const MAX_LIGHTS:=5
const LIFETIME:=2.6
const INTERVAL:=0.56
var key:=""
var pool:Array[int]=[]
var lights:Array[Dictionary]=[]
var seen:={}
var until_next:=0.0
func configure(context:String) -> void:
	if context==key:return
	key=context;pool.clear();lights.clear();seen.clear();until_next=0
func set_candidates(ids:Array[int]) -> void:
	pool=ids.duplicate()
	# Stable shuffled order; no use of the simulation's random generator.
	pool.sort_custom(func(a,b):return hash(key+":"+str(a))<hash(key+":"+str(b)))
func advance(dt:float,slots:Array,time:float,reduced:=false) -> void:
	for light in lights:light.age+=dt
	lights=lights.filter(func(light):return light.age<LIFETIME and slots[light.slot].leaf_id<0 and slots[light.slot].get("anchor_active",true))
	until_next-=dt
	if until_next>0:return
	until_next=INTERVAL
	if lights.size()>=(2 if reduced else MAX_LIGHTS):return
	for attempt in range(2):
		for index in pool:
			if seen.has(index) or slots[index].leaf_id>=0 or not slots[index].get("anchor_active",true) or time<float(slots[index].get("capture_after",0)):continue
			if lights.any(func(light):return light.slot==index):continue
			seen[index]=true
			lights.append({"slot":index,"position":slots[index].position,"age":0.0})
			return
		seen.clear()
func poses() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	for light in lights:
		var phase:float=light.age/LIFETIME
		var alpha:=smoothstep(0,0.30,phase)*(1-smoothstep(0.55,1,phase))*0.7
		if alpha>0.001:result.append({"slot":light.slot,"position":light.position,"alpha":alpha})
	return result
