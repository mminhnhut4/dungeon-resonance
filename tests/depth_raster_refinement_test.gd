extends "res://tests/depth_actor_test.gd"
## Art-only regression. Pixel padding and bindings do not certify native animation.

var seen_sheets: Dictionary[String, bool] = {}

func _enemy(floor_id: int) -> void:
	var enemy: BaseEnemy = await _fresh_enemy(floor_id)
	var art: Node2D = enemy.visual
	_check(art.snapshot().raster_ready and art.snapshot().frames == 10 and art.snapshot().walk_frames == 4, "Floor%d binds six primary and four gait raster poses" % floor_id)
	var collider: CollisionShape2D = enemy.get_node("BodyCollision")
	var shape_id: int = collider.shape.get_instance_id()
	var transform: Transform2D = collider.transform
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(art.META_PATH))
	var pivots: Array = metadata.enemy.get("row_pivots", [])
	var walk_pivots: Array = metadata.enemy.get("walk_row_pivots", [])
	var primary_ok: bool = pivots.size() > floor_id - 1 and pivots[floor_id - 1].size() == 6
	var gait_ok: bool = walk_pivots.size() > floor_id - 1 and walk_pivots[floor_id - 1].size() == 4
	_check(primary_ok and gait_ok and metadata.enemy.get("require_authored_pivots", false), "Floor%d requires semantic primary and gait pivots instead of a lowest weapon tip" % floor_id)
	_entry_padding(metadata.enemy, false)
	_entry_padding(metadata.enemy, true)
	if primary_ok and gait_ok:
		for index: int in 10:
			var expected: Array = pivots[floor_id - 1][index] if index < 6 else walk_pivots[floor_id - 1][index - 6]
			_check(art._pivots[index] == Vector2(float(expected[0]), float(expected[1])), "Floor%d pose%d reads its authored semantic pivot" % [floor_id, index])
	enemy.hurtbox.take_damage(_event(enemy, 1.0))
	_check(art.snapshot().clip == &"hurt" and art.snapshot().frame == 5 and art.snapshot().foot.is_equal_approx(enemy.global_position), "Floor%d real hurt seeks authored frame5 at the physical root" % floor_id)
	_check(collider.shape.get_instance_id() == shape_id and collider.transform == transform, "Floor%d art refinement keeps the collision resource and transform" % floor_id)

func _boss() -> void:
	var boss: BossGolem = await _fresh_boss(Vector2(600, 640))
	var art: Node2D = boss.presentation
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DepthEnemyArt.META_PATH))
	var entry: Dictionary = metadata.boss
	_entry_padding(entry, false)
	_entry_padding(entry, true)
	var pivots: Array = entry.get("pivots", [])
	var gait: Array = entry.get("walk_pivots", [])
	_check(art.snapshot().raster_ready and art.snapshot().primary_frames == 12 and art.snapshot().frames == 16 and pivots.size() == 12 and gait.size() == 4, "Boss binds twelve authored primary poses plus four gait frames")
	if pivots.size() == 12 and gait.size() == 4:
		for index: int in 16:
			var expected: Array = pivots[index] if index < 12 else gait[index - 12]
			_check(art._pivots[index] == Vector2(float(expected[0]), float(expected[1])), "Boss pose%d reads its authored boot pivot" % index)
	var collider: CollisionShape2D = boss.get_node("Body")
	var shape_id: int = collider.shape.get_instance_id()
	var transform: Transform2D = collider.transform
	boss.fsm.transition_to(&"sweep")
	_check(art.snapshot().clip == &"telegraph" and art.snapshot().frame == 2, "Phase1 thrust tell binds pose2")
	boss.state_time = boss.tell_seconds() + 0.05
	art.refresh()
	_check(art.snapshot().clip == &"attack" and art.snapshot().frame == 3, "Phase1 thrust body binds pose3")
	boss.hurtbox.take_damage(_event(boss, 260.0))
	boss.flash = 0.0
	boss.fsm.transition_to(&"sweep")
	_check(art.snapshot().clip == &"telegraph_sweep" and art.snapshot().frame == 8, "Phase2 low sweep tell binds distinct pose8")
	boss.state_time = boss.tell_seconds() + 0.05
	art.refresh()
	_check(art.snapshot().clip == &"attack_sweep" and art.snapshot().frame == 9, "Phase2 actual low sweep binds pose9 instead of thrust pose3")
	boss.state_time = boss.tell_seconds() + boss.active_seconds() + 0.10
	art.refresh()
	_check(art.snapshot().clip == &"recover_sweep" and art.snapshot().frame == 10, "Phase2 sweep recovery binds pose10")
	# Pixel traversal is deliberately synchronous; flush accumulated headless
	# physics before sampling the existing short local hitstop clock.
	await _step(4)
	feedback.hit_stop_seconds = 0.08
	boss.ai_enabled = true
	boss.hurtbox.take_damage(_event(boss, 1.0))
	var frozen: Dictionary = art.snapshot()
	await _step(2)
	print("DEPTH_REFINE_HURT_TRACE: immediate=%s resumed=%s freeze=%s hp=%s" % [frozen, art.snapshot(), feedback.is_frozen(), boss.health.current_health])
	_check(frozen.clip == &"hurt_phase2" and frozen.frame == 11 and art.snapshot() == frozen and feedback.is_frozen(), "Phase2 real incoming hit binds pose11 immediately and holds during hitstop")
	_check(collider.shape.get_instance_id() == shape_id and collider.transform == transform and art.snapshot().foot.is_equal_approx(boss.global_position), "Boss refinement leaves collision and physical root unchanged")
	feedback.reset_feedback()
	feedback.hit_stop_seconds = 0.0
	await _first_outgoing(1)
	await _first_outgoing(2)

func _first_outgoing(phase_id: int) -> void:
	var boss: BossGolem = await _fresh_boss(Vector2(600, 640))
	if phase_id == 2:
		boss.hurtbox.take_damage(_event(boss, 260.0))
		boss.flash = 0.0
	feedback.reset_feedback()
	feedback.hit_stop_seconds = 0.08
	boss.ai_enabled = true
	boss.fsm.transition_to(&"sweep")
	var accepted: Array[Dictionary] = []
	hero.hurtbox.hit_resolved.connect(func(event: DamageEvent, result: DamageResult) -> void:
		if event.source_id == boss.get_instance_id() and not result.blocked and result.actual_damage > 0.0:
			accepted.append({"damage": result.actual_damage, "time": boss.state_time})
	, CONNECT_ONE_SHOT)
	var samples: Array[Dictionary] = []
	boss.attack_hitbox.contact_detected.connect(func(_target: Hurtbox, _attack: AttackSnapshot) -> void:
		samples.append({"art": boss.presentation.snapshot(), "frozen": feedback.is_frozen(), "active": boss.attack_hitbox.active})
	, CONNECT_ONE_SHOT)
	for tick: int in ceili(1.5 * Engine.physics_ticks_per_second):
		await _step(1)
		if not samples.is_empty(): break
	var expected: int = 9 if phase_id == 2 else 3
	_check(accepted.size() == 1 and samples.size() == 1 and accepted[0].damage > 0 and samples[0].frozen and samples[0].active and samples[0].art.frame == expected, "Phase%d first real outgoing Player damage seeks active body pose%d before hitstop" % [phase_id, expected])
	feedback.reset_feedback()
	feedback.hit_stop_seconds = 0.0

func _lifetimes() -> void:
	for floor_id: int in range(1, 5):
		var enemy: BaseEnemy = await _fresh_enemy(floor_id)
		_check(enemy.visual.snapshot().frames == 10, "Floor%d immutable raster bank survives prior teardown" % floor_id)
	var boss: BossGolem = await _fresh_boss(Vector2(800, 640))
	_check(boss.presentation.snapshot().frames == 16, "Boss immutable primary and gait bank survive prior teardown")

func _entry_padding(entry: Dictionary, walk: bool) -> void:
	var frame_row_key: String = "walk_row_frames" if walk else "row_frames"
	var frame_flat_key: String = "walk_frames" if walk else "frames"
	if entry.has(frame_row_key) or entry.has(frame_flat_key):
		var groups: Array = entry.get(frame_row_key, [entry.get(frame_flat_key, [])])
		for frames: Array in groups:
			for frame: Dictionary in frames: _frame_padding(frame)
		return
	var row_key: String = "walk_row_sheets" if walk else "row_sheets"
	var flat_key: String = "walk_sheets" if walk else "sheets"
	var definitions: Array = entry.get(row_key, entry.get(flat_key, []))
	if definitions.is_empty():
		_sheet_padding(entry["walk_path" if walk else "path"], int(entry["walk_columns" if walk else "columns"]), int(entry["walk_rows" if walk else "rows"]))
	else:
		for definition: Dictionary in definitions:
			_sheet_padding(definition.path, int(definition.columns), int(definition.get("rows", 1)), definition.get("regions", []))

func _frame_padding(frame: Dictionary) -> void:
	var key: String = frame.path + JSON.stringify(frame.region)
	if seen_sheets.has(key): return
	seen_sheets[key] = true
	var texture: Texture2D = load(frame.path) as Texture2D
	var source: Image = texture.get_image()
	if source.is_compressed(): source.decompress()
	var rect: Array = frame.region
	var region := Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))
	var integer_pixels: bool = true
	for index: int in 4:
		integer_pixels = integer_pixels and float(rect[index]) == float(int(rect[index]))
	_check(integer_pixels and region.position.x >= 0 and region.position.y >= 0 and region.end.x <= source.get_width() and region.end.y <= source.get_height(), "%s authored frame stays on whole bounded source pixels" % frame.path.get_file())
	var expected: Array = frame.solid_bounds
	var body_rect := Rect2i(int(expected[0]), int(expected[1]), int(expected[2]) - int(expected[0]), int(expected[3]) - int(expected[1]))
	var cell: Image = source.get_region(region)
	var solid_pixels: int = 0
	for y: int in cell.get_height():
		for x: int in cell.get_width():
			if cell.get_pixel(x, y).a >= 8.0 / 255.0: solid_pixels += 1
	_check(region.encloses(body_rect) and solid_pixels == int(frame.solid_pixels) and solid_pixels > 500, "%s frame retains its recorded full opaque pose without extra neighbor pixels" % frame.path.get_file())
	var padding: Array = frame.get("margin", [0, 0, 0, 0])
	var margin := Rect2i(int(padding[0]), int(padding[1]), int(padding[2]), int(padding[3]))
	# AtlasTexture.get_image() intentionally excludes draw margins. Measure the
	# documented final draw canvas without changing any source PNG pixels.
	var drawn: Image = Image.create(region.size.x + margin.size.x, region.size.y + margin.size.y, false, Image.FORMAT_RGBA8)
	drawn.blit_rect(cell, Rect2i(Vector2i.ZERO, region.size), margin.position)
	var bounds: Rect2i = drawn.get_used_rect()
	var edge_pixels: int = 0
	for x: int in drawn.get_width():
		if drawn.get_pixel(x, 0).a > 0.0: edge_pixels += 1
		if drawn.get_pixel(x, drawn.get_height() - 1).a > 0.0: edge_pixels += 1
	for y: int in drawn.get_height():
		if drawn.get_pixel(0, y).a > 0.0: edge_pixels += 1
		if drawn.get_pixel(drawn.get_width() - 1, y).a > 0.0: edge_pixels += 1
	_check(edge_pixels == 0 and bounds.position.x >= 4 and bounds.position.y >= 4 and bounds.end.x <= drawn.get_width() - 4 and bounds.end.y <= drawn.get_height() - 4, "%s final Atlas draw retains alpha-clear padding without clipping the source pose" % frame.path.get_file())

func _sheet_padding(path: String, columns: int, rows: int, regions: Array = []) -> void:
	var key: String = path + JSON.stringify(regions)
	if seen_sheets.has(key): return
	seen_sheets[key] = true
	var texture: Texture2D = load(path) as Texture2D
	var image: Image = texture.get_image()
	if image.is_compressed(): image.decompress()
	var width: int = image.get_width() / columns
	var height: int = image.get_height() / rows
	_check(not regions.is_empty() or (image.get_width() % columns == 0 and image.get_height() % rows == 0), "%s uses explicit safe regions or integer exact cell dimensions" % path.get_file())
	for index: int in (regions.size() if not regions.is_empty() else columns * rows):
		var region := Rect2i(Vector2i(index % columns * width, index / columns * height), Vector2i(width, height))
		if not regions.is_empty():
			var rect: Array = regions[index]
			region = Rect2i(int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3]))
			_check(rect == [region.position.x, region.position.y, region.size.x, region.size.y], "%s frame%d atlas region lands on whole source pixels" % [path.get_file(), index])
		var cell: Image = image.get_region(region)
		width = cell.get_width()
		height = cell.get_height()
		var edge_pixels: int = 0
		for x: int in width:
			if cell.get_pixel(x, 0).a > 0.0: edge_pixels += 1
			if cell.get_pixel(x, height - 1).a > 0.0: edge_pixels += 1
		for y: int in height:
			if cell.get_pixel(0, y).a > 0.0: edge_pixels += 1
			if cell.get_pixel(width - 1, y).a > 0.0: edge_pixels += 1
		var bounds: Rect2i = cell.get_used_rect()
		_check(edge_pixels == 0 and bounds.size.x > 0 and bounds.size.y > 0 and bounds.position.x >= 4 and bounds.position.y >= 4 and bounds.end.x <= width - 4 and bounds.end.y <= height - 4, "%s cell%d has an alpha-clear border, padded nonempty pose, and no edge clipping (edge pixels=%d)" % [path.get_file(), index, edge_pixels])
