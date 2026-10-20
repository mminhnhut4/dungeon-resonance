extends SceneTree
const Warmup=preload("res://scripts/presentation/opening_render_warmup.gd")
var checks: int=0
var failures: int=0
func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated QA user data")
	if failures:quit(2);return
	AudioServer.set_bus_mute(0,true)
	var owner_node:=Node.new();root.add_child(owner_node)
	if DisplayServer.get_name()=="headless":
		Warmup.begin(owner_node)
		_check(owner_node.get_child_count()==0 and not Warmup._started,"Headless skips render resources and keeps startup gate clear")
	else:
		root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1)
		root.position=DisplayServer.screen_get_position(root.current_screen)+Vector2i(20,20)
		root.size=Vector2i(1152,648);Engine.max_fps=120
		Warmup.begin(owner_node)
		_check(owner_node.get_child_count()==1,"One temporary warmup owner")
		var interrupted: Node=owner_node.get_child(0)
		owner_node.remove_child(interrupted);interrupted.queue_free()
		_check(not Warmup._started,"Early teardown permits a later complete warmup")
		var spawn_owner:=WorldCampaign.new()
		var loot_owner:=LootSpawner.new()
		spawn_owner.spawn_rng.seed=7319;loot_owner.rng.seed=5321
		var spawn_state: int=spawn_owner.spawn_rng.state
		var loot_state: int=loot_owner.rng.state
		Warmup.begin(owner_node)
		var warm: Node=owner_node.get_child(0)
		var view: SubViewport=warm.get_child(0) as SubViewport
		_check(view!=null and view.world_2d!=root.world_2d and view.size==Vector2i(256,256),"Separate small rendering world")
		_check(warm.find_children("*","CollisionObject2D",true,false).is_empty(),"No physics body or hurtbox is warmed")
		_check(warm.find_children("*","AudioStreamPlayer2D",true,false).is_empty(),"No audio voice is created")
		_check(warm.find_children("*","GPUParticles2D",true,false).is_empty() and view.get_child(0).get_child_count()==6,"Four bounded particle samples, one trail and one temporary light; no GPUParticles2D scene nodes")
		_check(not warm._light.enabled,"First draws warm the unlit canvas specialization")
		var t: int=Time.get_ticks_usec()
		for _i: int in 4:await RenderingServer.frame_post_draw
		_check(warm._light.enabled and warm._light.get_parent()==view.get_child(0),"Later draws warm the lit specialization in the isolated world")
		for _i: int in 12:await RenderingServer.frame_post_draw
		await process_frame
		_check(not is_instance_valid(warm) and owner_node.get_child_count()==0,"Warmup viewport and children released after eight draws")
		_check(spawn_owner.spawn_rng.state==spawn_state and loot_owner.rng.state==loot_state,"Warmup preserves independent spawn and loot RNG states")
		spawn_owner.free();loot_owner.free()
		Warmup.begin(owner_node)
		_check(owner_node.get_child_count()==0,"Completed warmup is once per process")
		print("METRIC WarmupContract elapsed_ms=",(Time.get_ticks_usec()-t)/1000.0)
	owner_node.queue_free();await process_frame
	print("RESULT OpeningRenderWarmup checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
