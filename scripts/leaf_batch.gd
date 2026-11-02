extends RefCounted
## Stable identity order across attachment, flight and landing. Four bulk uploads,
## rather than thousands of RenderingServer calls and individual draw commands.
const Canopy = preload("res://scripts/canopy.gd")
const Piles = preload("res://scripts/leaf_piles.gd")
const STRIDE := 12
var rank := PackedInt32Array()
var batches: Array[MultiMesh] = []
var buffers: Array[PackedFloat32Array] = []
var cached: Array[PackedFloat32Array] = []

func _init(meshes: Array[MultiMesh]) -> void:
	batches=meshes
	var order: Array=range(Canopy.SLOT_COUNT)
	order.sort_custom(func(a,b):return Canopy.depth(a)<Canopy.depth(b))
	rank.resize(Canopy.SLOT_COUNT)
	for i in range(order.size()):rank[order[i]]=i
	clear()

func clear() -> void:
	buffers.clear()
	for i in range(4):
		var data:=PackedFloat32Array();data.resize(Canopy.SLOT_COUNT*STRIDE);data.fill(0)
		buffers.append(data)

func cache() -> void:
	cached.clear()
	for data in buffers:cached.append(data.duplicate())

func restore() -> void:
	buffers.clear()
	for data in cached:buffers.append(data.duplicate())

func leaf(id: int, position: Vector2, angle: float, colour: Color, roll:=1.0, grounded:=false) -> void:
	if id<0 or id>=rank.size():return
	var offset:=rank[id]*STRIDE
	var front:=grounded and Piles.in_front(id)
	var lane:=2 if front else 0
	var c:=cos(angle)*Canopy.RADIUS
	var s:=sin(angle)*Canopy.RADIUS
	for shadow in range(2):
		var data:=buffers[lane+shadow]
		data[offset]=c*roll;data[offset+1]=-s;data[offset+3]=position.x+shadow
		data[offset+4]=s*roll;data[offset+5]=c;data[offset+7]=position.y+shadow
		var tint:=Color(0.17,0.17,0.10,0.20) if shadow else colour
		data[offset+8]=tint.r;data[offset+9]=tint.g;data[offset+10]=tint.b;data[offset+11]=tint.a
		var other:=buffers[(0 if front else 2)+shadow]
		other[offset]=0;other[offset+1]=0;other[offset+4]=0;other[offset+5]=0

func upload() -> void:
	for i in range(4):batches[i].buffer=buffers[i]

func move_air(id: int, position: Vector2) -> void:
	var offset:=rank[id]*STRIDE
	buffers[0][offset+3]=position.x;buffers[0][offset+7]=position.y
	buffers[1][offset+3]=position.x+1;buffers[1][offset+7]=position.y+1
