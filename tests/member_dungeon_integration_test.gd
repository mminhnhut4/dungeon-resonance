extends SceneTree
## QA setup grants historical receipts; floor transitions use the product owner/UI.
const Catalog=preload("res://data/member_floor_catalog.gd")
var checks: int=0
var failures: int=0
var flow: GameFlow
var rows: Array[Dictionary]=[]
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func _step(count: int=1) -> void:
	for index: int in count:await physics_frame
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	flow=load("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override="user://member_integration.json";root.add_child(flow);await _step(4)
	_check(not flow.start_depth_campaign(5),"Fresh quest state cannot launch deep floor")
	_check(flow.profile.record_boss_defeat("member_fixture_opening_proof"),"Fixture uses durable opening proof owner")
	_check(flow.depth_progress.accept(),"Existing depth quest accepted")
	for number: int in range(1,6):_check(flow.depth_progress.record(StringName("depth_floor_%d"%number),number),"Fixture historical floor receipt %d"%number)
	_check(flow.start_depth_campaign(5),"Existing cleared-floor departure launches member-integrated scene")
	await _step(5)
	var run:=flow.active_scene as MemberDungeonCampaign
	_check(run!=null and run.global_floor_number()==8,"Main route selected new subtype at original floor8")
	_check(not run.enter_room(6),"Live floor8 boss prevents new-floor bypass")
	var player_id: int=run.player.get_instance_id();var inventory_id: int=run.gear.inventory.get_instance_id()
	run.boss.health.apply_damage(99999) # Boss-death setup only; not combat QA.
	for index: int in 360:
		if run.portal_active:break
		await _step(1)
	_check(run.portal_active and run.member_progress.unlocked(),"Defeated floor8 boss durably unlocks member path")
	PlayerTravel.relocate(run.player,DepthFloorCatalog.PORTAL);await _step(3)
	_check(run.floor_exit.open(),"Completed original boss floor opens product exit choice")
	_check(run.floor_exit.continue_button.visible and run.floor_exit.continue_button.text.contains("9/30"),"Boss8 offers concrete deeper floor9")
	run.floor_exit._continue();await _step(3)
	_check(run.member_active and run.member_floor==9,"Choice enters playable floor9")
	_check(run.player.get_instance_id()==player_id and run.gear.inventory.get_instance_id()==inventory_id,"Continuation retains same Player/inventory owners")
	for number: int in range(9,31):
		var room:=run.room as MemberDungeonRoom;var data: Dictionary=Catalog.floor_data(number)
		_check(run.member_floor==number and room.floor_number==number,"Correct active floor %d"%number)
		_check(room.traps.size()==data["hazards"].size() and room.platforms.size()==data["moving"].size()+data["collapse"].size(),"Live trap/platform consumers match authored floor%d"%number)
		_check(not room.locked and run.living_enemies().size()==MemberEncounterCatalog.entries(number).size(),"Authorized placement count and optional-clear exit floor%d"%number)
		_check(run.living_enemies().all(func(enemy:Node2D)->bool:return enemy.global_position.x>300 and enemy.global_position.x<Catalog.width(number)-300),"Entry/camp/exit buffer floor%d"%number)
		if number in [10,11,15]:
			var enemy:=run.living_enemies()[0] as MemberEnemy
			var defeats: int=run.member_defeats;var drops: int=run.gear.loot.spawned_total
			var table:=run.gear.loot.drop_table.duplicate() as DropTableResource;table.none_chance=0;run.gear.loot.drop_table=table
			var hit:=DamageEvent.new();hit.source_id=run.player.get_instance_id();hit.source_team_id=1;hit.target_id=enemy.get_instance_id();hit.attack_id=CombatIds.next_id();hit.root_event_id=hit.attack_id;hit.hit_window_id=1;hit.base_damage=99999
			enemy.hurtbox.take_damage(hit);await _step(3)
			_check(run.member_defeats==defeats+1 and run.gear.loot.spawned_total>drops,"Actual death enters existing loot owner once floor%d"%number)
			var after_drops: int=run.gear.loot.spawned_total
			enemy.health.died.emit();run._member_enemy_died(enemy);await _step(2)
			_check(run.member_defeats==defeats+1 and run.gear.loot.spawned_total==after_drops,"Duplicate death cannot duplicate drops floor%d"%number)
			if number==10:
				var soul: LootPickup
				for child: Node in run.gear.loot.get_children():
					if child is LootPickup and (child as LootPickup).kind==&"soul":soul=child as LootPickup;break
				_check(soul!=null,"Campaign enemy uses existing permanent soul pickup")
				if soul!=null:
					var souls_before: int=flow.profile.souls;var quantity: int=soul.quantity
					var old_bytes: PackedByteArray=FileAccess.get_file_as_bytes(flow.save_path_override)
					flow.profile._writer.fault_plan={"write_candidate":true}
					_check(not soul.collect() and flow.profile.souls==souls_before and FileAccess.get_file_as_bytes(flow.save_path_override)==old_bytes and run.has_pending_rewards(),"Reward write failure retains pickup and exact profile bytes")
					_check(run.retry_pending_rewards() and soul.collected_once and flow.profile.souls==souls_before+quantity,"Original retry commits permanent reward once")
					_check(not soul.collect() and flow.profile.souls==souls_before+quantity,"Duplicate collect cannot credit souls again")
			if number==11:
				_check(enemy.children_spawned==3 and run.living_enemies().size()==3,"Floor11 introduces three live spiderlings")
				_check(run.living_enemies().all(func(child:Node2D)->bool:return (child as MemberEnemy).campaign_lane and (child as MemberEnemy).lane_limits==enemy.lane_limits and (child as MemberEnemy).balance_floor==11 and (child as MemberEnemy).health.maximum_health==8),"Brood inherits safe lane and fixed-floor balance")
		_check(room.reference_background!=null and not room.reference_background.texture.resource_path.contains("Tang"),"Clean background; no screenshot HUD baked into floor%d"%number)
		if data["chest"]!=null:_check(run._member_chest!=null and run._member_chest.locked,"Optional reward stays locked before fire barrier %d"%number)
		PlayerTravel.relocate(run.player,Catalog.exit_point(number));await _step(2)
		_check(run.floor_exit.open(),"Product exit available at floor%d end"%number)
		rows.append({"floor":number,"width":room.room_width,"traps":room.traps.size(),"platforms":room.platforms.size(),"exit":run.can_choose_floor_exit()})
		if number==9:
			var before: PackedByteArray=FileAccess.get_file_as_bytes(flow.save_path_override)
			flow.profile._writer.fault_plan={"write_candidate":true}
			run.floor_exit._continue();await _step(2)
			_check(run.member_floor==9 and run.has_pending_rewards() and FileAccess.get_file_as_bytes(flow.save_path_override)==before,"Write failure holds same floor/reward and exact profile bytes")
			_check(run.player.get_instance_id()==player_id and run.gear.inventory.get_instance_id()==inventory_id,"Write failure preserves live owners")
			if not run.floor_exit.is_open:run.floor_exit.open()
			run.floor_exit._continue();await _step(2)
			_check(run.member_floor==10 and not run.has_pending_rewards(),"Product retry commits once and continues")
		elif number<30:
			run.floor_exit._continue();await _step(2)
		else:
			_check(not run.floor_exit.continue_button.visible,"Floor30 is terminal")
			run.floor_exit._return_or_retry();await _step(5)
	_check(flow.active_scene is PrologueHub,"Terminal return uses existing GameFlow bank/return")
	_check(int(flow.profile.extension_state(MemberDungeonProgress.SCOPE).get("cleared",0))==30,"All22exit receipts durable")
	_check(flow.start_depth_campaign(5),"Completed quest allows fresh departure through existing guide route")
	await _step(4);run=flow.active_scene as MemberDungeonCampaign
	_check(run.player.get_instance_id()!=player_id and not run.member_active and not run.enter_room(6),"Fresh trip has new Player and still requires its live floor8 boss")
	run.boss.health.apply_damage(99999)
	for index: int in 360:
		if run.portal_active:break
		await _step()
	PlayerTravel.relocate(run.player,DepthFloorCatalog.PORTAL);await _step(3)
	_check(run.floor_exit.open(),"Re-entry boss exit opens")
	run.floor_exit._continue();await _step(3)
	_check(run.member_floor==9 and run._member_chests.is_empty() and run.living_enemies().size()==1,"New trip resets chest and authored encounter")
	var reset_room:=run.room as MemberDungeonRoom
	_check(reset_room.traps.all(func(t: MemberDungeonTrap)->bool:return t.age<.3) and reset_room.barriers.all(func(b: EnvironmentBarrier)->bool:return not b.is_open),"Re-entry rebuilds fresh trap clocks and closed obstacles")
	var revision: int=flow.profile.extension_revision(MemberDungeonProgress.SCOPE)
	PlayerTravel.relocate(run.player,Catalog.exit_point(9));await _step(2);run.floor_exit.open();run.floor_exit._return_or_retry();await _step(4)
	_check(flow.active_scene is PrologueHub and flow.profile.extension_revision(MemberDungeonProgress.SCOPE)==revision,"Replay exit is idempotent and returns without duplicate progression commit")
	var path: String=flow.save_path_override;var before: PackedByteArray=FileAccess.get_file_as_bytes(path);var saved_souls: int=flow.profile.souls
	flow.queue_free();await _step(4)
	var cold:=SanctuaryProfile.new();cold.save_path=path
	_check(cold.load_profile(),"Original cold reader loads additive member content")
	_check(cold.souls==saved_souls,"Cold reader preserves collected encounter rewards")
	var progress:=MemberDungeonProgress.new();progress.initialize(cold)
	_check(progress.available() and progress.unlocked() and int(progress.state()["cleared"])==30,"Cold progress/unlock restored through same owner")
	_check(FileAccess.get_file_as_bytes(path)==before,"Cold load leaves profile bytes unchanged")
	_check(load("res://scripts/runtime/profile_commit_writer.gd").seal_valid(load("res://scripts/runtime/profile_commit_writer.gd").read_json(path)),"Original numeric seal valid after new-floor saves")
	var out:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("integration.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks,"failures":failures,"floors":rows,"scope":"Fixture historical receipts/death; real flow/exit handlers and original writer. Exit relocation isolates transition, not traversal or natural combat."},"\t"));out.close()
	await root.get_node("AudioManager").shutdown()
	print("RESULT MemberDungeonIntegration checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
