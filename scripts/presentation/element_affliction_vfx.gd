class_name ElementAfflictionVFX
extends Node2D
## Actor-owned presentation of live conditions. No damage, status or control writes.

const FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const POISON_TEXTURE: Texture2D = preload("res://assets/vfx/movement/regions/poison_wisp.tres")
const BURN_TEXTURE: Texture2D = preload("res://assets/vfx/movement/regions/burn_flame.tres")
const POISON_COLOR: Color = Color(0.42, 0.78, 0.24)
const BURN_COLOR: Color = Color(1.0, 0.38, 0.08)
var burn: GPUParticles2D
var poison: GPUParticles2D
var burn_visible: bool = false
var poison_visible: bool = false
var material_count: int = 0
var _actor_id: int = 0
var _status_id: int = 0
var _feedback_id: int = 0
var _rig_id: int = 0
var _materials: Array[ShaderMaterial] = []


func _ready() -> void:
	process_physics_priority = 30
	z_index = 7
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func initialize(owner_actor: Node2D, hurt: Hurtbox, feedback: CombatFeedback = null) -> void:
	_actor_id = owner_actor.get_instance_id()
	_status_id = hurt.damage_resolver.status_controller.get_instance_id()
	_feedback_id = feedback.get_instance_id() if is_instance_valid(feedback) else 0
	if burn == null:
		burn = _make_emitter("BurnEmbers", BURN_TEXTURE, BURN_COLOR, 9, true)
		poison = _make_emitter("PoisonWisps", POISON_TEXTURE, POISON_COLOR, 7, false)
	var rig: PlayerVisualRig = owner_actor.get_node_or_null("Visuals") as PlayerVisualRig
	if rig != null:
		_rig_id = rig.get_instance_id()
		if not rig.modular_skin_changed.is_connected(_on_skin_changed):
			rig.modular_skin_changed.connect(_on_skin_changed)
	_refresh_materials()
	refresh_visual()


func _make_emitter(emitter_name: String, stamp: Texture2D, color: Color, count: int, additive: bool) -> GPUParticles2D:
	var particles := GPUParticles2D.new()
	particles.name = emitter_name
	particles.emitting = false
	particles.amount = count
	particles.lifetime = 0.8
	particles.fixed_fps = 60
	particles.local_coords = false
	particles.texture = stamp
	particles.position = Vector2(0.0, -25.0)
	particles.visibility_rect = Rect2(-70.0, -85.0, 140.0, 120.0)
	var behavior := ParticleProcessMaterial.new()
	behavior.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	behavior.emission_box_extents = Vector3(11.0, 16.0, 0.0)
	behavior.direction = Vector3(0.0, -1.0, 0.0)
	behavior.spread = 24.0
	behavior.gravity = Vector3.ZERO
	behavior.initial_velocity_min = 5.0
	behavior.initial_velocity_max = 14.0
	behavior.scale_min = 0.022 if additive else 0.03
	behavior.scale_max = 0.041 if additive else 0.049
	behavior.color = color
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.add_point(0.18, Color(1.0, 1.0, 1.0, 0.72 if additive else 0.48))
	gradient.add_point(0.65, Color(1.0, 1.0, 1.0, 0.46 if additive else 0.28))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	behavior.color_ramp = ramp
	particles.process_material = behavior
	var canvas := CanvasItemMaterial.new()
	canvas.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	canvas.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if additive else CanvasItemMaterial.BLEND_MODE_MIX
	particles.material = canvas
	add_child(particles)
	return particles


func _physics_process(_delta: float) -> void:
	refresh_visual()


func refresh_visual() -> void:
	if burn == null:
		return
	var status: StatusController = instance_from_id(_status_id) as StatusController if is_instance_id_valid(_status_id) else null
	var alive: bool = status != null and status.health != null and status.health.current_health > 0.0
	burn_visible = alive and status.burn_remaining > 0.0
	var element: ElementStatusController = status as ElementStatusController
	poison_visible = alive and element != null and element.poison_count > 0 and element.poison_remaining > 0.0
	var feedback: CombatFeedback = instance_from_id(_feedback_id) as CombatFeedback if is_instance_id_valid(_feedback_id) else null
	var frozen: bool = feedback != null and feedback.is_frozen()
	var gpu: bool = DisplayServer.get_name() != "headless"
	burn.emitting = burn_visible and gpu
	poison.emitting = poison_visible and gpu
	burn.visible = burn_visible
	poison.visible = poison_visible
	burn.speed_scale = 0.0 if frozen else 1.0
	poison.speed_scale = 0.0 if frozen else 1.0
	var color: Color = POISON_COLOR if poison_visible else BURN_COLOR
	if poison_visible and burn_visible:
		color = POISON_COLOR.lerp(BURN_COLOR, 0.4)
	for shader_material: ShaderMaterial in _materials:
		shader_material.set_shader_parameter("status_color", color)
		shader_material.set_shader_parameter("status_strength", 0.2 if poison_visible or burn_visible else 0.0)


func _on_skin_changed() -> void:
	_refresh_materials.call_deferred()


func _refresh_materials() -> void:
	_clear_tint()
	_materials.clear()
	var actor: Node = instance_from_id(_actor_id) as Node if is_instance_id_valid(_actor_id) else null
	if actor == null:
		return
	for node: Node in actor.find_children("*", "Sprite2D", true, false):
		var shader_material: ShaderMaterial = (node as Sprite2D).material as ShaderMaterial
		if shader_material != null and shader_material.shader == FLASH_SHADER and not _materials.has(shader_material):
			_materials.append(shader_material)
	material_count = _materials.size()
	refresh_visual()


func _clear_tint() -> void:
	for shader_material: ShaderMaterial in _materials:
		shader_material.set_shader_parameter("status_strength", 0.0)


func _exit_tree() -> void:
	if is_instance_id_valid(_rig_id):
		var rig: PlayerVisualRig = instance_from_id(_rig_id) as PlayerVisualRig
		if rig != null and rig.modular_skin_changed.is_connected(_on_skin_changed):
			rig.modular_skin_changed.disconnect(_on_skin_changed)
	_clear_tint()
	_materials.clear()
	_actor_id = 0
	_status_id = 0
	_feedback_id = 0
	_rig_id = 0
