extends "res://tests/newcomer_route_probe.gd"
## Input-only earned H7 continuation. Preparation earns historical floor clears;
## final route cold-loads that exact pair and revisits both floors before crafting.
const Supply=preload("res://data/floor_supply_catalog.gd")
var preparation: bool=false
var supply_hub: ExteriorHub
var acquired: Array[Dictionary]=[]
var route_snapshots: Array[Dictionary]=[]
var actual_enemy_hits: int=0
var craft_result: Dictionary={}
func route_snapshot(label: String) -> void:
	var inv: GearInventory=flow.active_scene.get("gear").inventory
	route_snapshots.append({"label":label,"profile_coins":flow.profile.coins,"inventory":GearInventoryCodec.encode(inv),"depth":flow.depth_progress.state(),"hp":flow.active_scene.get("player").health.current_health})
func pickup_received(pickup: LootPickup) -> void:
	if not pickup.has_meta(&"floor_supply_source"):return
	var dungeon: DepthCampaign=flow.active_scene as DepthCampaign
	acquired.append({"id":String(pickup.get_meta(&"floor_supply_source")),"item":String(pickup.item_id),"quantity":pickup.quantity,"floor":dungeon.global_floor_number(),"inventory":dungeon.gear.inventory.materials.duplicate(),"at_usec":Time.get_ticks_usec()})
func hit_received(_event: DamageEvent,result: DamageResult) -> void:
	if not result.blocked and result.actual_damage>0:actual_enemy_hits+=1
func launch_existing() -> bool:
	supply_hub=flow.active_scene as ExteriorHub
	var guide: DepthGuide=supply_hub.get_node("DepthGuide") as DepthGuide
	if not await _walk(supply_hub.player,guide.npc.global_position.x):return false
	await _key(KEY_E);await pause(.5)
	if not _check(guide.opened,"Physical E opens the existing Lạc Ấn floor selector"):return false
	if not flow.depth_progress.state()["accepted"]:
		await _click(guide.action);await pause(.6)
		if not _check(flow.depth_progress.state()["accepted"],"Existing UI accepts and saves the depth map"):return false
	if not preparation and not _check(guide.floor_choice.item_count>=2 and flow.depth_progress.can_start_floor(2),"Cold earned history offers both previously completed floors"):return false
	await _click(guide.action);await _step(16)
	return _check(flow.active_scene is DepthCampaign and not flow.active_scene.is_opening_segment() and flow.active_scene.room_number==1,"Actual selected shortcut enters existing floor4")
func fight_floor(number: int) -> bool:
	var dungeon: DepthCampaign=flow.active_scene as DepthCampaign
	if not _check(dungeon!=null and dungeon.room_number==number and not dungeon.content.qa_tools_enabled,"Normal floor and QA tools disabled"):return false
	if not dungeon.gear.loot.pickup_collected.is_connected(pickup_received):dungeon.gear.loot.pickup_collected.connect(pickup_received)
	for enemy: Node2D in dungeon.living_enemies():enemy.hurtbox.hit_resolved.connect(hit_received)
	bot.run=dungeon;bot.enabled=true;_stage(("earn" if preparation else "revisit")+"_floor_%d_actual_combat"%(number+3))
	for i: int in 10800:
		if not is_instance_valid(dungeon) or dungeon.outcome!=&"" or (not dungeon.room.locked and dungeon.living_enemies().is_empty()):break
		await _step(1)
	bot.stop()
	if not _check(is_instance_valid(dungeon) and dungeon.outcome==&"" and dungeon.player.health.current_health>0 and not dungeon.room.locked,"Actual floor combat cleared using ordinary move/jump/dash/attack/spell inputs"):return false
	_stage("pick_guaranteed_floor_%d"%(number+3))
	var source: Dictionary=Supply.sources_for_floor(number)[0]
	if not acquired.any(func(row: Dictionary)->bool:return row["id"]==String(source["id"])):
		if not await _walk(dungeon.player,Supply.drop_point(number).x):return false
		await pause(.9)
	if not _check(acquired.any(func(row: Dictionary)->bool:return row["id"]==String(source["id"]) and row["quantity"]==source["quantity"]),"Guaranteed source is physically collected into the actual bag"):return false
	route_snapshot("collected_floor_%d"%(number+3))
	if native:await _shot("collected_floor_%d"%(number+3))
	if not await _walk(dungeon.player,DepthFloorCatalog.exit_point(number).x+4):return false
	await _key(KEY_E);await pause(.5)
	if not _check(dungeon.floor_exit.is_open,"Physical E opens the normal completed-floor exit"):return false
	await _click(dungeon.floor_exit.continue_button if number==1 else dungeon.floor_exit.return_button);await _step(18)
	return _check(flow.active_scene is DepthCampaign and flow.active_scene.room_number==2,"Existing continue choice advances to floor5") if number==1 else _check(flow.active_scene is ExteriorHub,"Existing return choice banks carried loot at the hub")
func show_sources(label: String) -> void:
	_stage(label);await _key(KEY_M);await pause(.4)
	var screen: InventoryScreen=(flow.active_scene as PrologueHub).gear.modal as InventoryScreen
	if not screen.journal._supply_open:await _click(screen.journal.supply_button)
	await pause(1.2)
	_check(screen.journal._supply_open and screen.journal.supply_board.visible,"Actual M toggle displays the separate source page")
	if native:await _shot(label)
	await _key(KEY_ESCAPE);await pause(.3)
func deposit_preparation() -> bool:
	supply_hub=flow.active_scene as ExteriorHub;_stage("prepare_empty_material_bag_through_existing_stash")
	if not await _walk(supply_hub.player,supply_hub.stations[&"stash"].global_position.x):return false
	await _key(KEY_E);await pause(.7)
	if not _check(supply_hub.station_open and supply_hub.current_station==&"stash","Actual E opens the existing stash service"):return false
	await _click(supply_hub.station_content.find_child("DepositAllMaterials",true,false) as Button);await pause(.7)
	var inv: GearInventory=supply_hub.gear.inventory
	if not _check(inv.materials[&"dust"]==0 and inv.materials[&"crystal"]==0,"Normal stash transfer creates a genuine material shortfall without deleting items"):return false
	await _key(KEY_ESCAPE);return true
func craft_from_bag() -> bool:
	supply_hub=flow.active_scene as ExteriorHub;_stage("return_to_Thanh_Vy_and_craft")
	if not await _talk(supply_hub,NpcCatalog.HEALER):return false
	await _click(supply_hub.dialogue.choice_list.get_node_or_null("Choice_rune_learning") as Button);await pause(.6)
	var inv: GearInventory=supply_hub.gear.inventory
	if not _check(supply_hub.station_open and supply_hub.current_station==&"rune_learning" and supply_hub.rune_learning.quote(&"fire")["can_craft"],"Actual Thanh Vy service can craft the genuinely learned Fire rune"):return false
	var previous: Dictionary=GearInventoryCodec.encode(inv);var ids: Array=inv.items.keys();var count: int=inv.bag[&"fire"]
	await _click(supply_hub.station_content.find_child("RuneService_fire",true,false) as Button);await pause(.5)
	var confirm: Button=supply_hub.station_content.find_child("ConfirmPurchase",true,false) as Button
	if not _check(confirm!=null and inv.bag[&"fire"]==count,"Existing confirmation does not consume or grant early"):return false
	await _click(confirm);await pause(.8)
	var added: Array=inv.items.keys().filter(func(uid: int)->bool:return not ids.has(uid))
	craft_result={"before":previous,"after":GearInventoryCodec.encode(inv),"new_uids":added}
	for id: StringName in RuneLearningService.CRAFT_COST:
		_check(inv.materials[id]==int(previous["materials"][String(id)])-RuneLearningService.CRAFT_COST[id],"Existing craft consumes its exact real cost:"+String(id))
	_check(added.size()==1 and inv.items[added[0]].kind==&"rune" and inv.items[added[0]].definition_id==&"fire" and inv.items[added[0]].source==&"crafted" and inv.bag[&"fire"]==count+1,"One useful owned Fire rune publishes with a new unique UID")
	if native:await _shot("actual_crafted_rune_and_material_costs")
	await _key(KEY_ESCAPE);await pause(.7);return true
func _run() -> void:
	preparation="--prepare" in OS.get_cmdline_user_args();native=DisplayServer.get_name()!="headless"
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or not native or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json";start_usec=Time.get_ticks_usec()
	var expected: String=OS.get_environment("FOLLOWUP_SOURCE_PROFILE") if preparation else OS.get_environment("REVISIT_SOURCE_PROFILE")
	var expected_npc: String=OS.get_environment("FOLLOWUP_SOURCE_NPC") if preparation else OS.get_environment("REVISIT_SOURCE_NPC")
	if not _check(not expected.is_empty() and FileAccess.get_sha256(profile_path)==expected and FileAccess.get_sha256(profile_path+".npc_v1.json")==expected_npc,"Exact prior earned QA profile/NPC pair before product startup"):quit(2);return
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30)
	if not _check(not flow.qa_tools_enabled and flow.profile.opening_progress["completed"].has("golem_defeated"),"Earned opening proof and ordinary product flow, no grants"):await finish_supply(false);return
	if not preparation:
		if not _check(flow.depth_progress.can_start_floor(1) and flow.depth_progress.can_start_floor(2),"Both floors were genuinely completed in the preparation route"):await finish_supply(false);return
		var inv: GearInventory=flow.active_scene.get("gear").inventory
		_check(inv.materials[&"dust"]==0 and inv.materials[&"crystal"]==0,"Prepared stash transfer persists the real material need")
		recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
		await show_sources("know_material_need_and_two_floor_sources")
	route_snapshot("departure")
	if not await launch_existing():await finish_supply(false);return
	if not await fight_floor(1):await finish_supply(false);return
	if not await fight_floor(2):await finish_supply(false);return
	route_snapshot("returned_with_source_materials")
	if preparation:
		if not await deposit_preparation():await finish_supply(false);return
	else:
		await show_sources("returned_material_progress")
		if not await craft_from_bag():await finish_supply(false);return
	await finish_supply(true)
func finish_supply(complete: bool) -> void:
	bot.stop();var cap: Dictionary={}
	if is_instance_valid(recorder):await pause(.5);cap=recorder.finish()
	var profile_sha: String=FileAccess.get_sha256(profile_path);var npc_sha: String=FileAccess.get_sha256(profile_path+".npc_v1.json")
	var result: Dictionary={"complete":complete,"prepare":preparation,"checks":checks,"failures":failures,"profile_sha256":profile_sha,"npc_sha256":npc_sha,"acquired":acquired,"enemy_hits":actual_enemy_hits,"snapshots":route_snapshots,"craft":craft_result,"capture":cap,"scope":"Input-only continuation of earned H7; preparation earns floors4/5 and deposits materials through actual UI. Final cold route uses ordinary selector, fights, physical source pickups, normal return and Thanh Vy craft. No HP/damage/AI/warp/RNG/grant overrides. Not a playtest or balance/strict-gate claim."}
	var file:=FileAccess.open(evidence.path_join("floor-revisit-route.json"),FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	bot.queue_free();flow.queue_free()
	if is_instance_valid(recorder):recorder.queue_free()
	current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT FloorRevisit checks=%d failures=%d complete=%s prepare=%s"%[checks,failures,complete,preparation]);quit(0 if complete and failures==0 else 1)
