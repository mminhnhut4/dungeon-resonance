extends SceneTree
## Bounded real loot/death/pickup checks; comparison is per-kill seeded, not a statistical estimate.
var checks: int = 0
var failures: int = 0
var hz: int = 60
var expected_chance: float = 0.15
var label: String = "candidate60"
var samples: Array[Dictionary] = []
var results: Array[Dictionary] = []
const SAMPLE_SEEDS: int = 64
const GEAR_IDS: Array[StringName] = [&"ancient_sword", &"shadow_dagger", &"storm_arcane_staff", &"starter_top", &"starter_gloves"]

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz = int(argument.trim_prefix("--hz="))
		if argument.begins_with("--expected-chance="): expected_chance = float(argument.trim_prefix("--expected-chance="))
		if argument.begins_with("--label="): label = argument.trim_prefix("--label=")
	Engine.physics_ticks_per_second = hz
	call_deferred("_run")

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition: failures += 1
	results.append({"pass": condition, "description": description})
	print("%s: %s" % ["PASS" if condition else "FAIL", description])

func _frames(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func _disable_pickup(pickup: LootPickup) -> void:
	pickup.automatic = false
	pickup.set_physics_process(false)

func _spawner() -> LootSpawner:
	var loot := LootSpawner.new()
	loot.inventory = GearInventory.new()
	loot.permanent_profile = SanctuaryProfile.new()
	loot.permanent_profile.save_path = "user://verification/enemy_loot/%s/unused.json" % label
	loot.drop_table = preload("res://data/loot/world_drop_table.tres").duplicate(true) as DropTableResource
	loot.pickup_spawned.connect(_disable_pickup)
	root.add_child(loot)
	return loot

func _empty(loot: LootSpawner) -> void:
	for pickup: Node in loot.get_children():
		loot.remove_child(pickup)
		pickup.free()

func _snapshot(loot: LootSpawner) -> Array[Dictionary]:
	var trace: Array[Dictionary] = []
	for pickup: LootPickup in loot.get_children():
		var row: Dictionary = {"kind": str(pickup.kind), "id": str(pickup.item_id), "quantity": pickup.quantity, "quality": pickup.quality}
		if pickup.runtime_item != null:
			var item: GearItem = pickup.runtime_item
			row["gear"] = {"kind": str(item.kind), "id": str(item.definition_id), "quality": item.quality, "source": str(item.source), "broken": item.broken, "rolled": item.loot_rolled, "bonus": item.drop_bonus, "affix": str(item.affix_id), "affix_value": item.affix_value}
		trace.append(row)
	return trace

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\", "/").begins_with(qa + "/"), "Synthetic user:// is isolated before any native scene/save")
	if failures > 0: quit(1); return
	AudioServer.set_bus_mute(0, true)
	_test_seeded_loot()
	await _test_native_lifecycle()
	_check(not paused and is_equal_approx(Engine.time_scale, 1.0), "Teardown retains normal pause/time scale")
	_check(get_nodes_in_group(&"loot").is_empty() and get_nodes_in_group(&"enemies").is_empty(), "Room-owned enemies/pickups are released")
	DirAccess.make_dir_recursive_absolute("user://verification")
	var file := FileAccess.open("user://verification/enemy_loot_%s.json" % label, FileAccess.WRITE)
	_check(file != null, "Evidence file opens in isolated user://")
	if file != null:
		file.store_string(JSON.stringify({"label": label, "hz": hz, "checks": checks, "failures": failures, "gear_gate": MaterialCatalog.BROKEN_GEAR_DROP_CHANCE, "marginal_world_gear": 0.65 * MaterialCatalog.BROKEN_GEAR_DROP_CHANCE, "seeds_per_type": SAMPLE_SEEDS, "samples": samples, "results": results, "gpu": false}, "\t"))
		file.close()
	print("RESULT EnemyLootRate checks=%d failures=%d hz=%d chance=%.3f label=%s" % [checks, failures, hz, MaterialCatalog.BROKEN_GEAR_DROP_CHANCE, label])
	await root.get_node("AudioManager").shutdown()
	quit(0 if failures == 0 else 1)

func _test_seeded_loot() -> void:
	var loot := _spawner()
	var table: DropTableResource = loot.drop_table
	_check(MaterialCatalog.BROKEN_GEAR_DROP_CHANCE > 0.0 and MaterialCatalog.BROKEN_GEAR_DROP_CHANCE < 1.0 and is_equal_approx(MaterialCatalog.BROKEN_GEAR_DROP_CHANCE, expected_chance), "Existing equipment gate has the requested bounded value")
	_check(is_equal_approx(table.none_chance, 0.35) and is_equal_approx(table.stone_chance, 0.12) and is_equal_approx(table.blueprint_chance_total, 0.005), "Shared empty/material, stone and eligible blueprint probabilities retain baseline")
	_check(table.regular_souls == 1 and table.elite_souls == 3 and table.boss_souls == 25 and MaterialCatalog.CRYSTAL_SELL_PRICE == 5 and is_equal_approx(MaterialCatalog.ESSENCE_DROP_CHANCE, 0.15), "Soul quantities, sale price and legacy essence rate retain baseline")
	for specification: Dictionary in [{"type": "regular", "id": &"ancient_guard", "elite": false, "boss": false, "souls": 1}, {"type": "elite", "id": &"runic_champion", "elite": true, "boss": false, "souls": 3}, {"type": "boss", "id": &"golem", "elite": false, "boss": true, "souls": 25}]:
		var valid: bool = true
		var gear_count: int = 0
		var first_trace: Array[Dictionary] = []
		for seed: int in SAMPLE_SEEDS:
			_empty(loot)
			loot.rng.seed = 2026100500 + seed
			loot.enemy_drop(Vector2(600, 640), specification["id"], specification["elite"], specification["boss"])
			var per_kill: int = 0
			for pickup: LootPickup in loot.get_children():
				valid = valid and pickup.quantity > 0 and pickup.quantity <= MaterialCatalog.MAX_COUNT and pickup.item_id != &"origin_divine_stone"
				if pickup.kind == &"soul": valid = valid and pickup.quantity == specification["souls"]
				if pickup.kind == &"coins": valid = valid and pickup.quantity >= 1 and pickup.quantity <= 3
				if pickup.kind == &"material": valid = valid and pickup.item_id in MaterialCatalog.IDS
				if pickup.runtime_item != null:
					var item: GearItem = pickup.runtime_item
					per_kill += 1
					valid = valid and item.uid > 0 and item.definition_id in GEAR_IDS and item.quality == GearItem.Quality.COMMON and item.broken and item.loot_rolled and item.source == &"drop"
					valid = valid and (item.drop_bonus >= 0.03 and item.drop_bonus <= 0.08 if item.kind == &"weapon" else is_zero_approx(item.drop_bonus))
				valid = valid and per_kill <= 1
			gear_count += per_kill
			var trace: Array[Dictionary] = _snapshot(loot)
			if seed == 0: first_trace = trace
			samples.append({"type": specification["type"], "seed": 2026100500 + seed, "pickups": trace})
		_empty(loot)
		loot.rng.seed = 2026100500
		loot.enemy_drop(Vector2(600, 640), specification["id"], specification["elite"], specification["boss"])
		_check(_snapshot(loot) == first_trace, "%s: same seeded kill replays item/affix values (UID excluded)" % specification["type"])
		_check(valid and gear_count > 0, "%s: 64 bounded kills retain one equipment maximum, approved Common broken pool and quantity limits (%d gear)" % [specification["type"], gear_count])
	_empty(loot)
	table.none_chance = 1.0
	table.blueprint_chance_total = 0.0
	loot.rng.seed = 17
	loot.enemy_drop(Vector2.ZERO, &"golem", false, true)
	_check(loot.get_child_count() == 0, "A forced empty boss roll still awards no gear, Soul, coins or materials")
	table.blueprint_chance_total = 1.0
	loot.enemy_drop(Vector2.ZERO, &"runic_champion", true, false)
	_check(loot.get_child_count() == 1 and (loot.get_child(0) as LootPickup).kind == &"blueprint", "Eligible blueprint remains independent of the empty-material gate")
	_empty(loot)
	loot.enemy_drop(Vector2.ZERO, &"ancient_guard", false, false)
	_check(loot.get_child_count() == 0, "Ordinary enemies remain ineligible for blueprints")
	loot.drop_table = null
	loot.prologue_drops_enabled = true
	loot.crystal_drops_enabled = true
	var legacy_valid: bool = true
	var legacy_gear: int = 0
	for seed: int in SAMPLE_SEEDS:
		_empty(loot)
		loot.drop_serial = 0
		loot.rng.seed = 2026100500 + seed
		loot.enemy_drop(Vector2.ZERO)
		var counts: Dictionary = {"rune": 0, "consumable": 0, "crystal": 0, "gear": 0}
		for pickup: LootPickup in loot.get_children():
			if pickup.kind == &"rune": counts["rune"] += 1
			if pickup.kind == &"consumable": counts["consumable"] += pickup.quantity
			if pickup.item_id == &"crystal": counts["crystal"] += pickup.quantity
			if pickup.runtime_item != null: counts["gear"] += 1
		legacy_valid = legacy_valid and counts["rune"] == 1 and counts["consumable"] == 1 and counts["crystal"] == 1 and counts["gear"] <= 1
		legacy_gear += counts["gear"]
		samples.append({"type": "legacy", "seed": 2026100500 + seed, "pickups": _snapshot(loot)})
	_check(legacy_valid and legacy_gear > 0, "Legacy prologue keeps one rune, potion and crystal; optional equipment uses the same gate (%d gear)" % legacy_gear)
	loot.drop_table = preload("res://data/loot/world_drop_table.tres").duplicate(true) as DropTableResource
	var chest_valid: bool = true
	for large: bool in [false, true]:
		for seed: int in 4:
			_empty(loot)
			loot.rng.seed = 2026100500 + seed
			loot.chest_drop(Vector2.ZERO, large)
			var rune_count: int = 0
			var gear_count: int = 0
			var material_or_gear: int = 0
			for pickup: LootPickup in loot.get_children():
				if pickup.kind == &"rune": rune_count += 1
				if pickup.kind == &"material":
					material_or_gear += 1
					chest_valid = chest_valid and pickup.quantity >= 3 and pickup.quantity <= 5 and pickup.item_id != &"origin_divine_stone"
				if pickup.runtime_item != null:
					gear_count += 1
					material_or_gear += 1
					chest_valid = chest_valid and pickup.quality == GearItem.Quality.RARE
			chest_valid = chest_valid and rune_count == (3 if large else 2) and gear_count <= 1 and material_or_gear >= (4 if large else 3) and material_or_gear <= (6 if large else 5)
			samples.append({"type": "large_chest" if large else "chest", "seed": 2026100500 + seed, "pickups": _snapshot(loot)})
	_check(chest_valid, "Native chest output keeps finite rune counts, material quantities and at most one Rare equipment")
	loot.free()

func _test_native_lifecycle() -> void:
	var run := preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	run.profile = SanctuaryProfile.new()
	run.profile.save_path = "user://verification/enemy_loot/%s/native.json" % label
	run.world_building_enabled = true
	run.run_seed = 20261005
	root.add_child(run)
	current_scene = run
	run.survival.set_enabled(false)
	run.player.controls_enabled = false
	run.feedback.hit_stop_seconds = 0.0
	run.feedback.enable_global_hitstop(false)
	run.gear.loot.pickup_spawned.connect(_disable_pickup)
	for enemy: Node2D in run.living_enemies(): enemy.set("ai_enabled", false)
	await _frames(3)
	var guard: BaseEnemy
	var slime: SlimeEnemy
	for enemy: Node2D in run.living_enemies():
		if enemy is BaseEnemy and guard == null: guard = enemy as BaseEnemy
		if enemy is SlimeEnemy: slime = enemy as SlimeEnemy
	_check(guard != null and slime != null, "Actual seeded opening contains native monster and slime death hooks")
	if guard != null:
		var before_deaths: int = run.world_deaths
		guard.health.apply_damage(99999.0)
		run._world_enemy_died(guard)
		await _frames(2)
		var total: int = run.gear.loot.spawned_total
		var state: int = run.gear.loot.rng.state
		run._world_enemy_died(guard)
		await _frames(2)
		_check(run.world_deaths == before_deaths + 1 and run.processed_deaths.has(guard.get_instance_id()) and run.gear.loot.spawned_total == total and run.gear.loot.rng.state == state, "Real monster death plus repeated callbacks spends one loot transaction and no extra RNG")
	if slime != null:
		var before_deaths: int = run.world_deaths
		slime.health.apply_damage(99999.0)
		run._enemy_died(slime)
		await _frames(2)
		var total: int = run.gear.loot.spawned_total
		var state: int = run.gear.loot.rng.state
		run._enemy_died(slime)
		await _frames(2)
		_check(run.world_deaths == before_deaths + 1 and run.gear.loot.spawned_total == total and run.gear.loot.rng.state == state, "Real slime death plus repeated callbacks spends one loot transaction and no extra RNG")
	var previous_room: int = run.room.get_instance_id()
	_check(run.enter_stage(3), "Native stage transition succeeds")
	for enemy: Node2D in run.living_enemies(): enemy.set("ai_enabled", false)
	var total: int = run.gear.loot.spawned_total
	var state: int = run.gear.loot.rng.state
	run._spawn_world_loot(Vector2.ZERO, &"ancient_guard", false, previous_room)
	_check(run.gear.loot.spawned_total == total and run.gear.loot.rng.state == state, "Stale room death cannot issue loot after transition")
	await _test_pickup_and_save(run)
	_check(run.enter_stage(4), "Actual Golem stage loads for native reward callback")
	run.boss.set_physics_process(false)
	run.boss.set_process(false)
	run.gear.loot.drop_table = run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance = 0.0
	run.gear.loot.drop_table.blueprint_chance_total = 0.0
	var before_proofs: int = run.profile.boss_proofs[&"golem"]
	run.boss.health.apply_damage(99999.0)
	run._boss_defeated()
	run._boss_defeated()
	await _frames(2)
	total = run.gear.loot.spawned_total
	state = run.gear.loot.rng.state
	var receipt: String = run._boss_receipt
	var soul_pickups: int = 0
	for pickup: LootPickup in run.gear.loot.get_children():
		if pickup.kind == &"soul" and pickup.quantity == 25: soul_pickups += 1
	run._boss_defeated()
	await _frames(2)
	_check(run.portal_active and not run.reward_chest.locked and soul_pickups == 1 and run.gear.loot.spawned_total == total and run.gear.loot.rng.state == state and run.profile.boss_proofs[&"golem"] == before_proofs + 1 and run._boss_receipt == receipt, "Native repeated boss callbacks retain one loot transaction, one proof and unlocked chest/exit")
	var reader := SanctuaryProfile.new()
	reader.save_path = run.profile.save_path
	_check(reader.load_profile() and not reader.record_boss_defeat(receipt) and reader.boss_proofs[&"golem"] == before_proofs + 1, "Reloaded boss receipt rejects a repeated proof reward")
	current_scene = null
	run.queue_free()
	await _frames(4)

func _test_pickup_and_save(run: WorldCampaign) -> void:
	var inventory := GearInventory.new()
	for index: int in GearInventory.EQUIPMENT_BAG_CAPACITY: inventory.add_item(&"weapon", &"ancient_sword")
	var loot := _spawner()
	loot.player = run.player
	loot.inventory = inventory
	loot.rng.seed = 20261005
	var rolled: GearItem = loot._broken_drop()
	var pickup: LootPickup = loot.spawn_gear(rolled, run.player.global_position)
	var duplicate_pickup: LootPickup = loot.spawn_gear(rolled, run.player.global_position)
	var frozen: Dictionary = _snapshot(loot)[0]["gear"].duplicate(true)
	_check(pickup != null and not pickup.collect() and not pickup.collected_once and pickup.runtime_item.uid == rolled.uid and _snapshot(loot)[0]["gear"] == frozen, "Full equipment bag leaves the exact rolled pickup available without losing/rerolling its UID")
	var released_uid: int = inventory.equipment_bag_uids()[0]
	inventory.items.erase(released_uid)
	_check(pickup.collect() and not pickup.collect() and inventory.items.has(rolled.uid) and inventory.equipment_bag_uids().size() == GearInventory.EQUIPMENT_BAG_CAPACITY, "Making room retries and collects the same equipment UID exactly once")
	inventory.items.erase(inventory.equipment_bag_uids()[0])
	_check(not duplicate_pickup.collect() and not duplicate_pickup.collected_once and inventory.items.has(rolled.uid), "A second pickup carrying the owned UID cannot grant duplicate equipment")
	var bank := SanctuaryProfile.new()
	bank.save_path = "user://verification/enemy_loot/%s/gear.json" % label
	bank.hub_inventory = GearInventoryCodec.encode(inventory)
	_check(GearInventoryCodec.valid(bank.hub_inventory) and bank.save(), "Collected equipment commits through the existing safe-Hub inventory codec")
	var reader := SanctuaryProfile.new()
	reader.save_path = bank.save_path
	var loaded: bool = reader.load_profile()
	var restored: GearInventory = GearInventoryCodec.decode(reader.hub_inventory) if loaded else null
	var item: GearItem = restored.items.get(rolled.uid) if restored != null else null
	_check(item != null and item.uid == rolled.uid and item.definition_id == rolled.definition_id and item.quality == rolled.quality and item.broken == rolled.broken and item.loot_rolled == rolled.loot_rolled and is_equal_approx(item.drop_bonus, rolled.drop_bonus) and item.affix_id == rolled.affix_id and is_equal_approx(item.affix_value, rolled.affix_value), "Real save/load retains equipment identity, broken quality and frozen affix roll")
	if restored != null:
		duplicate_pickup.inventory = restored
		_check(not duplicate_pickup.collect() and restored.items.size() == inventory.items.size(), "A saved/loaded owned UID still rejects duplicate collection")
	loot.queue_free()
	await _frames(2)
