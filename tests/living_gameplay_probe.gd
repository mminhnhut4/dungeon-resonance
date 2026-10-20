extends "res://tests/story_gameplay_probe.gd"
## Real earned item4 files, normal viewport input and wall time. No branch fixture.
var living_mode: String = "observe"
var live_observations: Array[Dictionary] = []
var physical_hits: Array[Dictionary] = []
var quest_before: String
var source_gear: Dictionary
var observed_enemy_id: int = 0
var uninvolved_before: Dictionary = {}
var opening_direction: Vector2 = Vector2.ZERO

func note(label: String) -> void:
	var positions: Dictionary={}
	for id: String in hub.npc_population.actors:
		var actor: Node2D=hub.npc_population.actors[id] as Node2D
		if is_instance_valid(actor):positions[id]={"x":actor.global_position.x,"y":actor.global_position.y}
	live_observations.append({"actor_positions":positions,"player_x":hub.player.global_position.x,"label":label,"tick":hub.npc_population.state.tick,"lam":hub.npc_population.state.records[TanDangProgress.LAM].duplicate(true),"moc":hub.npc_population.state.living_view(TanDangProgress.MOC),"du":hub.npc_population.state.living_view(TanDangProgress.DU),"coins":flow.profile.coins,"souls":flow.profile.souls})

func _real_hit(event: DamageEvent,result: DamageResult) -> void:
	physical_hits.append({"source":event.source_id,"target":event.target_id,"player":event.source_id==hub.player.get_instance_id(),"kind":event.source_kind,"root":event.root_event_id,"damage":result.actual_damage,"blocked":result.blocked})

func _connect_encounter() -> void:
	if is_instance_valid(hub.living.enemy) and hub.living.enemy.get_instance_id()!=observed_enemy_id:
		observed_enemy_id=hub.living.enemy.get_instance_id();hub.living.enemy.hurtbox.hit_resolved.connect(_real_hit)

func _watch(seconds: float) -> void:
	var until: int=Time.get_ticks_usec()+roundi(seconds*1000000.0)
	while Time.get_ticks_usec()<until:
		_connect_encounter()
		await pause(.1)

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-item4" in OS.get_cmdline_user_args():quit(2);return
	living_mode="help" if "--help-event" in OS.get_cmdline_user_args() else "observe"
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("LIVING_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("LIVING_SOURCE_NPC"),"Starts with the exact played item4 profile and NPC pair, no scenario edits")
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	hub.player.equipped_weapon.attack_committed.connect(func(committed: AttackSnapshot) -> void:opening_direction=committed.attack_direction)
	_check(not flow.qa_tools_enabled and hub.tan_dang.progress.state()["rewards"].has("q3") and hub.npc_population.state.living_view(TanDangProgress.LAM)["event_phase"] in ["none","outbound"],"Earned rescued route naturally starts the newly available NPC work")
	quest_before=Writer.canonical(hub.tan_dang.progress.state());source_gear=GearInventoryCodec.encode(hub.gear.inventory);uninvolved_before=hub.npc_population.state.records.duplicate(true);initial_money=Vector2i(flow.profile.coins,flow.profile.souls);initial_stash=flow.profile.material_stash.duplicate()
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
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
		_stage("draw_the_threat_away_with_real_walking")
		for i: int in 8:
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

func finish_living(complete: bool) -> void:
	bot.stop();await close_dialogue();await pause(.4);note("final")
	var capture: Dictionary=recorder.finish()
	var data: Dictionary={"checks":checks,"failures":failures,"complete":complete,"mode":living_mode,"source_profile_sha256":OS.get_environment("LIVING_SOURCE_PROFILE"),"source_npc_sha256":OS.get_environment("LIVING_SOURCE_NPC"),"observations":live_observations,"physical_hits":physical_hits,"opening_direction":opening_direction,"all_npc_before":uninvolved_before,"all_npc_after":hub.npc_population.state.records.duplicate(true),"inventory_before":source_gear,"inventory_after":GearInventoryCodec.encode(hub.gear.inventory),"quest":hub.tan_dang.progress.state(),"capture":{"wall_seconds":capture["wall_seconds"],"frames":capture["frames"].size(),"audio":capture["audio"]},"scope":"Actual earned item4 save, product map/event/actors and normal wall-time input. NPC autonomous movement/endpoint room transfer belongs to product owner. No player teleport, grant, unlock, forced damage/HP/RNG/phase or scenario fixture. Automated QA, not human user research."}
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	data["profile_sha256"]=FileAccess.get_sha256(profile_path);data["npc_sha256"]=FileAccess.get_sha256(profile_path+".npc_v1.json")
	var file:=FileAccess.open(evidence.path_join("living-route.json"),FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t",true,true));file.close()
	print("RESULT LivingGameplay checks=%d failures=%d complete=%s mode=%s wall=%.3f"%[checks,failures,complete,living_mode,capture["wall_seconds"]]);quit(0 if complete and failures==0 else 1)
