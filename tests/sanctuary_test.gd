extends "res://tests/survival_test_base.gd"

func _initialize() -> void:
	suite = "sanctuary"
	super._initialize()


func test_system() -> void:
	level.queue_free()
	await _step(4)
	profile.souls = 0
	profile.unlocked_weapons.assign([&"ancient_sword", &"shadow_dagger"])
	profile.archived_recipes.clear()
	profile.discovered_recipes.clear()
	profile.add_souls(200)
	_check(profile.last_save_ok and FileAccess.file_exists(profile.save_path), "Soul award writes a persistent versioned save")
	_check(not profile.spend(201) and not profile.spend(-1) and profile.souls == 200, "Invalid soul transactions leave the balance unchanged")
	_check(profile.unlock_weapon(&"blade_fan") and profile.souls == 150, "Blacksmith permanently unlocks Blade Fan for fifty souls")
	_check(not profile.unlock_weapon(&"blade_fan") and profile.souls == 150, "Repeated unlock cannot charge again")
	_check(profile.unlock_weapon(&"ritual_staff") and profile.souls == 75, "Staff unlock uses its separate seventy-five-soul cost")
	_check(not profile.archive(&"firestorm"), "Undiscovered recipes cannot be bought")
	profile.discover(&"firestorm")
	_check(profile.archive(&"firestorm") and profile.souls == 70, "Archive stores a discovered recipe for five souls")
	_check(not profile.archive(&"firestorm") and not profile.unlock_weapon(&"unknown"), "Permanent progress rejects duplicates and unknown IDs")
	_check(profile.set_style(&"chaotic") and not profile.set_style(&"unknown"), "Storyteller choices accept only the three supported profiles")
	profile.starting_weapon = &"blade_fan"
	profile.save()
	var loaded := SanctuaryProfile.new()
	loaded.save_path = profile.save_path
	_check(loaded.load_profile() and loaded.souls == 70 and loaded.unlocked_weapons.has(&"ritual_staff"), "A fresh profile restores souls and unlocks from disk")
	_check(loaded.archived_recipes.has(&"firestorm") and loaded.style == &"chaotic" and loaded.starting_weapon == &"blade_fan", "Save restores archive, storyteller and chosen starting weapon")
	# A valid backup is retained before every replacement.
	profile.save()
	var file: FileAccess = FileAccess.open(profile.save_path, FileAccess.WRITE)
	file.store_string("{\"version\":1,\"souls\":\"invalid\",\"weapons\":42}")
	file.close()
	_check(loaded.load_profile() and loaded.souls == 70, "Malformed save schema recovers from the last backup")
	profile.save()
	var flow := preload("res://scenes/game_flow.tscn").instantiate() as GameFlow
	flow.save_path_override = profile.save_path
	root.add_child(flow)
	current_scene = flow
	await _step(5)
	_check(flow.active_scene is SanctuaryHub and flow.profile.souls == 70, "Main scene starts in Sanctuary with persistent currency")
	var hub := flow.active_scene as SanctuaryHub
	_check(hub.start_selector.item_count == 4 and hub.info.text.contains("70"), "Hub UI exposes all unlocked starting weapons and currency")
	flow.start_run()
	await _step(20)
	var run := flow.active_scene as DungeonRun
	_check(run.player.equipped_weapon.definition.id == &"blade_fan" and run.player.available_weapons.size() == 4, "Selected unlock becomes a usable run starting weapon")
	_check(run.survival.director.style == &"chaotic", "Run receives the selected storyteller profile")
	run.survival.director.automatic = false
	for enemy: Node2D in run.living_enemies():
		enemy.ai_enabled = false
	var before: int = run.executor.spawned_projectiles
	Input.action_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")
	await _time(0.2)
	_check(run.executor.spawned_projectiles == before + 3, "Unlocked Blade Fan really launches three branching knives")
	run.player.equipped_weapon.equip(run.survival.weapon_definition(&"ritual_staff"))
	run.player.action_state_machine.transition_to(&"ready")
	before = run.executor.spawned_projectiles
	Input.action_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")
	await _time(0.28)
	_check(run.executor.spawned_projectiles == before + 1, "Unlocked Staff really fires its distinct slow attack")
	var balance: int = flow.profile.souls
	run.enter_room(2)
	await _step(20)
	for enemy: Node2D in run.living_enemies():
		enemy.ai_enabled = false
		if enemy.is_elite:
			enemy.hurtbox.take_damage(_damage(enemy.hurtbox, 999.0))
	await _step(3)
	_check(flow.profile.souls == balance + 3, "Elite kill awards persistent souls exactly once")
	run.gear.modal.open()
	run.player.health.apply_damage(999.0)
	await _time(1.4)
	_check(flow.active_scene is SanctuaryHub and flow.profile.souls == balance + 3, "Death returns to Hub and preserves earned souls")
	_check((flow.active_scene as SanctuaryHub).from_defeat and is_equal_approx(Engine.time_scale, 1.0), "Return closes slow-time modal and labels defeat correctly")
	flow.start_run()
	await _step(20)
	run = flow.active_scene as DungeonRun
	_check(run.player.health.current_health == 115.0 and run.gear.inventory.total_shards() == 0 and run.survival.condition.stress == 0.0, "New run starts fully healthy with the confirmed outfit and resets wounds, stress and temporary inventory")
	_check(flow.profile.archived_recipes.has(&"firestorm") and flow.profile.unlocked_weapons.size() == 4, "Permanent knowledge and weapon lines survive fresh runs")
	run.finish(&"defeat")
	flow.show_hub(true)
	await _step(4)
	for index: int in 2:
		flow.start_run()
		await _step(20)
		(flow.active_scene as DungeonRun).finish(&"defeat")
		flow.show_hub(true)
		await _step(20)
	var baseline: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for index: int in 8:
		flow.start_run()
		await _step(20)
		var active: DungeonRun = flow.active_scene
		active.gear.modal.open()
		active.finish(&"defeat")
		flow.show_hub(true)
		await _step(20)
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= baseline + 2, "Eight Hub/Run cycles retain no actor, inventory or UI Nodes")
	_check(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources + 1, "Hub/Run cycles retain no extra scene resources")
	_check(get_nodes_in_group(&"enemies").is_empty() and get_nodes_in_group(&"loot").is_empty(), "Hub has no leftover dungeon enemies or loot")
	print("STRESS sanctuary objects %d -> %d, resources %d -> %d" % [baseline, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])
	flow.queue_free()
	await _step(4)
