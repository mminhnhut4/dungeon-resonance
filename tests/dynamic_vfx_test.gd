extends "res://tests/survival_test_base.gd"

func _damage(target: Hurtbox, amount: float, heavy: bool = false) -> DamageEvent:
	var event: DamageEvent = super._damage(target,amount,heavy)
	event.source_id=level.get_instance_id()
	return event
## Public movement input and finite cosmetic clocks, not duplicated damage logic.

func _initialize() -> void:
	suite = "dynamic_vfx"
	super._initialize()

func test_system() -> void:
	var presentation: SlicePresentation = level.presentation
	var collision: CollisionShape2D = player.get_node("BodyCollision")
	var shape: Shape2D = collision.shape
	var local_collision: Transform2D = collision.transform
	var hurt_shape: Shape2D = player.hurtbox.get_node("CollisionShape2D").shape
	var before: int = presentation.foot_dust_count
	await _key(KEY_SHIFT)
	_check(presentation.foot_dust_count == before + 1, "Real dash input produces exactly one cosmetic foot puff")
	_check(presentation.foot_dust.get_child_count() == 1, "Dash has one finite room-owned emitter")
	var puff: FootstepDust = presentation.foot_dust.get_child(0) as FootstepDust
	_check(puff.particles.amount == 4 and puff.particles.one_shot and not puff.particles.local_coords, "Dust emits four world-space one-shot motes")
	_check(not puff.particles.emitting and puff.particles.texture == FootstepDust.TEXTURE, "Headless dust keeps the shared native PNG without GPU emission")
	_check(puff.get_children().all(func(child: Node) -> bool: return not child is CollisionObject2D and not child is Light2D), "Dust adds neither collision nor light passes")
	await _time(0.45)
	_check(presentation.foot_dust.get_child_count() == 0, "Dash smoke expires without waiting for GPU finished")
	before = presentation.foot_dust_count
	await _key(KEY_SPACE)
	_check(player.velocity.y < 0.0, "Jump fixture uses the real variable-jump motor")
	await _time(0.8)
	_check(player.motor.is_grounded() and presentation.foot_dust_count == before + 2, "A real jump-to-floor cycle creates one takeoff and one landing puff")
	await _time(0.3)
	_check(presentation.foot_dust_count == before + 2, "Standing on the floor does not repeat takeoff or landing smoke")
	var pool_origin: Vector2 = presentation.foot_dust.position
	presentation.foot_dust.position = Vector2(150, 80)
	var placed: FootstepDust = presentation.spawn_foot_dust(Vector2(520, 640))
	_check(placed.global_position.is_equal_approx(Vector2(520, 640)), "Configure-before-attach preserves world foot contact under a transformed pool")
	presentation.foot_dust.position = pool_origin
	for index: int in 25:
		presentation.spawn_foot_dust(Vector2(520, 640), Vector2.RIGHT)
	_check(presentation.foot_dust.get_child_count() == SlicePresentation.MAX_FOOTSTEP_DUST, "Spam keeps at most eight finite smoke owners")
	await _time(0.7)
	_check(presentation.foot_dust.get_child_count() == 0, "All smoke owners retire after the finite lifetime")
	_check(collision.shape == shape and collision.transform.is_equal_approx(local_collision) and player.hurtbox.get_node("CollisionShape2D").shape == hurt_shape, "Dash/jump/smoke retain the original body and hurtbox resources/transforms")
	var weapon: Weapon = player.equipped_weapon
	weapon.equip(preload("res://data/weapons/ancient_sword.tres"))
	weapon.start_combo()
	var step: AttackStepDefinition = weapon.definition.combo_steps[0]
	weapon.advance(step.windup_seconds + step.active_seconds * 0.5)
	var trail: WeaponTrail = presentation.trail
	trail.refresh_visual()
	_check(trail.crescent.visible and trail.crescent_ink.visible and weapon.hitbox.active, "Silver crescent and dark ink outline share the real active weapon window")
	_check(trail.crescent.mesh == trail.crescent_ink.mesh and trail.crescent_vertex_count == 66, "Outline reuses one bounded mesh rather than spawning attack particles or textures")
	_check(is_equal_approx(WeaponTrail.CRESCENT_SWEEP, deg_to_rad(120)) and is_equal_approx(WeaponTrail.CRESCENT_SWEEP_SECONDS, 0.12), "Cosmetic slash sweeps 120 degrees over its authored 0.12-second presentation clock")
	weapon.cancel_combo()
	trail.refresh_visual()
	_check(not trail.crescent.visible and not trail.crescent_ink.visible and not weapon.hitbox.active, "Cancel retires both mesh layers with the original hitbox")
	var burst: ImpactBurst = presentation.spawn_impact(Vector2(520, 610), Color.WHITE, &"fire", Vector2.RIGHT)
	burst.enable_melee_sparks()
	var behavior: ParticleProcessMaterial = burst.particles.process_material
	_check(burst.particles.amount == 10 and behavior.direction.x < 0 and behavior.color.r > behavior.color.b, "Melee contact emits ten warm shards opposite the strike")
	var dummy: TrainingDummy = level.dummy_a
	var skin: PropSpriteSkin = dummy.get_node("PropSpriteSkin") as PropSpriteSkin
	var flash_material: ShaderMaterial = skin.sprite.material as ShaderMaterial
	_check(flash_material.shader.resource_path == "res://shaders/hit_flash.gdshader", "Dummy uses the shared alpha-preserving hit flash shader")
	dummy.hurtbox.take_damage(_damage(dummy.hurtbox, 3))
	skin.refresh_skin()
	_check(float(flash_material.get_shader_parameter("flash")) == 1.0, "Resolved damage activates the initial white flash")
	await _time(0.1)
	skin.refresh_skin()
	_check(float(flash_material.get_shader_parameter("flash")) == 0.0, "White flash expires before the remaining hurt tint")
	await _test_boss_hud_lifetime()


func _test_boss_hud_lifetime() -> void:
	var run: DungeonRun = preload("res://scenes/dungeon_run.tscn").instantiate()
	run.profile = SanctuaryProfile.new()
	run.profile.save_path = "user://verification/dynamic_vfx_boss_hud_%d.json" % Engine.physics_ticks_per_second
	root.add_child(run)
	run.survival.set_enabled(false)
	run.feedback.hit_stop_seconds = 0.0
	run.player.set_physics_process(false)
	run.enter_room(3)
	var hud: ArtHUD = run.presentation.art_hud
	hud.set_process(false) # Reproduce the stale getter once, without flooding logs.
	await _step(3)
	var boss: BossGolem = run.boss
	var boss_instance_id: int = boss.get_instance_id()
	hud.refresh_hud()
	_check(hud.boss_panel.visible and hud.boss_id == boss_instance_id and hud.boss_hp.value == 500.0, "Real Boss encounter publishes its live identity and five-hundred health before death")
	boss.hurtbox.take_damage(_damage(boss.hurtbox, 1000.0))
	await _time(0.8) # Actual Dead FSM reaches its authored 0.6s queue_free.
	_check(not is_instance_id_valid(boss_instance_id) and run.portal_active and not run.reward_chest.locked, "Actual lethal DamageEvent frees Boss through Dead FSM and unlocks victory rewards")
	hud.refresh_hud()
	_check(not hud.boss_panel.visible and hud.boss_id == 0 and hud.boss_hp.value == 0.0 and hud.boss_text.text.is_empty() and hud.player_panel.visible, "HUD safely retires the freed Boss reference while Player UI remains visible")
	for frame: int in 5:
		hud.refresh_hud()
	_check(hud.boss_id == 0 and not hud.boss_panel.visible and hud.boss_hp.tooltip_text.is_empty(), "Repeated frames after Boss queue_free cannot resurrect a stale footer or health tooltip")
	run.retry()
	run.enter_room(3)
	await _step(3)
	var replacement_id: int = run.boss.get_instance_id()
	hud.refresh_hud()
	_check(replacement_id != boss_instance_id and hud.boss_id == replacement_id and hud.boss_panel.visible and hud.boss_text.text == "500 / 500", "Retry binds the new Boss after the previous instance was freed")
	run.enter_room(1)
	await _step(3)
	hud.refresh_hud()
	_check(not is_instance_id_valid(replacement_id) and hud.boss_id == 0 and not hud.boss_panel.visible and hud.player_panel.visible, "Leaving a Boss room clears its footer after the room subtree is freed")
	# Keep the HUD alive after its world/player disappear: IDs must not become
	# strong actor references and _process must tolerate this teardown order.
	run.presentation.remove_child(hud)
	root.add_child(hud)
	var run_id: int = run.get_instance_id()
	run.queue_free()
	await _step(4)
	hud.refresh_hud()
	_check(not is_instance_id_valid(run_id) and not hud.player_panel.visible and not hud.boss_panel.visible and hud.boss_id == 0, "Retained HUD tolerates world and Player teardown without casting freed objects")
	hud.queue_free()
	await _step(3)
