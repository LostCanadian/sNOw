extends RefCounted
## Source anchors and body measurements keep limbs from resizing the animal.
const Regions=preload("res://scripts/animal_motion_regions.gd")
const Travel=preload("res://scripts/travel_regions.gd")
const SHEETS:={
	"travel":preload("res://assets/art/wildlife_travel.png"),
	"owl":preload("res://assets/art/owl_motion.png"),
	"squirrel":preload("res://assets/art/squirrel_motion.png"),
	"rabbit":preload("res://assets/art/rabbit_motion.png"),
	"rare":preload("res://assets/art/rare_motion.png")}
const RECTS:={"travel":Travel.RECTS,"owl":Regions.OWL_RECTS,"squirrel":Regions.SQUIRREL_RECTS,"rabbit":Regions.RABBIT_RECTS,"rare":Regions.RARE_RECTS}
const ANCHORS:={"travel":Travel.ANCHORS,"owl":Regions.OWL_ANCHORS,"squirrel":Regions.SQUIRREL_ANCHORS,"rabbit":Regions.RABBIT_ANCHORS,"rare":Regions.RARE_ANCHORS}
static func reference_frame(sheet:String,frame:int) -> int:
	if sheet=="travel":return frame
	if sheet=="owl":return 2
	if sheet=="squirrel":return 12
	if sheet=="rabbit":return frame-frame%8+4
	return 6 if frame<8 else 8
static func draw_pose(canvas:Node2D,pose:Dictionary) -> void:
	var sheet:String=pose.sheet;var frame:int=pose.frame
	var region:Rect2=RECTS[sheet][frame]
	var anchor:Vector2=ANCHORS[sheet][frame]
	var reference:Rect2=RECTS[sheet][reference_frame(sheet,frame)]
	var body_height:float=Travel.BODY_HEIGHTS[frame] if sheet=="travel" else (Regions.OWL_BODY_HEIGHTS[frame] if sheet=="owl" else reference.size.y)
	var size:float=pose.height/body_height
	var rect:=Rect2((region.position-anchor)*size,region.size*size)
	canvas.draw_set_transform(pose.position,0,Vector2(pose.direction,1))
	canvas.draw_texture_rect_region(SHEETS[sheet],rect,region,Color(1,1,1,pose.alpha))
	canvas.draw_set_transform(Vector2.ZERO)
