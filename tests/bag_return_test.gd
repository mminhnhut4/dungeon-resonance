extends SceneTree
var checks: int = 0
var failures: int = 0
var flow: GameFlow

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: ", text)
func _frames(count: int) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame

func _pickup(run: DungeonRun, kind: StringName, id: StringName, count: int, item: GearItem = null) -> bool:
	var loot := LootPickup.new()
	loot.player = run.player
	loot.inventory = run.gear.inventory
	loot.permanent_profile = run.profile
	loot.kind = kind
	loot.item_id = id
	loot.quantity = count
	loot.runtime_item = item
	loot.position = run.player.position
	run.add_child(loot)
	return loot.collect()

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\", "/").begins_with(qa + "/"):
		print("FAIL: isolated QA root required")
		quit(2)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var source := SanctuaryProfile.new()
	source.save_path = "user://verification/bag_return_%d.json" % Time.get_ticks_usec()
	source.coins = 100
	source.material_stash[&"dust"] = 37
	var kit: GearInventory = HubPreparation.starter_inventory()
	kit.items[kit.equipped_weapon_uid].enhancement_level = 4
	kit.materials[&"dust"] = 10
	kit.materials[&"metal"] = 6
	kit.consumables[&"potion"] = 3
	kit.add_rune(&"fire")
	source.hub_inventory = GearInventoryCodec.encode(kit)
	_check(source.save(), "Persist prepared gear and starting materials in isolated profile")
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = source.save_path
	root.add_child(flow)
	current_scene = flow
	await _frames(12)
	flow.start_campaign()
	await _frames(8)
	var run := flow.active_scene as DungeonRun
	_check(run != null and run.gear.inventory.expedition_active, "Actual start boundary records protected materials")
	if run == null:
		flow.queue_free()
		await _frames(4)
		quit(1)
		return
	run.room.process_mode = Node.PROCESS_MODE_DISABLED
	var bag: GearInventory = run.gear.inventory
	_check(bag.spend_material(&"dust", 10), "Consume original carried materials during expedition")
	_check(_pickup(run, &"material", &"dust", 10) and _pickup(run, &"material", &"metal", 4), "Real pickup collectors add new stacks into bag")
	_check(bag.spend_material(&"metal", 5), "Consumption uses new material before remaining protected material")
	_check(_pickup(run, &"coins", &"coins", 11), "Real coin pickup enters expedition wallet")
	_check(_pickup(run, &"rune", &"wind", 1), "Real rune pickup enters owned ledger")
	var loot_inventory := GearInventory.new()
	var weapon: GearItem = loot_inventory.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	weapon.source = &"drop"
	weapon.loot_rolled = true
	weapon.drop_bonus = 0.04
	_check(_pickup(run, &"weapon", weapon.definition_id, 1, weapon), "Real gear pickup preserves rolled UID and properties")
	run.player.health.apply_damage(20)
	_check(run.survival.use_consumable(&"potion") and bag.consumables[&"potion"] == 2, "Consumption uses bag and leaves only unused potions")
	var expected_items: Dictionary = GearInventoryCodec.encode(bag)
	run.player.health.apply_damage(100000)
	_check(run.outcome == &"defeat", "Actual death signal reaches defeat return state")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(flow.profile.save_path)
	flow.profile._writer.fault_plan = {"write_candidate":true}
	_check(not flow.show_hub(true), "Failed return save retains the ended run")
	_check(flow.active_scene == run and bag.run_coins == 11 and bag.materials[&"dust"] == 10 and FileAccess.get_file_as_bytes(flow.profile.save_path) == bytes, "Return failure preserves exact save and live owned items for retry")
	_check(flow.retry_pending_return(), "Explicit return retry commits once")
	await _frames(12)
	var hub := flow.active_scene as PrologueHub
	_check(hub != null, "Retry reaches actual safe Hub")
	var kept: GearInventory = hub.gear.inventory
	_check(not kept.expedition_active and kept.protected_materials.is_empty(), "Successful return ends expedition provenance at the safe Hub")
	_check(kept.equipped_weapon_uid == kit.equipped_weapon_uid and kept.items[kit.equipped_weapon_uid].enhancement_level == 4, "Death keeps original equipped UID and enhancement")
	_check(kept.items.has(weapon.uid) and kept.items[weapon.uid].drop_bonus == 0.04, "Death keeps newly looted weapon and rolled properties")
	_check(GearInventoryCodec.encode(kept)["items"] == expected_items["items"], "All gear and rune records survive exactly")
	_check(kept.materials[&"dust"] == 0 and kept.materials[&"metal"] == 5 and flow.profile.material_stash[&"dust"] == 37, "Only remaining original materials survive, storage unchanged")
	_check(kept.consumables[&"potion"] == 2 and kept.bag[&"fire"] == 1 and kept.bag[&"wind"] == 1, "Unused potions and both original/new runes survive")
	_check(flow.profile.coins == 111 and kept.run_coins == 0, "Defeat banks all carried coins exactly once")
	_check(not flow.retry_pending_return() and flow.profile.coins == 111, "Completed return cannot replay currency credit")
	var loaded := SanctuaryProfile.new()
	loaded.save_path = source.save_path
	_check(loaded.load_profile(), "Cold reader accepts sealed post-death profile")
	var restored: GearInventory = GearInventoryCodec.decode(loaded.hub_inventory)
	_check(restored != null and restored.items.has(weapon.uid) and restored.materials[&"metal"] == 5 and restored.materials[&"dust"] == 0 and loaded.coins == 111, "Cold load preserves death decision and exact currency")
	flow.queue_free()
	await _frames(8)
	print("RESULT bag_return checks=%d failures=%d hz=%d" % [checks, failures, Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)
