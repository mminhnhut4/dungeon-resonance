extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step(count: int) -> void:
	for _i: int in count:await physics_frame;await process_frame
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Synthetic user directory")
	if failures:quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	var stage:=Node2D.new();root.add_child(stage)
	var dust:=FootstepDust.new();dust.configure(Vector2(420,400),Vector2.RIGHT);stage.add_child(dust)
	var impact:=ImpactBurst.new();impact.configure(Vector2(580,400),Color.RED,&"fire",Vector2.RIGHT);stage.add_child(impact)
	var gpu_ids: Array[int]=[dust.particles.get_instance_id(),impact.particles.get_instance_id()]
	var cpu_ids: Array[int]=[]
	if DisplayServer.get_name()=="headless":
		_check(impact.compatibility_particles==null and dust.find_children("*","CPUParticles2D",true,false).is_empty(),"Headless keeps the existing non-emitting GPU parameter fixtures")
	else:
		var cpu_dust: CompatibilityParticleBurst=dust.find_children("*","CPUParticles2D",true,false)[0] as CompatibilityParticleBurst
		var cpu_impact: CompatibilityParticleBurst=impact.compatibility_particles
		_check(cpu_dust!=null and cpu_impact!=null and not dust.particles.visible and not impact.particles.visible and not dust.particles.emitting and not impact.particles.emitting,"Compatibility draws CPU bursts while authored GPU sources stay inactive")
		cpu_ids=[cpu_dust.get_instance_id(),cpu_impact.get_instance_id()]
		_check(cpu_dust.amount==4 and cpu_dust.one_shot and not cpu_dust.local_coords and cpu_dust.fixed_fps==60 and cpu_dust.texture==FootstepDust.TEXTURE and is_equal_approx(cpu_dust.lifetime,0.25),"Foot dust retains count, one-shot, world space, texture and clock")
		_check(cpu_impact.amount==16 and cpu_impact.one_shot and not cpu_impact.local_coords and cpu_impact.texture==impact.particles.texture and cpu_impact.material==impact.particles.material,"Contact retains the authored fan budget, texture and blend material")
		impact.configure_combat(GearItem.Quality.RARE);impact.enable_melee_sparks();impact.configure(Vector2(580,400),Color.BLUE,&"physical",Vector2.LEFT)
		_check(cpu_impact.amount==11 and cpu_impact.color==Color(1.0,0.66,0.16) and cpu_impact.direction.x>0 and cpu_impact.color_ramp!=null,"Reconfiguration updates real quality, mineral color, opposite strike direction and ramp")
		_check(is_equal_approx(cpu_impact.scale_amount_min*cpu_impact.texture.get_width(),3.0) and is_equal_approx(cpu_impact.scale_amount_max*cpu_impact.texture.get_width(),7.0),"Compatibility sparks keep the authored 3–7px size")
		impact.particles.speed_scale=0.0;await process_frame;await process_frame
		_check(cpu_impact.speed_scale==0.0,"Source hitstop speed is mirrored by the rendered emitter")
		impact.particles.speed_scale=1.0;await process_frame;await process_frame
		_check(cpu_impact.speed_scale==1.0,"Rendered emitter resumes with its source")
		_check(stage.find_children("*","CollisionObject2D",true,false).is_empty() and stage.find_children("*","AudioStreamPlayer2D",true,false).is_empty(),"Fallback creates no damage/collision or audio owner")
		var movement:=MovementVFX.new()
		movement.marks=Node2D.new();movement.add_child(movement.marks);stage.add_child(movement)
		var skid: GPUParticles2D=movement.spawn_skid(Vector2(700,400),Vector2.RIGHT)
		_check(not skid.visible and not skid.emitting and movement.marks.get_child_count()==1 and skid.global_position.is_equal_approx(Vector2(700,397)),"Skid keeps one world-positioned lifetime owner with an inactive GPU source")
		for _i: int in 12:movement.spawn_skid(Vector2(700,400),Vector2.RIGHT)
		_check(movement.marks.get_child_count()==MovementVFX.MAX_MARKS and movement.marks.find_children("*","CPUParticles2D",true,false).size()==MovementVFX.MAX_MARKS,"Skid spam preserves eight finite owners and eight rendered emitters")
		movement.advance_lifetimes(0.5);await process_frame
		_check(movement.marks.get_child_count()==0 and movement._lifetimes.is_empty(),"Skid lifetime retires each source and renderer together")
		movement.queue_free()
		await RenderingServer.frame_post_draw
		_check(root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("cpu_bursts.png"))==OK,"Native burst evidence saved")
	await _step(40)
	_check(not is_instance_valid(dust) and not is_instance_valid(impact) and gpu_ids.all(func(id: int) -> bool:return not is_instance_id_valid(id)) and cpu_ids.all(func(id: int) -> bool:return not is_instance_id_valid(id)),"Finite owners release original and rendered emitters together")
	stage.queue_free();await _step(3);await root.get_node("AudioManager").shutdown()
	print("RESULT CompatibilityParticleBurst checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
