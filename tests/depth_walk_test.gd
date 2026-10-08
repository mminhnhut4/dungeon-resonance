extends "res://tests/depth_actor_test.gd"
## Only the appended gait atlas, manual physical seek and owner lifetimes.

func _enemy(floor_id: int) -> void:
	var enemy: BaseEnemy = await _fresh_enemy(floor_id)
	hero.relocate(Vector2(100 if floor_id != 4 else 200, 640))
	enemy.attack_cooldown = 10.0
	enemy.state_machine.transition_to(&"chase")
	enemy.ai_enabled = true
	var frames: Dictionary[int, bool] = {}
	var scales: Dictionary[String, bool] = {}
	var start: Vector2 = enemy.global_position
	var collider: CollisionShape2D = enemy.get_node("BodyCollision") as CollisionShape2D
	var collider_id: int = collider.shape.get_instance_id()
	var collider_transform: Transform2D = collider.transform
	for step: int in 16:
		await _time(0.06)
		var sample: Dictionary = enemy.visual.snapshot()
		if sample.clip == &"walk":
			frames[int(sample.frame)] = true
			scales[str(sample.scale)] = true
			_check(sample.foot.is_equal_approx(enemy.global_position), "Floor%d gait frame%d remains at the physical root" % [floor_id, int(sample.frame)])
			if frames.size() in [1, 3]: await _capture("enemy_%d_walk_%d" % [floor_id, frames.size()], enemy)
		if frames.size() == 4: break
	_check(enemy.visual.snapshot().walk_frames == 4 and enemy.visual.snapshot().frames == 10 and frames.size() == 4 and enemy.global_position.distance_to(start) > 20, "Floor%d cycles four actual appended gait/wing/drift frames during real movement" % floor_id)
	_check(scales.size() == 1 and collider.shape.get_instance_id() == collider_id and collider.transform == collider_transform and not enemy.attack_hitbox.active, "Floor%d gait keeps one source-normalized scale and leaves its collider/window unchanged" % floor_id)
	feedback.hit_stop_seconds = 0.08
	enemy.hurtbox.take_damage(_event(enemy, 1.0))
	var frozen: Dictionary = enemy.visual.snapshot()
	await _step(2)
	_check(feedback.is_frozen() and enemy.visual.snapshot() == frozen, "Floor%d appended gait/body holds the exact actual-hit frozen sample" % floor_id)
	feedback.reset_feedback()
	feedback.hit_stop_seconds = 0.0

func _boss() -> void:
	var boss: BossGolem = await _fresh_boss(Vector2(800, 640))
	hero.relocate(Vector2(200, 640))
	boss.ai_enabled = true
	var frames: Dictionary[int, bool] = {}
	var scales: Dictionary[String, bool] = {}
	var start: Vector2 = boss.global_position
	for step: int in 12:
		await _time(0.06)
		var sample: Dictionary = boss.presentation.snapshot()
		if sample.clip == &"walk":
			frames[int(sample.frame)] = true
			scales[str(sample.scale)] = true
			_check(sample.foot.is_equal_approx(boss.global_position), "Boss gait frame%d remains at the physical foot" % int(sample.frame))
			if frames.size() in [1, 3]: await _capture("boss_walk_%d" % frames.size(), boss)
		if frames.size() == 4: break
	_check(boss.presentation.snapshot().walk_frames == 4 and boss.presentation.snapshot().frames == 16 and frames.size() == 4 and boss.global_position.distance_to(start) > 30, "Seal boss seeks four real gait frames while its grounded motor travels")
	_check(scales.size() == 1 and boss.fsm.get_state_id() == &"idle" and not boss.attack_hitbox.active, "Boss gait has one fixed walk scale and cannot create a combat window")

func _lifetimes() -> void:
	for cycle: int in 2:
		for floor_id: int in range(1, 5):
			var enemy: BaseEnemy = await _fresh_enemy(floor_id)
			_check(enemy.visual.snapshot().frames == 10 and enemy.visual.snapshot().walk_frames == 4, "Appended floor%d atlas survives actor teardown cycle%d" % [floor_id, cycle])
			enemy.queue_free()
			await _step(3)
		var boss: BossGolem = await _fresh_boss(Vector2(800, 640))
		_check(boss.presentation.snapshot().frames == 16 and boss.presentation.snapshot().walk_frames == 4, "Appended boss atlas survives actor teardown cycle%d" % cycle)
		boss.queue_free()
		await _step(3)
