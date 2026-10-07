extends SceneTree
## Render an actual hit for visual QA, then leave the normal room playable.


func _initialize() -> void:
	call_deferred("_preview")


func _preview() -> void:
	var level := (load("res://scenes/test_level.tscn") as PackedScene).instantiate() as Node2D
	root.add_child(level)
	current_scene = level
	await _step_frames(5)
	var player: Player = level.player
	var dummy: TrainingDummy = level.dummy_a
	player.reset_movement_at(Vector2(365, 547))
	await _step_frames(3)
	var cursor := InputEventMouseMotion.new()
	cursor.position = root.get_canvas_transform() * (dummy.global_position + Vector2(0, -24))
	root.push_input(cursor, true)
	Input.action_press(&"attack")
	await _step_frames(1)
	Input.action_release(&"attack")
	for frame: int in 60:
		if dummy.hit_count > 0:
			break
		await _step_frames(1)
	await _step_frames(7)
	await RenderingServer.frame_post_draw
	var directory: String = ProjectSettings.globalize_path("res://docs/verification")
	DirAccess.make_dir_recursive_absolute(directory)
	var image_path: String = directory.path_join("combat_preview.png")
	var result: Error = root.get_texture().get_image().save_png(image_path)
	print("COMBAT PREVIEW: hit_count=%d, screenshot_error=%d, file=%s" % [dummy.hit_count, result, image_path])
	level.reset_room()
	print("COMBAT PREVIEW: ready for keyboard/mouse playtest")


func _step_frames(count: int) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame
