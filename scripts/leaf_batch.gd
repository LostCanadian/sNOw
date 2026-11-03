extends RefCounted
## Stable identity order across attachment, flight and landing. Four bulk uploads,
## rather than thousands of RenderingServer calls and individual draw commands.
const Canopy = preload("res://scripts/canopy.gd")
const Piles = preload("res://scripts/leaf_piles.gd")
const STRIDE := 12
const PALETTE_WIDTH:=128
const PALETTE_HEIGHT:=ceili(Canopy.SLOT_COUNT/128.0)
var rank := PackedInt32Array()
var batches: Array[MultiMesh] = []
var buffers: Array[PackedFloat32Array] = []
var cached: Array[PackedFloat32Array] = []
var palette_bytes:=PackedByteArray()
var cached_palette:=PackedByteArray()
var palette_texture:ImageTexture

func _init(meshes: Array[MultiMesh]) -> void:
	batches=meshes
	var order: Array=range(Canopy.SLOT_COUNT)
	order.sort_custom(func(a,b):return Canopy.depth(a)<Canopy.depth(b))
	rank.resize(Canopy.SLOT_COUNT)
	for i in range(order.size()):rank[order[i]]=i
	clear()
	palette_texture=ImageTexture.create_from_image(palette_image())

func clear() -> void:
	buffers.clear()
	palette_bytes.resize(PALETTE_WIDTH*PALETTE_HEIGHT*8);palette_bytes.fill(0)
	for i in range(4):
		var data:=PackedFloat32Array();data.resize(Canopy.SLOT_COUNT*STRIDE);data.fill(0)
		buffers.append(data)

func cache() -> void:
	cached.clear()
	cached_palette=palette_bytes.duplicate()
	for data in buffers:cached.append(data.duplicate())

func restore() -> void:
	buffers.clear()
	palette_bytes=cached_palette.duplicate()
	for data in cached:buffers.append(data.duplicate())

func leaf(id: int, position: Vector2, angle: float, colour: Color, roll:=1.0, grounded:=false, size:=1.0, breeze:=false) -> void:
	if id<0 or id>=rank.size():return
	var offset:=rank[id]*STRIDE
	var pixel:=rank[id]*4
	palette_bytes[PALETTE_WIDTH*PALETTE_HEIGHT*4+pixel]=255 if breeze else 0
	palette_bytes[pixel]=colour.r8;palette_bytes[pixel+1]=colour.g8
	palette_bytes[pixel+2]=colour.b8;palette_bytes[pixel+3]=colour.a8
	var front:=grounded and Piles.in_front(id)
	var lane:=2 if front else 0
	var c:=cos(angle)*Canopy.RADIUS*size
	var s:=sin(angle)*Canopy.RADIUS*size
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
	palette_texture.update(palette_image())

func palette_image() -> Image:
	return Image.create_from_data(PALETTE_WIDTH,PALETTE_HEIGHT*2,false,Image.FORMAT_RGBA8,palette_bytes)

func move_air(id: int, position: Vector2) -> void:
	var offset:=rank[id]*STRIDE
	buffers[0][offset+3]=position.x;buffers[0][offset+7]=position.y
	buffers[1][offset+3]=position.x+1;buffers[1][offset+7]=position.y+1
