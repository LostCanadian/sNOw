extends RefCounted
## A thin coat first follows real leaf supports, then joins into two broad drifts.
const GROUND:=502.0
const DEPTH:=12.0
static func build(surface) -> Dictionary:
	var raw:=PackedFloat32Array()
	var heights:=PackedFloat32Array()
	var mass:=0.0
	for i in range(91):
		var y:=minf(surface.surface(i*4.0,0),surface.surface(i*4.0,1))
		var height:=maxf(0,499.27-y)
		raw.append(lerpf(GROUND,y-5.5,smoothstep(0,4,height)))
		heights.append(height);mass+=height
	var centers:=Vector2(100,260)
	if mass>0.01:
		for iteration in range(6):
			var weights:=Vector2.ZERO;var sums:=Vector2.ZERO
			for i in range(91):
				var x:=i*4.0
				var lane:=0 if absf(x-centers.x)<=absf(x-centers.y) else 1
				weights[lane]+=heights[i];sums[lane]+=x*heights[i]
			for lane in range(2):
				if weights[lane]>0:centers[lane]=sums[lane]/weights[lane]
	var widths:=Vector2(70,70)
	var variance:=Vector2.ZERO;var weights:=Vector2.ZERO
	var crests:=Vector2.ZERO
	for i in range(91):
		var x:=i*4.0
		var lane:=0 if absf(x-centers.x)<=absf(x-centers.y) else 1
		weights[lane]+=heights[i]
		variance[lane]+=heights[i]*pow(x-centers[lane],2)
		crests[lane]=maxf(crests[lane],heights[i])
	for lane in range(2):
		if weights[lane]>0:widths[lane]=clampf(sqrt(variance[lane]/weights[lane])*1.7,70,110)
	# Fit the drifts above the real supports, without a broad artificial uplift
	# over empty ground. The low ground coat is only twelve pixels deep.
	for i in range(91):
		var x:=i*4.0
		var basis:=Vector2(exp(-0.5*pow((x-centers.x)/widths.x,2)),exp(-0.5*pow((x-centers.y)/widths.y,2)))
		var missing:=heights[i]-maxf(crests.x*basis.x,crests.y*basis.y)
		if missing>0:
			var lane:=0 if basis.x>=basis.y else 1
			crests[lane]+=missing/maxf(0.001,basis[lane])
	var support:=PackedVector2Array();var top:=PackedVector2Array()
	for i in range(181):
		var x:=i*2.0
		# A small local envelope smooths leaf-sized corners but retains the pile.
		var nearest:=1000.0;var first:=maxi(0,floori(x/4)-3);var last:=mini(90,ceili(x/4)+3)
		for j in range(first,last+1):nearest=minf(nearest,raw[j]+pow(x-j*4,2)/12.0)
		var total:=0.0
		for j in range(first,last+1):total+=exp((nearest-raw[j]-pow(x-j*4,2)/12.0)/0.8)
		support.append(Vector2(x,nearest-0.8*log(total)))
		var hills:=Vector2(crests.x*exp(-0.5*pow((x-centers.x)/widths.x,2)),crests.y*exp(-0.5*pow((x-centers.y)/widths.y,2)))
		var hill:=0.5*(hills.x+hills.y+sqrt(pow(hills.x-hills.y,2)+0.04*hills.x*hills.y))
		top.append(Vector2(x,GROUND-DEPTH-hill))
	return {"support":support,"top":top,"centers":centers,"widths":widths,"crests":crests}
static func contour(surface) -> PackedVector2Array:
	return build(surface).top
static func layers(profile:Dictionary,amount:float) -> Dictionary:
	var upper:=PackedVector2Array();var lower:=PackedVector2Array([Vector2(0,640),Vector2(360,640)])
	var join:=smoothstep(0.12,1.0,amount)
	for i in range(profile.top.size()):
		var support:Vector2=profile.support[i]
		upper.append(support.lerp(profile.top[i],join)-Vector2(0,amount*(1-join)*2))
	return {"upper":upper,"lower":lower,"coating_alpha":smoothstep(0,0.12,amount),"body_alpha":smoothstep(0.12,0.95,amount)}
static func mesh(outline:PackedVector2Array,opacity:float) -> ArrayMesh:
	# Narrow strips keep the bank lighting local. A polygon fan would stretch
	# a contour vertex's shade across the entire bank and create diagonal seams.
	var vertices:=PackedVector3Array();var colours:=PackedColorArray();var indices:=PackedInt32Array()
	for i in range(outline.size()):
		var p:=outline[i]
		vertices.append(Vector3(p.x,p.y,0));vertices.append(Vector3(p.x,640,0))
		colours.append(Color(0.94,0.97,0.985,opacity));colours.append(Color(0.94,0.97,0.985,opacity))
		if i>0:
			var k:=i*2
			indices.append_array(PackedInt32Array([k-2,k-1,k,k-1,k+1,k]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colours;arrays[Mesh.ARRAY_INDEX]=indices
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
