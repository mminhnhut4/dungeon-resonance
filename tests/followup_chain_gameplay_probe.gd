extends "res://tests/linked_gameplay_probe.gd"
## Current earned H7 save; actual one-link casts and unmodified dungeon combat.
var chain_cues: Array[Dictionary] = []
func _chain_node(node: Node) -> void:
	if node is SpellVisual and node.chain_ordinal>0:
		chain_cues.append({"phase":phase,"wall_usec":Time.get_ticks_usec(),"ordinal":node.chain_ordinal,"endpoints":node.segments.duplicate(),"lifetime":node.lifetime})
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-h7" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("FOLLOWUP_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("FOLLOWUP_SOURCE_NPC"),"Exact H7 earned profile and NPC files before product startup")
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	_check(not flow.qa_tools_enabled and realm()==3 and hub.player.resonance_controller.get_recipe().id==&"firestorm" and hub.gear.inventory.equipped_weapon_uid==1,"Earned Truc Co/Fire-Wind and original sword UID1, no grants or edited loadout")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	node_added.connect(_chain_node);hub.link_dummy.hurtbox.hit_resolved.connect(rear_hit)
	await power_page("earned_truc_co_before_cast")
	for i: int in 3:
		if not await cast_at_targets("accepted_one_link_%d"%i,1):await _finish_followup_chain(false);return
	_check(chain_cues.size()>=3 and chain_cues.all(func(row: Dictionary)->bool:return row["ordinal"]==1 and row["lifetime"]==0.25),"Existing target pair produces actual bounded ordinal1 cues")
	if not await real_dungeon():await _finish_followup_chain(false);return
	await _finish_followup_chain(true)
func _finish_followup_chain(complete: bool) -> void:
	bot.stop();await pause(.4);var cap: Dictionary=recorder.finish()
	var data: Dictionary={"checks":checks,"failures":failures,"complete":complete,"chain_cues":chain_cues,"rear_contacts":rear_contacts,"dungeon_links":dungeon_links,"snapshots":snapshots,"source_profile":OS.get_environment("FOLLOWUP_SOURCE_PROFILE"),"source_npc":OS.get_environment("FOLLOWUP_SOURCE_NPC"),"capture":{"wall_seconds":cap["wall_seconds"],"frames":cap["frames"].size(),"audio":cap["audio"]},"scope":"Actual earned H7 save, three normal I inputs on existing product dummies and actual portal/combat/return input. No grant, HP, damage, warp, RNG or state fixture. One earned link only; second-hop coverage is unit-only. This records new presentation, not another breakthrough unlock."}
	var f:=FileAccess.open(evidence.path_join("followup-chain.json"),FileAccess.WRITE);f.store_string(JSON.stringify(data,"\t"));f.close()
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT FollowupChain checks=%d failures=%d complete=%s wall=%.3f"%[checks,failures,complete,cap["wall_seconds"]]);quit(0 if complete and failures==0 else 1)
