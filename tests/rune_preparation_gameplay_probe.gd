extends "res://tests/shattered_mine_gameplay_probe.gd"
## Input-only extension of the already-earned mine route; no inventory/HP/AI overrides.
const Guide=preload("res://scripts/ui/rune_preparation.gd")
var quest_observations: Array[Dictionary]=[]
func observe_quest(label: String) -> void:
	var hub: PrologueHub=flow.active_scene as PrologueHub
	quest_observations.append({"label":label,"view":Guide.view(flow.profile,hub.gear.inventory,hub.rune_learning),"inventory":GearInventoryCodec.encode(hub.gear.inventory),"at_usec":Time.get_ticks_usec()})
func preparation_departure() -> bool:
	var hub: PrologueHub=flow.active_scene as PrologueHub
	_stage("Thanh_Vy_choose_optional_preparation")
	if not await _talk(hub,NpcCatalog.HEALER):return false
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_rune_preparation") as Button);await pause(.7)
	var panel: VBoxContainer=hub.station_content.get_node_or_null("RunePreparationPanel") as VBoxContainer
	if not _check(panel!=null and panel.get("last_view")["state"]=="choose_rune","Actual Thanh Vy opens optional guide without auto-selection"):return false
	var choice: OptionButton=panel.get("choice") as OptionButton
	await _click(choice);await pause(.3)
	var popup: PopupMenu=choice.get_popup()
	print("PREPARATION_MENU before embedded=%s focused=%d"%[popup.is_embedded(),popup.get_focused_item()])
	# Mouse-opened popup starts with focused=-1: first Down reaches the placeholder.
	for code: Key in [KEY_DOWN,KEY_DOWN,KEY_ENTER]:
		for down: bool in [true,false]:
			var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down;root.push_input(event,true);await _step(2)
		print("PREPARATION_MENU key=%d focused=%d selected=%d open=%s"%[code,popup.get_focused_item(),choice.selected,popup.visible])
	await pause(.6)
	if not _check(Guide.session(flow.profile)["selected"]==&"fire" and panel.get("last_view")["state"]=="already_prepared","Keyboard selection acknowledges existing earned Fire rune without requiring another craft"):return false
	observe_quest("already_owned_no_required_craft");await _shot("quest_owned_no_grind");await pause(1.2)
	await _click(panel.get("extra_button") as Button);await pause(.6)
	if not _check(panel.get("last_view")["state"]=="withdraw_materials" and panel.get("last_view")["sources"].contains("Mỏ Linh Thạch Vỡ"),"Explicit extra preparation acknowledges stash first and offers optional existing mine source"):return false
	observe_quest("explicit_extra_stash_or_mine");await _shot("quest_optional_mine_route");await pause(1.4)
	await _key(KEY_ESCAPE);await pause(.4)
	await show_sources("quest_shared_selection_in_M")
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	return _check(screen.journal.supply_board.get("preparation_panel").get("last_view")["selected"]==&"fire","M uses the same selection across closed hub panels")
func craft_from_bag() -> bool:
	var success: bool=await super.craft_from_bag()
	if not success:return false
	var hub: PrologueHub=flow.active_scene as PrologueHub
	if not _check(Guide.view(flow.profile,hub.gear.inventory,hub.rune_learning)["state"]=="crafted_this_session","Selected guide completes from actual paid craft callback after return"):return false
	observe_quest("actual_craft_saved")
	if not await _talk(hub,NpcCatalog.HEALER):return false
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_rune_preparation") as Button);await pause(.7)
	var panel: VBoxContainer=hub.station_content.get_node_or_null("RunePreparationPanel") as VBoxContainer
	if not _check(panel!=null and panel.get("last_view")["state"]=="crafted_this_session","Reopened NPC guide displays actual saved result and use step"):return false
	await _shot("quest_saved_use_at_hub");await pause(1.8);await _key(KEY_ESCAPE);await pause(.4)
	await _key(KEY_TAB);await pause(.7)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	var bar: TabBar=screen.tabs.get_tab_bar()
	var point: Vector2=bar.global_position+bar.get_tab_rect(3).get_center()
	for down: bool in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await _step(2)
	await pause(.7)
	if not _check(screen.is_open and screen.tabs.current_tab==3 and screen.carried_page.find_child("BagRune_fire",true,false)!=null,"Actual bag UI lists Fire after the normal saved craft"):return false
	await _shot("quest_real_bag_after_craft");await pause(1.8);await _key(KEY_ESCAPE);await pause(.3)
	return true
func finish_mine(complete: bool) -> void:
	var file:=FileAccess.open(evidence.path_join("rune-preparation-route.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete":complete,"failures":failures,"observations":quest_observations,"scope":"Input-only earned continuation; player already owns Fire, explicitly elects another paid craft. Stash alternative acknowledged; mine trip optional. No grants, HP, AI, damage, warp or RNG overrides."},"\t"));file.close()
	await super.finish_mine(complete)

func _run() -> void:
	native=DisplayServer.get_name()!="headless"
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or not native or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json";start_usec=Time.get_ticks_usec()
	if not _check(FileAccess.get_sha256(profile_path)==OS.get_environment("MINE_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("MINE_SOURCE_NPC"),"Exact earned source pair before prototype startup"):quit(2);return
	bot=CombatBot.new();root.add_child(bot)
	flow=preload("res://scenes/maps/shattered_mine_entry.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30)
	var hub: PrologueHub=flow.active_scene as PrologueHub
	if not _check(hub!=null and not flow.qa_tools_enabled and not flow.depth_expansion_enabled,"Standalone prototype uses ordinary hub owners and no production floor list"):await finish_mine(false);return
	starting_ledger=GearInventoryCodec.encode(hub.gear.inventory)
	_check(hub.gear.inventory.materials[&"dust"]==0 and hub.gear.inventory.materials[&"crystal"]==0,"Earned stash transfer leaves a genuine material need")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	if not await preparation_departure():await finish_mine(false);return
	_stage("prototype_departure_actual_portal");await _shot("prototype_hub")
	if not await _walk(hub.player,hub.stations[&"portal"].global_position.x):await finish_mine(false);return
	await _key(KEY_E);await _step(20)
	var run: DungeonRun=flow.active_scene as DungeonRun
	if not _check(run!=null and run.get_script().resource_path.ends_with("shattered_mine_run.gd") and not run.content.qa_tools_enabled,"Actual E enters the standalone mine using ordinary prepared inventory"):await finish_mine(false);return
	if not _check(not run.floor_exit.is_open and run.player.controls_enabled,"Portal E is not consumed again by the mine entrance return choice"):await finish_mine(false);return
	run.gear.loot.pickup_collected.connect(mine_pickup)
	for enemy: Node2D in run.living_enemies():enemy.hurtbox.hit_resolved.connect(hit_received)
	mine_position("entry");await _shot("mine_entry")
	_stage("walk_down_main_slope")
	if not await _walk(run.player,2000,1800):await finish_mine(false);return
	mine_position("lower_arena");await _shot("mine_lower_arena")
	_stage("ordinary_ground_combat");bot.run=run;bot.enabled=true
	for i: int in 7200:
		if run.outcome!=&"" or run.living_enemies().is_empty():break
		await _step(1)
	bot.stop();await _step(20)
	if not _check(run.outcome==&"" and run.player.health.current_health>0 and run.living_enemies().is_empty() and actual_enemy_hits>0,"Ordinary input combat clears existing live enemies without damage/HP/AI overrides"):await finish_mine(false);return
	mine_position("combat_cleared")
	_stage("walk_up_main_slope_to_lever")
	if not await _walk(run.player,4500,1800):await finish_mine(false);return
	mine_position("east_lever");await _shot("mine_east_lever")
	_check(not run.room.get("shortcut_open"),"Shortcut stays closed until the actual interaction")
	await _key(KEY_E);await pause(.5)
	if not _check(run.room.get("shortcut_open"),"Physical E at the lever opens the return bridge"):await finish_mine(false);return
	_stage("optional_resource_spur")
	if not await _walk(run.player,5020):await finish_mine(false);return
	await _key(KEY_E)
	await pause(1.5);mine_position("resource_spur");await _shot("mine_resource_spur")
	if not _check(mine_sources.size()==2 and mine_sources.any(func(v: Dictionary)->bool:return v["item"]=="dust" and v["quantity"]==2) and mine_sources.any(func(v: Dictionary)->bool:return v["item"]=="crystal" and v["quantity"]==1),"Both real mine sources physically enter the bag exactly once"):await finish_mine(false);return
	_stage("return_across_open_upper_shortcut")
	if not await _walk(run.player,2600,1800):await finish_mine(false);return
	mine_position("upper_bridge_midpoint");await _shot("mine_shortcut")
	if not _check(absf(run.player.global_position.y-360)<12,"Player actually stands on the upper return bridge above the lower arena"):await finish_mine(false);return
	if not await _walk(run.player,180,1800):await finish_mine(false);return
	mine_position("west_return");await _key(KEY_E);await pause(.5)
	if not _check(run.floor_exit.is_open,"Actual entrance E opens the return choice"):await finish_mine(false);return
	await _click(run.floor_exit.return_button);await _step(20)
	if not _check(flow.active_scene is PrologueHub,"Existing GameFlow banks carried materials and returns to the hub"):await finish_mine(false);return
	if not await craft_from_bag():await finish_mine(false);return
	await finish_mine(true)
