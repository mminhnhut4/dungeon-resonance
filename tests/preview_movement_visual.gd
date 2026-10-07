extends "res://tests/preview_starter_character.gd"
## Real GPU evidence of the approved movement atlas and resolved reaction clocks.

func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	if DisplayServer.get_name() == "headless":
		print("FAIL: Movement visual preview needs a real GPU")
		await audio.shutdown()
		quit(1)
		return
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate()
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/preview_movement_visual.json"
	root.add_child(campaign)
	current_scene = campaign
	campaign.survival.director.automatic = false
	campaign.feedback.hit_stop_seconds = 0.0
	_freeze_input_and_ai()
	for enemy: Node2D in campaign.living_enemies():
		enemy.global_position = Vector2(1120.0, 640.0)
	rig = campaign.player.get_node("Visuals")
	camera = campaign.player.get_node("Camera2D")
	camera.follow_enabled = false
	camera.position = Vector2(0.0, -30.0)
	camera.zoom = Vector2(3.5, 3.5)
	camera.position_smoothing_enabled = false
	camera.shake_intensity = 0.0
	campaign.player.relocate(Vector2(540.0, 640.0))
	campaign.player.energy.enabled = false
	campaign.player.suspend_controls(false)
	_pointer(Vector2(850.0, 610.0))
	await _frames(12)
	_press(KEY_D, true)
	await _frames(25)
	_verify(rig.displayed_animation == &"run" and absf(rig._hair_angle) > 0.01 and absf(rig._sash_angle) > 0.01, "Real run gives hair and sash independent trailing motion")
	await _movement_capture("run_secondary")
	_press(KEY_D, false)
	await _frames(5)
	_verify(campaign.presentation.movement_vfx.skid_count == 1, "Real braking activates the production dust atlas emitter")
	await _movement_capture("skid_dust")
	await _frames(20)
	campaign.player.relocate(Vector2(540.0, 640.0))
	await _frames(5)
	_press(KEY_SHIFT, true)
	for frame: int in 24:
		if campaign.presentation.movement_vfx.ghosts.get_child_count() == 5:
			break
		await _frames(1)
	_press(KEY_SHIFT, false)
	_verify(campaign.presentation.movement_vfx.ghosts.get_child_count() == 5, "Five real mounted-part sword snapshots share the dash wind streak")
	await _movement_capture("dash_afterimages")
	await _frames(25)
	campaign.player.relocate(Vector2(540.0, 640.0))
	await _frames(5)
	_press(KEY_SPACE, true)
	await _frames(3)
	await _movement_capture("jump_takeoff")
	_press(KEY_SPACE, false)
	await _wait_pose(&"land", 75)
	await _frames(3)
	_verify(rig.skeleton.scale.y < rig.modular_skin.visual_scale, "Landing compresses only the cosmetic skeleton")
	await _movement_capture("landing_compression")
	await _frames(15)
	await _capture_reactions()
	for code: int in [KEY_D, KEY_SPACE, KEY_SHIFT]:
		_press(code, false)
	campaign.queue_free()
	await _frames(5)
	await audio.shutdown()
	print("MOVEMENT VISUAL PREVIEW: %d captures; %s" % [captures, "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)


func _capture_reactions() -> void:
	for pose: StringName in [&"flinch", &"knockback", &"kneel", &"thrown"]:
		campaign.player.reset_movement_at(Vector2(540.0, 640.0))
		await _frames(5)
		campaign.player.hurtbox.set_invulnerable(false)
		var event: DamageEvent = _player_damage(3.0)
		event.hit_reaction = pose
		event.attack_direction = Vector2.LEFT
		event.knockback = Vector2(-190.0, -440.0 if pose == &"thrown" else 0.0)
		var result: DamageResult = campaign.player.hurtbox.take_damage(event)
		await _frames(4)
		_verify(result.actual_damage > 0.0 and rig.displayed_animation == StringName("reaction_" + String(pose)), "Resolved %s hit drives the actual Player presentation" % pose)
		await _movement_capture("reaction_" + String(pose))
		if pose == &"thrown":
			await _wait_pose(&"reaction_get_up", 100)
			await _frames(4)
			_verify(rig.displayed_animation == &"reaction_get_up", "Thrown floor recovery enters the actual get-up pose")
			await _movement_capture("reaction_get_up")
		await _frames(30)


func _movement_capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://docs/verification/movement_visual_" + label + ".png")
	_verify(picture.save_png(path) == OK, "Capture " + path)
	captures += 1
