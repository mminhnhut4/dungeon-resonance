class_name TanDangSpriteArt
extends RefCounted
## Manual atlas seek only. The actor owns movement, combat clocks and life.
## One Sprite2D and twelve shared-atlas regions; no animation timer or callbacks.
const MANIFEST: String = "res://assets/sprites/npc/tan_dang_v1/manifest.json"
const BASE: String = "res://assets/sprites/npc/tan_dang_v1/"
const MAX_MOTION_SAMPLE: float = 32.0
# Only the seven authored sheets stay resident between room-owned actors.
# No actor, Sprite2D, frame metadata or callbacks are held by this bank.
const RESIDENT_ATLASES: Array[String] = ["moc_yen.png", "moc_yen_steps.png", "lam_tuoc.png", "lam_tuoc_steps.png", "du_hanh.png", "du_hanh_steps.png", "du_hanh_follow.png"]
static var resident_atlases: Dictionary[String, Texture2D] = {}

static func _atlas_texture(path: String) -> Texture2D:
	if resident_atlases.has(path): return resident_atlases[path]
	var texture: Texture2D = load(path) as Texture2D
	# Future/custom manifest paths retain normal ResourceLoader lifetime.
	if texture != null and path.get_base_dir() == BASE.trim_suffix("/") and path.get_file() in RESIDENT_ATLASES:
		resident_atlases[path] = texture
	return texture
const IDS: Array[String] = ["tan_dang_moc_yen","tan_dang_lam_tuoc","tan_dang_du_hanh"]
const POSES: Array[String] = ["idle","contact_a","pass_a","contact_b","pass_b","anticipate_early","anticipate_late","active_early","active_late","recover","hurt","downed"]
var available: bool = false
var frame_index: int = 0
var pose_name: String = "idle"
var walk_distance: float = 0.0
var actual_displacement := Vector2.ZERO
var teleport_discarded: bool = false
var frame_pivot := Vector2.ZERO
var frame_region := Rect2()
var stance_contact_local := Vector2.ZERO
var planted_contact_world := Vector2.ZERO
var has_stance_contact: bool = false
var support_role: String = "none"
var draw_scale: float = 1.0
var atlas_path: String = ""
var frame_atlas_path: String = ""
var last_error: String = "unconfigured"
var _sprite: Sprite2D
var _frames: Array[AtlasTexture] = []
var _pivots: Array[Vector2] = []
var _contacts: Array[Vector2] = []
var _measured_contacts: Array[bool] = []
var _roles: Array[String] = []
var _scale_multipliers: Array[float] = []
var _atlas_paths: Array[String] = []
var _base_draw_scale: float = 1.0
var _last_world := Vector2.ZERO
var _last_phase: String = "idle"
var _last_mode: String = ""
var _cycle_distance: float = 48.0
var _source_facing: float = 1.0
var _last_physics_tick: int = -1
var _walking: bool = false
var _walk_phase_distance: float = 0.0
var _motion_direction: float = 0.0

func configure(owner_node: Node2D, sprite: Sprite2D, stable_id: String) -> bool:
	available = false
	if stable_id not in IDS or not is_instance_valid(owner_node) or not is_instance_valid(sprite): return _refuse("invalid_actor")
	if not FileAccess.file_exists(MANIFEST): return _refuse("manifest_missing")
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	if not document is Dictionary or document.get("version") != 1 or not document.get("actors") is Dictionary: return _refuse("invalid_manifest")
	var grid: Vector2 = _vector(document.get("grid"),Vector2.ZERO)
	if grid.x < 1.0 or grid.y < 1.0 or grid.x != floorf(grid.x) or grid.y != floorf(grid.y) or grid.x*grid.y != 12.0: return _refuse("invalid_grid")
	var columns: int = int(grid.x)
	var entry: Variant = document["actors"].get(stable_id)
	if not entry is Dictionary or not entry.get("texture") is String: return _refuse("actor_entry_missing")
	var invalid := Vector2(INF,INF)
	var cell: Vector2 = _vector(entry.get("frame_size"),invalid)
	var pivot: Vector2 = _vector(entry.get("pivot"),invalid)
	var details: Variant = entry.get("frames",[])
	if not details is Array or details.size() not in [0,12]: return _refuse("invalid_frame_metadata")
	var explicit_regions: int = 0
	for detail: Variant in details:
		if not detail is Dictionary: return _refuse("invalid_frame_metadata")
		if detail.has("region"): explicit_regions += 1
	if explicit_regions not in [0,12]: return _refuse("partial_frame_regions")
	var source_height: float = _number(entry.get("body_height_px"),0.0)
	var draw_height: float = _number(entry.get("draw_height",document.get("draw_height",60.0)),NAN)
	_cycle_distance = _number(entry.get("walk_cycle_distance",document.get("walk_cycle_distance",48.0)),NAN)
	if explicit_regions == 0 and (cell.x <= 0.0 or cell.y <= 0.0 or not cell.is_finite()): return _refuse("invalid_frame_size")
	if not is_finite(source_height) or source_height <= 0.0 or not is_finite(draw_height) or draw_height < 30.0 or draw_height > 100.0 or not is_finite(_cycle_distance) or _cycle_distance < 8.0 or _cycle_distance > 128.0: return _refuse("invalid_geometry")
	if str(entry.get("source_facing","right")) not in ["right","left"]: return _refuse("invalid_source_facing")
	_source_facing = -1.0 if entry.get("source_facing","right") == "left" else 1.0
	atlas_path = str(entry["texture"])
	if not atlas_path.begins_with("res://"): atlas_path = BASE.path_join(atlas_path)
	if not ResourceLoader.exists(atlas_path,"Texture2D"): return _refuse("atlas_missing")
	var atlas: Texture2D = _atlas_texture(atlas_path)
	if atlas == null: return _refuse("atlas_invalid")
	if explicit_regions == 0 and not Vector2(atlas.get_size()).is_equal_approx(cell*grid): return _refuse("atlas_grid_mismatch")
	var atlases: Dictionary = {atlas_path:atlas}
	_frames.clear(); _pivots.clear(); _contacts.clear(); _measured_contacts.clear(); _roles.clear()
	_scale_multipliers.clear(); _atlas_paths.clear()
	for index: int in 12:
		var info: Dictionary = details[index] if details.size() == 12 else {}
		if info.has("texture") and not info["texture"] is String: return _refuse("invalid_frame_texture")
		var frame_path: String = str(info.get("texture",atlas_path))
		if not frame_path.begins_with("res://"): frame_path = BASE.path_join(frame_path)
		if not atlases.has(frame_path):
			if not ResourceLoader.exists(frame_path,"Texture2D"): return _refuse("frame_atlas_missing")
			var extra_atlas: Texture2D = _atlas_texture(frame_path)
			if extra_atlas == null: return _refuse("frame_atlas_invalid")
			atlases[frame_path] = extra_atlas
		var frame_atlas: Texture2D = atlases[frame_path]
		var multiplier: float = _number(info.get("scale_multiplier",1.0),NAN)
		if not is_finite(multiplier) or multiplier < 0.05 or multiplier > 4.0: return _refuse("invalid_frame_scale")
		var region: Rect2 = _region(info["region"]) if explicit_regions == 12 else Rect2(Vector2(index%columns,floori(float(index)/float(columns)))*cell,cell)
		if not region.position.is_finite() or not region.size.is_finite() or region.position.x < 0.0 or region.position.y < 0.0 or region.size.x <= 0.0 or region.size.y <= 0.0 or region.end.x > frame_atlas.get_width() or region.end.y > frame_atlas.get_height(): return _refuse("invalid_frame_region")
		var frame := AtlasTexture.new()
		frame.atlas = frame_atlas
		frame.region = region
		frame.filter_clip = true
		_frames.append(frame)
		var point: Vector2 = _vector(info["pivot"],invalid) if info.has("pivot") else pivot
		var contact: Vector2 = _vector(info["stance_contact"],invalid) if info.has("stance_contact") else point
		if not point.is_finite() or not contact.is_finite(): return _refuse("invalid_frame_contact")
		var role: String = str(info.get("support_role","none"))
		if role not in ["left","right","both","none"]: return _refuse("invalid_support_role")
		_pivots.append(point)
		_contacts.append(contact)
		_measured_contacts.append(info.has("stance_contact"))
		_roles.append(role)
		_scale_multipliers.append(multiplier)
		_atlas_paths.append(frame_path)
	_base_draw_scale = draw_height/source_height
	_sprite = sprite
	_sprite.centered = false
	_sprite.offset = Vector2.ZERO
	_sprite.flip_h = false
	_sprite.flip_v = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	_sprite.visible = true
	_last_world = owner_node.global_position
	available = true
	last_error = ""
	_apply(owner_node,0,1.0)
	return true

func _refuse(message: String) -> bool:
	last_error = message
	return false

static func _vector(value: Variant, fallback: Vector2) -> Vector2:
	if not value is Array or value.size() != 2: return fallback
	if not (value[0] is int or value[0] is float) or not (value[1] is int or value[1] is float): return fallback
	var result := Vector2(float(value[0]),float(value[1]))
	return result if result.is_finite() else fallback

static func _number(value: Variant, fallback: float) -> float:
	if not (value is int or value is float): return fallback
	return float(value)

static func _region(value: Variant) -> Rect2:
	var invalid := Rect2(Vector2(INF,INF),Vector2(INF,INF))
	if not value is Array or value.size() != 4: return invalid
	for component: Variant in value:
		if not (component is int or component is float): return invalid
	return Rect2(float(value[0]),float(value[1]),float(value[2]),float(value[3]))

func sync(owner_node: Node2D, phase: String, remaining: float, spec: Dictionary, mode: String, playing: bool, frame_delta: float, facing: float, window: int = 0) -> void:
	if not available or not is_instance_valid(_sprite): return
	actual_displacement = owner_node.global_position-_last_world
	_last_world = owner_node.global_position
	teleport_discarded = actual_displacement.length() >= MAX_MOTION_SAMPLE
	var physics_tick: int = Engine.get_physics_frames()
	var same_physics_tick: bool = physics_tick == _last_physics_tick
	_last_physics_tick = physics_tick
	var seek: int = 0
	var duration: float = float(spec.get(phase,0.0))
	if phase == "tell" and window == 2: duration = float(spec.get("followup_tell",duration))
	var fraction: float = clampf(1.0-remaining/duration,0.0,1.0) if duration > 0.0 else 0.0
	if mode in ["downed","dead","recovering"]: seek = 11
	elif phase == "hurt": seek = 10
	elif phase == "tell": seek = 5 if fraction < 0.5 else 6
	elif phase == "active": seek = 7 if fraction < 0.5 else 8
	elif phase == "recover": seek = 9
	elif not playing and _last_phase == phase and _last_mode == mode: seek = frame_index
	elif same_physics_tick and actual_displacement.length_squared() <= 0.00000001 and _last_phase == phase and _last_mode == mode: seek = frame_index
	elif playing and frame_delta > 0.0 and not teleport_discarded and absf(actual_displacement.x) > 0.00001 and phase in ["idle","approach"] and mode != "talk":
		var motion: float = signf(actual_displacement.x)
		if not _walking or motion != _motion_direction: _walk_phase_distance = 0.0
		_motion_direction = motion
		_walking = true
		walk_distance += absf(actual_displacement.x)
		_walk_phase_distance += absf(actual_displacement.x)
		var cycle: float = fposmod(_walk_phase_distance,_cycle_distance)/_cycle_distance
		var step: int = mini(3,int(floor(cycle*4.0)))
		# A retreat keeps facing the target; reverse the authored step sequence.
		if actual_displacement.x*facing < 0.0: step = posmod(-step,4)
		seek = 1+step
	else:
		_walking = false
	if phase not in ["idle","approach"]: _walking = false
	_last_phase = phase
	_last_mode = mode
	_apply(owner_node,seek,facing)

func _apply(owner_node: Node2D, index: int, facing: float) -> void:
	frame_index = clampi(index,0,11)
	pose_name = POSES[frame_index]
	frame_pivot = _pivots[frame_index]
	frame_region = _frames[frame_index].region
	stance_contact_local = _contacts[frame_index]
	draw_scale = _base_draw_scale*_scale_multipliers[frame_index]
	frame_atlas_path = _atlas_paths[frame_index]
	var direction: float = (-1.0 if facing < 0.0 else 1.0)*_source_facing
	_sprite.texture = _frames[frame_index]
	_sprite.scale = Vector2(draw_scale*direction,draw_scale)
	# Authored downed art stays horizontal; only the image cancels the inherited
	# physical-root rotation. No body/hurtbox/caption transform is changed.
	_sprite.rotation = -owner_node.rotation
	_sprite.position = (-frame_pivot*_sprite.scale).rotated(-owner_node.rotation)
	has_stance_contact = _measured_contacts[frame_index]
	support_role = _roles[frame_index]
	planted_contact_world = _sprite.to_global(_contacts[frame_index])
