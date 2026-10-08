extends "res://tests/depth_campaign_test.gd"
## Native capture is explicit; traversal and chest use actual Player input.
var capture: bool=false
var evidence: Array[Dictionary]=[]
var timing: Dictionary={}

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): hz=int(argument.trim_prefix("--hz="))
		if argument=="--native-approved": capture=true
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if hz not in [60,120] or capture!=(DisplayServer.get_name()!="headless") or not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):
		print("FAIL: wide-floor test requires isolated save and explicit native approval"); quit(2); return
	Engine.physics_ticks_per_second=hz; AudioServer.set_bus_mute(0,true)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1280,720)
	bank=SanctuaryProfile.new(); bank.save_path="user://wide_depth/%d_%d/profile.json" % [hz,Time.get_ticks_usec()]
	_check(_initialize_bank(),"Wide-floor fixture initializes a sealed isolated profile through its owner")
	if failures>0: _stop_fixture(); return
	await _open_wide_run()
	var expedition: DepthCampaign=run as DepthCampaign
	var actor_id: int=run.player.get_instance_id()
	var opening_before: Dictionary=bank.opening_progress.duplicate(true)
	var receipts_before: Array[String]=bank.boss_receipts.duplicate()
	_check(run.room_number==1 and is_equal_approx(Catalog.room_width(1),1920),"Only Vân Thạch begins with a1920-wide layout")
	_check(Catalog.enemy_anchors(1)==[Vector2(600,640),Vector2(1120,640),Vector2(1660,640)] and run.living_enemies().size()==3,"Same three guard definitions occupy three authored encounter pockets")
	_check(run.room.get("landmarks").size()==3,"Exactly three room-owned landmarks are rendered")
	_check(run.room.get("terrain_art").get("sprites").size()==50,"Wide floor and unchanged shelves use50 terrain sprites within64 cap")
	_check(run.presentation.atmosphere.torches.size()==4 and run.presentation.atmosphere.dust.amount==72,"Wider presentation keeps four torch lights and72 dust particles")
	_check(is_equal_approx(run.presentation.atmosphere.torches[-1].get_parent().position.x,1680),"Existing torch positions cover the far side without extra light owners")
	var backdrop: Sprite2D=run.room.get("background") as Sprite2D
	_check(backdrop.scale.x==backdrop.scale.y and backdrop.texture.get_width()*backdrop.scale.x>=1920 and backdrop.texture.get_height()*backdrop.scale.y>=720,"Background uses uniform cover with no aspect stretch or uncovered width")
	var chest: TreasureChest=expedition.branch_chest
	_check(chest!=null and chest.get_parent()==run.room and chest.position==Vector2(560,356) and not chest.large and not chest.relic_reward,"One ordinary room-owned branch chest rests on the existing high ledge")
	_check(not chest.interact() and not chest.is_open,"Branch reward cannot open from the entry below it")
	await _pursuit_over_old_edge()
	_disable_ai()
	PlayerTravel.relocate(run.player,Catalog.ENTRY,PlayerTravel.Kind.INTRA_EXPEDITION); await _step(5)
	var hp_before: float=run.player.health.current_health
	var inventory_before: Dictionary=GearInventoryCodec.encode(run.gear.inventory)
	var walking_started: int=Time.get_ticks_msec()
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size=extent; await _step(3)
		for point: Vector2 in [Vector2(180,640),Vector2(1000,640),Vector2(1770,640)]:
			await _walk(point.x)
			await _step(ceili(hz*.25))
			_check(run.player.motor.is_grounded() and absf(run.player.position.y-640)<2 and absf(run.player.position.x-point.x)<25,"Real walking reaches%s at%s without a gap or wall trap" % [point,extent])
			_check(_visible_landmarks_clear(),"Visible landmark directions stay clear of the depth HUD at%s/%s" % [extent,point])
			await _picture("wide_%d_%d" % [extent.x,roundi(point.x)])
		var camera: Camera2D=run.player.get_node("Camera2D") as Camera2D
		var half_view: float=extent.x/camera.zoom.x*.5
		_check(camera.limit_right==1888 and camera.get_screen_center_position().x-half_view>=31.0 and camera.get_screen_center_position().x+half_view<=1889.0,"Camera follows past old edge and clamps inside new walls at%s" % extent)
		_check(not run.advance_room() and run.room.locked,"Walking to the far side never bypasses the three-guard seal")
	timing["two_resolution_walk_wall_seconds"]=(Time.get_ticks_msec()-walking_started)/1000.0
	await _walk(180)
	var branch_started: int=Time.get_ticks_msec()
	var shelves: Array=Catalog.floor_data(1)["shelves"]
	for index: int in 3:
		var shelf: Rect2=shelves[index]
		if index==2: await _walk((shelves[1] as Rect2).end.x-30)
		await _jump(Vector2(shelf.get_center().x,shelf.position.y))
		_check(run.player.motor.is_grounded() and absf(run.player.position.y-shelf.position.y)<2,"Existing base jump reaches branch step%d" % index)
	_check(GearInventoryCodec.encode(run.gear.inventory)==inventory_before and is_equal_approx(run.player.health.current_health,hp_before),"Wider traversal and optional branch preserve carried UIDs and HP")
	await _picture("wide_branch_before_open")
	run.gear.loot.rng.seed=4242
	var dropped_before: int=run.gear.loot.spawned_total
	var depth_events_before: int=events.size()
	var save_before: PackedByteArray=FileAccess.get_file_as_bytes(bank.save_path)
	await _key_e()
	_check(chest.is_open and expedition._opened_branch_chests.has(1),"Actual E opens the chest and marks its expedition ownership")
	var dropped_after: int=run.gear.loot.spawned_total
	_check(dropped_after-dropped_before>=5 and dropped_after-dropped_before<=7,"Ordinary existing chest table emits a finite5–7 real pickups")
	await _key_e(); await _key_e()
	_check(not chest.interact() and run.gear.loot.spawned_total==dropped_after,"Repeated E/interact cannot respawn the same branch reward")
	_check(events.size()==depth_events_before and FileAccess.get_file_as_bytes(bank.save_path)==save_before and bank.opening_progress==opening_before and bank.boss_receipts==receipts_before,"Opening branch loot grants no depth/opening/boss receipt or permanent save award")
	await _walk(715); await _step(hz)
	_check(run.player.motor.is_grounded() and absf(run.player.position.y-640)<2,"Optional branch drops safely onto the continuous combat lane")
	timing["branch_jump_open_drop_wall_seconds"]=(Time.get_ticks_msec()-branch_started)/1000.0
	var old_room: int=run.room.get_instance_id()
	var old_chest: int=chest.get_instance_id()
	allow_commit=false
	await _clear_roster()
	await _walk(Catalog.exit_point(1).x)
	_check(run.can_choose_floor_exit() and run.has_pending_rewards() and not run.advance_room(),"Real far exit is reachable; a failed progress commit still blocks transition")
	allow_commit=true; _check(run.retry_pending_rewards(),"Existing progress owner retries the same pending clear")
	_check(run.advance_room(),"Cleared far exit advances through the existing room lifecycle")
	await _step(6); _disable_ai()
	_check(run.room_number==2 and run.player.get_instance_id()==actor_id and not is_instance_id_valid(old_room) and not is_instance_id_valid(old_chest),"Transition retains Player and frees the wide room and branch chest")
	var narrow_camera: Camera2D=run.player.get_node("Camera2D") as Camera2D
	_check(narrow_camera.limit_right==1248 and run.room.get("room_width")==1280.0 and expedition.branch_chest==null and run.room.get("landmarks").is_empty(),"Floor two resets width/camera and receives no branch reward or markers")
	_check(Catalog.enemy_anchors(2)==[Vector2(580,520),Vector2(735,520),Vector2(890,520),Vector2(1045,520)],"Floor-two roster anchors retain their original values")
	_check(run.enter_room(1),"Fixture re-enters first floor inside the same expedition")
	await _step(5); _disable_ai()
	_check(expedition.branch_chest==null and run.gear.loot.spawned_total==dropped_after,"Same expedition cannot regenerate its opened branch chest after room rebuild")
	_release(); run.queue_free(); await _step(6)
	await _open_wide_run()
	_check((run as DepthCampaign).branch_chest!=null and not (run as DepthCampaign).branch_chest.is_open,"A fresh expedition owns one fresh branch chest")
	_release(); run.queue_free(); await _step(6)
	_check(is_equal_approx(Engine.time_scale,1.0),"Wide-room teardown releases modal clocks")
	var file:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("wide_floor_report.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify({"checks":checks,"failures":failures,"hz":hz,"native":capture,"timing":timing,"captures":evidence,"limits":"Pursuit includes actual melee and live AI. Geometry/chest legs disable AI; roster deaths use an explicit health fixture. Wall times describe the probe, not normal gameplay duration or balance."},"\t")); file.close()
	root.get_node("AudioManager").call("shutdown")
	print("RESULT DepthWideFloor checks=%d failures=%d hz=%d native=%s" % [checks,failures,hz,capture]); quit(0 if failures==0 else 1)

func _open_wide_run() -> void:
	run=CAMPAIGN.instantiate() as DungeonRun; run.profile=bank; run.world_building_enabled=true
	run.starting_inventory=HubPreparation.starter_inventory(bank); run.set("depth_progress_committer",_commit_depth)
	root.add_child(run); current_scene=run; await _step(8)
	run.feedback.hit_stop_seconds=0; run.feedback.enable_global_hitstop(false)
	run.survival.set_enabled(false); run.player.health.minimum_health=1
	run.gear.loot.drop_table=run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance=1.0; run.gear.loot.drop_table.blueprint_chance_total=0.0
	_disable_ai(); await _step(5)

func _pursuit_over_old_edge() -> void:
	var guard: BaseEnemy=run.living_enemies()[0] as BaseEnemy
	PlayerTravel.relocate(run.player,guard.global_position+Vector2(-32,0)); await _step(3)
	var motion:=InputEventMouseMotion.new()
	motion.position=run.player.get_canvas_transform()*(guard.global_position+Vector2(0,-25))
	Input.parse_input_event(motion); await _step(2)
	var before: float=guard.health.current_health
	Input.action_press(&"attack"); await _step(1); Input.action_release(&"attack"); await _step(ceili(hz*.4))
	_check(guard.health.current_health<before and guard.hit_aggro.active(),"Actual committed Player melee provokes the existing guard memory")
	PlayerTravel.relocate(run.player,Vector2(1770,640)); await _step(3)
	guard.ai_enabled=true; guard.state_machine.process_mode=Node.PROCESS_MODE_INHERIT
	var pursuit_started: int=Time.get_ticks_msec()
	var needed_seconds: float=(1280.0-guard.global_position.x)/guard.definition.chase_speed+2.0
	for _index: int in ceili(hz*needed_seconds):
		if guard.global_position.x>1280: break
		await _step(1)
	timing["accepted_melee_pursuit_wall_seconds"]=(Time.get_ticks_msec()-pursuit_started)/1000.0
	print("PURSUIT ",JSON.stringify({"position":[guard.position.x,guard.position.y],"speed":guard.definition.chase_speed,"memory":guard.hit_aggro.remaining,"state":guard.state_machine.get_state_id(),"needed_seconds":needed_seconds}))
	_check(guard.global_position.x>1280 and guard.global_position.x<1830 and guard.is_on_floor() and guard.hit_aggro.active(),"Live guard pursues over the former room edge on real continuous ground")
	guard.ai_enabled=false; guard.state_machine.process_mode=Node.PROCESS_MODE_DISABLED
	guard.attack_hitbox.deactivate()

func _key_e() -> void:
	for pressed: bool in [true,false]:
		var key:=InputEventKey.new(); key.keycode=KEY_E; key.physical_keycode=KEY_E; key.pressed=pressed
		root.push_input(key,true); await _step(1)
	await _step(2)

func _visible_landmarks_clear() -> bool:
	var viewport_rect: Rect2=root.get_visible_rect()
	var hud_rect: Rect2=(run as DepthCampaign).depth_hud.get_global_rect()
	for marker: Node2D in run.room.get("landmarks"):
		var caption: Label=marker.get_node("LandmarkCaption") as Label
		if caption.z_as_relative or caption.z_index<1: return false
		var transform: Transform2D=caption.get_global_transform_with_canvas()
		var rectangle:=Rect2(transform.origin,caption.size*transform.get_scale())
		if rectangle.intersects(viewport_rect) and rectangle.intersects(hud_rect): return false
	return true

func _picture(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	var path: String=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(label+".png")
	root.get_texture().get_image().save_png(path)
	evidence.append({"path":path,"player":[run.player.position.x,run.player.position.y]})
