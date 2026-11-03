extends RefCounted
## A smooth blanket above the real pile supports. A soft minimum of broad
## parabolas rounds both peaks and valleys without cutting through piled leaves.
static func contour(surface) -> PackedVector2Array:
	var supports:=PackedVector2Array()
	for i in range(91):
		var x:=i*4.0
		var top:=minf(472.0-sin(x*0.06)*4,minf(surface.surface(x,0),surface.surface(x,1))-14)
		supports.append(Vector2(x,top))
	var result:=PackedVector2Array()
	for i in range(181):
		var x:=i*2.0
		var nearest:=1000.0
		for p in supports:nearest=minf(nearest,p.y+pow(x-p.x,2)/140.0)
		var sum:=0.0
		for p in supports:sum+=exp((nearest-p.y-pow(x-p.x,2)/140.0)/8.0)
		result.append(Vector2(x,nearest-8.0*log(sum)))
	return result
