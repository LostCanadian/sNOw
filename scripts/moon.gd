extends Node2D
## Smooth paper moon: both the circular edge and terminator use pixel derivatives.
const PAPER=preload("res://assets/art/paper_leaf.png")
const MOON_SHADER=preload("res://scripts/moon.gdshader")
var ink:ShaderMaterial
func _ready() -> void:
	visible=false
	ink=ShaderMaterial.new();ink.shader=MOON_SHADER;material=ink
func refresh(profile:Dictionary,won:bool) -> void:
	var amount:float=profile.get("night_amount",1.0 if profile.time=="night" else 0.0)
	visible=amount>0.001 and not won
	modulate.a=amount
	position=profile.get("moon_position",profile.sun);rotation=profile.moon_turn
	ink.set_shader_parameter("cloud_dimming",lerpf(1.0,0.45,profile.get("cloud",1.0 if profile.weather=="storm" else 0.0)))
	ink.set_shader_parameter("phase_angle",float(profile.moon)*TAU/8)
	queue_redraw()
func _draw() -> void:
	draw_texture_rect(PAPER,Rect2(-10,-10,20,20),false)
