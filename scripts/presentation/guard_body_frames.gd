class_name GuardBodyFrames
extends RefCounted
## Baked articulated source poses. Seek only; actor FSM/hitbox owns gameplay.
const ASSET_ROOT: String = "res://assets/sprites/enemies/guard_rendered_r1/"
const PIVOT: Vector2 = Vector2(168, 292)
const CANVAS: Vector2 = Vector2(448, 320)
const SCALE: float = 0.30
const PRE_STRIKE_WINDUP: float = 0.88
static var _bank: Dictionary = {}
static var last_error: String = ""
var actor: BaseEnemy
var sprite: Sprite2D
var clip_id: StringName = &"idle"
var frame_index: int = 0
var frame_data: Dictionary = {}
var selected_progress: float = 0.0
var displayed_facing: float = 1.0
var valid: bool = false
var _last_state: StringName = &""
var _last_state_time: float = -1.0
var _last_clock: float = -1.0

static func _load_bank() -> bool:
	if not _bank.is_empty(): return true
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(ASSET_ROOT+"guard_rig.json"))
	if not data is Dictionary: return _invalid("metadata must be a Dictionary")
	var canvas: Array = data.get("canvas",[])
	var pivot: Array = data.get("root_pivot",[])
	if canvas.size()!=2 or pivot.size()!=2: return _invalid("canvas/pivot length")
	if Vector2(canvas[0],canvas[1])!=CANVAS or Vector2(pivot[0],pivot[1])!=PIVOT or not is_equal_approx(float(data.get("world_scale",0)),SCALE): return _invalid("canvas/pivot/scale values")
	var built: Dictionary = {}
	for entry: Dictionary in data["clips"]:
		var atlas_name: String = entry["atlas"]
		if atlas_name.contains("/") or atlas_name.contains("\\") or not ResourceLoader.exists(ASSET_ROOT+atlas_name): return _invalid("missing/unsafe atlas "+atlas_name)
		var atlas: Texture2D = load(ASSET_ROOT+atlas_name) as Texture2D
		var textures: Array[AtlasTexture] = []
		for frame: Dictionary in entry["frames"]:
			var rect: Array = frame["rect"]
			if rect.size()!=4 or rect[2]!=448 or rect[3]!=320: return _invalid("frame rectangle shape")
			var region := Rect2(rect[0],rect[1],rect[2],rect[3])
			if not Rect2(Vector2.ZERO,atlas.get_size()).encloses(region): return _invalid("out-of-atlas frame "+atlas_name)
			var texture := AtlasTexture.new()
			texture.atlas=atlas
			texture.region=region
			texture.filter_clip=true
			textures.append(texture)
		if textures.size()!=int(entry["count"]): return _invalid("clip count")
		built[StringName(entry["id"]) ]={"metadata":entry,"textures":textures}
	for required: StringName in [&"idle",&"walk",&"windup_sweep",&"attack_sweep",&"recover",&"hurt",&"death"]:
		if not built.has(required): return _invalid("missing clip "+String(required))
	_bank=built # Shared immutable textures/JSON; never per-actor clocks.
	return true

static func _invalid(reason: String) -> bool:
	last_error=reason
	return false

func bind(owner_actor: BaseEnemy, owner_sprite: Sprite2D) -> bool:
	actor=owner_actor
	sprite=owner_sprite
	valid=_load_bank() and actor.definition.id==&"ancient_guard" and is_equal_approx(actor.definition.visual_height,60.0)
	if not valid: return false
	sprite.centered=false
	sprite.scale=Vector2.ONE*SCALE
	seek_actor(0.0,actor.facing,false,true)
	actor.state_machine.state_changed.connect(_on_state_changed)
	return true

func _on_state_changed(_previous: StringName,_next: StringName) -> void:
	# Read the just-entered actor clock before contact can freeze presentation.
	# No clock advance, transition or combat event is owned by this observer.
	seek_actor(0.0,actor.facing,false,true)

func seek_actor(walk_phase_radians: float,facing: float,moving: bool,force_sample: bool=false) -> void:
	if not valid or not is_instance_valid(actor) or not is_instance_valid(sprite): return
	var state: StringName=actor.state_machine.get_state_id()
	if not force_sample and not actor.ai_enabled and actor.health.current_health>0.0 and state==_last_state and actor.state_time==_last_state_time and actor.clock==_last_clock:
		return # Frozen clocks hold even the last walking pose; a real state change can seek.
	_last_state=state
	_last_state_time=actor.state_time
	_last_clock=actor.clock
	var progress: float=0.0
	var loop: bool=false
	clip_id=&"idle"
	match state:
		&"telegraph":
			clip_id=&"windup_sweep"
			progress=actor.state_time/maxf(0.001,actor.definition.windup)
		&"attack":
			clip_id=&"attack_sweep"
			progress=actor.state_time/maxf(0.001,actor.definition.active)
		&"recover":
			clip_id=&"recover"
			progress=actor.state_time/maxf(0.001,actor.definition.recovery)
		&"hurt":
			clip_id=&"hurt"
			progress=actor.state_time/0.18
		&"dead":
			clip_id=&"death"
			progress=actor.state_time/0.30
		_:
			loop=true
			if moving and state in [&"patrol",&"chase"] and actor.is_on_floor():
				clip_id=&"walk"
				progress=fposmod(walk_phase_radians/TAU,1.0)
			else: progress=fposmod(actor.clock/1.6,1.0)
	selected_progress=clampf(progress,0.0,1.0)
	displayed_facing=-1.0 if facing<0.0 else 1.0
	# Source attack[0] repeats the raised windup[5]; attack[1] is still overhead.
	# Both preparation poses belong before the already-authoritative hitbox opens.
	var committed_frame: int=-1
	if state==&"telegraph":
		if selected_progress>=PRE_STRIKE_WINDUP:
			clip_id=&"attack_sweep"
			committed_frame=1
		else:
			committed_frame=roundi(selected_progress/PRE_STRIKE_WINDUP*5.0)
	elif state==&"attack":
		committed_frame=2 # Forward/down strike from the first active timestamp.
	var entry: Dictionary=_bank[clip_id]
	var textures: Array[AtlasTexture]=entry["textures"]
	frame_index=committed_frame if committed_frame>=0 else mini(textures.size()-1,floori(selected_progress*textures.size())) if loop else roundi(selected_progress*(textures.size()-1))
	frame_data=entry["metadata"]["frames"][frame_index]
	sprite.texture=textures[frame_index]
	sprite.flip_h=displayed_facing<0.0
	sprite.offset=Vector2(-280,-292) if sprite.flip_h else -PIVOT
	sprite.scale=Vector2.ONE*SCALE

func anchor_local(id: String) -> Vector2:
	var values: Array=frame_data.get(id,[168,292])
	var point: Vector2=(Vector2(values[0],values[1])-PIVOT)*SCALE
	point.x*=displayed_facing
	return point

func snapshot() -> Dictionary:
	return {"valid":valid,"clip":clip_id,"frame":frame_index,"progress":selected_progress,"facing":displayed_facing,"canvas":CANVAS,"pivot":PIVOT,"scale":SCALE,"hand":anchor_local("sword_hand"),"front_boot":anchor_local("front_boot_contact"),"back_boot":anchor_local("back_boot_contact"),"front_stance":frame_data.get("contact_front",false),"back_stance":frame_data.get("contact_back",false)}

func release() -> void:
	if is_instance_valid(actor) and is_instance_valid(actor.state_machine) and actor.state_machine.state_changed.is_connected(_on_state_changed):
		actor.state_machine.state_changed.disconnect(_on_state_changed)
	actor=null
	sprite=null
	frame_data={}
	valid=false
