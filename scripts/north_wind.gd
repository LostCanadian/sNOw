extends RefCounted
## Shared curved eddy path for art, swept branch stripping and airborne forces.
const PERIOD := 4.8
const WARNING := 0.8
const SWEEP := 2.1
const RADIUS := 52.0
static func cycle(time: float) -> int:return floori(time/PERIOD)
static func direction(time: float) -> float:return 1.0 if cycle(time)%2==0 else -1.0
static func phase(time: float) -> String:
	var local:=fposmod(time,PERIOD)
	return "warning" if local<WARNING else ("blast" if local<WARNING+SWEEP else "rest")
static func progress(time: float) -> float:
	return clampf((fposmod(time,PERIOD)-WARNING)/SWEEP,0,1)
static func point(t:float,lane:float,side:float) -> Vector2:
	var x:=lerpf(-160,520,t)+sin(t*TAU*2)*54*sin(t*PI)
	var y:=lane+sin(t*TAU)*61+sin(t*TAU*3)*12
	return Vector2(x if side>0 else 360-x,y)
static func center(time:float,lane:float) -> Vector2:
	return point(progress(time),lane,direction(time))
static func tangent(time:float,lane:float) -> Vector2:
	var t:=progress(time)
	return (point(minf(1,t+0.002),lane,direction(time))-point(maxf(0,t-0.002),lane,direction(time))).normalized()
static func segment(previous:float,time:float,lane:float) -> Array[Vector2]:
	var beginning:=cycle(time)*PERIOD+WARNING
	return [center(maxf(previous,beginning),lane),center(time,lane)]
static func force(position:Vector2,time:float,lane:float) -> Vector2:
	if phase(time)!="blast":return Vector2.ZERO
	return force_at(position, center(time,lane), tangent(time,lane)*150, direction(time)*165)
static func force_at(position:Vector2,origin:Vector2,travel:Vector2,spin:float) -> Vector2:
	var radial:=position-origin
	var strength:=clampf(1-radial.length()/94.0,0,1)
	return (travel+radial.orthogonal().normalized()*spin)*strength
static func downburst(time:float) -> float:
	if time < 0 or phase(time)!="blast":return 0.0
	return pow(sin(progress(time)*PI),2)
