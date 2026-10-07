class_name CampfireVisualSkin
extends Node2D
## Fixed log pivot, animated flame, small real light and finite spatial audio.

const FRAMES: SpriteFrames = preload("res://assets/environment/props/campfire/campfire_frames_v1.tres")
const LIGHT: Texture2D = preload("res://assets/presentation/light_radial.png")
const SPARK: Texture2D = preload("res://assets/presentation/spark.png")
var flame: AnimatedSprite2D
var light: PointLight2D
var embers: GPUParticles2D
var campfire_id: int = 0
var player_id: int = 0
var audio: Node
var sound_deadline: int = 0
var clock: float = 0.0
var _needs_range_exit: bool = false

func bind(fire: Campfire, player: Player) -> void:
	campfire_id = fire.get_instance_id()
	player_id = player.get_instance_id()
	fire.presentation_skin_active = true
	fire.queue_redraw()
	audio = get_node_or_null("/root/AudioManager")
	flame = AnimatedSprite2D.new()
	flame.name = "PaintedFlickeringFire"
	flame.sprite_frames = FRAMES
	flame.centered = false
	flame.offset = Vector2(-271.5, -678)
	flame.scale = Vector2.ONE * 0.085
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var emissive := CanvasItemMaterial.new()
	emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	flame.material = emissive
	add_child(flame)
	flame.play(&"burn")
	light = PointLight2D.new()
	light.name = "WarmFireFlicker"
	light.texture = LIGHT
	light.color = Color(1, 0.52, 0.19)
	light.position = Vector2(0, -20)
	light.texture_scale = 2.0
	light.energy = 0.85
	light.shadow_enabled = false
	add_child(light)
	embers = GPUParticles2D.new()
	embers.name = "QuietEmbers"
	embers.amount = 8
	embers.lifetime = 1.2
	embers.fixed_fps = 30
	embers.texture = SPARK
	embers.position = Vector2(0, -20)
	embers.visibility_rect = Rect2(-45, -80, 90, 110)
	var behavior := ParticleProcessMaterial.new()
	behavior.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	behavior.emission_box_extents = Vector3(9, 2, 0)
	behavior.direction = Vector3(0, -1, 0)
	behavior.spread = 22
	behavior.gravity = Vector3(0, -6, 0)
	behavior.initial_velocity_min = 12
	behavior.initial_velocity_max = 22
	behavior.scale_min = 0.045
	behavior.scale_max = 0.09
	behavior.color = Color(1, 0.56, 0.16, 0.7)
	embers.process_material = behavior
	embers.material = emissive
	embers.emitting = DisplayServer.get_name() != "headless"
	add_child(embers)
	visibility_changed.connect(_visibility_changed)

func _process(delta: float) -> void:
	clock += delta
	light.energy = 0.84 + sin(clock * 8.1) * 0.07 + sin(clock * 13.7) * 0.035
	var player: Player = instance_from_id(player_id) as Player if is_instance_id_valid(player_id) else null
	var near: bool = is_visible_in_tree() and player != null and player.global_position.distance_to(global_position) < 380.0
	if audio == null: return
	if not near:
		if sound_deadline != 0: audio.stop_owner(self)
		sound_deadline = 0
		_needs_range_exit = false
	elif not _needs_range_exit and Time.get_ticks_msec() >= sound_deadline:
		var voice: AudioStreamPlayer2D = audio.play_fire_ambience(global_position + Vector2(0, -20), self)
		sound_deadline = Time.get_ticks_msec() + (ceili(voice.stream.get_length() * 1000.0 / voice.pitch_scale) if voice != null else 1000)

func release_ambience() -> void:
	# A presentation rebuild ends this room's audio generation. A surviving
	# gameplay fire may become audible again only after a real visibility/range
	# exit and new approach, never because its old segment deadline expires.
	if is_instance_valid(audio): audio.stop_owner(self)
	sound_deadline = 0
	_needs_range_exit = true

func _visibility_changed() -> void:
	if not is_visible_in_tree() and audio != null:
		audio.stop_owner(self)
		sound_deadline = 0
		_needs_range_exit = false

func _exit_tree() -> void:
	if is_instance_valid(audio): audio.stop_owner(self)
