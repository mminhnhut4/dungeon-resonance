extends SceneTree
## Focused actual Guard/motor/FSM presentation proof. No pose/clock/position warps.
## Native screenshots require explicit opt-in; headless writes JSON only.
var arena: Node2D
var guard: BaseEnemy
var hero: Player
var feedback: CombatFeedback
var camera: Camera2D
var wall: StaticBody2D
var native: bool = false
var evidence: String = ""
var checks: int = 0
var failures: int = 0
var sequence: Array[Dictionary] = []
var captures: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var metrics: Dictionary = {}
var _last_motes: Array = []
var _last_motion_position: Vector2 = Vector2.ZERO
var _stationary_world_samples: int = 0
var _max_motes: int = 0
var _max_root_error: float = 0.0
var _max_anchor_error: float = 0.0
var _body_shape_id: int = 0
var _body_shape_size: Vector2 = Vector2.ZERO
var _body_shape_position: Vector2 = Vector2.ZERO
var _hit_shape_id: int = 0
var _definition_id: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	native = DisplayServer.get_name()!="headless"
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/").to_lower()
	evidence = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\","/")
	if not _check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").to_lower().begins_with(qa+"/"),"Isolated presentation QA user directory"):
		quit(2)
		return
	if not _check(native == ("--native-approved" in OS.get_cmdline_user_args()) and (not native or evidence.is_absolute_path()),"Native requires explicit approval and an absolute evidence directory"):
		quit(2)
		return
	if native:
		root.set_flag(Window.FLAG_NO_FOCUS,true)
		root.size = Vector2i(1280,720)
		root.content_scale_size = Vector2i(1280,720)
		DirAccess.make_dir_recursive_absolute(evidence)
	AudioServer.set_bus_mute(0,true)
	RenderingServer.set_default_clear_color(Color("202b2d"))
	await _build()
	var completed: bool = false
	if _check(guard.visual.body_frames!=null and guard.visual.body_frames.valid and guard.visual.opening_skill_art!=null,"Actual AncientGuard scene binds existing authored body and new helper"):
		completed = await _exercise()
	await _finish(completed)

func _build() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var room := DungeonRoom.new()
	room.room_number = 1
	arena.add_child(room) # Existing authored opening floor/shelves/colliders.
	feedback = CombatFeedback.new()
	feedback.hit_stop_seconds = 0.08
	arena.add_child(feedback)
	feedback.enable_global_hitstop(false) # Actual room-owned local feedback clock.
	hero = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	hero.position = Vector2(230,640) # One fixture spawn, never repositioned afterward.
	hero.combat_feedback = feedback
	hero.controls_enabled = false
	arena.add_child(hero)
	hero.health.minimum_health = 1.0
	hero.hurtbox.hit_resolved.connect(_accepted_contact)
	guard = preload("res://scenes/enemies/ancient_guard.tscn").instantiate() as BaseEnemy
	guard.position = Vector2(650,640) # One fixture spawn; sight AI owns every step.
	guard.player = hero
	guard.combat_feedback = feedback
	arena.add_child(guard)
	camera = Camera2D.new()
	camera.position = Vector2(620,590)
	camera.zoom = Vector2(3,3) # QA close-up only; never edits an actor/collider.
	arena.add_child(camera)
	camera.make_current()
	await _frames(5)
	var body: CollisionShape2D = guard.get_node("BodyCollision") as CollisionShape2D
	_body_shape_id = body.shape.get_instance_id()
	_body_shape_size = (body.shape as RectangleShape2D).size
	_body_shape_position = body.position
	_hit_shape_id = guard.attack_hitbox.collision_shape.get_instance_id()
	_definition_id = guard.definition.get_instance_id()
	_last_motion_position = guard.global_position
	metrics["spawn"] = {"guard":guard.global_position,"player":hero.global_position,"body_shape_class":body.shape.get_class(),"body_size":_body_shape_size,"body_position":_body_shape_position,"player_collision":_player_shape(),"definition":guard.definition.resource_path,"note":"Only initial fixture placement; all recorded walking is actual sight AI/WorldEnemyMotor."}

func _exercise() -> bool:
	var helper: OpeningEnemySkillArt = guard.visual.opening_skill_art
	var start: Vector2 = guard.global_position
	var walked: bool = false
	for tick: int in Engine.physics_ticks_per_second*2:
		await _frames(1)
		_sample("walk")
		if guard.global_position.x<start.x-30.0 and helper.step_count>0 and int(helper.snapshot()["foot_motes"])>0:
			walked = true
			break
	if not _check(walked and guard.state_machine.get_state_id()==&"chase" and guard.is_on_floor(),"Sight AI and actual motor produce grounded translation plus authored foot plants"): return false
	await _capture("01_guard_walk")
	_check(_stationary_world_samples>0,"A retained foot mote stays at its planted world point while the actor translates")
	var held: Dictionary = helper.snapshot()
	var held_position: Vector2 = guard.global_position
	paused = true
	await _frames(4)
	_check(helper.snapshot()==held and guard.global_position==held_position,"Tree pause holds helper pose, planted motes and actual actor")
	paused = false
	guard.ai_enabled = false
	await _frames(4)
	_check(helper.snapshot()==held and guard.global_position==held_position,"AI-off freezes the sampled pose and cannot emit imaginary foot plants")
	guard.ai_enabled = true
	# A real accepted hit supplies the existing20s attacker memory. The wall
	# blocks the actual chase without patrol turning away or an AI override.
	wall = _wall(guard.global_position.x-55.0)
	var provoked: DamageResult = guard.hurtbox.take_damage(_incoming(1.0))
	_check(not provoked.blocked and provoked.actual_damage>0.0 and guard.hit_aggro.active(),"Live Player source provokes through the existing damage/aggro owner")
	var reached_wall: bool = false
	for tick: int in Engine.physics_ticks_per_second*3:
		await _frames(1)
		_sample("wall_approach")
		if guard.is_on_wall() and guard.state_machine.get_state_id()==&"chase" and not feedback.is_frozen():
			reached_wall = true
			break
	if not _check(reached_wall,"Actual grounded chase reaches the temporary solid through WorldEnemyMotor"): return false
	await _frames(3)
	var blocked_steps: int = helper.step_count
	var blocked_x: float = guard.global_position.x
	for tick: int in ceili(0.35*Engine.physics_ticks_per_second):
		await _frames(1)
		_sample("wall_blocked")
	_check(absf(guard.global_position.x-blocked_x)<0.05 and helper.step_count==blocked_steps and not helper.moving,"Wall-blocked real motor creates no footstep motion or dust emissions")
	_check(guard.global_position.x>wall.position.x+10.0 and not guard.attack_hitbox.active,"Ground body stays outside the unchanged solid and cannot attack through it")
	wall.queue_free()
	wall = null
	await _frames(3)
	if not await _wait_phase(&"telegraph",guard.definition.windup*0.82,9.0): return false
	_check(helper.phase==&"telegraph" and not guard.attack_hitbox.active,"Metal anticipation reads real tell clock while physical attack is closed")
	await _capture("02_guard_tell")
	if not await _wait_phase(&"attack",0.0,2.0): return false
	_check(helper.phase==&"attack" and guard.attack_hitbox.active,"First actual active state samples the existing committed blade")
	await _capture("03_guard_active")
	if not await _wait_phase(&"recover",0.0,2.0): return false
	_check(helper.phase==&"recover" and not guard.attack_hitbox.active,"Actual recovery closes the physical hitbox and fades the blade accent")
	await _capture("04_guard_recover")
	_check(not contacts.is_empty() and guard.visual.sweep_vfx.impact_count>0,"Existing sweep actually changes Player HP and owns the accepted-contact ink")
	if not contacts.is_empty():
		_check(contacts[0]["helper_phase"]==&"attack" and contacts[0]["hitbox_active"] and contacts[0]["body_clip"]==&"attack_sweep","Accepted contact already sees active helper/body before feedback freeze")
	if not await _wait_phase(&"telegraph",0.18,4.0): return false
	var before_hits: int = feedback.impact_count
	var interrupted: DamageResult = guard.hurtbox.take_damage(_incoming(1.0))
	_check(not interrupted.blocked and interrupted.actual_damage>0.0 and feedback.impact_count==before_hits+1 and feedback.is_frozen(),"Accepted hit during real tell activates actual room feedback freeze")
	_check(guard.state_machine.get_state_id()==&"hurt" and helper.phase==&"" and int(helper.snapshot()["foot_motes"])==0 and not helper.front_planted and not helper.back_planted and not guard.attack_hitbox.active,"Hurt synchronously clears all new cues before frozen physics can sample again")
	await _capture("05_guard_hurt_interrupt")
	held = helper.snapshot()
	var frozen_clock: float = guard.state_time
	for tick: int in maxi(2,floori(0.025*Engine.physics_ticks_per_second)):
		await _frames(1)
		_sample("accepted_hitstop")
	_check(feedback.is_frozen() and guard.state_time==frozen_clock and helper.snapshot()==held,"Real hitstop holds cleared helper and the authoritative hurt clock together")
	var body: CollisionShape2D = guard.get_node("BodyCollision") as CollisionShape2D
	_check(body.shape.get_instance_id()==_body_shape_id and (body.shape as RectangleShape2D).size==_body_shape_size and body.position==_body_shape_position and guard.attack_hitbox.collision_shape.get_instance_id()==_hit_shape_id and guard.definition.get_instance_id()==_definition_id,"Presentation preserves raw physical shape/resources, definition and hitbox ownership")
	_check(_max_root_error<0.001 and _max_anchor_error<0.001 and guard.visual.motion.transform==Transform2D.IDENTITY,"Every motion sample preserves common foot root and exact authored blade anchors")
	_check(_max_motes<=3 and get_nodes_in_group(&"opening_enemy_skill_art").size()==1 and helper.snapshot()["damage_emitters"]==0 and helper.snapshot()["lights"]==0 and helper.snapshot()["audio_voices"]==0,"New presentation remains bounded and has no gameplay/light/audio emitters")
	metrics["walk"] = {"start":start,"end_before_wall":held_position,"stationary_world_samples":_stationary_world_samples,"max_foot_motes":_max_motes,"max_root_error":_max_root_error,"max_anchor_error":_max_anchor_error}
	metrics["interrupt"] = {"state":guard.state_machine.get_state_id(),"clock":guard.state_time,"feedback_frozen":feedback.is_frozen(),"helper":helper.snapshot()}
	return true

func _wait_phase(wanted: StringName, minimum: float, seconds: float) -> bool:
	for tick: int in ceili(seconds*Engine.physics_ticks_per_second):
		await _frames(1)
		_sample("natural_"+String(wanted))
		if guard.state_machine.get_state_id()==wanted and guard.state_time>=minimum: return true
	return _check(false,"Natural AI reaches "+String(wanted)+" without forcing state/clock/position")

func _sample(label: String) -> void:
	if not is_instance_valid(guard) or guard.visual.opening_skill_art==null: return
	var helper: OpeningEnemySkillArt = guard.visual.opening_skill_art
	var sampled: Dictionary = helper.snapshot()
	var world_motes: Array = sampled["foot_motes_world"]
	if guard.global_position.distance_to(_last_motion_position)>0.1:
		for point: Vector2 in world_motes:
			if _last_motes.has(point): _stationary_world_samples += 1
	_last_motes = world_motes.duplicate()
	_last_motion_position = guard.global_position
	_max_motes = maxi(_max_motes,int(sampled["foot_motes"]))
	_max_root_error = maxf(_max_root_error,EnemySpriteArt.foot_world(guard.visual.sprite,GuardBodyFrames.PIVOT).distance_to(guard.global_position))
	if helper.phase!=&"":
		# Hurt/dead synchronously hide the new blade before hitstop; their unused
		# cached points need not seek while frozen. Every visible phase must match.
		_max_anchor_error = maxf(_max_anchor_error,helper.blade_hand.distance_to(guard.visual.body_frames.anchor_local("sword_hand")))
		_max_anchor_error = maxf(_max_anchor_error,helper.blade_tip.distance_to(guard.visual.body_frames.anchor_local("saber_tip")))
	camera.global_position = guard.global_position+Vector2(guard.facing*30.0,-50.0)
	camera.force_update_scroll()
	if sequence.size()<2000:
		sequence.append({"sample":label,"physics_frame":Engine.get_physics_frames(),"actor":guard.global_position,"velocity":guard.velocity,"grounded":guard.is_on_floor(),"wall":guard.is_on_wall(),"state":guard.state_machine.get_state_id(),"state_time":guard.state_time,"hitbox_active":guard.attack_hitbox.active,"feedback_frozen":feedback.is_frozen(),"body":guard.visual.body_frames.snapshot(),"helper":sampled})

func _capture(label: String) -> void:
	if not native: return
	await RenderingServer.frame_post_draw
	var image_path: String = evidence.path_join(label+".png")
	var saved: Error = root.get_texture().get_image().save_png(image_path)
	_check(saved==OK,"Native frame saved: "+label)
	captures.append({"path":image_path,"state":guard.state_machine.get_state_id(),"state_time":guard.state_time,"actor":guard.global_position,"body":guard.visual.body_frames.snapshot(),"helper":guard.visual.opening_skill_art.snapshot()})

func _accepted_contact(event: DamageEvent, result: DamageResult) -> void:
	if not is_instance_valid(guard) or event.source_id!=guard.get_instance_id() or result.blocked or result.actual_damage<=0.0: return
	contacts.append({"physics_frame":Engine.get_physics_frames(),"attack_id":event.attack_id,"damage":result.actual_damage,"state":guard.state_machine.get_state_id(),"state_time":guard.state_time,"hitbox_active":guard.attack_hitbox.active,"helper_phase":guard.visual.opening_skill_art.phase,"body_clip":guard.visual.body_frames.clip_id,"blade_tip":guard.visual.body_frames.anchor_local("saber_tip")})

func _incoming(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = hero.get_instance_id()
	event.source_team_id = 1
	event.target_id = guard.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	event.physical_damage = true
	event.attack_direction = (guard.global_position-hero.global_position).normalized()
	return event

func _wall(x: float) -> StaticBody2D:
	var solid := StaticBody2D.new()
	solid.position = Vector2(x,590)
	solid.collision_layer = 1
	solid.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20,100)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	solid.add_child(collider)
	arena.add_child(solid)
	return solid

func _player_shape() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child: Node in hero.get_children():
		if child is CollisionShape2D:
			result.append({"name":child.name,"class":child.shape.get_class(),"resource_id":child.shape.get_instance_id(),"position":child.position})
	return result

func _finish(completed: bool) -> void:
	paused = false
	var held_frames: GuardBodyFrames = guard.visual.body_frames if is_instance_valid(guard) else null
	arena.queue_free()
	current_scene = null
	await _frames(6)
	root.get_node("AudioManager").stop_all()
	_check(get_nodes_in_group(&"opening_enemy_skill_art").is_empty() and get_nodes_in_group(&"guard_sweep_vfx").is_empty() and get_nodes_in_group(&"world_enemies").is_empty(),"Owner teardown removes all Guard presentation and actor owners")
	_check(held_frames==null or not held_frames.valid,"Teardown releases authored frame actor/sprite references")
	_check(not paused and is_equal_approx(Engine.time_scale,1.0),"Probe releases pause and gameplay time claims")
	var source: Dictionary = {}
	for path: String in ["res://scripts/presentation/world_enemy_visual.gd","res://scripts/presentation/opening_enemy_skill_art.gd","res://scripts/presentation/guard_body_frames.gd","res://scripts/presentation/guard_sweep_vfx.gd","res://scripts/actors/enemies/base_enemy.gd","res://data/enemies/ancient_guard.tres","res://tests/opening_enemy_presentation_probe.gd"]:
		source[path] = FileAccess.get_sha256(path)
	var report: Dictionary = {"checks":checks,"failures":failures,"completed":completed,"physics_hz":Engine.physics_ticks_per_second,"native":native,"captures":captures,"contacts":contacts,"metrics":metrics,"motion_sequence":sequence,"source_sha256":source,"scope":"actual AncientGuard scene and original DungeonRoom floor; natural sight/motor/tell/active/recovery, one initial spawn only; controlled accepted damage and temporary wall isolate interruption/solid tests; native images require root review"}
	var json: String = JSON.stringify(report,"\t")
	var file := FileAccess.open("user://opening_enemy_presentation_%d.json" % Engine.physics_ticks_per_second,FileAccess.WRITE)
	file.store_string(json)
	file.close()
	if native:
		file = FileAccess.open(evidence.path_join("opening_enemy_presentation.json"),FileAccess.WRITE)
		file.store_string(json)
		file.close()
	print("RESULT OpeningEnemyPresentation checks=%d failures=%d hz=%d native=%s captures=%d" % [checks,failures,Engine.physics_ticks_per_second,native,captures.size()])
	quit(0 if completed and failures==0 else 1)

func _frames(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _check(passed: bool, message: String) -> bool:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: "+message)
	return passed
