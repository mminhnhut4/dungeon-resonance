extends SceneTree
var flow: GameFlow
var checks: int=0
var failures: int=0
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func step(count: int=3) -> void:
	for _i: int in count:await physics_frame;await process_frame
func setup_case(id: String) -> ExteriorHub:
	var profile:=SanctuaryProfile.new();profile.save_path="user://part3-upgrade-transaction/"+id+"/profile.json";profile.coins=100
	var inv: GearInventory=HubPreparation.starter_inventory(profile);inv.materials[&"enhancement_stone_1"]=2;profile.material_stash[&"enhancement_stone_1"]=99
	profile.hub_inventory=GearInventoryCodec.encode(inv);check(profile.save(),"Synthetic wallet and carried/stored ledgers saved")
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=profile.save_path;root.add_child(flow);await step(12)
	var hub: ExteriorHub=flow.active_scene as ExteriorHub;hub.open_station(&"smith_enhance");await step(3);return hub
func close_case() -> void:
	flow.queue_free();await step(8)
func button(hub: ExteriorHub) -> Button:return hub.station_content.find_child("EnhanceWeapon_%d"%hub.gear.inventory.equipped_weapon_uid,true,false) as Button
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	Engine.physics_ticks_per_second=120 if "--hz=120" in OS.get_cmdline_user_args() else 60
	AudioServer.set_bus_mute(0,true)
	var hub: ExteriorHub=await setup_case("duplicate")
	var inv: GearInventory=hub.gear.inventory;var uid: int=inv.equipped_weapon_uid
	var old: Button=button(hub);check(old!=null and not old.disabled,"Actual enhancement offer is enabled")
	old.pressed.emit();old.pressed.emit()
	check(inv.items[uid].enhancement_level==1 and inv.materials[&"enhancement_stone_1"]==1 and flow.profile.coins==95,"Two deliveries from one quoted UI button spend once and apply one level")
	check(flow.profile.material_stash[&"enhancement_stone_1"]==99,"Enhancement never takes the fallback stone from stash")
	await close_case()
	hub=await setup_case("rollback");inv=hub.gear.inventory;uid=inv.equipped_weapon_uid
	old=button(hub)
	var before: PackedByteArray=FileAccess.get_file_as_bytes(flow.profile.save_path)
	flow.profile._writer.fault_plan={"write_candidate":true};old.pressed.emit()
	check(FileAccess.get_file_as_bytes(flow.profile.save_path)==before and inv.items[uid].enhancement_level==0 and inv.materials[&"enhancement_stone_1"]==2 and flow.profile.coins==100,"Failed actual enhancement button restores exact save bytes, bag, coins and level")
	flow.profile._writer.fault_plan.clear();old.pressed.emit()
	check(inv.items[uid].enhancement_level==0 and flow.profile.coins==100,"Consumed stale callback cannot retry a failed quote by itself")
	var retry: Button=button(hub);retry.pressed.emit()
	check(inv.items[uid].enhancement_level==1 and flow.profile.coins==95 and inv.materials[&"enhancement_stone_1"]==1,"Fresh rebuilt quote retries once after save failure")
	await close_case();hub=await setup_case("closed");inv=hub.gear.inventory;uid=inv.equipped_weapon_uid;old=button(hub)
	hub.close_station();old.pressed.emit()
	check(inv.items[uid].enhancement_level==0 and flow.profile.coins==100,"Closing the service invalidates an unconsumed old enhancement callback")
	await close_case();await root.get_node("AudioManager").shutdown()
	print("RESULT PowerUpgradeTransactions checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
