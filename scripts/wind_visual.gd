extends Node2D
## Sixteen paper curl poses crossfade at 18 fps while the whole eddy rolls.
const ART=preload("res://assets/art/north_wind_motion.png")
const Wind=preload("res://scripts/north_wind.gd")
var game
func _ready() -> void:
	material=ShaderMaterial.new();material.shader=preload("res://scripts/wind_paper.gdshader")
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
func _draw() -> void:
	if game.visual_mode()!="play" or not game.sim.has_north_wind():return
	var time:float=game.sim.wind_time()
	if Wind.phase(time)!="blast":return
	var center:=Wind.center(time,game.sim.wind_lane)
	var side:=Wind.direction(time)
	var heading:=Wind.tangent(time,game.sim.wind_lane).angle()
	if side<0:heading-=PI
	var frames:=time*18
	var frame:=floori(frames)%16
	var blend:=smoothstep(0,1,fposmod(frames,1.0))
	var alpha:=0.65 if game.reduced_effects else 0.86
	var roll:=0.0 if game.reduced_effects else sin(time*3.7)*0.12
	draw_set_transform(center,heading+roll,Vector2(side,1))
	for layer in range(2):
		var index:=(frame+layer)%16
		var cell:=Vector2(ART.get_size())/4
		var source:=Rect2(Vector2(index%4,index/4)*cell,cell)
		draw_texture_rect_region(ART,Rect2(-111,-98,222,196),source,Color(1,1,1,alpha*((1-blend) if layer==0 else blend)))
	draw_set_transform(Vector2.ZERO)
