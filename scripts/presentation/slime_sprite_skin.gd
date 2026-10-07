class_name SlimeSpriteSkin
extends Node2D
## Read-only sprite adapter; the hidden Body keeps existing feedback/FSM values.

const SPRITE_TEXTURE: Texture2D = preload("res://assets/sprites/enemies/enemy_slime.png")
const FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const NORMAL_HEIGHT: float = 36.0
const ICE_TINT: Color = Color(0.50, 0.82, 1.25)
const POISON_TINT: Color = Color(0.92, 0.55, 1.08)

var sprite: Sprite2D
var geometry: Dictionary = {}
var tint: Color = Color.WHITE
var _actor_id: int = 0
var _body: Polygon2D
var _eyes: Line2D
var _body_visible: bool = true
var _eyes_visible: bool = true
var _eyes_z_index: int = 0
var _eyes_position: Vector2 = Vector2.ZERO
var _material: ShaderMaterial
var motion: Node2D
var actor_shadow: ActorShadow
var clock: float = 0.0
var _was_grounded: bool = true
var _landing_clock: float = 1.0
var walk_phase: float = 0.0
var displayed_facing: float = -1.0
var active_cue_count: int = 0
var hit_reaction_count: int = 0
var active_cue_remaining: float = 0.0
var _last_position: Vector2
var _bite_was_active: bool = false
var _hit_remaining: float = 0.0
var _hit_axis: float = 1.0


func bind(owner_actor: Node2D) -> void:
	_restore_placeholders()
	_actor_id = owner_actor.get_instance_id() if is_instance_valid(owner_actor) else 0
	if _actor_id == 0:
		active_cue_remaining = 0.0
		_hit_remaining = 0.0
		queue_redraw()
		if sprite != null:
			sprite.visible = false
		if is_instance_valid(actor_shadow):
			actor_shadow.bind(null)
		return
	_body = owner_actor.get_node("Body") as Polygon2D
	_eyes = owner_actor.get_node("Eyes") as Line2D
	_body_visible = _body.visible
	_eyes_visible = _eyes.visible
	_eyes_z_index = _eyes.z_index
	_eyes_position = _eyes.position
	_body.visible = false
	_eyes.visible = false
	_eyes.z_index = z_index + 1
	_eyes.position.y = -NORMAL_HEIGHT * 0.72
	if sprite == null:
		motion = Node2D.new()
		motion.name = "SlimeFootDynamics"
		add_child(motion)
		sprite = Sprite2D.new()
		sprite.name = "SlimeSprite"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		motion.add_child(sprite)
		_material = ShaderMaterial.new()
		_material.shader = FLASH_SHADER
		sprite.material = _material
	geometry = EnemySpriteArt.configure(sprite, SPRITE_TEXTURE, NORMAL_HEIGHT)
	clock = 0.0
	_landing_clock = 1.0
	walk_phase = 0.0
	displayed_facing = float(owner_actor.get("_facing"))
	_last_position = owner_actor.global_position
	_bite_was_active = false
	_hit_remaining = 0.0
	active_cue_remaining = 0.0
	active_cue_count = 0
	hit_reaction_count = 0
	motion.scale = Vector2.ONE
	motion.position = Vector2.ZERO
	motion.rotation = 0.0
	var body: CharacterBody2D = owner_actor as CharacterBody2D
	_was_grounded = body.is_on_floor() if body != null else true
	if actor_shadow == null:
		actor_shadow = ActorShadow.new()
		actor_shadow.name = "ActorShadow"
		add_child(actor_shadow)
	actor_shadow.bind(body, Vector2.ZERO, 32.0, 6.0)
	(owner_actor as SlimeEnemy).hurtbox.hit_resolved.connect(_on_visual_hit)
	sprite.visible = true
	refresh_skin()


func _ready() -> void:
	z_index = 1
	process_physics_priority = 15
	if _actor_id == 0 and get_parent() is CharacterBody2D:
		bind(get_parent() as Node2D)


func _physics_process(delta: float) -> void:
	if _actor_id == 0:
		return
	if not is_instance_id_valid(_actor_id):
		queue_free()
		return
	var actor: SlimeEnemy = instance_from_id(_actor_id) as SlimeEnemy
	if actor == null:
		return
	actor_shadow.set_feedback(actor.combat_feedback)
	if is_instance_valid(actor.combat_feedback) and actor.combat_feedback.is_frozen():
		return
	clock += maxf(delta, 0.0)
	_sync_pose(actor, maxf(delta, 0.0))
	refresh_skin(true)
	queue_redraw()


func _sync_pose(actor: SlimeEnemy, delta: float) -> void:
	var state: StringName = actor.state_machine.get_state_id()
	var grounded: bool = actor.is_on_floor()
	if grounded and not _was_grounded:
		_landing_clock = 0.0
	_was_grounded = grounded
	_landing_clock += delta
	var distance: float = absf(actor.global_position.x - _last_position.x)
	_last_position = actor.global_position
	if grounded and state in [&"patrol", &"chase"] and distance < 32.0:
		walk_phase = fmod(walk_phase + distance * TAU / 28.0, TAU)
	_hit_remaining = maxf(0.0, _hit_remaining - delta)
	if actor.last_damage_event == null: _hit_remaining = 0.0 # Existing home reset.
	active_cue_remaining = maxf(0.0, active_cue_remaining - delta)
	var bite_active: bool = state == &"attack" and actor.bite_hitbox.active
	if bite_active and not _bite_was_active:
		active_cue_count += 1
		active_cue_remaining = 0.12
	if not bite_active: active_cue_remaining = 0.0
	_bite_was_active = bite_active
	if state == &"attack" and actor._state_time < actor.telegraph_seconds + 0.12:
		displayed_facing = actor._facing
	elif state in [&"patrol", &"chase"] and absf(actor.velocity.x) > 8.0:
		displayed_facing = signf(actor.velocity.x)
	elif not is_instance_valid(actor.player) or absf(actor.player.global_position.x - actor.global_position.x) > 6.0:
		displayed_facing = actor._facing
	var target_position := Vector2.ZERO
	var target_scale := Vector2.ONE
	var target_rotation: float = 0.0
	if state == &"attack":
		# The current AI lunges along the floor. This tiny visual hop follows its
		# existing bite clock; it deliberately adds no jump to the physical FSM.
		target_scale = ProceduralAnimator.slime_attack_scale(actor._state_time, actor.telegraph_seconds)
		target_position.y = ProceduralAnimator.slime_hop_offset(actor._state_time, actor.telegraph_seconds)
	elif not grounded and absf(actor.velocity.y) > 1.0:
		target_scale = ProceduralAnimator.AIR_SCALE
	elif _landing_clock < 0.30:
		target_scale = ProceduralAnimator.landing_scale(_landing_clock)
	elif state in [&"patrol", &"chase"]:
		var weight: float = clampf(absf(actor.velocity.x) / maxf(1.0, actor.chase_speed), 0, 1)
		if absf(actor.velocity.x) < 8.0:
			target_scale.y = ProceduralAnimator.breathing_scale(clock)
		else:
			# Static PNG approximation: a distance-driven compress/release gait.
			var step: float = sin(walk_phase) * weight
			target_scale = Vector2(1.0 + step * 0.06, 1.0 - step * 0.045)
			target_rotation = displayed_facing * step * 0.035
	if _hit_remaining > 0.0:
		var recoil: float = sin(_hit_remaining / 0.18 * PI)
		target_rotation += _hit_axis * recoil * 0.14
		target_scale += Vector2(0.05, -0.05) * recoil
	# Zero-delta sync remains an explicit pose sample for editor/legacy fixtures.
	var blend: float = 1.0 - exp(-28.0 * delta) if delta > 0.0 else 1.0
	motion.scale = motion.scale.lerp(target_scale, blend)
	motion.rotation = lerp_angle(motion.rotation, target_rotation, blend)
	motion.position = motion.position.lerp(target_position, blend)
	if state != &"attack": motion.position = Vector2.ZERO
	_eyes.position.y = -NORMAL_HEIGHT * 0.72 * motion.scale.y + motion.position.y


func refresh_skin(use_motion_facing: bool = false) -> void:
	if _actor_id == 0 or not is_instance_id_valid(_actor_id) or sprite == null or geometry.is_empty():
		return
	var actor: Node2D = instance_from_id(_actor_id) as Node2D
	var mutant: Variant = actor.get("projectile_element")
	tint = ICE_TINT if mutant == &"ice" else POISON_TINT if mutant == &"poison" else Color.WHITE
	var flash_time: float = float(actor.get("_flash_remaining"))
	var body_color: Color = _body.color
	# Base green belongs to the asset; only the old feedback colors become tints.
	if flash_time > 0.0:
		tint = Color(1.0, 0.28, 0.22) if flash_time <= 0.12 else Color.WHITE
	elif body_color != Color(0.35, 0.86, 0.5):
		tint = body_color
	sprite.modulate = Color(tint.r, tint.g, tint.b, _body.modulate.a)
	_material.set_shader_parameter("flash", 1.0 if flash_time > 0.12 else 0.0)
	_material.set_shader_parameter("active", flash_time > 0.080001)
	EnemySpriteArt.set_facing(sprite, geometry["foot_pixel"], displayed_facing < 0.0 if use_motion_facing else float(actor.get("_facing")) < 0.0)
	# Manhunter keeps its original eye signal but only during that incident.
	_eyes.visible = bool(actor.get("enraged"))
	queue_redraw()


func _on_visual_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0.0 or event.source_kind == DamageEvent.SourceKind.DOT: return
	_hit_remaining = 0.18
	_hit_axis = signf(event.attack_direction.x) if absf(event.attack_direction.x) > 0.1 else displayed_facing
	hit_reaction_count += 1
	active_cue_remaining = 0.0
	_bite_was_active = false


func _draw() -> void:
	if _actor_id == 0 or not is_instance_id_valid(_actor_id): return
	var actor: SlimeEnemy = instance_from_id(_actor_id) as SlimeEnemy
	if actor == null or actor.state_machine.get_state_id() != &"attack": return
	var center := Vector2(0, -14)
	var direction := Vector2(actor._facing, 0)
	var start: float = -0.7 if actor._facing > 0 else PI - 0.7
	if actor._state_time < actor.telegraph_seconds:
		var progress: float = clampf(actor._state_time / actor.telegraph_seconds, 0, 1)
		draw_arc(center + direction * 26.0, 14.0, start, start + 1.4, 12, Color(1, 0.78, 0.28, 0.35 + progress * 0.45), 2)
	elif actor.bite_hitbox.active and active_cue_remaining > 0.0:
		# Bite launch mark is distinct from the accepted-hit impact adapter.
		var progress: float = 1.0 - active_cue_remaining / 0.12
		draw_arc(center + direction * 26.0, 14.0 + progress * 5.0, start, start + 1.4, 12, Color(0.6, 1, 0.6, 1.0 - progress), 3)


func get_foot_world() -> Vector2:
	return EnemySpriteArt.foot_world(sprite, geometry["foot_pixel"]) if sprite != null and not geometry.is_empty() else global_position


func _restore_placeholders() -> void:
	if _actor_id != 0 and is_instance_id_valid(_actor_id):
		var actor: SlimeEnemy = instance_from_id(_actor_id) as SlimeEnemy
		if actor != null and is_instance_valid(actor.hurtbox) and actor.hurtbox.hit_resolved.is_connected(_on_visual_hit):
			actor.hurtbox.hit_resolved.disconnect(_on_visual_hit)
	if is_instance_valid(_body):
		_body.visible = _body_visible
	if is_instance_valid(_eyes):
		_eyes.visible = _eyes_visible
		_eyes.z_index = _eyes_z_index
		_eyes.position = _eyes_position
	_body = null
	_eyes = null


func _exit_tree() -> void:
	_restore_placeholders()
	_actor_id = 0
	geometry = {}
