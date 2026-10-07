class_name NpcPilotActor
extends HubNpc
## Approved idle art for P01/P02/P03; neutral vector fallback for other residents.
## Presentation follows the existing local heightfield; no Player motor edits.
const ROAD_IDLE_ATLAS: Texture2D = preload("res://assets/sprites/npc/road_idle_v1/runtime/road_npcs_idle_atlas.png")
const ROAD_IDLE_ROWS: Dictionary = {"pilot_traveler":0, "pilot_bridge_keeper":1, "pilot_pilgrim":2}
const ROAD_IDLE_PIVOT := Vector2(128,272)
const ROAD_IDLE_SCALE: float = 0.25
signal cue_requested(stable_id: String, cue: StringName, world_position: Vector2, lifetime_owner: Node)
var stable_id: String
var world_state: NpcWorldState
var room: ExteriorRoom
var health: HealthComponent
var hurtbox: Hurtbox
var caption: Label
var _step_distance: float = 0.0
var _last_mode: String = ""
var _motion_distance: float = 0.0
var _pose_clock: float = 0.0
var _facing: float = 1.0
var social_activity: String = ""
var _uses_road_idle_art: bool = false
var traveler_walk_art: NpcTravelerWalkArt

func bind_road_idle_art() -> void:
	# One honest idle frame per ID. Bind before add_child so _ready builds it once.
	if not ROAD_IDLE_ROWS.has(stable_id): return
	var frame := AtlasTexture.new()
	frame.atlas = ROAD_IDLE_ATLAS
	frame.region = Rect2(0,int(ROAD_IDLE_ROWS[stable_id])*288,256,288)
	frame.filter_clip = true
	_uses_road_idle_art = true
	if stable_id == "pilot_traveler":
		traveler_walk_art = NpcTravelerWalkArt.new()
		traveler_walk_art.ground_room = room
		add_child(traveler_walk_art)
	set_approved_portrait(frame)

func _build_sprite() -> void:
	if not _uses_road_idle_art:
		super._build_sprite()
		return
	if body == null:
		body = Sprite2D.new()
		body.name = "ApprovedNpcSprite"
		add_child(body)
	body.texture = portrait
	body.centered = false
	body.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	body.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	body.scale = Vector2.ONE * ROAD_IDLE_SCALE
	# Source manifest owns pivot and size; faint alpha padding is not body geometry.
	alpha_geometry = {"foot_pixel":ROAD_IDLE_PIVOT}
	_scale = ROAD_IDLE_SCALE
	EnemySpriteArt.set_facing(body,ROAD_IDLE_PIVOT,_facing < 0.0)

func _ready() -> void:
	super._ready()
	add_to_group(&"npc_pilot_actor")
	var spec: Dictionary = NpcPilotCatalog.definition(stable_id)
	preview_tint = Color(spec["tint"])
	_pose_clock = NpcPilotCatalog.IDS.find(stable_id) * 0.73
	health = HealthComponent.new()
	health.maximum_health = NpcPilotCatalog.MAX_HEALTH
	health.minimum_health = 1.0
	add_child(health)
	health.current_health = world_state.records[stable_id]["hp"]
	var resolver := NpcPilotResolver.new()
	resolver.health = health
	resolver.world_state = world_state
	resolver.stable_id = stable_id
	resolver.origin_offset_x = room.global_position.x
	add_child(resolver)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.actor_body = self
	hurtbox.health = health
	hurtbox.damage_resolver = resolver
	hurtbox.team_id = 3
	hurtbox.collision_layer = 16 # Existing enemy Hurtbox channel; neutral has own team.
	hurtbox.collision_mask = 0
	var shape := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 11
	capsule.height = 52
	shape.shape = capsule
	shape.position.y = -26
	hurtbox.add_child(shape)
	add_child(hurtbox)
	caption = Label.new()
	caption.set_meta(&"debug_keep",true)
	caption.position = Vector2(-105, -98)
	caption.size = Vector2(210, 40)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 13)
	add_child(caption)
	sync_record(false)

func _process(_delta: float) -> void:
	# Simulation owns all position/state clocks; rendering just reflects records.
	pass

func sync_record(emit_cues: bool = true, interpolation_time: float = 0.0, frame_delta: float = 0.0) -> void:
	var record: Dictionary = world_state.records[stable_id]
	var previous: Vector2 = position
	health.current_health = record["hp"]
	var mode: String = record["mode"]
	var spec: Dictionary = NpcPilotCatalog.definition(stable_id)
	if frame_delta <= 0.0:
		# Explicit spawn/test synchronization never replays offscreen steps.
		position.x = float(record["x"])
	elif emit_cues:
		var speed: float = float(spec["speed"]) * (1.8 if mode == "flee" else 1.0)
		var sampled_x: float = float(record["x"])
		if mode in ["walk", "flee"]:
			sampled_x = move_toward(sampled_x, float(record["target"]), speed * interpolation_time)
			_facing = signf(float(record["target"]) - position.x) if not is_equal_approx(float(record["target"]),position.x) else _facing
		# Follow the bounded clock sample continuously; pause holds the exact pose.
		position.x = move_toward(position.x, sampled_x, speed * frame_delta)
		_pose_clock += frame_delta
	position.y = room.floor_y(position.x)
	_motion_distance += previous.distance_to(position) if emit_cues else 0.0
	caption.text = "%s\n%s" % [spec["name"], NpcPilotCatalog.activity_label(stable_id, record)]
	if mode == "work" and not social_activity.is_empty(): caption.text = "%s\n%s" % [spec["name"],social_activity]
	if mode != _last_mode:
		_last_mode = mode
		if emit_cues: cue_requested.emit(stable_id, StringName("npc_" + mode), global_position, self)
	_step_distance = _step_distance + previous.distance_to(position) if emit_cues else 0.0
	if emit_cues and mode in ["walk", "flee"] and _step_distance >= 40.0:
		_step_distance = 0
		cue_requested.emit(stable_id, &"npc_footstep", global_position, self)
	modulate.a = 0.65 if mode == "recovering" else 1.0
	rotation = -PI * 0.42 if mode == "downed" else 0.0
	caption.rotation = -rotation
	caption.position = Vector2(-105,-98).rotated(-rotation)
	if _uses_road_idle_art and is_instance_valid(body):
		if traveler_walk_art != null:
			traveler_walk_art.sync(body,portrait,mode,emit_cues,position.x-previous.x,frame_delta,float(record["hp"]),global_position,_facing)
		EnemySpriteArt.set_facing(body,ROAD_IDLE_PIVOT,_facing < 0.0)
	queue_redraw()

func _draw() -> void:
	if portrait != null:
		super._draw()
		return
	# Temporary vector art: visual gait/gestures only, no extra body collisions.
	var moving: bool = _last_mode in ["walk", "flee"]
	var stride: float = sin(_motion_distance * 0.16) if moving else 0.0
	var bob: float = absf(stride) * 1.4 if moving else sin(_pose_clock * 2.4) * 0.4
	if _last_mode in ["downed", "dead"]: bob = 0.0
	draw_set_transform(Vector2(0, -2), 0, Vector2(1, 0.26))
	draw_circle(Vector2.ZERO, 15, Color(0.01, 0.02, 0.02, 0.4))
	draw_set_transform(Vector2.ZERO)
	draw_line(Vector2(-5,-9),Vector2(-7+stride*6,0),preview_tint.darkened(0.25),5)
	draw_line(Vector2(5,-9),Vector2(7-stride*6,0),preview_tint.darkened(0.25),5)
	var lean: float = _facing * (2.0 if _last_mode == "flee" else 0.8) if moving else 0.0
	draw_colored_polygon(PackedVector2Array([Vector2(-9+lean,-38-bob),Vector2(9+lean,-38-bob),Vector2(14,-7),Vector2(-14,-7)]),preview_tint)
	draw_circle(Vector2(lean,-48-bob),9,preview_tint.lightened(0.12))
	var gesture: float = sin(_pose_clock*3.0)*2.0 if _last_mode in ["work", "talk"] else stride*3.0
	var reach: float = 8.0 if _last_mode == "work" else 3.0
	draw_line(Vector2(lean+_facing*8,-34-bob),Vector2(_facing*(12+reach),-24-bob+gesture),preview_tint.darkened(0.15),4)
	draw_line(Vector2(lean-_facing*8,-34-bob),Vector2(-_facing*12,-21-bob-gesture),preview_tint.darkened(0.15),4)
