class_name ElementAfflictionVFX
extends Node2D
## Actor-owned presentation of live conditions. No damage, status or control writes.

const FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const POISON_TEXTURE: Texture2D = preload("res://assets/vfx/movement/regions/poison_wisp.tres")
const BURN_TEXTURE: Texture2D = preload("res://assets/vfx/movement/regions/burn_flame.tres")
const POISON_COLOR: Color = Color(0.42, 0.78, 0.24)
const BURN_COLOR: Color = Color(1.0, 0.38, 0.08)
var _burn_cpu: CompatibilityParticleBurst
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
var ice_progress: float = 0.0
var ice_frozen: bool = false
var ice_seconds: float = 0.0
var reaction_remaining: float = 0.0
var reaction_count: int = 0
var _indicator_y: float = -58.0
var _hurt_id: int = 0
const REACTION_SECONDS: float = 0.5
const ICE_COLOR: Color = Color(0.55,0.9,1.0)


func _ready() -> void:
	process_physics_priority = 30
	z_index = 7
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func initialize(owner_actor: Node2D, hurt: Hurtbox, feedback: CombatFeedback = null) -> void:
	_actor_id = owner_actor.get_instance_id()
	_status_id = hurt.damage_resolver.status_controller.get_instance_id()
	_feedback_id = feedback.get_instance_id() if is_instance_valid(feedback) else 0
	_hurt_id = hurt.get_instance_id()
	if not hurt.hit_resolved.is_connected(_on_resolved): hurt.hit_resolved.connect(_on_resolved)
	_indicator_y = -108.0 if owner_actor is Player else -92.0 if owner_actor is TrainingDummy else -owner_actor.definition.visual_height-14.0 if owner_actor is BaseEnemy else -52.0
	if burn == null:
		burn = _make_emitter("BurnEmbers", BURN_TEXTURE, BURN_COLOR, 9, true)
		# Reuse one bounded CPU emitter only on Compatibility. The authored GPU
		# node remains the parameter source, including the original hit-stop clock.
		_burn_cpu = CompatibilityParticleBurst.attach(burn)
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


func _physics_process(delta: float) -> void:
	var feedback: CombatFeedback = instance_from_id(_feedback_id) as CombatFeedback if is_instance_id_valid(_feedback_id) else null
	if feedback == null or not feedback.is_frozen(): reaction_remaining = maxf(0.0,reaction_remaining-delta)
	refresh_visual()


func refresh_visual() -> void:
	if burn == null:
		return
	var status: StatusController = instance_from_id(_status_id) as StatusController if is_instance_id_valid(_status_id) else null
	var alive: bool = status != null and status.health != null and status.health.current_health > 0.0
	burn_visible = alive and status.burn_remaining > 0.0
	var element: ElementStatusController = status as ElementStatusController
	ice_progress = clampf(element.freeze_meter/100.0,0.0,1.0) if alive and element!=null else 0.0
	ice_seconds = element.freeze_remaining if alive and element!=null else 0.0
	ice_frozen = ice_seconds>0.0
	poison_visible = alive and element != null and element.poison_count > 0 and element.poison_remaining > 0.0
	var feedback: CombatFeedback = instance_from_id(_feedback_id) as CombatFeedback if is_instance_id_valid(_feedback_id) else null
	var frozen: bool = feedback != null and feedback.is_frozen()
	var gpu: bool = DisplayServer.get_name() != "headless"
	burn.emitting = burn_visible and gpu and not is_instance_valid(_burn_cpu)
	poison.emitting = poison_visible and gpu
	burn.visible = burn_visible and not is_instance_valid(_burn_cpu)
	poison.visible = poison_visible
	burn.speed_scale = 0.0 if frozen else 1.0
	poison.speed_scale = 0.0 if frozen else 1.0
	if is_instance_valid(_burn_cpu):
		_burn_cpu.speed_scale = burn.speed_scale
		# Hidden CPU particles stop aging. Clear old world-space particles only
		# on a new burn; extensions and hit-stop must keep the in-flight phase.
		# Preserve the emitter seed instead of consuming global RNG on re-entry.
		if burn_visible and gpu and not _burn_cpu.emitting:
			_burn_cpu.restart(true)
		_burn_cpu.set_emission(burn_visible and gpu)
		_burn_cpu.visible = burn_visible
	var color: Color = POISON_COLOR if poison_visible else BURN_COLOR
	if poison_visible and burn_visible:
		color = POISON_COLOR.lerp(BURN_COLOR, 0.4)
	for shader_material: ShaderMaterial in _materials:
		shader_material.set_shader_parameter("status_color", color)
		shader_material.set_shader_parameter("status_strength", 0.2 if poison_visible or burn_visible else 0.0)
	queue_redraw()


func _on_resolved(_event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage<=0.0 or result.reaction_id!=&"thermal_shock": return
	reaction_remaining = REACTION_SECONDS
	reaction_count += 1
	# The hit-stop sampler may not run again before rendering this contact.
	refresh_visual()


func _draw() -> void:
	if ice_progress<=0.0 and reaction_remaining<=0.0: return
	var font: Font = ThemeDB.fallback_font
	if ice_progress>0.0:
		# Three distinct shards show35/70/100 without covering the actor's pose.
		for n: int in 3:
			var fill: float = clampf(ice_progress*3.0-n,0.0,1.0)
			var at: Vector2 = Vector2((n-1)*10.0,_indicator_y)
			var shape := PackedVector2Array([at+Vector2(0,-5),at+Vector2(3,0),at+Vector2(0,5),at+Vector2(-3,0)])
			draw_colored_polygon(shape,Color(ICE_COLOR,0.15+0.8*fill))
		var text: String = "ĐÓNG BĂNG %.1fs"%(ceilf(ice_seconds*10.0)/10.0) if ice_frozen else "Băng %d%%"%roundi(ice_progress*100)
		draw_string_outline(font,Vector2(24,_indicator_y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color(0.02,0.04,0.06,0.95))
		draw_string(font,Vector2(24,_indicator_y),text,HORIZONTAL_ALIGNMENT_LEFT,-1,12,ICE_COLOR)
		if ice_frozen:
			# Faceted restraint follows the status window; no particle/light/physics node.
			var shell := PackedVector2Array([Vector2(-17,-12),Vector2(-13,-39),Vector2(0,-49),Vector2(16,-34),Vector2(18,-8)])
			draw_polyline(shell,Color(ICE_COLOR,0.7),1.5,true)
	if reaction_remaining>0.0:
		var phase: float = 1.0-reaction_remaining/REACTION_SECONDS
		var fade: float = minf(1.0,reaction_remaining/0.15)
		for n: int in 6:
			var axis: Vector2 = Vector2.from_angle(n*TAU/6.0-PI*0.5)
			var center: Vector2 = Vector2(0,-25)+axis*(10+phase*25)
			draw_line(center,center+axis*7,Color(ICE_COLOR,fade),2,true)
		var text: String = "SỐC NHIỆT"
		var at: Vector2 = Vector2(24,_indicator_y-phase*8)
		draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color(0.03,0.02,0.01,fade))
		draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(1.0,0.65,0.26,fade))


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
	if is_instance_id_valid(_hurt_id):
		var hurt: Hurtbox = instance_from_id(_hurt_id) as Hurtbox
		if hurt!=null and hurt.hit_resolved.is_connected(_on_resolved): hurt.hit_resolved.disconnect(_on_resolved)
	_hurt_id = 0
	reaction_remaining = 0.0
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
