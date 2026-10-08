extends SceneTree
## Narrow mechanics/clock/root/lifetime gate. Headless is not animation acceptance.

const ENEMY: PackedScene = preload("res://scenes/enemies/depth_enemy.tscn")
const BOSS: PackedScene = preload("res://scenes/enemies/depth_boss.tscn")
var arena: Node2D
var hero: Player
var feedback: CombatFeedback
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	arena = Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(1000, 680)
	floor_body.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = Vector2(2000, 80)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	floor_body.add_child(collision)
	arena.add_child(floor_body)
	hero = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	arena.add_child(hero)
	hero.controls_enabled = false
	feedback = CombatFeedback.new()
	feedback.hit_stop_seconds = 0.0
	arena.add_child(feedback)
	hero.combat_feedback = feedback
	print("DEPTH ACTOR TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	for floor_id: int in range(1, 5): await _enemy(floor_id)
	await _boss()
	await _lifetimes()
	arena.queue_free()
	await _step(5)
	_check(get_nodes_in_group(&"depth_enemies").is_empty() and get_nodes_in_group(&"depth_bosses").is_empty() and get_nodes_in_group(&"enemy_hazards").is_empty(), "Depth room teardown releases all actor/hazard owners")
	_check(is_equal_approx(Engine.time_scale, 1.0) and not paused, "Depth teardown restores pause and global time")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _enemy(floor_id: int) -> void:
	var enemy: BaseEnemy = await _fresh_enemy(floor_id)
	var base_id: String = ["ancient_guard", "bloodwing_bat", "sword_wraith", "runic_champion"][floor_id - 1]
	var original: WorldEnemyData = load("res://data/enemies/%s.tres" % base_id) as WorldEnemyData
	_check(enemy.definition != original and enemy.definition.id != original.id and enemy.definition.maximum_hp == original.maximum_hp and enemy.definition.attack_damage == original.attack_damage, "Floor%d uses private data with inherited prototype HP/damage" % floor_id)
	_check(enemy.definition.moveset == floor_id - 1 and enemy.get_node("BodyCollision").shape.size == original.body_size and enemy.visual.name == "DepthEnemyArt", "Floor%d owns its distinct moveset and independent physical/raster body" % floor_id)
	_check(enemy.visual.snapshot().raster_ready and enemy.visual.snapshot().primary_frames == 6 and enemy.visual.sprite.texture is AtlasTexture and enemy.visual.snapshot().foot.is_equal_approx(enemy.global_position), "Floor%d loads actual six-pose raster at the physical foot" % floor_id)
	await _capture("enemy_%d_idle" % floor_id, enemy)
	var body: CollisionShape2D = enemy.get_node("BodyCollision") as CollisionShape2D
	var body_id: int = body.shape.get_instance_id()
	var before_transform: Transform2D = body.transform
	var hit: DamageEvent = _event(enemy, 2.0)
	var result: DamageResult = enemy.hurtbox.take_damage(hit)
	_check(not result.blocked and enemy.flash_remaining == 0.12 and enemy.visual._material.get_shader_parameter("flash") == 1.0 and enemy.visual.snapshot().clip == &"hurt", "Floor%d refreshes actual hit raster before frozen clocks" % floor_id)
	await _capture("enemy_%d_hurt" % floor_id, enemy)
	_check(enemy.hurtbox.take_damage(hit).blocked and enemy.hit_count == 1 and body.shape.get_instance_id() == body_id and body.transform == before_transform and original.id == StringName(base_id), "Floor%d deduplicates actual damage without shared data/collider mutation" % floor_id)
	enemy = await _fresh_enemy(floor_id)
	enemy.state_machine.transition_to(&"telegraph")
	var committed: Vector2 = enemy.locked_direction
	enemy.ai_enabled = true
	await _time(enemy.definition.windup - 0.04)
	_check(enemy.state_machine.get_state_id() == &"telegraph" and not enemy.attack_hitbox.active and enemy.visual.snapshot().clip == &"telegraph" and hero.health.current_health == 100, "Floor%d has a real warning without premature damage" % floor_id)
	await _capture("enemy_%d_tell" % floor_id, enemy)
	await _time(0.09)
	if floor_id == 4:
		_check(get_nodes_in_group(&"world_slow_fields").size() == 1 and enemy.attack_kind == &"slow_field", "Forge shield commits one finite warned field at the locked target")
		await _capture("enemy_%d_active" % floor_id, enemy)
		await _time(0.50)
		var status: ElementStatusController = hero.hurtbox.damage_resolver.status_controller as ElementStatusController
		_check(status.slow_remaining > 0.0 and hero.health.current_health < 100 and enemy.health is EnemyShieldHealth, "Forge field damages/slows through resolver while runtime armor remains actor-owned")
	else:
		_check(enemy.attack_hitbox.active and enemy.attack_hitbox.attack_snapshot.attack_direction == committed and enemy.visual.snapshot().clip == &"attack", "Floor%d raster active phase reads the exact committed hit window" % floor_id)
		await _capture("enemy_%d_active" % floor_id, enemy)
		await _time(enemy.definition.active - 0.03)
		_check(hero.health.current_health < 100 and enemy.attack_hitbox._hit_targets.size() == 1, "Floor%d real physical attack contacts Player once" % floor_id)
	await _time(0.07)
	_check(enemy.state_machine.get_state_id() == &"recover" and not enemy.attack_hitbox.active and enemy.visual.snapshot().clip == &"recover", "Floor%d recovery closes the real hitbox and seeks recovery raster" % floor_id)
	await _capture("enemy_%d_recover" % floor_id, enemy)
	if floor_id in [1, 4]:
		_check(enemy.velocity.x * enemy.facing <= 0.0, "Floor%d physical flank recovery retreats without moving its sprite root alone" % floor_id)
	elif floor_id == 2:
		print("SPORE_RECOVERY_TRACE: pos=%s vel=%s facing=%s time=%s desired=%s" % [enemy.global_position, enemy.velocity, enemy.facing, enemy.state_time, enemy._desired])
		await _time(0.12)
		print("SPORE_WITHDRAW_TRACE: pos=%s vel=%s facing=%s time=%s desired=%s" % [enemy.global_position, enemy.velocity, enemy.facing, enemy.state_time, enemy._desired])
		_check(enemy.velocity.y < 0.0 and enemy.velocity.x * enemy.facing < 0.0, "Spore bat physically withdraws above the landing line")
	elif floor_id == 3:
		_check(enemy.global_position.x < hero.global_position.x, "Locked crystal thrust physically passes the target instead of retargeting midstrike")

func _boss() -> void:
	var boss: BossGolem = await _fresh_boss(Vector2(600, 640))
	_check(boss.health.maximum_health == 500.0 and boss.phase == 1 and boss.has_meta(&"custom_boss_visual") and boss.has_node("DepthBossArt"), "Fifth boss owns its art and inherited prototype health/protocol")
	_check(boss.presentation.snapshot().raster_ready and boss.presentation.snapshot().primary_frames == 12 and boss.presentation.snapshot().foot.is_equal_approx(boss.global_position), "Fifth boss loads actual twelve-pose raster with an authored boot pivot")
	await _capture("boss_idle", boss)
	boss.fsm.transition_to(&"sweep")
	boss.ai_enabled = true
	await _time(0.65)
	_check(not boss.attack_hitbox.active and hero.health.current_health == 100 and boss.presentation.snapshot().clip == &"telegraph", "Seal thrust warns for0.70s before its narrow physical window")
	await _capture("boss_thrust_tell", boss)
	await _time(0.10)
	_check(boss.attack_hitbox.active and boss.attack_hitbox._query_shape.size == Vector2(140, 30) and boss.attack_hitbox.attack_snapshot.base_damage == 20 and boss.presentation.snapshot().clip == &"attack", "Phase1 thrust uses a distinct live shape and exact active raster")
	print("SEAL_THRUST_TRACE: boss=%s shape=%s hero=%s hurt=%s hp=%s hits=%s" % [boss.global_position, boss.attack_hitbox.global_position, hero.global_position, hero.hurtbox.global_position, hero.health.current_health, boss.attack_hitbox._hit_targets])
	_check(hero.health.current_health < 100 and boss.attack_hitbox._hit_targets.size() == 1, "Seal thrust delivers actual Player damage once through the common hitbox")
	await _capture("boss_thrust_active_contact", boss)
	await _time(0.20)
	_check(not boss.attack_hitbox.active and boss.presentation.snapshot().clip == &"recover" and boss.velocity.x * boss.facing <= 0, "Thrust recovery closes damage and physically steps back")
	await _capture("boss_thrust_recover", boss)
	boss = await _fresh_boss(Vector2(800, 640))
	boss.fsm.transition_to(&"orbs")
	boss.ai_enabled = true
	await _time(0.65)
	_check(get_nodes_in_group(&"enemy_hazards").is_empty() and boss.presentation.snapshot().clip == &"telegraph_fan", "Ritual fan has its own visible gather before any projectile exists")
	await _capture("boss_fan_gather", boss)
	await _time(0.30)
	_check(boss.emitted_orbs == 3 and get_nodes_in_group(&"enemy_hazards").size() == 3 and boss.fan_directions.size() == 3 and not boss.fan_directions[0].is_equal_approx(boss.fan_directions[2]), "Phase1 commits three real orbs across a bounded fan")
	await _capture("boss_fan_flight", boss)
	var phases: Array[int] = [0]
	boss.phase_two_started.connect(func() -> void: phases[0] += 1)
	boss.hurtbox.take_damage(_event(boss, 260.0))
	_check(boss.phase == 2 and phases[0] == 1 and boss.phase_two_count == 1 and boss.health.current_health == 240, "Fifth boss transitions once at actual half-health damage")
	boss.hurtbox.take_damage(_event(boss, 1.0))
	_check(phases[0] == 1 and boss.tell_seconds() > 0.70 and boss.fan_count() == 5, "Phase2 keeps one transition and grants a longer readable five-orb warning")
	for hazard: Node in get_nodes_in_group(&"enemy_hazards"): hazard.queue_free()
	await _step(3)
	boss.ai_enabled = false
	boss.fsm.transition_to(&"orbs")
	boss.ai_enabled = true
	await _time(1.35)
	_check(boss.emitted_orbs == 5 and get_nodes_in_group(&"enemy_hazards").size() == 5 and absf(boss.fan_directions[0].angle_to(boss.fan_directions[4])) > 1.0, "Phase2 emits five physical orbs with a wider committed fan")
	await _capture("boss_phase2_fan_flight", boss)
	boss = await _fresh_boss(Vector2(600, 640))
	boss.hurtbox.take_damage(_event(boss, 260.0))
	boss.flash = 0.0
	boss.fsm.transition_to(&"sweep")
	boss.ai_enabled = true
	await _time(0.84)
	_check(not boss.attack_hitbox.active and boss.presentation.snapshot().clip == &"telegraph_sweep", "Phase2 sweep preserves its longer warning and distinct raster clip")
	await _capture("boss_phase2_sweep_tell", boss)
	await _time(0.12)
	_check(boss.attack_hitbox.active and boss.attack_hitbox._query_shape.size == Vector2(280, 32) and hero.health.current_health < 100, "Phase2 broad sweep matches its real Player damage window")
	await _capture("boss_phase2_sweep_contact", boss)
	boss = await _fresh_boss(Vector2(600, 640))
	feedback.hit_stop_seconds = 0.08
	boss.ai_enabled = true
	boss.fsm.transition_to(&"sweep")
	boss.hurtbox.take_damage(_event(boss, 2.0))
	var state_time: float = boss.state_time
	var art: Dictionary = boss.presentation.snapshot()
	await _capture("boss_hurt_hitstop", boss)
	await _step(2)
	_check(feedback.is_frozen() and boss.state_time == state_time and boss.presentation.snapshot() == art and art.flash == 1.0 and art.clip == &"hurt", "Fifth boss actual hit flashes immediately and freezes body/attack clocks together")
	feedback.reset_feedback()
	feedback.hit_stop_seconds = 0.0

func _lifetimes() -> void:
	await _wipe()
	var deaths: Array[int] = [0]
	var enemy: BaseEnemy = await _fresh_enemy(4)
	enemy.defeated.connect(func(_actor: BaseEnemy) -> void: deaths[0] += 1)
	enemy.hurtbox.take_damage(_event(enemy, 999.0))
	enemy.hurtbox.take_damage(_event(enemy, 999.0))
	await _time(0.40)
	_check(deaths[0] == 1 and not is_instance_valid(enemy), "Depth enemy lethal damage emits one finite corpse owner and releases it")
	var boss: BossGolem = await _fresh_boss(Vector2(800, 640))
	var boss_deaths: Array[int] = [0]
	boss.defeated.connect(func() -> void: boss_deaths[0] += 1)
	boss.ai_enabled = true
	boss.hurtbox.take_damage(_event(boss, 999.0))
	await _time(0.70)
	_check(boss_deaths[0] == 1 and not is_instance_valid(boss), "Depth boss preserves the real defeated signal and finite corpse lifetime")
	for cycle: int in 3:
		for floor_id: int in range(1, 5):
			enemy = await _fresh_enemy(floor_id)
			_check(enemy.visual.snapshot().raster_ready and enemy.visual.snapshot().primary_frames == 6 and enemy.visual.sprite.texture != null, "Raster bank survives previous floor%d actor teardown in cycle%d" % [floor_id, cycle])
			enemy.queue_free()
			await _step(3)
		boss = await _fresh_boss(Vector2(800, 640))
		_check(boss.presentation.snapshot().raster_ready and boss.presentation.snapshot().primary_frames == 12 and boss.presentation.sprite.texture != null, "Boss raster bank survives previous actor teardown in cycle%d" % cycle)
		boss.queue_free()
		await _step(3)
	_check(get_nodes_in_group(&"depth_enemies").is_empty() and get_nodes_in_group(&"depth_bosses").is_empty() and get_nodes_in_group(&"enemy_hazards").is_empty(), "Repeated depth actor cycles leave no actor, raster observer or attack entity")

func _fresh_enemy(floor_id: int) -> BaseEnemy:
	await _wipe()
	_reset_hero()
	var enemy: BaseEnemy = ENEMY.instantiate() as BaseEnemy
	enemy.set("depth_floor", floor_id)
	enemy.player = hero
	enemy.combat_feedback = feedback
	enemy.ai_enabled = false
	enemy.position = Vector2(578, 640) if floor_id == 1 else Vector2(590, 550) if floor_id == 2 else Vector2(620, 610) if floor_id == 3 else Vector2(650, 640)
	arena.add_child(enemy)
	await _step(3)
	return enemy

func _fresh_boss(position: Vector2) -> BossGolem:
	await _wipe()
	_reset_hero()
	var boss: BossGolem = BOSS.instantiate() as BossGolem
	boss.position = position
	boss.player = hero
	boss.feedback = feedback
	boss.ai_enabled = false
	arena.add_child(boss)
	await _step(3)
	return boss

func _reset_hero() -> void:
	hero.reset_movement_at(Vector2(500, 640))
	hero.controls_enabled = false
	hero.hurtbox.set_invulnerable(false)
	hero.hurtbox.damage_resolver.status_controller.clear()
	hero.damage_grace_remaining = 0.0

func _wipe() -> void:
	feedback.reset_feedback()
	for node: Node in get_nodes_in_group(&"enemies") + get_nodes_in_group(&"enemy_hazards") + get_nodes_in_group(&"combat_text"):
		if arena.is_ancestor_of(node): node.queue_free()
	await _step(4)

func _event(target: Node2D, damage: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = hero.get_instance_id()
	event.source_team_id = 1
	event.target_id = target.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = damage
	event.melee_hit = true
	return event

func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", label])

func _capture(_tag: String, _actor: Node2D) -> void:
	pass # External native probe may observe these exact timestamps without changing clocks.
