extends SceneTree
var run: WorldCampaign
var checks: int=0
var failures: int=0
const DEST: String="res://docs/verification/reactive_aggro_gpu_r5"
var images: Array[Dictionary]=[]
var metrics: Dictionary={}
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	if DisplayServer.get_name()=="headless": print("ERROR: GPU route refuses headless" );quit(2);return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	Engine.max_fps=60
	Engine.physics_ticks_per_second=60
	DirAccess.make_dir_recursive_absolute(DEST)
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated route user://")
	if failures: quit(2);return
	AudioServer.set_bus_mute(0,true)
	run=preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	run.run_seed=20261003;run.profile=SanctuaryProfile.new()
	root.add_child(run);current_scene=run;run.survival.set_enabled(false)
	await _frames(8)
	var shapes: Array[Dictionary]=[]
	for node: Node in run.room.find_children("*","StaticBody2D",true,false):
		var body:=node as StaticBody2D
		for child: Node in body.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				shapes.append({"path":String(body.get_path()),"position":child.global_position,"size":child.shape.size,"one_way":child.one_way_collision,"layer":body.collision_layer})
	metrics["first_room_static_colliders"]=shapes
	var bodies: Array[Dictionary]=[]
	var guard: BaseEnemy
	for enemy: Node in run.living_enemies():
		enemy.ai_enabled=false
		for child: Node in enemy.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D:
				bodies.append({"type":enemy.enemy_type if enemy is BaseEnemy else "runic_slime","size":child.shape.size,"scale":child.global_scale,"physical_height":child.shape.size.y*child.global_scale.y,"position":enemy.global_position})
		if enemy is BaseEnemy and enemy.definition.id==&"ancient_guard": guard=enemy
	metrics["first_room_enemy_bodies"]=bodies
	_check(guard!=null,"Seeded existing first-room Guard")
	if guard==null: await _finish();return
	run.player.controls_enabled=false;run.player.reset_movement_at(Vector2(180,640));run.player.controls_enabled=false
	await _shot("before_far_hit")
	var before: Vector2=guard.global_position
	_hit(guard,1.0);guard.ai_enabled=true
	await _frames(Engine.physics_ticks_per_second)
	_check(guard.hit_aggro.active() and guard.player==run.player and guard.state_machine.get_state_id()==&"chase","Actual first-room far hit creates pursuit")
	_check(guard.global_position.x<before.x-25.0,"Actual seeded Guard advances toward attacker on native motor")
	metrics["guard_far_hit"]={"before":before,"after":guard.global_position,"state":guard.state_machine.get_state_id(),"remaining":guard.hit_aggro.remaining}
	guard.ai_enabled=false
	await _shot("far_hit_pursuit")
	var room_id: int=run.room.get_instance_id()
	run.player.reset_movement_at(Vector2(180,640));run.player.controls_enabled=true
	Input.action_press(&"move_right")
	var wall_hits: Dictionary={}
	for tick: int in int(Engine.physics_ticks_per_second*4.2):
		await _frames(1)
		for index: int in run.player.get_slide_collision_count():
			var collision: KinematicCollision2D=run.player.get_slide_collision(index)
			var node: Node=collision.get_collider() as Node
			if node!=null and absf(collision.get_normal().x)>0.5: wall_hits[String(node.get_path())]=node.global_position
	Input.action_release(&"move_right")
	_check(run.stage==1 and run.room.locked and not run.room.door_shape.disabled,"First-room gate stays locked with living enemies")
	_check(run.player.global_position.x>1160.0 and run.player.global_position.x<1178.0 and not wall_hits.is_empty(),"Native player movement meets actual locked door at1190, does not phase through")
	metrics["locked_gate"]={"player":run.player.global_position,"door":run.room.door.global_position,"wall_hits":wall_hits,"stage":run.stage,"room_id":room_id}
	await _shot("locked_gate_native_walk")
	for enemy: Node in run.living_enemies(): _hit(enemy,10000.0)
	await _frames(12)
	_check(not run.room.locked and run.room.door_shape.disabled,"Actual enemy defeat/clear pipeline disables gate collision")
	Input.action_press(&"move_right")
	for tick: int in int(Engine.physics_ticks_per_second*1.0):
		await _frames(1)
		if run.stage==2: break
	Input.action_release(&"move_right")
	_check(run.stage==2 and run.room.get_instance_id()!=room_id,"Native walk crosses unlocked threshold and advances to existing next stage")
	_check(run.player.health.current_health>0.0 and run.outcome==&"","Route succeeds without death or artificial wall disable")
	metrics["after_clear"]={"stage":run.stage,"room_id":run.room.get_instance_id(),"player":run.player.global_position,"locked":run.room.locked,"outcome":run.outcome}
	await _shot("after_clear_next_stage")
	await _finish()
func _hit(enemy: Node,amount: float) -> void:
	var event:=DamageEvent.new();event.source_id=run.player.get_instance_id();event.source_team_id=1;event.target_id=enemy.get_instance_id();event.attack_id=CombatIds.next_id();event.root_event_id=event.attack_id;event.hit_window_id=1;event.base_damage=amount;event.physical_damage=true
	enemy.hurtbox.take_damage(event)
func _frames(count: int) -> void:
	for tick: int in count: await physics_frame;await process_frame
func _check(passed: bool,message: String) -> void:
	checks+=1
	if not passed: failures+=1;print("FAIL: "+message)
func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var frame: Image=root.get_texture().get_image()
	var path: String=DEST+"/"+label+".png"
	_check(frame.save_png(path)==OK,"Actual GPU screenshot "+label)
	images.append({"file":path.trim_prefix("res://"),"stage":run.stage,"player":run.player.global_position,"hp":run.player.health.current_health,"physics_frame":Engine.get_physics_frames()})
func _finish() -> void:
	var report:=FileAccess.open(DEST+"/capture_manifest.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"images":images,"scope":"Actual native first-room motor, accepted damage, clear/gate pipeline; no full-suite, performance, final map redesign or manual focus acceptance","body_sha256":FileAccess.get_sha256("res://scripts/presentation/guard_body_frames.gd"),"sweep_sha256":FileAccess.get_sha256("res://scripts/presentation/guard_sweep_vfx.gd")},"\t"));report.close()
	Input.action_release(&"move_right");run.queue_free();await _frames(5);root.get_node("AudioManager").stop_all()
	var file:=FileAccess.open("user://opening_route_%d.json"%Engine.physics_ticks_per_second,FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"geometry_edits":"none; mapworker owns layout"},"\t"));file.close()
	print("RESULT OpeningRoute %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
