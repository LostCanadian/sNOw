extends Node2D
## A planted paper bank with a soft lower edge and seasonal colour transitions.
const ART=preload("res://assets/art/root_meadow.png")
const REGION=preload("res://scripts/root_meadow_region.gd").RECT
const WIDTH:=420.0
var world
var paper:ShaderMaterial
static func cover_rect() -> Rect2:
	return Rect2(-30,436,WIDTH,86)
func _ready() -> void:
	paper=ShaderMaterial.new();paper.shader=preload("res://scripts/meadow.gdshader")
	paper.set_shader_parameter("region_uv",Vector4(REGION.position.x/ART.get_width(),REGION.position.y/ART.get_height(),REGION.size.x/ART.get_width(),REGION.size.y/ART.get_height()))
	material=paper
func _draw() -> void:
	var tint:=Color.WHITE
	var autumn:=0.0
	var spring:=0.0
	if world!=null:
		autumn=clampf((world.profile.week-2)/10.0,0,1)
		tint=world.light("meadow")
		if world.winter:tint=tint.lerp(Color(0.65,0.75,0.82),0.4)
		if world.victory:
			spring=world.spring
			tint=tint.lerp(Color.WHITE,spring)
	paper.set_shader_parameter("light",tint)
	paper.set_shader_parameter("autumn",autumn)
	paper.set_shader_parameter("spring",spring)
	# Low shoulders cover the roots where the main bank's silhouette tapers.
	# Reuse the complete soft-edged painting so the overlapping clumps blend.
	draw_texture_rect_region(ART,Rect2(-38,432,280,70),REGION)
	draw_texture_rect_region(ART,Rect2(156,437,280,70),REGION)
	draw_texture_rect_region(ART,cover_rect(),REGION)
