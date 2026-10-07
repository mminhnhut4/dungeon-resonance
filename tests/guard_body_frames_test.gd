extends SceneTree
## Live motor/FSM checks for received body frames. Headless is not visual acceptance.
var arena: Node2D
var hero: Player
var feedback: CombatFeedback
var guard: BaseEnemy
var checks: int=0
var failures: int=0
var metrics: Dictionary={}
var contact_events: Array[Dictionary]=[]

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated user:// before scene construction")
	if failures>0: quit(1); return
	AudioServer.set_bus_mute(0,true)
	arena=Node2D.new()
	root.add_child(arena)
	var floor_body:=StaticBody2D.new()
	floor_body.position=Vector2(1100,650)
	floor_body.collision_layer=1
	var floor_shape:=CollisionShape2D.new()
	var floor_rect:=RectangleShape2D.new()
	floor_rect.size=Vector2(2400,20)
	floor_shape.shape=floor_rect
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	hero=preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	arena.add_child(hero)
	hero.reset_movement_at(Vector2(200,640))
	hero.controls_enabled=false
	hero.hurtbox.hit_resolved.connect(_record_contact)
	feedback=CombatFeedback.new()
	arena.add_child(feedback)
	feedback.enable_global_hitstop(false)
	feedback.hit_stop_seconds=0.0
	await _fresh()
	_check(guard.visual.body_frames!=null and guard.visual.body_frames.valid,"Received Guard body bank is installed: "+GuardBodyFrames.last_error)
	if guard.visual.body_frames==null: await _finish(); return
	_validate_received_pixels()
	await _pose_clock_and_mirror()
	await _contact_pose_and_timestamp()
	for state: StringName in [&"patrol",&"chase"]:
		for side: float in [-1.0,1.0]: await _walking(state,side)
	await _freeze_interrupt_and_poise()
	await _lifecycle()
	await _finish()

func _fresh() -> void:
	if is_instance_valid(guard):
		guard.queue_free()
		await _frames(3)
	guard=preload("res://scenes/enemies/ancient_guard.tscn").instantiate() as BaseEnemy
	guard.global_position=Vector2(950,640)
	guard.ai_enabled=false
	guard.player=hero
	guard.combat_feedback=feedback
	arena.add_child(guard)
	guard.ai_enabled=true # Settle the actual motor onto the existing floor.
	await _frames(4)
	guard.ai_enabled=false
	guard.velocity=Vector2.ZERO

func _pose_clock_and_mirror() -> void:
	var body: GuardBodyFrames=guard.visual.body_frames
	var shape_id: int=(guard.get_node("BodyCollision") as CollisionShape2D).shape.get_instance_id()
	var definition_id: int=guard.definition.get_instance_id()
	var hit_id: int=guard.attack_hitbox.collision_shape.get_instance_id()
	for item: Array in [[&"telegraph",&"windup_sweep",0.45,6],[&"attack",&"attack_sweep",0.18,3],[&"recover",&"recover",0.55,6],[&"hurt",&"hurt",0.18,3],[&"dead",&"death",0.30,6]]:
		# QA samples real FSM clocks; does not introduce an animation-owned timer.
		guard.state_machine.transition_to(item[0])
		for progress: float in [0.0,0.5,1.0]:
			guard.state_time=float(item[2])*progress
			for side: float in [-1.0,1.0]:
				body.seek_actor(0.0,side,false,true)
				var expected_clip: StringName=&"attack_sweep" if item[0]==&"telegraph" and progress==1.0 else item[1]
				var expected_frame: int=2 if item[0]==&"attack" else 1 if item[0]==&"telegraph" and progress==1.0 else roundi(progress*(int(item[3])-1))
				_check(body.clip_id==expected_clip and body.frame_index==expected_frame,"Live clock maps %s %.2f facing %.0f"%[item[0],progress,side])
				_check(EnemySpriteArt.foot_world(guard.visual.sprite,GuardBodyFrames.PIVOT).distance_to(guard.global_position)<0.001 and guard.visual.sprite.scale==Vector2.ONE*0.30,"Constant root/scale survives frame and facing change")
				_check(guard.visual.sweep_vfx.hand_local().distance_to(body.anchor_local("sword_hand"))<0.001,"r1 VFX reads the delivered pose hand anchor within world-transform precision")
	_check(shape_id==(guard.get_node("BodyCollision") as CollisionShape2D).shape.get_instance_id() and definition_id==guard.definition.get_instance_id() and hit_id==guard.attack_hitbox.collision_shape.get_instance_id(),"Pose sampling preserves collider resource, shared definition and hitbox shape node identities")
	_check(guard.definition.visual_height==60.0 and guard.definition.windup==0.45 and guard.definition.active==0.18 and guard.definition.recovery==0.55,"60px body and original attack duration resources unchanged")
	await _fresh() # The QA dead-state sample above is not allowed to prolong a corpse.

func _contact_pose_and_timestamp() -> void:
	for side: float in [-1.0,1.0]:
		await _fresh()
		guard.facing=side
		hero.reset_movement_at(guard.global_position+Vector2(side*78,0))
		hero.controls_enabled=false
		var body: GuardBodyFrames=guard.visual.body_frames
		var vfx: GuardSweepVFX=guard.visual.sweep_vfx
		guard.state_machine.transition_to(&"telegraph")
		guard.state_time=0.44
		body.seek_actor(0.0,side,false,true)
		_check(body.anchor_local("saber_tip").y<-29.0 and not guard.attack_hitbox.active,"Late windup retains overhead preparation before hitbox opens")
		guard.state_machine.transition_to(&"attack")
		for stamp: float in [0.0,1.0/120.0,1.0/60.0,0.05,0.09,0.135]:
			guard.state_time=stamp
			body.seek_actor(0.0,side,false,true)
			vfx.seek_actor()
			var hand: Vector2=body.anchor_local("sword_hand")
			var tip: Vector2=body.anchor_local("saber_tip")
			_check(guard.attack_hitbox.active and tip.x*side>50.0 and tip.y>=-29.0 and tip.y<=-3.0 and hand.x*side>0.0,"At active %.5fs facing %.0f blade is already forward in existing physical band"%[stamp,side])
			_check(vfx.ribbon_center(stamp/0.18,0.0).distance_to(hand)<0.001 and vfx.blade_tip_local().distance_to(tip)<0.001,"Contact ribbon starts at actual posed hand and reads posed blade tip")
			var u: float=(tip.x*side-hand.x*side)/(91.0-hand.x*side)
			_check(vfx.ribbon_center(stamp/0.18,u).distance_to(tip)<0.001,"Committed ribbon passes through the blade tip before its energy extension")
	for side: float in [-1.0,1.0]:
		await _fresh()
		contact_events.clear()
		guard.facing=side
		hero.reset_movement_at(guard.global_position+Vector2(side*78,0))
		hero.controls_enabled=false
		hero.hurtbox.set_invulnerable(false)
		guard.state_machine.transition_to(&"telegraph")
		feedback.hit_stop_seconds=0.05 # Real local hitstop must hold the committed pose, not preparation.
		guard.ai_enabled=true
		for tick: int in 100:
			await _frames(1)
			if not contact_events.is_empty(): break
		_check(contact_events.size()==1,"One natural accepted sweep contact, facing %.0f"%side)
		if not contact_events.is_empty():
			var contact: Dictionary=contact_events[0]
			_check(contact["state"]=="attack" and float(contact["time"])<=1.0/float(Engine.physics_ticks_per_second)+0.00001 and contact["hitbox_active"],"Original first-tick contact timestamp is preserved")
			var callback_tip: Vector2=contact["blade_tip_at_callback"]
			_check(callback_tip.x*side>50.0 and callback_tip.y>=-29.0 and callback_tip.y<=-3.0,"Actual damage callback already observes the committed blade pose before hitstop")
			var tip: Vector2=guard.visual.body_frames.anchor_local("saber_tip")
			_check(guard.visual.body_frames.clip_id==&"attack_sweep" and tip.x*side>50.0 and tip.y>=-29.0 and tip.y<=-3.0,"First contact presentation has forward blade after its actual visual update")
			_check(feedback.is_frozen() and guard.visual.sweep_vfx.phase==&"attack","Actual contact hitstop holds the forward body and active ribbon")
			metrics["contact_%.0f"%side]=contact
		guard.ai_enabled=false
	feedback.hit_stop_seconds=0.0
	feedback.reset_feedback()

func _record_contact(event: DamageEvent,result: DamageResult) -> void:
	if is_instance_valid(guard) and event.source_id==guard.get_instance_id() and not result.blocked and result.actual_damage>0.0:
		contact_events.append({"state":String(guard.state_machine.get_state_id()),"time":guard.state_time,"hitbox_active":guard.attack_hitbox.active,"damage":result.actual_damage,"body_at_callback":guard.visual.body_frames.snapshot(),"blade_tip_at_callback":guard.visual.body_frames.anchor_local("saber_tip")})

func _walking(state: StringName,side: float) -> void:
	await _fresh()
	guard.facing=side
	hero.reset_movement_at(guard.global_position+Vector2(side*250,0))
	hero.controls_enabled=false
	guard.player=null if state==&"patrol" else hero
	guard.state_machine.transition_to(state)
	guard.attack_cooldown=4.0
	guard.ai_enabled=true
	var max_slide: float=0.0
	var max_floor_error: float=0.0
	var max_phase_error: float=0.0
	var max_root_error: float=0.0
	var held_stance: String=""
	var stance_origin: float=0.0
	var seen: Dictionary={}
	var travel: float=0.0
	for tick: int in int(Engine.physics_ticks_per_second*1.15):
		var before: Vector2=guard.global_position
		var previous_phase: float=guard.visual.walk_phase
		await _frames(1)
		var moved: float=absf(guard.global_position.x-before.x)
		travel+=moved
		var body: GuardBodyFrames=guard.visual.body_frames
		seen[body.frame_index]=true
		max_phase_error=maxf(max_phase_error,absf(angle_difference(fmod(previous_phase+moved*TAU/36.0,TAU),guard.visual.walk_phase)))
		max_root_error=maxf(max_root_error,EnemySpriteArt.foot_world(guard.visual.sprite,GuardBodyFrames.PIVOT).distance_to(guard.global_position))
		var stance: String="front" if bool(body.frame_data["contact_front"]) else "back"
		var boot: Vector2=guard.global_position+body.anchor_local("front_boot_contact" if stance=="front" else "back_boot_contact")
		if stance!=held_stance:
			held_stance=stance
			stance_origin=boot.x
		max_slide=maxf(max_slide,absf(boot.x-stance_origin))
		max_floor_error=maxf(max_floor_error,absf(boot.y-640.0))
	_check(seen.size()>12 and guard.visual.body_frames.clip_id==&"walk","%s %.0f displays real walking poses from actual travel"%[state,side])
	_check(max_slide<0.751 and max_floor_error<0.10,"%s %.0f planted sole drift/floor respect baked bound and original motor safe margin"%[state,side])
	_check(max_phase_error<0.001 and max_root_error<0.001,"%s %.0f actual motor distance and fixed physical pivot agree"%[state,side])
	_check(guard.visual.motion.transform==Transform2D.IDENTITY,"Authored body does not receive legacy whole-image tilt/squash")
	metrics["%s_%.0f"%[state,side]]={"travel":travel,"frames_seen":seen.size(),"stance_drift":max_slide,"floor_error":max_floor_error,"phase_error":max_phase_error,"root_error":max_root_error}
	guard.ai_enabled=false
	var frame_before: int=guard.visual.body_frames.frame_index
	var phase_before: float=guard.visual.walk_phase
	await _frames(6)
	_check(guard.visual.body_frames.frame_index==frame_before and guard.visual.walk_phase==phase_before,"AI freeze holds selected pose and travel phase")
	guard.global_position.x+=100.0
	guard.ai_enabled=true
	await _frames(1)
	_check(absf(angle_difference(phase_before,guard.visual.walk_phase))<0.001,"Teleport rebases observed root without walking 100 imaginary pixels")
	guard.ai_enabled=false

func _freeze_interrupt_and_poise() -> void:
	await _fresh()
	hero.reset_movement_at(guard.global_position+Vector2(70,0))
	hero.controls_enabled=false
	guard.state_machine.transition_to(&"telegraph")
	guard.ai_enabled=true
	await _frames(10)
	var body: GuardBodyFrames=guard.visual.body_frames
	var frame_before: int=body.frame_index
	var clock: float=guard.state_time
	paused=true
	await _frames(4)
	_check(body.frame_index==frame_before and guard.state_time==clock,"Pause holds the chosen body frame with the real tell clock")
	paused=false
	feedback.hit_stop_remaining=0.08
	await _frames(1)
	clock=guard.state_time
	frame_before=body.frame_index
	await _frames(2)
	_check(body.frame_index==frame_before and guard.state_time==clock,"Hitstop holds body frame and actual actor clock together")
	feedback.reset_feedback()
	var incoming: DamageEvent=_damage(guard,1.0)
	incoming.stun_seconds=0.20
	guard.hurtbox.take_damage(incoming)
	await _frames(1)
	_check(body.clip_id==&"hurt" and not guard.attack_hitbox.active and guard.visual.sweep_vfx.phase.is_empty(),"Real stun interrupts windup into authored hurt and clears dangerous cue")
	await _fresh()
	guard.state_machine.transition_to(&"attack")
	guard.ai_enabled=true
	await _frames(1)
	var started: int=guard.attacks_started
	var result: DamageResult=guard.hurtbox.take_damage(_damage(guard,1.0))
	await _frames(1)
	_check(not result.blocked and guard.has_poise() and guard.visual.body_frames.clip_id==&"attack_sweep" and guard.attacks_started==started,"Accepted hit during existing active Poise preserves attack pose/clock instead of starting Hurt")
	guard.health.apply_damage(guard.health.current_health+1.0)
	await _frames(1)
	_check(guard.visual.body_frames.clip_id==&"death" and not guard.attack_hitbox.active,"Actual death selects authored collapse and deactivates the original hitbox")
	await _frames(ceili(0.31*Engine.physics_ticks_per_second)+2)
	_check(not is_instance_valid(guard),"Original 0.30-second death deadline still frees the actor")

func _lifecycle() -> void:
	for iteration: int in 4:
		await _fresh()
		var body: GuardBodyFrames=guard.visual.body_frames
		guard.queue_free()
		await _frames(4)
		_check(not body.valid and body.actor==null and body.sprite==null,"Teardown releases authored frame owner/sprite references")
	_check(get_nodes_in_group(&"guard_sweep_vfx").is_empty(),"Repeated owner teardown leaves no Guard VFX owners")

func _damage(target: BaseEnemy,amount: float) -> DamageEvent:
	var event:=DamageEvent.new()
	event.source_id=hero.get_instance_id()
	event.target_id=target.get_instance_id()
	event.source_team_id=1
	event.attack_id=CombatIds.next_id()
	event.root_event_id=event.attack_id
	event.hit_window_id=1
	event.base_damage=amount
	return event

func _finish() -> void:
	arena.queue_free()
	await _frames(5)
	root.get_node("AudioManager").stop_all()
	_check(get_nodes_in_group(&"world_enemies").is_empty() and not paused and Engine.time_scale==1.0,"Final teardown restores actor/pause/global-time state")
	var report: Dictionary={"checks":checks,"failures":failures,"physics_hz":Engine.physics_ticks_per_second,"metrics":metrics,"GPU":"unrun; slot belongs to parent","acceptance":"candidate only; authored-frame/artifact inspection is not runtime visual acceptance"}
	DirAccess.make_dir_recursive_absolute("user://verification")
	var file:=FileAccess.open("user://verification/guard_body_%d.json"%Engine.physics_ticks_per_second,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("RESULT GuardBodyFrames %d checks, %d failures; physics_hz=%d; GPU UNRUN"%[checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures==0 else 1)

func _validate_received_pixels() -> void:
	var frames_seen: int=0
	var clipped: int=0
	var neutral_height: int=0
	for entry: Dictionary in GuardBodyFrames._bank.values():
		var atlas: Texture2D=entry["textures"][0].atlas
		var image: Image=atlas.get_image()
		if image.is_compressed(): image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		for frame: Dictionary in entry["metadata"]["frames"]:
			var rect: Array=frame["rect"]
			var crop: Image=image.get_region(Rect2i(int(rect[0]),int(rect[1]),448,320))
			var bytes: PackedByteArray=crop.get_data()
			for x: int in 448:
				if bytes[x*4+3]>=8 or bytes[((319*448+x)*4)+3]>=8: clipped+=1
			for y: int in 320:
				if bytes[(y*448)*4+3]>=8 or bytes[(y*448+447)*4+3]>=8: clipped+=1
			if frame["clip"]=="idle" and int(frame["index"])==0:
				var min_y: int=320
				var max_y: int=-1
				for y: int in 320:
					for x: int in 448:
						if bytes[(y*448+x)*4+3]>=8:
							min_y=mini(min_y,y)
							max_y=maxi(max_y,y)
				neutral_height=max_y-min_y+1
			frames_seen+=1
	_check(frames_seen==76 and clipped==0,"All 76 actual imported RGBA frames have transparent borders and uncut blade/limbs")
	_check(neutral_height==200,"Received neutral solid alpha height is 200px, mapped once to original 60px body")
	metrics["actual_pixels"]={"frames":frames_seen,"alpha_ge_8_border_pixels":clipped,"neutral_height":neutral_height}

func _frames(count: int) -> void:
	for frame: int in count: await physics_frame; await process_frame

func _check(passed: bool,message: String) -> void:
	checks+=1
	if not passed:
		failures+=1
		print("FAIL: "+message)
