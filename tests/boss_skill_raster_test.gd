extends "res://tests/survival_test_base.gd"
## Natural actor FSM ticks and actual active shapes; the test never authors the
## boss state_time or gives a cosmetic node ownership of damage/clock/lifetime.

const HELPER = preload("res://scripts/presentation/boss_skill_raster_helper.gd")
const ART = preload("res://scripts/presentation/rendered_spell_art.gd")


func _initialize() -> void:
	suite = "boss_skill_raster"
	super._initialize()


func _damage(target: Hurtbox, amount: float, heavy: bool = false) -> DamageEvent:
	var event: DamageEvent = super._damage(target, amount, heavy)
	event.source_id = level.get_instance_id()
	event.stagger_force = 0.0
	return event


func test_system() -> void:
	session.set_enabled(false)
	player.controls_enabled = false
	player.hurtbox.set_invulnerable(true)
	player.set_physics_process(false)
	for enemy: SlimeEnemy in level.enemies:
		enemy.contact_damage_enabled = false
	_check(ART.available(), "Rendered boss cues use the imported painted atlas")
	var resident: Texture2D = ART.sheet
	var cells: Array[AtlasTexture] = ART.cells.duplicate()
	await _boss_case(preload("res://scenes/enemies/boss_golem.tscn"), 1)
	await _boss_case(preload("res://scenes/enemies/depth_boss.tscn"), 1)
	await _boss_case(preload("res://scenes/enemies/depth_boss.tscn"), 2)
	await _outgoing_first_window(preload("res://scenes/enemies/boss_golem.tscn"), 1)
	await _outgoing_first_window(preload("res://scenes/enemies/depth_boss.tscn"), 1)
	await _outgoing_first_window(preload("res://scenes/enemies/depth_boss.tscn"), 2)
	_check(ART.sheet == resident and ART.cells == cells and cells.size() == 20, "Boss cues and flight glyphs reuse the same finite twenty-cell sheet")
	_check(get_nodes_in_group(&"boss_skill_raster").is_empty() and get_nodes_in_group(&"boss_orb_vfx").is_empty(), "Case teardown releases boss cue and finite orb visual owners")
	await _caps_and_clear()
	player.set_physics_process(true)


func _inside_rectangle(helper: Node2D, rectangle: Rect2) -> bool:
	var count: int = 0
	for sprite: Sprite2D in helper._sweep:
		if not sprite.visible:
			continue
		count += 1
		var size: Vector2 = sprite.texture.get_size() * sprite.scale.abs()
		if sprite.rotation != 0.0 or not rectangle.encloses(Rect2(sprite.position - size * 0.5, size)):
			return false
	return count == 2


func _boss_case(scene: PackedScene, wanted_phase: int) -> void:
	var boss: BossGolem = scene.instantiate() as BossGolem
	boss.position = Vector2(900, 640)
	boss.feedback = level.combat_feedback
	boss.player = null
	level.add_child(boss)
	await _step(3)
	var helper: Node2D = HELPER.attach(boss)
	var title: String = ("Depth" if boss is DepthBoss else "Golem") + " phase%d" % wanted_phase
	_check(helper != null and helper.get_parent() == boss and HELPER.attach(boss) == helper, title + " owns one idempotent capped adapter")
	if helper == null:
		boss.queue_free()
		await _step(3)
		return
	var body: CollisionShape2D = boss.get_node("Body") as CollisionShape2D
	var body_shape: Shape2D = body.shape
	var body_transform: Transform2D = body.transform
	var hurt_shape: Shape2D = (boss.hurtbox.get_child(0) as CollisionShape2D).shape
	var hurt_transform: Transform2D = (boss.hurtbox.get_child(0) as CollisionShape2D).transform
	if wanted_phase == 2:
		boss.hurtbox.take_damage(_damage(boss.hurtbox, 255.0))
		await _time(0.20)
	_check(boss.phase == wanted_phase and helper.snapshot().visible_sprites == 0, title + " idle has no fictional skill area")
	boss.facing = -1.0
	boss.fsm.transition_to(&"sweep")
	var tell: float = boss.tell_seconds() if boss is DepthBoss else 0.50
	await _time(tell * 0.45)
	var anticipated: Dictionary = helper.snapshot()
	_check(anticipated.phase == &"windup" and not anticipated.active and not boss.attack_hitbox.active and _inside_rectangle(helper, anticipated.sweep_rectangle), title + " painted windup stays inside the authored future rectangle")
	var timer_before: float = boss.state_time
	var health_before: float = boss.health.current_health
	helper.refresh()
	helper.refresh()
	_check(boss.state_time == timer_before and boss.health.current_health == health_before and not boss.attack_hitbox.active, title + " cosmetic refresh writes no state clock, hitbox or damage")
	for tick: int in ceili(tell * Engine.physics_ticks_per_second):
		if boss.attack_hitbox.active:
			break
		await _step(1)
	var actual: RectangleShape2D = boss.attack_hitbox._query_shape as RectangleShape2D
	var rectangle := Rect2(boss.attack_hitbox.position - actual.size * 0.5, actual.size) if actual != null else Rect2()
	_check(actual != null and helper.snapshot().active and helper.snapshot().sweep_rectangle == rectangle and _inside_rectangle(helper, rectangle), title + " natural active window reads exact live shape/offset and fits both painted quads")
	var active_root: int = boss.attack_hitbox.attack_snapshot.root_event_id if boss.attack_hitbox.attack_snapshot != null else 0
	var active_transform: Transform2D = boss.attack_hitbox.transform
	helper.refresh()
	_check(active_root > 0 and boss.attack_hitbox.attack_snapshot.root_event_id == active_root and boss.attack_hitbox._query_shape == actual and boss.attack_hitbox.transform == active_transform, title + " active rendering preserves contact root/resource/transform")
	level.combat_feedback.hit_stop_seconds = 0.08
	boss.hurtbox.take_damage(_damage(boss.hurtbox, 1.0))
	var held: Dictionary = helper.snapshot()
	var held_clock: float = boss.state_time
	await _step(2)
	_check(level.combat_feedback.is_frozen() and boss.state_time == held_clock and helper.snapshot() == held, title + " accepted-hit stop holds the exact painted clock/window")
	level.combat_feedback.reset_feedback()
	level.combat_feedback.hit_stop_seconds = 0.0
	paused = true
	for tick: int in 3:
		await process_frame
	_check(boss.state_time == held_clock and helper.snapshot() == held, title + " tree pause keeps body and painted cue together")
	paused = false
	for tick: int in Engine.physics_ticks_per_second:
		if not boss.attack_hitbox.active:
			break
		await _step(1)
	_check(not boss.attack_hitbox.active and not helper.snapshot().active and helper.snapshot().phase == &"recovery", title + " authored window closes while only the finite recovery paint remains")
	await _time(1.0)
	_check(boss.fsm.get_state_id() == &"idle" and helper.snapshot().visible_sprites == 0, title + " natural recovery removes the cue before the next attack")
	boss.fsm.transition_to(&"sweep")
	await _time(tell * 0.20)
	boss.fsm.transition_to(&"staggered")
	_check(helper.snapshot().visible_sprites == 0 and not boss.attack_hitbox.active, title + " cancellation removes the cue at the FSM boundary")
	boss.fsm.transition_to(&"idle")
	await _fan(boss, helper, title)
	_check(body.shape == body_shape and body.transform == body_transform and (boss.hurtbox.get_child(0) as CollisionShape2D).shape == hurt_shape and (boss.hurtbox.get_child(0) as CollisionShape2D).transform == hurt_transform, title + " adapter preserves Body and Hurtbox geometry/resources")
	var children: Array[int] = []
	for sprite: Sprite2D in helper._seal + helper._sweep:
		children.append(sprite.get_instance_id())
	var helper_id: int = helper.get_instance_id()
	boss.fsm.transition_to(&"dead")
	_check(helper.snapshot().visible_sprites == 0 and not boss.attack_hitbox.active, title + " death removes all skill paint immediately")
	await _time(0.70)
	var released: bool = not is_instance_valid(boss) and not is_instance_id_valid(helper_id)
	for id: int in children:
		released = released and not is_instance_id_valid(id)
	_check(released, title + " existing boss death lifetime frees all four resident sprites")
	level.combat_feedback.reset_feedback()


func _fan(boss: BossGolem, helper: Node2D, title: String) -> void:
	player.reset_movement_at(Vector2(200, 640))
	boss.player = player
	boss.fsm.transition_to(&"orbs")
	var tell: float = boss.tell_seconds() if boss is DepthBoss else 0.55
	await _time(tell * 0.45)
	_check(helper.snapshot().phase == &"windup" and helper.snapshot().visible_sprites == 2 and helper.snapshot().sweep_rectangle == Rect2() and boss.emitted_orbs == 0, title + " painted gather seal precedes actual fan release without a damage rectangle")
	for tick: int in ceili(tell * Engine.physics_ticks_per_second):
		if boss.emitted_orbs > 0:
			break
		await _step(1)
	var orbs: Array[EnemyHazard] = []
	for node: Node in get_nodes_in_group(&"enemy_hazards"):
		if node is EnemyHazard and node.source_id == boss.get_instance_id() and node.kind == &"orb":
			orbs.append(node as EnemyHazard)
	_check(orbs.size() == 1 and helper.snapshot().phase == &"active", title + " first existing socket release starts the painted cast window once")
	if orbs.is_empty():
		return
	var orb: EnemyHazard = orbs[0]
	var shape: Shape2D = orb.hitbox._query_shape
	var transform_before: Transform2D = orb.hitbox.transform
	var root_before: int = orb.attack.root_event_id
	var visual: Node2D = orb.get_node_or_null("BossOrbVFX") as Node2D
	var glyph: Sprite2D = visual.get_node_or_null("RenderedBossOrbGlyph") as Sprite2D if visual != null else null
	_check(glyph != null and glyph.texture == ART.cell(ART.CAST, &"lightning") and glyph.position == Vector2.ZERO and (glyph.texture.get_size() * glyph.scale).is_equal_approx(Vector2.ONE * HELPER.ORB_DIAMETER), title + " actual BossOrbVFX binds the painted26px glyph at its real head")
	_check(shape is CircleShape2D and shape.radius == 9.0 and orb.hitbox._query_shape == shape and orb.hitbox.transform == transform_before and orb.attack.root_event_id == root_before, title + " painted orb retains nine-pixel physical shape and existing root")
	await _time(0.12)
	if glyph != null:
		var motion: Dictionary = visual.snapshot()
		var frozen_transform: Transform2D = glyph.transform
		var frozen_life: float = orb.life
		level.combat_feedback.hit_stop_remaining = 0.09
		await _step(2)
		_check(orb.life == frozen_life and glyph.transform == frozen_transform and visual.snapshot() == motion, title + " orb body/glyph/wake use the same frozen hazard life")
		level.combat_feedback.reset_feedback()
	var wanted_orbs: int = boss.fan_count() if boss is DepthBoss else 3
	for tick: int in Engine.physics_ticks_per_second:
		if boss.emitted_orbs >= wanted_orbs:
			break
		await _step(1)
	_check(boss.emitted_orbs == wanted_orbs and helper.snapshot().resident_sprites == 4 and helper.snapshot().damage_emitters == 0 and helper.snapshot().lights == 0, title + " finite cue keeps the existing fan count with no hazard/light emitter")
	boss.player = null
	for hazard: Node in get_nodes_in_group(&"enemy_hazards"):
		if hazard is EnemyHazard and hazard.source_id == boss.get_instance_id():
			hazard.queue_free()
	await _step(3)
	_check(get_nodes_in_group(&"boss_orb_vfx").is_empty(), title + " clearing physical fan hazards releases all painted flight children")

func _caps_and_clear() -> void:
	var bosses: Array[BossGolem] = []
	var helpers: Array[Node2D] = []
	for index: int in HELPER.MAX_BOSS_VISUALS + 1:
		var boss: BossGolem = preload("res://scenes/enemies/boss_golem.tscn").instantiate() as BossGolem
		boss.ai_enabled = false
		boss.player = null
		boss.feedback = level.combat_feedback
		boss.position = Vector2(900, 640)
		level.add_child(boss)
		bosses.append(boss)
		var helper: Node2D = HELPER.attach(boss)
		if helper != null:
			helpers.append(helper)
	await _step(2)
	_check(helpers.size() == HELPER.MAX_BOSS_VISUALS and get_nodes_in_group(&"boss_skill_raster").size() == HELPER.MAX_BOSS_VISUALS and not bosses[-1].has_node("BossSkillRasterHelper"), "Four actor-owned paint slots retain original boss fallback beyond the cosmetic cap")
	var survivor: BossGolem = bosses[0]
	var helper: Node2D = helpers[0]
	var children: Array[int] = []
	for sprite: Sprite2D in helper._seal + helper._sweep:
		children.append(sprite.get_instance_id())
	helper.bind(survivor)
	var reused: bool = helper.snapshot().resident_sprites == 4
	for id: int in children:
		reused = reused and is_instance_id_valid(id)
	_check(reused and survivor.fsm.state_changed.is_connected(helper._state_changed) and survivor.attack_hitbox.contact_detected.is_connected(helper._contact_published), "Rebinding the same helper reuses four sprites and finite FSM/contact listeners")
	var transform_before: Transform2D = survivor.global_transform
	var clock_before: float = survivor.state_time
	var hp_before: float = survivor.health.current_health
	helper.clear()
	_check(helper.snapshot().visible_sprites == 0 and helper.snapshot().actor_id == 0 and not survivor.fsm.state_changed.is_connected(helper._state_changed) and not survivor.attack_hitbox.contact_detected.is_connected(helper._contact_published) and survivor.global_transform == transform_before and survivor.state_time == clock_before and survivor.health.current_health == hp_before, "Helper-alone clear releases listeners/owner without moving, freezing or damaging the live boss")
	var helper_id: int = helper.get_instance_id()
	helper.queue_free()
	await _step(2)
	var released: bool = is_instance_valid(survivor) and not is_instance_id_valid(helper_id)
	for id: int in children:
		released = released and not is_instance_id_valid(id)
	_check(released, "Freeing only the cosmetic adapter releases its four sprites while the boss remains live")
	for boss: BossGolem in bosses:
		boss.queue_free()
	await _step(3)
	_check(get_nodes_in_group(&"boss_skill_raster").is_empty(), "Capped adapter cleanup retains no dead actor or room reference")

func _outgoing_first_window(scene: PackedScene, wanted_phase: int) -> void:
	var boss: BossGolem = scene.instantiate() as BossGolem
	boss.position = Vector2(900, 640)
	boss.feedback = level.combat_feedback
	boss.player = null
	level.add_child(boss)
	await _step(3)
	var helper: Node2D = HELPER.attach(boss)
	var title: String = ("Depth" if boss is DepthBoss else "Golem") + " outgoing phase%d" % wanted_phase
	if wanted_phase == 2:
		boss.hurtbox.take_damage(_damage(boss.hurtbox, 255.0))
		await _time(0.20)
	player.reset_movement_at(Vector2(780, 640))
	player.controls_enabled = false
	player.hurtbox.set_invulnerable(false)
	player.damage_grace_remaining = 0.0
	await _step(2)
	boss.player = player
	level.combat_feedback.hit_stop_seconds = 0.08
	var hp_before: float = player.health.current_health
	boss.fsm.transition_to(&"sweep")
	for tick: int in Engine.physics_ticks_per_second * 2:
		if player.health.current_health < hp_before:
			break
		await _step(1)
	var attack: AttackSnapshot = boss.attack_hitbox.attack_snapshot
	var sample: Dictionary = helper.snapshot()
	_check(player.health.current_health == hp_before - 20.0 and level.combat_feedback.is_frozen() and attack != null and boss.attack_hitbox.active, title + " first active tick delivers real twenty-damage Player contact and starts hitstop")
	_check(sample.active and sample.phase == &"active" and sample.visible_sprites == 2 and sample.contact_refreshes == 1 and attack != null and sample.last_contact_root == attack.root_event_id and _inside_rectangle(helper, sample.sweep_rectangle), title + " same contact publishes exact painted active root before the frozen physics refresh")
	var clock_before: float = boss.state_time
	await _step(2)
	_check(boss.state_time == clock_before and helper.snapshot() == sample and player.health.current_health == hp_before - 20.0, title + " frozen first-contact paint holds and never duplicates damage")
	level.combat_feedback.reset_feedback()
	level.combat_feedback.hit_stop_seconds = 0.0
	boss.player = null
	boss.queue_free()
	await _step(3)
	player.reset_movement_at(Vector2(780, 640))
	player.controls_enabled = false
	player.hurtbox.set_invulnerable(true)
