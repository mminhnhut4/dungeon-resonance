extends "res://tests/tan_dang_walkthrough_test.gd"
## Fresh continuous story/UI input, then one declared defeat fixture for recovery.
var stages: Array[Dictionary]=[]
var last_choice: StringName=&""

func mark(label: String,hold: int=100) -> void:
	stages.append({"label":label,"frame":Engine.get_process_frames()});print("MOVIE_STAGE "+JSON.stringify(stages.back()))
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(label+".png"))==OK,"Actual native frame captured: "+label)
	await _frames(hold)

func _choose(id: StringName) -> bool:
	var ok: bool=await super._choose(id);last_choice=id
	if ok and id in [&"td_choice_rescue",&"td_assist",&"td_reconcile"]:await mark("choice_"+String(id))
	return ok

func _interact(id: StringName) -> bool:
	var ok: bool=await super._interact(id)
	if ok and id==StringName(TanDangProgress.DU) and hub.npc_population.state.records[TanDangProgress.DU]["mode"]=="downed":await mark("spare_or_kill")
	return ok

func _close_dialogue() -> bool:
	if not hub.dialogue.is_open:return _check(hub.player.controls_enabled,"Automatic decision close already restored controls")
	var ok: bool=await super._close_dialogue()
	if ok and last_choice==&"td_choice_rescue":await mark("rescue_committed")
	return ok

func _journal_mark(label: String) -> void:
	await _key(KEY_M)
	var journal: QuestJournal=(hub.gear.modal as InventoryScreen).journal
	journal.relations_button.grab_focus();await _key(KEY_ENTER);await _frames(4)
	_check(journal.selected_id==&"tan_dang_relations","Real M header opens relationship journal")
	journal.detail_scroll.scroll_vertical=int(journal.detail_scroll.get_v_scroll_bar().max_value);await _frames(4)
	await mark(label,140)
	await _key(KEY_ESCAPE)

func _walk_x(x: float) -> bool:
	for _i: int in 600:
		var difference: float=x-hub.player.global_position.x
		_release_motion()
		if absf(difference)<5 and absf(hub.player.velocity.x)<4:await _frames(3);return true
		if absf(difference)>maxf(4,absf(hub.player.velocity.x)*absf(hub.player.velocity.x)/(2*hub.player.motor.ground_deceleration)+3):Input.action_press(&"move_right" if difference>0 else &"move_left")
		await _frames(1)
	_release_motion();return false

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.physics_ticks_per_second=60;Engine.max_fps=60;AudioServer.set_bus_mute(0,true)
	path="user://verification/part4_movie/profile.json"
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=path;root.add_child(flow);current_scene=flow;await _frames(14);hub=flow.active_scene as ExteriorHub
	await mark("fresh_start",30)
	if not await _walkthrough():await finish();return
	_check(hub.tan_dang.progress.state()["choice"]=="rescue" and not flow.qa_tools_enabled,"Complete existing quest by actual walk/doors/UI without grants")
	await mark("story_completed",30)
	flow.queue_free();current_scene=null;await _frames(10)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=path;root.add_child(flow);current_scene=flow;await _frames(14);hub=flow.active_scene as ExteriorHub
	_check(hub.npc_population.state.karma(TanDangProgress.DU)["rescued"] and not hub.npc_population.state.karma(TanDangProgress.DU)["assistance_used"],"Cold product load remembers rescue and the unclaimed one-time help")
	await _journal_mark("cold_rescue_memory")
	if not await _interact(StringName(TanDangProgress.DU)):await finish();return
	await _choose(&"td_assist");hub.dialogue.confirm_button.grab_focus();await _key(KEY_ENTER)
	_check(hub.npc_population.state.karma(TanDangProgress.DU)["assistance_used"] and flow.profile.material_stash[&"linen_fiber"]==2,"Real confirmed meeting grants exactly the existing two linen")
	await mark("aid_committed",80);await _close_dialogue()
	var du: CultivatorActor=hub.npc_population.actors[TanDangProgress.DU] as CultivatorActor
	if not _check(await _walk_x(du.global_position.x+42),"Continuous movement positions the real melee attacker"):await finish();return
	for _i: int in 16:
		if hub.npc_population.state.records[TanDangProgress.DU]["mode"]=="downed":break
		var motion:=InputEventMouseMotion.new();motion.position=hub.player.get_canvas_transform()*du.hurtbox.global_position;root.push_input(motion,true)
		var event:=InputEventAction.new();event.action=&"attack";event.pressed=true;Input.parse_input_event(event);await _frames(2)
		event=InputEventAction.new();event.action=&"attack";event.pressed=false;Input.parse_input_event(event);await _frames(42)
		if hub.player.health.current_health<=0:break
	_check(hub.player.health.current_health>0 and hub.npc_population.state.records[TanDangProgress.DU]["mode"]=="downed","Real starter melee and self-defense reach downed without direct injury, pose or HP-floor overrides")
	if hub.npc_population.state.records[TanDangProgress.DU]["mode"]!="downed":await finish();return
	if not await _interact(StringName(TanDangProgress.DU)):await finish();return
	await _choose(&"pilot_spare");await _close_dialogue()
	await _journal_mark("mercy_conditions")
	if not await _walk_to(&"portal"):await finish();return
	await _key(KEY_E);await _frames(10)
	_check(flow.active_scene is DungeonRun,"Actual portal E starts the expedition")
	# Sole non-natural setup in this recording: real defeat triggers the existing
	# committed expedition return; no forged outcome or direct NPC healing.
	(flow.active_scene as DungeonRun).player.health.apply_damage(9999)
	for _i: int in 600:
		if flow.active_scene is ExteriorHub:break
		await _frames(1)
	hub=flow.active_scene as ExteriorHub
	_check(hub.tan_dang.progress.can_reconcile(TanDangProgress.DU),"Committed return enables the already-spared life after recovery")
	await mark("after_expedition_fixture",20)
	if not await _interact(StringName(TanDangProgress.DU)):await finish();return
	await _choose(&"td_reconcile");hub.dialogue.confirm_button.grab_focus();await _key(KEY_ENTER);await _frames(4)
	_check(hub.npc_population.state.records[TanDangProgress.DU]["causality"]["reconciled"] and flow.profile.material_stash[&"linen_fiber"]==2,"Confirmed peace preserves used aid and its exact old balance")
	await mark("peace_committed",80);await _close_dialogue();await _journal_mark("peace_journal")
	await finish()

func finish() -> void:
	_release_motion()
	var data: Dictionary={"checks":checks,"failures":failures,"walked_distance":walked_distance,"walked_ticks":walked_ticks,"stages":stages,"scope":"Fresh save, actual continuous input/ordinary doors for full rescue/book story; cold load, confirmed aid, real starter melee/self-defense and spare; one declared defeat setup after actual portal E to exercise existing expedition recovery, no forged outcome/direct NPC heal. No inventory/gratitude/progression grants, no actor warps or forced poses. Muted; MovieMaker is not performance proof."}
	var file:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("movie.json"),FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
	if is_instance_valid(flow):flow.queue_free();current_scene=null;await _frames(8)
	await root.get_node("AudioManager").shutdown()
	print("RESULT Part4CausalityMovie checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
