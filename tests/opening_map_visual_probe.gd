extends "res://tests/depth_floor_selection_test.gd"
## Two native checkpoints only; setup relocation is not motor/traversal evidence.
func _run() -> void:
	capture = "--native-approved" in OS.get_cmdline_user_args()
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not capture or DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):
		quit(2); return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	path = "user://verification/opening_map_visual_%d.json" % Time.get_ticks_usec()
	AudioServer.set_bus_mute(0,true)
	await _open()
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	_check(hub.enter_exterior(&"o01_p01"),"Existing travel owner builds P01 native checkpoint")
	var x: float = hub.exterior.jumps[0]["landing"].x+30.0
	PlayerTravel.relocate(hub.player,hub.exterior.to_global(Vector2(x,hub.exterior.floor_y(x))))
	await _step(15)
	_check(hub.player.motor.is_grounded(),"Native fixture rests on actual main road below optional shelf")
	await _picture("p01_optional_landings")
	_check(hub.enter_exterior(&"o02_b04"),"Existing travel owner builds B04 native checkpoint")
	x = 1160.0
	PlayerTravel.relocate(hub.player,hub.exterior.to_global(Vector2(x,hub.exterior.floor_y(x))))
	await _step(15)
	_check(hub.player.motor.is_grounded(),"Mast native fixture rests on actual dock heightfield")
	await _picture("b04_mast_grounding")
	await _close()
	print("RESULT opening_map_visual checks=%d failures=%d captures=2" % [checks,failures])
	quit(0 if failures == 0 else 1)
