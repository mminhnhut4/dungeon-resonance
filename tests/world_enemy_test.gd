extends SceneTree
## Real FSM, world collision, Hurtbox/DoT and finite presentation ownership.

var arena: Node2D
var hero: Player
var feedback: CombatFeedback
var floor_body: StaticBody2D
var checks: int = 0
var failures: int = 0
const IDS: Array[StringName] = [&"ancient_guard", &"bloodwing_bat", &"sword_wraith", &"runic_champion"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	arena = Node2D.new()
	root.add_child(arena)
	current_scene = arena
	floor_body = _block(Vector2(600, 680), Vector2(1200, 80))
	_block(Vector2(1100, 360), Vector2(30, 720))
	hero = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	arena.add_child(hero)
	hero.reset_movement_at(Vector2(500, 640))
	hero.controls_enabled = false
	feedback = CombatFeedback.new()
	feedback.hit_stop_seconds = 0.0
	arena.add_child(feedback)
	hero.combat_feedback = feedback
	print("WORLD ENEMY TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	await _assets()
	await _guard()
	await _bat()
	await _wraith()
	await _champion()
	await _hazard_lifetime()
	await _incidents_and_conditions()
	await _stress()
	arena.queue_free()
	await _step(5)
	_check(get_nodes_in_group(&"world_enemies").is_empty() and get_nodes_in_group(&"world_enemy_hazards").is_empty() and root.get_node("AudioManager").get_active_voice_count() == 0, "Final arena teardown releases actors, hazards and spatial owners")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _assets() -> void:
	for id: StringName in IDS:
		var enemy: BaseEnemy = await _fresh(id, Vector2(800, 520 if id == &"bloodwing_bat" else 640))
		var sprite: Sprite2D = enemy.visual.sprite
		var body: CollisionShape2D = enemy.get_node("BodyCollision") as CollisionShape2D
		var shape_id: int = body.shape.get_instance_id()
		var local_transform: Transform2D = body.transform
		var hp: float = enemy.definition.maximum_hp
		var image: Image = sprite.texture.get_image()
		_check((sprite.texture is AtlasTexture and image.detect_alpha() != Image.ALPHA_NONE and enemy.visual.body_frames != null and enemy.visual.body_frames.valid and (sprite.texture as AtlasTexture).region.size == GuardBodyFrames.CANVAS and enemy.visual.geometry.get("authored_frames",false)) if id == &"ancient_guard" else (sprite.texture is AtlasTexture and image.detect_alpha() != Image.ALPHA_NONE and enemy.visual.geometry["bounds"].size.x < image.get_width()), "Approved %s art uses its live authored frame or solid alpha contract" % id)
		_check(((sprite.scale == Vector2.ONE * GuardBodyFrames.SCALE and enemy.visual.geometry["foot_pixel"] == GuardBodyFrames.PIVOT and is_equal_approx(enemy.definition.visual_height,60.0)) if id == &"ancient_guard" else is_equal_approx(sprite.scale.y * enemy.visual.geometry["bounds"].size.y, enemy.definition.visual_height)) and body.shape.size == enemy.definition.body_size, "Authored %s visual dimensions and body shape remain independent" % id)
		enemy.hurtbox.take_damage(_damage(enemy, 3))
		await _step(2)
		_check(enemy.definition.maximum_hp == hp and body.shape.get_instance_id() == shape_id and body.transform == local_transform and enemy.flash_remaining > 0, "Actual %s hit flashes without mutating shared definition or collider" % id)

func _guard() -> void:
	var guard: BaseEnemy = await _fresh(&"ancient_guard", Vector2(578, 640))
	guard.ai_enabled = true
	await _time(0.25)
	_check(guard.state_machine.get_state_id() == &"telegraph" and not guard.attack_hitbox.active and hero.health.current_health == 100.0, "Guard warns its slow saber sweep before the hitbox opens")
	await _time(0.27)
	_check(guard.state_machine.get_state_id() == &"attack" and guard.has_poise() and guard.attack_hitbox.active, "Guard's active sweep has authored Poise and a real hit window")
	var hit: DamageEvent = _damage(guard, 8)
	hit.knockback = Vector2(500, -100)
	var hp: float = guard.health.current_health
	guard.hurtbox.take_damage(hit)
	_check(guard.health.current_health == hp - 8 and guard.state_machine.get_state_id() == &"attack" and guard.motor._pending_impulse.is_zero_approx(), "Poise takes real damage but does not interrupt or knock back the committed sweep")
	var count: int = guard.hit_count
	_check(guard.hurtbox.take_damage(hit).blocked and guard.hit_count == count, "Duplicate delivery cannot repeat HP loss, flash or Hurt")
	_check(hero.health.current_health < 100.0 and guard.attack_hitbox._hit_targets.size() == 1, "Real sweeping hitbox reaches Player once through DamageEvent")
	var stun: DamageEvent = _damage(guard, 1)
	stun.stun_seconds = 0.35
	guard.hurtbox.take_damage(stun)
	_check(guard.state_machine.get_state_id() == &"hurt" and not guard.attack_hitbox.active and not guard.has_poise(), "Stun overrides active Poise and cancels the hostile window")
	await _time(0.55)
	_check(guard.state_machine.get_state_id() != &"hurt", "Guard exits finite Hurt after stun instead of becoming stuck")
	guard = await _fresh(&"ancient_guard", Vector2(1068, 640))
	guard.player = null
	guard.facing = 1
	guard.ai_enabled = true
	await _time(0.45)
	_check(guard.facing < 0 and guard.global_position.x <= 1070, "Grounded patrol turns at a real wall without crossing it")
	guard = await _fresh(&"ancient_guard", Vector2(617, 640))
	(floor_body.get_node("Shape") as CollisionShape2D).shape.size.x = 640
	floor_body.position.x = 320
	guard.player = null
	guard.facing = 1
	guard.ai_enabled = true
	await _time(0.6)
	_check(guard.facing < 0 and guard.global_position.y <= 641, "Grounded patrol ray detects an actual ledge before falling")
	(floor_body.get_node("Shape") as CollisionShape2D).shape.size.x = 1200
	floor_body.position.x = 600

func _bat() -> void:
	var bat: BaseEnemy = await _fresh(&"bloodwing_bat", Vector2(820, 470))
	bat.ai_enabled = true
	await _time(0.4)
	_check(bat.attack_kind == &"jade_bolt" and get_nodes_in_group(&"world_enemy_hazards").size() == 1, "Far bat commits a jade poison projectile after its distinct wind-up")
	bat.ai_enabled = false
	await _time(1.65)
	var status: ElementStatusController = hero.hurtbox.damage_resolver.status_controller as ElementStatusController
	_check(hero.health.current_health < 100 and status.poison_count == 1 and status.poison_remaining > 0, "Actual jade projectile strikes Player and applies finite poison through the shared resolver")
	_check(get_nodes_in_group(&"world_enemy_hazards").is_empty(), "Poison projectile destroys its hitbox after one contact")
	bat = await _fresh(&"bloodwing_bat", Vector2(590, 550))
	bat.ai_enabled = true
	await _time(0.4)
	_check(bat.attack_kind == &"dive" and bat.attack_hitbox.active and bat.velocity.length() > 100, "Near bat commits an aimed aerial dive rather than a ground melee clone")
	await _time(0.3)
	_check(hero.health.current_health < 100 and bat.global_position.y <= 641 and bat.visual.trail.size() <= 10, "Dive makes real contact while world collision and its jade trail remain bounded")
	bat = await _fresh(&"bloodwing_bat", Vector2(1060, 560))
	hero.relocate(Vector2(1020, 640))
	bat.locked_target = Vector2(1200, 560)
	bat.locked_direction = Vector2.RIGHT
	bat.attack_kind = &"dive"
	bat.state_machine.transition_to(&"attack")
	bat.ai_enabled = true
	await _time(0.25)
	_check(bat.global_position.x < 1070 and not bat.attack_hitbox.active, "A committed dive stops at a wall instead of tunneling through room terrain")

func _wraith() -> void:
	var wraith: BaseEnemy = await _fresh(&"sword_wraith", Vector2(700, 610))
	var body_id: int = (wraith.get_node("BodyCollision") as CollisionShape2D).shape.get_instance_id()
	wraith.ai_enabled = true
	await _time(0.3)
	_check(wraith.state_machine.get_state_id() == &"telegraph" and wraith.visual.sprite.modulate.a < 0.2 and not wraith.attack_hitbox.active and hero.health.current_health == 100, "Phasing wraith fades visually but cannot attack while invisible")
	_check(not wraith.hurtbox.invulnerable and wraith.hurtbox.monitorable, "Wraith camouflage grants no unrequested damage immunity")
	await _time(0.35)
	_check(wraith.visual.sprite.modulate.a > 0.95 and wraith.attack_hitbox.active and wraith.attack_hitbox.attack_snapshot.attack_direction == wraith.locked_direction, "Wraith fully reappears before its committed purple thrust window")
	await _time(0.28)
	_check(hero.health.current_health < 100 and wraith.visual.trail.size() <= 10 and (wraith.get_node("BodyCollision") as CollisionShape2D).shape.get_instance_id() == body_id, "Piercing phase dash damages once without changing collision or exceeding the cosmetic trail budget")
	var burn: DamageEvent = _damage(wraith, 2)
	burn.burn_damage = 2
	burn.burn_duration = 0.4
	burn.burn_interval = 0.1
	wraith.hurtbox.take_damage(burn)
	var hp: float = wraith.health.current_health
	await _time(0.35)
	_check(wraith.health.current_health < hp and wraith.state_machine.get_state_id() != &"hurt", "Burn ticks hurt the wraith without renewing Hurt or creating a DoT reaction lock")

func _champion() -> void:
	var champion: BaseEnemy = await _fresh(&"runic_champion", Vector2(600, 640))
	var shield: EnemyShieldHealth = champion.health as EnemyShieldHealth
	var event: DamageEvent = _damage(champion, 25)
	event.burn_damage = 10
	event.burn_duration = 0.65
	event.burn_interval = 0.2
	champion.hurtbox.take_damage(event)
	_check(shield.current_shield == 50 and shield.current_health == 160, "Guardian's real protective shield takes damage before its HP")
	_check(champion.hurtbox.take_damage(event).blocked and shield.current_shield == 50, "Shield damage still uses the shared attack duplicate gate")
	await _time(0.62)
	_check(shield.current_shield < 50 and shield.current_health == 160 and champion.definition.shield_hp == 75, "Shared burn DoT depletes runtime shield without changing HP or cached shield definition")
	var total: float = shield.current_shield + shield.current_health
	champion.hurtbox.take_damage(_damage(champion, 50))
	await _step(2)
	_check(shield.current_shield == 0 and shield.current_health < 160 and is_equal_approx(shield.current_health, total - 50) and champion.visual.shatter_remaining > 0, "Shield-breaking overflow reaches HP exactly once and triggers finite jade shatter")
	champion = await _fresh(&"runic_champion", Vector2(650, 640))
	champion.ai_enabled = true
	await _time(0.65)
	_check(get_nodes_in_group(&"world_slow_fields").size() == 1 and hero.health.current_health == 100, "Guardian locks a field under Player with a separate visible warning before contact")
	await _time(0.5)
	var statuses: ElementStatusController = hero.hurtbox.damage_resolver.status_controller as ElementStatusController
	_check(statuses.slow_remaining > 0 and statuses.movement_multiplier == 0.55, "Activated jade field applies finite slow through a real DamageEvent")
	_check(is_equal_approx(champion.definition.visual_height / 60, 1.5) and champion.scale == Vector2.ONE, "Guardian's 1.5x art size is authored independently of its physical body scale")

func _hazard_lifetime() -> void:
	var enemy: BaseEnemy = await _fresh(&"bloodwing_bat", Vector2(850, 480))
	var deaths: Array[int] = [0]
	enemy.defeated.connect(func(_dead: BaseEnemy) -> void: deaths[0] += 1)
	for index: int in 25:
		enemy.locked_target = hero.global_position
		enemy.locked_direction = Vector2.RIGHT
		enemy._spawn_hazard(&"jade_bolt")
	_check(get_nodes_in_group(&"world_enemy_hazards").size() == 16, "Burst enemy projectiles obey the shared sixteen-entity budget")
	for hazard: Node in get_nodes_in_group(&"world_enemy_hazards"): hazard.queue_free()
	await _step(3)
	for index: int in 10: enemy._spawn_hazard(&"slow_field")
	_check(get_nodes_in_group(&"world_slow_fields").size() == 4, "Runic fields have a separate four-field ceiling")
	enemy.hurtbox.take_damage(_damage(enemy, 999))
	enemy.hurtbox.take_damage(_damage(enemy, 999))
	await _step(3)
	_check(deaths[0] == 1 and get_nodes_in_group(&"world_enemy_hazards").is_empty() and enemy.state_machine.get_state_id() == &"dead", "Lethal damage emits one death and immediately dissolves the dead source's hazards")
	await _time(0.35)
	_check(not is_instance_valid(enemy), "Finite corpse fade completes even when fixture AI was disabled")
	enemy = await _fresh(&"ancient_guard", Vector2(620, 640))
	enemy.ai_enabled = true
	enemy.state_machine.transition_to(&"telegraph")
	feedback.hit_stop_seconds = 0.05
	feedback.on_hit_confirmed(_damage(enemy, 1), _result())
	var time: float = enemy.state_time
	var visual_clock: float = enemy.clock
	await _step(2)
	_check(enemy.state_time == time and enemy.clock == visual_clock, "Enemy attack and visual clocks freeze together during actual combat hit-stop")
	feedback.reset_feedback()
	feedback.hit_stop_seconds = 0

func _stress() -> void:
	await _wipe()
	for id: StringName in IDS:
		var enemy: BaseEnemy = await _fresh(id, Vector2(850, 580))
		enemy.queue_free()
		await _step(3)
	var objects: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for cycle: int in 6:
		for id: StringName in IDS:
			var enemy: BaseEnemy = await _fresh(id, Vector2(850, 580))
			enemy.queue_free()
			await _step(3)
	_check(get_nodes_in_group(&"world_enemies").is_empty() and get_nodes_in_group(&"world_enemy_hazards").is_empty(), "Repeated four-archetype lifecycles leave no enemies or attack entities")
	_check(int(Performance.get_monitor(Performance.OBJECT_COUNT)) <= objects and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)) <= resources, "Warm actor cycles retain no additional objects or definition/sprite resources")
	print("STRESS: world enemies objects=%d->%d resources=%d->%d" % [objects, int(Performance.get_monitor(Performance.OBJECT_COUNT)), resources, int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))])

func _incidents_and_conditions() -> void:
	var guard: BaseEnemy = await _fresh(&"ancient_guard", Vector2(650, 640))
	var victim: BaseEnemy = preload("res://scenes/enemies/ancient_guard.tscn").instantiate() as BaseEnemy
	victim.position = Vector2(610, 640)
	victim.player = hero
	victim.combat_feedback = feedback
	victim.ai_enabled = false
	arena.add_child(victim)
	var director := StorytellerDirector.new()
	director.player = hero
	director.world = arena
	director.enabled = false
	director.automatic = false
	arena.add_child(director)
	director.current_incident = &"swarm"
	director._apply_incident()
	guard._choose_target()
	_check(guard.enraged and guard.attack_rate_multiplier == 1.4 and guard.hurtbox.team_id == 0 and guard.attack_hitbox.collision_mask == 24 and guard.player == victim, "Real Swarm integration accelerates the new family and chooses the closest hostile regardless of faction")
	guard.state_machine.transition_to(&"telegraph")
	guard.state_machine.transition_to(&"attack")
	guard.ai_enabled = true
	await _step(3)
	_check(victim.health.current_health < victim.health.maximum_health, "Enraged guard's actual sweeping hitbox can damage another enemy")
	director.current_incident = &""
	director._apply_incident()
	_check(not guard.enraged and guard.attack_rate_multiplier == 1.0 and guard.hurtbox.team_id == 2 and guard.player == hero, "Ending Swarm restores the original team, speed and Player target")
	director.queue_free()
	var condition := BodyConditionComponent.new()
	condition.actor = guard
	condition.feedback = feedback
	guard.add_child(condition)
	condition.inflict(&"crippled")
	condition.inflict(&"severe_burn")
	guard.player = null
	guard.state_machine.transition_to(&"patrol")
	guard.facing = 1
	await _time(0.20)
	_check(guard.condition_speed_multiplier == 0.6 and is_equal_approx(guard.velocity.x, guard.definition.patrol_speed * 0.6) and guard.health.healing_multiplier == 0.5, "Attached body wounds reduce actual new-enemy travel speed and healing without mutating data")
	condition.clear()
	_check(guard.condition_speed_multiplier == 1.0 and guard.health.healing_multiplier == 1.0, "Clearing wounds restores neutral new-enemy modifiers")
	var bat: BaseEnemy = await _fresh(&"bloodwing_bat", Vector2(850, 470))
	hero.hurtbox.set_invulnerable(true)
	bat._spawn_hazard(&"jade_bolt")
	var hazard: WorldEnemyHazard = get_nodes_in_group(&"world_enemy_hazards")[0] as WorldEnemyHazard
	hazard._hit(hero.hurtbox, hazard.attack)
	_check(hero.health.current_health == 100 and hero.hurtbox.damage_resolver.status_controller.poison_count == 0 and hazard.emitted_hits == 0 and not hazard.hitbox.active, "A protected Player blocks poison and HP loss while the projectile still closes its one-shot window")
	await _step(3)
	hero.hurtbox.set_invulnerable(false)
	bat.enraged = true
	bat._spawn_hazard(&"jade_bolt")
	hazard = get_nodes_in_group(&"world_enemy_hazards")[0] as WorldEnemyHazard
	_check(hazard.attack.source_team_id == 0 and hazard.hitbox.collision_mask == 24, "Enraged ranged attacks snapshot faction-free damage and both hostile layers")
	hazard.queue_free()
	await _step(3)
	bat._spawn_hazard(&"slow_field")
	await _time(3.2)
	_check(get_nodes_in_group(&"world_enemy_hazards").is_empty(), "A surviving source cannot retain its warned slow field past its finite three-second lifetime")

func _fresh(id: StringName, position: Vector2) -> BaseEnemy:
	await _wipe()
	hero.reset_movement_at(Vector2(500, 640))
	hero.controls_enabled = false
	hero.hurtbox.damage_resolver.status_controller.clear()
	hero.hurtbox.set_invulnerable(false)
	hero.damage_grace_remaining = 0
	var enemy: BaseEnemy = (load("res://scenes/enemies/%s.tscn" % id) as PackedScene).instantiate() as BaseEnemy
	enemy.position = position
	enemy.player = hero
	enemy.combat_feedback = feedback
	enemy.ai_enabled = false
	arena.add_child(enemy)
	await _step(3)
	return enemy

func _wipe() -> void:
	feedback.reset_feedback()
	for node: Node in get_nodes_in_group(&"world_enemies") + get_nodes_in_group(&"enemy_hazards") + get_nodes_in_group(&"combat_text"):
		if arena.is_ancestor_of(node): node.queue_free()
	await _step(4)

func _damage(enemy: BaseEnemy, amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = hero.get_instance_id()
	event.source_team_id = 1
	event.target_id = enemy.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	return event

func _result() -> DamageResult:
	var result := DamageResult.new()
	result.actual_damage = 1
	return result

func _block(position: Vector2, extent: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = extent
	var collision := CollisionShape2D.new()
	collision.name = "Shape"
	collision.shape = shape
	body.add_child(collision)
	arena.add_child(body)
	return body

func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", text])
