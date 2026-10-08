extends "res://tests/depth_floor_selection_test.gd"
## Native wall-clock samples, distinct from fixed-fps movement/logic checks.
func _run() -> void:
	var allowed: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name()=="headless" or "--native-approved" not in OS.get_cmdline_user_args() or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		quit(2); return
	path="user://verification/sect_render_%d.json" % Time.get_ticks_usec()
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,720); Engine.max_fps=120
	await _open()
	var hub: ExteriorHub=flow.active_scene as ExteriorHub
	for id: String in SectRouteCatalog.FACTIONS:
		for event: String in ["accept","west","east","guest"]: _check(hub.sect_journey.progress.record(id,event),"Fixture records existing quest prerequisite")
	var measurements: Array[Dictionary]=[]
	for room_id: StringName in SectRouteCatalog.ROOMS:
		var started: int=Time.get_ticks_usec()
		_check(hub.enter_exterior(room_id),"Enter rendered map through existing travel owner")
		var entry_ms: float=(Time.get_ticks_usec()-started)/1000.0
		PlayerTravel.relocate(hub.player,hub.exterior.to_global(Vector2(hub.exterior.width*.5,hub.exterior.floor_y(hub.exterior.width*.5))))
		await _step(60)
		var times: Array[float]=[]
		var draw_max: int=0
		var last: int=Time.get_ticks_usec()
		var start: int=last
		while Time.get_ticks_usec()-start<2500000:
			await process_frame
			var now: int=Time.get_ticks_usec()
			times.append((now-last)/1000.0); last=now
			draw_max=maxi(draw_max,int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		times.sort()
		var mean: float=0
		var stalls: int=0
		for ms: float in times: mean+=ms; stalls+=1 if ms>50 else 0
		mean/=maxi(1,times.size())
		measurements.append({"room":room_id,"frames":times.size(),"entry_ms":entry_ms,"mean_ms":mean,"p95_ms":times[int((times.size()-1)*.95)],"p99_ms":times[int((times.size()-1)*.99)],"max_ms":times[-1],"over_50ms":stalls,"draw_calls_max":draw_max})
		_check(hub.exterior.get_node_or_null("SectRoomArt")!=null and times.size()>60,"Actual room art rendered during a sufficient wall-clock sample")
		print("SECT_RENDER ",JSON.stringify(measurements[-1]))
	var output:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("FRAME_TIMES.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"renderer":RenderingServer.get_video_adapter_name(),"resolution":str(root.size),"fps_cap":Engine.max_fps,"setup":"Quest prerequisites seeded via owner; stationary actual player in each map; warm 60 physics frames; no fixed-fps or real save","samples":measurements},"\t")); output.close()
	await _close()
	print("RESULT sect_render checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
