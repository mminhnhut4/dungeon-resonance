extends SceneTree
## Finite, silent actual P01 capture fixture; concept images are never screenshots.
var flow: GameFlow
var world: ExteriorHub
var actor: Player
var failures: int = 0
var capture_prefix: String = ""
var captures: int = 0
var shots: Dictionary = {}
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture-prefix="): capture_prefix = arg.trim_prefix("--capture-prefix=")+"_"
	root.size = Vector2i(1152,648)
	root.content_scale_size = Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/pilgrimage_visual_%d.json" % Time.get_ticks_usec()
	root.add_child(flow)
	current_scene = flow
	await _step(12)
	world = flow.active_scene as ExteriorHub
	actor = world.player
	if not world.enter_exterior(&"o01_p01"):
		print("FAIL: actual main P01 entry")
		quit(1)
		return
	await _step(8)
	await _capture("p01_art_west_entry")
	await _walk(320)
	await _capture("p01_art_tunnel_shrine")
	await _walk(565)
	await _capture("p01_art_tree_slope")
	await _walk(980)
	await _capture("p01_art_lantern_ascent")
	await _walk(1380)
	await _capture("p01_art_rest_plateau")
	var art := world.exterior.get_node("PilgrimagePresentation") as PilgrimagePresentation
	art.show_alpha_cleanup(false)
	await _capture("p01_art_plateau_raw_alpha")
	art.show_alpha_cleanup(true)
	await _walk(1605)
	await _capture("p01_art_j1_takeoff")
	await _jump(world.exterior.jumps[0]["landing"])
	await _capture("p01_art_j1_first_landing")
	await _jump(world.exterior.jumps[1]["landing"])
	await _capture("p01_art_j1_second_landing")
	# Return from the optional branch onto the original continuous W.
	Input.action_press(&"move_right")
	await _step(36)
	Input.action_release(&"move_right")
	await _step(25)
	await _walk(2330)
	await _capture("p01_art_east_door")
	var shot_file := FileAccess.open("res://docs/verification/"+capture_prefix+"p01_camera_positions.json",FileAccess.WRITE)
	shot_file.store_string(JSON.stringify(shots,"\t"))
	shot_file.close()
	world.door_latched = false
	if not world.interact_station(&"door_east"):
		print("FAIL: P01 actual east E exit after art/jumps")
		failures += 1
	await _step(8)
	if world.exterior.room_id != &"o01_p02":
		print("FAIL: expected original P02 on actual E exit")
		failures += 1
	world.return_to_hub()
	await _step(6)
	flow.queue_free()
	await _step(8)
	print("RESULT P01VisualCapture %d captures, %d failures; original actor/geometry, private profile, QA master muted" % [captures,failures])
	quit(0 if failures == 0 else 1)

func _walk(x: float) -> void:
	var direction: int = 1 if actor.global_position.x < ExteriorHub.ORIGIN.x+x else -1
	var input: StringName = &"move_right" if direction > 0 else &"move_left"
	Input.action_press(input)
	for tick: int in 650:
		await _step(1)
		if direction*(actor.global_position.x-ExteriorHub.ORIGIN.x-x) >= 0: break
	Input.action_release(input)
	await _step(8)

func _jump(target: Vector2) -> void:
	Input.action_press(&"move_right")
	Input.action_press(&"jump")
	for tick: int in 90:
		await _step(1)
		if actor.global_position.x >= ExteriorHub.ORIGIN.x+target.x: Input.action_release(&"move_right")
		if tick > 6 and actor.motor.is_grounded(): break
	Input.action_release(&"jump")
	Input.action_release(&"move_right")
	await _step(6)
	var landed: Vector2 = world.exterior.to_local(actor.global_position)
	if not actor.motor.is_grounded() or absf(landed.y-target.y) > 2 or absf(landed.x-target.x) > 55:
		failures += 1
		print("FAIL: actual branch landing target=%s actor=%s grounded=%s" % [target,landed,actor.motor.is_grounded()])

func _capture(name: String) -> void:
	await _step(4)
	await RenderingServer.frame_post_draw
	captures += 1
	var at: Vector2 = world.exterior.to_local(actor.global_position)
	shots[name] = {"actor_x":at.x,"actor_foot_y":at.y,"W_floor_y":world.exterior.floor_y(at.x),"grounded":actor.motor.is_grounded(),"room":String(world.exterior.room_id),"local_NPC_count":world.npc_population.actors.size()}
	if root.get_texture().get_image().save_png("res://docs/verification/"+capture_prefix+name+".png") != OK:
		print("FAIL: PNG "+name)
		failures += 1

func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame
