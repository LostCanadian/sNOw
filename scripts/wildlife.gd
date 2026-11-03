extends Node2D
## Original textured paper cutouts, using the standard canvas material.
const ART=preload("res://assets/art/wildlife.png")
const REGIONS=preload("res://scripts/wildlife_regions.gd").RECTS
var world
func _draw() -> void:
	if world==null:return
	for animal in world.animal_poses():
		var region:Rect2=REGIONS[animal.frame]
		var height:float=animal.height
		var width:=height*region.size.x/region.size.y
		draw_set_transform(animal.position,0,Vector2(animal.direction,1))
		draw_texture_rect_region(ART,Rect2(-width/2,-height,width,height),region,Color(0.92,0.94,0.93,animal.alpha))
		draw_set_transform(Vector2.ZERO)
