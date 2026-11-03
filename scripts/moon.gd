extends Node2D
## Smooth paper moon: both the circular edge and terminator use pixel derivatives.
const PAPER=preload("res://assets/art/paper_leaf.png")
const MOON_SHADER=preload("res://scripts/moon.gdshader")
var ink:ShaderMaterial
func _ready() -> void:
	visible=false
	ink=ShaderMaterial.new();ink.shader=MOON_SHADER;material=ink
func refresh(profile:Dictionary,won:bool) -> void:
	visible=profile.time=="night" and not won
	position=profile.sun;rotation=profile.moon_turn
	ink.set_shader_parameter("cloud_dimming",0.58 if profile.weather=="storm" else 1.0)
	ink.set_shader_parameter("phase_angle",float(profile.moon)*TAU/8)
	queue_redraw()
func _draw() -> void:
	draw_texture_rect(PAPER,Rect2(-10,-10,20,20),false)
