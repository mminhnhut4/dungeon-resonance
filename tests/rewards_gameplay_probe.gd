extends "res://tests/newcomer_route_probe.gd"
## Continuation of the actually played item1 save. No grants/warps/state fixtures.
const Writer=preload("res://scripts/runtime/profile_commit_writer.gd")
var hub: ExteriorHub
var repaired_uid: int=0
var source_crystals: int=0
var source_attempts: int=0
var snapshots: Array[Dictionary]=[]

func snapshot(label: String) -> void:
	var inventory: GearInventory=flow.active_scene.gear.inventory
	var entries: Array[Dictionary]=OpeningRewardCatalog.received(flow.profile,inventory)
	for entry: Dictionary in entries:entry.erase("icon")
	snapshots.append({"label":label,"souls":flow.profile.souls,"coins":flow.profile.coins,"stash":flow.profile.material_stash.duplicate(),"inventory":GearInventoryCodec.encode(inventory),"receipts":entries})

func history(label: String) -> void:
	_stage(label);await _key(KEY_M);await pause(.8)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	if screen.journal.selected_id==PowerProgressionGuide.ID:await _click(screen.journal.power_button);await pause(.3)
	await _click(screen.journal.quest_buttons.get(OpeningRewardCatalog.ID) as Button);await pause(2)
	_check(screen.journal.selected_id==OpeningRewardCatalog.ID and not screen.journal.action_button.visible,"Actual M history shows earned receipts without a reclaim button")
	await _shot(label);snapshot(label)
	for i: int in 6:await _key(KEY_PAGEDOWN);await pause(.15)
	await pause(1.5);await _shot(label+"_remaining");await _key(KEY_ESCAPE)

func travel(id: StringName,destination: StringName) -> bool:
	var x: float=(ExteriorHub.ORIGIN+hub.exterior.interactions[id]).x if hub.outside else hub.stations[id].global_position.x
	if not await _walk(hub.player,x):return false
	await _step(5)
	if not _check(hub.nearest_station()==id,"Actual nearest physical door is "+String(id)):return false
	await _key(KEY_E);await _step(12)
	return _check((hub.exterior.room_id if hub.outside else ExteriorRouteCatalog.HUB)==destination,"Actual E travel reaches "+String(destination))

func jump_to(actor: Player,target: Vector2) -> bool:
	bot.action(&"jump",true)
	for i: int in 120:
		var dx: float=target.x-actor.global_position.x
		bot.action(&"move_left",dx< -6);bot.action(&"move_right",dx>6)
		await _step(1)
		if i>5 and actor.motor.is_grounded():break
	bot.stop();await _step(5)
	return _check(absf(actor.global_position.x-target.x)<24 and absf(actor.global_position.y-target.y)<4,"Ordinary held jump lands on the physical shelf %s; actual %s"%[target,actor.global_position])

func collect_floor(run: DungeonRun) -> bool:
	for i: int in 35:
		var nearest: LootPickup
		for child: Node in run.gear.loot.get_children():
			if child is LootPickup and not child.collected_once and (nearest==null or child.global_position.distance_to(run.player.global_position)<nearest.global_position.distance_to(run.player.global_position)):nearest=child
		if nearest==null:return true
		if not await _walk(run.player,clampf(nearest.global_position.x,60,1230),900):return false
		await _key(KEY_E);await _step(7)
	return _check(false,"Bounded normal pickup loop finished")

func floor_exit(run: DungeonRun,return_to_hub: bool) -> bool:
	if not await _walk(run.player,1240):return false
	await _key(KEY_E);await _step(4)
	if not _check(run.floor_exit.is_open,"Actual completed-floor E offers its normal choice"):return false
	await _click(run.floor_exit.return_button if return_to_hub else run.floor_exit.continue_button);await _step(12)
	return true

func chest_trip() -> bool:
	_stage("source_trip_%d"%source_attempts)
	if not await _walk(hub.player,hub.stations[&"portal"].global_position.x):return false
	await _key(KEY_E);await _step(10)
	if not _check(flow.active_scene is DungeonRun,"Entered ordinary dungeon through portal E"):return false
	var run: DungeonRun=flow.active_scene as DungeonRun;bot.run=run;bot.enabled=true
	for i: int in 10800:
		if run.outcome!=&"" or (run.living_enemies().is_empty() and not run.room.locked):break
		await _step(1)
	bot.stop()
	if not _check(run.outcome==&"" and not run.room.locked,"Real combat clears the source route without an HP floor"):return false
	if not await collect_floor(run) or not await floor_exit(run,false):return false
	var chest: TreasureChest=run.get("secret_chest") as TreasureChest
	if not _check(is_instance_valid(chest) and not chest.is_open,"Existing finite chest is present at the secret stage"):return false
	_stage("climb_to_real_chest_%d"%source_attempts)
	if not await _walk(run.player,180):return false
	for point: Vector2 in [Vector2(90,534),Vector2(250,444)]:
		if not await jump_to(run.player,point):return false
	if not await _walk(run.player,400) or not await jump_to(run.player,Vector2(270,366)):return false
	var barriers: Array[EnvironmentBarrier]=[]
	for child: Node in run.room.get_children():
		if child is EnvironmentBarrier and child.global_position.x<300 and not child.is_open:barriers.append(child)
	barriers.sort_custom(func(a: EnvironmentBarrier,b: EnvironmentBarrier) -> bool:return a.global_position.x>b.global_position.x)
	for barrier: EnvironmentBarrier in barriers:
		_stage("open_real_barrier_%d"%source_attempts)
		if not await _walk(run.player,barrier.global_position.x+58):return false
		var aim:=InputEventMouseMotion.new();aim.position=run.get_canvas_transform()*barrier.global_position;root.push_input(aim,true);await _step(3)
		for strike: int in 4:
			if barrier.is_open:break
			if barrier.requires_fire:
				var recipe: ResonanceDefinition=run.player.resonance_controller.get_recipe()
				await pause(recipe.cooldown_seconds+.3);bot.action(&"spell_cast",true);await _step(2);bot.action(&"spell_cast",false);await pause(.7)
			else:
				bot.action(&"attack",true);await _step(2);bot.action(&"attack",false);await pause(.55)
		if not _check(barrier.is_open,"Actual fire/melee inputs open the existing physical barrier"):return false
	if not await _walk(run.player,90):return false
	var before: int=run.gear.inventory.materials[&"crystal"]
	await _key(KEY_E);await pause(1)
	if not _check(chest.is_open,"Physical E opens the actual chest after real jumping/fire casts"):return false
	if not await collect_floor(run):return false
	source_crystals+=int(run.gear.inventory.materials[&"crystal"])-before
	_stage("real_chest_loot_%d"%source_attempts);snapshot("real_chest_loot_%d"%source_attempts);await pause(9);await _shot("chest_source_%d"%source_attempts)
	if not await floor_exit(run,true):return false
	for i: int in 300:
		if flow.active_scene is ExteriorHub:break
		await _step(1)
	hub=flow.active_scene as ExteriorHub
	return _check(hub!=null and not hub.outside,"Normal return keeps actually picked materials")

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-earned" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("REWARDS_SOURCE_SHA256"),"Starts from byte-identical actually played item1 QA save, no state fixture")
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	_check(not flow.qa_tools_enabled and flow.profile.bounty_claimed and hub.gear.inventory.materials[&"crystal"]==0 and not OpeningExplorationProgress.state_for(flow.profile)["cache_claimed"],"Earned bounty and missing crystal are genuine starting state")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	await history("earned_bounty_history");await power_page("missing_crystal_source")
	_stage("walk_to_optional_reward")
	if not await travel(&"exterior_road",&"o01_p01") or not await travel(&"door_east",&"o01_p02") or not await travel(&"door_east",&"o01_p03"):await _finish(false);return
	if not await _walk(hub.player,ExteriorHub.ORIGIN.x+1830):await _finish(false);return
	for point: Vector2 in [Vector2(1940,OpeningExploration.LEDGES[0].position.y),Vector2(2110,OpeningExploration.LEDGES[1].position.y)]:
		if not await jump_to(hub.player,ExteriorHub.ORIGIN+point):await _finish(false);return
	if not await _walk(hub.player,ExteriorHub.ORIGIN.x+OpeningExploration.CACHE_POINT.x):await _finish(false);return
	_stage("claim_existing_cache")
	await _key(KEY_E);await _dialogue_ready(hub)
	var stored: int=flow.profile.material_stash[&"dust"]
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_explore_cache_claim") as Button);await pause(1)
	_check(flow.profile.material_stash[&"dust"]==stored,"Reward confirmation does not give an early preview payout")
	await _click(hub.dialogue.cancel_button);await pause(.5)
	_check(not OpeningExplorationProgress.state_for(flow.profile)["cache_claimed"],"Cancel keeps the one-time opportunity unclaimed")
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_explore_cache_claim") as Button);await pause(.7);await _click(hub.dialogue.confirm_button);await pause(.5)
	if hub.dialogue.is_open:await _key(KEY_ESCAPE)
	_check(flow.profile.material_stash[&"dust"]==stored+OpeningExplorationProgress.REWARD and hub.gear.inventory.materials[&"dust"]==0,"Exactly existing reward goes to stash, not automatically to bag")
	await pause(2);await _shot("cache_receipt_notice");await pause(3);await history("cache_received_history")
	if not await travel(&"door_west",&"o01_p02") or not await travel(&"door_west",&"o01_p01") or not await travel(&"door_west",ExteriorRouteCatalog.HUB):await _finish(false);return
	_stage("withdraw_reward_to_bag")
	if not await _walk(hub.player,hub.stations[&"stash"].global_position.x):await _finish(false);return
	await _key(KEY_E);await pause(1);await _click(hub.station_content.find_child("WithdrawMaterial_dust",true,false) as Button);await pause(1)
	_check(hub.gear.inventory.materials[&"dust"]==1 and flow.profile.material_stash[&"dust"]==stored+1,"Actual withdraw moves one stored reward into bag, preserving the rest")
	await _key(KEY_ESCAPE);_stage("use_reward_for_repair")
	if not await _talk(hub,NpcCatalog.SMITH):await _finish(false);return
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_smith_repair") as Button);await pause(1)
	for item: GearItem in hub.gear.inventory.items.values():
		if item.broken and hub.economy.quote_repair(item.uid)["can_repair"]:repaired_uid=item.uid;break
	if not _check(repaired_uid>0,"Actually carried broken gear can use the real reward material"):await _finish(false);return
	var offer: Dictionary=hub.economy.quote_repair(repaired_uid);var metal: int=hub.gear.inventory.materials[&"metal"];var dust: int=hub.gear.inventory.materials[&"dust"]
	await _click(hub.station_content.find_child("RepairEquipment_%d"%repaired_uid,true,false) as Button);await pause(2)
	_check(hub.gear.inventory.items[repaired_uid].can_equip() and hub.gear.inventory.materials[&"metal"]==metal-int(offer["metal"]) and hub.gear.inventory.materials[&"dust"]==dust-int(offer["dust"]) and flow.profile.material_stash[&"dust"]==stored+1,"Real repair spends quoted bag materials once, unlocks the same gear and leaves stash intact")
	await _shot("reward_used_for_repair");await _key(KEY_ESCAPE);await history("spent_and_remaining_reward")
	for attempt: int in 8:
		source_attempts=attempt+1
		if not await chest_trip():await _finish(false);return
		if hub.gear.inventory.materials[&"crystal"]>0:break
	if not _check(source_crystals>0 and hub.gear.inventory.materials[&"crystal"]>0,"Actual random chest loot supplies the previously missing crystal after normal return"):await _finish(false);return
	await power_page("actual_materials_next_step");await history("final_received_reward_and_balances");await _finish(true)

func _finish(complete: bool) -> void:
	bot.stop();await pause(.3)
	var capture: Dictionary=recorder.finish();var state: Dictionary={"checks":checks,"failures":failures,"complete":complete,"source_profile_sha256":OS.get_environment("REWARDS_SOURCE_SHA256"),"profile_path":ProjectSettings.globalize_path(profile_path),"profile_sha256":FileAccess.get_sha256(profile_path),"repaired_uid":repaired_uid,"source_attempts":source_attempts,"crystals_collected":source_crystals,"snapshots":snapshots,"notice_ids":flow.reward_notice.displayed,"capture":{"wall_seconds":capture["wall_seconds"],"frames":capture["frames"].size(),"audio":capture["audio"]},"scope":"Normal real-time viewport inputs from item1 actually played save; no grants/unlocks/warps/HP/loot/RNG/state fixtures. QA automation, not human research."}
	var file:=FileAccess.open(evidence.path_join("rewards-route.json"),FileAccess.WRITE);file.store_string(JSON.stringify(state,"\t",true,true));file.close()
	recorder.queue_free();bot.queue_free();flow.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT RewardsGameplay checks=%d failures=%d complete=%s wall=%.3f"%[checks,failures,complete,capture["wall_seconds"]]);quit(0 if complete and failures==0 else 1)
