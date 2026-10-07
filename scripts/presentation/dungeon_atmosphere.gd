class_name DungeonAtmosphere
extends Node2D
## One world CanvasModulate; room decorations and light budgets are owned here.

const LIGHT: Texture2D = preload("res://assets/presentation/light_radial.png")
const SPARK: Texture2D = preload("res://assets/presentation/spark.png")
const TORCH: SpriteFrames = preload("res://assets/presentation/torch_frames.tres")
const PAINTED_TORCH: SpriteFrames = preload("res://assets/environment/props/campfire/torch_flame_frames_v1.tres")
const VIGNETTE: Shader = preload("res://shaders/dungeon_vignette.gdshader")
var ambient: CanvasModulate
var glow_environment: WorldEnvironment
var room_art: Node2D
var dust: GPUParticles2D
var player_mote: PointLight2D
var actor: Player
var torches: Array[PointLight2D] = []
var clock: float = 0.0
var quiet_motes: GPUParticles2D
var vignette_layer: CanvasLayer
var vignette_rect: ColorRect

func initialize(player: Player) -> void:
	actor = player
	ambient = CanvasModulate.new()
	ambient.name = "DungeonAmbient"
	ambient.color = Color(0.38, 0.40, 0.59)
	add_child(ambient)
	# Godot 4.7 Compatibility supports SDR glow. Higher CanvasLayers keep UI crisp.
	glow_environment = WorldEnvironment.new()
	glow_environment.name = "DungeonCanvasGlow"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_CANVAS
	environment.background_canvas_max_layer = 0
	environment.glow_enabled = true
	# Compatibility uses SDR glow: HDR2D and blend-mode settings are unavailable.
	environment.glow_hdr_threshold = 0.85
	environment.glow_hdr_scale = 0.25
	environment.glow_intensity = 0.42
	environment.glow_bloom = 0.035
	glow_environment.environment = environment
	add_child(glow_environment)
	player_mote = PointLight2D.new()
	player_mote.name = "FloatingPlayerLight"
	player_mote.texture = LIGHT
	player_mote.color = Color(1.0, 0.76, 0.45)
	player_mote.energy = 1.35
	player_mote.texture_scale = 2.5 # 128px radial texture: approximately 160px radius.
	player_mote.shadow_enabled = false
	add_child(player_mote)
	_build_quiet_motes()
	vignette_layer = CanvasLayer.new()
	vignette_layer.name = "WorldVignette"
	vignette_layer.layer = 1
	add_child(vignette_layer)
	vignette_rect = ColorRect.new()
	vignette_rect.name = "SubtleCorners"
	vignette_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vignette_material := ShaderMaterial.new()
	vignette_material.shader = VIGNETTE
	vignette_rect.material = vignette_material
	vignette_layer.add_child(vignette_rect)

func _build_quiet_motes() -> void:
	quiet_motes = GPUParticles2D.new()
	quiet_motes.name = "QuietChiMotes"
	quiet_motes.emitting = false
	quiet_motes.amount = 5
	quiet_motes.lifetime = 2.2
	quiet_motes.fixed_fps = 30
	quiet_motes.local_coords = false
	quiet_motes.texture = SPARK
	quiet_motes.visibility_rect = Rect2(-60, -75, 120, 120)
	var behavior := ParticleProcessMaterial.new()
	behavior.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	behavior.emission_box_extents = Vector3(23, 22, 0)
	behavior.direction = Vector3(0, -1, 0)
	behavior.spread = 30
	behavior.gravity = Vector3.ZERO
	behavior.initial_velocity_min = 3
	behavior.initial_velocity_max = 7
	behavior.scale_min = 0.035
	behavior.scale_max = 0.065
	behavior.color = Color(0.68, 0.83, 0.61, 0.19)
	quiet_motes.process_material = behavior
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	blend.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	quiet_motes.material = blend
	add_child(quiet_motes)

func rebuild(boss_room: bool = false) -> void:
	if is_instance_valid(room_art):
		remove_child(room_art)
		room_art.queue_free()
	torches.clear()
	room_art = Node2D.new()
	room_art.name = "RoomAtmosphere"
	add_child(room_art)
	var backdrop := DungeonBackdrop.new()
	backdrop.boss_room = boss_room
	room_art.add_child(backdrop)
	for location: Vector2 in [Vector2(300, 340), Vector2(630, 305), Vector2(955, 340), Vector2(1120, 500)]:
		var holder := Node2D.new()
		holder.position = location
		room_art.add_child(holder)
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = PAINTED_TORCH
		sprite.scale = Vector2.ONE * 0.075
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var emissive := CanvasItemMaterial.new()
		emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		sprite.material = emissive
		holder.add_child(sprite)
		sprite.play(&"burn")
		var light := PointLight2D.new()
		light.texture = LIGHT
		light.texture_scale = 5.4
		light.color = Color(1.0, 0.59, 0.25)
		light.energy = 1.5
		light.position = Vector2(0, -15)
		light.shadow_enabled = false
		holder.add_child(light)
		torches.append(light)
	_build_dust()

func _build_dust() -> void:
	dust = GPUParticles2D.new()
	dust.name = "AmbientAsh"
	dust.emitting = false
	dust.amount = 72
	dust.lifetime = 8.0
	dust.preprocess = 4.0
	dust.fixed_fps = 30
	dust.texture = SPARK
	dust.position = Vector2(640, 360)
	dust.visibility_rect = Rect2(-680, -400, 1360, 800)
	var behavior := ParticleProcessMaterial.new()
	behavior.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	behavior.emission_box_extents = Vector3(640, 360, 0)
	behavior.direction = Vector3(1, -0.3, 0)
	behavior.spread = 40
	behavior.gravity = Vector3.ZERO
	behavior.initial_velocity_min = 4
	behavior.initial_velocity_max = 12
	behavior.scale_min = 0.12
	behavior.scale_max = 0.32
	behavior.color = Color(0.7, 0.68, 0.85, 0.3)
	dust.process_material = behavior
	var blend := CanvasItemMaterial.new()
	blend.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	blend.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	dust.material = blend
	room_art.add_child(dust)
	dust.emitting = DisplayServer.get_name() != "headless"

func _process(delta: float) -> void:
	clock += delta
	for index: int in torches.size():
		torches[index].energy = 1.45 + sin(clock * 7 + index * 2.1) * 0.07 + sin(clock * 13.7) * 0.03
	if is_instance_valid(actor) and is_instance_valid(player_mote):
		player_mote.global_position = actor.global_position + Vector2(-22 + sin(clock * 2) * 9, -47 + cos(clock * 2.5) * 6)
		quiet_motes.global_position = actor.global_position + Vector2(0, -28)
		var idle: bool = actor.health.current_health > 0.0 and actor.motor.is_grounded() and actor.locomotion_state_machine.get_state_id() == &"idle" and actor.action_state_machine.get_state_id() == &"ready"
		quiet_motes.emitting = idle and DisplayServer.get_name() != "headless"
		quiet_motes.speed_scale = 0.0 if actor.combat_feedback != null and actor.combat_feedback.is_frozen() else 1.0

func _draw() -> void:
	pass
