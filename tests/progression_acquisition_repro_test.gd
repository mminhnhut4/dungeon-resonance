extends SceneTree
## Regression expectations on an unchanged private155 copy; two gaps must fail.
var checks: int = 0
var failures: int = 0
var directory: String
var observations: Dictionary = {}

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL",label])

func _step(count: int) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame

func _has_runes(inventory: GearInventory) -> bool:
	return inventory.items.values().any(func(item: GearItem) -> bool: return item.kind == &"rune")

func _rune_pickups(spawner: LootSpawner) -> int:
	return spawner.get_children().filter(func(node: Node) -> bool: return node is LootPickup and node.kind == &"rune").size()

func _acquisition_gap() -> void:
	var profile := SanctuaryProfile.new()
	var inventory: GearInventory = HubPreparation.starter_inventory(profile)
	_check(not _has_runes(inventory),"Current starter has no rune grant")
	var spawner := LootSpawner.new()
	spawner.inventory = inventory
	spawner.permanent_profile = profile
	spawner.drop_table = preload("res://data/loot/world_drop_table.tres").duplicate(true) as DropTableResource
	spawner.drop_table.none_chance = 0.0
	spawner.drop_table.blueprint_chance_total = 0.0
	root.add_child(spawner)
	var world_runes: int = 0
	var other_pickups: int = 0
	for seed_value: int in 32:
		spawner.rng.seed = seed_value + 701
		for enemy_id: StringName in [&"slime",&"ancient_guard",&"bloodwing_bat",&"sword_wraith",&"runic_champion",&"golem"]:
			spawner.enemy_drop(Vector2.ZERO,enemy_id,enemy_id == &"runic_champion",enemy_id == &"golem")
			world_runes += _rune_pickups(spawner)
			other_pickups += spawner.get_child_count()
			spawner.clear()
		spawner.chest_drop(Vector2.ZERO,false)
		world_runes += _rune_pickups(spawner); other_pickups += spawner.get_child_count(); spawner.clear()
		spawner.chest_drop(Vector2.ZERO,true)
		world_runes += _rune_pickups(spawner); other_pickups += spawner.get_child_count(); spawner.clear()
	_check(other_pickups > 0,"World loot fixture actually executes 256 nonempty enemy/chest calls")
	_check(world_runes > 0,"Fresh player has a natural RuneShard source in current world loot")
	spawner.drop_table = null
	spawner.rng.seed = 701
	spawner.chest_drop(Vector2.ZERO,false)
	var legacy_runes: int = _rune_pickups(spawner)
	_check(legacy_runes == 2,"Existing legacy small chest already defines two rune drops")
	spawner.clear()
	spawner.chest_drop(Vector2.ZERO,true)
	_check(_rune_pickups(spawner) == 3,"Existing legacy large chest already defines three rune drops")
	observations["rune_acquisition"]={"world_loot_calls":256,"world_runes":world_runes,"world_other_pickups":other_pickups,"legacy_small_chest_runes":legacy_runes,"starter_has_runes":_has_runes(inventory)}
	spawner.queue_free()
	await _step(4)

func _zero_soul_victory() -> void:
	var flow := GameFlow.new()
	flow.hub_scene = preload("res://scenes/hub/exterior_hub_room.tscn")
	flow.campaign_scene = preload("res://scenes/world_campaign.tscn")
	flow.world_building_enabled = true
	flow.save_path_override = directory + "/zero_soul/profile.json"
	root.add_child(flow)
	await _step(4)
	flow.start_campaign()
	await _step(4)
	var run: WorldCampaign = flow.active_scene as WorldCampaign
	_check(run != null,"Actual155 GameFlow starts the existing world campaign")
	if run == null: flow.queue_free(); await _step(4); return
	run.gear.loot.drop_table = run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance = 1.0
	run.gear.loot.drop_table.blueprint_chance_total = 0.0
	run.enter_stage(4)
	run.feedback.hit_stop_seconds = 0.0
	run.feedback.enable_global_hitstop(false)
	run.boss.health.apply_damage(9999)
	await _step(5)
	var profile: SanctuaryProfile = flow.profile
	_check(run.portal_active and profile.boss_proofs[&"golem"] == 1 and profile.opening_progress["completed"].has("golem_defeated"),"Real Golem death commits proof and opens the existing victory portal")
	_check(run.gear.loot.get_child_count() == 0 and profile.souls == 0 and not profile.opening_progress["completed"].has("reward_collected"),"Existing empty boss gate produces no Soul or fabricated collection milestone")
	_check(run.win(),"Actual portal victory completes with zero Souls")
	_check(flow.show_hub(false),"Completed zero-Soul run successfully returns through the real owner")
	await _step(4)
	_check(profile.opening_progress["completed"].has("returned_to_hub"),"Successful completed run records return independently of chance currency")
	_check(profile.souls == 0 and profile.coins == 0 and not profile.opening_progress["completed"].has("reward_collected"),"Return credits no missing Soul/coins or false collected reward")
	var path: String = profile.save_path
	var reader := SanctuaryProfile.new()
	reader.save_path = path
	_check(reader.load_profile(),"Zero-Soul victory profile cold reloads through existing writer")
	_check(reader.opening_progress["completed"].has("returned_to_hub"),"Completed zero-Soul return milestone survives cold reload")
	_check(reader.souls == 0 and reader.boss_proofs[&"golem"] == 1 and reader.boss_receipts.size() == 1,"Cold reload keeps exact zero currency and one proof receipt")
	observations["zero_soul_victory"]={"outcome":"victory","actual_hub":flow.active_scene is PrologueHub,"souls":reader.souls,"coins":reader.coins,"proofs":reader.boss_proofs[&"golem"],"completed":reader.opening_progress["completed"].duplicate(),"boss_receipts":reader.boss_receipts.size()}
	flow.queue_free()
	await _step(6)
	_check(is_equal_approx(Engine.time_scale,1.0),"Teardown releases modal time claims")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or DisplayServer.get_name() != "headless":
		print("FAIL: Requires isolated user:// and headless engine"); quit(2); return
	directory = "user://verification/progression_repro_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	AudioServer.set_bus_mute(0,true)
	await _acquisition_gap()
	await _zero_soul_victory()
	print("PROGRESSION_REPRO: "+JSON.stringify(observations))
	print("RESULT ProgressionAcquisitionRepro checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)
