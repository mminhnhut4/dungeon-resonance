extends SceneTree
## Actual WorldCampaign GPU capture. Controlled QA actor placement; no fixture art.
var run: WorldCampaign
var images: Array[Dictionary] = []
var clips: Dictionary = {}
var checks: int = 0
var failures: int = 0
const DEST: String = "res://docs/verification/guard_body_gpu_r2"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name()=="headless":
		print("ERROR: GPU capture refuses a headless renderer")
		quit(2)
		return
	root.set_flag(Window.FLAG_NO_FOCUS,true)
	Engine.max_fps=60
	Engine.physics_ticks_per_second=60
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"GPU user:// is isolated")
	DirAccess.make_dir_recursive_absolute(DEST)
	AudioServer.set_bus_mute(0,true)
	run=preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	run.run_seed=20261003
	run.profile=SanctuaryProfile.new()
	root.add_child(run)
	current_scene=run
	run.survival.set_enabled(false)
	await _frames(8)
	var guard: BaseEnemy
	for node: Node in get_nodes_in_group(&"world_enemies"):
		var enemy:=node as BaseEnemy
		enemy.ai_enabled=false
		if guard==null and enemy.definition.id==&"ancient_guard": guard=enemy
	for node: Node in get_nodes_in_group(&"enemies"):
		if node!=guard: node.set("ai_enabled",false)
	_check(guard!=null and guard.visual.sweep_vfx!=null,"Existing first-room Guard has its candidate VFX")
	if guard==null:
		await _finish()
		return
	_check(guard.visual.body_frames!=null and guard.visual.body_frames.valid,"Actual received Guard body atlas is installed in this scene")
	await _walk_sequence(guard,"guard_walk_left",-1.0)
	await _walk_sequence(guard,"guard_walk_right",1.0)
	await _guard_sequence(guard,"guard_left",-1.0)
	await _guard_sequence(guard,"guard_right",1.0)
	await _hurt_sequence(guard)
	guard.ai_enabled=false
	run.player.reset_movement_at(Vector2(180,640)) # QA reset, not a production heal.
	_check(run.enter_stage(4),"Enter the real existing boss room")
	await _frames(6)
	var boss: BossGolem=run.boss
	_check(boss!=null and boss.has_node("GolemStoneSkin"),"Existing boss room installs its normal PNG skin")
	if boss==null:
		await _finish()
		return
	for node: Node in get_nodes_in_group(&"enemies"):
		if node!=boss:
			node.set("ai_enabled",false)
			if node is SlimeEnemy: (node as SlimeEnemy).contact_damage_enabled=false
	run.player.reset_movement_at(boss.global_position+Vector2(-210,0))
	run.player.controls_enabled=false
	run.player.hurtbox.set_invulnerable(true) # Boss-only framing; Guard contacts above remain real.
	var damage:=DamageEvent.new()
	damage.source_id=run.player.get_instance_id()
	damage.target_id=boss.get_instance_id()
	damage.source_team_id=1
	damage.attack_id=CombatIds.next_id()
	damage.root_event_id=damage.attack_id
	damage.hit_window_id=1
	damage.base_damage=251.0
	var result: DamageResult=boss.hurtbox.take_damage(damage)
	_check(not result.blocked and boss.phase==2,"QA damage uses the real resolver to reach existing phase two")
	await _boss_sequence(boss)
	await _finish()

func _guard_sequence(guard: BaseEnemy,label: String,side: float) -> void:
	guard.ai_enabled=false
	run.player.reset_movement_at(guard.global_position+Vector2(side*78,0))
	run.player.controls_enabled=false
	run.feedback.hit_stop_seconds=0.0
	run.feedback.enable_global_hitstop(false) # QA capture preserves visible phase samples.
	guard.state_machine.transition_to(&"patrol")
	await _frames(3)
	var before_hits: int=guard.visual.sweep_vfx.impact_count
	guard.ai_enabled=true
	var captured: Dictionary={}
	var sequence: Array[Dictionary]=[]
	var started: bool=false
	var tick: int=0
	var frame_index: int=0
	for index: int in 360:
		await RenderingServer.frame_post_draw
		var state: StringName=guard.state_machine.get_state_id()
		if state==&"telegraph": started=true
		if started:
			if tick%4==0:
				sequence.append(_clip_frame(label,frame_index,guard))
				frame_index+=1
			tick+=1
			if state==&"telegraph" and guard.state_time>=guard.definition.windup*0.30 and not captured.has("windup"):
				await _shot(label+"_windup",guard)
				captured["windup"]=true
			elif state==&"attack" and not captured.has("active"):
				await _shot(label+"_active",guard)
				captured["active"]=true
			elif state==&"recover" and not captured.has("recovery"):
				await _shot(label+"_recovery",guard)
				captured["recovery"]=true
			if captured.has("recovery") and state not in [&"telegraph",&"attack",&"recover"]:
				break
	_check(captured.size()==3,"Actual "+label+" has windup/active/recovery screenshots")
	_check(guard.visual.sweep_vfx.impact_count==before_hits+1,"Actual "+label+" has one accepted contact impact")
	clips[label]={"frames":sequence,"sample_fps":15,"source":"actual WorldCampaign GPU viewport","fixed_render_step":60}
	guard.ai_enabled=false

func _boss_sequence(boss: BossGolem) -> void:
	var skin: BossGolemSkin=boss.get_node("GolemStoneSkin") as BossGolemSkin
	var vfx: GolemStompVFX=skin.stomp_vfx
	var captured: Dictionary={}
	var sequence: Array[Dictionary]=[]
	var started: bool=false
	var tick: int=0
	var frame_index: int=0
	for index: int in 720:
		await RenderingServer.frame_post_draw
		var state: StringName=boss.fsm.get_state_id()
		if state==&"stomp": started=true
		if started:
			if tick%4==0:
				sequence.append(_clip_frame("boss_stomp",frame_index,boss))
				frame_index+=1
			tick+=1
			if state==&"stomp" and boss.state_time>=0.15 and boss.state_time<0.5 and not captured.has("windup"):
				await _shot("boss_stomp_windup",boss)
				captured["windup"]=true
			elif state==&"stomp" and boss.launched and boss.state_time<0.82 and not captured.has("flight"):
				await _shot("boss_stomp_flight",boss)
				captured["flight"]=true
			elif state==&"stomp" and boss.state_time>=0.82 and not captured.has("plunge"):
				await _shot("boss_stomp_plunge",boss)
				captured["plunge"]=true
			elif state==&"recover" and vfx.impact_count>0 and not captured.has("impact"):
				await _shot("boss_stomp_landing",boss)
				captured["impact"]=true
			elif captured.has("impact") and state==&"recover" and boss.state_time>=0.20 and not captured.has("recovery"):
				await _shot("boss_stomp_recovery",boss)
				captured["recovery"]=true
			if captured.has("recovery") and state!=&"stomp" and state!=&"recover":
				break
		if not run.outcome.is_empty(): break
	_check(captured.size()==5,"Real boss stomp has tell/flight/plunge/landing/recovery")
	_check(vfx.impact_count==1 and boss.shockwave_count==2 and vfx.linked_wave_count==2,"GPU landing has one impact and the original two skinned hazards")
	_check(skin.sprite.visible and skin.sprite.modulate.a>0.9,"Boss body remains visible through the captured attack")
	clips["boss_stomp"]={"frames":sequence,"sample_fps":15,"source":"actual WorldCampaign GPU viewport","fixed_render_step":60}

func _clip_frame(label: String,index: int,actor: Node2D) -> Dictionary:
	var image: Image=root.get_texture().get_image()
	var path: String=DEST+"/%s_%04d.jpg"%[label,index]
	var saved: Error=image.save_jpg(path,0.88)
	if saved!=OK: failures+=1
	var info: Dictionary=_trace(actor)
	info["file"]=path.trim_prefix("res://")
	info["width"]=image.get_width()
	info["height"]=image.get_height()
	return info

func _shot(label: String,actor: Node2D) -> void:
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	var path: String=DEST+"/"+label+".png"
	_check(image.save_png(path)==OK,"Actual GPU screenshot "+label)
	var info: Dictionary=_trace(actor)
	info["file"]=path.trim_prefix("res://")
	if actor is BossGolem:
		var pixel: Vector2=root.get_canvas_transform()*actor.global_position
		var zoom: Vector2=run.player.get_node("Camera2D").zoom
		var box:=Rect2i(Vector2i(pixel+Vector2(-38,-100)*zoom),Vector2i(Vector2(76,100)*zoom))
		box=box.intersection(Rect2i(0,0,image.get_width(),image.get_height()))
		var white: int=0
		var count: int=0
		for y: int in range(box.position.y,box.end.y):
			for x: int in range(box.position.x,box.end.x):
				var color: Color=image.get_pixel(x,y)
				if color.r>0.97 and color.g>0.97 and color.b>0.97: white+=1
				count+=1
		info["boss_roi_white_fraction"]=float(white)/maxi(1,count)
		_check(count>0 and float(white)/maxi(1,count)<0.25,"Boss ROI avoids broad whiteout in "+label)
	images.append(info)

func _trace(actor: Node2D) -> Dictionary:
	var state: StringName=actor.state_machine.get_state_id() if actor is BaseEnemy else actor.fsm.get_state_id()
	var data: Dictionary={"state":String(state),"state_time":actor.state_time,"actor_id":actor.get_instance_id(),"actor_world":[actor.global_position.x,actor.global_position.y],"player_hp":run.player.health.current_health,"physics_frame":Engine.get_physics_frames(),"draw_frame":Engine.get_frames_drawn()}
	if actor is BaseEnemy:
		data["vfx"]=actor.visual.sweep_vfx.snapshot()
		data["body"]=actor.visual.body_frames.snapshot()
		data["hitbox_active"]=actor.attack_hitbox.active
	else:
		data["vfx"]=(actor.get_node("GolemStoneSkin") as BossGolemSkin).stomp_vfx.snapshot()
		data["shockwave_count"]=actor.shockwave_count
	return data

func _finish() -> void:
	var report: Dictionary={"checks":checks,"failures":failures,"scene":"res://scenes/world_campaign.tscn","controlled_QA_placement":true,"other_enemy_AI_frozen":true,"phase_two_initialized_by_resolved_QA_damage":true,"boss_only_player_invulnerable":true,"guard_contacts_resolved_normally":true,"global_hitstop_disabled_for_phase_capture":true,"renderer":RenderingServer.get_current_rendering_method(),"adapter":RenderingServer.get_video_adapter_name(),"display_driver":DisplayServer.get_name(),"user_data_dir":OS.get_user_data_dir(),"images":images,"clips":clips,"subjective_visual_acceptance":false,"full_roster_acceptance":false,"Golem_body_animation":"not supplied; existing body plus r1 stomp VFX and reviewed light-only hunks","Player_white_flash":"unchanged; accepted-contact ink above body evaluated from actual captures"}
	var file:=FileAccess.open(DEST+"/capture_manifest.json",FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(report,"\t"))
		file.close()
	run.queue_free()
	await _frames(4)
	root.get_node("AudioManager").stop_all()
	print("RESULT EnemyVFXGPU %d checks, %d failures; screenshots=%d; body visibility review pending"%[checks,failures,images.size()])
	quit(0 if failures==0 else 1)

func _walk_sequence(guard: BaseEnemy,label: String,side: float) -> void:
	guard.ai_enabled=false
	guard.player=null
	guard.facing=side
	guard.state_machine.transition_to(&"patrol")
	run.player.reset_movement_at(guard.global_position+Vector2(side*180,0))
	run.player.controls_enabled=false
	guard.visual._last_position=guard.global_position # QA positioning rebase, not extra travel.
	guard.ai_enabled=true
	var sequence: Array[Dictionary]=[]
	var seen: Dictionary={}
	for tick: int in 78:
		await RenderingServer.frame_post_draw
		seen[guard.visual.body_frames.frame_index]=true
		sequence.append(_clip_frame(label,sequence.size(),guard))
		if tick in [12,30,48,66]: await _shot(label+"_pose_%02d"%tick,guard)
	_check(seen.size()>20 and guard.visual.body_frames.clip_id==&"walk","Actual "+label+" shows motor-driven authored gait")
	clips[label]={"frames":sequence,"sample_fps":60,"source":"actual WorldCampaign GPU viewport","fixed_render_step":60}
	guard.ai_enabled=false
	guard.player=run.player

func _hurt_sequence(guard: BaseEnemy) -> void:
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
	# Actor damage callbacks are immediate; presentation seeks in the next render update.
	# The first captured run intentionally remains in evidence (40/41, one early sample).
	await RenderingServer.frame_post_draw
	await _shot("guard_hurt_interrupt",guard)
	_check(not resolved.blocked and guard.visual.body_frames.clip_id==&"hurt" and not guard.attack_hitbox.active,"Real accepted stun selects authored Hurt and cancels the attack")
	var sequence: Array[Dictionary]=[]
	for tick: int in 18:
		await RenderingServer.frame_post_draw
		sequence.append(_clip_frame("guard_hurt",sequence.size(),guard))
	clips["guard_hurt"]={"frames":sequence,"sample_fps":60,"source":"actual WorldCampaign GPU viewport","fixed_render_step":60}
	guard.ai_enabled=false

func _frames(count: int) -> void:
	for index: int in count: await process_frame

func _check(passed: bool,message: String) -> void:
	checks+=1
	if not passed:
		failures+=1
		print("FAIL: "+message)
