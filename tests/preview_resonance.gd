extends SceneTree
## Capture real rendered spell/HUD examples, then optionally leave a playable room.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var level := (load("res://scenes/test_level.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(level)
	current_scene = level
	var directory: String = ProjectSettings.globalize_path("res://docs/verification")
	DirAccess.make_dir_recursive_absolute(directory)
	for index: int in 3:
		level.reset_room()
		for enemy: SlimeEnemy in level.enemies:
			enemy.ai_enabled = false
		level.player.reset_movement_at(Vector2(365, 547))
		level.set_rune_preset(index + 1)
		await _step(3)
		var cursor := InputEventMouseMotion.new()
		cursor.position = root.get_canvas_transform() * (level.dummy_a.global_position + Vector2(0, -24))
		root.push_input(cursor, true)
		Input.action_press(&"spell_cast")
		await _step(1)
		Input.action_release(&"spell_cast")
		for frame: int in 90:
			await _step(1)
			if index < 2 and level.dummy_a.hit_count > 0:
				break
			if index == 2 and level.spell_executor.get_child_count() > 0:
				break
		await _step(8 if index == 2 else 2)
		await RenderingServer.frame_post_draw
		var names: Array[String] = ["firestorm", "overload", "charged_slash"]
		var error: Error = root.get_texture().get_image().save_png(directory.path_join("%s_preview.png" % names[index]))
		print("VISUAL ", names[index], " screenshot_error=", error)
	level.reset_room()
	level.set_rune_preset(4)
	for enemy: SlimeEnemy in level.enemies:
		enemy.ai_enabled = true
	if "--stay" in OS.get_cmdline_user_args():
		print("PREVIEW: normal room ready for playtest")
		return
	level.queue_free()
	await _step(3)
	quit()


func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame
