extends SceneTree
## Explicit synthetic/history fixtures exercise real canonical flow and transactions.
## Product footage is a separate input-only route from an earned QA profile.
const Catalog=preload("res://data/floor_supply_catalog.gd")
var flow: GameFlow
var checks: int=0
var failures: int=0
var path: String="user://floor-supply-fixture/profile.json"
func _initialize() -> void:call_deferred("run")
func step(n: int) -> void:
	for i: int in n:await physics_frame;await process_frame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+message)
func open_flow() -> void:
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=path;root.add_child(flow);current_scene=flow;await step(12)
func close_flow() -> void:
	flow.queue_free();current_scene=null;await step(8)
func sources(run_scene: DepthCampaign) -> Array[Node]:
	return run_scene.gear.loot.get_children().filter(func(n: Node)->bool:return n.has_meta(&"floor_supply_source"))
func fixture_run(run_scene: DepthCampaign) -> void:
	run_scene.feedback.hit_stop_seconds=0;run_scene.feedback.enable_global_hitstop(false);run_scene.survival.set_enabled(false);run_scene.player.health.minimum_health=1
	run_scene.gear.loot.drop_table=run_scene.gear.loot.drop_table.duplicate(true);run_scene.gear.loot.drop_table.none_chance=1;run_scene.gear.loot.drop_table.blueprint_chance_total=0
	for enemy: Node2D in run_scene.living_enemies():enemy.set("ai_enabled",false)
func clear_fixture(run_scene: DepthCampaign) -> void:
	for enemy: Node2D in run_scene.living_enemies():enemy.health.apply_damage(99999)
	await step(10)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	root.unfocusable=true;Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	var ids: Array[StringName]=[]
	check(Catalog.VERSION==2 and Catalog.SOURCES.size()==3,"Version2 has three sources on existing floors4/5")
	for source: Dictionary in Catalog.SOURCES:
		check(not ids.has(source["id"]) and source["id"]!=&"","Stable unique source IDs");ids.append(source["id"])
		check(source["floor_id"]==DepthFloorCatalog.floor_data(source["floor"])["id"] and source["global_floor"]==source["floor"]+3,"Source names/identities use the actual existing floor catalog")
		check(source["chance"]==1.0 and not source["exclusive"] and source["item"] in MaterialCatalog.IDS,"Guaranteed non-exclusive existing useful item")
		check(source["quantity"]==RuneLearningService.CRAFT_COST[source["item"]],"Each source quantity complete one existing rune craft")
	check(Catalog.sources_for_floor(999).is_empty() and Catalog.sources_for_floor(3).is_empty(),"No accidental extra floor grants")
	var copy: Array[Dictionary]=Catalog.sources_for_floor(1);copy[0]["quantity"]=999
	check(Catalog.SOURCES[0]["quantity"]==2,"Callers cannot mutate shared source data")
	await open_flow()
	var hub: PrologueHub=flow.active_scene as PrologueHub
	var view: Dictionary=Catalog.view(Catalog.SOURCES[0],flow.profile,hub.gear.inventory)
	check(not view["can_revisit"] and view["unlock"].contains("Golem"),"Board reads the existing Golem gate")
	check(not flow.start_depth_campaign(1),"Guide does not bypass opening unlock")
	check(flow.profile.record_boss_defeat("floor_supply_history_fixture"),"Explicit fixture: historical opening proof via owner")
	check(flow.depth_progress.accept(),"Existing accepted journey transaction")
	for number: int in [1,2]:check(flow.depth_progress.record(StringName("depth_floor_%d"%number),number),"Explicit fixture: historical cleared floor")
	flow.profile.souls=100;check(flow.profile.save(),"Explicit fixture wallet saved for existing rune learning")
	check(hub.rune_learning.learn(&"fire"),"Learn through existing transaction; no new knowledge owner")
	check(flow.start_depth_campaign(1),"Existing shortcut starts a previously cleared floor")
	var dungeon: DepthCampaign=flow.active_scene as DepthCampaign;fixture_run(dungeon)
	dungeon.gear.loot.maximum_pickups=1
	var blocker: LootPickup=dungeon.gear.loot.spawn(&"material",&"metal",Vector2(900,100));blocker.automatic=false
	await clear_fixture(dungeon)
	check(sources(dungeon).is_empty() and not dungeon._supply_sources_issued.has(&"seal_van_thach_dust"),"Capacity refusal does not consume the guaranteed source")
	check(not dungeon.room.locked and not dungeon.has_pending_rewards(),"Optional source allocation cannot lock door or return")
	check(blocker.collect(),"Existing pickup collection frees a real budget slot")
	await step(5)
	check(sources(dungeon).size()==1,"Source retry waits for queued deletion and respects the pickup cap")
	var pickup: LootPickup=sources(dungeon)[0] as LootPickup;pickup.automatic=false
	check(pickup.item_id==Catalog.SOURCES[0]["item"] and pickup.quantity==Catalog.SOURCES[0]["quantity"],"Runtime drop matches the board's single source contract")
	dungeon._check_clear();dungeon._try_supply_sources();await step(3)
	check(sources(dungeon).size()==1,"Repeated clear callbacks cannot duplicate the same source")
	dungeon.gear.inventory.materials[&"dust"]=MaterialCatalog.MAX_COUNT
	check(not pickup.collect() and not pickup.collected_once and is_instance_valid(pickup),"Full material stack rejects collection without consuming source")
	check(not dungeon.room.locked and not dungeon.has_pending_rewards(),"Full material stack does not trap the player")
	dungeon.gear.inventory.materials[&"dust"]=0
	while dungeon.gear.inventory.equipment_bag_uids().size()<GearInventory.EQUIPMENT_BAG_CAPACITY:dungeon.gear.inventory.add_item(&"weapon",&"ancient_sword")
	check(pickup.collect() and dungeon.gear.inventory.materials[&"dust"]==2,"A full equipment bag does not incorrectly block a material stack")
	check(not pickup.collect(),"Same pickup cannot apply twice before free")
	await step(4)
	check(dungeon.enter_room(1),"Room can be rebuilt within the same expedition")
	fixture_run(dungeon);await clear_fixture(dungeon)
	check(sources(dungeon).is_empty(),"Rebuilding and clearing the same room does not reissue its source")
	check(dungeon.enter_room(2),"Existing next floor remains reachable")
	fixture_run(dungeon);dungeon.gear.loot.maximum_pickups=1;await clear_fixture(dungeon)
	check(sources(dungeon).size()==1 and not dungeon._supply_sources_issued.has(&"seal_moc_can_dust_v2"),"Floor5 first source respects cap1 and leaves second eligible")
	pickup=sources(dungeon)[0] as LootPickup;pickup.automatic=false
	var old_crystal: int=dungeon.gear.inventory.materials[&"crystal"]
	check(pickup.collect() and dungeon.gear.inventory.materials[&"crystal"]==old_crystal+1,"Second source adds one crystal into carried inventory")
	await step(3)
	check(sources(dungeon).size()==1 and sources(dungeon)[0].item_id==&"dust","After crystal collection floor5 retries the second source under cap1")
	pickup=sources(dungeon)[0] as LootPickup;pickup.automatic=false
	check(pickup.quantity==2 and pickup.collect() and dungeon.gear.inventory.materials[&"dust"]==4,"Floor5 dust2 supplements the previously carried floor4 dust2")
	await step(3);dungeon._try_supply_sources();await step(2)
	check(sources(dungeon).is_empty(),"Both floor5 source receipts suppress duplicate callbacks")
	var bag: Dictionary=GearInventoryCodec.encode(dungeon.gear.inventory)
	var before: PackedByteArray=FileAccess.get_file_as_bytes(path)
	dungeon.outcome=&"retreat" # Explicit return fixture; product route uses the E panel.
	flow.profile._writer.fault_plan={"write_candidate":true}
	check(not flow.show_hub(false) and flow.return_save_pending and flow.active_scene==dungeon,"Failed return save retains the live run for retry")
	check(FileAccess.get_file_as_bytes(path)==before and GearInventoryCodec.encode(dungeon.gear.inventory)==bag,"Failed return preserves source counts, UIDs and profile bytes")
	check(flow.retry_pending_return(),"Existing return retry banks the source inventory")
	await step(10);hub=flow.active_scene as PrologueHub
	check(hub.gear.inventory.materials[&"dust"]==4 and hub.gear.inventory.materials[&"crystal"]==old_crystal+1,"Safe return publishes the exact carried materials")
	var rune_count: int=hub.gear.inventory.bag[&"fire"]
	check(hub.rune_learning.craft(&"fire"),"Existing Thanh Vy service consumes the two source materials")
	check(hub.gear.inventory.materials[&"dust"]==2 and hub.gear.inventory.materials[&"crystal"]==old_crystal and hub.gear.inventory.bag[&"fire"]==rune_count+1,"Real rune item and exact recipe costs publish together")
	var saved: Dictionary=GearInventoryCodec.encode(hub.gear.inventory)
	await close_flow();await open_flow();hub=flow.active_scene as PrologueHub
	check(GearInventoryCodec.encode(hub.gear.inventory)==saved,"Cold product load keeps crafted UID and source counts without replay grants")
	check(flow.depth_progress.can_start_floor(1) and flow.depth_progress.can_start_floor(2) and not flow.depth_progress.can_start_floor(3),"Revisit preserves the existing direct-launch policy")
	check(flow.start_depth_campaign(1),"A fresh expedition may deliberately gather the guaranteed source again")
	dungeon=flow.active_scene as DepthCampaign;fixture_run(dungeon);await clear_fixture(dungeon)
	check(sources(dungeon).size()==1,"Once-per-expedition source resets only at a new expedition boundary")
	pickup=sources(dungeon)[0] as LootPickup;pickup.automatic=false
	check(pickup.collect() and dungeon.gear.inventory.materials[&"dust"]==4,"Defeat fixture carries newly gathered source material")
	dungeon.player.health.minimum_health=0;dungeon.player.health.apply_damage(99999)
	await step(Engine.physics_ticks_per_second*2)
	hub=flow.active_scene as PrologueHub
	check(hub!=null and hub.gear.inventory.materials[&"dust"]==2,"Defeat keeps the existing protected-material policy instead of banking fresh source loot")
	check(flow.depth_progress.can_start_floor(1),"Death cannot revoke the previously cleared floor shortcut")
	await close_flow();await root.get_node("AudioManager").shutdown()
	print("RESULT FloorSupply checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
