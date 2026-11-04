extends SceneTree
const Snow=preload("res://scripts/snow_bank.gd")
const Piles=preload("res://scripts/leaf_piles.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:
	var piles=Piles.new()
	for i in range(120):piles.deposit(135,i*2)
	for i in range(55):piles.deposit(240,i*2+1)
	var before:PackedFloat32Array=piles.heights.duplicate()
	var bank:=Snow.contour(piles)
	check(bank.size()==181 and bank[0].x==0 and bank[-1].x==360,"snow blankets the complete viewport with a fine contour")
	var covered:=true;var rounded:=true
	for i in range(bank.size()):
		var p:=bank[i]
		covered=covered and p.y<minf(piles.surface(p.x,0),piles.surface(p.x,1))-2
		if i>0 and i<bank.size()-1:rounded=rounded and absf(bank[i-1].y-2*p.y+bank[i+1].y)<0.5
	check(covered,"snow stays above both lanes of piled leaves")
	check(rounded,"pile peaks and valleys become continuous rounded drifts rather than angular teeth")
	check(piles.heights==before and bank==Snow.contour(piles),"the drape is deterministic and cannot move the underlying piles")
	var profile:Dictionary=Snow.build(piles)
	var first:Dictionary=Snow.layers(profile,0.05)
	var last:Dictionary=Snow.layers(profile,1.0)
	var starts_on_leaves:=true
	for i in range(first.upper.size()):
		starts_on_leaves=starts_on_leaves and first.upper[i].distance_to(profile.support[i])<1
	check(starts_on_leaves and first.body_alpha>0 and first.body_alpha<0.02,"snow starts as a thin coat on the leaf pile instead of rising from underneath it")
	check(last.upper==profile.top and last.lower[0].y==640,"the coating joins into complete banks as accumulation finishes")
	var peaks:=0
	for i in range(1,bank.size()-1):
		if bank[i].y<bank[i-1].y and bank[i].y<=bank[i+1].y:peaks+=1
	check(peaks<=2,"the settled snow forms at most two coherent banks")
	var bare:=Snow.contour(Piles.new())
	check(bare[0].y==Snow.GROUND-Snow.DEPTH,"empty ground receives a shallow coat without invented tall piles")
	var bare_start:Dictionary=Snow.layers(Snow.build(Piles.new()),0.05)
	check(absf(bare_start.upper[0].y-Snow.GROUND)<1.0,"the first ground coating rests on the ground rather than floating above it")
	var mesh:ArrayMesh=Snow.mesh(bank,1.0)
	var geometry:Array=mesh.surface_get_arrays(0)
	var vertices:PackedVector3Array=geometry[Mesh.ARRAY_VERTEX]
	var triangles:PackedInt32Array=geometry[Mesh.ARRAY_INDEX]
	var local:=true
	for i in range(0,triangles.size(),3):
		var a:float=vertices[triangles[i]].x;var b:float=vertices[triangles[i+1]].x;var c:float=vertices[triangles[i+2]].x
		local=local and maxf(a,maxf(b,c))-minf(a,minf(b,c))<=2.01
	check(local,"bank lighting triangles remain local instead of stretching diagonal shading seams across the snow")
	var actual_top:=502.0;var snow_top:=502.0
	for i in range(91):actual_top=minf(actual_top,minf(piles.surface(i*4.0,0),piles.surface(i*4.0,1)))
	for point in bank:snow_top=minf(snow_top,point.y)
	check(snow_top>=actual_top-14,"snow adds a restrained coat above the real piles instead of inflating tall artificial banks")
	var shades:PackedColorArray=geometry[Mesh.ARRAY_COLOR]
	check(shades[0].a==0 and shades[1].a==1 and vertices[1].y>vertices[0].y,"a transparent feather softens the filled bank edge without drawing an outline")
	var gradual:=true;var previous:Dictionary=Snow.layers(profile,0)
	for frame in range(1,61):
		var next:Dictionary=Snow.layers(profile,frame/60.0)
		gradual=gradual and next.body_alpha>=previous.body_alpha and next.body_alpha-previous.body_alpha<0.04
		for i in range(bank.size()):gradual=gradual and next.upper[i].y<=previous.upper[i].y
		previous=next
	check(gradual,"the complete snow body builds upward and fades in continuously from the leaf supports")
	var winter=preload("res://scripts/winter_fall.gd").new();winter.phase="snow"
	for frame in range(120):winter.step(1.0/60)
	check(not winter.finished() and winter.cover()<0.65,"snowfall is still building after two seconds instead of jumping to a finished bank")
	for frame in range(180):winter.step(1.0/60)
	check(winter.finished() and winter.cover()==1,"gradual snow accumulation still reaches a stable complete state")
	var rear:Dictionary=Snow.build(piles,0);var front:Dictionary=Snow.build(piles,1)
	var rear_top:=502.0;var front_top:=502.0
	for point in rear.top:rear_top=minf(rear_top,point.y)
	for point in front.top:front_top=minf(front_top,point.y)
	check(front_top<rear_top-50,"front and rear snow sample their own leaf supports rather than copying the tallest combined pile")
	print("Snow blanket: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
