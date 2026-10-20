class_name OpeningRenderWarmup
extends Node
## First-draw Compatibility shader cost belongs to initial loading, not combat.
## The uncomposited viewport owns four bounded render-only particle samples.
## Engine allocation can consume global RNG; game spawn/loot RNG owners are
## independent and never passed here. No profile, physics, input or audio writes.

static var _started: bool = false
const DRAW_FRAMES: int = 8
const LIT_DRAW_START: int = 4
var _draws: int = 0
var _viewport: SubViewport
var _light: PointLight2D

class ParticleSample extends Node2D:
	var process_material: ParticleProcessMaterial
	var stamp: Texture2D
	var particle_rid: RID
	var quad: ArrayMesh
	func _ready() -> void:
		particle_rid = RenderingServer.particles_create()
		RenderingServer.particles_set_mode(particle_rid, RenderingServer.PARTICLES_MODE_2D)
		RenderingServer.particles_set_amount(particle_rid, 4)
		RenderingServer.particles_set_lifetime(particle_rid, 1.0)
		RenderingServer.particles_set_custom_aabb(particle_rid, AABB(Vector3(-128, -128, -1), Vector3(256, 256, 2)))
		RenderingServer.particles_set_process_material(particle_rid, process_material.get_rid())
		quad = ArrayMesh.new()
		var half: Vector2 = stamp.get_size() * 0.5
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), half, Vector2(-half.x, half.y)])
		arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
		arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ARRAY_FLAG_USE_2D_VERTICES)
		RenderingServer.particles_set_draw_passes(particle_rid, 1)
		RenderingServer.particles_set_draw_pass_mesh(particle_rid, 0, quad.get_rid())
		RenderingServer.particles_set_emitting(particle_rid, true)
	func _draw() -> void:
		RenderingServer.canvas_item_add_particles(get_canvas_item(), particle_rid, stamp.get_rid())
	func _exit_tree() -> void:
		if particle_rid.is_valid(): RenderingServer.free_rid(particle_rid)


static func begin(owner_node: Node) -> void:
	if _started or DisplayServer.get_name() == "headless" or RenderingServer.get_current_rendering_method() != "gl_compatibility": return
	_started = true
	var warmup := OpeningRenderWarmup.new()
	warmup.name = "OpeningRenderWarmup"
	owner_node.add_child(warmup)


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(256, 256)
	_viewport.world_2d = World2D.new()
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	var stage := Node2D.new()
	_viewport.add_child(stage)
	# Shader variants use enabled features, not tint/speed/amount: skid (point),
	# foot/contact (point+ramp), burn/poison (box+ramp), and both blend modes.
	for variant: int in 4:
		var sample := ParticleSample.new()
		sample.position = Vector2(128, 128)
		var behavior := ParticleProcessMaterial.new()
		behavior.direction = Vector3(0, -1, 0)
		behavior.gravity = Vector3(0, -12, 0)
		behavior.initial_velocity_min = 10
		behavior.initial_velocity_max = 24
		behavior.scale_min = 0.025
		behavior.scale_max = 0.045
		if variant > 0:
			var gradient := Gradient.new()
			gradient.set_color(0, Color.WHITE)
			gradient.set_color(1, Color(1, 1, 1, 0))
			var ramp := GradientTexture1D.new()
			ramp.gradient = gradient
			behavior.color_ramp = ramp
		if variant == 1:
			behavior.damping_min = 20
			behavior.damping_max = 30
		if variant >= 2:
			behavior.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			behavior.emission_box_extents = Vector3(11, 16, 0)
		sample.process_material = behavior
		sample.stamp = MovementVFX.DUST if variant == 0 else FootstepDust.TEXTURE if variant == 1 else ElementAfflictionVFX.BURN_TEXTURE if variant == 2 else ElementAfflictionVFX.POISON_TEXTURE
		var canvas := CanvasItemMaterial.new()
		canvas.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		canvas.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD if variant in [1, 2] else CanvasItemMaterial.BLEND_MODE_MIX
		sample.material = canvas
		stage.add_child(sample)
	var trail := WeaponTrail.new()
	stage.add_child(trail)
	trail.position = Vector2(128, 128)
	trail.prepare_first_draw()
	# GLES3 specializes even unshaded canvas materials by intersecting lights.
	# Draw each sample first without a light, then with a local warmup light.
	_light = PointLight2D.new()
	_light.position = Vector2(128, 128)
	_light.texture = WeaponTrail.WEAPON_LIGHT
	_light.enabled = false
	stage.add_child(_light)
	RenderingServer.frame_post_draw.connect(_after_draw)


func _after_draw() -> void:
	_draws += 1
	if _draws == LIT_DRAW_START: _light.enabled = true
	if _draws >= DRAW_FRAMES:
		RenderingServer.frame_post_draw.disconnect(_after_draw)
		queue_free.call_deferred()


func _exit_tree() -> void:
	if RenderingServer.frame_post_draw.is_connected(_after_draw):
		RenderingServer.frame_post_draw.disconnect(_after_draw)
	if _draws < DRAW_FRAMES: _started = false
