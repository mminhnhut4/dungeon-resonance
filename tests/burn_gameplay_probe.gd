extends "res://tests/linked_gameplay_probe.gd"
## Same earned H7 save, Hub targets/cast inputs and resolution for GPU/CPU videos.
## Dungeon remains normal/unseeded; performance comparisons use the separate fixture.
var burn_owners: Dictionary[int,WeakRef]={}
var previous_burn: Dictionary[int,bool]={}
var burn_events: Array[Dictionary]=[]
var max_burning: int=0
var max_cpu_burning: int=0
var backend_correct: bool=true
func _born(node: Node) -> void:
	if node is ElementAfflictionVFX:burn_owners[node.get_instance_id()]=weakref(node)
func _watch() -> void:
	var count: int=0;var cpu_count: int=0
	for id: int in burn_owners.keys():
		var visual: ElementAfflictionVFX=burn_owners[id].get_ref() as ElementAfflictionVFX
		if not is_instance_valid(visual):burn_owners.erase(id);previous_burn.erase(id);continue
		if visual.burn==null:continue
		var active: bool=visual.burn_visible
		var cpu: CPUParticles2D=visual.get_node_or_null("BurnEmbersCompatibility") as CPUParticles2D
		if active:
			count+=1
			if cpu!=null and cpu.emitting and cpu.visible:cpu_count+=1
			backend_correct=backend_correct and (visual.burn.emitting and visual.burn.visible if "--baseline" in OS.get_cmdline_user_args() else cpu!=null and cpu.emitting and cpu.visible and not visual.burn.emitting and not visual.burn.visible)
		if active!=bool(previous_burn.get(id,false)):
			if burn_events.size()<512:burn_events.append({"id":id,"phase":phase,"active":active,"wall_usec":Time.get_ticks_usec(),"actor":String(visual.get_parent().name),"cpu":cpu!=null,"position":(visual.get_parent() as Node2D).global_position})
			previous_burn[id]=active
	max_burning=maxi(max_burning,count);max_cpu_burning=maxi(max_cpu_burning,cpu_count)
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-h7" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("FOLLOWUP_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("FOLLOWUP_SOURCE_NPC"),"Starts from the exact same earned H7 profile/NPC bytes")
	node_added.connect(_born);process_frame.connect(_watch)
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	_check(not flow.qa_tools_enabled and realm()==3 and hub.player.resonance_controller.get_recipe().id==&"firestorm" and hub.gear.inventory.equipped_weapon_uid==1,"Same earned sword/Fire-Wind/realm through the unmodified product owner")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	hub.link_dummy.hurtbox.hit_resolved.connect(rear_hit)
	for i: int in 3:
		if not await cast_at_targets("same_hub_firestorm_%d"%i,1):await _finish_burn(false);return
	_check(burn_events.filter(func(e: Dictionary)->bool:return e["active"] and String(e["phase"]).begins_with("same_hub_")).size()>=3,"Three actual input casts visibly re-trigger real target burn")
	if not await real_dungeon():await _finish_burn(false);return
	_check(max_burning>0 and backend_correct,"Observed gameplay burn uses the expected active backend and retained original source settings")
	await _finish_burn(true)
func _finish_burn(complete: bool) -> void:
	bot.stop();await pause(0.4);var cap: Dictionary=recorder.finish()
	var state: Dictionary={"checks":checks,"failures":failures,"complete":complete,"max_burning":max_burning,"max_cpu_burning":max_cpu_burning,"backend_correct":backend_correct,"burn_events":burn_events,"source_profile":OS.get_environment("FOLLOWUP_SOURCE_PROFILE"),"source_npc":OS.get_environment("FOLLOWUP_SOURCE_NPC"),"capture":{"wall_seconds":cap["wall_seconds"],"frames":cap["frames"].size(),"audio":cap["audio"]},"scope":"Same H7 earned save and three Hub Firestorm input casts, normal portal and first-floor combat/return. No grants, loadout/HP/damage/phase/warp/RNG overrides; normal1× continuous viewport. Hub comparison shares exact conditions; normal unseeded dungeon outcomes need not match. Not a benchmark or subjective audio review."}
	var f:=FileAccess.open(evidence.path_join("burn-gameplay.json"),FileAccess.WRITE);f.store_string(JSON.stringify(state,"\t"));f.close()
	process_frame.disconnect(_watch);node_added.disconnect(_born);burn_owners.clear();previous_burn.clear()
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT BurnGameplay checks=%d failures=%d complete=%s wall=%.3f"%[checks,failures,complete,cap["wall_seconds"]]);quit(0 if complete and failures==0 else 1)
