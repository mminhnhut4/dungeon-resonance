extends "res://tests/survival_test_base.gd"
## Real state/cancel/lifetime checks, separate from native visual acceptance.
func _initialize() -> void:
	suite="combat_visual_runtime"; super._initialize()
func test_system() -> void:
	session.set_enabled(false)
	for enemy: SlimeEnemy in level.enemies: enemy.contact_damage_enabled=false
	player.hurtbox.set_invulnerable(true); player.energy.enabled=false
	var cue: Node2D=level.presentation.cast_cue
	_check(cue!=null and not cue.visible,"One bound seal begins hidden outside Cast")
	_install(&"fire_bolt"); player.resonance_controller.reset_runtime()
	await _key(KEY_I)
	var state: PlayerCastState=player.action_state_machine.current_state as PlayerCastState
	_check(state!=null and state.payload!=null and cue.visible and cue.root_id==state.payload.root_id,"Real I input displays the committed Fire windup seal")
	var root_before: int=cue.root_id; var direction_before: float=cue.global_rotation
	player.aim._cursor_viewport_position=Vector2(0,0); cue.refresh()
	_check(cue.root_id==root_before and is_equal_approx(cue.global_rotation,direction_before),"Changing cursor after commit cannot turn the seal")
	var casts_before: int=level.spell_executor.get_child_count()
	await _key(KEY_SHIFT)
	_check(not cue.visible and level.spell_executor.get_child_count()==casts_before and player.resonance_controller.cooldown_remaining()>0.0,"Dash cancels seal and unreleased projectile while retaining committed cooldown")
	await _time(0.6)
	for recipe: StringName in [&"fire_bolt",&"ice_bolt",&"wind_bolt",&"poison_bolt",&"lightning_bolt"]:
		_check(_install(recipe),"Real fixture equip resolves "+str(recipe))
		player.resonance_controller.reset_runtime()
		var payload: SpellSnapshot=player.resonance_controller.commit_cast()
		payload.origin=Vector2(250,180); payload.direction=Vector2.RIGHT
		level.spell_executor.spawn_cast(payload)
		await _step(1)
		var projectile: SpellProjectile=level.spell_executor.get_child(level.spell_executor.get_child_count()-1) as SpellProjectile
		var wake: SpellProjectileVFX=projectile.get_node("SpellTrailVFX") as SpellProjectileVFX
		_check(wake.committed_recipe==recipe and wake.tracked_root_id==payload.root_id and wake.z_index==6 and wake.particles.amount<=12,"Readable body/wake retain exact committed root and bounded particles for "+str(recipe))
		projectile.queue_free(); await _step(2)
	_check(level.presentation.projectile_vfx_owners.is_empty(),"Projectile deletion releases its body/wake registry")
	var boss: BossGolem=preload("res://scenes/enemies/boss_golem.tscn").instantiate()
	boss.position=Vector2(1150,640); boss.feedback=level.combat_feedback; boss.player=null; level.add_child(boss)
	await _step(3)
	var skin: BossGolemSkin=boss.get_node("GolemStoneSkin") as BossGolemSkin
	var rig: Node2D=skin.art_rig
	var body: CollisionShape2D=boss.get_node("Body"); var physical: Transform2D=body.transform; var shape: Shape2D=body.shape
	var rest: float=rig.arm_r.rotation
	boss.fsm.transition_to(&"sweep"); await _time(0.28)
	var tell: float=rig.arm_r.rotation
	_check(rig.pose==&"sweep_tell" and absf(tell-rest)>0.25 and not boss.attack_hitbox.active,"Natural tell visibly raises the arm before physical damage")
	while not boss.attack_hitbox.active and boss.state_time<0.7: await _step(1)
	skin.refresh_skin()
	_check(rig.pose==&"sweep_active" and boss.attack_hitbox.active and absf(rig.arm_r.rotation-tell)>0.25,"Natural release pose follows the existing active hitbox")
	await _time(0.2)
	_check(rig.pose==&"sweep_recovery" and not boss.attack_hitbox.active,"Natural recovery pose follows deactivation")
	var clock_before: float=boss.state_time; skin.refresh_skin(); skin.refresh_skin()
	_check(is_equal_approx(boss.state_time,clock_before) and body.shape==shape and body.transform==physical,"Seeking the rig cannot advance combat or move physical resources")
	var hit: DamageEvent=super._damage(boss.hurtbox,2.0); hit.source_id=level.get_instance_id(); hit.stagger_force=0.0
	level.combat_feedback.hit_stop_seconds=0.08
	boss.hurtbox.take_damage(hit); skin.refresh_skin()
	var frozen_pose: float=rig.arm_r.rotation; var frozen_clock: float=boss.state_time
	await _step(2)
	_check(level.combat_feedback.is_frozen() and is_equal_approx(boss.state_time,frozen_clock) and is_equal_approx(rig.arm_r.rotation,frozen_pose),"Accepted hurt hitstop freezes real combat and articulated pose together")
	await _time(0.2); level.combat_feedback.hit_stop_seconds=0.0
	var lethal: DamageEvent=super._damage(boss.hurtbox,1000.0); lethal.source_id=level.get_instance_id()
	boss.hurtbox.take_damage(lethal); await _time(0.2)
	_check(rig.pose==&"dead" and absf(rig.torso.rotation)>0.05 and skin.modulate.a<1.0,"Real lethal damage slumps the stone rig on the original death clock")
	await _time(0.5); _check(not is_instance_valid(boss),"Death deadline frees rig with its boss")

func _install(recipe: StringName) -> bool:
	var runes: Array[RuneData]=[]
	for definition: ResonanceDefinition in player.resonance_controller.recipes:
		if definition.id!=recipe: continue
		for id: StringName in definition.recipe_rune_ids:
			for rune: RuneData in GearInventory.RUNES:
				if rune.id==id: runes.append(rune)
		player.resonance_controller.catalyst_a.runtime_state.opened_slots=5
		return player.resonance_controller.catalyst_a.install_runes(runes) and player.resonance_controller.get_recipe()==definition
	return false
