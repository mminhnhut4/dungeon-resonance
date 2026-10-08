class_name DepthEnemyArt
extends WorldEnemyVisual
## Manual raster seek from actor clocks. No animation track owns hitboxes.

const META_PATH: String = "res://assets/sprites/depth/depth_actors.json"
static var _sheet_bank: Dictionary = {}
var raster_ready: bool = false
var selected_clip: StringName = &"idle"
var selected_frame: int = 0
var selected_progress: float = 0.0
var _frames: Array[AtlasTexture] = []
var _pivots: Array[Vector2] = []
var _clips: Dictionary = {}
var _world_scale: float = 1.0
var frame_scales: Array[float] = []
var primary_frames: int = 0
var walk_frames: int = 0
var _last_foot: Vector2
var _walk_distance: float = 0.0
var _source_faces_left: bool = false
var _last_sample: Vector2 = Vector2(-1, -1)
var tint: Color = Color.WHITE

func bind(target: BaseEnemy) -> void:
	actor = target
	process_physics_priority = 15
	motion = Node2D.new()
	motion.name = "FootPivot"
	add_child(motion)
	sprite = Sprite2D.new()
	sprite.name = "DepthRasterSprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	motion.add_child(sprite)
	_material = ShaderMaterial.new()
	_material.shader = FLASH
	sprite.material = _material
	var floor_id: int = int(actor.get("depth_floor"))
	tint = [Color(0.90, 0.90, 0.70), Color(0.46, 1, 0.58), Color(0.48, 0.86, 1), Color(1, 0.47, 0.20)][floor_id - 1]
	raster_ready = configure_raster("enemy", floor_id - 1, actor.definition.visual_height)
	if not raster_ready:
		var old_id: String = ["guard", "bat", "wraith", "champion"][floor_id - 1]
		geometry = _configure_sprite(load("res://assets/sprites/enemies/regions/world_%s.tres" % old_id) as Texture2D, actor.definition.visual_height)
	shadow = ActorShadow.new()
	add_child(shadow)
	shadow.bind(actor, Vector2.ZERO, actor.definition.body_size.x + 8, 6, actor.combat_feedback)
	_last_foot = actor.global_position
	actor.state_machine.state_changed.connect(_depth_state_changed)
	actor.hurtbox.hit_resolved.connect(_depth_hit)
	seek_actor(true)

func configure_raster(section: String, row: int, height: float) -> bool:
	if not FileAccess.file_exists(META_PATH): return false
	var metadata: Variant = JSON.parse_string(FileAccess.get_file_as_string(META_PATH))
	if not metadata is Dictionary or not metadata.has(section): return false
	var entry: Dictionary = metadata[section]
	if entry.has("sheets") or entry.has("row_sheets") or entry.has("frames") or entry.has("row_frames"):
		return _configure_multi_sheet(entry, row, height)
	var path: String = entry.get("path", "")
	var cell: Array = entry.get("cell", [])
	var columns: int = int(entry.get("columns", 0))
	var rows: int = int(entry.get("rows", 0))
	var flatten: bool = bool(entry.get("flatten_frames", false))
	if not path.begins_with("res://assets/sprites/depth/") or cell.size() != 2 or columns < 4 or columns > 32 or rows < 1 or rows * columns > 64 or row < 0 or row >= rows or not ResourceLoader.exists(path): return false
	var key: String = "%s:%d" % [path, row]
	if not _sheet_bank.has(key):
		var atlas: Texture2D = load(path) as Texture2D
		var extent: Vector2 = Vector2(float(cell[0]), float(cell[1]))
		if atlas == null or extent.x <= 0 or extent.y <= 0 or atlas.get_size() != extent * Vector2(columns, rows): return false
		var frames: Array[AtlasTexture] = []
		var pivots: Array[Vector2] = []
		var max_height: float = 1.0
		for index: int in (columns * rows if flatten else columns):
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2(Vector2(index % columns, index / columns if flatten else row) * extent, extent)
			frame.filter_clip = true
			var alpha: Dictionary = EnemySpriteArt.alpha_geometry(frame)
			if alpha.is_empty(): return false
			frames.append(frame)
			pivots.append(alpha.foot_pixel)
			max_height = maxf(max_height, float(alpha.bounds.size.y))
		_sheet_bank[key] = {"frames": frames, "pivots": pivots, "height": max_height}
	var bank: Dictionary = _sheet_bank[key]
	# The bank is immutable; actor teardown may only clear its own array views.
	_frames = bank.frames.duplicate()
	_pivots = bank.pivots.duplicate()
	var authored: Array = entry.get("pivots", [])
	if not flatten:
		var per_row: Array = entry.get("row_pivots", [])
		authored = per_row[row] if per_row.size() > row else []
	if not _apply_authored_pivots(_pivots, authored, _frames, bool(entry.get("require_authored_pivots", false))): return false
	_world_scale = height / maxf(1.0, float(entry.get("scale_height", bank.height)))
	primary_frames = _frames.size()
	frame_scales.assign(Array(_frames).map(func(_texture: AtlasTexture) -> float: return _world_scale))
	_source_faces_left = bool(entry.get("faces_left", false))
	_clips = entry.get("clips", {"idle": [0], "walk": [1], "telegraph": [2], "attack": [3], "recover": [4], "hurt": [5], "dead": [5]})
	_append_walk(entry, row, height)
	return true

func _append_walk(entry: Dictionary, default_row: int, height: float) -> void:
	if entry.has("walk_sheets") or entry.has("walk_row_sheets") or entry.has("walk_frames") or entry.has("walk_row_frames"):
		_append_multi_walk(entry, default_row, height)
		return
	var path: String = entry.get("walk_path", "")
	var cell: Array = entry.get("walk_cell", [])
	var columns: int = int(entry.get("walk_columns", 0))
	var rows: int = int(entry.get("walk_rows", 0))
	var row: int = int(entry.get("walk_row", default_row))
	if not path.begins_with("res://assets/sprites/depth/") or cell.size() != 2 or columns != 4 or row < 0 or row >= rows or not ResourceLoader.exists(path): return
	var key: String = "walk:%s:%d" % [path, row]
	if not _sheet_bank.has(key):
		var atlas: Texture2D = load(path) as Texture2D
		var extent := Vector2(float(cell[0]), float(cell[1]))
		if atlas == null or extent.x <= 0 or extent.y <= 0 or atlas.get_size() != extent * Vector2(columns, rows): return
		var frames: Array[AtlasTexture] = []
		var pivots: Array[Vector2] = []
		var maximum_height: float = 1.0
		for index: int in columns:
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = Rect2(Vector2(index, row) * extent, extent)
			frame.filter_clip = true
			var alpha: Dictionary = EnemySpriteArt.alpha_geometry(frame)
			if alpha.is_empty(): return
			frames.append(frame)
			pivots.append(alpha.foot_pixel)
			maximum_height = maxf(maximum_height, float(alpha.bounds.size.y))
		_sheet_bank[key] = {"frames": frames, "pivots": pivots, "height": maximum_height}
	var bank: Dictionary = _sheet_bank[key]
	var first: int = _frames.size()
	var authored: Array = entry.get("walk_pivots", [])
	var per_row: Array = entry.get("walk_row_pivots", [])
	if per_row.size() > row: authored = per_row[row]
	var gait_pivots: Array[Vector2] = bank.pivots.duplicate()
	if not _apply_authored_pivots(gait_pivots, authored, bank.frames, bool(entry.get("require_authored_pivots", false))): return
	# One scale for all four gait poses, preventing per-frame alpha height jitter.
	var gait_scale: float = height / maxf(1.0, float(entry.get("walk_scale_height", bank.height)))
	for index: int in columns:
		_frames.append(bank.frames[index])
		_pivots.append(gait_pivots[index])
		frame_scales.append(gait_scale)
	walk_frames = columns
	_clips = _clips.duplicate(true)
	_clips["walk"] = [first, first + 1, first + 2, first + 3]

func _apply_authored_pivots(destination: Array[Vector2], authored: Array, frames: Array[AtlasTexture], required: bool) -> bool:
	if authored.is_empty(): return not required
	if authored.size() != destination.size(): return false
	for index: int in authored.size():
		if not authored[index] is Array or authored[index].size() != 2: return false
		var pivot := Vector2(float(authored[index][0]), float(authored[index][1]))
		var extent: Vector2 = frames[index].get_size()
		if not is_finite(pivot.x) or not is_finite(pivot.y) or pivot.x < 0 or pivot.y < 0 or pivot.x > extent.x or pivot.y > extent.y: return false
		destination[index] = pivot
	return true

func _select_sheets(entry: Dictionary, row: int, walk: bool) -> Array:
	var frame_row_key: String = "walk_row_frames" if walk else "row_frames"
	var frame_flat_key: String = "walk_frames" if walk else "frames"
	if entry.has(frame_row_key) or entry.has(frame_flat_key):
		var definitions: Array = []
		var authored: Array = entry.get(frame_flat_key, [])
		if entry.has(frame_row_key):
			var choices: Array = entry[frame_row_key]
			if row < 0 or row >= choices.size(): return []
			authored = choices[row]
		for frame: Dictionary in authored:
			definitions.append({"path": frame.get("path", ""), "columns": 1, "rows": 1, "regions": [frame.get("region", [])], "margin": frame.get("margin", [0, 0, 0, 0]), "scale_height": frame.get("body_height", 0)})
		return definitions
	var row_key: String = "walk_row_sheets" if walk else "row_sheets"
	var flat_key: String = "walk_sheets" if walk else "sheets"
	if entry.has(row_key):
		var choices: Array = entry[row_key]
		if row < 0 or row >= choices.size() or not choices[row] is Dictionary: return []
		return [choices[row]]
	return entry.get(flat_key, [])

func _configure_multi_sheet(entry: Dictionary, row: int, height: float) -> bool:
	var bank: Dictionary = _multi_sheet_bank(_select_sheets(entry, row, false))
	if bank.is_empty(): return false
	_frames = bank.frames.duplicate()
	_pivots = bank.pivots.duplicate()
	var authored: Array = entry.get("pivots", [])
	var per_row: Array = entry.get("row_pivots", [])
	if per_row.size() > row: authored = per_row[row]
	if not _apply_authored_pivots(_pivots, authored, _frames, bool(entry.get("require_authored_pivots", false))): return false
	var source_height: float = maxf(1.0, float(entry.get("scale_height", bank.height)))
	_world_scale = height / source_height
	primary_frames = _frames.size()
	frame_scales.clear()
	for index: int in primary_frames:
		var authored_height: float = float(bank.scale_heights[index])
		frame_scales.append(height / (authored_height if authored_height > 0 else source_height))
	_source_faces_left = bool(entry.get("faces_left", false))
	_clips = entry.get("clips", {"idle": [0], "walk": [1], "telegraph": [2], "attack": [3], "recover": [4], "hurt": [5], "dead": [5]})
	_append_walk(entry, row, height)
	return true

func _append_multi_walk(entry: Dictionary, row: int, height: float) -> void:
	var bank: Dictionary = _multi_sheet_bank(_select_sheets(entry, row, true))
	if bank.is_empty() or bank.frames.size() != 4: return
	var gait_pivots: Array[Vector2] = bank.pivots.duplicate()
	var authored: Array = entry.get("walk_pivots", [])
	var per_row: Array = entry.get("walk_row_pivots", [])
	if per_row.size() > row: authored = per_row[row]
	if not _apply_authored_pivots(gait_pivots, authored, bank.frames, bool(entry.get("require_authored_pivots", false))): return
	var first: int = _frames.size()
	# The entire gait uses one authored scale; stride poses cannot resize the body.
	var authored_height: float = float(bank.scale_heights[0])
	var source_height: float = float(entry.get("walk_scale_height", authored_height if authored_height > 0 else bank.height))
	var gait_scale: float = height / maxf(1.0, source_height)
	for index: int in 4:
		_frames.append(bank.frames[index])
		_pivots.append(gait_pivots[index])
		frame_scales.append(gait_scale)
	walk_frames = 4
	_clips = _clips.duplicate(true)
	_clips["walk"] = [first, first + 1, first + 2, first + 3]

func _multi_sheet_bank(definitions: Array) -> Dictionary:
	if definitions.is_empty(): return {}
	var key: String = "multi:" + JSON.stringify(definitions)
	if _sheet_bank.has(key): return _sheet_bank[key]
	var frames: Array[AtlasTexture] = []
	var pivots: Array[Vector2] = []
	var scale_heights: Array[float] = []
	var maximum_height: float = 1.0
	for definition: Variant in definitions:
		if not definition is Dictionary: return {}
		var path: String = definition.get("path", "")
		var columns: int = int(definition.get("columns", 0))
		var rows: int = int(definition.get("rows", 1))
		var row: int = int(definition.get("row", 0))
		if not path.begins_with("res://assets/sprites/depth/") or columns < 1 or rows < 1 or columns * rows > 64 or row < 0 or row >= rows or not ResourceLoader.exists(path): return {}
		var atlas: Texture2D = load(path) as Texture2D
		if atlas == null: return {}
		var cell: Array = definition.get("cell", [atlas.get_width() / float(columns), atlas.get_height() / float(rows)])
		if cell.size() != 2: return {}
		var extent := Vector2(float(cell[0]), float(cell[1]))
		var regions: Array = definition.get("regions", [])
		if extent.x <= 0 or extent.y <= 0 or (regions.is_empty() and atlas.get_size() != extent * Vector2(columns, rows)): return {}
		var count: int = regions.size() if not regions.is_empty() else columns
		if count < 1 or frames.size() + count > 64: return {}
		for index: int in count:
			var region := Rect2(Vector2(index, row) * extent, extent)
			if not regions.is_empty():
				if not regions[index] is Array or regions[index].size() != 4: return {}
				var rect: Array = regions[index]
				region = Rect2(float(rect[0]), float(rect[1]), float(rect[2]), float(rect[3]))
			if region.position.x < 0 or region.position.y < 0 or region.size.x <= 0 or region.size.y <= 0 or region.end.x > atlas.get_width() or region.end.y > atlas.get_height(): return {}
			var frame := AtlasTexture.new()
			frame.atlas = atlas
			frame.region = region
			frame.filter_clip = true
			var padding: Array = definition.get("margin", [0, 0, 0, 0])
			if padding.size() != 4: return {}
			frame.margin = Rect2(float(padding[0]), float(padding[1]), float(padding[2]), float(padding[3]))
			if frame.margin.position.x < 0 or frame.margin.position.y < 0 or frame.margin.size.x < frame.margin.position.x or frame.margin.size.y < frame.margin.position.y: return {}
			var alpha: Dictionary = EnemySpriteArt.alpha_geometry(frame)
			if alpha.is_empty(): return {}
			frames.append(frame)
			pivots.append(alpha.foot_pixel)
			scale_heights.append(float(definition.get("scale_height", 0.0)))
			maximum_height = maxf(maximum_height, float(alpha.bounds.size.y))
	var bank: Dictionary = {"frames": frames, "pivots": pivots, "scale_heights": scale_heights, "height": maximum_height}
	_sheet_bank[key] = bank
	return bank

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(actor): return
	if is_instance_valid(actor.combat_feedback) and actor.combat_feedback.is_frozen(): return
	var distance: float = actor.global_position.distance_to(_last_foot)
	_last_foot = actor.global_position
	if distance < 32.0 and actor.state_machine.get_state_id() in [&"patrol", &"chase"]:
		_walk_distance += distance
	seek_actor()

func seek_actor(force: bool = false) -> void:
	if not is_instance_valid(actor): return
	var sample := Vector2(actor.clock, actor.state_time)
	if not force and sample == _last_sample: return
	_last_sample = sample
	var state: StringName = actor.state_machine.get_state_id()
	selected_clip = &"idle"
	selected_progress = fposmod(actor.clock / 1.6, 1.0)
	match state:
		&"telegraph": selected_clip = &"telegraph"; selected_progress = actor.state_time / maxf(0.001, actor.definition.windup)
		&"attack": selected_clip = &"attack"; selected_progress = actor.state_time / maxf(0.001, actor.definition.active)
		&"recover": selected_clip = &"recover"; selected_progress = actor.state_time / maxf(0.001, actor.definition.recovery)
		&"hurt": selected_clip = &"hurt"; selected_progress = actor.state_time / 0.18
		&"dead": selected_clip = &"dead"; selected_progress = actor.state_time / 0.30
		_:
			if absf(actor.velocity.x) > 2.0 or (actor.definition.flying and actor.velocity.length() > 2.0):
				selected_clip = &"walk"
				selected_progress = fposmod(_walk_distance / 36.0, 1.0)
	if actor.flash_remaining > 0.075 and state != &"dead": selected_clip = &"hurt"
	selected_progress = clampf(selected_progress, 0, 1)
	displayed_facing = actor.facing
	if raster_ready:
		var choices: Array = _clips.get(String(selected_clip), [0])
		selected_frame = int(choices[mini(choices.size() - 1, floori(selected_progress * choices.size()))])
		selected_frame = clampi(selected_frame, 0, _frames.size() - 1)
		sprite.texture = _frames[selected_frame]
		sprite.centered = false
		sprite.scale = Vector2.ONE * frame_scales[selected_frame]
		geometry = {"foot_pixel": _pivots[selected_frame], "authored_frames": true}
		EnemySpriteArt.set_facing(sprite, _pivots[selected_frame], (displayed_facing < 0) != _source_faces_left)
	else:
		EnemySpriteArt.set_facing(sprite, geometry.foot_pixel, displayed_facing < 0)
	# Poses stay at the physical foot; flight comes entirely from the motor.
	motion.position = Vector2.ZERO
	motion.rotation = 0.0
	motion.scale = Vector2.ONE
	sprite.modulate = Color(1, 1, 1, maxf(0.0, 1 - actor.state_time / 0.30) if state == &"dead" else 1.0)
	_material.set_shader_parameter("flash", 1.0 if actor.flash_remaining > 0.075 else 0.0)
	queue_redraw()

func _depth_state_changed(_previous: StringName, _next: StringName) -> void:
	seek_actor(true)

func _depth_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0 or event.source_kind == DamageEvent.SourceKind.DOT: return
	hit_reaction_count += 1
	seek_actor(true)

func snapshot() -> Dictionary:
	return {"raster_ready": raster_ready, "clip": selected_clip, "frame": selected_frame, "progress": selected_progress, "pivot": geometry.get("foot_pixel", Vector2.ZERO), "foot": EnemySpriteArt.foot_world(sprite, geometry.get("foot_pixel", Vector2.ZERO)), "frames": _frames.size(), "primary_frames": primary_frames, "walk_frames": walk_frames, "scale": sprite.scale, "facing": displayed_facing, "clock": actor.clock, "state_time": actor.state_time}

func _draw() -> void:
	if not is_instance_valid(actor): return
	var state: StringName = actor.state_machine.get_state_id()
	var center := Vector2(0, -actor.definition.body_size.y * 0.5)
	if state == &"telegraph":
		var target: Vector2 = to_local(actor.locked_target)
		if actor.attack_kind == &"slow_field":
			draw_arc(target + Vector2(0, 18), 64, 0, TAU, 32, Color(tint, 0.85), 2.5)
			draw_circle(target + Vector2(0, 18), 64, Color(tint, 0.08))
		elif actor.attack_kind == &"sweep":
			draw_arc(center, 68, actor.facing * 0.0 + (-0.8 if actor.facing > 0 else PI - 0.8), 0.8 if actor.facing > 0 else PI + 0.8, 20, Color(tint, 0.85), 2)
		else:
			draw_line(center, target, Color(tint, 0.85), 2)
			draw_circle(target, 9, Color(tint, 0.15))
	if actor.attack_hitbox.active:
		var collision: CollisionShape2D = actor.attack_hitbox.collision_shape
		if collision != null and collision.shape is RectangleShape2D:
			var size: Vector2 = collision.shape.size
			draw_rect(Rect2(actor.attack_hitbox.position + collision.position - size * 0.5, size), Color(tint, 0.13), true)
			draw_rect(Rect2(actor.attack_hitbox.position + collision.position - size * 0.5, size), Color(tint, 0.90), false, 2)
	if actor.health is EnemyShieldHealth and actor.health.current_shield > 0.0:
		draw_arc(center, 43, 0, TAU, 32, Color(tint, 0.6), 2)

func _exit_tree() -> void:
	if is_instance_valid(actor):
		if is_instance_valid(actor.state_machine) and actor.state_machine.state_changed.is_connected(_depth_state_changed): actor.state_machine.state_changed.disconnect(_depth_state_changed)
		if is_instance_valid(actor.hurtbox) and actor.hurtbox.hit_resolved.is_connected(_depth_hit): actor.hurtbox.hit_resolved.disconnect(_depth_hit)
	actor = null
	_frames.clear()
	_pivots.clear()
	frame_scales.clear()
