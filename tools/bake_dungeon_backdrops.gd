extends SceneTree
## Bake original static masonry to PNG so hundreds of draw commands become one.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for boss_room: bool in [false, true]:
		var viewport := SubViewport.new()
		viewport.size = Vector2i(1280, 720)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(viewport)
		var backdrop := DungeonBackdrop.new()
		backdrop.bake_mode = true
		backdrop.boss_room = boss_room
		viewport.add_child(backdrop)
		backdrop.modulate = Color.WHITE
		for frame: int in 8:
			await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "res://assets/presentation/backdrop_boss.png" if boss_room else "res://assets/presentation/backdrop_foyer.png"
		var error: Error = viewport.get_texture().get_image().save_png(path)
		print("BAKE ", path, ": ", error_string(error))
		viewport.queue_free()
		await process_frame
	for frame: int in 3:
		await process_frame
	quit()
