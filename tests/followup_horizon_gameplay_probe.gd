extends "res://tests/living_gameplay_probe.gd"
## Actual earned rt2 pair only; ordinary input and product wall-time progression.
## QA evidence only, never changes any owner/HP/position/clock/RNG/save field.
var horizon_samples: Array[Dictionary] = []
var horizon_doors: Array[Dictionary] = []
var horizon_round_trip: Dictionary = {}
var continuity_exercised: bool = false
var continuity_reason: String = "not_attempted"
var last_horizon_sample: int = 0
var greeted_capture: Dictionary = {}
var residents_connected: Dictionary = {}

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-item4" in OS.get_cmdline_user_args():quit(2);return
	living_mode="help"
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	if not _check(FileAccess.get_sha256(profile_path)==OS.get_environment("LIVING_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("LIVING_SOURCE_NPC"),"Starts with the exact played item4 profile and NPC pair, no scenario edits"):quit(2);return
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	hub.player.equipped_weapon.attack_committed.connect(func(committed: AttackSnapshot) -> void:opening_direction=committed.attack_direction)
	_check(not flow.qa_tools_enabled and hub.tan_dang.progress.state()["rewards"].has("q3") and hub.npc_population.state.living_view(TanDangProgress.LAM)["event_phase"] in ["none","outbound"],"Earned rescued route naturally starts the newly available NPC work")
	quest_before=Writer.canonical(hub.tan_dang.progress.state());source_gear=GearInventoryCodec.encode(hub.gear.inventory);uninvolved_before=hub.npc_population.state.records.duplicate(true);initial_money=Vector2i(flow.profile.coins,flow.profile.souls);initial_stash=flow.profile.material_stash.duplicate()
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	RenderingServer.frame_post_draw.connect(_horizon_sample)
	_stage("observe_three_residents_without_prompting_them");note("start")
	if not await _walk(hub.player,1040):await finish_living(false);return
	await _shot("three_residents_working");await _watch(5)
	var before_positions: Dictionary={}
	for id: String in TanDangProgress.NPC_IDS:before_positions[id]=float(hub.npc_population.state.records[id]["x"])
	await _watch(4);note("independent_routines")
	_check(TanDangProgress.NPC_IDS.any(func(id: String) -> bool:return absf(float(hub.npc_population.state.records[id]["x"])-float(before_positions[id]))>10.0),"Residents move towards their own authored work while Player only watches")
	for i: int in 70:
		if hub.npc_population.state.records[TanDangProgress.LAM]["room"]=="o01_p01":break
		await _watch(.5)
	_check(hub.npc_population.state.records[TanDangProgress.LAM]["room"]=="o01_p01","Lâm independently walks to the real road endpoint and leaves for P01")
	await _shot("lam_has_left_for_p01");note("npc_crossed_first")
	if living_mode=="help":
		_stage("watch_the_courtyard_before_following")
		await _watch(6.0)
	if not await travel(&"exterior_road",&"o01_p01"):await finish_living(false);return
	_stage("follow_the_actual_road_to_the_foraging_work")
	if not await _walk(hub.player,ExteriorHub.ORIGIN.x+(605 if living_mode=="help" else 660)):await finish_living(false);return
	for i: int in 160:
		await _watch(.2)
		if is_instance_valid(hub.living.enemy):break
	if not _check(is_instance_valid(hub.living.enemy),"The product event spawns the real room-owned slime after Lâm reaches and works at the collection point"):await finish_living(false);return
	_connect_encounter()
	_stage("actual_event_"+living_mode);note("danger")
	if living_mode=="help":
		# One ordinary left-facing strike from between the slime and traveler.
		# Then draw the living threat away and allow the NPC to choose retreat;
		# do not swing through residents or manufacture a slain-monster outcome.
		var aim:=InputEventMouseMotion.new();aim.position=hub.player.get_canvas_transform()*hub.living.enemy.hurtbox.global_position;root.push_input(aim,true);await _step(2);await _key(KEY_J)
		_check(opening_direction.x<0.0,"Opening real sword input commits toward the slime on Player's left, away from the traveler")
		await _watch(.1);await _shot("actual_danger")
		_stage("attempt_danger_room_return_by_real_doors")
		if not await _horizon_round_trip():await finish_living(false);return
		_stage("draw_the_threat_away_after_actual_room_return")
		for i: int in 4:
			if hub.npc_population.state.living_view(TanDangProgress.LAM)["event_phase"]!="danger":break
			if not await _walk(hub.player,ExteriorHub.ORIGIN.x+(1900.0 if i%2==0 else 1000.0)):await finish_living(false);return
			await _watch(.3)
		await _shot("real_helping_strike_and_finite_retreat")
		if not await _walk(hub.player,ExteriorHub.ORIGIN.x+740):await finish_living(false);return
	else:await _shot("actual_danger")
	for i: int in 220:
		var view: Dictionary=hub.npc_population.state.living_view(TanDangProgress.LAM)
		if view["event_phase"] in ["returning","done"]:break
		await _watch(.25)
	var result: Dictionary=hub.npc_population.state.living_view(TanDangProgress.LAM)
	_check(result["event_phase"] in ["returning","done"] and not result["outcome"].is_empty(),"NPC encounter resolves and return starts without a Player decision or timeout prompt")
	if living_mode=="help":_check(result["outcome"] in ["helped","withdrew"] and result["help_credited"] and result["forage_help"] and physical_hits.any(func(hit: Dictionary) -> bool:return hit["player"] and not hit["blocked"] and hit["damage"]>0),"Only an accepted real Player strike credits this one helping outcome")
	else:_check(result["outcome"] in ["self","withdrew"] and not result["help_credited"] and not physical_hits.any(func(hit: Dictionary) -> bool:return hit["player"] and hit["damage"]>0),"Watching alone leaves NPC to fight or withdraw, without invented Player gratitude")
	_check(not hub.npc_population.state.records[TanDangProgress.LAM]["causality"]["harmed"],"This helping/observing route never disguises Player injury as assistance")
	await _shot("event_resolved_without_menu");note("result")
	for i: int in 100:
		if hub.npc_population.state.records[TanDangProgress.LAM]["room"]=="h00_traveler_hub":break
		await _watch(.3)
	if not await travel(&"door_west",ExteriorRouteCatalog.HUB):await finish_living(false);return
	_stage("return_and_hear_the_consequences")
	if not await _walk(hub.player,1150):await finish_living(false);return
	for i: int in 120:
		if hub.npc_population.state.living_view(TanDangProgress.LAM)["event_phase"]=="done":break
		await _watch(.25)
	await _watch(4);note("home")
	_check(hub.npc_population.state.living_view(TanDangProgress.LAM)["event_phase"]=="done" and not is_instance_valid(hub.living.enemy),"Returned NPC closes the one event and no threat follows into the courtyard")
	if not await interact_story(StringName(TanDangProgress.LAM),"lam_remembers_the_actual_trip",true):await finish_living(false);return
	await close_dialogue();await _watch(8)
	if living_mode=="help":
		_check(hub.npc_population.state.living_view(TanDangProgress.LAM)["acknowledged"]["forage_help"],"Lâm naturally gives the visible specific help greeting near Player and saves its once-only acknowledgement")
	for i: int in 100:
		if hub.npc_population.state.living_view(TanDangProgress.DU)["heard_materials"]:break
		await _watch(.4)
	_check(hub.npc_population.state.living_view(TanDangProgress.DU)["heard_materials"],"Dư learns this trip only through an actual nearby calm conversation with returned Lâm")
	_check(hub.npc_population.state.living_view(TanDangProgress.MOC)["heard_materials"],"Mộc hears the returning Lâm only as their actual courtyard paths remain nearby long enough")
	note("greetings_and_local_news")
	await _shot("actual_local_news")
	await journal(&"tan_dang_relations","living_relationship_journal")
	_check(Writer.canonical(hub.tan_dang.progress.state())==quest_before,"Autonomous work never changes the already-earned quest, core, contribution, guest or recipe receipts")
	_check(Vector2i(flow.profile.coins,flow.profile.souls)==initial_money and flow.profile.material_stash==initial_stash,"This encounter creates no currency, stored loot or renewed aid")
	for id: String in TanDangProgress.NPC_IDS:_check(hub.tan_dang.progress.alive(id),"Ordinary independent route preserves each real living person: "+id)
	var uninvolved_safe: bool=true
	for id: String in uninvolved_before:
		if id==TanDangProgress.LAM:continue
		for field: String in ["hp","trust","fear","death","karma"]:
			uninvolved_safe=uninvolved_safe and Writer.canonical(uninvolved_before[id].get(field))==Writer.canonical(hub.npc_population.state.records[id].get(field))
	_check(uninvolved_safe,"No uninvolved resident is injured or assigned distrust by this route")
	await finish_living(true)


func _horizon_state() -> Dictionary:
	var view: Dictionary = hub.npc_population.state.living_view(TanDangProgress.LAM)
	return {"wall_usec":Time.get_ticks_usec(),"room":String(hub.exterior.room_id) if hub.outside else String(ExteriorRouteCatalog.HUB),"phase":view.get("event_phase",""),"elapsed":view.get("danger_elapsed",-1.0),"outcome":view.get("outcome",""),"help_credited":view.get("help_credited",false),"player_x":hub.player.global_position.x,"player_y":hub.player.global_position.y,"player_hp":hub.player.health.current_health,"lam_hp":hub.npc_population.state.records[TanDangProgress.LAM]["hp"],"transition_count":hub.transition_count}

func _horizon_round_trip() -> bool:
	# Read actual authored doors. Walking may let Lâm finish naturally; that is
	# recorded as not_exercised and never reversed or held in danger for a clip.
	horizon_round_trip["at_request"] = _horizon_state()
	if not await _horizon_door(&"door_east",&"o01_p02","exit_danger"): return false
	horizon_round_trip["after_exit"] = _horizon_state()
	await _watch(1.0)
	horizon_round_trip["offroom_after_one_second"] = _horizon_state()
	if not await _horizon_door(&"door_west",&"o01_p01","return_to_danger"): return false
	var before: Dictionary = horizon_round_trip.get("before_exit",{})
	var after: Dictionary = _horizon_state()
	horizon_round_trip["after_return"] = after
	if before.get("phase","")!="danger" or after["phase"]!="danger":
		continuity_reason = "not_exercised_event_already_resolved_at_door_or_return"
		print("HORIZON_NATIVE_NOT_EXERCISED "+JSON.stringify(horizon_round_trip))
	else:
		var before_elapsed: float = float(before.get("elapsed",-1.0))
		var after_elapsed: float = float(after["elapsed"])
		continuity_exercised = before_elapsed>0.0 and after_elapsed>=before_elapsed and after_elapsed<35.0
		continuity_reason = "actual_room_return_preserved_elapsed" if continuity_exercised else "actual_room_return_reset_or_invalid_elapsed"
		_check(continuity_exercised,"Actual normal-input P01→P02→P01 danger return preserves positive elapsed")
		_check(is_equal_approx(float(horizon_round_trip["after_exit"]["elapsed"]),float(horizon_round_trip["offroom_after_one_second"]["elapsed"])),"Actual off-room wall time consumes none of Lâm's danger horizon")
	print("HORIZON_NATIVE_BOUNDARY "+JSON.stringify({"exercised":continuity_exercised,"reason":continuity_reason,"observations":horizon_round_trip}))
	await _shot("horizon_after_ordinary_room_return")
	return true

func _horizon_door(id: StringName,destination: StringName,label: String) -> bool:
	await close_dialogue()
	if not hub.outside or not hub.exterior.interactions.has(id): return _check(false,"Actual room has the requested authored door: "+String(id))
	var x: float = (ExteriorHub.ORIGIN+hub.exterior.interactions[id]).x
	var departure: Dictionary = _horizon_state()
	if not await _walk(hub.player,x): return false
	await _step(5)
	if not _check(hub.nearest_station()==id,"Normal walking reaches exact authored horizon door: "+String(id)): return false
	var before: Dictionary = _horizon_state()
	if label=="exit_danger": horizon_round_trip["before_exit"] = before
	await _key(KEY_E); await _step(12)
	var after: Dictionary = _horizon_state()
	horizon_doors.append({"label":label,"door":String(id),"authored_x":x,"walk_start":departure,"before_E":before,"after_E":after})
	return _check((hub.exterior.room_id if hub.outside else ExteriorRouteCatalog.HUB)==destination,"Actual E crosses horizon door to "+String(destination))

func _horizon_sample() -> void:
	if not is_instance_valid(hub) or not is_instance_valid(recorder) or not recorder.capturing: return
	var now: int = Time.get_ticks_usec()
	if now-last_horizon_sample<200000 or horizon_samples.size()>=3000: return
	last_horizon_sample=now
	_connect_encounter()
	var sample: Dictionary = _horizon_state()
	if not horizon_samples.is_empty():
		var previous: Dictionary = horizon_samples.back()
		sample["player_displacement"]=[float(sample["player_x"])-float(previous["player_x"]),float(sample["player_y"])-float(previous["player_y"])]
		sample["same_room_as_previous"]=sample["room"]==previous["room"]
	var labels: Array[Dictionary] = []
	for id: String in hub.npc_population.actors:
		var actor: NpcPilotActor = hub.npc_population.actors[id] as NpcPilotActor
		if not is_instance_valid(actor): continue
		var instance: int = actor.get_instance_id()
		if not residents_connected.has(instance):
			residents_connected[instance]=true
			actor.hurtbox.hit_resolved.connect(_real_hit)
		var caption: Label = actor.caption
		var transform: Transform2D = caption.get_global_transform_with_canvas()
		var rectangle := transform*Rect2(Vector2.ZERO,caption.size)
		labels.append({"id":id,"x":actor.global_position.x,"y":actor.global_position.y,"local_x":actor.position.x,"owner_x":hub.npc_population.state.records[id]["x"],"owner_target":hub.npc_population.state.records[id]["target"],"owner_room":hub.npc_population.state.records[id]["room"],"caption":caption.text,"visible":caption.is_visible_in_tree(),"screen_rect":[rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y],"rotation":transform.get_rotation()})
		if id==TanDangProgress.LAM and greeted_capture.is_empty():
			var view: Dictionary = hub.npc_population.state.living_view(id)
			var resident: CultivatorActor = actor as CultivatorActor
			if resident!=null and view.get("forage_help",false) and not view.get("acknowledged",{}).get("forage_help",false) and resident.greeting_hint==hub.living._greeting_line(id,"forage_help") and caption.text.contains(resident.greeting_hint) and caption.is_visible_in_tree():
				var image_path: String = evidence.path_join("actual_unacknowledged_forage_greeting.png")
				var status: Error = root.get_texture().get_image().save_png(image_path)
				greeted_capture={"saved":status==OK,"wall_usec":now,"text":caption.text,"screen_rect":[rectangle.position.x,rectangle.position.y,rectangle.size.x,rectangle.size.y],"phase":view["event_phase"],"room":view["room"],"acknowledged_at_capture":false}
				print("HORIZON_ACTUAL_GREETING "+JSON.stringify(greeted_capture))
	sample["captions"]=labels
	if is_instance_valid(hub.living.enemy): sample["enemy"]={"id":hub.living.enemy.get_instance_id(),"x":hub.living.enemy.global_position.x,"y":hub.living.enemy.global_position.y,"hp":hub.living.enemy.health.current_health}
	horizon_samples.append(sample)

func finish_living(complete: bool) -> void:
	if RenderingServer.frame_post_draw.is_connected(_horizon_sample): RenderingServer.frame_post_draw.disconnect(_horizon_sample)
	var data: Dictionary={"route_complete":complete,"continuity_exercised":continuity_exercised,"continuity_reason":continuity_reason,"round_trip":horizon_round_trip,"doors":horizon_doors,"samples":horizon_samples,"actual_unacknowledged_forage_greeting":greeted_capture,"physical_hits":physical_hits,"final":_horizon_state(),"spoken":spoken,"scope":"Earned rt2 exact files, normal walking/mouse/J/E/M wall-time input. Samples read actual owner elapsed/phase and actual caption bounds. No position/clock/HP/RNG/save/phase mutation. A naturally resolved event before boundary is not_exercised, never forced to remain danger. This route does not prove crash durability or audio quality."}
	var file:=FileAccess.open(evidence.path_join("horizon-route.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(data,"\t",true,true));file.close()
	await super.finish_living(complete and continuity_exercised)