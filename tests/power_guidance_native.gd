extends "res://tests/linked_gameplay_probe.gd"
const Labels=preload("res://scripts/cultivation/opening_cultivation_labels.gd")
var guidance_rows: Array[Dictionary]=[]
var initial_inventory: Dictionary={}
func show_power(label: String,notes: bool=false) -> Dictionary:
	_stage(label);await _key(KEY_M);await pause(.5)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	if screen.journal.selected_id!=PowerProgressionGuide.ID:await _click(screen.journal.power_button)
	await pause(.7)
	screen.journal.scroll_detail(-100000);await pause(.3)
	var row: Dictionary=PowerProgressionGuide.row(flow.profile,hub.gear.inventory)
	guidance_rows.append({"label":label,"row":row,"actor":flow.profile.cultivation_progress["actors"]["player"].duplicate(true)})
	_check(screen.journal.selected_id==PowerProgressionGuide.ID and screen.journal.guide_label.is_visible_in_tree(),"Real mission page shows the existing power route and visible guidance")
	await _shot(label);await pause(1.2)
	if notes:
		for index: int in 3:await _key(KEY_PAGEDOWN);await pause(.15)
		await _shot(label+"_sources");await pause(1.5)
		_check("Linh Thạch" in screen.journal.guide_label.text and "Tàn Hồn" in screen.journal.guide_label.text and "Tinh Thạch" in screen.journal.guide_label.text and "khác mana" in screen.journal.guide_label.text,"Visible notes distinguish money, souls, material and cultivation energy")
		screen.journal.scroll_detail(100000);await pause(.4)
		await _shot(label+"_wallets");await pause(1.8)
		_check(screen.journal.guide_label.get_global_rect().end.y<=screen.journal.detail_scroll.get_global_rect().end.y+2,"Scrolled capture includes the end of the visible resource legend")
	await _key(KEY_ESCAPE);await pause(.2)
	return row
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-item2" in OS.get_cmdline_user_args():quit(2);return
	native=true;root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("POWER_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("POWER_SOURCE_NPC"),"Starts from byte-identical actually earned item2 QA profile/NPC")
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	_check(realm()==0 and hub.gear.inventory.materials[&"crystal"]==4 and hub.gear.inventory.materials[&"dust"]==3 and not flow.qa_tools_enabled,"Inherited real stage zero and four carried crystals, no grants or state overrides")
	initial_inventory=GearInventoryCodec.encode(hub.gear.inventory);initial_wallets=Vector2i(flow.profile.coins,flow.profile.souls)
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	var before: Dictionary=await show_power("power_missing_training",true)
	_check(before["power"]["key"]==&"cultivation" and "thiếu" in before["card"]["prerequisite"] and "Luyện Khí I → Luyện Khí II" in before["power"]["current"],"Earned save exposes its actual next realm and missing cultivation energy")
	if not await open_training():await finish_power(false);return
	_stage("one_paid_training_session")
	await _click(hub.station_content.find_child("CultivationStartPlayer",true,false) as Button)
	for index: int in 600:
		if int(flow.profile.cultivation_progress["actors"]["player"]["energy"])>=8:break
		await _step(1)
	if not await open_training():await finish_power(false);return
	var stop: Button=hub.station_content.find_child("CultivationStop",true,false) as Button
	if stop!=null:await _click(stop);await pause(.3)
	_check(int(flow.profile.cultivation_progress["actors"]["player"]["energy"])==8 and hub.gear.inventory.materials[&"crystal"]==3,"One actual closed-panel training session pays exactly one crystal for eight cumulative energy")
	await _key(KEY_ESCAPE)
	var ready: Dictionary=await show_power("power_ready_for_first_stage")
	_check(Labels.breakthrough_action(0) in ready["card"]["action"] and "Đột phá" not in ready["card"]["action"],"Ready mission action names the actual first Tiến tầng button")
	if not await open_training():await finish_power(false);return
	var button: Button=hub.station_content.find_child("CultivationBreakthrough_player",true,false) as Button
	_check(button!=null and not button.disabled and button.text.begins_with(Labels.breakthrough_action(0)),"The offered station action has the same wording as the guidance")
	await _shot("power_actual_stage_button");await pause(1)
	await _click(button);await pause(.6)
	_check(realm()==1 and hub.gear.inventory.materials[&"crystal"]==3 and hub.gear.inventory.materials[&"dust"]==3,"Actual single-use transaction advances exactly one stage without invented material costs")
	_check(Vector2i(flow.profile.coins,flow.profile.souls)==initial_wallets,"Linh Thach and Tan Hon wallets are not spent by this zero-fee realm gate")
	await _key(KEY_ESCAPE)
	var after: Dictionary=await show_power("power_updated_after_real_stage",true)
	_check("Luyện Khí II → Luyện Khí III" in after["power"]["current"] and Labels.breakthrough_action(1) in after["card"]["action"] and "Tu vi tích lũy: 8" in after["power"]["guidance"],"Reopened UI reflects committed new realm, next action and earned energy")
	_check(GearInventoryCodec.encode(hub.gear.inventory)["items"]==initial_inventory["items"],"Training and realm progression preserve every existing item UID and attributes")
	await finish_power(true)
func finish_power(complete: bool) -> void:
	bot.stop();await pause(.3);var capture: Dictionary=recorder.finish()
	var result: Dictionary={"complete":complete and failures==0,"checks":checks,"failures":failures,"views":guidance_rows,"realm":realm(),"actor":flow.profile.cultivation_progress["actors"]["player"].duplicate(true),"inventory":GearInventoryCodec.encode(hub.gear.inventory),"coins":flow.profile.coins,"souls":flow.profile.souls,"profile_sha256":FileAccess.get_sha256(profile_path),"capture":{"wall_seconds":capture["wall_seconds"],"frames":capture["frames"].size(),"audio":capture["audio"]},"scope":"Earned item2 QA copy; real M/scroll/station UI, one paid training session and one existing stage transaction. No save/stat/loot/UID/HP/AI grants or overrides; no soundtrack change."}
	var f:=FileAccess.open(evidence.path_join("power-guidance-native.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT PowerGuidanceNative checks=%d failures=%d complete=%s"%[checks,failures,complete and failures==0]);quit(0 if complete and failures==0 else 1)
