extends SceneTree
## Explicitly approved, isolated native evidence from the real opening rooms.
## No hardware input, personal saves, art import or progression grants.
var flow: GameFlow
var hub: ExteriorHub
var actor: CultivatorActor
var checks: int = 0
var failures: int = 0
var captures: Array[Dictionary] = []
var evidence: String
var accepted_injuries: int = 0
var seal_body_regions: Array[Image] = []
var seal_pose_frames: Array[int] = []
var seal_motion: Dictionary = {}
var atlas_motion: Array[Dictionary] = []
var record_atlas: bool = false

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	var approved: bool = "--native-approved" in OS.get_cmdline_user_args()
	var isolated: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	evidence = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\","/").trim_suffix("/")
	if not approved or DisplayServer.get_name() == "headless" or isolated.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(isolated+"/") or not evidence.begins_with(isolated+"/"):
		print("FAIL: explicit native approval and isolated user/evidence directories required"); quit(2); return
	DirAccess.make_dir_recursive_absolute(evidence)
	root.size = Vector2i(1280,720)
	if "--small-viewport" in OS.get_cmdline_user_args(): root.size = Vector2i(800,450)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var master: int = AudioServer.get_bus_index("Master")
	if master >= 0: AudioServer.set_bus_mute(master,true)
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/tan_dang_native_%d.json" % OS.get_process_id()
	root.add_child(flow)
	current_scene = flow
	await _step(10)
	hub = flow.active_scene as ExteriorHub
	_check(hub != null and hub.npc_population != null,"Actual configured opening binds its population")
	if hub == null: await _finish(); return
	await _select("tan_dang_moc_yen")
	if "--atlas-presentation" in OS.get_cmdline_user_args():
		record_atlas = true
		await _atlas_technique("moc_yen")
		_check(hub.enter_exterior(&"o01_p03",&"main",&"west",false),"Existing P03 room loads for atlas validation")
		await _step(8)
		await _select("tan_dang_lam_tuoc")
		await _atlas_technique("lam_tuoc")
		await _select("tan_dang_du_hanh")
		await _atlas_technique("du_hanh")
		_check(accepted_injuries == 6,"Two actual Player-source injury contacts per new NPC, no direct HP or life edits")
		await _finish()
		return
	if "--seal-presentation" in OS.get_cmdline_user_args():
		await _seal_presentation()
		await _finish()
		return
	await _capture("moc_yen_neutral")
	await _technique("moc_yen")
	_check(hub.enter_exterior(&"o01_p03",&"main",&"west",false),"Authored road transition opens the actual P03 room")
	await _step(8)
	await _select("tan_dang_lam_tuoc")
	await _capture("p03_neutral_pair")
	await _technique("lam_tuoc")
	if is_instance_valid(actor): actor._stop_defense("QA · Kết thúc mẫu hữu hạn")
	await _select("tan_dang_du_hanh")
	await _technique("du_hanh")
	_check(accepted_injuries == 3,"Exactly three live Player-source query contacts provoked the three native samples")
	_check(captures.size() == 11,"Native output has two neutral views and nine real phase captures")
	await _finish()

func _select(id: String) -> void:
	actor = hub.npc_population.actors.get(id) as CultivatorActor
	_check(is_instance_valid(actor),"Canonical population owns the visible identity "+id)
	if not is_instance_valid(actor): return
	PlayerTravel.relocate(hub.player,actor.global_position+Vector2(-32,0))
	var camera := hub.player.get_node("Camera2D") as Camera2D
	camera.set_process(false)
	camera.set_physics_process(false)
	camera.position = Vector2(0,-72)
	camera.reset_smoothing()
	camera.force_update_scroll()
	await _step(4)

func _atlas_technique(label: String) -> void:
	var fighter: CultivatorActor = actor
	_check(fighter != null and fighter.new_sprite != null and fighter.new_sprite.available,"Actual canonical actor binds the selected transparent atlas: "+label)
	if fighter == null or fighter.new_sprite == null or not fighter.new_sprite.available: return
	_check(fighter.caption.z_index == 3,"New resident caption draws above existing world poles without moving its actor: "+label)
	var original_shape: Shape2D = (fighter.hurtbox.get_child(0) as CollisionShape2D).shape
	_check(fighter.new_sprite.frame_index == 0 and fighter.body.texture is AtlasTexture,"Live idle image is an atlas frame: "+label)
	await _capture(label+"_atlas_idle")
	await _injure(fighter)
	await _capture(label+"_atlas_hurt")
	_check(fighter.combat_phase == "hurt" and fighter.new_sprite.frame_index == 10,"Real incoming contact seeks authored hurt pose after presentation draw: "+label)
	await _wait_phase(fighter,"tell",3.0)
	var start_position: Vector2 = fighter.global_position
	var original_target: Vector2 = fighter._strike_center
	for fraction: float in [0.15,0.75]:
		await _wait_fraction(fighter,"tell",fraction)
		var expected: int = 5 if fraction < 0.5 else 6
		_check(fighter.combat_phase == "tell" and not fighter.strike_hitbox.active and fighter.new_sprite.frame_index == expected,"Harmless windup seeks pose%d: %s" % [expected,label])
		_check(fighter._strike_center.is_equal_approx(original_target),"Pose seek cannot retarget committed aim: "+label)
		await _capture(label+"_atlas_tell_%02d" % int(fraction*100))
	await _wait_phase(fighter,"active",3.0)
	for fraction: float in [0.15,0.72]:
		await _wait_fraction(fighter,"active",fraction)
		var expected: int = 7 if fraction < 0.5 else 8
		_check(fighter.combat_phase == "active" and fighter.strike_hitbox.active and fighter.new_sprite.frame_index == expected,"Actual hit window seeks attack pose%d: %s" % [expected,label])
		await _capture(label+"_atlas_active_%02d" % int(fraction*100))
	if label == "lam_tuoc":
		await _wait_phase(fighter,"tell",3.0)
		await _wait_fraction(fighter,"tell",0.75)
		_check(fighter._strike_window == 2 and fighter.new_sprite.frame_index == 6 and not fighter.strike_hitbox.active,"Second cut retains its separate harmless follow-up windup")
		await _capture(label+"_atlas_followup_tell")
		await _wait_phase(fighter,"active",3.0)
		_check(fighter._strike_window == 2 and fighter.strike_hitbox.active,"Second slash visual reads the second real hit window")
		await _capture(label+"_atlas_followup_active")
	await _wait_phase(fighter,"recover",3.0)
	await _capture(label+"_atlas_recover")
	_check(fighter.new_sprite.frame_index == 9 and not fighter.strike_hitbox.active,"Authored recovery cannot deliver extra damage: "+label)
	_check(fighter.accepted_strikes == (2 if label == "lam_tuoc" else 1),"Expected accepted physical contacts only: "+label)
	if label == "du_hanh": _check(fighter.global_position.distance_to(start_position) > 0.1 and fighter.global_position.distance_to(start_position) <= 20.1,"Captured lunge includes real bounded physical movement, not sprite-only translation")
	_check((fighter.hurtbox.get_child(0) as CollisionShape2D).shape == original_shape,"Atlas seek preserves the original physical capsule resource: "+label)
	fighter._stop_defense("QA · Kết thúc mẫu atlas")
	await _injure(fighter,200.0)
	await _step(4)
	_check(fighter.world_state.records[fighter.stable_id]["mode"] == "downed" and fighter.health.current_health == 1.0 and fighter.new_sprite.frame_index == 11 and not fighter.strike_hitbox.active,"Existing life owner seeks collapsed art at its unchanged health floor: "+label)
	await _capture(label+"_atlas_downed")
	# A reflected X basis decomposes to rotation PI although its Y basis is
	# upright. Test the actual vertical axis, accepting the authored facing flip.
	_check(fighter.body.get_global_transform().y.normalized().is_equal_approx(Vector2.DOWN) and fighter.caption.get_global_transform().y.normalized().is_equal_approx(Vector2.DOWN),"Only the sprite counterrotates; collapsed image and caption remain upright: "+label)

func _seal_presentation() -> void:
	var fighter: CultivatorActor = actor
	var original_position: Vector2 = fighter.global_position
	var original_record: Dictionary = hub.npc_population.state.records[fighter.stable_id].duplicate(true)
	var spec: Dictionary = CultivatorCatalog.definition(fighter.stable_id)
	_check(spec["tell"] == 1.1 and spec["active"] == 0.16 and spec["recover"] == 0.9 and spec["radius"] == 34.0 and spec["damage"] == 16.0,"Existing seal timing, radius and realm damage contracts remain unchanged")
	await _capture("seal_idle")
	await _injure(fighter)
	await _wait_phase(fighter,"tell",3.0)
	original_position = fighter.global_position
	original_record = hub.npc_population.state.records[fighter.stable_id].duplicate(true)
	var locked_target: Vector2 = fighter._strike_center
	var hp_before: float = hub.player.health.current_health
	for fraction: float in [0.05,0.5,0.88]:
		await _wait_fraction(fighter,"tell",fraction)
		_check(fighter.combat_phase == "tell" and not fighter.strike_hitbox.active,"Charging seal is harmless at fraction %.2f" % fraction)
		_check(fighter._strike_center.is_equal_approx(locked_target),"Visible seal remains on its committed point")
		await _capture("seal_tell_%02d" % int(fraction*100))
		if fighter.new_sprite != null and fighter.new_sprite.available: seal_pose_frames.append(fighter.new_sprite.frame_index)
		var frame: Image = root.get_texture().get_image()
		# Canvas coordinates remain logical1280x720 under the project's stretch.
		# Map both corners to the actual screenshot pixels, including viewport800.
		var scale: Vector2 = Vector2(frame.get_size())/root.get_visible_rect().size
		var transform: Transform2D = fighter.get_global_transform_with_canvas()
		var corner: Vector2 = (transform*Vector2(-30,-65))*scale
		var opposite: Vector2 = (transform*Vector2(30,0))*scale
		var region := Rect2i(Vector2i(corner),Vector2i(opposite-corner))
		seal_body_regions.append(frame.get_region(region))
		seal_motion["region"] = [region.position.x,region.position.y,region.size.x,region.size.y]
		seal_motion["viewport"] = [frame.get_width(),frame.get_height()]
		seal_motion["logical"] = [root.get_visible_rect().size.x,root.get_visible_rect().size.y]
	seal_motion["early_middle"] = _changed_pixels(seal_body_regions[0],seal_body_regions[1])
	seal_motion["middle_late"] = _changed_pixels(seal_body_regions[1],seal_body_regions[2])
	print("SEAL_MOTION "+JSON.stringify(seal_motion))
	# The painted atlas has two authored anticipation poses. The sampled region
	# also contains charging VFX; pixel differences cannot prove a third body pose.
	_check(int(seal_motion["early_middle"]) > 8,"Actual rendered caster/charge region changes from early to late anticipation")
	_check(seal_pose_frames == [5,6,6],"Painted anticipation seeks its two actual authored poses without inventing a third")
	_check(is_equal_approx(hub.player.health.current_health,hp_before),"Entire charging animation deals no early damage")
	await _wait_phase(fighter,"active",3.0)
	_check(fighter.strike_hitbox.active and fighter.strike_hitbox.get_children().size() > 0,"Impact frame uses the existing active physical hitbox")
	await _capture("seal_impact")
	await _wait_phase(fighter,"recover",3.0)
	_check(not fighter.strike_hitbox.active and fighter.accepted_strikes == 1,"One committed seal produces one accepted damaging contact")
	_check(hub.player.health.current_health < hp_before and hp_before-hub.player.health.current_health <= 16.0,"Native seal still delivers bounded realm-scaled damage through the existing resolver")
	await _capture("seal_recover_early")
	await _wait_fraction(fighter,"recover",0.8)
	await _capture("seal_recover_late")
	_check(fighter.global_position.is_equal_approx(original_position),"Presentation never displaces the caster's physical root")
	_check(hub.npc_population.state.records[fighter.stable_id]["x"] == original_record["x"] and hub.npc_population.state.records[fighter.stable_id]["room"] == original_record["room"],"Art does not alter durable placement or room ownership")
	# A second real strike proves the marked point does not follow a dodging player.
	await _wait_phase(fighter,"tell",4.0)
	locked_target = fighter._strike_center
	var old_window: int = fighter.accepted_strikes
	PlayerTravel.relocate(hub.player,hub.player.global_position+Vector2(72,0))
	await _wait_fraction(fighter,"tell",0.8)
	_check(fighter._strike_center.is_equal_approx(locked_target),"Moving out of the telegraph cannot drag its lock point")
	await _capture("seal_dodge_lock")
	await _wait_phase(fighter,"recover",3.0)
	_check(fighter.combat_phase == "recover","Dodged seal still completes its original active window")
	_check(fighter.accepted_strikes == old_window,"Leaving the marked circle avoids the second real strike")
	await _wait_phase(fighter,"tell",4.0)
	await _wait_fraction(fighter,"tell",0.45)
	_check(fighter._strike != null and fighter._strike.attack_direction.x > 0.0,"A later real cast mirrors the gesture toward the player on the right")
	await _capture("seal_tell_right")
	# Isolated guard injection: no files are forged or restored. The owner lock
	# must stop the existing clock/hitbox and let its presentation clear too.
	fighter.world_state.compound_locked = true
	await _step(3)
	_check(fighter.combat_phase == "idle" and not fighter.strike_hitbox.active,"Owner lock cancels a committed tell before impact")
	await _capture("seal_compound_locked")
	fighter.world_state.compound_locked = false
	fighter._stop_defense("QA · Kết thúc mẫu hữu hạn")
	await _step(2)
	_check(fighter.combat_phase == "idle" and not fighter.strike_hitbox.active,"Cancellation clears the impact and retains idle presentation")
	await _capture("seal_stopped")
	await _injure(fighter,200.0)
	await _step(4)
	_check(fighter.world_state.records[fighter.stable_id]["mode"] == "downed" and fighter.health.current_health == 1.0 and not fighter.strike_hitbox.active,"New robe/pose obeys the existing downed health floor and closes all attack VFX")
	_check(is_equal_approx(fighter.rotation,-PI*0.42) and is_equal_approx(fighter.caption.get_global_transform().get_rotation(),0.0),"Downed presentation retains the existing foot pivot and upright caption")
	await _capture("seal_downed")
	_check(accepted_injuries == 2 and captures.size() == 12,"Exactly two real Player injuries and twelve native seal presentation frames")

func _wait_fraction(fighter: CultivatorActor, phase: String, fraction: float) -> void:
	for _index: int in 300:
		if fighter.combat_phase != phase: return
		var duration: float = float(fighter._combat_spec[phase])
		if 1.0-fighter.phase_remaining/duration >= fraction: return
		await _step(1)

func _changed_pixels(first: Image, second: Image) -> int:
	if first.get_size() != second.get_size(): return 0
	var changed: int = 0
	for y: int in first.get_height():
		for x: int in first.get_width():
			var a: Color = first.get_pixel(x,y)
			var b: Color = second.get_pixel(x,y)
			if absf(a.r-b.r)+absf(a.g-b.g)+absf(a.b-b.b) > 0.12: changed += 1
	return changed

func _technique(label: String) -> void:
	if not is_instance_valid(actor): return
	var fighter: CultivatorActor = actor
	await _injure(fighter)
	await _wait_phase(fighter,"tell",3.0)
	_check(fighter.combat_phase == "tell" and not fighter.strike_hitbox.active,"Named technique has a harmless visible tell: "+label)
	await _capture(label+"_tell")
	await _wait_phase(fighter,"active",3.0)
	_check(fighter.combat_phase == "active" and fighter.strike_hitbox.active,"Actual damaging window is visible: "+label)
	await _capture(label+"_active")
	await _wait_phase(fighter,"recover",3.0)
	_check(fighter.combat_phase == "recover" and not fighter.strike_hitbox.active,"Recovery closes the actual hitbox: "+label)
	await _capture(label+"_recovery")
	_check(fighter.accepted_strikes > 0,"The captured native skill made real Player contact: "+label)
	fighter._stop_defense("QA · Kết thúc mẫu hữu hạn")

func _injure(fighter: CultivatorActor, damage: float = 1.0) -> void:
	var probe: Hitbox = ActorCombatRig.hitbox(fighter.get_parent() as Node2D,16)
	var snapshot := AttackSnapshot.new()
	snapshot.source_id = hub.player.get_instance_id()
	snapshot.source_team_id = hub.player.hurtbox.team_id
	snapshot.attack_id = CombatIds.next_id()
	snapshot.root_event_id = snapshot.attack_id
	snapshot.base_damage = damage
	snapshot.attack_origin = hub.player.global_position
	probe.contact_detected.connect(func(target: Hurtbox, attack: AttackSnapshot) -> void:
		if target != fighter.hurtbox: return
		var event := DamageEvent.new()
		event.source_id = attack.source_id
		event.source_team_id = attack.source_team_id
		event.target_id = target.get_actor_id()
		event.attack_id = attack.attack_id
		event.root_event_id = attack.root_event_id
		event.hit_window_id = attack.hit_window_id
		event.base_damage = attack.base_damage
		event.attack_origin = attack.attack_origin
		event.physical_damage = true
		event.melee_hit = true
		var result: DamageResult = target.take_damage(event)
		if result.actual_damage > 0.0: accepted_injuries += 1
	)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20,48)
	probe.activate(snapshot,shape,(fighter.get_parent() as Node2D).to_local(fighter.global_position+Vector2(0,-26)))
	await _step(1)
	probe.sample_contacts()
	probe.deactivate()
	probe.queue_free()

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var output: String = evidence.path_join(label+".png")
	var result: Error = root.get_texture().get_image().save_png(output)
	_check(result == OK,"Native PNG saved: "+label)
	var labels: Array[Dictionary] = []
	for id: String in CultivatorCatalog.TAN_DANG_IDS:
		var resident: CultivatorActor = hub.npc_population.actors.get(id) as CultivatorActor
		if not is_instance_valid(resident): continue
		labels.append({"id":id,"caption":resident.caption.text,"caption_position":[resident.caption.global_position.x,resident.caption.global_position.y],"body_position":[resident.global_position.x,resident.global_position.y],"phase":resident.combat_phase,"remaining":resident.phase_remaining,"active":resident.strike_hitbox.active,"hp":resident.health.current_health,"maximum_hp":resident.health.maximum_health})
		if resident.new_sprite != null and resident.new_sprite.available:
			labels[-1]["sprite"] = {"frame":resident.new_sprite.frame_index,"pose":resident.new_sprite.pose_name,"atlas":resident.new_sprite.frame_atlas_path,"scale":resident.new_sprite.draw_scale,"foot_world":[resident.new_sprite.planted_contact_world.x,resident.new_sprite.planted_contact_world.y],"region":[resident.new_sprite.frame_region.position.x,resident.new_sprite.frame_region.position.y,resident.new_sprite.frame_region.size.x,resident.new_sprite.frame_region.size.y]}
	captures.append({"label":label,"path":output,"residents":labels})

func _wait_phase(fighter: CultivatorActor, phase: String, seconds: float) -> void:
	for _index: int in int(ceil(seconds*Engine.physics_ticks_per_second)):
		if not is_instance_valid(fighter) or fighter.combat_phase == phase: return
		await _step(1)

func _step(count: int) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame
		if record_atlas and atlas_motion.size() < 6000 and is_instance_valid(actor) and actor.new_sprite != null and actor.new_sprite.available:
			atlas_motion.append({"tick":Engine.get_physics_frames(),"id":actor.stable_id,"x":actor.global_position.x,"y":actor.global_position.y,"phase":actor.combat_phase,"remaining":actor.phase_remaining,"active":actor.strike_hitbox.active,"frame":actor.new_sprite.frame_index,"walk_distance":actor.new_sprite.walk_distance,"foot":[actor.new_sprite.planted_contact_world.x,actor.new_sprite.planted_contact_world.y],"scale":actor.new_sprite.draw_scale})

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL: "+label)

func _finish() -> void:
	var output := FileAccess.open(evidence.path_join("tan_dang_combat_native.json"),FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"seal_motion":seal_motion,"atlas_motion":atlas_motion,"scope":"Actual isolated opening rooms and real NPC clocks/query contacts; fixture Player relocation is not natural walking evidence. No FPS or footlock claim."},"\t"))
		output.close()
	if is_instance_valid(flow): flow.queue_free()
	await _step(6)
	await root.get_node("AudioManager").shutdown()
	print("RESULT TanDangCombatNative checks=%d failures=%d captures=%d" % [checks,failures,captures.size()])
	quit(0 if failures == 0 else 1)
