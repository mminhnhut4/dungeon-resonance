extends SceneTree
## Art adapter gates: atlas crops, immutable room physics, bounds and teardown.

const ART_SCRIPT: Script = preload("res://scripts/presentation/foyer_art.gd")
var world: Node2D
var room: DungeonRoom
var art: Node2D
var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	world = Node2D.new()
	root.add_child(world)
	current_scene = world
	room = DungeonRoom.new()
	world.add_child(room)
	await _step(2)
	var colliders_before: Dictionary = _collision_snapshot()
	art = ART_SCRIPT.new()
	world.add_child(art)
	art.initialize(world)
	print("FOYER ART TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	_check(art.platform_sprites.is_empty() and room.architecture != null, "Architectural surfaces retain their dedicated stone skin instead of legacy floating jade slabs")
	_check(art.lights.size() == 2 and art.lights.size() <= ART_SCRIPT.MAX_LIGHTS, "Door columns respect the unchanged static eight-light cap")
	_check(art.floor_sprites.size() == 12, "The original full-width floor is covered by twelve atlas sprites")
	_check(_collision_snapshot() == colliders_before, "Art installation leaves every shape Resource, mask, transform and disable flag unchanged")
	var source_size := Vector2(1248, 832)
	var regions: Array[AtlasTexture] = [ART_SCRIPT.JADE_A, ART_SCRIPT.JADE_B, ART_SCRIPT.JADE_C, ART_SCRIPT.FLOOR_STONE, ART_SCRIPT.CHAINED_COLUMN]
	for region: AtlasTexture in regions:
		_check(Rect2(Vector2.ZERO, source_size).encloses(region.region) and region.filter_clip, "Atlas crop %s stays within the original sheet and clips filtering" % region.resource_path.get_file())
	_check(regions[0].atlas == regions[1].atlas and regions[1].atlas == regions[4].atlas, "All atlas crops share the unchanged source texture")
	for index: int in art.platform_sprites.size():
		var sprite: Sprite2D = art.platform_sprites[index]
		var expected: Vector2 = ART_SCRIPT.PLATFORM_CENTERS[index] - ART_SCRIPT.PLATFORM_SIZES[index] * 0.5
		# Node discovery order is not the authoring order; find the corresponding top.
		var has_aligned_top: bool = false
		for spec: int in ART_SCRIPT.PLATFORM_CENTERS.size():
			expected = ART_SCRIPT.PLATFORM_CENTERS[spec] - ART_SCRIPT.PLATFORM_SIZES[spec] * 0.5
			if sprite.global_position.is_equal_approx(expected):
				has_aligned_top = true
		_check(has_aligned_top and sprite.texture is AtlasTexture, "Visible jade slab %d keeps the actual collision top" % index)
	_check(art.columns.size() == 2 and not art.columns[0].flip_h and art.columns[1].flip_h, "Door columns use a shared crop mirrored symmetrically")
	var left: Sprite2D = art.columns[0]
	var right: Sprite2D = art.columns[1]
	var left_center: float = left.global_position.x + left.texture.get_width() * left.scale.x * 0.5
	var right_center: float = right.global_position.x + right.texture.get_width() * right.scale.x * 0.5
	_check(is_equal_approx((left_center + right_center) * 0.5, 1190.0), "Two columns flank the locked door center at 1190")
	_check(right.global_position.x + right.texture.get_width() * right.scale.x <= 1264.0, "Right column stays inside the room wall rather than outside the viewport")
	_check(room.door.visible and room.locked and not room.door_shape.disabled, "Visual columns do not unlock or hide the original door")
	for id: int in art.skinned_bodies:
		var body: StaticBody2D = instance_from_id(id) as StaticBody2D
		var hidden: bool = false
		for child: Node in body.get_children():
			if child is Polygon2D:
				hidden = hidden or not child.visible
		_check(hidden, "Only the placeholder Polygon2D is hidden on skinned body %d" % id)
	art.rebuild(world)
	await _step(3)
	_check(art.platform_sprites.is_empty() and art.lights.size() == 2 and _collision_snapshot() == colliders_before, "Rebuilding art respects architecture ownership without accumulating lights or changing physics")
	art.clear()
	await _step(3)
	var all_visible: bool = true
	for body: Node in room.find_children("*", "StaticBody2D", true, false):
		if body.has_meta(&"dungeon_architectural_surface"): continue
		for child: Node in body.get_children():
			if child is Polygon2D:
				all_visible = all_visible and child.visible
	_check(all_visible and art.lights.is_empty(), "Removing the art restores existing placeholder visuals and releases lights")
	art.rebuild(world)
	var light_ids: Array[int] = []
	for light: PointLight2D in art.lights:
		light_ids.append(light.get_instance_id())
	world.queue_free()
	await _step(4)
	var released: bool = true
	for id: int in light_ids:
		released = released and not is_instance_id_valid(id)
	_check(released, "Room teardown releases every jade light with its owner")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _collision_snapshot() -> Dictionary:
	var result: Dictionary = {}
	for body: Node in room.find_children("*", "StaticBody2D", true, false):
		var values: Array = [body.collision_layer, body.collision_mask, body.transform]
		for child: Node in body.get_children():
			if child is CollisionShape2D:
				values.append([child.shape.get_instance_id(), child.shape.size if child.shape is RectangleShape2D else Vector2.ZERO, child.disabled, child.transform, child.one_way_collision, child.one_way_collision_margin])
		result[body.get_instance_id()] = values
	return result


func _step(frames: int) -> void:
	for frame: int in frames:
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])
