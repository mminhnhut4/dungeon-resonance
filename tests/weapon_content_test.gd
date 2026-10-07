extends "res://tests/survival_test_base.gd"


func _initialize() -> void:
	suite = "weapon_content"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.energy.enabled = false
	var weapon: Weapon = player.equipped_weapon
	var expected_steps: Array[int] = [2, 4, 2, 2]
	for index: int in 4:
		await _key(KEY_F5)
		_check(weapon.definition is WeaponData and weapon.definition.id == ContentSession.WEAPON_IDS[index], "F5 selects authored archetype %d" % index)
		_check(weapon.definition.combo_steps.size() == expected_steps[index], "Archetype %d retains its own combo length" % index)
		_check(not weapon.hitbox.active and player.action_state_machine.get_state_id() == &"ready", "Weapon swap cancels previous hit windows")
	var sword: WeaponDefinition = load("res://data/weapons/demon_greatsword.tres")
	_check(sword.combo_steps[0].sweep_angle_degrees == 180.0 and sword.combo_steps[0].reach == 130.0, "Greatsword defines long 180-degree sweep")
	_check(sword.base_damage == 32.0 and sword.combo_steps[1].super_armor, "Greatsword has high base damage and second-step armor")
	player.reset_movement_at(Vector2(780, 640))
	weapon.equip(sword)
	_aim(Vector2(980, 620))
	player.action_state_machine.transition_to(&"attack")
	weapon._begin_step(1)
	var result: DamageResult = player.hurtbox.take_damage(_damage(player.hurtbox, 1.0))
	_check(not result.blocked and player.action_state_machine.get_state_id() == &"attack", "Super armor retains the second swing but still takes damage")
	player.reset_movement_at(Vector2(780, 640))
	player.action_state_machine.transition_to(&"attack")
	result = player.hurtbox.take_damage(_damage(player.hurtbox, 1.0))
	_check(not result.blocked and player.action_state_machine.get_state_id() == &"ready", "Unarmored content attack can be interrupted")
	player.reset_movement_at(Vector2(780, 640))
	level.dummy_a.global_position = Vector2(900, 640)
	level.dummy_a.set_physics_process(false)
	level.dummy_b.global_position = Vector2(650, 640)
	level.dummy_b.set_physics_process(false)
	level.dummy_a.hit_count = 0
	level.dummy_b.hit_count = 0
	player.action_state_machine.transition_to(&"attack")
	await _time(0.4)
	_check(level.dummy_a.hit_count == 1 and level.dummy_b.hit_count == 0, "Greatsword hits the front semicircle and excludes the rear")
	player.reset_movement_at(Vector2(450, 640))
	weapon.equip(load("res://data/weapons/gale_dual_daggers.tres"))
	_aim(Vector2(700, 620))
	player.action_state_machine.transition_to(&"attack")
	weapon._begin_step(3)
	var start_x: float = player.position.x
	await _time(0.1)
	_check(player.position.x > start_x + 15.0, "Dual daggers final active window produces a short forward lunge")
	_check(weapon.definition.critical_chance == 0.4 and weapon.definition.combo_steps[0].reach == 46.0, "Dual daggers trade short reach for forty-percent crit chance")
	player.reset_movement_at(Vector2(450, 640))
	weapon.equip(load("res://data/weapons/storm_arcane_staff.tres"))
	var before: int = level.spell_executor.spawned_projectiles
	player.action_state_machine.transition_to(&"attack")
	await _time(0.2)
	_check(level.spell_executor.spawned_projectiles == before + 1 and not weapon.hitbox.active, "Staff left click launches a wave through the projectile pipeline")
	var wave: SpellProjectile
	for child: Node in level.spell_executor.get_children():
		if child is SpellProjectile:
			wave = child
	_check(wave != null and wave.context.snapshot.behavior_id == &"arcane_wave" and wave.context.snapshot.speed == 400.0, "Wave snapshots authored mid-range speed and behavior")
	player.reset_movement_at(Vector2(780, 640))
	weapon.equip(load("res://data/weapons/blood_spiked_whip.tres"))
	level.dummy_a.global_position = Vector2(945, 640)
	level.dummy_a.hit_count = 0
	_aim(Vector2(1000, 620))
	player.action_state_machine.transition_to(&"attack")
	await _time(0.2)
	_check(level.dummy_a.hit_count == 1 and level.dummy_a.last_damage_event.knockback.x < 0.0, "Long straight whip hits and pulls toward the player's front")
	_check(weapon.definition.combo_steps[0].pull_force == 170.0, "Whip pull strength comes from step data")
	player.action_state_machine.transition_to(&"ready")
	await _key(KEY_Q)
	_check(weapon.definition != null and not weapon.hitbox.active, "Q cycles owned content resources without a stale hitbox")


func _aim(location: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * location
	root.push_input(motion, true)
	player.aim.sample_cursor()
