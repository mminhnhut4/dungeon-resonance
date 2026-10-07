extends SceneTree
var checks: int=0
var failures: int=0
var arena: Node2D
var hero: Player
var feedback: CombatFeedback
var actors: Array[Node]=[]
var metrics: Dictionary={}
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated user://")
	if failures: quit(2);return
	AudioServer.set_bus_mute(0,true)
	arena=Node2D.new();root.add_child(arena)
	_floor(Vector2(10000,650),Vector2(30000,20))
	hero=preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	arena.add_child(hero);hero.reset_movement_at(Vector2(20000,640));hero.controls_enabled=false
	feedback=CombatFeedback.new();arena.add_child(feedback);feedback.hit_stop_seconds=0.0
	for scene: PackedScene in [preload("res://scenes/enemies/ancient_guard.tscn"),preload("res://scenes/enemies/slime_enemy.tscn"),preload("res://scenes/enemies/mutant_slime.tscn"),preload("res://scenes/enemies/boss_golem.tscn")]:
		var enemy: Node=scene.instantiate()
		enemy.position=Vector2(900+actors.size()*250,640);enemy.player=hero
		if enemy is BossGolem: enemy.feedback=feedback
		else: enemy.combat_feedback=feedback
		arena.add_child(enemy);actors.append(enemy)
	await _frames(6)
	for enemy: Node in actors:
		_hit(enemy,1.0)
		_check(enemy.hit_aggro.active() and enemy.player==hero and is_equal_approx(enemy.hit_aggro.remaining,20.0),"Accepted player hit starts 20s memory for "+enemy.get_class())
	var settle_ticks: int=ceili(Engine.physics_ticks_per_second*0.22)
	await _frames(settle_ticks)
	for enemy: Node in actors:
		_check(enemy.player==hero and enemy.hit_aggro.active(),"Damage target persists outside old sight radius")
		if not enemy is BossGolem: _check(enemy.state_machine.get_state_id()==&"chase","Hurt returns to chase attacker beyond sight radius")
	# Advance actual actor physics, not a copied implementation of the lease math.
	await _frames(int(Engine.physics_ticks_per_second*19)-settle_ticks)
	for enemy: Node in actors:
		_check(absf(enemy.hit_aggro.remaining-1.0)<0.001,"Hit0 retains target through actual second19")
		_hit(enemy,1.0)
		_check(is_equal_approx(enemy.hit_aggro.remaining,20.0),"Accepted hit19 resets deadline to39")
	await _frames(int(Engine.physics_ticks_per_second*20)-1)
	for enemy: Node in actors:
		_check(enemy.hit_aggro.active(),"Target remains immediately before39")
	await _frames(1)
	for enemy: Node in actors:
		_check(not enemy.hit_aggro.active() and enemy.player==null,"Deadline drops actual actor target")
		_check((enemy.fsm.get_state_id()==&"idle" if enemy is BossGolem else enemy.state_machine.get_state_id()==&"patrol") and not _hitbox(enemy).active,"Expiry cancels attack and returns original idle/patrol")
		hero.reset_movement_at(enemy.global_position+Vector2(60,0));hero.controls_enabled=false
		await _frames(8)
		_check(enemy.player==null,"Expired target is not immediately reacquired on sight")
		_hit(enemy,1.0)
		_check(enemy.player==hero and enemy.hit_aggro.active(),"New accepted hit reactivates expired memory")
	await _pause_hitstop_and_invalid_hits()
	await _walls_and_death()
	await _finish()

func _pause_hitstop_and_invalid_hits() -> void:
	var enemy: Node=actors[0]
	for other: Node in actors: other.ai_enabled=false
	enemy.ai_enabled=true
	_hit(enemy,1.0)
	var held: float=enemy.hit_aggro.remaining
	paused=true
	for tick: int in 8: await process_frame
	_check(enemy.hit_aggro.remaining==held,"Tree pause does not advance20s")
	paused=false
	feedback.hit_stop_remaining=0.2
	await _frames(1)
	held=enemy.hit_aggro.remaining
	await _frames(4)
	_check(enemy.hit_aggro.remaining==held,"Real feedback hitstop does not advance20s")
	feedback.reset_feedback()
	enemy.ai_enabled=false
	var before: float=enemy.hit_aggro.remaining
	enemy.hurtbox.set_invulnerable(true)
	_hit(enemy,1.0)
	_check(enemy.hit_aggro.remaining==before,"Invulnerable blocked hit cannot renew memory")
	enemy.hurtbox.set_invulnerable(false)
	_hit(enemy,0.0)
	_check(enemy.hit_aggro.remaining==before,"Zero-damage projectile-like hit cannot renew memory")
	var fake:=DamageEvent.new();fake.source_id=actors[1].get_instance_id();fake.source_team_id=0;fake.target_id=enemy.get_instance_id();fake.attack_id=CombatIds.next_id();fake.root_event_id=fake.attack_id;fake.hit_window_id=1;fake.base_damage=1.0
	enemy.hurtbox.take_damage(fake)
	_check(enemy.hit_aggro.remaining==before,"Non-player damage cannot renew player target")
	var event: DamageEvent=_hit(enemy,1.0)
	enemy.ai_enabled=true;await _frames(Engine.physics_ticks_per_second);enemy.ai_enabled=false
	before=enemy.hit_aggro.remaining
	enemy.hurtbox.take_damage(event)
	_check(enemy.hit_aggro.remaining==before,"Resolver duplicate cannot renew memory")
	var stranger: Player=preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	arena.add_child(stranger);stranger.reset_movement_at(Vector2(21000,640));stranger.controls_enabled=false
	var wrong:=DamageEvent.new();wrong.source_id=stranger.get_instance_id();wrong.source_team_id=1;wrong.target_id=enemy.get_instance_id();wrong.attack_id=CombatIds.next_id();wrong.root_event_id=wrong.attack_id;wrong.hit_window_id=1;wrong.base_damage=1.0
	var result: DamageResult=enemy.hurtbox.take_damage(wrong)
	_check(not result.blocked and enemy.hit_aggro.remaining==before,"Another Player instance cannot impersonate the registered attacker")
	stranger.queue_free();await _frames(2)
	metrics["pause_hitstop_invalid"]={"held_seconds":held,"remaining_after_duplicate":before}

func _walls_and_death() -> void:
	var enemy: Node=actors[0]
	enemy.global_position=Vector2(900,640);enemy.motor.reset_motion()
	var wall: StaticBody2D=_floor(Vector2(1000,360),Vector2(24,720))
	hero.reset_movement_at(Vector2(1030,640));hero.controls_enabled=false
	_hit(enemy,1.0);enemy.ai_enabled=true
	await _frames(int(Engine.physics_ticks_per_second*1.0))
	_check(enemy.hit_aggro.active() and enemy.player==hero,"Solid wall/LOS does not erase20s attacker memory")
	_check(enemy.global_position.x<988.0 and not enemy.attack_hitbox.active and enemy.state_machine.get_state_id()==&"chase","Grounded pursuit stops at wall and does not attack through it")
	metrics["solid_wall"]={"enemy":enemy.global_position,"wall":wall.global_position,"memory":enemy.hit_aggro.remaining}
	var branch:=Node2D.new();arena.add_child(branch)
	for other: Node in actors: other.ai_enabled=false;_hit(other,1.0)
	hero.reparent(branch)
	for other: Node in actors: _check(other.player==null and not other.hit_aggro.active(),"Player leaves scene scope: target clears even with AI disabled")
	var rejected: DamageEvent=_hit(enemy,1.0)
	_check(not enemy.hit_aggro.active(),"Other scene-scope hit cannot recreate an old encounter target")
	hero.reparent(arena)
	for other: Node in actors: _hit(other,1.0)
	var doomed: Node=actors[1]
	_hit(doomed,10000.0)
	_check(doomed.player==null and not doomed.hit_aggro.active(),"Enemy death clears memory synchronously")
	hero.health.apply_damage(10000.0)
	for other: Node in actors: _check(other.player==null and not other.hit_aggro.active(),"Player death clears target/memory")
	# Separate valid player restores a scene fixture, not a real save or production heal.
	for other: Node in actors: other.queue_free()
	actors.clear();await _frames(4)
	_check(get_nodes_in_group(&"enemies").is_empty(),"Owner teardown removes actors and memory")

func _hit(enemy: Node,amount: float) -> DamageEvent:
	var event:=DamageEvent.new();event.source_id=hero.get_instance_id();event.source_team_id=1;event.target_id=enemy.get_instance_id();event.attack_id=CombatIds.next_id();event.root_event_id=event.attack_id;event.hit_window_id=1;event.base_damage=amount;event.physical_damage=true
	enemy.hurtbox.take_damage(event)
	return event
func _hitbox(enemy: Node) -> Hitbox: return enemy.attack_hitbox if enemy is BaseEnemy or enemy is BossGolem else enemy.bite_hitbox
func _floor(center: Vector2,size: Vector2) -> StaticBody2D:
	var body:=StaticBody2D.new();body.position=center;body.collision_layer=1;body.collision_mask=0
	var shape:=CollisionShape2D.new();var rectangle:=RectangleShape2D.new();rectangle.size=size;shape.shape=rectangle;body.add_child(shape);arena.add_child(body);return body
func _frames(count: int) -> void:
	for tick: int in count: await physics_frame;await process_frame
func _check(passed: bool,message: String) -> void:
	checks+=1
	if not passed: failures+=1;print("FAIL: "+message)
func _finish() -> void:
	paused=false;feedback.reset_feedback();arena.queue_free();await _frames(5)
	root.get_node("AudioManager").stop_all()
	var file:=FileAccess.open("user://reactive_aggro_%d.json"%Engine.physics_ticks_per_second,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"physics_hz":Engine.physics_ticks_per_second},"\t"));file.close()
	print("RESULT ReactiveAggro %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
