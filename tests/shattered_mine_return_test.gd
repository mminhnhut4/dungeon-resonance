extends SceneTree
## Explicit transaction fixtures: seed materials, relocate and defeat directly.
## Input-only footage is separate; the existing save writer is never replaced.
const ENTRY=preload("res://scenes/maps/shattered_mine_entry.tscn")
const ROOM=preload("res://scripts/rooms/shattered_mine_room.gd")
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int=0
var failures: int=0
var flow: GameFlow
func _initialize() -> void:call_deferred("run")
func step(n: int) -> void:
	for i: int in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func collect_fixture(run_scene: DungeonRun) -> void:
	for enemy: Node2D in run_scene.living_enemies():enemy.ai_enabled=false
	PlayerTravel.relocate(run_scene.player,ROOM.SUPPLY,PlayerTravel.Kind.INTRA_EXPEDITION);await step(5)
	check(run_scene.get("supply_cache").interact(),"Explicit relocated fixture opens the actual cache")
	for pickup: LootPickup in run_scene.gear.loot.get_children():
		if pickup.has_meta(&"shattered_mine_source"):check(pickup.collect(),"Fixture collects through the real inventory owner")
	await step(5)
func run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	AudioServer.set_bus_mute(0,true)
	flow=ENTRY.instantiate();flow.save_path_override="user://shattered-mine-return/profile.json";root.add_child(flow);current_scene=flow;await step(15)
	var hub: PrologueHub=flow.active_scene as PrologueHub
	hub.gear.inventory.materials[&"dust"]=7;hub.gear.inventory.materials[&"crystal"]=4
	flow.profile.hub_inventory=GearInventoryCodec.encode(hub.gear.inventory)
	check(flow.profile.save(),"Explicit protected-material fixture commits through existing writer")
	var original_ids: Array=hub.gear.inventory.items.keys()
	flow.start_campaign();await step(12)
	var mine: DungeonRun=flow.active_scene as DungeonRun
	check(mine!=null and mine.gear.inventory.expedition_active,"Existing departure starts provenance tracking")
	await collect_fixture(mine)
	check(mine.gear.inventory.materials[&"dust"]==9 and mine.gear.inventory.materials[&"crystal"]==5,"Source adds real carried materials above protected base")
	PlayerTravel.relocate(mine.player,ROOM.ENTRY,PlayerTravel.Kind.INTRA_EXPEDITION);await step(5)
	check(mine.can_choose_floor_exit() and not mine.living_enemies().is_empty(),"Unfinished sample supports an early retreat")
	var bytes: PackedByteArray=FileAccess.get_file_as_bytes(flow.profile.save_path)
	var bag: String=Writer.canonical(GearInventoryCodec.encode(mine.gear.inventory))
	flow.profile._writer.fault_plan={"write_candidate":true}
	check(mine.request_floor_return(),"Real return API accepts the sample entrance")
	check(flow.active_scene==mine and flow.return_save_pending and mine.outcome==&"retreat","Failed save holds the run and pending return")
	check(FileAccess.get_file_as_bytes(flow.profile.save_path)==bytes and Writer.canonical(GearInventoryCodec.encode(mine.gear.inventory))==bag,"Failure preserves exact file bytes and live UID/material ledger")
	check(flow.retry_pending_return(),"Existing retry completes the held return once")
	await step(12);hub=flow.active_scene as PrologueHub
	check(hub!=null and hub.gear.inventory.materials[&"dust"]==9 and hub.gear.inventory.materials[&"crystal"]==5,"Safe return banks the exact carried source")
	check(not flow.retry_pending_return(),"Repeated finished retry cannot duplicate return")
	for uid: int in original_ids:check(hub.gear.inventory.items.has(uid),"Prepared UID retained after return")
	flow.start_campaign();await step(12);mine=flow.active_scene as DungeonRun
	check(not mine.get("supply_claimed"),"A genuinely new expedition gets a new optional cache")
	await collect_fixture(mine)
	check(mine.gear.inventory.materials[&"dust"]==11 and mine.gear.inventory.materials[&"crystal"]==6,"Second trip receives one fresh source")
	mine.player.health.apply_damage(99999);await step(3)
	check(mine.outcome==&"defeat","Explicit death fixture reaches ordinary defeat owner")
	check(flow.show_hub(true),"Existing defeat return commits safely")
	await step(12);hub=flow.active_scene as PrologueHub
	check(hub.gear.inventory.materials[&"dust"]==9 and hub.gear.inventory.materials[&"crystal"]==5,"Defeat loses only new trip materials and preserves prior return")
	check(flow.profile.boss_proofs[&"golem"]==0 and not flow.profile.opening_progress["completed"].has("returned_to_hub"),"Mine retreat never invents Golem victory or opening completion")
	check(not flow.depth_expansion_enabled and flow.depth_progress==null,"Sample adds no numbered-floor authority")
	flow.queue_free();current_scene=null;await step(10);await root.get_node("AudioManager").shutdown()
	print("RESULT ShatteredMineReturn checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
