extends Node2D
## A separate material removes the generator's faint transparent matte at render time.
const ART=preload("res://assets/art/wildlife.png")
const REGIONS=preload("res://scripts/wildlife_regions.gd").RECTS
var world
func _ready() -> void:
	var shader:=Shader.new()
	shader.code="""shader_type canvas_item;
	varying vec4 paper_tint;
	void vertex() { paper_tint = COLOR; }
	void fragment() {
		vec4 ink = texture(TEXTURE, UV);
		COLOR = vec4(ink.rgb * paper_tint.rgb, smoothstep(0.24, 0.88, ink.a) * paper_tint.a);
	}"""
	var paper:=ShaderMaterial.new();paper.shader=shader;material=paper
func _draw() -> void:
	if world==null:return
	for animal in world.animal_poses():
		var region:Rect2=REGIONS[animal.frame]
		var height:float=animal.height
		var width:=height*region.size.x/region.size.y
		draw_set_transform(animal.position,0,Vector2(animal.direction,1))
		draw_texture_rect_region(ART,Rect2(-width/2,-height,width,height),region,Color(0.92,0.94,0.93,animal.alpha))
		draw_set_transform(Vector2.ZERO)
