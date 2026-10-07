extends "res://tests/survival_test_base.gd"
## Actual Hub -> Alpha -> death -> Hub -> campaign startup and wardrobe ownership.

func _initialize() -> void:
	suite = "starter_flow"
	use_neutral_equipment = false
	super._initialize()


func test_system() -> void:
	level.queue_free()
	await _step(4)
	var flow: GameFlow = preload("res://scenes/game_flow.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/starter_flow_%d.json" % Engine.physics_ticks_per_second
	root.add_child(flow)
	current_scene = flow
	await _step(8)
	var hub: SanctuaryHub = flow.active_scene as SanctuaryHub
	var hub_rig: PlayerVisualRig = hub.player.get_node("Visuals") as PlayerVisualRig
	_check(hub.starter_inventory.equipment_uids.size() == 7 and hub.starter_inventory.items.size() == 7, "First-entry Hub displays exactly one owned seven-piece starter kit")
	_check(hub_rig.is_modular_active() and hub_rig._modular_equipment.size() == 6 and not hub_rig.concept_sprite.visible, "First-entry Hub shows the fully dressed modular character")
	_check(hub.player.health.current_health == 115.0 and hub.player.health.maximum_health == 115.0 and hub.player.hurtbox.damage_resolver.armor_rating == 11.0, "Hub uses the confirmed full HP and defense before entering a run")
	_check(hub_rig.find_children("EquipmentVisual", "Node2D", true, false).size() == 1 and hub.starter_visual.weapon_sprite.texture != null, "Hub owns exactly one hand-held Common sword presentation")
	var old_hub_id: int = hub.get_instance_id()
	flow.start_run()
	await _step(20)
	var run: DungeonRun = flow.active_scene as DungeonRun
	run.survival.director.automatic = false
	for enemy: Node2D in run.living_enemies():
		enemy.ai_enabled = false
	_check(not is_instance_id_valid(old_hub_id), "Starting Alpha frees the Hub outfit ledger and presentation owner")
	_check(run.player.health.current_health == 115.0 and run.player.health.maximum_health == 115.0, "Actual GameFlow Alpha startup refills only after the complete fresh-run gear rebuild")
	_check(run.player.hurtbox.damage_resolver.armor_rating == 11.0 and run.player.equipped_weapon.damage_multiplier == 1.2, "Alpha starts with the real cloth armor and glove attack bonus")
	_check((run.player.get_node("Visuals") as PlayerVisualRig)._modular_equipment.size() == 6 and run.gear.inventory.equipment_uids.all(func(uid: int) -> bool: return uid > 0), "Alpha preserves the seven equipped slots and all body clothing groups")
	run.player.health.apply_damage(20.0)
	var hp: float = run.player.health.current_health
	var uids: Array[int] = run.gear.inventory.equipment_uids.duplicate()
	run.enter_room(2)
	await _step(5)
	_check(run.player.health.current_health == hp and run.gear.inventory.equipment_uids == uids, "A room transition keeps wounds and the same equipped UIDs")
	run.survival.director.automatic = false
	for enemy: Node2D in run.living_enemies():
		enemy.ai_enabled = false
	var old_run_id: int = run.get_instance_id()
	run.player.health.apply_damage(999.0)
	await _time(1.4)
	_check(flow.active_scene is SanctuaryHub and not is_instance_id_valid(old_run_id), "Defeat frees the equipped run and returns to the Sanctuary")
	hub = flow.active_scene as SanctuaryHub
	_check(hub.player.health.current_health == 115.0 and hub.starter_inventory.items.size() == 7 and hub.from_defeat, "Defeat Hub restores the single default cloth kit without carrying duplicate run items")
	flow.start_campaign()
	await _step(8)
	var campaign: LinearCampaign = flow.active_scene as LinearCampaign
	campaign.survival.director.automatic = false
	_check(campaign.player.health.current_health == 115.0 and campaign.player.hurtbox.damage_resolver.armor_rating == 11.0 and (campaign.player.get_node("Visuals") as PlayerVisualRig).is_modular_active(), "Actual campaign route starts with the same healthy modular starter kit")
	campaign.finish(&"defeat")
	flow.show_hub(true)
	await _step(8)
	var objects_before: int = 0
	var resources_before: int = 0
	for cycle: int in 6:
		flow.start_run()
		await _step(6)
		(flow.active_scene as DungeonRun).finish(&"defeat")
		flow.show_hub(true)
		await _step(8)
		if cycle == 1:
			objects_before = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources_before = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS: starter Hub objects=%d->%d resources=%d->%d" % [objects_before, objects_after, resources_before, resources_after])
	_check(objects_after <= objects_before and resources_after <= resources_before, "Six dressed Hub/Alpha cycles retain no extra outfit sprites, ledgers or resources after warm-up")
	flow.queue_free()
	await _step(4)
