extends SceneTree
## Geometry probes use real shapes/motors; AI behavior belongs to enemy owner.
var checks: int = 0
var failures: int = 0
var audit_only: bool = false
var world: Node2D
var room: DungeonRoom
var probe: CharacterBody2D
var motor: KnockbackMotor
var report: Array[Dictionary] = []
var actor: Player
var campaign: WorldCampaign

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	audit_only = "--audit-baseline" in OS.get_cmdline_user_args()
	world = Node2D.new()
	root.add_child(world)
	current_scene = world
	for number: int in [1,2,3]:
		room = DungeonRoom.new()
		room.room_number = number
		world.add_child(room)
		await _step(3)
		var row: Dictionary = {"room_number":number,"visits":"foyer / secret" if number==1 else "elite arena" if number==2 else "boss","geometry":[],"min_solid_overhead_main":INF,"spawn_x":[180,560,715,870,1020,890,980,1090,1130],"door_x":1190}
		for body: Node in room.find_children("*","StaticBody2D",true,false):
			for child: Node in body.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D and not child.disabled:
					var rectangle: Rect2 = Rect2(child.global_position-child.shape.size*0.5,child.shape.size)
					row["geometry"].append({"name":body.name,"x":rectangle.position.x,"y":rectangle.position.y,"w":rectangle.size.x,"h":rectangle.size.y,"one_way":child.one_way_collision})
					if rectangle.position.y>0 and rectangle.end.y<640 and rectangle.end.x>180 and rectangle.position.x<1130 and not child.one_way_collision:
						row["min_solid_overhead_main"] = minf(row["min_solid_overhead_main"],640-rectangle.end.y)
		# Actual tallest ground collider, 76x100, plus champion 48x75.
		for size: Vector2 in [Vector2(20,36),Vector2(32,50),Vector2(48,75),Vector2(56,48),Vector2(76,100)]:
			_create_probe(size,Vector2(180,640))
			await _move_probe(1130,500)
			var east_ok: bool = probe.position.x>=1120 and probe.is_on_floor() and absf(probe.position.y-640)<2
			await _move_probe(180,500)
			var west_ok: bool = absf(probe.position.x-180)<12 and probe.is_on_floor()
			row["geometry"].append({"probe_size":str(size),"east_walk":east_ok,"west_walk":west_ok,"end_x":probe.position.x})
			if not audit_only:
				_check(east_ok and west_ok,"Both directions of combat spine pass collider "+str(size)+" room "+str(number))
			probe.queue_free()
			await _step(2)
		if not audit_only:
			_check(float(row["min_solid_overhead_main"])>=128,"Main corridor has 100px actor plus headroom; room "+str(number))
			# Existing instantiated world actors use their own WorldEnemyMotor.
			for scene: PackedScene in [preload("res://scenes/enemies/ancient_guard.tscn"),preload("res://scenes/enemies/runic_champion.tscn")]:
				var enemy: BaseEnemy = scene.instantiate() as BaseEnemy
				enemy.position = Vector2(180,640)
				world.add_child(enemy)
				enemy.set_physics_process(false) # Geometry isolation, not an AI test.
				enemy.state_machine.process_mode = Node.PROCESS_MODE_DISABLED
				probe = enemy
				motor = enemy.motor
				await _move_probe(1130,500)
				_check(enemy.position.x>=1120 and enemy.is_on_floor(),"Actual "+String(enemy.enemy_type)+" motor crosses room "+str(number))
				enemy.queue_free()
				await _step(2)
		if not is_finite(float(row["min_solid_overhead_main"])): row["min_solid_overhead_main"] = null
		report.append(row)
		room.queue_free()
		await _step(3)
	if not audit_only: await _campaign_cases()
	var output := FileAccess.open("res://docs/verification/dungeon_layout/"+("baseline-audit.json" if audit_only else "layout-audit.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	world.queue_free()
	await _step(4)
	print("RESULT DungeonLayout %d checks, %d failures; baseline_audit=%s" % [checks,failures,audit_only])
	quit(0 if failures==0 else 1)

func _campaign_cases() -> void:
	campaign = preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	campaign.run_seed = 41
	world.add_child(campaign)
	campaign.feedback.hit_stop_seconds = 0
	campaign.survival.set_enabled(false)
	actor = campaign.player
	actor.health.minimum_health = 1
	for stage: int in [1,2,3,4]:
		if stage>1: _check(campaign.enter_stage(stage),"Existing campaign stage loads "+str(stage))
		await _step(4)
		for enemy: Node2D in campaign.living_enemies():
			if enemy is BaseEnemy: enemy.set_physics_process(false)
			elif enemy is SlimeEnemy: enemy.ai_enabled = false
			elif enemy is BossGolem: enemy.set_physics_process(false)
		await _step(5)
		_check(actor.motor.is_grounded() and absf(actor.position.y-640)<2,"Player spawn settles safely stage "+str(stage))
		for enemy: Node2D in campaign.living_enemies():
			_check(absf(enemy.position.y-640)<2 or enemy is BaseEnemy and enemy.definition.flying or enemy.get_meta(&"enemy_type",&"")==&"sword_wraith","Ground/flying spawn contract remains valid stage "+str(stage))
		if stage==1:
			for dummy: Node in campaign.room.get_children():
				if dummy is TrainingDummy: _check(absf(dummy.position.y-640)<2,"Foyer dummy foot sits on actual combat floor")
		if stage<4:
			var anchors: Dictionary = campaign.room.traversal_points
			await _walk_actor(180)
			await _jump_actor(anchors[&"west_stair"])
			_check(actor.motor.is_grounded() and absf(actor.position.y-534)<2,"Ordinary jump reaches west one-way stair stage "+str(stage))
			await _jump_actor(anchors[&"west_gallery"])
			_check(actor.motor.is_grounded() and absf(actor.position.y-444)<2,"Ordinary jump reaches west gallery stage "+str(stage))
			if stage==2:
				_check(campaign.secret_chest.position == Vector2(90,366) and campaign.secret_chest.relic_reward,"Secret chest identity/reward/anchor retained")
				# Open existing barrier through its existing damage resolver, not teleport.
				for barrier: Node in campaign.room.get_children():
					if barrier is EnvironmentBarrier:
						var damage := DamageEvent.new()
						damage.source_id = actor.get_instance_id()
						damage.source_team_id = 1
						damage.target_id = barrier.hurtbox.get_actor_id()
						damage.attack_id = CombatIds.next_id()
						damage.root_event_id = damage.attack_id
						damage.hit_window_id = 1
						damage.source_kind = DamageEvent.SourceKind.RESONANCE
						damage.spell_id = &"firestorm"
						damage.base_damage = 1
						damage.burn_damage = 1
						barrier.hurtbox.take_damage(damage)
						_check(barrier.is_open,"Existing secret barrier still opens through combat contract")
				await _step(3)
				await _walk_actor(anchors[&"secret_takeoff"].x)
				await _jump_actor(Vector2(270,366))
				await _walk_actor(90)
				_check(actor.motor.is_grounded() and absf(actor.position.y-366)<2 and absf(actor.position.x-90)<20,"Secret chest reached by real jump/walking after gate opens")
				await _walk_actor(370)
				await _step(45)
			await _walk_actor(650)
			await _step(45)
			_check(actor.motor.is_grounded() and absf(actor.position.y-640)<2,"Gallery exit drops to combat floor without a trapping ledge")
			await _walk_actor(1010)
			await _jump_actor(anchors[&"east_stair"])
			_check(actor.motor.is_grounded() and absf(actor.position.y-534)<2,"Ordinary jump reaches east stair")
			await _jump_actor(anchors[&"east_gallery"])
			_check(actor.motor.is_grounded() and absf(actor.position.y-444)<2,"Upper east route reachable with existing jump")
			await _walk_actor(670)
			await _step(45)
			_check(actor.motor.is_grounded() and absf(actor.position.y-640)<2,"Upper east route has a safe central return drop")
		campaign.room.set_locked(false)
		await _step(3)
		await _walk_actor(1150)
		_check(actor.motor.is_grounded() and absf(actor.position.y-640)<2,"Unlocked exit approach stays on original floor")
		for column: Sprite2D in campaign.room.architecture.grounded_props:
			_check(absf(column.position.y+column.texture.get_height()*column.scale.y-640)<0.1,"Architecture pillar foot touches original floor")
	_release()
	campaign.queue_free()
	await _step(6)

func _walk_actor(x: float) -> void:
	var action: StringName = &"move_right" if x>actor.position.x else &"move_left"
	var direction: float = 1 if action==&"move_right" else -1
	Input.action_press(action)
	for tick: int in 350:
		await _step(1)
		if direction*(actor.position.x-x)>=0: break
	Input.action_release(action)
	await _step(12)

func _jump_actor(at: Vector2) -> void:
	var action: StringName = &"move_right" if at.x>actor.position.x else &"move_left"
	var direction: float = 1 if action==&"move_right" else -1
	Input.action_press(action)
	Input.action_press(&"jump")
	for tick: int in 60:
		await _step(1)
		if direction*(actor.position.x-at.x)>=0: break
	Input.action_release(action)
	await _step(60)
	Input.action_release(&"jump")
	await _step(4)

func _release() -> void:
	for action: StringName in [&"move_left",&"move_right",&"jump",&"dash",&"interact"]: Input.action_release(action)

func _create_probe(size: Vector2, at: Vector2) -> void:
	probe = CharacterBody2D.new()
	probe.collision_layer = 4
	probe.collision_mask = 1
	probe.floor_snap_length = 1
	var shape := RectangleShape2D.new()
	shape.size = size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0,-size.y*0.5)
	probe.add_child(collider)
	motor = KnockbackMotor.new()
	motor.body = probe
	probe.add_child(motor)
	probe.position = at
	world.add_child(probe)

func _move_probe(x: float, budget: int) -> void:
	for tick: int in budget:
		await physics_frame
		var delta_x: float = x-probe.position.x
		motor.step(1.0/60.0,INF,clampf(delta_x*10,-180,180))
		await process_frame
		if absf(x-probe.position.x)<3 and probe.is_on_floor(): break

func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _check(passed: bool, message: String) -> void:
	checks+=1
	if not passed:
		failures+=1
		print("FAIL: "+message)
