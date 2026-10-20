extends "res://tests/newcomer_route_probe.gd"
## Actual item3 earned save and ordinary story inputs. No synthetic branch state.
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
var hub: ExteriorHub
var snapshots: Array[Dictionary]=[]
var spoken: Array[Dictionary]=[]
var initial_inventory: String
var initial_money: Vector2i
var initial_stash: Dictionary

func snapshot(label: String) -> void:
	snapshots.append({"label":label,"quest":hub.tan_dang.progress.state(),"coins":flow.profile.coins,"souls":flow.profile.souls,"stash":flow.profile.material_stash.duplicate(),"inventory":GearInventoryCodec.encode(hub.gear.inventory),"npc":hub.npc_population.state.records.duplicate(true)})

func read_dialogue(label: String,linger: bool=false) -> bool:
	if not _check(hub.dialogue.is_open,"Actual story dialogue is open: "+label):return false
	_stage(label)
	spoken.append({"label":label,"speaker":hub.dialogue.speaker_label.text,"pages":hub.dialogue.pages.duplicate(),"context":String(hub.tan_dang.context)})
	for i: int in 30:
		if hub.dialogue.is_typing():await _key(KEY_E)
		await pause(1.6 if linger and hub.dialogue.page_index<2 else .2)
		if linger and hub.dialogue.page_index<2:await _shot(label+"_page%d"%hub.dialogue.page_index)
		if hub.dialogue.page_index==hub.dialogue.pages.size()-1:
			await pause(.3);return true
		await _key(KEY_E)
	return _check(false,"Dialogue pages finish within bounded actual E inputs")

func close_dialogue() -> void:
	if hub.dialogue.is_open:await _key(KEY_ESCAPE);await _step(5)

func interact_story(id: StringName,label: String,linger: bool=false) -> bool:
	await close_dialogue()
	for i: int in 5:
		var x: float=NAN
		if hub.npc_population.actors.has(String(id)):x=hub.npc_population.actors[String(id)].global_position.x
		elif not hub.outside and hub.stations.has(id):x=hub.stations[id].global_position.x
		elif hub.outside and hub.exterior.interactions.has(id):x=(ExteriorHub.ORIGIN+hub.exterior.interactions[id]).x
		if not _check(is_finite(x),"Authored physical story interaction exists: "+String(id)):return false
		if not await _walk(hub.player,x):return false
		await _step(5)
		if hub.nearest_station()==id:break
	if not _check(hub.nearest_station()==id,"Ordinary walking reaches the exact nearest story speaker/object: "+String(id)):return false
	await _key(KEY_E)
	return await read_dialogue(label,linger)

func choose(action: String,label: String="") -> bool:
	var button: Button=hub.dialogue.choice_list.get_node_or_null("Choice_td_"+action) as Button
	if not _check(button!=null,"Actual canonical choice exists: "+action):return false
	await _click(button);await pause(.5)
	if hub.dialogue.pending_choice!=&"":return true
	return await read_dialogue(label if not label.is_empty() else "after_"+action)

func travel(id: StringName,destination: StringName) -> bool:
	await close_dialogue()
	var x: float=(ExteriorHub.ORIGIN+hub.exterior.interactions[id]).x if hub.outside else hub.stations[id].global_position.x
	if not await _walk(hub.player,x):return false
	await _step(5)
	if not _check(hub.nearest_station()==id,"Physical authored door is nearest: "+String(id)):return false
	await _key(KEY_E);await _step(12)
	return _check((hub.exterior.room_id if hub.outside else ExteriorRouteCatalog.HUB)==destination,"Ordinary E travel reaches "+String(destination))

func journal(id: StringName,label: String) -> void:
	await close_dialogue();_stage(label);await _key(KEY_M);await pause(.7)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	if id==&"tan_dang_relations":await _click(screen.journal.relations_button)
	else:
		if screen.journal.selected_id==PowerProgressionGuide.ID:await _click(screen.journal.power_button);await pause(.3)
		await _click(screen.journal.quest_buttons.get(id) as Button)
	await pause(2);_check(screen.journal.selected_id==id,"Actual M screen selects the current quest/relationship journal")
	await _shot(label)
	for i: int in 4:await _key(KEY_PAGEDOWN);await pause(.12)
	await pause(1.4);await _shot(label+"_details");await _key(KEY_ESCAPE);snapshot(label)

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-item3" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("STORY_SOURCE_SHA256"),"Starts from exact byte-identical earned item3 save")
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	_check(not flow.qa_tools_enabled and not hub.tan_dang.progress.state()["accepted"] and FoundationResonance.unlocked(flow.profile),"Earned Truc Co save has not started this optional story, no injected story state")
	initial_inventory=Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory));initial_money=Vector2i(flow.profile.coins,flow.profile.souls);initial_stash=flow.profile.material_stash.duplicate()
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	if not await interact_story(StringName(TanDangProgress.MOC),"moc_why_the_gate_matters",true) or not await choose("accept"):await finish_game(false);return
	if not await interact_story(TanDangJourney.LAMP,"inspect_missing_core",true) or not await choose("observe_lamp"):await finish_game(false);return
	if not await travel(&"exterior_road",&"o01_p01") or not await travel(&"door_east",&"o01_p02") or not await travel(&"door_east",&"o01_p03"):await finish_game(false);return
	if not await interact_story(StringName(TanDangProgress.LAM),"lam_why_he_took_the_core",true) or not await choose("find_lam"):await finish_game(false);return
	if not await interact_story(StringName(TanDangProgress.DU),"du_accepts_his_part",true) or not await choose("inspect_core") or not await choose("q1_reward"):await finish_game(false);return
	_check(hub.tan_dang.progress.state()["contribution"]==2 and hub.tan_dang.progress.state()["discoveries"].size()==3,"Canonical evidence through both living speakers earns exactly q1 once")
	if not await interact_story(TanDangJourney.REFUGE,"one_core_two_promises",true):await finish_game(false);return
	var profile_before: PackedByteArray=FileAccess.get_file_as_bytes(profile_path);var npc_before: PackedByteArray=FileAccess.get_file_as_bytes(profile_path+".npc_v1.json")
	if not await choose("choice_rescue"):await finish_game(false);return
	_check(hub.dialogue.pending_choice==&"td_choice_rescue" and hub.tan_dang.progress.state()["choice"]=="","Real irreversible story choice waits for confirmation")
	_stage("cancel_then_confirm_rescue");await pause(2);await _shot("rescue_confirmation")
	await _click(hub.dialogue.cancel_button);await pause(.5)
	_check(FileAccess.get_file_as_bytes(profile_path)==profile_before and FileAccess.get_file_as_bytes(profile_path+".npc_v1.json")==npc_before and hub.tan_dang.progress.state()["choice"]=="","Actual cancel keeps both authoritative files and all story/currency/items unchanged")
	if not await choose("choice_rescue"):await finish_game(false);return
	await _click(hub.dialogue.confirm_button);await pause(.5)
	_check(hub.tan_dang.progress.state()["choice"]=="rescue" and hub.tan_dang.progress.state()["core"]=="spent" and hub.tan_dang.progress.alive(TanDangProgress.DU) and hub.tan_dang.progress.state()["contribution"]==4,"Confirmed rescue consumes the one core, keeps Du alive and pays q2 exactly once")
	await read_dialogue("committed_rescue",true);await journal(&"tan_dang_q2","journal_remembers_the_choice")
	if not await travel(&"door_west",&"o01_p02") or not await travel(&"door_west",&"o01_p01") or not await travel(&"door_west",ExteriorRouteCatalog.HUB):await finish_game(false);return
	_check(hub.tan_dang.progress.state()["lamp"]=="broken" and hub.npc_population.actors.has(TanDangProgress.LAM) and hub.npc_population.actors.has(TanDangProgress.DU),"Normal return shows gate damage and the actual saved people at home")
	if not await interact_story(StringName(TanDangProgress.MOC),"moc_counts_the_cost",true) or not await choose("report_moc"):await finish_game(false);return
	if not await interact_story(StringName(TanDangProgress.LAM),"lam_stays_to_answer",true) or not await choose("report_lam") or not await choose("q3_reward"):await finish_game(false);return
	_check(hub.tan_dang.progress.state()["contribution"]==6 and hub.tan_dang.progress.state()["rewards"]==["q1","q2","q3"],"Three finite story rewards pay exactly six contribution")
	if not await choose("recipe"):await finish_game(false);return
	_check(hub.dialogue.pending_choice==&"td_recipe" and hub.tan_dang.progress.known_recipe(),"Existing self-discovered Firestorm is acknowledged without a new purchase")
	await _click(hub.dialogue.confirm_button);await pause(.4);await read_dialogue("existing_recipe_is_free")
	_check(hub.tan_dang.progress.state()["recipe_claimed"] and not hub.tan_dang.progress.state()["recipe_paid"] and hub.tan_dang.progress.state()["contribution"]==6,"Known recipe receipt consumes zero contribution and never duplicates knowledge")
	if not await choose("support") or not await choose("decline"):await finish_game(false);return
	_check(hub.tan_dang.progress.state()["membership"]=="guest" and hub.tan_dang.progress.state()["declined"] and FoundationResonance.unlocked(flow.profile),"Guest keeps full progression; support does not reset or grant another breakthrough")
	if not await interact_story(StringName(TanDangProgress.DU),"saved_du_remembers_you",true):await finish_game(false);return
	var linen: int=flow.profile.material_stash[&"linen_fiber"];profile_before=FileAccess.get_file_as_bytes(profile_path);npc_before=FileAccess.get_file_as_bytes(profile_path+".npc_v1.json")
	if not await choose("assist"):await finish_game(false);return
	_check(hub.dialogue.pending_choice==&"td_assist" and flow.profile.material_stash[&"linen_fiber"]==linen,"Actual aid is an offer, not an early preview grant")
	_stage("cancel_then_accept_real_aid");await pause(2);await _shot("aid_confirmation")
	await _click(hub.dialogue.cancel_button);await pause(.5)
	_check(FileAccess.get_file_as_bytes(profile_path)==profile_before and FileAccess.get_file_as_bytes(profile_path+".npc_v1.json")==npc_before and not hub.npc_population.state.karma(TanDangProgress.DU)["assistance_used"],"Cancel preserves exact profile/NPC bytes and the one lifetime aid opportunity")
	if not await choose("assist"):await finish_game(false);return
	await _click(hub.dialogue.confirm_button);await pause(.4);await read_dialogue("du_keeps_his_word",true)
	_check(flow.profile.material_stash[&"linen_fiber"]==linen+2 and hub.npc_population.state.karma(TanDangProgress.DU)["assistance_used"],"Only the committed real aid sends existing two linen to stash once")
	if not await interact_story(StringName(TanDangProgress.DU),"du_after_the_gift",true):await finish_game(false);return
	_check(not hub.tan_dang.offered.has(&"td_assist"),"Meeting the saved person again cannot offer a second lifetime gift")
	await journal(&"tan_dang_relations","journal_relationship_memory");await journal(&"tan_dang_q3","journal_completed_and_next_step")
	_check(Writer.canonical(GearInventoryCodec.encode(hub.gear.inventory))==initial_inventory and Vector2i(flow.profile.coins,flow.profile.souls)==initial_money,"Story travel and aid preserve all carried UIDs/affixes/slots/materials and both wallets")
	var expected_stash: Dictionary=initial_stash.duplicate();expected_stash[&"linen_fiber"]=int(expected_stash[&"linen_fiber"])+2
	_check(flow.profile.material_stash==expected_stash,"Only the existing two-linen aid changes stored materials")
	for id: String in TanDangProgress.NPC_IDS:_check(hub.tan_dang.progress.alive(id) and not hub.npc_population.state.records[id]["causality"]["harmed"],"Natural rescue route introduces no fabricated injury/death: "+id)
	await finish_game(true)

func finish_game(complete: bool) -> void:
	bot.stop();await close_dialogue();await pause(.3);snapshot("final")
	var capture: Dictionary=recorder.finish()
	var state: Dictionary={"checks":checks,"failures":failures,"complete":complete,"source_profile_sha256":OS.get_environment("STORY_SOURCE_SHA256"),"profile_path":ProjectSettings.globalize_path(profile_path),"snapshots":snapshots,"spoken":spoken,"capture":{"wall_seconds":capture["wall_seconds"],"frames":capture["frames"].size(),"audio":capture["audio"]},"scope":"Actual item3 earned save; normal real-time viewport walking/doors/E/dialogue/confirmation/journal inputs. Rescue branch only; hard branches tested separately as explicit fixtures. No grants/unlocks/warps/HP/damage/RNG/story-state fixtures. QA automation, not human research."}
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	state["profile_sha256"]=FileAccess.get_sha256(profile_path);state["npc_sha256"]=FileAccess.get_sha256(profile_path+".npc_v1.json")
	var file:=FileAccess.open(evidence.path_join("story-route.json"),FileAccess.WRITE);file.store_string(JSON.stringify(state,"\t",true,true));file.close()
	print("RESULT StoryGameplay checks=%d failures=%d complete=%s wall=%.3f"%[checks,failures,complete,capture["wall_seconds"]]);quit(0 if complete and failures==0 else 1)
