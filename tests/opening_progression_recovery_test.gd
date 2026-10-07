extends SceneTree
## Real finite chest, Catalyst, victory/defeat, cold reload and native writer faults.
class FaultProfile extends SanctuaryProfile:
	var failure_stage: StringName = &""
	var reject: bool = false
	var writes: int = 0
	func save() -> bool:
		writes += 1
		return super.save()
	func _open_writer(path: String) -> FileAccess:
		var failed: bool = failure_stage == &"write" or (failure_stage == &"decision_write" and path == save_path + ".decision.tmp")
		return null if reject and failed else super._open_writer(path)
	func _copy_file(source: String, target: String) -> Error:
		if reject and profile_version == 1 and failure_stage == &"decision_write": return ERR_CANT_CREATE
		return super._copy_file(source,target)
	func _rename_file(source: String, target: String) -> Error:
		var history_publish: bool = source == save_path + ".decision.tmp" and target == save_path + ".decision" if profile_version == 2 else source == save_path + ".bak.tmp" and target == save_path + ".bak"
		var matches: bool = (failure_stage == &"commit" and source == save_path + ".tmp" and target == save_path) or (failure_stage == &"decision_commit" and history_publish)
		return ERR_CANT_CREATE if reject and matches else super._rename_file(source,target)

var checks: int = 0
var failures: int = 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL",label])

func _step(count: int = 4) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame

func _pause(flow: GameFlow) -> void:
	flow.set_process(false)
	flow.cultivation_session.set_physics_process(false)
	if flow.active_scene is ExteriorHub: flow.active_scene.npc_population.set_process(false)

func _open(id: String, saved_path: String = "") -> GameFlow:
	var flow := GameFlow.new()
	flow.hub_scene = preload("res://scenes/hub/exterior_hub_room.tscn")
	flow.campaign_scene = preload("res://scenes/world_campaign.tscn")
	flow.world_building_enabled = true
	flow.save_path_override = directory+"/"+id+"/profile.json" if saved_path.is_empty() else saved_path
	root.add_child(flow)
	_pause(flow)
	await _step()
	return flow

func _close(flow: GameFlow) -> void:
	flow.queue_free()
	await _step(6)
	_check(is_equal_approx(Engine.time_scale,1.0),"Flow cleanup releases modal time claims")

func _fault(flow: GameFlow) -> FaultProfile:
	var bank := FaultProfile.new()
	bank.save_path = flow.profile.save_path
	_check(bank.load_profile(),"Fault fixture loads the actual committed profile")
	flow.profile = bank
	flow.active_scene.profile = bank
	flow.active_scene.economy.profile = bank
	return bank

func _empty_boss(run: WorldCampaign) -> void:
	run.gear.loot.drop_table = run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance = 1.0
	run.gear.loot.drop_table.blueprint_chance_total = 0.0
	run.enter_stage(4)
	run.feedback.hit_stop_seconds = 0.0
	run.feedback.enable_global_hitstop(false)
	run.boss.health.apply_damage(9999)
	await _step(5)

func _pair_seed(run: WorldCampaign) -> int:
	var probe := LootSpawner.new()
	probe.inventory = run.gear.inventory
	probe.drop_table = run.gear.loot.drop_table
	probe.quality_enabled = run.gear.loot.quality_enabled
	probe.prologue_drops_enabled = run.gear.loot.prologue_drops_enabled
	root.add_child(probe)
	var found: int = -1
	for value: int in 256:
		probe.rng.seed = value+1701
		probe.chest_drop(Vector2.ZERO,false)
		var ids: Array[StringName] = []
		for pickup: LootPickup in probe.get_children():
			if pickup.kind == &"rune": ids.append(pickup.item_id)
		probe.clear()
		if ids.size() == 2 and ids.has(&"fire") and ids.has(&"wind"):
			found = value+1701
			break
	probe.queue_free()
	await _step()
	return found

func _finite_recipe_and_death() -> void:
	var flow: GameFlow = await _open("recipe")
	flow.start_campaign()
	await _step()
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	_check(run != null and run.enter_stage(2),"Existing campaign exploration exposes its existing secret chest")
	var seed_value: int = await _pair_seed(run)
	_check(seed_value >= 0,"A reachable seed yields actual Fire/Wind pickups without inventory grants")
	if seed_value < 0: await _close(flow); return
	run.gear.loot.rng.seed = seed_value
	var chest: TreasureChest = run.secret_chest
	PlayerTravel.relocate(run.player,chest.global_position,PlayerTravel.Kind.INTRA_EXPEDITION)
	_check(chest.interact(),"Real unlocked chest opens within player interaction distance")
	var spawned: int = run.gear.loot.spawned_total
	_check(not chest.interact() and run.gear.loot.spawned_total == spawned,"Repeated real chest interaction cannot spawn another reward")
	var rune_uids: Array[int] = []
	var rune_ids: Array[StringName] = []
	for pickup: LootPickup in run.gear.loot.get_children():
		pickup.automatic = false
		if pickup.kind != &"rune": continue
		rune_ids.append(pickup.item_id)
		_check(pickup.collect() and not pickup.collect(),"Actual rune pickup commits once and rejects repeated collection")
		for item: GearItem in run.gear.inventory.items.values():
			if item.kind == &"rune" and not rune_uids.has(item.uid): rune_uids.append(item.uid)
	_check(rune_ids.size() == 2 and rune_ids.has(&"fire") and rune_ids.has(&"wind") and rune_uids.size() == 2,"Finite chest owns exactly two valid rune UIDs")
	_check(run.gear.inventory.equip_catalyst_set([&"fire",&"wind"]),"Owned chest runes install via the existing Catalyst API")
	var recipe: ResonanceDefinition = run.player.resonance_controller.get_recipe()
	_check(recipe != null and recipe.id == &"firestorm","Actual Player resolves the first exact recipe from collected runes")
	await _empty_boss(run)
	var profile: SanctuaryProfile = flow.profile
	var before_spawn: int = run.gear.loot.spawned_total
	run._boss_defeated()
	await _step()
	_check(profile.boss_proofs[&"golem"] == 1 and profile.boss_receipts.size() == 1 and run.gear.loot.spawned_total == before_spawn,"Repeated real boss callback cannot duplicate proof or loot")
	_check(run.win() and flow.show_hub(false),"Zero-Soul portal victory returns with the surviving collected rune UIDs")
	await _step()
	_pause(flow)
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	_check(rune_uids.all(func(uid: int) -> bool: return hub.gear.inventory.items.has(uid)),"Victory banks exact surviving rune UIDs")
	_check(profile.souls == 0 and not profile.opening_progress["completed"].has("reward_collected") and profile.opening_progress["completed"].has("returned_to_hub"),"Return event does not fabricate zero-Soul collection or currency")
	var rows: Array[Dictionary] = MapQuestProjection.rows(profile,hub.gear.inventory)
	_check(rows[3]["guide"]["status"] == "exact_set" and rows[3]["done"],"Integrated journal guide reads the owned exact recipe and committed return")
	var count: int = hub.gear.inventory.items.size()
	_check(flow.show_hub(false),"Repeated return callback remains safe on the existing Hub")
	await _step()
	_pause(flow)
	_check(flow.active_scene.gear.inventory.items.size() == count and rune_uids.all(func(uid: int) -> bool: return flow.active_scene.gear.inventory.items.has(uid)) and profile.souls == 0 and profile.coins == 0,"Repeated return creates no extra item UID, Soul or coin")
	var path: String = profile.save_path
	await _close(flow)
	flow = await _open("recipe_reload",path)
	hub = flow.active_scene as ExteriorHub
	_check(rune_uids.all(func(uid: int) -> bool: return hub.gear.inventory.items.has(uid)) and hub.player.resonance_controller.get_recipe().id == &"firestorm","Cold reload restores collected UIDs and the exact Catalyst recipe")
	flow.start_campaign()
	await _step()
	run = flow.active_scene as WorldCampaign
	run.player.health.apply_damage(9999)
	_check(flow.show_hub(true),"Actual player death returns through the existing defeat owner")
	await _step()
	_pause(flow)
	hub = flow.active_scene as ExteriorHub
	_check(not hub.gear.inventory.items.values().any(func(item: GearItem) -> bool: return item.kind == &"rune") and rune_uids.all(func(uid: int) -> bool: return not hub.gear.inventory.items.has(uid)),"Death discards carried rune UIDs rather than resurrecting the banked run copy")
	_check(flow.profile.opening_progress["completed"].has("returned_to_hub") and flow.profile.souls == 0 and flow.profile.coins == 0,"Death retains the prior committed milestone without new rewards")
	rows = MapQuestProjection.rows(flow.profile,hub.gear.inventory)
	_check(rows[3]["guide"]["blockers"].has("rune_fire_required") and rows[3]["guide"]["blockers"].has("rune_wind_required") and "rương nhỏ có 2" in rows[3]["guide"]["body"],"Guide after death reports real missing runes and the actual finite source")
	await _close(flow)
	flow = await _open("death_reload",path)
	_check(not flow.active_scene.gear.inventory.items.values().any(func(item: GearItem) -> bool: return item.kind == &"rune") and flow.profile.opening_progress["completed"].has("returned_to_hub"),"Cold reload preserves death losses and the historical return milestone")
	await _close(flow)

func _fresh_defeat() -> void:
	var flow: GameFlow = await _open("fresh_defeat")
	flow.start_campaign()
	await _step()
	flow.active_scene.player.health.apply_damage(9999)
	_check(flow.show_hub(true),"Fresh defeat still returns to the safe Hub")
	await _step()
	_check(not flow.profile.opening_progress["completed"].has("returned_to_hub") and flow.profile.souls == 0,"Fresh defeat fabricates neither successful-run return nor Soul reward")
	await _close(flow)

func _zero_soul_fault(stage: StringName) -> void:
	var flow: GameFlow = await _open("zero_fault_"+String(stage))
	var bank: FaultProfile = _fault(flow)
	flow.start_campaign()
	await _step()
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	await _empty_boss(run)
	_check(run.win() and bank.souls == 0 and bank.boss_proofs[&"golem"] == 1,"%s actual zero-Soul victory precedes return fault" % stage)
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
	var uids: Array = run.gear.inventory.items.keys().duplicate()
	bank.failure_stage = stage; bank.reject = true
	_check(not flow.show_hub(false) and flow.return_save_pending and flow.active_scene == run,"%s failed victory-return write retains the actual completed run" % stage)
	_check(not bank.opening_progress["completed"].has("returned_to_hub") and bank.hub_inventory.is_empty() and run.gear.inventory.items.keys() == uids and FileAccess.get_file_as_bytes(bank.save_path) == bytes,"%s fault rolls milestone/inventory together without phantom commit" % stage)
	var writes: int = bank.writes
	for _index: int in 20: flow._process(1.0); flow.show_hub(false)
	_check(bank.writes == writes,"%s pending return performs no automatic frame/repeated-callback retry" % stage)
	_check(not flow.retry_pending_return() and bank.writes == writes+1,"%s one explicit failed retry makes one transaction attempt" % stage)
	bank.reject = false
	_check(flow.retry_pending_return() and not flow.retry_pending_return(),"%s explicit successful retry clears the pending return exactly once" % stage)
	await _step()
	var reader := SanctuaryProfile.new(); reader.save_path = bank.save_path
	_check(reader.load_profile() and reader.opening_progress["completed"].has("returned_to_hub") and not reader.opening_progress["completed"].has("reward_collected") and reader.souls == 0 and reader.coins == 0 and reader.boss_proofs[&"golem"] == 1 and reader.boss_receipts.size() == 1,"%s cold reload has one committed return/proof and zero fabricated rewards" % stage)
	await _close(flow)

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or DisplayServer.get_name() != "headless":
		print("FAIL: Requires isolated user:// and headless engine"); quit(2); return
	directory = "user://verification/progression_recovery_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	AudioServer.set_bus_mute(0,true)
	await _finite_recipe_and_death()
	await _fresh_defeat()
	for stage: StringName in [&"write",&"decision_write",&"decision_commit",&"commit"]: await _zero_soul_fault(stage)
	print("RESULT OpeningProgressionRecovery checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)
