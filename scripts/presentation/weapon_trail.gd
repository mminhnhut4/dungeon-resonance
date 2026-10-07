class_name WeaponTrail
extends Node2D
## Hand-painted slash with bounded mesh fallbacks. Weapon owns every clock.

const TRAIL_SHADER: Shader = preload("res://shaders/weapon_trail.gdshader")
const SEGMENTS: int = 32
const SLASH_SHADER: Shader = preload("res://shaders/handpainted_slash.gdshader")
const WEAPON_LIGHT: Texture2D = preload("res://assets/presentation/light_radial.png")
const SLASH_PATHS: Array[String] = [
	"res://assets/vfx/slashes/regions/common.tres",
	"res://assets/vfx/slashes/regions/rare.tres",
	"res://assets/vfx/slashes/regions/very_rare.tres",
	"res://assets/vfx/slashes/regions/epic.tres",
	"res://assets/vfx/slashes/regions/legendary.tres",
	"res://assets/vfx/slashes/regions/divine.tres",
]
const COMBO_SWEEP_DEGREES: Array[float] = [100.0, 130.0, 160.0]
var _slash_textures: Array[Texture2D] = []

var weapon: Weapon
var feedback: CombatFeedback
var ribbon: MeshInstance2D
var crescent: MeshInstance2D
var style_id: StringName = &"sword"
var tint: Color = Color(0.66, 1.0, 0.93)
var visual_progress: float = 0.0
var rendered_attack_id: int = 0
var vertex_count: int = 0
var crescent_vertex_count: int = 0
var crescent_progress: float = 0.0
const CRESCENT_SWEEP: float = TAU / 3.0
const CRESCENT_SWEEP_SECONDS: float = 0.12
var crescent_ink: MeshInstance2D
var slash_sprite: Sprite2D
var art_enabled: bool = false
var committed_quality: int = 0
var committed_element: StringName = &"physical"
var art_sweep_degrees: float = 100.0
var art_progress: float = 0.0
var _slash_material: ShaderMaterial
var blade_light: PointLight2D
var _material: ShaderMaterial
var _crescent_material: ShaderMaterial
var _snapshot: AttackSnapshot
var _step: AttackStepDefinition
var _geometry := ArrayMesh.new()
var _crescent_geometry := ArrayMesh.new()
var _last_phase: int = -1
var _last_progress: float = -1.0


func _ready() -> void:
	z_index = 6
	# Keep the shared atlas resident for this room's lifetime. Clearing the
	# display sprite at Recovery must not unload/re-upload it on the next hit.
	for path: String in SLASH_PATHS:
		_slash_textures.append(load(path) as Texture2D)
	ribbon = MeshInstance2D.new()
	ribbon.name = "LuminousRibbon"
	ribbon.mesh = _geometry
	_material = ShaderMaterial.new()
	_material.shader = TRAIL_SHADER
	ribbon.material = _material
	add_child(ribbon)
	ribbon.visible = false
	crescent_ink = MeshInstance2D.new()
	crescent_ink.name = "CrescentInkEdge"
	crescent_ink.mesh = _crescent_geometry
	crescent_ink.scale = Vector2.ONE * 1.035
	crescent_ink.self_modulate = Color(0.008, 0.015, 0.019, 0.9)
	var ink_material := CanvasItemMaterial.new()
	ink_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	crescent_ink.material = ink_material
	add_child(crescent_ink)
	crescent_ink.visible = false
	crescent = MeshInstance2D.new()
	crescent.name = "SilverJadeCrescent"
	crescent.mesh = _crescent_geometry
	_crescent_material = ShaderMaterial.new()
	_crescent_material.shader = TRAIL_SHADER
	_crescent_material.set_shader_parameter("trail_color", Color(0.28, 1.0, 0.81))
	_crescent_material.set_shader_parameter("silver_core", 1.0)
	crescent.material = _crescent_material
	add_child(crescent)
	crescent.visible = false
	slash_sprite = Sprite2D.new()
	slash_sprite.name = "HandPaintedSlash"
	# Production cells are 512px wide, with the painted arc origin at (170,256).
	# Centered Sprite offset places that origin on the unchanged Weapon socket.
	slash_sprite.offset = Vector2(86.0, 0.0)
	_slash_material = ShaderMaterial.new()
	_slash_material.shader = SLASH_SHADER
	slash_sprite.material = _slash_material
	crescent.add_child(slash_sprite)
	slash_sprite.visible = false
	blade_light = PointLight2D.new()
	blade_light.name = "CommittedBladeLight"
	blade_light.texture = WEAPON_LIGHT
	blade_light.texture_scale = 0.35
	blade_light.position = Vector2(18.0, 0.0)
	blade_light.shadow_enabled = false
	blade_light.enabled = false
	add_child(blade_light)
	if is_instance_valid(weapon) and weapon.snapshot != null:
		_on_attack_committed(weapon.snapshot)


func bind(next_weapon: Weapon, next_feedback: CombatFeedback = null) -> void:
	_disconnect_weapon()
	_snapshot = null
	_step = null
	rendered_attack_id = 0
	weapon = next_weapon
	feedback = next_feedback
	if ribbon != null:
		ribbon.visible = false
	if crescent != null:
		crescent.visible = false
		crescent_ink.visible = false
		slash_sprite.visible = false
		slash_sprite.texture = null
	art_enabled = false
	art_progress = 0.0
	if blade_light != null:
		blade_light.enabled = false
	if not is_instance_valid(weapon):
		return
	weapon.attack_committed.connect(_on_attack_committed)
	weapon.attack_finished.connect(_on_attack_finished)
	if weapon.snapshot != null:
		_on_attack_committed(weapon.snapshot)


func _process(_delta: float) -> void:
	refresh_visual()


func refresh_visual() -> void:
	if ribbon == null:
		return
	blade_light.enabled = false
	if not is_instance_valid(weapon) or weapon.snapshot == null or _snapshot == null or _step == null:
		ribbon.visible = false
		crescent.visible = false
		crescent_ink.visible = false
		slash_sprite.visible = false
		return
	if weapon.snapshot.attack_id != rendered_attack_id:
		_on_attack_committed(weapon.snapshot)
	if _step.motion == &"punch":
		ribbon.visible = false
		crescent.visible = false
		crescent_ink.visible = false
		slash_sprite.visible = false
		return
	if weapon.phase == Weapon.Phase.NONE or weapon.phase == Weapon.Phase.COMBO_WAIT:
		ribbon.visible = false
		crescent.visible = false
		crescent_ink.visible = false
		slash_sprite.visible = false
		return
	# Weapon's phase clock already stops with the local CombatFeedback hit-stop.
	# Shader has no TIME input, so the luminous pattern also freezes on impact.
	visual_progress = clampf(1.0 - weapon._phase_remaining / maxf(weapon._phase_duration, 0.001), 0.0, 1.0)
	var opacity: float = 1.0
	var arc_progress: float = visual_progress
	match weapon.phase:
		Weapon.Phase.WINDUP:
			opacity = 0.12 + visual_progress * 0.13
			arc_progress = 0.08
		Weapon.Phase.ACTIVE:
			opacity = 0.88
			arc_progress = 0.12 + visual_progress * 0.88
		Weapon.Phase.RECOVERY:
			opacity = pow(1.0 - visual_progress, 2.0) * 0.65
			arc_progress = 1.0
	ribbon.visible = opacity > 0.002
	_material.set_shader_parameter("opacity", opacity)
	_material.set_shader_parameter("animation_phase", visual_progress)
	var melee: bool = _snapshot.weapon_definition.attack_kind == &"melee"
	crescent.visible = melee and weapon.phase != Weapon.Phase.WINDUP and opacity > 0.002
	var crescent_elapsed: float = weapon._phase_duration - weapon._phase_remaining
	if weapon.phase == Weapon.Phase.RECOVERY:
		crescent_elapsed += _step.active_seconds
	var sweep_progress: float = clampf(crescent_elapsed / CRESCENT_SWEEP_SECONDS, 0.0, 1.0)
	var crescent_opacity: float = opacity
	if weapon.phase == Weapon.Phase.RECOVERY:
		crescent_opacity = pow(maxf(0, 1.0 - (weapon._phase_duration - weapon._phase_remaining) / CRESCENT_SWEEP_SECONDS), 2.0) * 0.65
	crescent.visible = crescent.visible and crescent_opacity > 0.002
	crescent_ink.visible = crescent.visible
	crescent_ink.self_modulate.a = crescent_opacity * 0.8
	_crescent_material.set_shader_parameter("opacity", crescent_opacity)
	_crescent_material.set_shader_parameter("animation_phase", visual_progress)
	# The old authored silhouette remains a softer accent under the new silver arc.
	_material.set_shader_parameter("opacity", opacity * (0.45 if melee else 1.0))
	_refresh_art(sweep_progress, crescent_opacity)
	# Exactly one tiny light is owned by this trail. A plain Common sword keeps
	# it off; upgraded/rune imbued blades pulse only on the real Active clock.
	blade_light.enabled = melee and weapon.phase == Weapon.Phase.ACTIVE and (committed_quality >= GearItem.Quality.RARE or committed_element != &"physical")
	if blade_light.enabled:
		blade_light.color = tint
		blade_light.energy = (0.25 + committed_quality * 0.06) * (0.9 + sin(visual_progress * PI) * 0.1)
	if _last_phase != weapon.phase or absf(_last_progress - arc_progress) > 0.002:
		_build_mesh(arc_progress)
		if melee:
			_build_crescent(sweep_progress)
		_last_phase = weapon.phase
		_last_progress = arc_progress


func _on_attack_committed(attack: AttackSnapshot) -> void:
	_snapshot = attack
	rendered_attack_id = attack.attack_id
	var definition: WeaponDefinition = attack.weapon_definition
	if definition == null or attack.cosmetic_combo_index < 0 or attack.cosmetic_combo_index >= definition.combo_steps.size():
		_step = null
		return
	_step = definition.combo_steps[attack.cosmetic_combo_index]
	style_id = &"sword"
	tint = Color(0.66, 1.0, 0.93)
	var pattern: float = 0.0
	match definition.id:
		&"demon_greatsword":
			style_id = &"greatsword"
			tint = Color(1.0, 0.32, 0.055)
		&"gale_dual_daggers", &"shadow_dagger":
			style_id = &"daggers"
			tint = Color(0.67, 0.30, 1.0)
			pattern = 1.0
		&"blood_spiked_whip":
			style_id = &"whip"
			tint = Color(0.23, 0.62, 1.0)
			pattern = 2.0
		&"storm_arcane_staff", &"ritual_staff":
			style_id = &"staff"
			tint = Color(0.52, 0.55, 1.0)
			pattern = 3.0
	committed_quality = attack.cosmetic_quality
	# New families select an authored profile; legacy IDs keep their old contract.
	if definition.visual_profile != &"legacy":
		match definition.visual_profile:
			&"heavy", &"overhead", &"crush": style_id = &"greatsword"
			&"dual": style_id = &"daggers"; pattern = 1.0
			&"chain": style_id = &"whip"; pattern = 2.0
			&"staff", &"fan": style_id = &"staff"; pattern = 3.0
			_: style_id = &"sword"
	committed_element = attack.cosmetic_element
	tint = attack.cosmetic_tint
	art_sweep_degrees = COMBO_SWEEP_DEGREES[mini(attack.cosmetic_combo_index, 2)]
	art_enabled = definition.attack_kind == &"melee" and _step.motion == &"slash"
	if slash_sprite != null:
		slash_sprite.texture = _slash_textures[clampi(committed_quality, 0, 5)] if art_enabled else null
		art_enabled = slash_sprite.texture != null
		_slash_material.set_shader_parameter("element_color", tint)
		# Rarity controls silhouette/radiance, never overrides the rune's hue.
		_slash_material.set_shader_parameter("radiance", [0.95, 1.0, 1.08, 1.24, 1.4, 1.6][clampi(committed_quality, 0, 5)])
	if _material != null:
		_material.set_shader_parameter("trail_color", tint)
		_material.set_shader_parameter("pattern", pattern)
		_crescent_material.set_shader_parameter("trail_color", tint)
	_last_phase = -1
	_last_progress = -1.0
	if crescent != null:
		crescent.self_modulate = Color(1.0, 1.0, 1.0, 0.0 if art_enabled else 1.0)


func _on_attack_finished(attack_id: int) -> void:
	if attack_id != rendered_attack_id:
		return
	_snapshot = null
	_step = null
	if ribbon != null:
		ribbon.visible = false
	if crescent != null:
		crescent.visible = false
		crescent_ink.visible = false
		slash_sprite.visible = false
		slash_sprite.texture = null
	art_enabled = false
	art_progress = 0.0
	if blade_light != null:
		blade_light.enabled = false


func _refresh_art(progress: float, opacity: float) -> void:
	slash_sprite.visible = art_enabled and crescent.visible
	if not art_enabled:
		return
	# Keep the small mesh as data/fallback; its draw is transparent while the
	# art is present. There is only one bright slash, with no extra light pass.
	_crescent_material.set_shader_parameter("opacity", 0.0)
	crescent_ink.self_modulate.a = 0.0
	if weapon.phase != Weapon.Phase.WINDUP:
		_material.set_shader_parameter("opacity", 0.0)
	art_progress = progress
	var eased: float = (1.0 - cos(progress * PI)) * 0.5
	var reverse: float = -1.0 if _snapshot.cosmetic_combo_index % 2 == 1 else 1.0
	slash_sprite.rotation = deg_to_rad(art_sweep_degrees) * (eased - 0.5) * reverse
	slash_sprite.flip_v = reverse < 0.0
	var reach: float = _step.reach if _step.reach > 0.0 else maxf(48.0, _step.hitbox_offset.length() + 20.0)
	slash_sprite.scale = Vector2.ONE * (reach * 2.0 / maxf(slash_sprite.texture.get_width(), 1.0))
	_slash_material.set_shader_parameter("opacity", opacity)


func _build_mesh(progress: float) -> void:
	var reach: float = _step.reach
	if reach <= 0.0:
		reach = maxf(48.0, _step.hitbox_offset.length() + 20.0)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var sweep: float = deg_to_rad(maxf(_step.sweep_angle_degrees, 65.0))
	var width: float = 12.0
	if style_id == &"greatsword":
		width = 28.0
	elif style_id == &"daggers":
		width = 5.0
	elif style_id == &"whip":
		width = 9.0
	elif style_id == &"staff":
		width = 19.0
		reach = 86.0
	var reverse_sweep: float = -1.0 if _snapshot.cosmetic_combo_index % 2 == 1 else 1.0
	for index: int in SEGMENTS + 1:
		var ratio: float = index / float(SEGMENTS)
		var center: Vector2
		var normal: Vector2
		if style_id == &"whip":
			center = Vector2(10.0 + ratio * reach * progress, sin(ratio * TAU * 1.5 + progress * 2.0) * 8.0 * sin(ratio * PI))
			normal = Vector2.UP
		elif _step.motion == &"thrust" and style_id != &"staff":
			center = Vector2(9.0 + ratio * reach * progress, sin(ratio * PI) * 5.0 * reverse_sweep)
			normal = Vector2.UP
		else:
			var angle: float = (-sweep * 0.5 + ratio * sweep * progress) * reverse_sweep
			normal = Vector2.from_angle(angle)
			center = normal * reach
		var thickness: float = width * (0.18 + sin(ratio * PI * 0.5) * 0.82)
		for edge: int in 2:
			var point: Vector2 = center + normal * thickness * (edge - 0.5)
			vertices.append(Vector3(point.x, point.y, 0.0))
			uvs.append(Vector2(ratio, edge))
		if index < SEGMENTS:
			var base: int = index * 2
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_geometry.clear_surfaces()
	_geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	vertex_count = vertices.size()


func _build_crescent(progress: float) -> void:
	# Its origin and rotation are inherited from the committed Weapon socket,
	# while tapering both ends makes a crescent instead of a thick debug arc.
	crescent_progress = progress
	var reach: float = _step.reach
	if reach <= 0.0:
		reach = maxf(48.0, _step.hitbox_offset.length() + 20.0)
	var width: float = clampf(reach * 0.24, 10.0, 30.0)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var reverse: float = -1.0 if _snapshot.cosmetic_combo_index % 2 == 1 else 1.0
	for index: int in SEGMENTS + 1:
		var ratio: float = index / float(SEGMENTS)
		var angle: float = (-CRESCENT_SWEEP * 0.5 + ratio * CRESCENT_SWEEP * progress) * reverse
		var radial: Vector2 = Vector2.from_angle(angle)
		var thickness: float = width * pow(maxf(sin(ratio * PI), 0.0), 0.75)
		for edge: int in 2:
			var point: Vector2 = radial * (reach - thickness * (1 - edge))
			vertices.append(Vector3(point.x, point.y, 0.0))
			uvs.append(Vector2(ratio, edge))
		if index < SEGMENTS:
			var base: int = index * 2
			indices.append_array(PackedInt32Array([base, base + 1, base + 2, base + 1, base + 3, base + 2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	_crescent_geometry.clear_surfaces()
	_crescent_geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	crescent_vertex_count = vertices.size()


func _disconnect_weapon() -> void:
	if not is_instance_valid(weapon):
		return
	if weapon.attack_committed.is_connected(_on_attack_committed):
		weapon.attack_committed.disconnect(_on_attack_committed)
	if weapon.attack_finished.is_connected(_on_attack_finished):
		weapon.attack_finished.disconnect(_on_attack_finished)


func _exit_tree() -> void:
	_disconnect_weapon()
	_snapshot = null
	_step = null
	weapon = null
	feedback = null
