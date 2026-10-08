extends SceneTree
## Real scene ownership and a separate NPC writer failure during floor return.
class FaultNpcIO extends SanctuaryProfile:
	var reject: bool = false
	func _open_writer(path: String) -> FileAccess:
		return null if reject else super._open_writer(path)

var checks: int = 0
var failures: int = 0
var directory: String

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

func _step(count: int = 3) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame

func _open(path: String) -> GameFlow:
	var flow := GameFlow.new()
	flow.hub_scene = preload("res://scenes/hub/exterior_hub_room.tscn")
	flow.campaign_scene = preload("res://scenes/world_campaign.tscn")
	flow.world_building_enabled = true
	flow.save_path_override = path
	root.add_child(flow)
	flow.set_process(false)
	flow.cultivation_session.set_physics_process(false)
	flow.active_scene.npc_population.set_process(false)
	await _step()
	return flow

func _close(flow: GameFlow) -> void:
	flow.queue_free()
	await _step(4)
	_check(TimeScaleClaims.owner_count(self) == 0, "Scene teardown releases modal claims")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--hz=120": Engine.physics_ticks_per_second = 120
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not allowed.is_absolute_path() or not ProjectSettings.globalize_path("user://").replace("\\", "/").begins_with(allowed + "/"):
		print("FAIL: Dedicated QA root required")
		quit(1)
		return
	directory = "user://npc_expedition_%d_%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	DirAccess.make_dir_recursive_absolute(directory)
	var path: String = directory + "/profile.json"
	var flow: GameFlow = await _open(path)
	var victim: String = "pilot_gatherer"
	var life: NpcWorldState = flow.npc_life
	life.receive_hit(victim, 1.0, 0.0)
	var wounded: Dictionary = life.records[victim].duplicate(true)
	_check(wounded["mode"] == "recovering" and wounded["hp"] == 1.0, "Real resident withdraws at one HP")
	_check(flow.show_hub(), "Ordinary Hub rebuild succeeds")
	await _step()
	_check(flow.npc_life.records[victim]["mode"] == "recovering", "Hub rebuild does not count as an expedition")
	await _close(flow)
	flow = await _open(path)
	life = flow.npc_life
	_check(life.records[victim]["mode"] == "recovering" and life.records[victim]["trust"] == wounded["trust"], "Cold reload preserves injury and memory")
	var fault := FaultNpcIO.new()
	life.io = fault
	flow.start_campaign()
	await _step()
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	_check(flow.npc_life == life, "Expedition retains the original NPC owner, without a second writer")
	run.feedback.hit_stop_seconds = 0.0
	run.feedback.enable_global_hitstop(false)
	run.gear.loot.drop_table = run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance = 1.0
	run.gear.loot.drop_table.blueprint_chance_total = 0.0
	for _attempt: int in 4:
		for enemy: Node2D in run.living_enemies(): enemy.health.apply_damage(99999)
		await _step(4)
		if not run.room.locked: break
	_check(not run.room.locked, "Actual enemy deaths unlock the existing first-floor return")
	var pickup: LootPickup = run.gear.loot.spawn(&"rune", &"fire", run.player.position)
	pickup.automatic = false
	_check(pickup.collect(), "One finite rune enters carried inventory")
	pickup = run.gear.loot.spawn(&"coins", &"coins", run.player.position, 11)
	pickup.automatic = false
	_check(pickup.collect(), "One finite coin pickup enters carried inventory")
	var expected: Dictionary = GearInventoryCodec.encode(run.gear.inventory)
	expected["run_coins"] = 0
	PlayerTravel.relocate(run.player, Vector2(1240,640), PlayerTravel.Kind.INTRA_EXPEDITION)
	await _step()
	fault.reject = true
	_check(run.floor_exit.open() and run.request_floor_return(), "Actual floor return reaches the injected NPC writer failure")
	_check(flow.active_scene == run and flow.return_save_error == &"npc_recovery_failed", "Failed recovery retains the completed run and explicit retry")
	_check(life.records[victim]["mode"] == "recovering" and life.records[victim]["hp"] == 1.0, "Failed recovery rolls back injury state")
	_check(flow.profile.coins == 11 and GearInventoryCodec.encode(run.gear.inventory) == expected, "Bank commit is durable while item UIDs remain available for retry")
	_check(not flow.retry_pending_return() and flow.profile.coins == 11 and GearInventoryCodec.encode(run.gear.inventory) == expected, "Repeated failed recovery cannot duplicate coins or discard items")
	var cold_bank := SanctuaryProfile.new()
	cold_bank.save_path = path
	_check(cold_bank.load_profile() and cold_bank.coins == 11 and GearInventoryCodec.encode(GearInventoryCodec.decode(cold_bank.hub_inventory)) == expected, "Cold bank reader already owns the exact coins and item UIDs after NPC-only failure")
	var cold_life := NpcWorldState.new()
	cold_life.save_path = life.save_path
	_check(cold_life.load_state() and cold_life.records[victim]["mode"] == "recovering" and cold_life.records[victim]["trust"] == wounded["trust"], "Known cross-file limit: cold NPC reader retains injury until a later expedition; it cannot invent an uncommitted recovery")
	fault.reject = false
	run.floor_exit.return_button.pressed.emit()
	await _step()
	_check(flow.active_scene is ExteriorHub and not flow.return_save_pending, "Existing retry finishes the safe return")
	var recovered: Dictionary = flow.npc_life.records[victim]
	_check(recovered["mode"] != "recovering" and recovered["hp"] > 1.0, "Expedition recovery restores the same resident")
	for field: String in ["trust", "fear", "debt", "episode", "greeted", "legacy_death"]:
		_check(recovered[field] == wounded[field], "Recovery preserves causal field " + field)
	_check(flow.profile.coins == 11 and GearInventoryCodec.encode(flow.active_scene.gear.inventory) == expected, "Successful recovery transfers exact item UIDs and money once")
	_check(flow.show_hub() and flow.profile.coins == 11, "Repeated Hub callback adds no reward")
	await _close(flow)
	flow = await _open(path)
	_check(flow.npc_life.records[victim]["hp"] > 1.0 and GearInventoryCodec.encode(flow.active_scene.gear.inventory) == expected and flow.profile.coins == 11, "Cold reload matches the committed recovery and bank")
	await _close(flow)
	print("NPC EXPEDITION RECOVERY: %d/%d" % [checks-failures, checks])
	quit(0 if failures == 0 else 1)
