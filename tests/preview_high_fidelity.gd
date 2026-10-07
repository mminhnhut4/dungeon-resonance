extends "res://tests/preview_starter_character.gd"
## Finite GPU evidence of imported painted VFX and live elemental conditions.


func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	if DisplayServer.get_name() == "headless":
		print("FAIL: High-fidelity preview requires GPU rendering")
		await audio.shutdown()
		quit(1)
		return
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/preview_high_fidelity.json"
	root.add_child(campaign)
	current_scene = campaign
	campaign.survival.director.automatic = false
	_freeze_input_and_ai()
	rig = campaign.player.get_node("Visuals") as PlayerVisualRig
	camera = campaign.player.get_node("Camera2D") as PlayerCamera
	camera.follow_enabled = false
	camera.position = Vector2(0.0, -26.0)
	camera.position_smoothing_enabled = false
	camera.reset_shake()
	campaign.player.relocate(Vector2(540.0, 640.0))
	campaign.player.health.reset_health()
	for enemy: Node2D in campaign.living_enemies():
		enemy.global_position = Vector2(1100, 640)
	_pointer(Vector2(850, 615))
	await _frames(12)
	await _high_capture("foyer_native")
	camera.zoom = Vector2(3.2, 3.2)
	camera.force_update_scroll()
	await _frames(4)
	await _high_capture("starter_closeup")
	campaign.player.set_physics_process(false)
	campaign.gear.inventory.add_rune(&"wind")
	campaign.gear.inventory.equip(3, &"wind")
	var item: GearItem = campaign.gear.inventory.items[campaign.gear.inventory.equipped_weapon_uid]
	var weapon: Weapon = campaign.player.equipped_weapon
	for tier: int in 6:
		item.quality = tier
		campaign.gear.inventory.changed.emit()
		campaign.player.action_state_machine.transition_to(&"ready")
		campaign.player.action_state_machine.transition_to(&"attack")
		var step: AttackStepDefinition = weapon.definition.combo_steps[0]
		weapon.advance(step.windup_seconds + step.active_seconds * 0.70)
		campaign.presentation.trail.refresh_visual()
		await _frames(3)
		_verify(weapon.hitbox.active and campaign.presentation.trail.slash_sprite.visible and weapon.snapshot.cosmetic_quality == tier, "Actual tier %d has imported painted slash inside original active window" % tier)
		await _high_capture("slash_tier_%d" % tier)
		weapon.cancel_combo()
	campaign.player.action_state_machine.transition_to(&"ready")
	item.quality = GearItem.Quality.COMMON
	campaign.gear.inventory.changed.emit()
	campaign.player.set_physics_process(true)
	var status: ElementStatusController = campaign.player.hurtbox.damage_resolver.status_controller as ElementStatusController
	status.clear()
	campaign.player.damage_grace_remaining = 0.0
	campaign.player.hurtbox.set_invulnerable(false)
	var poison_event: DamageEvent = _player_damage(1.0)
	poison_event.poison_stacks = 2
	poison_event.poison_percent = 0.001
	poison_event.poison_seconds = 3.0
	campaign.player.hurtbox.take_damage(poison_event)
	await _frames(42)
	var condition: ElementAfflictionVFX = campaign.player.get_node("ElementAfflictionVFX") as ElementAfflictionVFX
	_verify(condition.poison_visible and condition.poison.emitting, "Real resolved poison enables the painted GPU mist")
	await _high_capture("poison_player")
	status.clear()
	campaign.player.damage_grace_remaining = 0.0
	campaign.player.hurtbox.set_invulnerable(false)
	var fire_event: DamageEvent = _player_damage(1.0)
	fire_event.burn_damage = 0.1
	fire_event.burn_interval = 0.5
	fire_event.burn_duration = 3.0
	campaign.player.hurtbox.take_damage(fire_event)
	await _frames(42)
	_verify(condition.burn_visible and condition.burn.emitting and not condition.poison_visible, "Real resolved burn enables a distinct painted GPU flame")
	await _high_capture("burn_player")
	status.clear()
	var impact: ImpactBurst = campaign.presentation.spawn_impact(campaign.player.global_position + Vector2(43, -20), Color(0.35, 1.0, 0.78), &"wind", Vector2.RIGHT)
	impact.configure_combat(GearItem.Quality.EPIC, true, 2)
	impact.enable_melee_sparks()
	await _frames(3)
	_verify(impact.ground_crack != null and impact.shockwave != null, "Epic confirmed-hit finisher renders localized crack and distortion")
	await _high_capture("epic_impact")
	await _frames(75)
	_verify(not is_instance_valid(impact), "High-tier impact releases all shader/particle owners")
	campaign.player.set_physics_process(true)
	campaign.enter_stage(4)
	_freeze_input_and_ai()
	camera.zoom = Vector2(1.35, 1.35)
	camera.position = Vector2(0, -26)
	campaign.player.relocate(Vector2(720, 640))
	_pointer(Vector2(1050, 590))
	await _frames(10)
	await _high_capture("boss_arena")
	campaign.queue_free()
	await _frames(5)
	await audio.shutdown()
	print("HIGH FIDELITY PREVIEW: %d captures; %s" % [captures, "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)


func _high_capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var capture_image: Image = root.get_texture().get_image()
	var output: String = ProjectSettings.globalize_path("res://docs/verification/high_fidelity_" + label + ".png")
	_verify(capture_image.save_png(output) == OK, "Capture " + output)
	captures += 1
