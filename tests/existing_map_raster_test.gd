extends SceneTree
## Actual known room builders and a short Player motor walk. Art-only geometry,
## visibility and finite ownership checks; not natural/native map acceptance.

const RASTER = preload("res://scripts/presentation/existing_map_raster.gd")
var checks: int = 0
var failures: int = 0
var actor: Player
var current_fixture: Node2D


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	AudioServer.set_bus_mute(0, true)
	_check(RASTER.texture_for(&"unknown_room") == null and RASTER.resident_bank.is_empty(), "Unrecognised IDs cannot load an arbitrary texture or grow the resident bank")
	for key: StringName in RASTER.EXTERIOR_PATHS:
		_check(RASTER.texture_for(key) != null, "Actual imported exterior PNG is available: " + str(key))
	for key: StringName in RASTER.CAMPAIGN_PATHS:
		_check(RASTER.texture_for(key) != null, "Actual imported campaign PNG is available: " + str(key))
	if failures > 0:
		await root.get_node("AudioManager").shutdown()
		quit(1)
		return
	var resident_before: Dictionary = RASTER.resident_bank.duplicate()
	_check(resident_before.size() == RASTER.MAX_RESIDENT_TEXTURES, "Exactly eight whitelisted source textures are resident")
	actor = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	root.add_child(actor)
	actor.hurtbox.set_invulnerable(true)
	actor.energy.enabled = false
	for key: StringName in RASTER.EXTERIOR_PATHS:
		await _test_exterior(key)
	await _test_gate_and_existing_routes()
	actor.queue_free()
	actor = null
	await _step(3)
	await _test_campaign()
	_check(RASTER.resident_bank == resident_before and RASTER.texture_for(&"not_a_map") == null, "Repeated map/stage binding retains the same eight textures and cannot expand its cache")
	_check(root.find_children("ExistingMapRaster", "Node", true, false).is_empty() and get_nodes_in_group(&"spell_entities").is_empty(), "Final room/run teardown leaves no raster owner or gameplay spell entity")
	print("RESULT ExistingMapRaster checks=%d failures=%d hz=%d HEADLESS_BINDING_ONLY" % [checks, failures, Engine.physics_ticks_per_second])
	await root.get_node("AudioManager").shutdown()
	quit(1 if failures else 0)


func _test_exterior(key: StringName) -> void:
	var room := ExteriorRoom.new()
	room.position = Vector2(3500, 0)
	_check(room.configure(key, ExteriorRouteCatalog.MAIN, false), "Existing room layout configures without new route/content: " + str(key))
	var before_ready: Dictionary = _geometry(room)
	root.add_child(room)
	current_fixture = room
	await _step(2)
	var art: ExistingMapRaster = room.get_node_or_null("ExistingMapRaster") as ExistingMapRaster
	_check(art != null and art.sprite.texture == RASTER.texture_for(key), "Real ExteriorRoom configure hook attaches PNG before SceneTree and preserves it through ready: " + str(key))
	_check(_geometry(room) == before_ready, "SceneTree attachment preserves all collider IDs/shapes/transforms and geographic data: " + str(key))
	if art == null:
		room.queue_free()
		await _step(2)
		return
	art.clear()
	var collision_before: Dictionary = _geometry(room)
	var foreground_before: Array[Dictionary] = _foreground(room)
	var grounding_before: Array[Vector2] = _floor_rays(room)
	art = RASTER.attach_exterior(room)
	_check(_geometry(room) == collision_before and _foreground(room) == foreground_before, "Paint binding leaves colliders/lines/labels/landmark props visible and unchanged: " + str(key))
	_check(_covered(art, room.bounds) and art.image_key == key and art.owner_id == room.get_instance_id(), "Uniform cover crop stays inside the real PNG and exactly fills actual room bounds: " + str(key))
	_check(_quiet(art), "Raster owns one Sprite and no collider/light/audio/process loop: " + str(key))
	var sprite_id: int = art.sprite.get_instance_id()
	for repeat: int in 3:
		RASTER.attach_exterior(room)
	_check(art.sprite.get_instance_id() == sprite_id and art.get_child_count() == 1 and _geometry(room) == collision_before, "Repeated attach reuses one owner/Sprite rather than accumulating room art: " + str(key))
	_check(_floor_rays(room) == grounding_before and grounding_before.size() >= room.surface.size() - 1, "Actual physics floor queries retain every authored route segment after paint binding: " + str(key))
	PlayerTravel.relocate(actor, room.to_global(Vector2(90, room.floor_y(90))), PlayerTravel.Kind.INTRA_EXPEDITION)
	await _step(8)
	var start_x: float = actor.global_position.x
	Input.action_press(&"move_right")
	await _step(ceili(0.22 * Engine.physics_ticks_per_second))
	Input.action_release(&"move_right")
	await _step(8)
	var end_x: float = actor.global_position.x
	var east_grounded: bool = actor.motor.is_grounded() and absf(actor.global_position.y - room.to_global(Vector2(0, room.floor_y(actor.global_position.x - room.global_position.x))).y) < 2.0
	Input.action_press(&"move_left")
	await _step(ceili(0.22 * Engine.physics_ticks_per_second))
	Input.action_release(&"move_left")
	await _step(8)
	_check(end_x - start_x > 45.0 and actor.global_position.x < end_x - 45.0 and east_grounded and actor.motor.is_grounded(), "Actual Player input walks both directions on the existing dry west approach: " + str(key))
	_check(_geometry(room) == collision_before and _foreground(room) == foreground_before, "Short movement leaves route geometry, anchors and foreground markers unchanged: " + str(key))
	var hidden: Array[Dictionary] = art.hidden_visuals.duplicate()
	var owner_id: int = art.get_instance_id()
	room.remove_child(art)
	art.queue_free()
	await _step(2)
	var restored: bool = true
	for record: Dictionary in hidden:
		var item: CanvasItem = instance_from_id(int(record.id)) as CanvasItem
		restored = restored and item != null and item.visible == bool(record.visible)
	_check(restored and not is_instance_id_valid(owner_id) and not is_instance_id_valid(sprite_id) and _foreground(room) == foreground_before and _geometry(room) == collision_before, "Removing only raster restores original background visibility and releases both nodes: " + str(key))
	room.queue_free()
	await _step(3)
	current_fixture = null


func _test_gate_and_existing_routes() -> void:
	for route: StringName in [ExteriorRouteCatalog.MAIN, ExteriorRouteCatalog.TUNNEL]:
		var room := ExteriorRoom.new()
		room.configure(&"o01_p02", route, false)
		root.add_child(room)
		await _step(2)
		var before: Dictionary = _geometry(room)
		var markers: Array[Dictionary] = _foreground(room)
		_check(RASTER.attach_exterior(room) == null and _geometry(room) == before and _foreground(room) == markers, "P02's existing bridge/corridor art stays outside the six new PNG rooms: " + str(route))
		if route == ExteriorRouteCatalog.TUNNEL:
			_check(room.gate_visual.visible and room.gate.collision_layer == 1 and room.gate.collision_mask == 1, "Closed SC01 retains visible gate and blocking physics")
			room.set_gate(true)
			_check(not room.gate_visual.visible and room.gate.collision_layer == 0 and room.gate.collision_mask == 0, "Opening SC01 still controls its own visibility and physical layer/mask")
			room.set_gate(false)
			_check(room.gate_visual.visible and _geometry(room) == before, "Reclosing SC01 restores its original authored gate state")
		else:
			var ropes: int = 0
			for child: Node in room.get_children():
				if child is Line2D and child.points != room.surface:
					ropes += 1
					_check(child.visible, "Existing fixed bridge rope remains visible")
			_check(ropes == 1, "P02 retains one actual bridge rope")
		room.queue_free()
		await _step(3)


func _test_campaign() -> void:
	var profile := SanctuaryProfile.new()
	profile.save_path = "user://verification/existing_map_raster_%d.json" % Engine.physics_ticks_per_second
	var campaign := preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	campaign.profile = profile
	campaign.run_seed = 61008
	root.add_child(campaign)
	current_fixture = campaign
	campaign.survival.set_enabled(false)
	campaign.feedback.hit_stop_seconds = 0.0
	await _step(4)
	_check(not campaign.room.has_node("ExistingMapRaster"), "Stage1 retains its existing foyer background path")
	for stage: int in [2, 3]:
		_check(campaign.enter_stage(stage), "Existing campaign API loads stage " + str(stage))
		for enemy: Node in campaign.living_enemies():
			enemy.set_physics_process(false)
		await _step(3)
		var art: ExistingMapRaster = campaign.room.get_node_or_null("ExistingMapRaster") as ExistingMapRaster
		_check(art != null and art.image_key == RASTER.CAMPAIGN_KEYS[stage], "Real Slice rebuild hook binds the correct actual campaign PNG: " + str(stage))
		if art == null:
			continue
		art.clear()
		var geometry_before: Dictionary = _geometry(campaign.room)
		var foreground_before: Array[Dictionary] = _foreground(campaign.room)
		var seed_state: int = campaign.spawn_rng.state
		var legacy: Array[Node] = []
		for child: Node in campaign.presentation.atmosphere.room_art.find_children("*", "", true, false):
			if child is DungeonBackdrop:
				legacy.append(child)
		var foyer_before: Array[Dictionary] = _sprites(campaign.presentation.foyer_art)
		art = RASTER.attach_campaign(campaign.room, stage, campaign.presentation.atmosphere.room_art)
		_check(_geometry(campaign.room) == geometry_before and _foreground(campaign.room) == foreground_before and campaign.spawn_rng.state == seed_state, "Campaign background binding leaves physics/door/labels/traversal/RNG unchanged: " + str(stage))
		_check(_covered(art, RASTER.CAMPAIGN_BOUNDS) and _quiet(art), "Campaign PNG covers authored 1280x720 with one quiet Sprite: " + str(stage))
		var legacy_hidden: bool = not legacy.is_empty()
		for child: Node in legacy:
			legacy_hidden = legacy_hidden and not child.visible
		_check(legacy_hidden and art.hidden_visuals.size() == legacy.size(), "Only legacy DungeonBackdrop is hidden under atmosphere: " + str(stage))
		_check(_sprites(campaign.presentation.foyer_art) == foyer_before and campaign.presentation.foyer_art.visible, "Existing FoyerArt textures, transforms and individual visibility remain unchanged: " + str(stage))
		var door_visibility: bool = campaign.room.door.visible
		campaign.room.set_locked(not campaign.room.locked)
		await _step(2)
		_check(campaign.room.door.visible != door_visibility and campaign.room.door_shape.disabled == not campaign.room.locked, "Stage door still toggles its own marker and collider independently of paint: " + str(stage))
		art.clear()
		var restored: bool = true
		for child: Node in legacy:
			restored = restored and child.visible
		_check(restored and not art.sprite.visible and art.sprite.texture == null and art.owner_id == 0, "Explicit campaign clear restores old backdrop and drops Sprite texture/owner references: " + str(stage))
		RASTER.attach_campaign(campaign.room, stage, campaign.presentation.atmosphere.room_art)
	var art_ids: Array[int] = []
	for child: Node in campaign.find_children("ExistingMapRaster", "Node", true, false):
		art_ids.append(child.get_instance_id())
	campaign.queue_free()
	await _step(5)
	var released: bool = true
	for item_id: int in art_ids:
		released = released and not is_instance_id_valid(item_id)
	_check(released, "Whole campaign teardown releases room-owned raster nodes")
	current_fixture = null


func _covered(art: ExistingMapRaster, rectangle: Rect2) -> bool:
	if art == null or art.sprite == null or art.sprite.texture == null:
		return false
	var paint: Sprite2D = art.sprite
	var actual := Rect2(paint.position - paint.region_rect.size * paint.scale * 0.5, paint.region_rect.size * paint.scale)
	return art.z_index <= -30 and paint.visible and paint.region_enabled and paint.region_filter_clip_enabled and paint.scale.x > 0.0 and is_equal_approx(paint.scale.x, paint.scale.y) and actual.position.distance_to(rectangle.position) < 0.01 and actual.size.distance_to(rectangle.size) < 0.01 and Rect2(Vector2.ZERO, Vector2(paint.texture.get_width(), paint.texture.get_height())).grow(0.01).encloses(paint.region_rect)


func _quiet(art: ExistingMapRaster) -> bool:
	return art != null and art.get_child_count() == 1 and art.get_child(0) is Sprite2D and not art.is_processing() and not art.is_physics_processing() and art.find_children("*", "CollisionObject2D", true, false).is_empty() and art.find_children("*", "PointLight2D", true, false).is_empty() and art.find_children("*", "AudioStreamPlayer2D", true, false).is_empty()


func _floor_rays(room: ExteriorRoom) -> Array[Vector2]:
	var contacts: Array[Vector2] = []
	for index: int in room.surface.size() - 1:
		var x: float = (room.surface[index].x + room.surface[index + 1].x) * 0.5
		var at: Vector2 = room.to_global(Vector2(x, room.floor_y(x)))
		var query := PhysicsRayQueryParameters2D.create(at - Vector2(0, 30), at + Vector2(0, 80), 1)
		var hit: Dictionary = room.get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			contacts.append(hit.position)
	return contacts


func _geometry(room: Node2D) -> Dictionary:
	var bodies: Array[Dictionary] = []
	for child: Node in room.find_children("*", "CollisionObject2D", true, false):
		var shapes: Array[Dictionary] = []
		for shape: Node in child.get_children():
			if shape is CollisionShape2D:
				shapes.append({"id": shape.get_instance_id(), "resource_id": shape.shape.get_instance_id() if shape.shape != null else 0, "content": _shape_content(shape.shape), "transform": shape.transform, "disabled": shape.disabled, "one_way": shape.one_way_collision, "margin": shape.one_way_collision_margin})
			elif shape is CollisionPolygon2D:
				shapes.append({"id": shape.get_instance_id(), "polygon": shape.polygon.duplicate(), "transform": shape.transform, "disabled": shape.disabled, "one_way": shape.one_way_collision, "margin": shape.one_way_collision_margin})
		bodies.append({"id": child.get_instance_id(), "transform": child.transform, "global": child.global_transform, "layer": child.collision_layer, "mask": child.collision_mask, "shapes": shapes})
	var geography: Dictionary = {"transform": room.transform, "bodies": bodies}
	if room is ExteriorRoom:
		geography.merge({"surface": room.surface.duplicate(), "anchors": room.anchors.duplicate(), "interactions": room.interactions.duplicate(), "jumps": room.jumps.duplicate(true), "width": room.width, "bounds": room.bounds})
	elif room is DungeonRoom:
		geography.merge({"traversal": room.traversal_points.duplicate()})
	return geography


func _foreground(room: Node2D) -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for child: Node in room.get_children():
		if child is ExistingMapRaster or child is Polygon2D and child.z_index in [-20, -18]:
			continue
		if child is CanvasItem:
			var record: Dictionary = {"id": child.get_instance_id(), "visible": child.visible, "transform": child.get_transform(), "z": child.z_index}
			if child is Label: record["text"] = child.text
			if child is Line2D: record.merge({"points": child.points.duplicate(), "width": child.width})
			if child is Polygon2D: record["polygon"] = child.polygon.duplicate()
			records.append(record)
		if child is StaticBody2D:
			for paint: Node in child.get_children():
				if paint is Polygon2D:
					records.append({"id": paint.get_instance_id(), "visible": paint.visible, "transform": paint.transform, "z": paint.z_index})
	return records


func _shape_content(shape: Shape2D) -> Dictionary:
	if shape is RectangleShape2D: return {"size": shape.size}
	if shape is CircleShape2D: return {"radius": shape.radius}
	if shape is CapsuleShape2D: return {"radius": shape.radius, "height": shape.height}
	if shape is SegmentShape2D: return {"a": shape.a, "b": shape.b}
	if shape is ConvexPolygonShape2D: return {"points": shape.points.duplicate()}
	return {}


func _sprites(owner: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for child: Node in owner.find_children("*", "Sprite2D", true, false):
		result.append({"id": child.get_instance_id(), "texture_id": child.texture.get_instance_id() if child.texture != null else 0, "visible": child.visible, "transform": child.transform, "region": child.region_rect})
	return result


func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame


func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok:
		failures += 1
	print(("PASS: " if ok else "FAIL: ") + text)
