extends SceneTree
## Narrow actual-GPU contact timing review; no gameplay or body-art generation.
const DEST: String="res://docs/verification/guard_contact_gpu_r3"
var run: WorldCampaign
var images: Array[Dictionary]=[]
var clips: Dictionary={}
var contacts: Array[Dictionary]=[]
var guard: BaseEnemy
var checks: int=0
var failures: int=0

func _initialize() -> void: call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name()=="headless": print("ERROR: GPU capture refuses headless"); quit(2); return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	Engine.max_fps=60
	Engine.physics_ticks_per_second=60
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated GPU user://")
	if failures: quit(1); return
	DirAccess.make_dir_recursive_absolute(DEST)
	AudioServer.set_bus_mute(0,true)
	run=preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	run.run_seed=20261003
	run.profile=SanctuaryProfile.new()
	root.add_child(run)
	current_scene=run
	run.survival.set_enabled(false)
	await _frames(8)
	for node: Node in get_nodes_in_group(&"world_enemies"):
		var enemy:=node as BaseEnemy
		enemy.ai_enabled=false
		if guard==null and enemy.definition.id==&"ancient_guard": guard=enemy
	for node: Node in get_nodes_in_group(&"enemies"):
		if node!=guard: node.set("ai_enabled",false)
	_check(guard!=null and guard.visual.body_frames!=null and guard.visual.body_frames.valid,"Actual existing Guard installs received body frames")
	if guard==null: await _finish(); return
	run.player.controls_enabled=false
	run.player.hurtbox.hit_resolved.connect(_record_contact)
	run.feedback.enable_global_hitstop(true) # Keep real contact hitstop; state-entry observers must already have committed the pose.
	await _attack_sequence("guard_left",-1.0)
	await _attack_sequence("guard_right",1.0)
	await _hurt_sequence()
	await _finish()

func _attack_sequence(label: String,side: float) -> void:
	guard.ai_enabled=false
	run.player.reset_movement_at(guard.global_position+Vector2(side*78,0))
	run.player.controls_enabled=false
	run.player.hurtbox.set_invulnerable(false)
	guard.player=run.player
	guard.facing=side
	guard.state_machine.transition_to(&"patrol")
	await _frames(3)
	guard.attack_cooldown=0.0
	var before_hits: int=guard.visual.sweep_vfx.impact_count
	var before_hp: float=run.player.health.current_health
	contacts.clear()
	var captured: Dictionary={}
	var sequence: Array[Dictionary]=[]
	var started: bool=false
	guard.ai_enabled=true
	for tick: int in 240:
		await RenderingServer.frame_post_draw
		var state: StringName=guard.state_machine.get_state_id()
		if state==&"telegraph": started=true
		if not started: continue
		sequence.append(_clip_frame(label,sequence.size()))
		if state==&"telegraph" and guard.state_time>=0.40 and not captured.has("late_windup"):
			_shot_now(label+"_late_windup")
			_check(guard.visual.body_frames.anchor_local("saber_tip").y<-29.0 and not guard.attack_hitbox.active,"Late windup is raised preparation before the physical active window")
			captured["late_windup"]=true
		if state==&"attack" and not captured.has("early_active"):
			_shot_now(label+"_early_active")
			_check(guard.state_time<=1.0/60.0+0.00001,"Early active capture is within its first authoritative tick")
			_check_committed_blade(side)
			captured["early_active"]=true
		if guard.visual.sweep_vfx.impact_count>before_hits and not captured.has("contact"):
			_shot_now(label+"_accepted_contact")
			_check_committed_blade(side)
			_check(run.player.health.current_health<before_hp and contacts.size()==1,"Captured contact is one real accepted HP-changing hit")
			if not contacts.is_empty():
				_check(contacts[0]["state"]=="attack" and float(contacts[0]["state_time"])<=1.0/60.0+0.00001,"Accepted contact retains its original first-tick timestamp")
			captured["contact"]=true
		if state==&"attack" and guard.state_time>=0.10 and not captured.has("mid_active"):
			_shot_now(label+"_mid_active")
			captured["mid_active"]=true
		if state==&"recover" and not captured.has("recovery"):
			_shot_now(label+"_recovery")
			captured["recovery"]=true
		if captured.has("recovery") and state not in [&"telegraph",&"attack",&"recover"]: break
	_check(captured.size()==5 and guard.visual.sweep_vfx.impact_count==before_hits+1,"Both timing and one-hit gating are captured for "+label)
	clips[label]={"frames":sequence,"sample_fps":60,"fixed_render_step":60,"source":"actual WorldCampaign GPU viewport","contacts":contacts.duplicate(true)}
	guard.ai_enabled=false

func _check_committed_blade(side: float) -> void:
	var body: GuardBodyFrames=guard.visual.body_frames
	var hand: Vector2=body.anchor_local("sword_hand")
	var tip: Vector2=body.anchor_local("saber_tip")
	var vfx: GuardSweepVFX=guard.visual.sweep_vfx
	_check(body.clip_id==&"attack_sweep" and tip.x*side>50.0 and tip.y>=-29.0 and tip.y<=-3.0 and guard.attack_hitbox.active,"Actual early/contact frame has forward blade in the existing active band")
	var u: float=(tip.x*side-hand.x*side)/(91.0-hand.x*side)
	_check(vfx.ribbon_center(vfx.progress,0.0).distance_to(hand)<0.001 and vfx.ribbon_center(vfx.progress,u).distance_to(tip)<0.001,"Actual ribbon joins posed hand and blade before its range extension")

func _record_contact(event: DamageEvent,result: DamageResult) -> void:
	if guard!=null and event.source_id==guard.get_instance_id() and not result.blocked and result.actual_damage>0.0:
		contacts.append({"state":String(guard.state_machine.get_state_id()),"state_time":guard.state_time,"damage":result.actual_damage,"attack_id":event.attack_id,"physics_frame":Engine.get_physics_frames()})

func _hurt_sequence() -> void:
	guard.ai_enabled=true
	guard.state_machine.transition_to(&"telegraph")
	await _frames(3)
	var damage:=DamageEvent.new()
	damage.source_id=run.player.get_instance_id()
	damage.target_id=guard.get_instance_id()
	damage.source_team_id=1
	damage.attack_id=CombatIds.next_id()
	damage.root_event_id=damage.attack_id
	damage.hit_window_id=1
	damage.base_damage=3.0
	damage.stun_seconds=0.20
	var resolved: DamageResult=guard.hurtbox.take_damage(damage)
	for tick: int in 4:
		await RenderingServer.frame_post_draw
		if guard.visual.body_frames.clip_id==&"hurt": break
	_shot_now("guard_hurt_after_visual_update")
	_check(not resolved.blocked and guard.state_machine.get_state_id()==&"hurt" and guard.visual.body_frames.clip_id==&"hurt" and guard.state_time<=0.05,"Accepted real stun selects authored Hurt within its first visual update")
	_check(not guard.attack_hitbox.active and guard.visual.sweep_vfx.phase==&"","Hurt cancels physical hitbox and committed ribbon")
	var sequence: Array[Dictionary]=[]
	for tick: int in 18:
		await RenderingServer.frame_post_draw
		sequence.append(_clip_frame("guard_hurt",sequence.size()))
	clips["guard_hurt"]={"frames":sequence,"sample_fps":60,"fixed_render_step":60,"source":"actual WorldCampaign GPU viewport"}
	guard.ai_enabled=false

func _trace() -> Dictionary:
	return {"state":String(guard.state_machine.get_state_id()),"state_time":guard.state_time,"actor_world":[guard.global_position.x,guard.global_position.y],"player_hp":run.player.health.current_health,"hitbox_active":guard.attack_hitbox.active,"body":guard.visual.body_frames.snapshot(),"blade_tip":guard.visual.body_frames.anchor_local("saber_tip"),"vfx":guard.visual.sweep_vfx.snapshot(),"hitstop_frozen":run.feedback.is_frozen(),"draw_frame":Engine.get_frames_drawn(),"physics_frame":Engine.get_physics_frames()}

func _clip_frame(label: String,index: int) -> Dictionary:
	var image: Image=root.get_texture().get_image()
	var path: String=DEST+"/%s_%04d.jpg"%[label,index]
	if image.save_jpg(path,0.88)!=OK: failures+=1
	var info: Dictionary=_trace()
	info.merge({"file":path.trim_prefix("res://"),"width":image.get_width(),"height":image.get_height()})
	return info

func _shot_now(label: String) -> void:
	# Called at frame_post_draw: do not advance the first-contact timestamp to take a shot.
	var image: Image=root.get_texture().get_image()
	var path: String=DEST+"/"+label+".png"
	_check(image.save_png(path)==OK,"GPU capture "+label)
	var info: Dictionary=_trace()
	info["file"]=path.trim_prefix("res://")
	images.append(info)

func _finish() -> void:
	var report: Dictionary={"checks":checks,"failures":failures,"images":images,"clips":clips,"source_hashes":{"body":FileAccess.get_sha256("res://scripts/presentation/guard_body_frames.gd"),"sweep":FileAccess.get_sha256("res://scripts/presentation/guard_sweep_vfx.gd"),"preview":FileAccess.get_sha256("res://tests/guard_contact_timing_preview.gd")},"QA":"fixed60; controls off; muted; other enemies frozen; real Guard damage and real global hitstop enabled; no Golem/walk/full-suite/performance/focus acceptance","Player_white_flash":"unchanged"}
	var file:=FileAccess.open(DEST+"/capture_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	if is_instance_valid(run): run.queue_free()
	await _frames(5)
	root.get_node("AudioManager").stop_all()
	print("RESULT GuardContactGPU %d checks, %d failures; screenshots=%d"%[checks,failures,images.size()])
	quit(0 if failures==0 else 1)

func _frames(count: int) -> void:
	for tick: int in count: await process_frame

func _check(passed: bool,message: String) -> void:
	checks+=1
	if not passed: failures+=1; print("FAIL: "+message)
