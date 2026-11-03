extends RefCounted
## Presentation only: a wave of buds travels from trunk to branch tips.
const DURATION:=3.5
static func greening(time:float) -> float:
	return smoothstep(0.25,5.5,time)
static func wardrobe(time:float) -> float:
	return smoothstep(0.75,3.5,time)
static func bud(index:int,position:Vector2,time:float) -> float:
	var distance:=position.distance_to(Vector2(180,390))/300.0
	var delay:=0.25+distance*1.25+fposmod(index*0.61803398875,1.0)*0.75
	return smoothstep(delay,delay+0.95,time)
static func flash(time:float) -> float:
	return smoothstep(0,0.18,time)*(1-smoothstep(0.25,1.45,time))
