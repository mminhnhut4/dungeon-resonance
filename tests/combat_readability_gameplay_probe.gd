extends "res://tests/linked_gameplay_probe.gd"
## Actual owned Ice/Fire via inventory UI. No grants, warp, HP/damage/RNG/state edit.
var reactions: Array[Dictionary] = []
var status_samples: Array[Dictionary] = []
var inputs: Array[Dictionary] = []
var watched: Dictionary[int,WeakRef] = {}
var last_cast: int = -1
func born(node: Node) -> void:
	if node is ElementAfflictionVFX:watched[node.get_instance_id()]=weakref(node)
func thermal_hit(event: DamageEvent,result: DamageResult) -> void:
	if result.blocked or result.actual_damage<=0:return
	var status: ElementStatusController=hub.dummy.hurtbox.damage_resolver.status_controller as ElementStatusController
	reactions.append({"phase":phase,"damage":result.actual_damage,"recipe":String(event.spell_id),"reaction":String(result.reaction_id),"meter":status.freeze_meter,"freeze":status.freeze_remaining,"kind":event.source_kind,"wall_usec":Time.get_ticks_usec()})
func observe() -> void:
	for id: int in watched.keys():
		var v: ElementAfflictionVFX=watched[id].get_ref() as ElementAfflictionVFX
		if not is_instance_valid(v):watched.erase(id);continue
		if v.ice_progress>0 or v.reaction_remaining>0:
			if status_samples.size()<2400:status_samples.append({"phase":phase,"actor":String(v.get_parent().name),"meter":v.ice_progress,"frozen":v.ice_frozen,"window":v.ice_seconds,"reaction":v.reaction_remaining,"wall_usec":Time.get_ticks_usec()})
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-h7" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("FOLLOWUP_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("FOLLOWUP_SOURCE_NPC"),"Exact earned H7 profile/NPC bytes before product startup")
	node_added.connect(born);process_frame.connect(observe)
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	_check(not flow.qa_tools_enabled and realm()==3 and hub.gear.inventory.equipped_weapon_uid==1 and hub.gear.inventory.bag[&"ice"]>0,"Actual earned realm/sword and owned Ice rune, no QA grant")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	if not await choose_pair([&"ice",&"fire"],"owned_ice_fire_ui"):await finish_combat(false);return
	hub.dummy.hurtbox.hit_resolved.connect(thermal_hit)
	if not await _walk(hub.player,540):await finish_combat(false);return
	_stage("ice_setup_then_thermal_consumption")
	var controller: ResonanceController=hub.player.resonance_controller
	for index: int in 4:
		for i: int in 240:
			if controller.can_cast() and hub.player.action_state_machine.get_state_id()==&"ready":break
			await _step(1)
		var aim:=InputEventMouseMotion.new();aim.position=hub.player.get_canvas_transform()*hub.dummy.hurtbox.global_position;root.push_input(aim,true);await _step(2)
		var count: int=controller.cast_count
		inputs.append({"cast":index,"energy_before":hub.player.energy.current,"cooldown_before":controller.cooldown_remaining(),"meter_before":(hub.dummy.hurtbox.damage_resolver.status_controller as ElementStatusController).freeze_meter,"wall_usec":Time.get_ticks_usec()})
		await _key(KEY_I)
		_check(controller.cast_count==count+1,"One ordinary I input commits one owned composite cast")
		await _step(20)
		await _shot("thermal_cast_%d"%index)
	_check(reactions.any(func(r: Dictionary)->bool:return r["freeze"]>0),"Three real spell contacts open the actual freeze setup window")
	_check(reactions.any(func(r: Dictionary)->bool:return r["reaction"]=="thermal_shock"),"Next real cast consumes freeze and produces the accepted thermal receipt")
	_check(status_samples.any(func(s: Dictionary)->bool:return s["meter"]>0 and s["meter"]<1) and status_samples.any(func(s: Dictionary)->bool:return s["frozen"]) and status_samples.any(func(s: Dictionary)->bool:return s["reaction"]>0),"Actual viewport playback observes buildup, frozen window and thermal feedback")
	await pause(1.0)
	_stage("ordinary_shared_energy_dash")
	var energy: float=hub.player.energy.current
	await _key(KEY_SHIFT);await _step(14)
	_check(hub.player.energy.current<energy and hub.player.motor.dash_cooldown_remaining>0,"Ordinary Shift spends shared energy and exposes actual dash cooldown")
	await pause(1)
	if not await dungeon():await finish_combat(false);return
	await finish_combat(true)
func dungeon() -> bool:
	_stage("normal_portal")
	if not await _walk(hub.player,hub.stations[&"portal"].global_position.x):return false
	await _key(KEY_E);await _step(12)
	if not _check(flow.active_scene is DungeonRun,"Physical portal enters ordinary opening dungeon"):return false
	var run: DungeonRun=flow.active_scene as DungeonRun
	_check(run.player.resonance_controller.get_recipe().id==&"thermal_shock","Normal scene replacement retains the UI-installed Ice/Fire recipe")
	bot.run=run;bot.enabled=true;_stage("opening_combat_existing_enemies")
	for i: int in 10800:
		if run.outcome!=&"" or (run.living_enemies().is_empty() and not run.room.locked):break
		await _step(1)
	bot.stop()
	if not _check(run.outcome==&"" and not run.room.locked,"Opening encounter clears with normal enemy HP/AI/damage and owned gear"):return false
	await pause(.6)
	if not await _walk(run.player,1240):return false
	await _key(KEY_E);await pause(.5)
	if not _check(run.floor_exit.is_open,"Physical completed-floor exit offers normal return"):return false
	await _click(run.floor_exit.return_button);await _step(16);hub=flow.active_scene as ExteriorHub
	return _check(hub!=null and realm()==3,"Normal return preserves earned realm/progression")
func finish_combat(complete: bool) -> void:
	bot.stop();await pause(.5);var cap: Dictionary=recorder.finish()
	var state: Dictionary={"checks":checks,"failures":failures,"complete":complete,"reactions":reactions,"status_samples":status_samples,"cast_inputs":inputs,"profile_source":OS.get_environment("FOLLOWUP_SOURCE_PROFILE"),"capture":{"wall_seconds":cap["wall_seconds"],"frames":cap["frames"].size(),"audio":cap["audio"]},"scope":"Exact earned H7; real inventory clicks equip owned Ice/Fire, I casts at product training target, Shift and physical portal/normal opening combat/return. No grants/warp/HP/damage/RNG/state fixtures.1x continuous; no FPS or subjective audio claim."}
	var f:=FileAccess.open(evidence.path_join("combat-gameplay.json"),FileAccess.WRITE);f.store_string(JSON.stringify(state,"\t"));f.close()
	process_frame.disconnect(observe);node_added.disconnect(born);watched.clear();bot.queue_free();flow.queue_free();current_scene=null;recorder.queue_free();await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT CombatGameplay checks=%d failures=%d complete=%s wall=%.3f"%[checks,failures,complete,cap["wall_seconds"]]);quit(0 if complete and failures==0 else 1)
