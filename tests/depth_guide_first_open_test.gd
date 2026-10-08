extends SceneTree
## Actual cold product entry and real E input; this validates layout, not native UX.
var checks: int = 0
var failures: int = 0
var trace: Array[Dictionary] = []
var capture: bool = false

func _initialize() -> void: _run.call_deferred()
func _step(count: int = 1) -> void:
	for index: int in count:
		await physics_frame
		await process_frame
func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)
func _key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code; event.keycode = code; event.pressed = pressed
	root.push_input(event, true)
func _observe(guide: DepthGuide, label: String) -> void:
	var bounds: Rect2 = root.get_visible_rect()
	var panel: Rect2 = guide.panel.get_global_rect()
	print("LAYOUT: ",label," heading_visible=",guide.heading.is_visible_in_tree()," heading_own_visible=",guide.heading.visible," heading_parent=",guide.heading.get_parent()," objective_text=",not guide.objective.text.is_empty()," row_visible=",guide.floor_rows[0].is_visible_in_tree()," row_own_visible=",guide.floor_rows[0].visible," row_intersects=",guide.floor_scroll.get_global_rect().intersects(guide.floor_rows[0].get_global_rect()))
	_check(guide.opened and guide.panel.is_visible_in_tree() and bounds.encloses(panel), label + " panel fits viewport")
	_check(panel.encloses(guide.heading.get_global_rect()) and panel.encloses(guide.objective.get_global_rect()), label + " heading and objective fit")
	_check(panel.encloses(guide.action.get_global_rect()) and panel.encloses(guide.back.get_global_rect()) and guide.action.disabled, label + " locked action and back fit")
	_check(guide.heading.is_visible_in_tree() and not guide.objective.text.is_empty() and guide.floor_rows[0].is_visible_in_tree() and guide.floor_scroll.get_global_rect().intersects(guide.floor_rows[0].get_global_rect()), label + " visible message and first floor")
	var rows: Array[String] = []
	for row: Label in guide.floor_rows: rows.append(str(row.get_global_rect()))
	trace.append({"label":label,"viewport":str(bounds),"panel":str(panel),"panel_minimum":str(guide.panel.get_combined_minimum_size()),"heading":str(guide.heading.get_global_rect()),"objective":str(guide.objective.get_global_rect()),"scroll":str(guide.floor_scroll.get_global_rect()),"rows":rows,"action":str(guide.action.get_global_rect()),"back":str(guide.back.get_global_rect())})
func _picture(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	var path: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(label + ".png")
	root.get_texture().get_image().save_png(path)
func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
		if argument == "--capture": capture = true
	if capture and DisplayServer.get_name() == "headless":
		push_error("Native capture requires a renderer"); quit(2); return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(800,600),Vector2i(1920,1080)]:
		root.size = extent
		var flow: GameFlow = load(ProjectSettings.get_setting("application/run/main_scene")).instantiate() as GameFlow
		flow.save_path_override = "user://verification/firstopen_%d_%d_%d.json" % [OS.get_process_id(),extent.x,Time.get_ticks_usec()]
		root.add_child(flow); current_scene = flow
		await _step(12)
		var hub: PrologueHub = flow.active_scene as PrologueHub
		var guide: DepthGuide = hub.get_node("DepthGuide") as DepthGuide
		PlayerTravel.relocate(hub.player,guide.npc.global_position,PlayerTravel.Kind.INTRA_EXPEDITION)
		await _step(5)
		_check(not guide.progress.unlocked() and not guide.opened, "%s cold locked fixture" % extent)
		_key(KEY_E,true)
		await _step(1)
		_observe(guide,"%d_first_1" % extent.x)
		_key(KEY_E,false)
		await _step(2); _observe(guide,"%d_first_3" % extent.x)
		await _step(5); _observe(guide,"%d_first_8" % extent.x)
		await _picture("npc_%d_first" % extent.x)
		_key(KEY_ESCAPE,true); await _step(1); _key(KEY_ESCAPE,false)
		await _step(3)
		_key(KEY_E,true); await _step(1); _key(KEY_E,false)
		_observe(guide,"%d_reopen_1" % extent.x)
		await _picture("npc_%d_reopen" % extent.x)
		guide.close(); flow.queue_free(); current_scene = null
		await _step(6)
	var evidence: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	if not evidence.is_empty():
		var file := FileAccess.open(evidence.path_join("firstopen_trace.json"),FileAccess.WRITE)
		file.store_string(JSON.stringify({"checks":checks,"failures":failures,"trace":trace},"\t"))
	print("RESULT: DepthGuideFirstOpen %d checks, %d failures" % [checks,failures])
	quit(0 if failures == 0 else 1)
