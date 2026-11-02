extends SceneTree
const Main=preload("res://main.tscn")
const Loop=preload("res://scripts/loop.gd")
var checks:=0
var failures:=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;push_error("FAIL: "+message)
func _initialize() -> void:run.call_deferred()
func run() -> void:
	var main=Main.instantiate();root.add_child(main);main.set_physics_process(false)
	main.start_run();main.finish_story()
	main.sim.week=13;main.sim.earned_points=24;main.sim.points=24;main.sim.status="won"
	main._physics_process(1.0/60)
	main._physics_process(main.FLOWER_DURATION)
	check(main.mode=="won" and main.overlay==null,"flowers finish before any closing card or Results overlay appears")
	main._physics_process(main.VICTORY_HOLD-0.1)
	check(main.mode=="won" and main.overlay==null,"completed flowers remain visible for a few seconds")
	main._physics_process(0.2)
	check(main.mode=="victory_outro" and main.visual_mode()=="won" and main.overlay==null,"the victory sentence gets its own story card over the completed flower scene")
	var score:int=main.sim.score
	main.pause_for_focus();var frozen:float=main.story_time;main._physics_process(1)
	check(main.mode=="paused" and main.story_time==frozen,"focus loss freezes the victory closing card")
	main.resume_game();main._physics_process(0.7)
	main.finish_story()
	check(main.mode=="won" and main.overlay!=null and main.sim.score==score,"Results follow the closing card without awarding victory twice")
	check(main.overlay.find_children("*","Label",true,false).all(func(label):return not label.text.contains("first flower")),"the victory sentence is absent from Results button slots")
	main.queue_free();await process_frame
	print("Finale: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
