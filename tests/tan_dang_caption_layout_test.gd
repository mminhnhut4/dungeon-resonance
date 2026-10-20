extends SceneTree
## Product read-only smoke plus declared spatial fixtures; no gameplay-route claim.

var checks: int = 0
var failures: int = 0
var arena: Node2D
var camera: Camera2D
var labels: Array[Label] = []
var anchors: Array[Vector2] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/").trim_suffix("/").to_lower()
	if not _check(qa.is_absolute_path() and OS.get_user_data_dir().replace("\\", "/").to_lower().begins_with(qa + "/"), "Isolated caption QA storage"):
		quit(2)
		return
	AudioServer.set_bus_mute(0, true)
	await _product_smoke()
	await _declared_positions()
	root.get_node("AudioManager").stop_all()
	print("RESULT TanDangCaptionLayout checks=%d failures=%d hz=%d" % [checks, failures, Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)


func _product_smoke() -> void:
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/caption_layout_%d.json" % Time.get_ticks_usec()
	root.add_child(flow)
	current_scene = flow
	await _frames(12)
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	if hub != null:
		# The isolated QA profile may restore an exterior anchor at startup.
		# Enter the real yard through its existing transition before checking
		# visible Hub labels; hidden-yard Controls are not placement candidates.
		if hub.outside or not hub.yard.is_visible_in_tree():
			if _check(hub.return_to_hub(false), "Product transition restores the visible Hub yard for the house-label fixture"):
				await _frames(4)
		if _check(hub.yard.is_visible_in_tree() and not hub.outside, "House-label fixture is in the actual visible Hub"):
			await _hub_station_fixture(hub)
	if _check(hub != null and hub.enter_exterior(&"o01_p03"), "Product P03 creates the two existing Tàn Đăng captions"):
		await _frames(5)
		var population: NpcPopulation = hub.npc_population
		var lam: CultivatorActor = population.actors.get(TanDangProgress.LAM) as CultivatorActor
		var du: CultivatorActor = population.actors.get(TanDangProgress.DU) as CultivatorActor
		if _check(is_instance_valid(lam) and is_instance_valid(du), "P03 has both live caption owners"):
			hub.player.controls_enabled = false
			var before: Dictionary = population.state.snapshot()
			var profile_bytes: PackedByteArray = FileAccess.get_file_as_bytes(flow.profile.save_path)
			var life_bytes: PackedByteArray = FileAccess.get_file_as_bytes(population.state.save_path)
			var hp_lam: float = lam.health.current_health
			var hp_du: float = du.health.current_health
			var lam_text: String = lam.caption.text
			var du_text: String = du.caption.text
			population._process(0.0)
			_check(population.state.snapshot() == before and FileAccess.get_file_as_bytes(flow.profile.save_path) == profile_bytes and FileAccess.get_file_as_bytes(population.state.save_path) == life_bytes, "Caption placement writes no profile or NPC owner state")
			_check(lam.health.current_health == hp_lam and du.health.current_health == hp_du and lam.caption.text == lam_text and du.caption.text == du_text and not hub.player.controls_enabled, "Placement changes no HP, pause/control state or authored text")
			_check(lam.caption.visible and du.caption.visible and lam.caption.is_visible_in_tree() and du.caption.is_visible_in_tree(), "Both existing captions remain available to greeting visibility checks")
	flow.queue_free()
	current_scene = null
	await _frames(6)


func _hub_station_fixture(hub: ExteriorHub) -> void:
	# Synthetic captions use the three authored Hub stop positions, but the
	# house heading and camera belong to the actual Product Hub scene. Its
	# painted Hub art displays station headings only near the real player.
	var heading: Label = hub.stations[&"house"].get_child(0) as Label
	var player_before: Vector2 = hub.player.global_position
	PlayerTravel.relocate(hub.player, hub.stations[&"house"].global_position)
	var product_camera: Camera2D = hub.player.get_node("Camera2D") as Camera2D
	product_camera.reset_smoothing()
	product_camera.force_update_scroll()
	await _frames(3)
	var viewport_rect: Rect2 = root.get_visible_rect()
	var house_rect: Rect2 = TanDangCaptionLayout._rect(heading)
	if not _check(heading.text == "NHÀ LỮ KHÁCH" and heading.is_visible_in_tree() and house_rect.has_area() and house_rect.intersects(viewport_rect), "Actual Product Hub house heading is painted and visible near the player"):
		PlayerTravel.relocate(hub.player, player_before)
		product_camera.reset_smoothing()
		product_camera.force_update_scroll()
		return
	var fixed: Array[Rect2] = []
	for station_id: StringName in [&"training", &"test_chest", &"house", &"stash", &"merchant", &"blacksmith", &"portal"]:
		var marker: Marker2D = hub.stations.get(station_id) as Marker2D
		if not is_instance_valid(marker) or marker.get_child_count() == 0: continue
		var station_label: Label = marker.get_child(0) as Label
		if not is_instance_valid(station_label) or not station_label.is_visible_in_tree(): continue
		var obstacle: Rect2 = TanDangCaptionLayout._rect(station_label)
		if obstacle.has_area() and obstacle.intersects(viewport_rect): fixed.append(obstacle)
	var local_labels: Array[Label] = []
	var local_anchors: Array[Vector2] = [Vector2(0, -108), Vector2(-120, -170), Vector2(-220, -158)]
	var positions: Array[float] = [1385.0, 900.0, 1345.0]
	var ids: Array[String] = [TanDangLivingCatalog.DU, TanDangLivingCatalog.MOC, TanDangLivingCatalog.LAM]
	var activities: Array[String] = ["Đi tới · Sửa đồ cũ", "Nghỉ cạnh sổ", "Nghỉ cạnh đồ sửa phù"]
	var living := TanDangLivingRuntime.new()
	activities[2] = living._greeting_line(TanDangLivingCatalog.LAM, "forage_help")
	living.free()
	for index: int in 3:
		var actor := Node2D.new()
		actor.position = Vector2(positions[index], 640)
		hub.yard.add_child(actor)
		var label := Label.new()
		label.position = local_anchors[index]
		label.size = Vector2(240, 72) if index == 1 else Vector2(220, 72)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", 13)
		# The product debug-label registry hides newly added world Labels unless
		# they carry the same approved visibility marker as NpcPilotActor.caption.
		label.set_meta(&"debug_keep", true)
		label.text = _copy(ids[index], activities[index])
		actor.add_child(label)
		local_labels.append(label)
	await _frames(2)
	print("HUB_VISIBILITY flow=", hub.get_parent().visible, " hub=", hub.visible, " yard=", hub.yard.visible, " yard_tree=", hub.yard.is_visible_in_tree(), " house_marker=", hub.stations[&"house"].visible, " house_label=", heading.visible, " house_tree=", heading.is_visible_in_tree(), " sample_actor=", local_labels[0].get_parent().visible, " sample_label=", local_labels[0].visible, " sample_tree=", local_labels[0].is_visible_in_tree(), " outside=", hub.outside)
	var initial_texts: Array[String] = [local_labels[0].text, local_labels[1].text, local_labels[2].text]
	var count_before: int = hub.yard.get_child_count()
	var result: Dictionary = TanDangCaptionLayout.place(local_labels, local_anchors, viewport_rect, fixed)
	var placed: Array[Vector2] = [local_labels[0].position, local_labels[1].position, local_labels[2].position]
	var clean: bool = result["unresolved"] == 0 and _clean_with_reservations(local_labels, fixed, viewport_rect)
	print("HUB_STATION_GEOMETRY viewport=", viewport_rect, " house=", house_rect, " reserved=", fixed, " result=", result)
	for index: int in local_labels.size():
		print("HUB_CAPTION_GEOMETRY ", ids[index], " actor=", (local_labels[index].get_parent() as Node2D).get_global_transform_with_canvas() * Vector2.ZERO, " anchor=", local_anchors[index], " lane=", local_labels[index].position - local_anchors[index], " rect=", TanDangCaptionLayout._rect(local_labels[index]), " lines=", local_labels[index].get_line_count())
	_check(result["considered"] == 3 and clean, "Actual Hub house heading and all three authored-stop captions have a readable two-pixel gap")
	for tick: int in 40:
		TanDangCaptionLayout.place(local_labels, local_anchors, viewport_rect, fixed)
	_check([local_labels[0].position, local_labels[1].position, local_labels[2].position] == placed and hub.yard.get_child_count() == count_before and [local_labels[0].text, local_labels[1].text, local_labels[2].text] == initial_texts, "Actual-house fixture keeps genuine unacknowledged forage greeting and forty placements stable")
	# Crossing at existing Hub work coordinates forces the long Lâm greeting
	# against Dư's caption. Its nearest vertical escape crosses the actual
	# house sign, so a clean allocation must avoid both rendered objects.
	(local_labels[0].get_parent() as Node2D).position.x = 1120.0
	(local_labels[2].get_parent() as Node2D).position.x = 1260.0
	await _frames(2)
	for index: int in local_labels.size(): local_labels[index].position = local_anchors[index]
	var baseline_crossing: bool = TanDangCaptionLayout._rect(local_labels[0]).intersects(TanDangCaptionLayout._rect(local_labels[2]))
	local_labels[2].position = local_anchors[2] + Vector2(0, -80)
	var house_conflict: bool = TanDangCaptionLayout._rect(local_labels[2]).grow(TanDangCaptionLayout.GAP).intersects(house_rect)
	local_labels[2].position = local_anchors[2]
	var crossing: Dictionary = TanDangCaptionLayout.place(local_labels, local_anchors, viewport_rect, fixed)
	var crossing_placed: Array[Vector2] = [local_labels[0].position, local_labels[1].position, local_labels[2].position]
	var shifted: bool = false
	for index: int in local_labels.size(): shifted = shifted or local_labels[index].position != local_anchors[index]
	print("HUB_HOUSE_CROSSING baseline=", baseline_crossing, " blocked_up80=", house_conflict, " house=", house_rect, " result=", crossing, " lanes=", [crossing_placed[0] - local_anchors[0], crossing_placed[1] - local_anchors[1], crossing_placed[2] - local_anchors[2]])
	_check(baseline_crossing and house_conflict and crossing["considered"] == 3 and crossing["unresolved"] == 0 and shifted and _clean_with_reservations(local_labels, fixed, viewport_rect), "Actual three-resident crossing rejects a house-overlapping lane and keeps the genuine forage caption readable")
	for tick: int in 40: TanDangCaptionLayout.place(local_labels, local_anchors, viewport_rect, fixed)
	_check([local_labels[0].position, local_labels[1].position, local_labels[2].position] == crossing_placed and [local_labels[0].text, local_labels[1].text, local_labels[2].text] == initial_texts and hub.yard.get_child_count() == count_before, "Forty crowded Hub passes keep lane, original greeting and node count stable")
	for label: Label in local_labels:
		label.get_parent().queue_free()
	PlayerTravel.relocate(hub.player, player_before)
	product_camera.reset_smoothing()
	product_camera.force_update_scroll()
	await _frames(3)


func _clean_with_reservations(items: Array[Label], fixed: Array[Rect2], viewport_rect: Rect2) -> bool:
	for label: Label in items:
		var bounds: Rect2 = TanDangCaptionLayout._rect(label)
		if not viewport_rect.encloses(bounds): return false
		for obstacle: Rect2 in fixed:
			if bounds.grow(TanDangCaptionLayout.GAP).intersects(obstacle): return false
	for first: int in items.size():
		for second: int in range(first + 1, items.size()):
			if TanDangCaptionLayout._rect(items[first]).grow(TanDangCaptionLayout.GAP).intersects(TanDangCaptionLayout._rect(items[second])): return false
	return true


func _declared_positions() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	current_scene = arena
	camera = Camera2D.new()
	camera.position = Vector2(1200, 640)
	arena.add_child(camera)
	camera.enabled = true
	await _frames(2)
	# Stable order: Dư, Mộc, Lâm. These are authored Hub stop coordinates.
	_make_label(Vector2(1120, 640), Vector2(0, -108), Vector2(220, 72), _copy(TanDangLivingCatalog.DU, "Sửa đồ cũ"))
	_make_label(Vector2(1010, 640), Vector2(-120, -170), Vector2(240, 72), _copy(TanDangLivingCatalog.MOC, "Chỉnh lại đèn cổng"))
	_make_label(Vector2(1260, 640), Vector2(-220, -158), Vector2(220, 72), _copy(TanDangLivingCatalog.LAM, "Nhặt vật liệu"))
	await _frames(2)
	var control_du: Rect2 = Rect2(Vector2(1120, 532), Vector2(220, 72))
	var control_lam: Rect2 = Rect2(Vector2(1040, 482), Vector2(220, 72))
	var occupied_du: Rect2 = TanDangCaptionLayout._rect(labels[0])
	var occupied_lam: Rect2 = TanDangCaptionLayout._rect(labels[2])
	_check(control_du.intersects(control_lam) and not occupied_du.intersects(occupied_lam), "Authored 72 px boxes overlap while short occupied text does not")
	labels[1].hide()
	var short_pair: Dictionary = _place()
	_check(short_pair["considered"] == 2 and labels[0].position == anchors[0] and labels[2].position == anchors[2], "Short pair keeps authored anchors when only empty Label space overlaps")
	labels[1].show()
	var texts: Array[String] = [labels[0].text, labels[1].text, labels[2].text]
	var child_count: int = arena.get_child_count()
	var result: Dictionary = _place()
	_check(result["considered"] == 3 and result["unresolved"] == 0 and _separated(), "Three valid Hub work stops fit without caption overlap")
	var placed: Array[Vector2] = [labels[0].position, labels[1].position, labels[2].position]
	for tick: int in 40:
		_place()
	_check([labels[0].position, labels[1].position, labels[2].position] == placed, "Forty layout passes start at anchors and never accumulate drift or lane jitter")
	_check(arena.get_child_count() == child_count and [labels[0].text, labels[1].text, labels[2].text] == texts, "Layout creates no nodes and does not replace work or greeting words")
	var lam_body: Node2D = labels[2].get_parent() as Node2D
	lam_body.position.x = camera.position.x + root.get_visible_rect().size.x / (2.0 * camera.zoom.x) + 60.0
	labels[2].position = anchors[2]
	var partial_caption_visible: bool = TanDangCaptionLayout._rect(labels[2]).intersects(root.get_visible_rect())
	var offscreen: Dictionary = _place()
	_check(partial_caption_visible and offscreen["considered"] == 2 and labels[2].position == anchors[2], "Offscreen actor keeps its authored caption even when the caption edge remains visible")
	lam_body.position.x = 1260.0
	# Use the actual finite presentation copy. Its geometry may or may not
	# intersect at these declared positions; the assertion follows evidence.
	labels[1].hide()
	var living: TanDangLivingRuntime = TanDangLivingRuntime.new()
	labels[2].text = _copy(TanDangLivingCatalog.LAM, living._greeting_line(TanDangLivingCatalog.LAM, "forage_help"))
	living.free()
	await _frames(2)
	labels[2].position = anchors[2]
	var long_baseline: Rect2 = TanDangCaptionLayout._rect(labels[2])
	var actual_overlap: bool = long_baseline.intersects(TanDangCaptionLayout._rect(labels[0]))
	print("ACTUAL_FORAGE_GREETING_OCCUPIED_OVERLAP=%s lines=%d" % [actual_overlap, labels[2].get_line_count()])
	var long_result: Dictionary = _place()
	_check(long_result["unresolved"] == 0 and _separated(), "Actual forage greeting remains readable with its measured line height")
	if actual_overlap:
		_check(labels[2].position != anchors[2], "Actual overlapping greeting moves to a bounded lane")
	else:
		_check(labels[2].position == anchors[2], "Actual nonoverlapping greeting keeps its authored anchor")
	labels[2].text = _copy(TanDangLivingCatalog.LAM, "Trở về kể chuyện vật liệu")
	# At P03 Mộc is absent; Lâm can stand to the right of Dư on the real slope.
	labels[1].hide()
	(labels[0].get_parent() as Node2D).position = Vector2(1385, 1450)
	(labels[2].get_parent() as Node2D).position = Vector2(1450, 1450)
	camera.position = Vector2(1390, 1450)
	await _frames(2)
	var p03: Dictionary = _place()
	_check(p03["considered"] == 2 and p03["unresolved"] == 0 and _separated(), "Declared P03 crossing keeps both visible residents readable")
	# Camera zoom and a viewport edge are evaluated in canvas coordinates.
	camera.zoom = Vector2(1.4, 1.4)
	camera.position = Vector2(1280.0 + root.get_visible_rect().size.x / (2.0 * camera.zoom.x), 1450)
	await _frames(2)
	var edge: Dictionary = _place()
	_check(edge["unresolved"] == 0 and _separated(), "Zoomed camera moves clipped occupied text back into the viewport")
	var retained: Array[Label] = labels.duplicate()
	arena.queue_free()
	current_scene = null
	await _frames(5)
	_check(get_nodes_in_group(&"npc_pilot_actor").is_empty() and not is_instance_valid(retained[0]), "Fixture teardown retains no actor or caption node")


func _make_label(world: Vector2, anchor: Vector2, size: Vector2, copy: String) -> void:
	var actor: Node2D = Node2D.new()
	actor.position = world
	arena.add_child(actor)
	var label: Label = Label.new()
	label.position = anchor
	label.size = size
	label.text = copy
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 13)
	actor.add_child(label)
	labels.append(label)
	anchors.append(anchor)


func _copy(id: String, activity: String) -> String:
	return "%s · %s\n%s" % [NpcPilotCatalog.definition(id)["name"], CultivatorCatalog.definition(id)["stage_label"], activity]


func _place() -> Dictionary:
	return TanDangCaptionLayout.place(labels, anchors, root.get_visible_rect())


func _separated() -> bool:
	var visible: Array[Rect2] = []
	for label: Label in labels:
		if not is_instance_valid(label) or not label.is_visible_in_tree(): continue
		var rect: Rect2 = TanDangCaptionLayout._rect(label)
		if not root.get_visible_rect().encloses(rect): return false
		for prior: Rect2 in visible:
			if rect.grow(TanDangCaptionLayout.GAP).intersects(prior.grow(TanDangCaptionLayout.GAP)): return false
		visible.append(rect)
	return true


func _frames(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame


func _check(ok: bool, message: String) -> bool:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", message])
	return ok
