extends SceneTree
var run: WorldCampaign
var checks: int=0
var failures: int=0
var metrics: Array[Dictionary]=[]
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step(count: int) -> void:
	for _i: int in count:await physics_frame;await process_frame
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated synthetic user data")
	if failures:quit(2);return
	AudioServer.set_bus_mute(0,true);root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=120
	run=preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	run.run_seed=20261016;run.profile=SanctuaryProfile.new();run.profile.save_path="user://part2/grounded.json"
	root.add_child(run);await _step(5)
	_check(run.enter_stage(4),"Existing boss stage is available")
	await _step(5);run.player.controls_enabled=false;run.player.health.minimum_health=1
	var boss: BossGolem=run.boss
	var skin: BossGolemSkin=boss.get_node("GolemStoneSkin") as BossGolemSkin
	var rig: Node2D=skin.art_rig
	var collider: CollisionShape2D=boss.get_node("Body") as CollisionShape2D
	var original_transform: Transform2D=collider.transform
	var shape_id: int=collider.shape.get_instance_id()
	var meshes: Array[Node]=rig.find_children("*","MeshInstance2D",true,false)
	var uv_hashes: Array[int]=[]
	for mesh: MeshInstance2D in meshes:uv_hashes.append(hash(mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]))
	_check(meshes.size()==21 and rig.find_children("*","Polygon2D",true,false).is_empty(),"Twenty-one static UV pieces; no Polygon2D UV path")
	for direction: float in [-1.0,1.0]:
		PlayerTravel.relocate(run.player,Vector2(120,640) if direction<0 else Vector2(1200,640))
		boss.facing=direction # Fixture selects initial committed mirror; real AI/motor moves.
		var previous: Dictionary={};var maximum_slide: float=0;var maximum_floor: float=0;var maximum_solver: float=0;var walking_frames: int=0;var walked: float=0;var last: Vector2=boss.global_position
		for _tick: int in int(6.0*Engine.physics_ticks_per_second):
			await _step(1)
			var now: Dictionary=rig.motion_snapshot()
			if now["pose"]==&"walk" and boss.velocity.x*direction>8:
				walking_frames+=1;walked+=absf(boss.global_position.x-last.x)
				maximum_solver=maxf(maximum_solver,now["stance_error"])
				for index: int in 2:
					if now["planted"][index]:
						var foot: Vector2=now["left_sole"] if index==0 else now["right_sole"]
						maximum_floor=maxf(maximum_floor,absf(foot.y-boss.global_position.y))
						if not previous.is_empty() and previous["planted"][index] and previous["pose"]==&"walk" and boss.global_position.distance_to(last)<32:
							var old: Vector2=previous["left_sole"] if index==0 else previous["right_sole"]
							maximum_slide=maxf(maximum_slide,foot.distance_to(old))
			previous=now;last=boss.global_position
		_check(walking_frames>20 and walked>25,"Real AI/motor walk in facing %.0f"%direction)
		_check(maximum_slide<0.35 and maximum_floor<0.25 and maximum_solver<0.25,"Planted soles keep world support/floor without stretching (%.4f/%.4f/%.4f)"%[maximum_slide,maximum_floor,maximum_solver])
		metrics.append({"direction":direction,"walking_frames":walking_frames,"walked":walked,"slide_per_tick":maximum_slide,"floor_error":maximum_floor,"solver_error":maximum_solver})
	_check(collider.transform==original_transform and collider.shape.get_instance_id()==shape_id,"Motion retains the physical collider shape/transform")
	for i: int in meshes.size():_check(hash((meshes[i] as MeshInstance2D).mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV])==uv_hashes[i],"Static UV buffer retained for piece%d"%i)
	if DisplayServer.get_name()!="headless":
		boss.ai_enabled=false
		PlayerTravel.relocate(run.player,boss.global_position+Vector2(-180,0));await _step(3)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("golem_grounded.png"))
	var file:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("grounded_motion.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics},"\t"));file.close()
	run.queue_free();await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT Part2GroundedMotion checks=%d failures=%d hz=%d"%[checks,failures,Engine.physics_ticks_per_second]);quit(0 if failures==0 else 1)
