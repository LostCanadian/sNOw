extends SceneTree
const Main=preload("res://main.tscn")
const Flakes=preload("res://scripts/snowflakes.gd")
var checks:=0
var failures:=0
func check(ok:bool,message:String) -> void:
	checks+=1
	if not ok:failures+=1;push_error(message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false);main.muted=true;main.sounds.muted=true
	var bands:={};var bounded:=true;var small:=0;var medium:=0;var large:=0
	for flake in main.snow:
		bounded=bounded and flake.size>=Flakes.MIN_RADIUS and flake.size<=Flakes.MAX_RADIUS
		bands[floori(flake.size)]=true
		if flake.size<2:small+=1
		elif flake.size<4:medium+=1
		else:large+=1
	check(bounded,"every flake has a bounded radius, including foreground crystals")
	check(bands.size()>=5 and small>0 and medium>small/2 and large>0,"the actual snowfall contains small, intermediate and larger flakes without a size gap")
	check(Flakes.detail(1)==0 and Flakes.detail(2.5)>0 and Flakes.detail(2.5)<1 and Flakes.detail(4)==1,"crystal detail blends in gradually as flakes get larger")
	main.preview_mode=true;main.preview_weather=1;main.reset_weather();main.snow_clock=1;main.advance_snow(.01)
	check(main.snow.filter(func(f):return f.active).all(func(f):return f.y+f.size<0),"even the largest new flakes enter from above the viewport")
	main.queue_free();await process_frame;await create_timer(.3).timeout
	print("Snowflake range: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
