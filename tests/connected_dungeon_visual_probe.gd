extends "res://tests/depth_floor_selection_test.gd"
## Native-only connected route evidence. AI disabled and direct-health kills are QA setup.
func _run() -> void:
	capture=OS.get_cmdline_user_args().has("--native-approved")
	var allowed: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	var evidence: String=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\","/")
	if not capture or DisplayServer.get_name()=="headless" or not allowed.is_absolute_path() or not evidence.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: native probe requires explicit approval and isolated QA/evidence roots"); quit(2); return
	Engine.physics_ticks_per_second=60
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,720)
	path="user://verification/connected_visual_%d.json" % Time.get_ticks_usec()
	await _open()
	flow.start_campaign(); await _step(6)
	var run: DepthCampaign=flow.active_scene as DepthCampaign
	_check(run!=null and run.is_opening_segment(),"Actual main entry is connected opening")
	if run==null: await _close(); _finish(); return
	_prepare_run(run)
	_check(run.enter_stage(4),"QA enters actual opening Golem room")
	await _step(4); _prepare_run(run)
	run.boss.health.apply_damage(99999); await _step(8)
	_check(run.portal_active and not run.has_pending_rewards(),"Actual defeated Golem opens saved bridge")
	PlayerTravel.relocate(run.player,Vector2(1160,640),PlayerTravel.Kind.INTRA_EXPEDITION)
	await _step(4)
	_check(run.floor_exit.open(),"Actual post-Golem choice opens")
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size=extent; await _step(4)
		run.floor_exit.panel.custom_minimum_size.x=minf(600,root.size.x-48)
		await _step(4)
		_check(root.get_visible_rect().encloses(run.floor_exit.panel.get_global_rect()),"Golem choice fits %d" % extent.x)
		_check(run.floor_exit.continue_button.visible and not run.floor_exit.continue_button.disabled,"Continue is available beside return at %d" % extent.x)
		await _picture("connected_golem_choice_%d" % extent.x)
	await _click(run.floor_exit.continue_button)
	await _step(6)
	_check(not run.is_opening_segment() and run.global_floor_number()==4,"Actual mouse continues same run to global4")
	for number: int in [1,2,3,4,5]:
		_prepare_run(run)
		root.size=Vector2i(800,600) if number%2==1 else Vector2i(1280,720)
		PlayerTravel.relocate(run.player,Vector2(650,640),PlayerTravel.Kind.INTRA_EXPEDITION)
		await _step(6)
		_check(run.room_number==number and run.global_floor_number()==number+3 and run.title.text.contains("%d/8" % (number+3)),"Actual global%d header and local ID" % (number+3))
		_check(run.room.locked and run.living_enemies().size()>0,"Global%d screenshot contains locked live roster" % (number+3))
		if root.size.x == 800:
			_check(run.depth_hud.get_global_rect().end.y <= 80.0,"Compact floor heading leaves combat and menu area clear")
		if number == 5:
			var art: ArtHUD = run.presentation.art_hud
			_check(art.boss_panel.visible and root.get_visible_rect().encloses(art.boss_frame.get_global_rect()) and root.get_visible_rect().encloses(art.boss_emblem.get_global_rect()),"Live boss frame and emblem remain inside small viewport")
			_check(not art.weapon_name.get_global_rect().intersects(art.boss_frame.get_global_rect()),"Small viewport keeps weapon caption above boss footer")
		await _picture("connected_floor_%d_%d" % [number+3,root.size.x])
		if number<5:
			await _clear_roster(run)
			_check(run.advance_room(),"Normal completion continues global%d" % (number+4))
			await _step(4)
		else:
			run.boss.health.apply_damage(99999); await _step(8)
	root.size=Vector2i(800,600)
	PlayerTravel.relocate(run.player,Vector2(1160,640),PlayerTravel.Kind.INTRA_EXPEDITION)
	await _step(4)
	_check(run.floor_exit.open(),"Final global8 return choice opens")
	await _picture("connected_final_return_choice_800")
	await _click(run.floor_exit.return_button); await _step(8)
	_check(flow.active_scene is PrologueHub,"Actual mouse returns continuous expedition to hub")
	await _picture("connected_returned_hub_800")
	await _close(); _finish()
func _picture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var evidence: String=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\","/")
	var image: Image=root.get_texture().get_image()
	_check(not image.is_empty() and image.get_width()==root.size.x,"Native pixels match viewport for "+label)
	var output: String=evidence.path_join(label+".png")
	var saved: Error=image.save_png(output)
	_check(saved==OK and FileAccess.file_exists(output),"Saved real renderer capture "+label)
func _finish() -> void:
	print("RESULT connected_dungeon_visual checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
