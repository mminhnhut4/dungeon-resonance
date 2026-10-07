class_name WorldEnemyVisual
extends Node2D
## Approved static atlas + physics-observed motion/VFX. Never advances attack clocks.

const FLASH: Shader = preload("res://shaders/hit_flash.gdshader")
const SOLID_ALPHA_CACHE: StringName = &"world_enemy_solid_geometry_v1"
var actor: BaseEnemy
var sprite: Sprite2D
var geometry: Dictionary = {}
var motion: Node2D
var shadow: ActorShadow
var trail: PackedVector2Array = []
var shatter_remaining: float = 0.0
var _last_shield: float = 0.0
var _material: ShaderMaterial
var walk_phase: float = 0.0
var displayed_facing: float = -1.0
var active_cue_count: int = 0
var hit_reaction_count: int = 0
var active_cue_remaining: float = 0.0
var _last_position: Vector2
var _last_state: StringName = &""
var _hit_remaining: float = 0.0
var _hit_axis: float = 1.0
var _was_grounded: bool = false
var _landing_remaining: float = 0.0
var sweep_vfx: GuardSweepVFX
var body_frames: GuardBodyFrames

func bind(target: BaseEnemy) -> void:
	actor = target
	motion = Node2D.new()
	add_child(motion)
	sprite = Sprite2D.new()
	sprite.name = "ApprovedEnemySprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	motion.add_child(sprite)
	var art_id: String = ["guard", "bat", "wraith", "champion"][actor.definition.moveset]
	var path: String = "res://assets/sprites/enemies/regions/world_%s.tres" % art_id
	if actor.definition.id == &"ancient_guard":
		body_frames = GuardBodyFrames.new()
		if body_frames.bind(actor, sprite):
			geometry = {"foot_pixel":GuardBodyFrames.PIVOT,"bounds":Rect2i(0,0,448,320),"authored_frames":true}
		else:
			body_frames.release()
			body_frames = null
	if body_frames == null and ResourceLoader.exists(path):
		geometry = _configure_sprite(load(path) as Texture2D, actor.definition.visual_height)
	_material = ShaderMaterial.new()
	_material.shader = FLASH
	sprite.material = _material
	shadow = ActorShadow.new()
	add_child(shadow)
	shadow.bind(actor, Vector2.ZERO, actor.definition.body_size.x + 8, 6, actor.combat_feedback)
	_last_shield = (actor.health as EnemyShieldHealth).current_shield if actor.health is EnemyShieldHealth else 0.0
	_last_position = actor.global_position
	displayed_facing = actor.facing
	_was_grounded = actor.is_on_floor()
	actor.hurtbox.hit_resolved.connect(_on_visual_hit)
	process_physics_priority = 15
	if actor.definition.moveset == WorldEnemyData.Moveset.SABER_SWEEP and get_tree().get_nodes_in_group(&"guard_sweep_vfx").size() < GuardSweepVFX.MAX_OWNERS:
		sweep_vfx = GuardSweepVFX.new()
		add_child(sweep_vfx)
		sweep_vfx.bind(actor, self)

func _configure_sprite(texture: Texture2D, height: float) -> Dictionary:
	# Very faint atmospheric edge pixels must not become the ground pivot.
	# Cache once on the imported atlas, without altering the source raster.
	var result: Dictionary = texture.get_meta(SOLID_ALPHA_CACHE, {})
	if result.is_empty():
		var image: Image = texture.get_image()
		if image.is_compressed() and image.decompress() != OK: return {}
		image.convert(Image.FORMAT_RGBA8)
		var pixels: PackedByteArray = image.get_data()
		var width: int = image.get_width()
		var min_x: int = width
		var min_y: int = image.get_height()
		var max_x: int = -1
		var max_y: int = -1
		for y: int in image.get_height():
			for x: int in width:
				if pixels[(y * width + x) * 4 + 3] < 32: continue
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
		if max_x < min_x: return {}
		var bounds := Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
		var foot_left: int = width
		var foot_right: int = -1
		for y: int in range(maxi(min_y, max_y - 3), max_y + 1):
			for x: int in range(min_x, max_x + 1):
				if pixels[(y * width + x) * 4 + 3] >= 32:
					foot_left = mini(foot_left, x)
					foot_right = maxi(foot_right, x)
		result = {"bounds": bounds, "ground_foot": Vector2((foot_left + foot_right + 1) * 0.5, bounds.end.y), "air_foot": Vector2(bounds.get_center().x, bounds.end.y)}
		texture.set_meta(SOLID_ALPHA_CACHE, result)
	var configured: Dictionary = result.duplicate()
	configured["foot_pixel"] = result["air_foot"] if actor.definition.flying else result["ground_foot"]
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * (height / float(result["bounds"].size.y))
	EnemySpriteArt.set_facing(sprite, configured["foot_pixel"], false)
	return configured

func _physics_process(delta: float) -> void:
	if actor == null: return
	if is_instance_valid(actor.combat_feedback) and actor.combat_feedback.is_frozen(): return
	var state: StringName = actor.state_machine.get_state_id()
	var height: float = actor.definition.visual_height
	var step_delta: float = maxf(0.0, delta)
	var grounded: bool = actor.is_on_floor()
	var distance: float = absf(actor.global_position.x - _last_position.x)
	_last_position = actor.global_position
	if state in [&"patrol", &"chase"] and grounded and distance < 32.0:
		# A stopped/wall-blocked actor has no walking phase. Teleports do not kick it.
		walk_phase = fmod(walk_phase + distance * TAU / 36.0, TAU)
	if grounded and not _was_grounded: _landing_remaining = 0.16
	_was_grounded = grounded
	_landing_remaining = maxf(0.0, _landing_remaining - step_delta)
	_hit_remaining = maxf(0.0, _hit_remaining - step_delta)
	active_cue_remaining = maxf(0.0, active_cue_remaining - step_delta)
	if state != _last_state:
		if state == &"attack":
			active_cue_count += 1
			active_cue_remaining = minf(0.12, actor.definition.active)
		else: active_cue_remaining = 0.0
		if state in [&"hurt", &"dead"]: trail.clear()
		_last_state = state
	_update_facing(state)
	var target_position := Vector2.ZERO
	var target_rotation: float = 0.0
	var target_scale := Vector2.ONE
	var opacity: float = 1.0
	if actor.definition.flying:
		target_position.y = height * 0.5 - actor.definition.body_size.y * 0.5 + sin(actor.clock * 3) * 2
		target_rotation = sin(actor.clock * 5) * 0.03
	else:
		# Grounded poses rotate/scale around the existing foot; never float the PNG.
		var speed_weight: float = clampf(absf(actor.velocity.x) / maxf(1.0, actor.definition.chase_speed), 0, 1)
		if state in [&"patrol", &"chase"] and grounded:
			target_scale.y = 1.0 + sin(walk_phase) * 0.018 * speed_weight
			target_rotation = displayed_facing * sin(walk_phase) * 0.035 * speed_weight
		else: target_scale.y = 1.0 + sin(actor.clock * 4) * 0.01
		if _landing_remaining > 0:
			target_scale += Vector2(0.05, -0.05) * sin(_landing_remaining / 0.16 * PI)
	if state == &"telegraph":
		var progress: float = clampf(actor.state_time / actor.definition.windup, 0, 1)
		var preparation: float = sin(progress * PI * 0.5)
		target_rotation -= actor.facing * (0.16 if actor.attack_kind == &"sweep" else 0.10) * preparation
		target_scale += Vector2(0.035, -0.035) * preparation
	if actor.definition.moveset == WorldEnemyData.Moveset.BAT_DIVE:
		target_scale.x = 1.0 + sin(actor.clock * 15) * 0.10
		target_rotation = actor.locked_direction.angle() * 0.16 if state == &"attack" and actor.attack_kind == &"dive" else target_rotation
	if actor.definition.moveset == WorldEnemyData.Moveset.PHASE_THRUST and state == &"telegraph":
		var progress: float = actor.state_time / actor.definition.windup
		opacity = lerpf(1.0, 0.10, progress / 0.3) if progress < 0.3 else 0.10 if progress < 0.6 else lerpf(0.10, 1.0, (progress - 0.6) / 0.4)
	if state == &"attack":
		if actor.attack_kind == &"sweep": target_rotation = actor.facing * lerpf(-0.22, 0.23, actor.state_time / actor.definition.active)
		if actor.attack_kind in [&"phase_thrust", &"dive"]:
			trail.append(actor.global_position + Vector2(0, -20))
			if trail.size() > 10: trail.remove_at(0)
	else:
		if not trail.is_empty(): trail.remove_at(0)
	if state == &"hurt" or _hit_remaining > 0.0:
		var recoil: float = sin(clampf(_hit_remaining / 0.18, 0, 1) * PI)
		target_rotation += _hit_axis * recoil * 0.14
		target_scale += Vector2(0.04, -0.04) * recoil
	# Exponential damping uses gameplay delta; state exits cannot reset the pose.
	var blend: float = 1.0 - exp(-24.0 * step_delta)
	motion.rotation = lerp_angle(motion.rotation, target_rotation, blend)
	motion.scale = motion.scale.lerp(target_scale, blend)
	motion.position = motion.position.lerp(target_position, blend) if actor.definition.flying else Vector2.ZERO
	if body_frames != null:
		# These PNGs already contain joint motion; preserve their common physical root.
		motion.position = Vector2.ZERO
		motion.rotation = 0.0
		motion.scale = Vector2.ONE
		body_frames.seek_actor(walk_phase,displayed_facing,distance>0.001 and distance<32.0)
	if state == &"dead": opacity = maxf(0.0, 1.0 - actor.state_time / 0.3)
	if not geometry.is_empty(): EnemySpriteArt.set_facing(sprite, geometry["foot_pixel"], displayed_facing < 0)
	sprite.modulate = Color(1, 0.38, 0.30, opacity) if actor.flash_remaining > 0.0 else Color(1, 0.50, 0.40, opacity) if actor.enraged else Color(1, 1, 1, opacity)
	_material.set_shader_parameter("flash", 1.0 if actor.flash_remaining > 0.075 else 0.0)
	shatter_remaining = maxf(0.0, shatter_remaining - delta)
	if actor.health is EnemyShieldHealth:
		var current: float = (actor.health as EnemyShieldHealth).current_shield
		if _last_shield > 0.0 and current <= 0.0: shatter_remaining = 0.4
		_last_shield = current
	queue_redraw()

func _update_facing(state: StringName) -> void:
	if state in [&"telegraph", &"attack"]:
		displayed_facing = actor.facing # The committed attack direction stays exact.
	elif state in [&"patrol", &"chase"] and absf(actor.velocity.x) > 8.0:
		displayed_facing = signf(actor.velocity.x)
	elif not is_instance_valid(actor.player) or absf(actor.player.global_position.x - actor.global_position.x) > 6.0:
		displayed_facing = actor.facing

func _on_visual_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0.0 or event.source_kind == DamageEvent.SourceKind.DOT: return
	_hit_remaining = 0.18
	_hit_axis = signf(event.attack_direction.x) if absf(event.attack_direction.x) > 0.1 else actor.facing
	hit_reaction_count += 1
	if actor.state_machine.get_state_id() != &"attack":
		active_cue_remaining = 0.0
		trail.clear()

func _exit_tree() -> void:
	if body_frames != null: body_frames.release()
	if is_instance_valid(actor) and is_instance_valid(actor.hurtbox) and actor.hurtbox.hit_resolved.is_connected(_on_visual_hit):
		actor.hurtbox.hit_resolved.disconnect(_on_visual_hit)
	actor = null

func _draw() -> void:
	if actor == null: return
	var state: StringName = actor.state_machine.get_state_id()
	var center := Vector2(0, -actor.definition.body_size.y * 0.5)
	if sprite.texture == null:
		# Temporary semantic silhouette only if approved art is unavailable.
		draw_circle(center, actor.definition.body_size.x * 0.5, Color(0.4, 0.55, 0.48))
	if state == &"telegraph":
		var target: Vector2 = to_local(actor.locked_target)
		var color := Color(0.8, 0.58, 0.3) if actor.attack_kind == &"sweep" else Color(0.3, 1, 0.6) if actor.attack_kind in [&"dive", &"jade_bolt", &"slow_field"] else Color(0.72, 0.40, 1)
		if actor.attack_kind == &"slow_field": draw_arc(target + Vector2(0, 18), 64, 0, TAU, 32, Color(color, 0.55), 2)
		elif actor.attack_kind == &"sweep":
			if not is_instance_valid(sweep_vfx): draw_arc(center, 68, -PI * 0.3 if actor.facing > 0 else PI * 0.7, PI * 0.3 if actor.facing > 0 else PI * 1.3, 18, Color(color, 0.5), 2)
		else:
			draw_line(center, target, Color(color, 0.45), 1.5)
			draw_circle(target, 10, Color(color, 0.18))
	if state == &"attack" and actor.attack_kind == &"sweep" and not is_instance_valid(sweep_vfx):
		var start: float = lerpf(-1.7, 0.3, actor.state_time / actor.definition.active)
		if actor.facing < 0: start += PI
		draw_arc(center, 68, start, start + 1.5, 20, Color(1.0, 0.85, 0.52, 0.8), 5)
		draw_arc(center, 70, start, start + 1.5, 20, Color(1.0, 0.98, 0.85), 1.5)
	if active_cue_remaining > 0.0 and state == &"attack" and not is_instance_valid(sweep_vfx):
		# Launch cue, not a hit-confirm spark: still visible with sound/shake off.
		var direction: Vector2 = actor.locked_direction
		var color := Color(0.8, 0.58, 0.3) if actor.attack_kind == &"sweep" else Color(0.3, 1, 0.6) if actor.attack_kind in [&"dive", &"jade_bolt", &"slow_field"] else Color(0.72, 0.40, 1)
		var progress: float = 1.0 - active_cue_remaining / minf(0.12, actor.definition.active)
		var tip: Vector2 = center + direction * (16.0 + progress * 16.0)
		draw_arc(tip, 7.0 + progress * 9.0, direction.angle() - 1.0, direction.angle() + 1.0, 12, Color(color, 1.0 - progress), 2)
	for index: int in range(1, trail.size()):
		var color := Color(0.72, 0.35, 1) if actor.attack_kind == &"phase_thrust" else Color(0.3, 1, 0.62)
		draw_line(to_local(trail[index - 1]), to_local(trail[index]), Color(color, float(index) / trail.size() * 0.6), 7)
	if _last_shield > 0.0:
		draw_arc(center, 43, 0, TAU, 32, Color(0.35, 0.9, 0.67, 0.7), 2)
	if shatter_remaining > 0.0:
		var radius: float = 43 + (0.4 - shatter_remaining) * 90
		for index: int in 12:
			var vector: Vector2 = Vector2.from_angle(index * TAU / 12)
			draw_line(center + vector * radius, center + vector * (radius + 7), Color(0.4, 1, 0.7, shatter_remaining / 0.4), 2)
