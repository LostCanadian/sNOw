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
	paper.set_shader_parameter("breeze_time",game.world.clock)
	var wind:float=game.world.profile.wind*(2.6 if game.world.profile.week==13 else 1.5)
	paper.set_shader_parameter("breeze_strength",0.0 if lane>=2 or game.reduced_effects or game.world.winter or game.world.victory else wind)
	draw_multimesh(renderer.batches[lane],game.PAPER_LEAF)
