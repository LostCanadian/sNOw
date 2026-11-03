extends Node2D
## Ground visitors stay in the valley; tree residents draw over bark, under foliage.
const Sprites=preload("res://scripts/animal_sprites.gd")
var world
var plane:="ground"
func _draw() -> void:
	if world==null:return
	for animal in world.animal_poses():
		if animal.plane==plane:Sprites.draw_pose(self,animal)
