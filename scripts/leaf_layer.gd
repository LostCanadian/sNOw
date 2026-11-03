extends Node2D
## Explicit palette lookup avoids Compatibility's packed per-instance colour path.
var game
const PAPER_SHADER=preload("res://scripts/leaf_palette.gdshader")
var lane:=0
var paper:ShaderMaterial
var current_palette:Texture2D
func _ready() -> void:
	paper=ShaderMaterial.new();paper.shader=PAPER_SHADER
	paper.set_shader_parameter("shadow",lane%2==1)
	material=paper
func _draw() -> void:
	var renderer=game.winter_renderer if game.world.winter else game.leaf_renderer
	if current_palette!=renderer.palette_texture:
		current_palette=renderer.palette_texture
		paper.set_shader_parameter("palette",current_palette)
	draw_multimesh(renderer.batches[lane],game.PAPER_LEAF)
