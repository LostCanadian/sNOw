extends Node2D
## Distant visitors stay behind bark; near crossings share the tree/planting pass.
const Sprites=preload("res://scripts/animal_sprites.gd")
var world
var planes: Array[String] = ["ground"]
func _draw() -> void:
	if world==null:return
	for animal in world.animal_poses():
		if animal.plane in planes:Sprites.draw_pose(self,animal)
