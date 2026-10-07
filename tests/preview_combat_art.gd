extends SceneTree
## Finite GPU preview on the secondary screen; production profile is untouched.
## Contact captures use the real swept projectile/Hurtbox path, not mock damage.

var campaign: LinearCampaign
var captures: int = 0
var failed: bool = false


func _initialize() -> void:
	Engine.max_fps = 60
	call_deferred("_run")


func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	var bus: int = AudioServer.get_bus_index("DungeonSFX")
	if bus >= 0:
		AudioServer.set_bus_mute(bus, true)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), true)
	if DisplayServer.get_name() == "headless":
		print("FAIL: Combat art preview requires a real GPU display")
		await audio.shutdown()
		quit(1)
		return
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/preview_combat_art.json"
	root.add_child(campaign)
	campaign.content.qa_tools_enabled = true # Explicit private fixture capability.
	current_scene = campaign
	campaign.survival.director.automatic = false
	campaign.feedback.hit_stop_seconds = 0.0
	campaign.player.energy.enabled = true
	campaign.player.energy.set_physics_process(false)
	_freeze_input_and_ai()
	campaign.player.relocate(Vector2(540, 640))
	# Show filled and empty portions of the art bars, plus real Fire/Wind slots.
	campaign.player.health.apply_damage(campaign.player.health.maximum_health * 0.24)
	campaign.player.energy.spend(30.0)
	if not campaign.content.select_recipe(&"firestorm"):
		failed = true
		print("FAIL: HUD preview could not equip the Fire/Wind rune pair")
	_pointer(Vector2(900, 618))
	await _frames(12)
	await _capture("foyer")
	campaign.player.set_physics_process(false)
	await _capture_melee()
	await _capture_actual_spell()
	# Keep a close platform view available for the dummy/HP art pass too.
	campaign.player.equipped_weapon.equip(preload("res://data/weapons/ancient_sword.tres"))
	campaign.content.select_recipe(&"firestorm")
	campaign.player.relocate(Vector2(340, 550))
	_pointer(Vector2(400, 526))
	await _frames(8)
	await _capture("training_dummy")
	await _capture_chest()
	campaign.player.health.reset_health()
	campaign.player.energy.reset()
	campaign.enter_stage(4)
	_freeze_input_and_ai()
	campaign.player.relocate(Vector2(590, 640))
	campaign.player.set_physics_process(false)
	_pointer(Vector2(890, 590))
	await _frames(10)
	await _capture("boss_phase_1")
	# Public health mutation is only a preview setup. It invokes the production
	# threshold, phase signal, minion summon and fixed Boss HUD update path.
	campaign.boss.health.apply_damage(260.0)
	_freeze_input_and_ai()
	await _frames(8)
	if campaign.boss.phase != 2 or campaign.boss.phase_two_count != 1:
		failed = true
		print("FAIL: Preview Boss did not enter phase two exactly once")
	await _capture("boss_phase_2")
	campaign.queue_free()
	await _frames(5)
	await audio.shutdown()
	print("COMBAT ART PREVIEW: %d captures; %s" % [captures, "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)


func _freeze_input_and_ai() -> void:
	campaign.player.suspend_controls(true)
	for enemy: Node2D in campaign.living_enemies():
		enemy.ai_enabled = false
		if enemy is SlimeEnemy:
			(enemy as SlimeEnemy).contact_damage_enabled = false


func _capture_melee() -> void:
	var ids: Array[StringName] = [&"ancient_sword", &"demon_greatsword", &"gale_dual_daggers", &"blood_spiked_whip"]
	var weapon: Weapon = campaign.player.equipped_weapon
	for id: StringName in ids:
		weapon.equip(load("res://data/weapons/%s.tres" % id) as WeaponDefinition)
		_pointer(Vector2(900, 615))
		weapon.start_combo()
		var step: AttackStepDefinition = weapon.definition.combo_steps[0]
		weapon.advance(step.windup_seconds + step.active_seconds * 0.80)
		campaign.presentation.trail.refresh_visual()
		# Player physics is paused, but the rig still reads the committed phase.
		await _frames(4)
		if not campaign.presentation.trail.crescent.visible or not weapon.hitbox.active:
			failed = true
			print("FAIL: %s Active window did not display its silver crescent" % id)
		await _capture("slash_" + str(id))
		weapon.cancel_combo()
	campaign.executor.clear_entities()
	await _frames(3)


func _capture_actual_spell() -> void:
	var enemies: Array[Node2D] = campaign.living_enemies()
	if enemies.is_empty() or not enemies[0] is SlimeEnemy:
		failed = true
		print("FAIL: Projectile contact preview has no real Slime target")
		return
	var target: SlimeEnemy = enemies[0] as SlimeEnemy
	for index: int in enemies.size():
		enemies[index].global_position = Vector2(1010 + index * 55, 640)
	target.global_position = Vector2(825, 640)
	campaign.player.equipped_weapon.equip(preload("res://data/weapons/storm_arcane_staff.tres"))
	for slot: int in GearInventory.CATALYST_INDICES:
		campaign.gear.inventory.equip(slot, &"")
	var controller: ResonanceController = campaign.player.resonance_controller
	controller.reset_runtime()
	_pointer(target.hurtbox.global_position)
	await _frames(5)
	# The moving camera changes the world point under a fixed viewport cursor.
	# Reproject the target immediately before the real cast commit, without a wait.
	_pointer(target.hurtbox.global_position)
	var spell: SpellSnapshot = controller.commit_cast()
	if spell == null or spell.recipe_id != &"basic":
		failed = true
		print("FAIL: Empty Catalyst did not commit the basic spell for GPU preview")
		return
	if spell.target_position.distance_to(target.hurtbox.global_position) > 0.05:
		failed = true
		print("FAIL: Preview cursor conversion missed the intended world target: %s vs %s" % [spell.target_position, target.hurtbox.global_position])
		return
	print("SPELL AIM PREVIEW: origin %s; target %s; direction %s" % [spell.origin, spell.target_position, spell.direction])
	var hit_before: int = target.hit_count
	campaign.executor.spawn_cast(spell)
	await _frames(6)
	var found_wake: bool = false
	for entity: Node in campaign.executor.get_children():
		if entity is SpellProjectile:
			var wake: SpellProjectileVFX = entity.get_node_or_null("SpellTrailVFX") as SpellProjectileVFX
			found_wake = wake != null and wake.points.size() >= 2 and wake.particles.emitting
	if not found_wake:
		failed = true
		print("FAIL: Moving basic projectile did not retain its real GPU wake")
	await _capture("spell_trail")
	var resolved: bool = false
	for frame: int in 90:
		if target.hit_count > hit_before:
			resolved = true
			break
		await _frames(1)
	if not resolved:
		failed = true
		print("FAIL: Preview projectile did not reach the real Slime Hurtbox")
		return
	var gold_jade: bool = false
	for burst: ImpactBurst in campaign.presentation.impacts.get_children():
		gold_jade = gold_jade or burst.element == &"spell_contact"
	if not gold_jade:
		failed = true
		print("FAIL: Resolved projectile contact did not spawn gold/jade GPU sparks")
	# Let the GPU advance the one-shot emitter while the finite impact remains.
	await _frames(3)
	await _capture("spell_contact")
	campaign.executor.clear_entities()
	await _frames(32)


func _capture_chest() -> void:
	if not campaign.enter_stage(2):
		failed = true
		print("FAIL: Chest preview could not enter the real secret room")
		return
	_freeze_input_and_ai()
	var chest: TreasureChest = campaign.secret_chest
	if not is_instance_valid(chest):
		failed = true
		print("FAIL: Secret room did not create its TreasureChest")
		return
	# This is the raised platform inside the authored hidden room. Forty pixels
	# keeps the Player inside the actual E-interaction radius and off its wall.
	campaign.player.relocate(chest.global_position + Vector2(40, 0))
	campaign.player.set_physics_process(false)
	_pointer(chest.global_position + Vector2(0, -18))
	await _frames(10)
	await _capture("chest_closed")
	var drops_before: int = campaign.gear.loot.spawned_total
	if not chest.interact():
		failed = true
		print("FAIL: In-range Player could not open the real secret chest")
		return
	# Catch the genuine chest loot during launch, before auto-pickup at 0.35s.
	await _frames(8)
	if not chest.is_open or campaign.gear.loot.spawned_total <= drops_before or campaign.gear.loot.get_child_count() == 0:
		failed = true
		print("FAIL: Open chest did not retain its real launched loot")
	await _capture("chest_open_loot")


func _pointer(world_position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = campaign.player.aim.get_canvas_transform() * world_position
	# Coordinates are already in the logical viewport. parse_input_event would
	# apply the 1152x648-to-1280x720 window stretch a second time in GPU runs.
	root.push_input(event, true)
	campaign.player.aim.sample_cursor()


func _frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame


func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var base_path: String = ProjectSettings.globalize_path("res://docs/verification/combat_art_" + label)
	var path: String = base_path + ".png"
	var revision: int = 2
	while FileAccess.file_exists(path):
		path = base_path + "_r%d.png" % revision
		revision += 1
	var image: Image = root.get_texture().get_image()
	var status: Error = image.save_png(path)
	if status != OK:
		failed = true
		print("FAIL: %s PNG save: %s" % [label, error_string(status)])
	else:
		print("CAPTURE %s: %s" % [label, path])
	captures += 1
