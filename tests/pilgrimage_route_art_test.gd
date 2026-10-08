extends SceneTree
## Two existing map skins: geometry, markers, gates and reversible visual ownership.
var checks: int = 0
var failures: int = 0
var geometry: Dictionary = {}
var baseline: Dictionary = {}
var evidence: String

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	evidence = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\", "/")
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
		if arg.begins_with("--geometry-baseline="):
			baseline = JSON.parse_string(FileAccess.get_file_as_string(arg.trim_prefix("--geometry-baseline=")))
	AudioServer.set_bus_mute(0, true)
	await _room(ExteriorRouteCatalog.MAIN, false)
	await _room(ExteriorRouteCatalog.TUNNEL, false)
	await _room(ExteriorRouteCatalog.TUNNEL, true)
	var p01 := ExteriorRoom.new()
	root.add_child(p01)
	_check(p01.configure(&"o01_p01", ExteriorRouteCatalog.MAIN, false), "Existing P01 still configures")
	_check(p01.has_node("PilgrimagePresentation") and not p01.has_node("PilgrimageRoutePresentation"), "P01 keeps its original presentation path")
	p01.queue_free()
	var p03 := ExteriorRoom.new()
	root.add_child(p03)
	_check(p03.configure(&"o01_p03", ExteriorRouteCatalog.MAIN, false) and not p03.has_node("PilgrimageRoutePresentation"), "Other map geometry/art stays outside the two-room scope")
	p03.queue_free()
	await _step(3)
	_check(not root.find_children("PilgrimageRoutePresentation", "Node", true, false).size(), "Map teardown releases the new room-owned art subtrees")
	var output := FileAccess.open(evidence + "/MAP_GEOMETRY_SNAPSHOT.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(geometry, "\t"))
	output.close()
	print("RESULT PilgrimageRouteArt checks=%d failures=%d hz=%d GPU_UNRUN" % [checks, failures, Engine.physics_ticks_per_second])
	await root.get_node("AudioManager").shutdown()
	quit(1 if failures else 0)

func _room(route: StringName, opened: bool) -> void:
	var room := ExteriorRoom.new()
	root.add_child(room)
	var key: String = str(route) + (":open" if opened else ":closed")
	_check(room.configure(&"o01_p02", route, opened), "Existing P02 geometry configures: " + key)
	await _step(2)
	geometry[key] = _geometry(room)
	if baseline.has(key):
		# Persisted JSON has numeric/text Variants rather than typed engine values.
		var persisted_current: Dictionary = JSON.parse_string(JSON.stringify(geometry[key]))
		_check(persisted_current == baseline[key], "Pre-patch surface/collider/anchor/interaction/marker snapshot is unchanged: " + key)
	var art: Node2D = room.get_node_or_null("PilgrimageRoutePresentation") as Node2D
	_check(art != null, "Painted presentation binds only the existing route: " + key)
	if art == null:
		room.queue_free()
		await _step(2)
		return
	var collision_before: Array[Dictionary] = PilgrimagePresentation.static_collision_snapshot(room)
	_check(collision_before == art.get("original_collisions") and room.anchors == art.get("original_anchors") and room.interactions == art.get("original_interactions"), "Attachment preserves collider resources/transforms and travel/interaction anchors: " + key)
	_check(art.find_children("*", "CollisionObject2D", true, false).is_empty() and art.find_children("*", "CollisionShape2D", true, false).is_empty() and art.find_children("*", "CollisionPolygon2D", true, false).is_empty(), "Art subtree creates no physics: " + key)
	_check(art.find_children("*", "PointLight2D", true, false).is_empty() and art.find_children("*", "AudioStreamPlayer2D", true, false).is_empty() and art.find_children("*", "PilgrimageAudio", true, false).is_empty(), "New route skin creates no light/audio/grounded-prop owner: " + key)
	var ground: Node2D = art.get("ground_layer") as Node2D
	var exact_top: Line2D = ground.get_node("ExactWalkableTop") as Line2D
	_check(exact_top.points == room.surface and not ground.find_children("*", "Polygon2D", true, false).is_empty(), "Painted cap follows the actual authored surface: " + key)
	_check(art.find_children("*", "Node", true, false).size() <= 90 and (art.get("lights") as Array).is_empty() and (art.get("grounded_contacts") as Array).is_empty(), "Asset/node allocation stays bounded without P01 hardcoded props: " + key)
	var markers_before: Array[Dictionary] = _markers(room)
	art.call("_process", 0.05)
	_check(_markers(room) == markers_before and PilgrimagePresentation.static_collision_snapshot(room) == collision_before, "Parallax leaves marker visibility/transforms and collision unchanged: " + key)
	if route == ExteriorRouteCatalog.MAIN:
		var rope_count: int = 0
		var post_count: int = 0
		for child: Node in room.get_children():
			if child is Line2D and child.points != room.surface:
				rope_count += 1
				_check(child.visible, "Existing bridge rope remains visible")
			if child is Polygon2D and child.z_index == 1:
				post_count += 1
				_check(child.visible, "Existing bridge post remains visible")
		_check(rope_count == 1 and post_count == 2, "Original fixed bridge keeps its rope and two posts")
	else:
		_check(room.gate_visual.visible == not opened and room.gate.collision_layer == (0 if opened else 1) and room.gate.collision_mask == (0 if opened else 1), "SC01 gate retains original visible/open/physics state")
		room.set_gate(not opened)
		_check(room.gate_visual.visible == opened and room.gate.collision_layer == (1 if opened else 0), "Existing gate state change stays readable under the skin")
		room.set_gate(opened)
	var hidden: Array = art.get("hidden_visuals").duplicate()
	art.queue_free()
	await _step(2)
	var restored: bool = true
	for record: Dictionary in hidden:
		var item: CanvasItem = (record["item"] as WeakRef).get_ref() as CanvasItem
		restored = restored and is_instance_valid(item) and item.visible == bool(record["visible"])
	_check(restored and _markers(room) == markers_before and PilgrimagePresentation.static_collision_snapshot(room) == collision_before, "Removing art restores every hidden visual and preserves room geometry/markers: " + key)
	room.queue_free()
	await _step(2)

func _geometry(room: ExteriorRoom) -> Dictionary:
	var colliders: Array[Dictionary] = []
	for body: Node in room.find_children("*", "StaticBody2D", true, false):
		var shapes: Array[Dictionary] = []
		for child: Node in body.get_children():
			if child is CollisionPolygon2D:
				shapes.append({"points": child.polygon, "transform": child.transform, "disabled": child.disabled, "one_way": child.one_way_collision})
		colliders.append({"transform": body.transform, "layer": body.collision_layer, "mask": body.collision_mask, "shapes": shapes})
	return {"surface": room.surface, "anchors": room.anchors, "interactions": room.interactions, "jumps": room.jumps, "bounds": room.bounds, "width": room.width, "min_y": room.min_y, "colliders": colliders, "markers": _markers(room)}

func _markers(room: ExteriorRoom) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for child: Node in room.get_children():
		if child is Label:
			records.append({"text": child.text, "transform": child.get_transform(), "visible": child.visible, "size": child.size, "mouse_filter": child.mouse_filter})
	return records

func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + message)
