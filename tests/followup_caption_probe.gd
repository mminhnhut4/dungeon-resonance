extends "res://tests/story_gameplay_probe.gd"
## Earned H7 profile, ordinary walking and wall time; baseline/final caption QA.
var caption_samples: Array[Dictionary] = []
var caption_started: int = 0
var caption_elapsed: float = 0.0
func _observe_captions() -> void:
	if not is_instance_valid(hub): return
	var items: Array[Dictionary] = []
	for id: String in TanDangProgress.NPC_IDS:
		var actor: CultivatorActor = hub.npc_population.actors.get(id) as CultivatorActor
		if not is_instance_valid(actor) or not actor.caption.is_visible_in_tree(): continue
		var rect: Rect2 = actor.caption.get_global_transform_with_canvas()*Rect2(Vector2.ZERO,actor.caption.size)
		items.append({"id":id,"x":actor.global_position.x,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y],"text":actor.caption.text})
	var intersections: Array[Dictionary] = []
	for a: int in items.size():
		for b: int in range(a+1,items.size()):
			var ra := Rect2(float(items[a]["rect"][0]),float(items[a]["rect"][1]),float(items[a]["rect"][2]),float(items[a]["rect"][3]))
			var rb := Rect2(float(items[b]["rect"][0]),float(items[b]["rect"][1]),float(items[b]["rect"][2]),float(items[b]["rect"][3]))
			if ra.intersects(rb) and ra.intersects(Rect2(Vector2.ZERO,Vector2(root.size))) and rb.intersects(Rect2(Vector2.ZERO,Vector2(root.size))):
				var overlap: Rect2 = ra.intersection(rb)
				intersections.append({"a":items[a]["id"],"b":items[b]["id"],"width":overlap.size.x,"height":overlap.size.y})
	if caption_samples.size()<6000:caption_samples.append({"elapsed":(Time.get_ticks_usec()-caption_started)/1000000.0,"items":items,"intersections":intersections})
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-h7" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("FOLLOWUP_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("FOLLOWUP_SOURCE_NPC"),"Exact earned H7 source pair, no scenario edits")
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	_check(not flow.qa_tools_enabled and hub.tan_dang.progress.state()["rewards"].has("q3"),"Product q3 opening, no QA tools")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence);caption_started=Time.get_ticks_usec();process_frame.connect(_observe_captions)
	_stage("walk_to_the_living_courtyard")
	if not await _walk(hub.player,1150):await _finish_captions(false);return
	_stage("watch_35_seconds_of_actual_routines");await pause(35);await _shot("routines_after_35_seconds")
	_stage("normal_jump_and_dash_in_the_clear_training_yard")
	if not await _walk(hub.player,650):await _finish_captions(false);return
	await _key(KEY_SPACE);await pause(.8);await _key(KEY_SHIFT);await pause(.6)
	_check(hub.player.health.current_health>0 and hub.player.controls_enabled,"Ordinary jump/dash retain live product controls")
	await _shot("normal_movement_VFX");await pause(.6)
	await _finish_captions(true)
func _finish_captions(complete: bool) -> void:
	bot.stop();process_frame.disconnect(_observe_captions)
	var cap: Dictionary=recorder.finish()
	var data: Dictionary={"complete":complete,"checks":checks,"failures":failures,"samples":caption_samples,"scope":"Exact earned H7 profile, normal wall-time walking and product schedules. No actor positions, route clocks, save flags, HP or greeting receipts edited. Rectangle intersections are geometry evidence; inspect captured glyphs separately.","capture":{"wall_seconds":cap["wall_seconds"],"frames":cap["frames"].size(),"audio":cap["audio"]}}
	var f:=FileAccess.open(evidence.path_join("caption-observations.json"),FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT FollowupCaption checks=%d failures=%d complete=%s wall=%.3f"%[checks,failures,complete,cap["wall_seconds"]]);quit(0 if complete and failures==0 else 1)
