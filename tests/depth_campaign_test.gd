extends SceneTree
## Focused depth lifecycle + real player traversal. Fixture kills do not certify combat feel.
const Catalog=preload("res://data/depth_floor_catalog.gd")
const Model=preload("res://scripts/cultivation/opening_cultivation_state.gd")
const CAMPAIGN: PackedScene=preload("res://scenes/rooms/depth_campaign.tscn")
var run: DungeonRun
var bank: SanctuaryProfile
var checks: int=0
var failures: int=0
var hz: int=60
var allow_commit: bool=true
var events: Dictionary[StringName,int]={}
var report: Array[Dictionary]=[]
func _initialize_bank() -> bool:
	if FileAccess.file_exists(bank.save_path) or not bank.save(): return false
	var initial: Dictionary=Model.new_progress(4)
	initial["config"]=SanctuaryProfile.CommitWriter.read_json("res://data/cultivation/opening_cultivation_config_v1.json")
	return bank.commit_cultivation(Model.initial_proposal(initial,bank.material_stash,bank.souls,bank.boss_proofs))
func _initialize() -> void: _run.call_deferred()
func _step(count: int=4) -> void:
	for _index: int in count: await physics_frame; await process_frame
func _check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures+=1
	print(("PASS: " if ok else "FAIL: ")+message)
func _stop_fixture() -> void:
	_release()
	root.get_node("AudioManager").call("shutdown")
	print("RESULT DepthCampaign checks=%d failures=%d hz=%d" % [checks,failures,hz])
	quit(1)
func _commit_depth(id: StringName,number: int) -> bool:
	if not allow_commit: return false
	events[id]=number; return true
func _release() -> void:
	for action: StringName in [&"move_left",&"move_right",&"jump",&"dash",&"interact"]: Input.action_release(action)
func _walk(x: float) -> void:
	var action: StringName=&"move_right" if x>run.player.position.x else &"move_left"
	var direction: float=1.0 if action==&"move_right" else -1.0
	Input.action_press(action)
	for _index: int in hz*5:
		await _step(1)
		if direction*(run.player.position.x-x)>=0: break
	Input.action_release(action); await _step(ceili(hz*.18))
func _jump(at: Vector2) -> void:
	var action: StringName=&"move_right" if at.x>run.player.position.x else &"move_left"
	var direction: float=1.0 if action==&"move_right" else -1.0
	Input.action_press(action); Input.action_press(&"jump")
	for _index: int in hz:
		await _step(1)
		if direction*(run.player.position.x-at.x)>=0: break
	Input.action_release(action); await _step(hz)
	Input.action_release(&"jump"); await _step(4)
func _disable_ai() -> void:
	for enemy: Node2D in run.living_enemies():
		enemy.set("ai_enabled",false)
		if enemy is BaseEnemy: (enemy as BaseEnemy).state_machine.process_mode=Node.PROCESS_MODE_DISABLED
func _geometry(number: int) -> void:
	var actor: Player=run.player
	var kit: Dictionary=GearInventoryCodec.encode(run.gear.inventory)
	var current_hp: float=actor.health.current_health
	_check(actor.motor.is_grounded() and absf(actor.position.y-640.0)<2.0,"Depth%d entry foot grounded on real y640" % number)
	_check(run.room is DungeonRoom and run.room.get("surfaces").size()==Catalog.floor_data(number)["shelves"].size()+1,"Depth%d has its own authored surfaces" % number)
	_check(run.room.get("raster_bound")==true,"Depth%d binds generated raster in actual room" % number)
	_check(run.room.arrow.visible and run.room.arrow.text.contains("PHONG ẤN"),"Depth%d gate hint remains visible outside debug overlay" % number)
	await _walk(1120)
	_check(actor.position.x>=1110 and actor.motor.is_grounded() and absf(actor.position.y-640)<2,"Depth%d player walks combat spine east without jump" % number)
	await _walk(180)
	_check(actor.position.x<=190 and actor.motor.is_grounded(),"Depth%d player walks combat spine west without jump" % number)
	var shelves: Array=Catalog.floor_data(number)["shelves"]
	if number<5:
		var first: Rect2=shelves[0]
		await _jump(Vector2(first.get_center().x,first.position.y))
		_check(actor.motor.is_grounded() and absf(actor.position.y-first.position.y)<2,"Depth%d normal jump reaches west step" % number)
		var gallery: Rect2=shelves[1]
		await _jump(Vector2(gallery.get_center().x,gallery.position.y))
		_check(actor.motor.is_grounded() and absf(actor.position.y-gallery.position.y)<2,"Depth%d normal jump reaches west gallery" % number)
		await _walk(gallery.end.x-30)
		var high: Rect2=shelves[2]
		await _jump(Vector2(high.get_center().x,high.position.y))
		_check(actor.motor.is_grounded() and absf(actor.position.y-high.position.y)<2,"Depth%d upper shortcut reached using existing jump input" % number)
		await _walk(high.end.x+22)
		await _step(ceili(hz*1.1))
		# A second high bridge may catch the body: walk to its far end before dropping.
		if actor.position.y<630:
			var next_bridge: Rect2=shelves[3]
			await _walk(next_bridge.end.x+24); await _step(ceili(hz*1.1))
			# Descending gallery may land on the intended east step: walk back off it.
			await _walk(700); await _step(ceili(hz*1.1))
		_check(actor.motor.is_grounded() and absf(actor.position.y-640)<2,"Depth%d shortcut returns to combat spine" % number)
	else:
		var ledge: Rect2=shelves[0]
		await _jump(Vector2(ledge.get_center().x,ledge.position.y))
		_check(actor.motor.is_grounded() and absf(actor.position.y-ledge.position.y)<2,"Boss arena side ledge reachable by ordinary jump")
		await _walk(310); await _step(hz)
		_check(actor.motor.is_grounded() and absf(actor.position.y-640)<2,"Boss arena side ledge returns to flat combat lane")
	_check(GearInventoryCodec.encode(run.gear.inventory)==kit and is_equal_approx(actor.health.current_health,current_hp),"Depth%d traversal keeps HP/UID ledger" % number)
	report.append({"floor":number,"player_end":[actor.position.x,actor.position.y],"raster":run.room.get("raster_bound"),"shelves":shelves.map(func(rect: Rect2) -> String: return str(rect))})
func _clear_roster() -> void:
	for enemy: Node2D in run.living_enemies(): enemy.health.apply_damage(99999)
	await _step(8)
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz=int(argument.trim_prefix("--hz="))
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name()!="headless" or hz not in [60,120] or not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):
		print("FAIL: depth tests require verified isolated user:// and60/120 headless"); quit(2); return
	Engine.physics_ticks_per_second=hz; AudioServer.set_bus_mute(0,true)
	bank=SanctuaryProfile.new()
	# Strict runs both rates under one QA root; each process owns a fresh sealed file.
	bank.save_path="user://depth_campaign_test/%d_%d_%d/profile.json" % [hz,OS.get_process_id(),Time.get_ticks_usec()]
	var initialized: bool=_initialize_bank()
	_check(initialized,"Depth fixture initializes a fresh sealed profile through cultivation commit owner")
	if not initialized: _stop_fixture(); return
	var prepared: GearInventory=HubPreparation.starter_inventory(bank)
	bank.hub_inventory=GearInventoryCodec.encode(prepared)
	var prepared_saved: bool=bank.save()
	_check(prepared_saved,"Depth fixture owns a fresh synthetic save with prepared UID ledger")
	if not prepared_saved: _stop_fixture(); return
	var document: Variant=JSON.parse_string(FileAccess.get_file_as_string(bank.save_path))
	var sealed: bool=document is Dictionary and document.get("version",0)==2
	_check(sealed,"Fault fixture is verified sealed version2")
	if not sealed: _stop_fixture(); return
	var old_opening: Dictionary=bank.opening_progress.duplicate(true)
	var old_proofs: Dictionary=bank.boss_proofs.duplicate(true)
	var old_receipts: Array[String]=bank.boss_receipts.duplicate()
	run=CAMPAIGN.instantiate() as DungeonRun; run.profile=bank; run.world_building_enabled=true; run.starting_inventory=prepared
	run.set("depth_progress_committer",_commit_depth)
	root.add_child(run); current_scene=run; await _step(10)
	run.feedback.hit_stop_seconds=0; run.feedback.enable_global_hitstop(false)
	run.survival.set_enabled(false); run.player.health.minimum_health=1
	run.gear.loot.drop_table=run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance=1.0; run.gear.loot.drop_table.blueprint_chance_total=0.0
	var player_id: int=run.player.get_instance_id()
	var gear_id: int=run.gear.get_instance_id()
	_check(not run.enter_room(0) and not run.enter_room(6),"Depth rejects out-of-range floors without resetting current state")
	for number: int in [1,2,3,4,5]:
		_check(run.room_number==number and run.get("stage")==number,"Independent lifecycle enters depth%d/5" % number)
		_disable_ai(); await _step(10)
		_check(run.room.locked and not run.advance_room(),"Depth%d roster locks progression" % number)
		_check(run.living_enemies().size()==int(Catalog.floor_data(number)["count"]),"Depth%d spawns distinct roster count" % number)
		for enemy: Node2D in run.living_enemies():
			_check(enemy.get_meta(&"custom_boss_visual",false) if number==5 else enemy.get("enemy_type")==Catalog.floor_data(number)["enemy"],"Depth%d actor identity matches its floor" % number)
		await _geometry(number)
		if number<5:
			var before_room: int=run.room.get_instance_id()
			if number==1: allow_commit=false
			await _clear_roster()
			_check(not run.room.locked and run.living_enemies().is_empty(),"Depth%d opens seal only after actual health-death lifecycle" % number)
			if number==1:
				_check(run.has_pending_rewards() and int(run.pending_reward_state()["depth_objective_count"])==1 and not run.advance_room(),"Failed depth committer retains one event and blocks disposal/advance")
				_check(not run.retry_pending_rewards() and run.room.get_instance_id()==before_room,"Failed retry keeps current room and event")
				allow_commit=true
				_check(run.retry_pending_rewards() and events.size()==1 and not run.has_pending_rewards(),"Successful depth retry delivers one bounded event")
				var soul: LootPickup=run.gear.loot.spawn(&"soul",&"souls",Vector2(700,640),5)
				soul.automatic=false
				bank._writer.fault_plan={"write_candidate":true}
				_check(not soul.collect() and soul.save_retry_pending and run.has_pending_rewards(),"Failed permanent pickup uses inherited run escrow")
				_check(soul.get_parent()==run._pending_pickup_root and int(run.pending_reward_state()["pickup_count"])==1,"Pickup survives outside disposable floor loot owner")
				_check(run.retry_pending_rewards() and bank.souls==5 and not run.has_pending_rewards(),"Retry collects inherited soul once through existing writer")
				_check(not soul.collect() and bank.souls==5,"Repeated permanent pickup cannot duplicate soul")
			await _walk(1230)
			_check(run.can_choose_floor_exit(),"Depth%d cleared exit reachable through real walking" % number)
			_check(run.floor_exit.open(),"Depth%d uses existing E-choice owner" % number)
			await _step(3)
			_check(run.floor_exit.heading.text.contains(str(number)+"/5") and not run.floor_exit.notice.text.contains("Golem"),"Depth exit text refers to this expedition")
			run.floor_exit._continue(); await _step(8)
			_check(run.player.get_instance_id()==player_id and run.gear.get_instance_id()==gear_id and run.room.get_instance_id()!=before_room,"Depth%d transition keeps player/gear and replaces room lifetime" % number)
		else:
			var final_boss: BossGolem=run.boss
			final_boss.health.apply_damage(final_boss.health.maximum_health*.6); await _step(5); _disable_ai()
			_check(final_boss.phase==2 and final_boss.phase_two_count==1 and run.living_enemies().size()==3,"Final boss phase two summons two owned guardians once")
			run._summon_adds(); _check(run.living_enemies().size()==3,"Repeated phase signal cannot multiply guardians")
			run.gear.loot.drop_table.none_chance=0.0
			final_boss.health.apply_damage(99999); await _step(8)
			_check(run.portal_active and not run.room.locked and not run.reward_chest.locked and run.living_enemies().is_empty(),"Final boss unlocks chest/return and dissolves its summons")
			var drops: int=run.gear.loot.spawned_total
			run._finish_boss(); await _step(2)
			_check(run.gear.loot.spawned_total==drops and events.size()==6,"Duplicate boss callback keeps finite loot and six depth events")
			_check(bank.boss_proofs==old_proofs and bank.boss_receipts==old_receipts and bank.opening_progress==old_opening,"Depth boss and soul do not grant legacy Golem/opening progress")
			await _walk(980)
			run.gear.loot.rng.seed=4242
			_check(run.reward_chest.interact() and not run.reward_chest.interact(),"Existing large reward chest is reachable and opens once")
			_check(run.gear.loot.spawned_total>drops,"Existing chest creates finite real pickups")
			await _walk(1160)
			_check(run.can_choose_floor_exit() and run.floor_exit.open(),"Five-floor return portal reachable by real input")
			await _step(3)
			_check(not run.floor_exit.continue_button.visible and run.floor_exit.heading.text.contains("U MINH"),"Final choice offers return and named boss context")
			run.floor_exit.close(); await _step(3)
			var returns: Array[int]=[0]
			run.floor_return_requested.connect(func() -> void: returns[0]+=1)
			_check(run.request_floor_return() and run.outcome==&"victory" and returns[0]==1,"Existing return signal produces one terminal victory")
	_check(events.keys().all(func(id: StringName) -> bool: return String(id).begins_with("depth_")),"Depth event namespace stays separate from legacy milestones")
	_release(); run.queue_free(); await _step(8)
	_check(is_equal_approx(Engine.time_scale,1.0),"Depth teardown releases existing modal time claims")
	var output: String=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")+"/depth_campaign_geometry.json"
	var file:=FileAccess.open(output,FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify({"hz":hz,"checks":checks,"failures":failures,"report":report,"limits":"AI isolated and roster deaths by direct health fixture; real walking/jump/choice/pickup/chest, no combat-feel acceptance."},"\t")); file.close()
	root.get_node("AudioManager").call("shutdown")
	print("RESULT DepthCampaign checks=%d failures=%d hz=%d" % [checks,failures,hz])
	quit(0 if failures==0 else 1)
