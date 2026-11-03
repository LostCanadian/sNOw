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
		covered=covered and p.y<minf(piles.surface(p.x,0),piles.surface(p.x,1))-8
		if i>0 and i<bank.size()-1:rounded=rounded and absf(bank[i-1].y-2*p.y+bank[i+1].y)<0.5
	check(covered,"snow stays above both lanes of piled leaves")
	check(rounded,"pile peaks and valleys become continuous rounded drifts rather than angular teeth")
	check(piles.heights==before and bank==Snow.contour(piles),"the drape is deterministic and cannot move the underlying piles")
	print("Snow blanket: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
