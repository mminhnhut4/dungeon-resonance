extends SceneTree
## Native isolated VFX fixture, not a product-play video or performance sample.
var checks: int=0
var failures: int=0
var stage: Node2D
var actor: SlimeEnemy
var visual: ElementAfflictionVFX
var feedback: CombatFeedback
var source: Node2D
var evidence: String
var captures: Array[Dictionary]=[]
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step(n: int) -> void:
	for _i: int in n:await physics_frame;await process_frame
func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image=root.get_texture().get_image()
	_check(image.save_png(evidence.path_join(label+".png"))==OK,"Actual native capture "+label)
	var orange_old: int=0;var orange_new: int=0
	for yy: int in range(325,405):
		for xx: int in range(145,255):
			var c: Color=image.get_pixel(xx,yy)
			if c.r>0.12 and c.r>c.g*1.25 and c.g>c.b*1.25:orange_old+=1
		for xx: int in range(595,705):
			var c: Color=image.get_pixel(xx,yy)
			if c.r>0.12 and c.r>c.g*1.25 and c.g>c.b*1.25:orange_new+=1
	captures.append({"label":label,"old_orange_pixels":orange_old,"new_orange_pixels":orange_new,"actor":actor.position,"clock":actor.statuses.burn_remaining,"source_emitting":visual.burn.emitting,"cpu":visual.get_node_or_null("BurnEmbersCompatibility")!=null})
	if "--assert-retrigger-clean" in OS.get_cmdline_user_args() and label in ["retrigger_first_frame","retrigger_150ms"]:
		_check(orange_old==0,"Re-trigger leaves no stale flames at the previous world position: "+label)
func _ignite(seconds: float) -> void:
	var fire:=DamageEvent.new();fire.source_id=source.get_instance_id();fire.source_team_id=1;fire.target_id=actor.get_instance_id();fire.attack_id=CombatIds.next_id();fire.root_event_id=fire.attack_id;fire.hit_window_id=1;fire.base_damage=0.1;fire.burn_damage=0.1;fire.burn_duration=seconds;fire.burn_interval=0.5
	var result: DamageResult=actor.hurtbox.take_damage(fire);visual.refresh_visual()
	_check(not result.blocked and visual.burn_visible and actor.statuses.burn_remaining>0.0,"Each visual fixture ignition is accepted by the real Hurtbox/status pipeline")
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(DisplayServer.get_name()!="headless" and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Native fixture uses isolated userdata")
	if failures:quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);root.content_scale_size=root.size;Engine.max_fps=120;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	RenderingServer.set_default_clear_color(Color(0.025,0.035,0.05))
	stage=Node2D.new();root.add_child(stage)
	feedback=CombatFeedback.new();feedback.hit_stop_seconds=0.0;stage.add_child(feedback);feedback.enable_global_hitstop(true)
	source=Node2D.new();stage.add_child(source)
	actor=preload("res://scenes/enemies/slime_enemy.tscn").instantiate() as SlimeEnemy
	actor.position=Vector2(200,400);actor.ai_enabled=false;actor.combat_feedback=feedback;stage.add_child(actor);actor.statuses.combat_feedback=feedback
	visual=ElementAfflictionVFX.new();visual.name="ElementAfflictionVFX";actor.add_child(visual);visual.initialize(actor,actor.hurtbox,feedback)
	await _step(8);_ignite(2.0);await _step(30);await _capture("first_burn_old_position")
	_ignite(3.0);await _capture("extended_burn_keeps_particles")
	_check(int(captures.back()["old_orange_pixels"])>0,"Extending an active burn keeps already visible particles rather than restarting the effect")
	actor.statuses.clear();visual.refresh_visual();await _step(72)
	actor.position=Vector2(650,400);await _step(2);await _capture("off_after_move")
	_ignite(2.0);await _step(1);await _capture("retrigger_first_frame")
	await _step(9);await _capture("retrigger_150ms")
	for i: int in 10:await _step(3);await _capture("retrigger_sample_%02d"%i)
	_check(captures.any(func(row: Dictionary)->bool:return String(row["label"]).begins_with("retrigger_sample_") and int(row["new_orange_pixels"])>0),"Re-trigger actually paints live flames at the new location")
	actor.statuses.clear();visual.refresh_visual();await _step(65)
	feedback.hitstop_manager.regular_seconds=0.4;feedback.hitstop_manager.request_hitstop();_ignite(1.5)
	var clock: float=actor.statuses.burn_remaining
	for _i: int in 3:await process_frame
	await _capture("retrigger_while_frozen")
	_check(actor.statuses.burn_remaining==clock and visual.burn.speed_scale==0.0,"Burn applied within hit-stop remains on the original frozen clock")
	var cpu: CPUParticles2D=visual.get_node_or_null("BurnEmbersCompatibility") as CPUParticles2D
	if cpu!=null:_check(cpu.speed_scale==0.0 and cpu.emitting,"CPU begins frozen and still owns live emission")
	while feedback.is_frozen():await process_frame
	await _step(18);await _capture("released_after_frozen_start")
	var f:=FileAccess.open(evidence.path_join("visual.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"fixture":"One real Slime/Hurtbox/Status/VFX on isolated empty stage; hidden>lifetime then moved450px; actual native images, no performance claim."},"\t"));f.close()
	stage.queue_free();await _step(5);await root.get_node("AudioManager").shutdown()
	print("RESULT BurnRetriggerVisual checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
