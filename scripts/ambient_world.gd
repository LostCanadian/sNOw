extends Node2D
## Bounded cosmetic presentation behind the playable tree. No simulation reference.
const Profile=preload("res://scripts/world_profile.gd")
const Wildlife=preload("res://scripts/wildlife.gd")
const Motion=preload("res://scripts/wildlife_motion.gd")
const Moon=preload("res://scripts/moon.gd")
const DAY=preload("res://assets/art/autumn_stage.png")
const SKIES=preload("res://assets/art/weather_stages.png")
const CLOUDS=preload("res://assets/art/winter_clouds.png")
var key:=""
var profile:Dictionary=Profile.choose("title",1)
var clock:=0.0
var victory:=false
var winter:=false
var reduced:=false
var cold:=0.0
var motion=Motion.new()
var viewing_preview:=false
var animals:Node2D
var haze:GradientTexture2D
var beam:GradientTexture2D
var moon:Node2D
func _ready() -> void:
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	show_behind_parent=true
	haze=GradientTexture2D.new();haze.width=128;haze.height=64;haze.fill=GradientTexture2D.FILL_RADIAL
	haze.fill_from=Vector2(0.5,0.5);haze.fill_to=Vector2(1,0.5)
	haze.gradient=Gradient.new();haze.gradient.colors=PackedColorArray([Color.WHITE,Color(1,1,1,0)])
	beam=GradientTexture2D.new();beam.width=128;beam.height=8
	beam.fill_from=Vector2(0,0);beam.fill_to=Vector2(1,0)
	beam.gradient=Gradient.new();beam.gradient.offsets=PackedFloat32Array([0,0.25,0.5,0.75,1])
	beam.gradient.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.5),Color.WHITE,Color(1,1,1,0.5),Color(1,1,1,0)])
	moon=Moon.new();add_child(moon)
	animals=Wildlife.new();animals.world=self;add_child(animals)
func configure(campaign_id:String,week:int,preview:=false) -> void:
	var next:="%s:%d:%s"%[campaign_id,week,preview]
	if key==next:return
	key=next;profile=Profile.choose(campaign_id,week);clock=0;viewing_preview=preview
	motion.reset(profile.seed)
	queue_redraw()
func advance(dt:float,paused:bool,soft:bool,won:bool,lost:bool,pressure:float,blowing:=false,player_x:=180.0) -> void:
	if paused:return
	reduced=soft;victory=won;winter=lost;cold=pressure
	moon.refresh(profile,won)
	clock+=dt
	motion.advance(dt,clock,player_x,blowing,soft,profile.time=="night" and not won)
	queue_redraw()
	if is_instance_valid(animals):animals.queue_redraw()
func set_canopy(slots:Array,variant:=-1.0) -> void:
	motion.select_perches(slots,variant)
func preview_full_moon() -> void:
	if not viewing_preview or profile.time!="night":return
	profile.moon=0;profile.rare=true;clock=0;motion.reset(profile.seed)
func animal_poses() -> Array[Dictionary]:
	var result:Array[Dictionary]=[]
	if profile.time!="night" or victory:result.append(motion.squirrel(clock,reduced))
	if profile.rare and not victory:
		result.append(motion.wolf(clock,reduced));result.append(motion.bat(clock,reduced))
	else:
		var coat:=0.0 if victory else (2.0 if winter else clampf((profile.week-2)/4.5,0,2))
		result.append_array(motion.rabbit(clock,coat,reduced))
	if profile.time=="night" and not victory:result.append(motion.owl(clock,reduced))
	return result
func rustle(slot:int,position:Vector2) -> Vector3:
	if reduced or winter:return Vector3.ZERO
	var phase:=clock*(1.4+float(slot%7)*0.08)+position.x*0.055+position.y*0.021
	var strength:float=profile.wind
	return Vector3(sin(phase)*0.55*strength,cos(phase*0.8)*0.3*strength,sin(phase)*0.055*strength)
func _draw() -> void:
	var sunny:bool=victory or (profile.time=="day" and profile.weather=="sun")
	if sunny:
		draw_texture_rect(DAY,Rect2(0,0,360,640),false)
	else:
		var panel:=2 if profile.time=="night" else (1 if profile.time=="dusk" else 0)
		var size:=Vector2(SKIES.get_size());var left:=floorf(size.x*panel/3)
		var right:=floorf(size.x*(panel+1)/3)
		draw_texture_rect_region(SKIES,Rect2(0,0,360,640),Rect2(left,0,right-left,size.y))
	if profile.time=="night" and not victory:draw_night()
	if sunny:draw_rays()
	if not victory:
		draw_rain()
		if profile.weather=="storm":
			draw_texture_rect(CLOUDS,Rect2(-25,-45,410,150),false,Color(0.5,0.57,0.68,0.68))
			# An infrequent soft sky glow, never a full-screen flash.
			var flash:=fmod(clock+float(profile.seed%13),23.0)
			if profile.time=="night" and not reduced and flash>20 and flash<20.45:
				draw_texture_rect(haze,Rect2(200,0,200,200),false,Color(0.69,0.75,0.9,sin((flash-20)/0.45*PI)*0.13))
	var mist:float=0.07 if victory else profile.fog+cold*0.14
	for i in range(3):
		var drift:=0.0 if reduced else sin(clock*0.06+i*2)*28
		draw_texture_rect(haze,Rect2(-100+drift,338+i*28,560,62),false,Color(0.78,0.85,0.87,mist*0.28))
func draw_night() -> void:
	for i in range(24):
		var p:=Vector2(fmod(i*97.3+32,360),70+fmod(i*37.7,140))
		var dim:=0.30 if profile.weather=="storm" else 0.60
		draw_circle(p,0.45 if i%3 else 0.8,Color(0.85,0.9,1,dim))
	draw_texture_rect(haze,Rect2(profile.sun-Vector2(28,28),Vector2(56,56)),false,Color(0.8,0.86,1,0.08))
func draw_rays() -> void:
	var sun:Vector2=Vector2(78,90) if victory else profile.sun
	var strength:float=(0.18 if victory else 0.11)*clampf(1-cold*1.2,0,1)
	for i in range(5):
		var drift:=0.0 if reduced else sin(clock*0.12+i)*8
		var target:=Vector2(30+i*82+drift,520)
		var top:=sun+Vector2((i-2)*6,0)
		var pts:=PackedVector2Array([top-Vector2(3,0),top+Vector2(3,0),target+Vector2(30,0),target-Vector2(30,0)])
		draw_polygon(pts,PackedColorArray([Color(1,0.91,0.64,strength)]),PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)]),beam)
	for i in range(5,0,-1):draw_circle(sun,11+i*5,Color(1,0.9,0.57,strength*0.16))
func draw_rain() -> void:
	if profile.rain<=0 or winter:return
	var count:=int((8 if reduced else 80*profile.rain)*(1-cold))
	for i in range(count):
		var y:=fmod(clock*(165+i%9*4)+i*47.3,490)-30
		var x:=fposmod(i*83.7-y*0.16,400)-20
		var alpha:=0.12+float(i%3)*0.03
		draw_line(Vector2(x,y),Vector2(x-1.8,y+6+i%3),Color(0.77,0.85,0.91,alpha),0.65,true)
