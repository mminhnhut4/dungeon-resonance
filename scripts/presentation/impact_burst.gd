class_name ImpactBurst
extends Node2D
## Finite directional mineral sparks. One owner/light, no debris sprite sheets.

const MAX_LIFETIME: float = 0.48
const LIGHT_TEXTURE: Texture2D = preload("res://assets/presentation/light_radial.png")
const SPARK_TEXTURE: Texture2D = preload("res://assets/presentation/spark.png")
const MINERAL_SPARK_PATH: String = "res://assets/vfx/movement/regions/hit_spark.tres"
const GROUND_CRACK_PATH: String = "res://assets/vfx/movement/regions/ground_crack.tres"
const IMPACT_WARP: Shader = preload("res://shaders/local_impact_warp.gdshader")
const FINISHER_DECAL_SECONDS: float = 1.0
const FINISHER_WARP_SECONDS: float = 0.12
const ART = preload("res://scripts/presentation/rendered_spell_art.gd")

var element: StringName = &"physical"
var tint: Color = Color(1.0, 0.82, 0.58)
var direction: Vector2 = Vector2.UP
var particles: GPUParticles2D
var flash: PointLight2D
var remaining: float = MAX_LIFETIME
var duration: float = MAX_LIFETIME
var melee_sparks: bool = false
var cosmetic_quality: int = GearItem.Quality.COMMON
var critical_contact: bool = false
var cosmetic_combo_index: int = 0
var peak_light_energy: float = 1.4
var ground_crack: Sprite2D
var shockwave: MeshInstance2D
var _warp_material: ShaderMaterial
var _initialized: bool = false
var _configured_world_position: Vector2 = Vector2.ZERO
var spell_recipe_id: StringName
var _art_layers: Array[Sprite2D] = []
var _art_ready: bool = false


func configure(world_position: Vector2, color: Color, element_id: StringName = &"physical", travel_direction: Vector2 = Vector2.UP) -> void:
	_configured_world_position = world_position
	global_position = world_position
	tint = color
	element = element_id
	direction = travel_direction.normalized() if travel_direction.length_squared() > 0.001 else Vector2.UP
	if _initialized:
		_update_tint()


func configure_spell(world_position: Vector2, travel_direction: Vector2 = Vector2.UP) -> void:
	configure(world_position, Color(0.35, 1.0, 0.76), &"spell_contact", travel_direction)

func configure_spell_art(recipe: StringName) -> void:
	spell_recipe_id = recipe
	if _initialized:
		_update_rendered_art()


func enable_melee_sparks() -> void:
	# Elemental light/rings still identify the installed rune. Contact sparks are
	# warm gold-orange for a readable metal impact, including on a stone wall.
	melee_sparks = true
	if _initialized:
		_update_tint()
		_update_finisher()


func configure_combat(quality: int, critical: bool = false, combo_index: int = 0) -> void:
	cosmetic_quality = clampi(quality, GearItem.Quality.COMMON, GearItem.Quality.DIVINE)
	critical_contact = critical
	cosmetic_combo_index = maxi(0, combo_index)
	if _initialized:
		_update_tint()
		_update_finisher()


func _ready() -> void:
	# Configure-before-attach must keep its world location even if a room or pool
	# has a transform. Tint/element are already set before particle initialization.
	global_position = _configured_world_position
	z_index = 8
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	additive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = additive
	_build_particles()
	_build_light()
	_initialized = true
	_update_tint()
	_update_finisher()
	queue_redraw()


func _build_particles() -> void:
	particles = GPUParticles2D.new()
	particles.name = "ElementSparks"
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 16 if element != &"poison" else 11
	particles.lifetime = 0.34
	particles.fixed_fps = 60
	particles.local_coords = false
	particles.visibility_rect = Rect2(-120.0, -120.0, 240.0, 240.0)
	particles.texture = load(MINERAL_SPARK_PATH) as Texture2D if ResourceLoader.exists(MINERAL_SPARK_PATH) else SPARK_TEXTURE
	particles.material = material
	var behavior := ParticleProcessMaterial.new()
	behavior.direction = Vector3(direction.x, direction.y, 0.0)
	behavior.spread = 48.0
	behavior.gravity = Vector3(0.0, 70.0 if element != &"poison" else -15.0, 0.0)
	behavior.initial_velocity_min = 65.0 if element != &"poison" else 25.0
	behavior.initial_velocity_max = 180.0 if element != &"poison" else 95.0
	behavior.damping_min = 50.0
	behavior.damping_max = 90.0
	var texture_width: float = maxf(1.0, particles.texture.get_width())
	behavior.scale_min = 3.0 / texture_width
	behavior.scale_max = (10.0 if element == &"ice" else 7.0) / texture_width
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	behavior.color_ramp = ramp
	particles.process_material = behavior
	add_child(particles)
	# Dummy rendering does not execute GPU simulation or its finished signal.
	# The independent finite owner clock below is the cleanup contract in both modes.
	if DisplayServer.get_name() != "headless":
		particles.emitting = true


func _build_light() -> void:
	flash = PointLight2D.new()
	flash.name = "ImpactLight"
	flash.texture = LIGHT_TEXTURE
	flash.texture_scale = 1.1
	flash.energy = 1.4
	flash.shadow_enabled = false
	add_child(flash)


func _update_tint() -> void:
	_update_rendered_art()
	if flash != null:
		flash.color = tint
		peak_light_energy = 0.55 + cosmetic_quality * 0.17 if melee_sparks or element == &"physical" else 1.4
		flash.energy = peak_light_energy
	if particles != null:
		var behavior: ParticleProcessMaterial = particles.process_material as ParticleProcessMaterial
		behavior.color = Color(1.0, 0.66, 0.16) if melee_sparks or element == &"physical" else tint
		if element == &"spell_contact":
			behavior.color = Color.WHITE
			var gradient := Gradient.new()
			gradient.set_color(0, Color(1.0, 0.83, 0.24))
			gradient.set_color(1, Color(0.2, 0.9, 0.65, 0.0))
			gradient.add_point(0.42, Color(0.3, 1.0, 0.79))
			var ramp := GradientTexture1D.new()
			ramp.gradient = gradient
			behavior.color_ramp = ramp
		var spark_direction: Vector2 = -direction if melee_sparks or element == &"physical" else direction
		behavior.direction = Vector3(spark_direction.x, spark_direction.y, 0.0)
		behavior.gravity = Vector3(0.0, 70.0 if element != &"poison" else -15.0, 0.0)
		behavior.initial_velocity_min = 65.0 if element != &"poison" else 25.0
		behavior.initial_velocity_max = 180.0 if element != &"poison" else 95.0
		var texture_width: float = maxf(1.0, particles.texture.get_width())
		behavior.scale_min = 3.0 / texture_width
		behavior.scale_max = (10.0 if element == &"ice" else 7.0) / texture_width
		particles.amount = mini(14, 10 + cosmetic_quality) if melee_sparks or element == &"physical" else 11 if element == &"poison" else 16
		behavior.spread = 42.0 if melee_sparks or element == &"physical" else 65.0

func _update_rendered_art() -> void:
	if melee_sparks or element == &"physical":
		_art_ready = false
		for sprite: Sprite2D in _art_layers: sprite.visible = false
		return
	if _art_layers.is_empty(): _art_layers = ART.make_layers(self)
	_art_ready = ART.configure(_art_layers, ART.CONTACT, spell_recipe_id, element)
	_seek_rendered_art()

func _seek_rendered_art() -> void:
	if not _art_ready: return
	var fade: float = clampf(1.0 - (duration - remaining) / MAX_LIFETIME, 0.0, 1.0)
	var age: float = 1.0 - fade
	# Painted debris stays finite and follows the same accepted-contact clock.
	ART.seek(_art_layers, Vector2.ONE * (68.0 + age * 38.0), pow(fade, 1.5), duration - remaining, ART.CONTACT, spell_recipe_id, tint)
	for sprite: Sprite2D in _art_layers: sprite.rotation += direction.angle()


func _update_finisher() -> void:
	if not _initialized or not melee_sparks or cosmetic_quality < GearItem.Quality.EPIC or cosmetic_combo_index < 2 or ground_crack != null:
		return
	if not ResourceLoader.exists(GROUND_CRACK_PATH):
		return
	duration = FINISHER_DECAL_SECONDS
	remaining = duration
	ground_crack = Sprite2D.new()
	ground_crack.name = "FiniteGroundCrack"
	ground_crack.texture = load(GROUND_CRACK_PATH) as Texture2D
	ground_crack.scale = Vector2(0.22, 0.1)
	ground_crack.position = Vector2(0.0, 16.0)
	ground_crack.z_index = -1
	# Dark painted mineral marks use normal alpha blending, not additive glow.
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ground_crack.material = ink
	add_child(ground_crack)
	var quad := QuadMesh.new()
	quad.size = Vector2(96.0, 96.0)
	shockwave = MeshInstance2D.new()
	shockwave.name = "LocalFinisherShockwave"
	shockwave.mesh = quad
	_warp_material = ShaderMaterial.new()
	_warp_material.shader = IMPACT_WARP
	_warp_material.set_shader_parameter("edge_color", tint)
	shockwave.material = _warp_material
	add_child(shockwave)


func _process(delta: float) -> void:
	remaining = maxf(0.0, remaining - delta)
	if flash != null:
		var flash_fade: float = clampf(1.0 - (duration - remaining) / MAX_LIFETIME, 0.0, 1.0)
		flash.energy = peak_light_energy * pow(flash_fade, 3.0)
	if ground_crack != null:
		ground_crack.modulate.a = pow(clampf(remaining / FINISHER_DECAL_SECONDS, 0.0, 1.0), 0.75) * 0.72
		var warp_progress: float = clampf((duration - remaining) / FINISHER_WARP_SECONDS, 0.0, 1.0)
		shockwave.visible = warp_progress < 1.0
		_warp_material.set_shader_parameter("wave_radius", 0.08 + warp_progress * 0.9)
		_warp_material.set_shader_parameter("opacity", (1.0 - warp_progress) * 0.6)
	_seek_rendered_art()
	queue_redraw()
	if remaining <= 0.0:
		queue_free()


func _draw() -> void:
	if _art_ready: return
	var fade: float = clampf(1.0 - (duration - remaining) / MAX_LIFETIME, 0.0, 1.0)
	var age: float = 1.0 - fade
	if melee_sparks or element == &"physical":
		# A small crisp contact star rather than a full-screen radial explosion.
		var spark_color := Color(1.0, 0.87, 0.48, pow(fade, 3.0))
		var normal: Vector2 = direction.orthogonal()
		var size: float = 4.0 + (2.0 if critical_contact else 0.0)
		draw_line(-direction * size, direction * size, spark_color, 1.4, true)
		draw_line(-normal * size * 0.65, normal * size * 0.65, spark_color, 1.2, true)
		return
	var ring_color := Color(tint.r, tint.g, tint.b, fade * fade * 0.8)
	draw_arc(Vector2.ZERO, 6.0 + age * 27.0, 0.0, TAU, 28, ring_color, 2.0, true)
	var bright := Color(1.0, 0.97, 0.89, pow(fade, 4.0))
	draw_circle(Vector2.ZERO, 4.5 + age * 3.0, bright)
	if element in [&"fire",&"spell_contact",&"poison"]:
		# Directional fractures originate at the accepted contact, rather than
		# a generic faint circle detached from the projectile's travel direction.
		for index: int in 5:
			var angle: float=direction.angle()+(index-2)*0.45
			var ray: Vector2=Vector2.from_angle(angle)
			var distance: float=12.0+age*34.0
			var stroke:=PackedVector2Array([ray*4.0,ray*distance*0.55+ray.orthogonal()*3.0,ray*distance])
			draw_polyline(stroke,Color(0.03,0.02,0.015,fade*fade),4.5,true)
			draw_polyline(stroke,ring_color,2.0,true)
	if element == &"wind":
		for index: int in 3:
			draw_arc(Vector2.ZERO,8.0+age*28.0+index*4.0,direction.angle()-PI*0.55,direction.angle()+PI*0.55,18,ring_color,2.0,true)
	elif element == &"lightning":
		for index: int in 4:
			var point: Vector2 = Vector2.from_angle(index * PI * 0.5 + 0.3) * (12.0 + age * 24.0)
			draw_polyline(PackedVector2Array([Vector2.ZERO, point * 0.45 + Vector2(4.0, -4.0), point]), ring_color, 1.8, true)
	elif element == &"ice":
		for index: int in 5:
			var point: Vector2 = Vector2.from_angle(index * TAU / 5.0) * (8.0 + age * 25.0)
			draw_line(point * 0.5, point, ring_color, 2.5, true)
