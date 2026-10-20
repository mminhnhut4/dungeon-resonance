extends "res://tests/tan_dang_walkthrough_test.gd"
## Fresh actual doors/walk/confirmation, no quest grants or player warps.
var stages: Array[Dictionary]=[]
var branch: String=""
var native: bool=false

func mark(label: String,hold: int=24) -> void:
	stages.append({"label":label,"frame":Engine.get_process_frames(),"branch":branch});print("MOVIE_STAGE "+JSON.stringify(stages.back()))
	if native:
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(branch+"_"+label+".png"))==OK,"Rendered native evidence: "+label)
	await _frames(hold if native else 1)

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	native=DisplayServer.get_name()!="headless"
	if native:
		if not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
		root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60
	AudioServer.set_bus_mute(0,true)
	for next_branch: String in ["rescue","gate"]:
		branch=next_branch;path="user://verification/part5_runtime/"+branch+".json"
		if not await _start() or not await _story():break
		if not await _secret():break
		await _cold()
		_check(hub.exploration.progress.state_for(flow.profile)["cache_claimed"] and OpeningExplorationProgress.shortcut_open(flow.profile),"Cold load preserves both bounded cache and quest-derived mechanical release")
		_check(_shortcut_body().contains("SC01: cơ cấu đường giữ đèn đã mở.") and not _shortcut_body().contains("sẽ mở"),"Cold quest save keeps the post-open exploration explanation")
		_check(hub.tan_dang.progress.alive(TanDangProgress.DU)==(branch=="rescue"),"Cold load retains canonical rescue/death consequence")
		var dust: int=flow.profile.material_stash[&"dust"]
		_check(not hub.exploration.progress.claim().get("ok",false) and flow.profile.material_stash[&"dust"]==dust,"Cold revisit cannot farm any dust")
		if not await _main_walk(2400) or not await _main_walk(1760):break
		if not await _main_walk(2200):break
		await mark("cold_revisit")
		_release_motion();flow.queue_free();current_scene=null;await _frames(8)
	if failures==0:
		branch="manual";path="user://verification/part5_runtime/manual.json"
		if await _start():
			await _manual_shortcut()
		_release_motion();flow.queue_free();current_scene=null;await _frames(8)
	await root.get_node("AudioManager").shutdown()
	var file:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("runtime-evidence.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"hz":Engine.physics_ticks_per_second,"segments":segments,"stages":stages,"walked_distance":walked_distance,"walked_ticks":walked_ticks,"scope":"Fresh actual walk/doors/UI both choices and a separate manual SC01 release; Separate translated-geometry suite covers Guard pursuit. No quest/inventory grants or player warps."},"\t"));file.close()
	print("RESULT Part5ExplorationRuntime checks=%d failures=%d hz=%d"%[checks,failures,Engine.physics_ticks_per_second]);quit(0 if failures==0 else 1)

func _start() -> bool:
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=path;root.add_child(flow);current_scene=flow;await _frames(14);hub=flow.active_scene as ExteriorHub
	return _check(hub!=null and not hub.outside and not flow.qa_tools_enabled,"Fresh default product with separate branch save")

func _story() -> bool:
	if not await _interact(TanDangJourney.LEDGER) or not await _choose(&"td_accept") or not await _close_dialogue():return false
	if not await _interact(TanDangJourney.LAMP) or not await _choose(&"td_observe_lamp") or not await _close_dialogue():return false
	if not await _door(&"exterior_road",&"o01_p01") or not await _door(&"tunnel",&"o01_p02"):return false
	_check(hub.exterior.route_id==ExteriorRouteCatalog.TUNNEL and not hub.exterior.gate_open,"Before q3 the existing physical shortcut gate stays closed")
	Input.action_press(&"move_right");await _frames(ceili(2.0*Engine.physics_ticks_per_second));_release_motion();await _frames(5)
	_check(hub.exterior.to_local(hub.player.global_position).x<640 and hub.player.motor.is_grounded(),"Closed gate stops actual walk without trapping feet")
	await mark("shortcut_closed")
	if not await _door(&"door_west",&"o01_p01"):return false
	if not await _door(&"door_east",&"o01_p02"):return false
	var long_begin: int=walked_ticks
	if not await _door(&"door_east",&"o01_p03"):return false
	_check(not OpeningExplorationProgress.shortcut_open(flow.profile) and _shortcut_body().contains("sẽ mở"),"Discovered P03 journal still points to the unopened SC01 mechanism")
	var long_ticks: int=walked_ticks-long_begin
	if not await _interact(TanDangJourney.REFUGE):return false
	for id: StringName in [&"td_find_lam",&"td_inspect_core",&"td_q1_reward"]:
		if not await _choose(id):return false
	if not await _choose(StringName("td_choice_"+branch)):return false
	hub.dialogue.confirm_button.grab_focus();await _key(KEY_ENTER)
	_check(hub.tan_dang.progress.state()["choice"]==branch,"Real confirmation commits the selected canonical branch")
	if not await _close_dialogue():return false
	if not await _door(&"door_west",&"o01_p02") or not await _door(&"door_west",&"o01_p01") or not await _door(&"door_west",ExteriorRouteCatalog.HUB):return false
	if branch=="gate":
		if not await _interact(TanDangJourney.LAMP) or not await _choose(&"td_install_core") or not await _close_dialogue():return false
	if not await _interact(StringName(TanDangProgress.MOC)) or not await _choose(&"td_report_moc") or not await _close_dialogue():return false
	if not await _interact(StringName(TanDangProgress.LAM)) or not await _choose(&"td_report_lam") or not await _choose(&"td_q3_reward") or not await _close_dialogue():return false
	_check(OpeningExplorationProgress.shortcut_open(flow.profile) and not flow.profile.exterior_progress["sc01_open"],"Committed quest opens existing shortcut without consuming the old manual flag")
	_check(_shortcut_body().contains("SC01: cơ cấu đường giữ đèn đã mở.") and not _shortcut_body().contains("sẽ mở"),"Quest-derived SC01 release updates the discovered journal without a manual lever flag")
	_check(hub.exploration.scene_choice==branch and hub.exploration.aftermath.get_child_count()==2,"Branch-specific grounded scenery is read directly from the saved choice")
	await _walk_x(1010);await mark("hub_aftermath",100)
	if not await _door(&"exterior_road",&"o01_p01") or not await _door(&"tunnel",&"o01_p02"):return false
	_check(hub.exterior.gate_open and hub.exterior.gate.collision_layer==0,"Physical cull of the existing gate collider after completion")
	if not await _main_walk(900):return false
	# Return to west by real walking, then time the same endpoint door crossing.
	if not await _walk_x(ExteriorHub.ORIGIN.x+150):return false
	var short_begin: int=walked_ticks
	if not await _door(&"door_east",&"o01_p03"):return false
	_check(walked_ticks-short_begin<long_ticks,"Actual shortcut walk to P03 takes fewer ticks than main P02")
	await mark("shortcut_open")
	if not await _walk_to(&"sc01_lever"):return false
	hub._process(0.0)
	_check(hub.nearest_station()==&"sc01_lever" and hub.prompt.text=="E · Cơ cấu đường giữ đèn · Đã mở" and not flow.profile.exterior_progress["sc01_open"],"Quest-open lever prompt reports the physical state without writing the manual flag")
	return true

func _shortcut_body() -> String:
	var rows: Array[Dictionary]=hub.exploration.journal_rows()
	return str(rows.back().get("body","")) if not rows.is_empty() else ""

func _manual_shortcut() -> void:
	if not await _door(&"exterior_road",&"o01_p01") or not await _door(&"door_east",&"o01_p02") or not await _door(&"door_east",&"o01_p03"):return
	if not await _walk_to(&"sc01_lever"):return
	hub._process(0.0)
	_check(not OpeningExplorationProgress.shortcut_open(flow.profile) and _shortcut_body().contains("sẽ mở") and hub.prompt.text=="E · Mở cổng đường giữ đèn","Before manual release the journal and lever both show the unopened mechanism")
	await _key(KEY_E)
	hub._process(0.0)
	_check(flow.profile.exterior_progress["sc01_open"] and OpeningExplorationProgress.shortcut_open(flow.profile) and not hub.tan_dang.progress.state()["rewards"].has("q3"),"Ordinary E opens historical SC01 without quest completion")
	_check(_shortcut_body().contains("SC01: cơ cấu đường giữ đèn đã mở.") and hub.prompt.text=="E · Cơ cấu đường giữ đèn · Đã mở","Manual release uses the same post-open journal and lever copy")
	await _cold()
	_check(OpeningExplorationProgress.shortcut_open(flow.profile) and _shortcut_body().contains("SC01: cơ cấu đường giữ đèn đã mở."),"Cold manual save keeps the post-open exploration explanation")

func _walk_x(x: float) -> bool:
	var start: Vector2=hub.player.global_position;var previous: Vector2=start;var moved: float=0
	for i: int in ceili((absf(x-start.x)/200+5)*Engine.physics_ticks_per_second):
		var dx: float=x-hub.player.global_position.x;var speed: float=absf(hub.player.velocity.x);_release_motion()
		if absf(dx)>maxf(4,speed*speed/(2*hub.player.motor.ground_deceleration)+3):Input.action_press(&"move_right" if dx>0 else &"move_left")
		await _frames(1);walked_ticks+=1
		var displacement: float=hub.player.global_position.distance_to(previous);moved+=displacement;walked_distance+=displacement;previous=hub.player.global_position
		if displacement>40:return _check(false,"Ordinary traversal must not teleport/sweep through geometry")
		if absf(x-hub.player.global_position.x)<6 and absf(hub.player.velocity.x)<2 and hub.player.motor.is_grounded():break
	_release_motion();await _frames(4)
	segments.append({"room":_room_key(),"route":hub.exterior.route_id if hub.outside else &"hub","start":start,"end":hub.player.global_position,"distance":moved})
	return _check(absf(x-hub.player.global_position.x)<8 and hub.player.motor.is_grounded(),"Actual continuous physical walk reaches x %.1f"%x)

func _main_walk(x: float) -> bool:
	if not await _walk_x(ExteriorHub.ORIGIN.x+x):return false
	return _check(absf(hub.exterior.to_local(hub.player.global_position).y-hub.exterior.floor_y(x))<3,"Main floor stays clear under optional one-way ledges")

func _jump_to(x: float,y: float) -> bool:
	Input.action_press(&"jump")
	for i: int in ceili(1.5*Engine.physics_ticks_per_second):
		var dx: float=ExteriorHub.ORIGIN.x+x-hub.player.global_position.x
		Input.action_release(&"move_left");Input.action_release(&"move_right")
		if absf(dx)>6:Input.action_press(&"move_right" if dx>0 else &"move_left")
		await _frames(1)
		if i>4 and hub.player.motor.is_grounded():break
	_release_motion();await _frames(5)
	return _check(absf(hub.exterior.to_local(hub.player.global_position).y-y)<3 and absf(hub.player.global_position.x-(ExteriorHub.ORIGIN.x+x))<20,"Existing single jump lands on the actual optional shelf")

func _secret() -> bool:
	if not await _main_walk(2240):return false
	_check(not hub.exploration.interact() and not hub.exploration.progress.state_for(flow.profile)["cache_claimed"],"E from the road below cannot collect through the secret landing")
	if not await _main_walk(1830):return false
	await mark("visible_clue",70)
	if not await _jump_to(1940,OpeningExploration.LEDGES[0].position.y):return false
	if not await _jump_to(2110,OpeningExploration.LEDGES[1].position.y):return false
	if not await _walk_x(ExteriorHub.ORIGIN.x+OpeningExploration.CACHE_POINT.x):return false
	_check(hub.nearest_station()==OpeningExploration.CACHE,"Cache has actual physical E reach only on the upper landing")
	await mark("secret_reached",70)
	if not await _interact(OpeningExploration.CACHE) or not await _choose(&"explore_cache_claim"):return false
	_check(hub.dialogue.pending_choice==&"explore_cache_claim","Reward requires normal confirmation")
	hub.dialogue.cancel_button.grab_focus();await _key(KEY_ENTER)
	_check(not hub.exploration.progress.state_for(flow.profile)["cache_claimed"],"Cancel consumes no reward or opportunity")
	if not await _choose(&"explore_cache_claim"):return false
	var before: int=flow.profile.material_stash[&"dust"]
	hub.dialogue.confirm_button.grab_focus();await _key(KEY_ENTER);await _frames(3)
	_check(flow.profile.material_stash[&"dust"]==before+2 and hub.exploration.progress.state_for(flow.profile)["cache_claimed"],"Actual confirmed E reward persists in existing stash with one receipt")
	await mark("reward_committed",70)
	if not await _main_walk(2410 if branch=="rescue" else 1780):return false
	_check(not hub.dialogue.is_open and hub.player.controls_enabled,"Walk/drop out on either side keeps normal controls and main route")
	# A whole-process reload is additional below; this cold product owner also
	# restores the ordinary saved west anchor, never a perch/inside collider.
	return true

func _cold() -> void:
	_release_motion();flow.queue_free();current_scene=null;await _frames(10)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=path;root.add_child(flow);current_scene=flow;await _frames(16);hub=flow.active_scene as ExteriorHub
	_check(hub.outside and hub.exterior.room_id==&"o01_p03" and hub.player.motor.is_grounded(),"Cold product load uses safe ordinary anchor rather than a removed shelf")
