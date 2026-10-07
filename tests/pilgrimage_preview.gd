extends SceneTree
## Private interactive preview, or finite actual P01 render benchmark.
var flow: GameFlow
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var target: int = 0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--benchmark-fps="): target = int(arg.trim_prefix("--benchmark-fps="))
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(1280,720)
	DisplayServer.window_set_title("Dungeon Resonance · P01 bản thử riêng")
	if target > 0:
		AudioServer.set_bus_mute(0,true)
		Engine.max_fps = target
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/p01_preview_%d.json" % Time.get_ticks_usec()
	root.add_child(flow)
	current_scene = flow
	for tick: int in 10: await physics_frame
	var hub := flow.active_scene as ExteriorHub
	hub.enter_exterior(&"o01_p01",&"main",&"west",false)
	if target <= 0: return
	var warmup: int = Time.get_ticks_msec()+1000
	while Time.get_ticks_msec() < warmup: await process_frame
	var start: int = Time.get_ticks_usec()
	var frames: int = 0
	var nodes_peak: int = 0
	var draw_calls_peak: int = 0
	Input.action_press(&"move_right")
	while Time.get_ticks_usec()-start < 6000000:
		await process_frame
		frames += 1
		nodes_peak = maxi(nodes_peak,int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
		draw_calls_peak = maxi(draw_calls_peak,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	Input.action_release(&"move_right")
	var elapsed: float = (Time.get_ticks_usec()-start)/1000000.0
	var report: Dictionary = {"target_fps":target,"measured_fps":frames/elapsed,"seconds":elapsed,"frames":frames,"node_peak":nodes_peak,"draw_calls_peak":draw_calls_peak,"local_NPCs":hub.npc_population.actors.size(),"room":String(hub.exterior.room_id),"candidate_audio_enabled":false,"headless":DisplayServer.get_name()=="headless","renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name()}
	var file := FileAccess.open("res://docs/verification/p01_benchmark_%d.json" % target,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	flow.queue_free()
	for tick: int in 8: await process_frame
	print("RESULT P01RenderBenchmark target=%d measured=%.3f seconds=%.3f nodes=%d draw_calls=%d; real GPU, private profile, QA muted" % [target,frames/elapsed,elapsed,nodes_peak,draw_calls_peak])
	quit(0)
