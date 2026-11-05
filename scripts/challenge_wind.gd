extends RefCounted
## Seeded, smooth wind changes. Sample once per tick; never consume leaf RNG.
const Wind = preload("res://scripts/north_wind.gd")
const CALM_SECONDS := 6.0
const SEGMENT_SECONDS := 6.0
const PRESSURE_SECONDS := 50.0

static func stage(time: float) -> float:
	# Raise pressure every fifty seconds, easing into each step over six seconds.
	var elapsed:=maxf(0,time)
	return floorf(elapsed/PRESSURE_SECONDS)+smoothstep(44,50,fposmod(elapsed,PRESSURE_SECONDS))

static func pressure(time: float) -> float:
	return 1.0+minf(1.25,stage(time)*0.18)

static func noise(index: int, seed_value: int, salt: int) -> float:
	var bits := (seed_value ^ (index * 0x45d9f3b) ^ salt) & 0xffffffff
	bits = (((bits >> 16) ^ bits) * 0x45d9f3b) & 0xffffffff
	bits = (bits >> 16) ^ bits
	return float(bits & 0xffff) / 65535.0

static func horizontal(index: int, seed_value: int) -> float:
	return 0.0 if index == 0 else lerpf(-30.0, 30.0, noise(index, seed_value, 7919))

static func sample(time: float, difficulty: int, seed_value: int, north_time := -1.0) -> Vector2:
	var elapsed := maxf(0, time - CALM_SECONDS)
	var segment := floori(elapsed / SEGMENT_SECONDS)
	var local := fposmod(elapsed, SEGMENT_SECONDS) / SEGMENT_SECONDS
	var scale: float = [0.70, 1.0, 1.25][clampi(difficulty, 0, 2)]
	scale *= 0.65*pressure(time)
	var sideways := lerpf(horizontal(segment, seed_value), horizontal(segment + 1, seed_value), smoothstep(0, 1, local))
	var down := 0.0
	if time > CALM_SECONDS and noise(segment, seed_value, 104729) < 0.45:
		var pulse := smoothstep(0.12, 0.40, local) * (1.0 - smoothstep(0.70, 0.95, local))
		down = lerpf(18.0, 42.0, noise(segment, seed_value, 15485863)) * pulse
	down += Wind.downburst(north_time) * 25.0
	return Vector2(sideways, down) * scale

static func squall(time:float,difficulty:int,seed_value:int,week:=0)->Dictionary:
	# week=0 is Challenge. Weeks one to three and the North Wind finale retain
	# their original weather; only normal later campaign weeks add these gusts.
	if week>0 and (week<4 or week>12):return {}
	if time<CALM_SECONDS:return {}
	var campaign:=week>0
	var progress:=clampf(float(week-3)/9.0,0,1) if campaign else 0.0
	var period:=lerpf(24,18,progress) if campaign else 16.0
	var elapsed:=time-CALM_SECONDS
	var cycle:=floori(elapsed/period)
	var local:=fposmod(elapsed,period)
	var warning:=smoothstep(0,0.8,local)*(1.0-smoothstep(2.8,3.2,local))
	var pulse:=smoothstep(3,4,local)*(1.0-smoothstep(7,8.5,local))
	var visible:=smoothstep(0,0.8,local)*(1.0-smoothstep(7,8.5,local))
	if visible<=0:return {}
	var lane:=lerpf(65,295,noise(cycle,seed_value,32452843))
	var scale:float=[0.70,1.0,1.25][clampi(difficulty,0,2)]
	var down:float=lerpf(0,110,progress)*scale if campaign else [140.0,165.0,190.0][clampi(difficulty,0,2)]*pressure(time)
	var cross:=lerpf(18,65,progress)*scale if campaign else 36.0*scale*pressure(time)
	cross*= -1.0 if noise(cycle,seed_value,49979687)<0.5 else 1.0
	return {"lane":lane,"radius":92.0,"warning":warning,"pulse":pulse,"visible":visible,"cross":cross*pulse,"down":down*pulse}

static func exposure(position:Vector2,lane:float,radius:float)->float:
	var across:=1.0-smoothstep(radius*0.45,radius,absf(position.x-lane))
	# High, distant leaves are vulnerable; close-range airflow remains useful.
	return across*lerpf(0.35,1.0,smoothstep(0,1,(335.0-position.y)/210.0))
