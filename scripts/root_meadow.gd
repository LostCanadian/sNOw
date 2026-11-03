extends Node2D
## Grass and a low paper soil bank cover the ends of the existing root painting.
const ART=preload("res://assets/art/root_meadow.png")
const REGION=preload("res://scripts/root_meadow_region.gd").RECT
const WIDTH:=340.0
var world
static func cover_rect() -> Rect2:
	var height:=68.0
	return Rect2(10,506-height,WIDTH,height)
func _draw() -> void:
	var tint:=Color.WHITE
	if world!=null and not world.victory:
		if world.profile.time=="night":tint=Color(0.56,0.68,0.81)
		elif world.profile.time=="dusk":tint=Color(0.92,0.80,0.76)
		elif world.profile.weather in ["rain","storm"]:tint=Color(0.80,0.89,0.88)
		if world.winter:tint=tint.lerp(Color(0.70,0.80,0.82),0.4)
	draw_texture_rect_region(ART,cover_rect(),REGION,tint)
