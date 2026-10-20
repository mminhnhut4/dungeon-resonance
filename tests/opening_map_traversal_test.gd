extends SceneTree
## Geometry regression: instantiated actors use their real motor; AI is isolated.
## Each route starts once, then reaches/returns through physical movement only.
const BRANCH_ROOMS: Array[StringName] = [&"o01_p01",&"o01_p02",&"o02_b02",&"tv02_pine_court",&"xl02_cooling_yard"]
var checks: int = 0
var failures: int = 0
var rows: Array[Dictionary] = []
var world: Node2D
var room: ExteriorRoom
var actor: Player
var solid_baseline: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	solid_baseline = "--audit-solid-baseline" in OS.get_cmdline_user_args()
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").to_lower()
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"),"Isolated QA user directory")
	if failures > 0:
		quit(2)
		return
	AudioServer.set_bus_mute(0,true)
	world = Node2D.new()
	root.add_child(world)
	current_scene = world
	for id: StringName in BRANCH_ROOMS:
		room = ExteriorRoom.new()
		world.add_child(room)
		_check(room.configure(id,ExteriorRouteCatalog.MAIN,false),"Configure existing branch room "+String(id))
		await _frames(3)
		var geometry: Array[Dictionary] = []
		for index: int in [1,2]:
			var shelf: StaticBody2D = room.get_node("BranchShelf%d" % index) as StaticBody2D
			var collider: CollisionPolygon2D = shelf.get_child(0) as CollisionPolygon2D
			_check(collider.one_way_collision and is_equal_approx(collider.one_way_collision_margin,4.0),"Optional landing is one-way in "+String(id))
			geometry.append({"name":shelf.name,"polygon":Array(collider.polygon),"one_way":collider.one_way_collision})
			# This optional audit restores only the exact previous shelf flag in
			# the live fixture. It does not edit source or simulate a passing route.
			if solid_baseline: collider.one_way_collision = false
		var row: Dictionary = {"room":id,"surface":Array(room.surface),"anchors":room.anchors.duplicate(),"interactions":room.interactions.duplicate(),"shelves":geometry,"motor_routes":[]}
		await _frames(3)
		var takeoff: Vector2 = room.jumps[0]["takeoff"]
		var last_landing: Vector2 = room.jumps[1]["landing"]
		var west_x: float = takeoff.x-80.0
		var east_x: float = last_landing.x+160.0
		for scene: PackedScene in [preload("res://scenes/enemies/ancient_guard.tscn"),preload("res://scenes/enemies/runic_champion.tscn")]:
			for direction: float in [1.0,-1.0]:
				var enemy: BaseEnemy = scene.instantiate() as BaseEnemy
				var start_x: float = west_x if direction > 0.0 else east_x
				var goal_x: float = east_x if direction > 0.0 else west_x
				enemy.position = Vector2(start_x,room.floor_y(start_x))
				enemy.ai_enabled = false
				world.add_child(enemy)
				enemy.set_physics_process(false)
				enemy.state_machine.process_mode = Node.PROCESS_MODE_DISABLED
				await _frames(3)
				var crossed: bool = await _move_enemy(enemy,goal_x)
				row["motor_routes"].append({"type":enemy.enemy_type,"size":enemy.definition.body_size,"direction":direction,"start_x":start_x,"goal_x":goal_x,"end":enemy.position,"crossed":crossed})
				if not solid_baseline: _check(crossed,"Real %s motor walks %s under both shelves in %s" % [enemy.enemy_type,"east" if direction > 0.0 else "west",id])
				elif enemy.enemy_type == &"runic_champion": _check(not crossed,"Original solid shelf reproduces tall-actor obstruction in "+String(id))
				enemy.queue_free()
				await _frames(3)
		if not solid_baseline:
			actor = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
			actor.position = Vector2(west_x,room.floor_y(west_x))
			world.add_child(actor)
			await _frames(8)
			await _walk_player(takeoff.x)
			for jump: Dictionary in room.jumps:
				# Consecutive ascent: no reset/relocate between the two jumps.
				await _walk_player(Vector2(jump["takeoff"]).x)
				await _jump_player(jump["landing"])
				var landing: Vector2 = jump["landing"]
				_check(actor.motor.is_grounded() and absf(actor.position.y-landing.y)<2.0 and absf(actor.position.x-landing.x)<44.0,"Actual consecutive Player landing in "+String(id))
			await _walk_player(east_x)
			await _frames(Engine.physics_ticks_per_second)
			_check(actor.motor.is_grounded() and absf(actor.position.y-room.floor_y(actor.position.x))<3.0,"Upper branch returns to main road in "+String(id))
			await _walk_player(west_x)
			_check(actor.position.x<west_x+20.0 and actor.motor.is_grounded(),"Player walks back under optional branch in "+String(id))
			row["player_end"] = actor.position
			actor.queue_free()
			await _frames(4)
		_check(room.dry_anchor(&"west") and room.dry_anchor(&"east"),"Mandatory entry anchors remain dry in "+String(id))
		rows.append(row)
		room.queue_free()
		await _frames(4)
	await _gate_and_grounding()
	world.queue_free()
	await _frames(5)
	root.get_node("AudioManager").stop_all()
	var file := FileAccess.open("user://opening_map_traversal_%d%s.json" % [Engine.physics_ticks_per_second,"_solid_baseline" if solid_baseline else ""],FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"physics_hz":Engine.physics_ticks_per_second,"solid_baseline":solid_baseline,"proof":"actual actor motor + consecutive Player input; not autonomous AI or native visual proof","rooms":rows},"\t"))
	file.close()
	print("RESULT OpeningMapTraversal %d checks, %d failures; solid_baseline=%s" % [checks,failures,solid_baseline])
	quit(0 if failures == 0 else 1)

func _gate_and_grounding() -> void:
	room = ExteriorRoom.new()
	world.add_child(room)
	room.configure(&"o01_p02",ExteriorRouteCatalog.TUNNEL,false)
	var enemy: BaseEnemy = preload("res://scenes/enemies/runic_champion.tscn").instantiate() as BaseEnemy
	world.add_child(enemy)
	enemy.ai_enabled = false
	enemy.set_physics_process(false)
	enemy.state_machine.process_mode = Node.PROCESS_MODE_DISABLED
	enemy.position = Vector2(540,room.floor_y(540))
	await _frames(5)
	var crossed_closed_gate: bool = await _move_enemy(enemy,750,2.0)
	_check(not crossed_closed_gate and enemy.position.x<640.0-enemy.definition.body_size.x*0.5,"SC01 stays a real blocking wall while closed")
	room.set_gate(true)
	await _frames(3)
	var crossed_open_gate: bool = await _move_enemy(enemy,750)
	_check(crossed_open_gate,"Same motor crosses SC01 only after the gate opens")
	enemy.queue_free()
	room.queue_free()
	await _frames(4)
	room = ExteriorRoom.new()
	world.add_child(room)
	room.configure(&"o02_b04",ExteriorRouteCatalog.MAIN,false)
	var grounded: bool = false
	for visual: Node in room.get_children():
		if not visual is Polygon2D: continue
		var polygon: PackedVector2Array = visual.polygon
		if polygon.size() == 4 and is_equal_approx(polygon[0].x,1160.0) and is_equal_approx(polygon[1].x,1174.0):
			grounded = is_equal_approx(polygon[2].y,room.floor_y(1160))
	_check(grounded,"B04 mast foot touches authored floor rather than a stale elevation")
	room.queue_free()
	await _frames(4)

func _move_enemy(enemy: BaseEnemy, x: float, seconds: float = 8.0) -> bool:
	for tick: int in ceili(seconds*Engine.physics_ticks_per_second):
		await physics_frame
		enemy.motor.step_world(1.0/Engine.physics_ticks_per_second,Vector2(clampf((x-enemy.position.x)*10.0,-180.0,180.0),0),false)
		await process_frame
		if absf(enemy.position.x-x)<3.0 and enemy.is_on_floor(): return true
	return false

func _walk_player(x: float) -> void:
	var action: StringName = &"move_right" if x>actor.position.x else &"move_left"
	var direction: float = 1.0 if action == &"move_right" else -1.0
	Input.action_press(action)
	for tick: int in Engine.physics_ticks_per_second*4:
		await _frames(1)
		if direction*(actor.position.x-x)>=0.0: break
	Input.action_release(action)
	await _frames(ceili(0.2*Engine.physics_ticks_per_second))

func _jump_player(point: Vector2) -> void:
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	for tick: int in Engine.physics_ticks_per_second:
		await _frames(1)
		if actor.position.x>=point.x: break
	Input.action_release(&"move_right")
	await _frames(Engine.physics_ticks_per_second)
	Input.action_release(&"jump")
	await _frames(4)

func _frames(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: "+message)
