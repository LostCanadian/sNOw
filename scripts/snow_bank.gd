extends RefCounted
## A thin coat first follows real leaf supports, then joins into two broad drifts.
const GROUND:=502.0
const DEPTH:=6.0
static func build(surface,depth_lane:int=-1) -> Dictionary:
	var raw:=PackedFloat32Array()
	var heights:=PackedFloat32Array()
	var mass:=0.0
	for i in range(91):
		var y:float=surface.surface(i*4.0,1 if depth_lane==0 else 0) if depth_lane>=0 else minf(surface.surface(i*4.0,0),surface.surface(i*4.0,1))
		var height:=maxf(0,499.27-y)
		raw.append(lerpf(GROUND,y-2.0,smoothstep(0,4,height)))
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
		if weights[lane]>0:widths[lane]=clampf(sqrt(variance[lane]/weights[lane])*1.7,70,105)
	var support:=PackedVector2Array();var top:=PackedVector2Array()
	for i in range(181):
		var x:=i*2.0
		# A rounded support envelope follows the actual piles without hard kernel edges.
		var nearest:=1000.0;var first:=0;var last:=90
		for j in range(first,last+1):nearest=minf(nearest,raw[j]+pow(x-j*4,2)/24.0)
		var total:=0.0
		for j in range(first,last+1):total+=exp((nearest-raw[j]-pow(x-j*4,2)/24.0)/0.8)
		var local_support:=nearest-0.8*log(total)
		support.append(Vector2(x,local_support))
		var hills:=Vector2(crests.x*exp(-0.5*pow((x-centers.x)/widths.x,2)),crests.y*exp(-0.5*pow((x-centers.y)/widths.y,2)))
		# A bounded rounded join does not inflate both banks to cover outliers.
		var hill:=0.5*(hills.x+hills.y+sqrt(pow(hills.x-hills.y,2)+576.0)-24.0)
		var drift:=GROUND-DEPTH-hill
		var coating:=local_support-DEPTH
		var highest:=minf(drift,coating)
		top.append(Vector2(x,GROUND-DEPTH if mass<0.01 else highest-6.0*log(exp((highest-drift)/6.0)+exp((highest-coating)/6.0))))
	# Blend the local coating into the broad drifts without a pinched join.
	var rounded:=top.duplicate()
	for i in range(top.size()):
		var y:=0.0
		for j in range(-2,3):y+=top[clampi(i+j,0,top.size()-1)].y*[1.0,4.0,6.0,4.0,1.0][j+2]/16.0
		rounded[i].y=y
	top=rounded
	return {"support":support,"top":top,"centers":centers,"widths":widths,"crests":crests}
static func contour(surface) -> PackedVector2Array:
	return build(surface).top
static func layers(profile:Dictionary,amount:float) -> Dictionary:
	var upper:=PackedVector2Array();var lower:=PackedVector2Array([Vector2(0,640),Vector2(360,640)])
	var join:=smoothstep(0.05,1.0,amount)
	for i in range(profile.top.size()):
		var support:Vector2=profile.support[i]
		upper.append(support.lerp(profile.top[i],join))
	return {"upper":upper,"lower":lower,"body_alpha":smoothstep(0,0.8,amount)}
static func mesh(outline:PackedVector2Array,opacity:float) -> ArrayMesh:
	# Filled, feathered paper. Three local rows give a soft edge and broad
	# slope shading without an outline stroke or diagonal polygon-fan seams.
	var vertices:=PackedVector3Array();var colours:=PackedColorArray();var indices:=PackedInt32Array()
	for i in range(outline.size()):
		var p:=outline[i]
		var before:Vector2=outline[maxi(0,i-1)];var after:Vector2=outline[mini(outline.size()-1,i+1)]
		var slope:float=(after.y-before.y)/maxf(1,after.x-before.x)
		var shade:=clampf(slope*0.055,-0.015,0.095)
		var top_colour:=Color(0.97-shade,0.98-shade*0.72,0.99-shade*0.4,opacity)
		vertices.append(Vector3(p.x,p.y,0));colours.append(Color(top_colour,0))
		vertices.append(Vector3(p.x,p.y+1.6,0));colours.append(top_colour)
		vertices.append(Vector3(p.x,640,0));colours.append(Color(0.94,0.96,0.98,opacity))
		if i>0:
			var k:=i*3
			indices.append_array(PackedInt32Array([k-3,k-2,k,k-2,k+1,k,k-2,k-1,k+1,k-1,k+2,k+1]))
	var arrays:=[];arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_COLOR]=colours;arrays[Mesh.ARRAY_INDEX]=indices
	var result:=ArrayMesh.new();result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return result
