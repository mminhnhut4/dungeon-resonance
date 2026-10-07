extends SceneTree
## Checks the actual P01 attachment against its pre-presentation physics state.
var checks: int = 0
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var flow := preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/pilgrimage_art_%d.json" % Time.get_ticks_usec()
	root.add_child(flow)
	current_scene = flow
	await _step(12)
	var world := flow.active_scene as ExteriorHub
	var actor: Player = world.player
	var inventory: GearInventory = world.gear.inventory
	var uids: Array = inventory.items.keys()
	actor.health.current_health = 37
	actor.energy.current = 41
	actor.energy.regeneration_delay = 10000
	var weak_rooms: Array[WeakRef] = []
	var first_node_count: int = 0
	for iteration: int in 6:
		_check(world.enter_exterior(&"o01_p01"),"Actual main-session P01 entry")
		await _step(8)
		var room: ExteriorRoom = world.exterior
		weak_rooms.append(weakref(room))
		var art: PilgrimagePresentation = room.get_node("PilgrimagePresentation") as PilgrimagePresentation
		_check(art != null and art.pack != null,"P01 attaches room-owned art through real room loader")
		_check(PilgrimagePresentation.static_collision_snapshot(room) == art.original_collisions,"Presentation preserves every body layer/mask/transform/polygon/one-way/disabled property")
		_check(room.anchors == art.original_anchors and room.interactions == art.original_interactions,"Presentation cannot move geographic anchors or interaction points")
		_check(art.find_children("*","CollisionObject2D",true,false).is_empty() and art.find_children("*","CollisionShape2D",true,false).is_empty() and art.find_children("*","CollisionPolygon2D",true,false).is_empty(),"Art subtree contains no physics objects/shapes")
		_check(art.lights.size() <= PilgrimagePresentation.MAX_LIGHTS and art.lights.size() == 2,"Warm-light budget is finite")
		_check(art.far_layer.z_index < art.middle_layer.z_index and art.middle_layer.z_index < art.ground_layer.z_index and art.prop_layer.z_index < 0,"Background/props stay behind actor and readable ground edge")
		_check(art.trees.size() == 1 and art.grounded_contacts.size() == 1,"P01 uses one accent pine, with an open plateau rather than repeated silhouettes")
		var contact_record: Dictionary = art.grounded_contacts[0]
		var pine: Node2D = contact_record["root"]
		var pine_sprite: Sprite2D = contact_record["sprite"]
		var contacts_grounded: bool = true
		for point: Vector2 in contact_record["profile"]:
			var rendered_contact: Vector2 = room.to_local(pine_sprite.to_global(point-contact_record["pivot"]))
			var burial: float = rendered_contact.y-room.floor_y(rendered_contact.x)
			contacts_grounded = contacts_grounded and burial >= -0.5 and burial < 45.0
		_check(contacts_grounded and absf(room.floor_y(pine.position.x-60)-room.floor_y(pine.position.x+60)) > 10,"Measured solid tree-foot samples meet the actual sloped terrain, independent of transparent margins")
		var node_count: int = art.find_children("*","Node",true,false).size()
		if iteration == 0: first_node_count = node_count
		_check(node_count == first_node_count and node_count < 400,"Repeated P01 entry has a bounded stable art node count")
		var far_position: Vector2 = art.far_layer.position
		PlayerTravel.relocate(actor,ExteriorHub.ORIGIN+Vector2(1400,room.floor_y(1400)))
		await _step(8)
		_check(actor.motor.is_grounded() and art.far_layer.position != far_position,"Camera-driven parallax works on actual actor relocation; floor remains grounded")
		_check(PilgrimagePresentation.static_collision_snapshot(room) == art.original_collisions,"Sway/light/parallax updates preserve collision geometry")
		_check(world.player == actor and world.gear.inventory == inventory and inventory.items.keys() == uids and actor.health.current_health == 37 and actor.energy.current == 41,"Art/travel retains one actor/UID ledger and HP/energy")
		_check(world.enter_exterior(&"o01_p02"),"Presentation room can unload into unchanged adjacent room")
		await _step(8)
		_check(weak_rooms[-1].get_ref() == null,"Old P01 room including art releases on travel")
		_check(not world.exterior.has_node("PilgrimagePresentation"),"First visual slice does not silently decorate P02")
	_check(world.return_to_hub(),"Art roundtrips into original hub")
	await _step(8)
	_check(world.player == actor and TimeScaleClaims.owner_count(self) == 0,"Roundtrip has no duplicate actor or modal ownership")
	flow.queue_free()
	await _step(8)
	for weak: WeakRef in weak_rooms: _check(weak.get_ref() == null,"Every old presentation room is released")
	print("RESULT PilgrimagePresentation %d checks, %d failures; physics_hz=%d; art_nodes=%d" % [checks,failures,Engine.physics_ticks_per_second,first_node_count])
	quit(0 if failures == 0 else 1)

func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _check(passed: bool, message: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: "+message)
