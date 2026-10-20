extends "res://tests/floor_supply_gameplay_probe.gd"
## Exact previously earned floor4/5 save. One normal floor5 replay, no fixture grants.
var floor_started_usec: int=0
var floor_done_usec: int=0
var source_profile: String=""
var source_npc: String=""
func show_sources(label: String) -> void:
	_stage(label);await _key(KEY_M);await pause(.4)
	var hub: ExteriorHub=flow.active_scene as ExteriorHub
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	if not screen.journal._supply_open:await _click(screen.journal.supply_button)
	await _step(5)
	var board: VBoxContainer=screen.journal.supply_board
	var scroll: ScrollContainer=board.get("scroll")
	var row: Dictionary=board.get("cells")[2]
	# Scroll the real page so the changed source is actually visible in the video.
	for i: int in 30:
		var area: Rect2=scroll.get_global_rect().grow(-5)
		if area.encloses((row["title"] as Label).get_global_rect()) and area.encloses((row["progress"] as Label).get_global_rect()):break
		var down: bool=(row["progress"] as Label).get_global_rect().end.y>area.end.y
		for pressed: bool in [true,false]:
			var wheel:=InputEventMouseButton.new();wheel.position=area.get_center();wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN if down else MOUSE_BUTTON_WHEEL_UP;wheel.pressed=pressed;root.push_input(wheel,true)
		await _step(3)
	var view: Dictionary=Supply.view(row["record"],flow.profile,hub.gear.inventory)
	_check(board.visible and scroll.get_global_rect().encloses((row["source"] as Label).get_global_rect()) and scroll.get_global_rect().encloses((row["progress"] as Label).get_global_rect()) and row["record"]["id"]==&"seal_moc_can_dust_v2" and (row["source"] as Label).text==view["source"] and (row["progress"] as Label).text==view["progress"],"Actual scrolled source page shows floor5 dust2 and the current carried deficit")
	await pause(1.2);await _shot(label);await _key(KEY_ESCAPE);await pause(.3)
func launch_existing() -> bool:
	supply_hub=flow.active_scene as ExteriorHub
	var guide: DepthGuide=supply_hub.get_node("DepthGuide") as DepthGuide
	_stage("choose_completed_floor5_in_existing_selector")
	if not await _walk(supply_hub.player,guide.npc.global_position.x):return false
	await _key(KEY_E);await pause(.4)
	if not _check(guide.opened and guide.floor_choice.item_count==2,"Earned floor history exposes exactly the two completed floors"):return false
	await _click(guide.floor_choice)
	var popup: PopupMenu=guide.floor_choice.get_popup()
	if not _check(popup.visible,"Actual completed-floor popup opens"):return false
	for i: int in 3:
		if popup.get_focused_item()==1:break
		await _key(KEY_DOWN)
	await _key(KEY_ENTER);await pause(.5)
	if not _check(guide.selected_floor==2 and guide.action.text.contains("tầng 5"),"Ordinary selector input chooses existing floor5 shortcut"):return false
	await _click(guide.action);await _step(16)
	floor_started_usec=Time.get_ticks_usec()
	return _check(flow.active_scene is DepthCampaign and flow.active_scene.room_number==2,"Normal departure enters only floor5, without replaying floor4")
func fight_floor(number: int) -> bool:
	var done: bool=await super.fight_floor(number)
	floor_done_usec=Time.get_ticks_usec()
	_check(acquired.any(func(row: Dictionary)->bool:return row["id"]=="seal_moc_can_crystal" and row["quantity"]==1) and acquired.any(func(row: Dictionary)->bool:return row["id"]=="seal_moc_can_dust_v2" and row["quantity"]==2),"Both physical floor5 supplements reach the carried bag")
	return done and failures==0
func _run() -> void:
	native=DisplayServer.get_name()!="headless"
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or not native or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json";start_usec=Time.get_ticks_usec()
	source_profile=OS.get_environment("MINE_SOURCE_PROFILE");source_npc=OS.get_environment("MINE_SOURCE_NPC")
	if not _check(not source_profile.is_empty() and FileAccess.get_sha256(profile_path)==source_profile and FileAccess.get_sha256(profile_path+".npc_v1.json")==source_npc,"Exact earned preparation profile/NPC bytes before startup"):quit(2);return
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30)
	supply_hub=flow.active_scene as ExteriorHub
	_check(not flow.qa_tools_enabled and flow.depth_progress.can_start_floor(2),"Actual earned completion enables floor5 replay")
	_check(Supply.VERSION==2 and supply_hub.gear.inventory.materials[&"dust"]==0 and supply_hub.gear.inventory.materials[&"crystal"]==0,"Version2 begins with genuine empty material bag after prior stash transfer")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	await show_sources("floor5_material_sources_before_departure");route_snapshot("departure")
	if not await launch_existing():await finish_supply(false);return
	if not await fight_floor(2):await finish_supply(false);return
	route_snapshot("returned_from_one_floor5")
	await show_sources("floor5_materials_ready_after_return")
	if not await craft_from_bag():await finish_supply(false);return
	await finish_supply(true)
func finish_supply(complete: bool) -> void:
	var file:=FileAccess.open(evidence.path_join("balance-native.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete":complete,"checks":checks,"failures":failures,"version":Supply.VERSION,"source_profile":source_profile,"source_npc":source_npc,"acquired":acquired,"snapshots":route_snapshots,"craft":craft_result,"native_floor5_enter_to_hub_seconds":float(floor_done_usec-floor_started_usec)/1000000.0 if floor_done_usec>floor_started_usec and floor_started_usec>0 else -1,"scope":"Input-only exact earned preparation: bag starts dust0/crystal0 from prior real stash transfer; M source board, physical LacAn selector to completed floor5, real4Bat combat/pickup/return/ThanhVy confirmation craft. No seed/stat/HP/AI/warp/grant overrides. One routebot sample, not human farm-speed or FPS benchmark."},"\t"));file.close()
	await super.finish_supply(complete)
