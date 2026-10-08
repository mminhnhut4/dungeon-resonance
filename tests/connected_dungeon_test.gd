extends "res://tests/depth_campaign_test.gd"
## Runtime lifecycle fixture: direct health defeats isolate routing, not combat difficulty.
var authorized: bool=false
var authorization_calls: int=0
func _authorize_depth() -> bool:
	authorization_calls+=1
	return authorized
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz=int(argument.trim_prefix("--hz="))
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name()!="headless" or hz not in [60,120] or not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):
		print("FAIL: connected tests require isolated headless60/120"); quit(2); return
	Engine.physics_ticks_per_second=hz; AudioServer.set_bus_mute(0,true)
	bank=SanctuaryProfile.new(); bank.save_path="user://connected/%d_%d_%d/profile.json" % [hz,OS.get_process_id(),Time.get_ticks_usec()]
	_check(_initialize_bank(),"Fresh synthetic sealed owner")
	var prepared: GearInventory=HubPreparation.starter_inventory(bank)
	run=CAMPAIGN.instantiate() as DungeonRun
	run.profile=bank; run.world_building_enabled=true; run.starting_inventory=prepared
	run.set("connected_opening",true); run.set("depth_entry_authorizer",_authorize_depth); run.set("depth_progress_committer",_commit_depth)
	root.add_child(run); current_scene=run; await _step(8)
	run.feedback.hit_stop_seconds=0; run.feedback.enable_global_hitstop(false); run.survival.set_enabled(false)
	run.player.health.minimum_health=1; _disable_ai()
	var depth: DepthCampaign=run as DepthCampaign
	_check(depth.is_opening_segment() and run.room_number==1 and depth.stage==1 and depth.global_floor_number()==1,"Connected fresh run starts opening floor1")
	_check(run.living_enemies().size()==4 and not (run.room is DepthRoom),"Opening uses original WorldCampaign roster/room")
	_check(run.floor_exit.continue_button.text=="Tiếp tục xuống tầng","Opening keeps ordinary continuation caption")
	var player_id: int=run.player.get_instance_id()
	var gear_id: int=run.gear.get_instance_id()
	var inventory_id: int=run.gear.inventory.get_instance_id()
	_check(depth.enter_stage(2) and depth.global_floor_number()==1 and depth.secret_chest!=null,"Opening secret branch retained without new global floor")
	_check(depth.enter_stage(3) and depth.global_floor_number()==2,"Opening arena maps global2")
	_check(depth.enter_stage(4) and depth.global_floor_number()==3,"Opening Golem maps global3")
	_disable_ai(); await _step(3)
	_check(not depth.advance_room(),"Live Golem blocks bridge")
	run.gear.loot.drop_table=run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance=1.0; run.gear.loot.drop_table.blueprint_chance_total=0.0
	bank._writer.fault_plan={"write_candidate":true}
	run.boss.health.apply_damage(99999); await _step(8)
	_check(run.portal_active and run._proof_pending and run.has_pending_rewards(),"Actual Golem death retains failed proof escrow")
	_check(not depth.advance_room() and authorization_calls==0,"Pending proof blocks bridge before authorizer")
	_check(run.retry_pending_rewards() and not run.has_pending_rewards(),"Inherited proof retry works in connected controller")
	_check(bank.boss_receipts.size()==1,"Golem receipt durably recorded exactly once")
	_check(not depth.advance_room() and depth.is_opening_segment(),"Failed depth authorization keeps Golem room and run")
	authorized=true
	run.gear.inventory.run_coins=37; run.player.health.current_health=53; run.player.energy.current=41
	run.player.energy.regeneration_delay=1.7; run.player.motor.dash_cooldown_remaining=.55
	run.player.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"fixture_clock"]=2.25
	var kit: Dictionary=GearInventoryCodec.encode(run.gear.inventory)
	var hp: float=run.player.health.current_health
	var energy: float=run.player.energy.current
	var delay: float=run.player.energy.regeneration_delay
	var cooldowns: Dictionary=run.player.resonance_controller.loadout_state.cooldowns_by_recipe_id.duplicate()
	var dash: float=run.player.motor.dash_cooldown_remaining
	PlayerTravel.relocate(run.player,Vector2(1160,640),PlayerTravel.Kind.INTRA_EXPEDITION)
	_check(run.floor_exit.open() and run.floor_exit.continue_button.visible,"Golem portal exposes continue and return choices")
	_check(run.floor_exit.continue_button.text.contains("4/8"),"Portal offers global floor4")
	run.floor_exit._continue()
	_check(not depth.is_opening_segment() and run.room_number==1 and depth.global_floor_number()==4,"Actual panel continue enters local1/global4")
	_check(run.player.get_instance_id()==player_id and run.gear.get_instance_id()==gear_id and run.gear.inventory.get_instance_id()==inventory_id,"Same Player GearSession and inventory owner across bridge")
	_check(GearInventoryCodec.encode(run.gear.inventory)==kit,"No bank reset UID/coins change on bridge")
	_check(is_equal_approx(run.player.health.current_health,hp) and is_equal_approx(run.player.energy.current,energy),"Bridge preserves actual HP and mana")
	_check(run.player.resonance_controller.loadout_state.cooldowns_by_recipe_id==cooldowns and is_equal_approx(run.player.motor.dash_cooldown_remaining,dash) and is_equal_approx(run.player.energy.regeneration_delay,delay),"Bridge preserves recipe/dash/regeneration clocks")
	_check(run.room is DepthRoom and (run.player.get_node("Camera2D") as Camera2D).limit_right==1888,"Actual wide depth1 and camera active")
	_check(not run.room.has_node("ExistingMapRaster"),"Depth removes WorldCampaign raster adapter")
	_check(not run.portal_active and run.outcome==&"" and bank.boss_receipts.size()==1,"Bridge continues same expedition without second proof or outcome")
	await _step(4); _disable_ai()
	for number: int in [1,2,3,4]:
		await _clear_roster()
		if number==1:
			PlayerTravel.relocate(run.player,Catalog.exit_point(1),PlayerTravel.Kind.INTRA_EXPEDITION)
			_check(run.floor_exit.open(),"Actual global4 cleared-floor choice opens")
			_check(run.floor_exit.continue_button.text=="Tiếp tục xuống tầng" and not run.floor_exit.continue_button.text.contains("4/8"),"After bridge, next-floor caption is reset rather than repeating floor4")
			run.floor_exit.close()
		_check(events.get(StringName("depth_floor_%d" % number),0)==number,"Global%d keeps local%d progress receipt" % [number+3,number])
		_check(depth.advance_room() and depth.global_floor_number()==number+4,"Connected route advances global%d" % (number+4))
		await _step(3); _disable_ai()
		_check(not run.room.has_node("ExistingMapRaster"),"Depth%d has no inherited opening raster" % (number+1))
	_check(run.room_number==5 and depth.global_floor_number()==8,"Existing fifth depth boss is global8")
	depth._finish_boss()
	_check(not run.portal_active and not events.has(&"depth_boss_defeated"),"Stale finish callback cannot complete healthy final boss")
	run.boss.health.apply_damage(99999); await _step(8)
	_check(run.portal_active and events.get(&"depth_boss_defeated",0)==5 and bank.boss_receipts.size()==1,"Final boss commits local5 only, never second Golem proof")
	_check(not depth.advance_room(),"Final global8 has no unbuilt ninth floor")
	_check(run.player.get_instance_id()==player_id and run.gear.get_instance_id()==gear_id,"Same actor/session survive all eight global floors")
	run.queue_free(); await _step(8)
	root.get_node("AudioManager").call("shutdown")
	print("RESULT ConnectedDungeon checks=%d failures=%d hz=%d" % [checks,failures,hz])
	quit(0 if failures==0 else 1)
