extends RefCounted
## Two depth lanes with fine, incremental support surfaces: new leaves land on old ones.
const RADIUS := 7.8
const GROUND := 502.0
const CELL := 4.0
const BINS := 91
var heights := PackedFloat32Array()
var highest := 0.0

func _init() -> void: clear()

static func in_front(id: int) -> bool:
	return id % 2 == 0

func clear() -> void:
	heights.resize(BINS*2)
	heights.fill(0)
	highest = 0.0

func minimum_y() -> float:
	# Conservative bound for every x and both lanes, including neighbour support.
	return GROUND - RADIUS * 0.35 - highest

func lane(id: int) -> int:
	return 1 if in_front(id) else 0

func surface(x: float, id: int) -> float:
	var index := clampi(roundi(x/CELL),0,BINS-1)
	var offset := lane(id)*BINS
	# A little overlap supports a leaf without turning the whole pile into a flat shelf.
	var height := heights[offset+index]
	for dx in [-1,1]:
		height=maxf(height,heights[offset+clampi(index+dx,0,BINS-1)]-1.8)
	return GROUND-RADIUS*0.35-height

func deposit(x: float, id: int) -> float:
	var y := surface(x,id)
	var index := clampi(roundi(x/CELL),0,BINS-1)
	var offset := lane(id)*BINS
	var thickness := 1.0 + fposmod(id*0.618034,1.0)*0.65
	for dx in range(-2,3):
		var i:=clampi(index+dx,0,BINS-1)
		heights[offset+i]+=thickness*(1.0-absf(dx)*0.28)
		highest = maxf(highest, heights[offset+i])
	return y

func seed(leaf: Dictionary) -> void:
	# Preserve existing poses when transitioning from live gameplay into the ending.
	var index:=clampi(roundi(leaf.position.x/CELL),0,BINS-1)
	var offset:=lane(leaf.id)*BINS
	var height:=maxf(0,GROUND-RADIUS*0.35-float(leaf.position.y))+1.2
	for dx in range(-2,3):
		var i:=clampi(index+dx,0,BINS-1)
		heights[offset+i]=maxf(heights[offset+i],height-maxf(0,absf(dx)-0.5)*0.8)
		highest = maxf(highest, heights[offset+i])
