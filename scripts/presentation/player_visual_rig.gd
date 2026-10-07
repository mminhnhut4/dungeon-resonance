class_name PlayerVisualRig
extends Node2D
## Cosmetic bones read authoritative combat clocks. Nothing here moves the actor.

signal modular_skin_changed

const TORSO: String = "Skeleton2D/Root/Hip/Torso"
const RIGHT_HAND: String = TORSO + "/Shoulder.R/Arm.R/Hand.R"
const LEFT_HAND: String = TORSO + "/Shoulder.L/Arm.L/Hand.L"
const CONCEPT_CACHE_KEY: StringName = &"dungeon_concept_alpha_v1"
const HIT_FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const HIT_TINT_SECONDS: float = 0.08
const MAX_HIT_TINT: float = 0.18 # Preserve at least82% of texture contrast during contact.
const HIT_TINT: Color = Color(0.96, 0.56, 0.36)
const SLOT_PATHS: Dictionary = {
	&"body": TORSO + "/BodySprite", &"hip": "Skeleton2D/Root/Hip/HipSprite",
	&"head": TORSO + "/Head/HeadSprite", &"hair": TORSO + "/Head/Hair",
	&"face": TORSO + "/Head/Face", &"mask": TORSO + "/Head/Mask",
	&"shoulder_left": TORSO + "/Shoulder.L/ShoulderSprite", &"shoulder_right": TORSO + "/Shoulder.R/ShoulderSprite",
	&"arm_left": TORSO + "/Shoulder.L/Arm.L/ArmSprite", &"arm_right": TORSO + "/Shoulder.R/Arm.R/ArmSprite",
	&"hand_left": LEFT_HAND + "/HandSprite", &"hand_right": RIGHT_HAND + "/HandSprite",
	&"leg_left": "Skeleton2D/Root/Hip/Leg.L/LegSprite", &"leg_right": "Skeleton2D/Root/Hip/Leg.R/LegSprite",
	&"foot_left": "Skeleton2D/Root/Hip/Leg.L/Foot.L/FootSprite", &"foot_right": "Skeleton2D/Root/Hip/Leg.R/Foot.R/FootSprite",
	&"weapon_left": LEFT_HAND + "/WeaponSlot/WeaponSprite", &"weapon_right": RIGHT_HAND + "/WeaponSlot/WeaponSprite",
}
const MODULAR_ALIASES: Dictionary = {
	&"torso": &"body", &"upper_arm_left": &"shoulder_left", &"upper_arm_right": &"shoulder_right",
	&"forearm_left": &"arm_left", &"forearm_right": &"arm_right",
	&"thigh_left": &"leg_left", &"thigh_right": &"leg_right",
}
const EQUIPMENT_PART_GROUPS: Array[StringName] = [&"armor", &"pants", &"boots", &"gloves", &"ring", &"amulet"]

@export var fallback_body_texture: Texture2D
@export var concept_body_texture: Texture2D
@export var swordsman_body_texture: Texture2D
@export var modular_skin: ModularCharacterSkin
var _mage_texture: Texture2D
@export_range(24.0, 96.0, 1.0) var concept_height: float = 42.0
@onready var body_sprite: Sprite2D = get_node(TORSO + "/BodySprite") as Sprite2D
@onready var skeleton: Skeleton2D = $Skeleton2D
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var weapon_slot: Node2D = get_node(RIGHT_HAND + "/WeaponSlot") as Node2D
var displayed_animation: StringName = &"RESET"
var displayed_time: float = 0.0
var committed_direction: Vector2 = Vector2.RIGHT
var concept_sprite: Sprite2D
var concept_pivot: Node2D
var concept_dynamics: Node2D
var actor_shadow: ActorShadow
var procedural: ProceduralAnimator = ProceduralAnimator.new()
var _concept_material: ShaderMaterial
var _hurtbox_id: int = 0
var _flash_remaining: float = 0.0
var concept_bounds: Rect2i
var concept_foot_pixel: Vector2
var breath_tween: Tween
var visual_facing_left: bool = false
var _actor_id: int = 0
var _cycle_time: float = 0.0
var _sprites: Dictionary = {}
var _modular_base: Array[Sprite2D] = []
var _modular_equipment: Dictionary = {}
var _modular_joints: Array[Bone2D] = []
var _modular_material: ShaderMaterial
var _modular_active: bool = false
var _legacy_visibility: Dictionary = {}
var _last_locomotion: StringName = &"idle"
var _land_remaining: float = 0.0
var _hurt_pose_remaining: float = 0.0
var _death_time: float = 0.0
var _hair_angle: float = 0.0
var _sash_angle: float = 0.0
var _secondary_clock: float = 0.0
var _breath_scale: float = 1.0:
	set(value):
		_breath_scale = value
		if is_instance_valid(concept_pivot):
			concept_pivot.scale.y = value
		_apply_concept_dynamics()


func _ready() -> void:
	_mage_texture = concept_body_texture
	process_physics_priority = 10
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for slot: StringName in SLOT_PATHS:
		_sprites[slot] = get_node(SLOT_PATHS[slot]) as Sprite2D
	# This legacy sprite remains the controller's flip/flash adapter. A live
	# concept must never render it, even if an inherited scene or tool restores
	# its visibility. self_modulate affects only this adapter, not its flash data.
	body_sprite.visibility_changed.connect(_suppress_concept_placeholder)
	if body_sprite.texture == null and fallback_body_texture != null:
		body_sprite.texture = fallback_body_texture
	if concept_body_texture != null:
		prepare_concept(concept_body_texture)
	_seek(&"RESET", 0.0)
	if modular_skin != null:
		set_modular_skin(modular_skin)
	if get_parent() is Player:
		bind(get_parent() as Player)


func bind(actor: Player) -> void:
	_disconnect_visual_hit()
	_stop_breathing()
	procedural.reset()
	_flash_remaining = 0.0
	_hurt_pose_remaining = 0.0
	_land_remaining = 0.0
	_death_time = 0.0
	_hair_angle = 0.0
	_sash_angle = 0.0
	_secondary_clock = 0.0
	_last_locomotion = &"idle"
	_apply_concept_dynamics()
	_apply_hit_tint()
	_actor_id = actor.get_instance_id() if is_instance_valid(actor) else 0
	_cycle_time = 0.0
	if is_node_ready():
		_seek(&"RESET", 0.0)
		if is_instance_valid(actor):
			_align_foot_pivot(actor)
			_align_modular_skeleton(actor)
			_bind_shadow(actor)
			_hurtbox_id = actor.hurtbox.get_instance_id() if is_instance_valid(actor.hurtbox) else 0
			if _hurtbox_id != 0:
				actor.hurtbox.hit_resolved.connect(_on_visual_hit)
		elif is_instance_valid(actor_shadow):
			actor_shadow.bind(null)


func prepare_concept(texture: Texture2D) -> bool:
	if texture == null:
		return false
	var data: Dictionary = _get_concept_data(texture)
	if data.is_empty():
		return false
	concept_body_texture = texture
	concept_bounds = data["bounds"]
	concept_foot_pixel = data["foot_pixel"]
	if not is_instance_valid(concept_pivot):
		concept_pivot = Node2D.new()
		concept_pivot.name = "ConceptFootPivot"
		add_child(concept_pivot)
		concept_dynamics = Node2D.new()
		concept_dynamics.name = "ConceptDynamics"
		concept_pivot.add_child(concept_dynamics)
		concept_sprite = Sprite2D.new()
		concept_sprite.name = "ConceptSprite"
		concept_sprite.centered = false
		concept_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		concept_dynamics.add_child(concept_sprite)
		_concept_material = ShaderMaterial.new()
		_concept_material.shader = HIT_FLASH_SHADER
		_apply_hit_tint()
		concept_sprite.material = _concept_material
	concept_sprite.texture = data["texture"]
	concept_sprite.flip_h = visual_facing_left
	var foot_x: float = concept_sprite.texture.get_width() - concept_foot_pixel.x if visual_facing_left else concept_foot_pixel.x
	concept_sprite.offset = Vector2(-foot_x, -concept_foot_pixel.y)
	var base_scale: float = concept_height / maxf(1.0, float(concept_bounds.size.y))
	concept_sprite.scale = Vector2.ONE * base_scale
	_suppress_concept_placeholder()
	var actor: Player = instance_from_id(_actor_id) as Player if _actor_id != 0 else null
	if is_instance_valid(actor):
		_align_foot_pivot(actor)
	return true


func _suppress_concept_placeholder() -> void:
	if not _modular_active and (not is_instance_valid(concept_sprite) or concept_sprite.texture == null):
		return
	body_sprite.self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	if body_sprite.visible:
		body_sprite.visible = false


func _align_foot_pivot(actor: Player) -> void:
	if not is_instance_valid(concept_pivot):
		return
	var collision: CollisionShape2D = actor.get_node_or_null("BodyCollision") as CollisionShape2D
	var bottom: float = 0.0
	if collision != null and collision.shape != null:
		bottom = collision.position.y + collision.shape.get_rect().end.y
	concept_pivot.position = Vector2(0.0, bottom)
	_apply_concept_dynamics()


func _bind_shadow(actor: Player) -> void:
	if actor_shadow == null:
		actor_shadow = ActorShadow.new()
		actor_shadow.name = "ActorShadow"
		add_child(actor_shadow)
	var collision: CollisionShape2D = actor.get_node_or_null("BodyCollision") as CollisionShape2D
	var foot: Vector2 = Vector2.ZERO
	if collision != null and collision.shape != null:
		foot.y = collision.position.y + collision.shape.get_rect().end.y
	actor_shadow.bind(actor, foot, 24.0, 5.0, actor.combat_feedback)


func _apply_concept_dynamics() -> void:
	if not is_instance_valid(concept_dynamics):
		return
	concept_dynamics.position.y = procedural.bob
	concept_dynamics.rotation = procedural.lean
	# Preserve the existing 1.03 Tween contract. A second cosmetic layer supplies
	# the small remainder for a composed 1.035 inhale, still about the same foot.
	concept_dynamics.scale.y = (1.0 + clampf((_breath_scale - 1.0) / 0.03, 0.0, 1.0) * 0.035) / maxf(_breath_scale, 0.001)


func _on_visual_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0.0:
		return
	_flash_remaining = HIT_TINT_SECONDS
	if event.source_kind != DamageEvent.SourceKind.DOT:
		_hurt_pose_remaining = 0.18
	_apply_hit_tint()


func _apply_hit_tint() -> void:
	var strength: float = MAX_HIT_TINT * clampf(_flash_remaining / HIT_TINT_SECONDS, 0.0, 1.0)
	for ink: ShaderMaterial in [_concept_material, _modular_material]:
		if ink == null: continue
		# The shared shader's active switch erases texture detail. Player uses its bounded mix instead.
		ink.set_shader_parameter("active", false)
		ink.set_shader_parameter("flash", strength)
		ink.set_shader_parameter("flash_color", HIT_TINT)

func _disconnect_visual_hit() -> void:
	if _hurtbox_id != 0 and is_instance_id_valid(_hurtbox_id):
		var hurtbox: Hurtbox = instance_from_id(_hurtbox_id) as Hurtbox
		if is_instance_valid(hurtbox) and hurtbox.hit_resolved.is_connected(_on_visual_hit):
			hurtbox.hit_resolved.disconnect(_on_visual_hit)
	_hurtbox_id = 0


func equip(slot: StringName, texture: Texture2D) -> bool:
	var canonical: StringName = &"body" if slot == &"torso" else slot
	if not _sprites.has(canonical):
		return false
	(_sprites[canonical] as Sprite2D).texture = texture
	return true


func get_slot_sprite(slot: StringName) -> Sprite2D:
	return _sprites.get(&"body" if slot == &"torso" else slot) as Sprite2D


func is_modular_active() -> bool:
	return _modular_active


func set_modular_skin(skin: ModularCharacterSkin) -> bool:
	# Validate the complete operation before touching the displayed skin.
	if _sprites.is_empty():
		return false
	if skin != null and (skin.id.is_empty() or skin.parts.is_empty() or not is_finite(skin.visual_scale) or skin.visual_scale < 0.25 or skin.visual_scale > 4.0 or not skin.foot_origin.is_finite() or not _valid_modular_parts(skin.parts, 32)):
		return false
	_clear_modular_sprites(_modular_base)
	for group: StringName in _modular_equipment:
		_clear_modular_sprites(_modular_equipment[group])
	_modular_equipment.clear()
	modular_skin = skin
	_modular_active = skin != null
	if not _modular_active:
		for sprite: Sprite2D in _sprites.values():
			sprite.visible = bool(_legacy_visibility.get(sprite.get_instance_id(), true))
		_legacy_visibility.clear()
		for joint: Bone2D in _modular_joints:
			if is_instance_valid(joint) and joint.get_parent() != null:
				joint.get_parent().remove_child(joint)
				joint.queue_free()
		_modular_joints.clear()
		skeleton.position = Vector2.ZERO
		skeleton.scale = Vector2(-1.0 if visual_facing_left else 1.0, 1.0)
		if is_instance_valid(concept_sprite):
			concept_sprite.visible = true
		_suppress_concept_placeholder()
		_modular_material = null
		modular_skin_changed.emit()
		return true
	_prepare_modular_joints()
	if _modular_material == null:
		_modular_material = ShaderMaterial.new()
		_modular_material.shader = HIT_FLASH_SHADER
		_apply_hit_tint()
	for sprite: Sprite2D in _sprites.values():
		if not _legacy_visibility.has(sprite.get_instance_id()):
			_legacy_visibility[sprite.get_instance_id()] = sprite.visible
		sprite.visible = false
	if is_instance_valid(concept_sprite):
		concept_sprite.visible = false
	for part: ModularCharacterPart in skin.parts:
		_modular_base.append(_mount_modular_part(part, &"BodyParts"))
	var actor: Player = instance_from_id(_actor_id) as Player if _actor_id != 0 else null
	if is_instance_valid(actor):
		_align_modular_skeleton(actor)
	_suppress_concept_placeholder()
	modular_skin_changed.emit()
	return true


func set_equipment_parts(group: StringName, parts: Array[ModularCharacterPart]) -> bool:
	if not _modular_active or group not in EQUIPMENT_PART_GROUPS or not _valid_modular_parts(parts, 16):
		return false
	if _modular_equipment.has(group):
		_clear_modular_sprites(_modular_equipment[group])
	var mounted: Array[Sprite2D] = []
	for part: ModularCharacterPart in parts:
		mounted.append(_mount_modular_part(part, group))
	_modular_equipment[group] = mounted
	return true


func clear_equipment_parts(group: StringName) -> void:
	if not _modular_equipment.has(group):
		return
	_clear_modular_sprites(_modular_equipment[group])
	_modular_equipment.erase(group)


func get_modular_bone(slot: StringName) -> Node2D:
	var canonical: StringName = MODULAR_ALIASES.get(slot, slot)
	if canonical == &"shin_left" or canonical == &"shin_right":
		return get_node_or_null("Skeleton2D/Root/Hip/Leg.%s/Knee" % ("L" if canonical == &"shin_left" else "R")) as Node2D
	if _modular_active and canonical in [&"foot_left", &"foot_right"]:
		return get_node_or_null("Skeleton2D/Root/Hip/Leg.%s/Knee/Ankle" % ("L" if canonical == &"foot_left" else "R")) as Node2D
	if not SLOT_PATHS.has(canonical):
		return null
	var sprite: Sprite2D = _sprites.get(canonical)
	return sprite.get_parent() as Node2D if is_instance_valid(sprite) else null


func get_hand_world_position(left_hand: bool = false) -> Vector2:
	var hand: Node2D = get_node(LEFT_HAND if left_hand else RIGHT_HAND) as Node2D
	return hand.global_position


func get_modular_foot_world() -> Vector2:
	return skeleton.to_global(modular_skin.foot_origin) if _modular_active else get_concept_foot_world()


func get_modular_visual_bounds() -> Rect2:
	var bounds := Rect2()
	var started: bool = false
	var mounted: Array[Sprite2D] = _modular_base.duplicate()
	for group: StringName in _modular_equipment:
		mounted.append_array(_modular_equipment[group])
	for sprite: Sprite2D in mounted:
		if not is_instance_valid(sprite) or not sprite.visible or sprite.texture == null:
			continue
		var rectangle: Rect2 = sprite.get_rect()
		for corner: Vector2 in [rectangle.position, Vector2(rectangle.end.x, rectangle.position.y), rectangle.end, Vector2(rectangle.position.x, rectangle.end.y)]:
			var world: Vector2 = sprite.to_global(corner)
			if not started:
				bounds = Rect2(world, Vector2.ZERO)
				started = true
			else:
				bounds = bounds.expand(world)
	return bounds


func _valid_modular_parts(parts: Array[ModularCharacterPart], maximum: int) -> bool:
	if parts.size() > maximum:
		return false
	var identifiers: Dictionary = {}
	for part: ModularCharacterPart in parts:
		if part == null or not part.is_valid_part() or identifiers.has(part.id):
			return false
		var canonical: StringName = MODULAR_ALIASES.get(part.bone_slot, part.bone_slot)
		if not SLOT_PATHS.has(canonical) and canonical not in [&"shin_left", &"shin_right"]:
			return false
		identifiers[part.id] = true
	return true


func _mount_modular_part(part: ModularCharacterPart, group: StringName) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = "%s_%s" % [group, part.id]
	sprite.centered = false
	sprite.texture = part.texture
	sprite.offset = -part.pivot_pixels
	sprite.scale = part.display_scale
	sprite.z_index = part.draw_order
	sprite.self_modulate = part.tint
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.material = _modular_material
	sprite.set_meta(&"part_id", part.id)
	get_modular_bone(part.bone_slot).add_child(sprite)
	return sprite


func _clear_modular_sprites(sprites: Array[Sprite2D]) -> void:
	for sprite: Sprite2D in sprites:
		if is_instance_valid(sprite) and sprite.get_parent() != null:
			sprite.get_parent().remove_child(sprite)
			sprite.queue_free()
	sprites.clear()


func _prepare_modular_joints() -> void:
	if not _modular_joints.is_empty():
		return
	for side: String in ["L", "R"]:
		var leg: Bone2D = get_node("Skeleton2D/Root/Hip/Leg.%s" % side) as Bone2D
		var knee := Bone2D.new()
		knee.name = "Knee"
		knee.position = Vector2(0.0, 8.0)
		knee.rest = Transform2D(0.0, knee.position)
		knee.set_autocalculate_length_and_angle(false)
		knee.set_length(8.0)
		knee.set_bone_angle(PI * 0.5)
		leg.add_child(knee)
		var ankle := Bone2D.new()
		ankle.name = "Ankle"
		ankle.position = Vector2(0.0, 8.0)
		ankle.rest = Transform2D(0.0, ankle.position)
		ankle.set_autocalculate_length_and_angle(false)
		ankle.set_length(4.0)
		ankle.set_bone_angle(0.0)
		knee.add_child(ankle)
		# Only top joints are owned here; each knee frees its ankle as a child.
		_modular_joints.append(knee)


func _align_modular_skeleton(actor: Player) -> void:
	if not _modular_active:
		return
	var collision: CollisionShape2D = actor.get_node_or_null("BodyCollision") as CollisionShape2D
	var bottom: float = collision.position.y + collision.shape.get_rect().end.y if collision != null and collision.shape != null else 0.0
	var size: float = modular_skin.visual_scale
	var facing: float = -1.0 if visual_facing_left else 1.0
	skeleton.scale = Vector2(facing, 1.0) * size
	skeleton.position = Vector2(0.0, bottom) - modular_skin.foot_origin * skeleton.scale


func _physics_process(delta: float) -> void:
	sync_from_player(delta)


func sync_from_player(delta: float = 0.0) -> void:
	var actor: Player = instance_from_id(_actor_id) as Player if _actor_id != 0 else null
	if not is_instance_valid(actor) or not actor.is_inside_tree():
		_actor_id = 0
		_stop_breathing()
		procedural.reset()
		_apply_concept_dynamics()
		_disconnect_visual_hit()
		if is_instance_valid(actor_shadow):
			actor_shadow.bind(null)
		return
	# Cosmetic facing follows the live cursor, independently of movement. The
	_sync_weapon_skin(actor)
	# Weapon snapshot remains authoritative for committed attack orientation.
	var horizontal_cursor: float = actor.aim.target_position.x - actor.global_position.x
	if absf(horizontal_cursor) > 0.5:
		visual_facing_left = horizontal_cursor < 0.0
	var facing: float = -1.0 if visual_facing_left else 1.0
	# Player owns flip_h. Cancel that local flip before the skeleton mirrors all
	# body parts, so the legacy full-body fallback is never mirrored twice.
	body_sprite.scale.x = -1.0 if body_sprite.flip_h else 1.0
	var action: StringName = actor.action_state_machine.get_state_id()
	# The feedback adapter's dark death tint is suitable for the old full PNG.
	# Separated cloth layers need a readable corpse under the dungeon modulate.
	var part_color: Color = Color(0.7, 0.7, 0.7, 1.0) if action == &"dead" else body_sprite.modulate
	for sprite: Sprite2D in _sprites.values():
		if sprite != body_sprite:
			sprite.modulate = body_sprite.modulate
	for sprite: Sprite2D in _modular_base:
		sprite.modulate = part_color
	for group: StringName in _modular_equipment:
		for sprite: Sprite2D in _modular_equipment[group]:
			sprite.modulate = part_color
	if is_instance_valid(concept_sprite):
		concept_sprite.flip_h = visual_facing_left
		var foot_x: float = concept_sprite.texture.get_width() - concept_foot_pixel.x if visual_facing_left else concept_foot_pixel.x
		concept_sprite.offset = Vector2(-foot_x, -concept_foot_pixel.y)
		concept_sprite.modulate = body_sprite.modulate
	var locomotion: StringName = actor.locomotion_state_machine.get_state_id()
	var frozen: bool = is_instance_valid(actor.combat_feedback) and actor.combat_feedback.is_frozen()
	if is_instance_valid(actor_shadow):
		actor_shadow.set_feedback(actor.combat_feedback)
	_update_breathing(action == &"ready" and locomotion == &"idle", frozen)
	if frozen:
		return
	# Preserve the complete drawn transform during hit-stop, including landing
	# squash and corpse floor contact; resetting before this guard caused a pop.
	skeleton.scale.x = facing
	_align_modular_skeleton(actor)
	_advance_secondary_motion(actor, delta)
	_flash_remaining = maxf(0.0, _flash_remaining - maxf(delta, 0.0))
	_hurt_pose_remaining = maxf(0.0, _hurt_pose_remaining - maxf(delta, 0.0))
	_land_remaining = maxf(0.0, _land_remaining - maxf(delta, 0.0))
	if _last_locomotion in [&"jump", &"fall"] and locomotion in [&"idle", &"run"]:
		_land_remaining = 0.18
	_last_locomotion = locomotion
	_apply_hit_tint()
	if action == &"dead":
		procedural.reset()
	else:
		procedural.advance_player(delta, actor.velocity.x, actor.motor.run_speed, locomotion == &"run" and actor.motor.is_grounded())
	_apply_concept_dynamics()
	if action == &"dead":
		_death_time = minf(0.4, _death_time + maxf(0.0, delta))
		_seek(&"dead", _death_time)
		return
	_death_time = 0.0
	var reaction: HitReactionComponent = actor.get_node_or_null("HitReaction") as HitReactionComponent
	if reaction != null and reaction.is_active:
		_sync_hit_reaction(reaction)
		return
	if action == &"attack" and actor.equipped_weapon.snapshot != null:
		_sync_attack(actor.equipped_weapon, facing)
		return
	if action == &"cast_spell":
		var cast: PlayerCastState = actor.action_state_machine.current_state as PlayerCastState
		if cast != null and cast.payload != null:
			_sync_cast(cast, facing)
			return
	if action == &"dash":
		_seek(&"dash", clampf(actor.motor.dash_duration - actor.motor.dash_remaining, 0.0, 0.16))
		return
	if action == &"hurt" or _hurt_pose_remaining > 0.0:
		_seek(&"hurt", 0.18 - _hurt_pose_remaining)
		return
	if _land_remaining > 0.0:
		_seek(&"land", 0.18 - _land_remaining)
		return
	var next_animation: StringName = locomotion if locomotion in [&"run", &"jump", &"fall"] else &"idle"
	if displayed_animation != next_animation:
		_cycle_time = 0.0
	_cycle_time += maxf(0.0, delta)
	var length: float = animation_player.get_animation(next_animation).length
	_seek(next_animation, fmod(_cycle_time, length))


func get_concept_foot_world() -> Vector2:
	if not is_instance_valid(concept_sprite) or concept_sprite.texture == null:
		return global_position
	var foot_x: float = concept_sprite.texture.get_width() - concept_foot_pixel.x if concept_sprite.flip_h else concept_foot_pixel.x
	return concept_sprite.to_global(concept_sprite.offset + Vector2(foot_x, concept_foot_pixel.y))


func _update_breathing(idle: bool, frozen: bool) -> void:
	if not idle:
		_stop_breathing()
		return
	if breath_tween == null or not breath_tween.is_valid():
		_breath_scale = 1.0
		breath_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_loops()
		breath_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		breath_tween.tween_property(self, "_breath_scale", 1.03, 0.6)
		breath_tween.tween_property(self, "_breath_scale", 1.0, 0.6)
	if frozen:
		breath_tween.pause()
	elif not breath_tween.is_running():
		breath_tween.play()


func _stop_breathing() -> void:
	if breath_tween != null and breath_tween.is_valid():
		breath_tween.kill()
	breath_tween = null
	_breath_scale = 1.0


static func _get_concept_data(texture: Texture2D) -> Dictionary:
	# Native texture metadata owns one mask per source texture lifetime. There
	# are no static GDScript Resource fields and no reference back to the source.
	var cached: Dictionary = texture.get_meta(CONCEPT_CACHE_KEY, {})
	if not cached.is_empty():
		return cached
	var source: Image = texture.get_image()
	if source == null or source.is_empty():
		return {}
	var data: Dictionary = build_edge_mask(source, source.detect_alpha() == Image.ALPHA_NONE)
	if data.is_empty():
		return {}
	texture.set_meta(CONCEPT_CACHE_KEY, data)
	return data


static func build_edge_mask(source: Image, remove_edge_white: bool = true) -> Dictionary:
	# Remove only near-white pixels connected to an image edge. Enclosed white
	# mask/face pixels stay opaque; the imported/source PNG is never modified.
	if source == null or source.is_empty() or source.get_width() * source.get_height() > 4194304:
		return {}
	var image: Image = source.duplicate() as Image
	image.convert(Image.FORMAT_RGBA8)
	var width: int = image.get_width()
	var height: int = image.get_height()
	var count: int = width * height
	var rgba: PackedByteArray = image.get_data()
	var visited := PackedByteArray()
	visited.resize(count)
	visited.fill(0)
	var queue := PackedInt32Array()
	queue.resize(count)
	var tail: int = 0
	for x: int in range(width):
		for pixel: int in [x, (height - 1) * width + x]:
			if visited[pixel] == 0 and _background_pixel(rgba, pixel, remove_edge_white):
				visited[pixel] = 1
				queue[tail] = pixel
				tail += 1
	for y: int in range(1, height - 1):
		for pixel: int in [y * width, y * width + width - 1]:
			if visited[pixel] == 0 and _background_pixel(rgba, pixel, remove_edge_white):
				visited[pixel] = 1
				queue[tail] = pixel
				tail += 1
	var head: int = 0
	var offsets := PackedInt32Array([-1, 1, -width, width])
	while head < tail:
		var pixel: int = queue[head]
		head += 1
		rgba[pixel * 4 + 3] = 0
		var x: int = pixel % width
		for side: int in range(4):
			if (side == 0 and x == 0) or (side == 1 and x == width - 1):
				continue
			var neighbor: int = pixel + offsets[side]
			if neighbor >= 0 and neighbor < count and visited[neighbor] == 0 and _background_pixel(rgba, neighbor, remove_edge_white):
				visited[neighbor] = 1
				queue[tail] = neighbor
				tail += 1
	var left: int = width
	var right: int = -1
	var top: int = height
	var bottom: int = -1
	for y: int in range(height):
		for x: int in range(width):
			if rgba[(y * width + x) * 4 + 3] > 8:
				left = mini(left, x)
				right = maxi(right, x)
				top = mini(top, y)
				bottom = maxi(bottom, y)
	if right < left or bottom < top:
		return {}
	var foot_left: int = width
	var foot_right: int = -1
	for y: int in range(maxi(top, bottom - 3), bottom + 1):
		for x: int in range(left, right + 1):
			if rgba[(y * width + x) * 4 + 3] > 8:
				foot_left = mini(foot_left, x)
				foot_right = maxi(foot_right, x)
	var runtime_image := Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, rgba)
	return {
		"texture": ImageTexture.create_from_image(runtime_image),
		"bounds": Rect2i(left, top, right - left + 1, bottom - top + 1),
		"foot_pixel": Vector2((foot_left + foot_right + 1) * 0.5, bottom + 1),
	}


static func _background_pixel(rgba: PackedByteArray, pixel: int, remove_edge_white: bool = true) -> bool:
	var index: int = pixel * 4
	if not remove_edge_white:
		return rgba[index + 3] == 0
	return rgba[index + 3] < 8 or (remove_edge_white and rgba[index] >= 244 and rgba[index + 1] >= 244 and rgba[index + 2] >= 244)


func _sync_weapon_skin(actor: Player) -> void:
	if _modular_active:
		return
	if swordsman_body_texture == null or _mage_texture == null or actor.equipped_weapon.definition == null:
		return
	var definition: WeaponDefinition = actor.equipped_weapon.definition
	var melee: bool = definition.visual_archetype == "swordsman" or (definition.visual_archetype == "auto" and definition.attack_kind == &"melee")
	var selected: Texture2D = swordsman_body_texture if melee else _mage_texture
	if concept_body_texture != selected:
		prepare_concept(selected)


func _sync_attack(weapon: Weapon, facing: float) -> void:
	var progress: float = clampf(1.0 - weapon._phase_remaining / maxf(weapon._phase_duration, 0.000001), 0.0, 1.0)
	var animation_time: float = 0.6
	match weapon.phase:
		Weapon.Phase.WINDUP:
			animation_time = 0.2 * progress
		Weapon.Phase.ACTIVE:
			animation_time = 0.2 + 0.1 * progress
		Weapon.Phase.RECOVERY:
			animation_time = 0.3 + 0.3 * progress
	var clip: StringName = &"attack_slash_1" if weapon.combo_index % 2 == 0 else &"attack_slash_2"
	if weapon._current_step != null and weapon._current_step.motion == &"punch":
		clip = &"punch"
	_seek(clip, animation_time)
	if weapon.snapshot.weapon_definition.visual_profile != &"legacy":
		var pose: Dictionary = WeaponMotionPose.evaluate(weapon.snapshot.weapon_definition.visual_profile, weapon.combo_index, weapon.phase, progress)
		(get_node(TORSO) as Bone2D).rotation += float(pose["lean"])
		(get_node(TORSO + "/Shoulder.L") as Bone2D).rotation += float(pose["support"])
		(get_node(TORSO + "/Shoulder.R") as Bone2D).rotation += deg_to_rad(float(pose["swing"])) * 0.18
	committed_direction = weapon.snapshot.attack_direction
	var authored_swing: float = weapon_slot.rotation
	weapon_slot.global_rotation = committed_direction.angle() + authored_swing * facing


func _sync_cast(cast: PlayerCastState, facing: float) -> void:
	var animation_time: float
	if not cast._launched:
		var progress: float = clampf(1.0 - cast._remaining / maxf(cast.payload.windup, 0.000001), 0.0, 1.0)
		animation_time = 0.2 * progress
	else:
		var progress: float = clampf(1.0 - cast._remaining / maxf(cast.payload.recovery, 0.000001), 0.0, 1.0)
		animation_time = 0.2 + 0.3 * progress
	_seek(&"cast_spell", animation_time)
	committed_direction = cast.payload.direction
	var authored_swing: float = weapon_slot.rotation
	weapon_slot.global_rotation = committed_direction.angle() + authored_swing * facing


func _seek(clip: StringName, time: float) -> void:
	var actor: Player = instance_from_id(_actor_id) as Player if _actor_id != 0 else null
	if _modular_active and is_instance_valid(actor):
		_align_modular_skeleton(actor)
	if animation_player.current_animation != clip:
		animation_player.play(&"RESET")
		animation_player.seek(0.0, true, true)
		animation_player.play(clip)
	displayed_animation = clip
	displayed_time = time
	animation_player.seek(time, true, true)
	_apply_modular_joint_pose()
	_apply_secondary_motion()


func _apply_modular_joint_pose() -> void:
	if not _modular_active:
		return
	# Knees are an opt-in extension: the old 14-bone rig and slot paths stay valid.
	# Read the displayed action clock; this pose never opens a hitbox or moves Player.
	var left_knee: Bone2D = get_modular_bone(&"shin_left") as Bone2D
	var right_knee: Bone2D = get_modular_bone(&"shin_right") as Bone2D
	left_knee.rotation = 0.05
	right_knee.rotation = 0.05
	match displayed_animation:
		&"idle":
			# Breathing lives in torso/head; grounded boots stay on their contact.
			(get_node("Skeleton2D/Root/Hip") as Bone2D).position = Vector2.ZERO
		&"run":
			var cycle: float = displayed_time / 0.6 * TAU
			left_knee.rotation = maxf(0.0, sin(cycle)) * 0.75
			right_knee.rotation = maxf(0.0, -sin(cycle)) * 0.75
			(get_modular_bone(&"upper_arm_left") as Bone2D).rotation = cos(cycle) * 0.4
			(get_modular_bone(&"upper_arm_right") as Bone2D).rotation = -cos(cycle) * 0.4
			(get_modular_bone(&"forearm_left") as Bone2D).rotation = -0.2 + sin(cycle) * 0.15
			(get_modular_bone(&"forearm_right") as Bone2D).rotation = -0.2 - sin(cycle) * 0.15
		&"jump":
			left_knee.rotation = 0.75
			right_knee.rotation = 0.4
		&"fall":
			left_knee.rotation = 0.25
			right_knee.rotation = 0.15
		&"land":
			var bend: float = sin(clampf(displayed_time / 0.18, 0.0, 1.0) * PI) * 0.35
			left_knee.rotation = bend
			right_knee.rotation = bend
			# Compress only the drawing around the same authored foot anchor.
			var foot: Vector2 = get_modular_foot_world()
			skeleton.scale *= Vector2(1.0 + bend * 0.12, 1.0 - bend * 0.22)
			skeleton.global_position += foot - get_modular_foot_world()
		&"dash":
			left_knee.rotation = 0.85
			right_knee.rotation = 0.25
		&"dead":
			left_knee.rotation = 0.3
			right_knee.rotation = 0.6
			_constrain_dead_visual_to_floor()


func _constrain_dead_visual_to_floor() -> void:
	var actor: Player = instance_from_id(_actor_id) as Player if _actor_id != 0 else null
	if not is_instance_valid(actor) or not actor.motor.is_grounded():
		return
	var collision: CollisionShape2D = actor.get_node_or_null("BodyCollision") as CollisionShape2D
	if collision == null or collision.shape == null:
		return
	var floor_y: float = collision.to_global(Vector2(0.0, collision.shape.get_rect().end.y)).y
	var bounds: Rect2 = get_modular_visual_bounds()
	if bounds.has_area() and (bounds.end.y > floor_y or displayed_time >= 0.4):
		# Reset by _align_modular_skeleton before the next seek. Only the corpse's
		# picture moves; the body, floor contact and Hurtbox remain untouched.
		# Settled art rests on the floor even when its tilted bounds end above it.
		skeleton.global_position.y -= bounds.end.y - floor_y


func get_mounted_part_sprites() -> Array[Sprite2D]:
	var mounted: Array[Sprite2D] = _modular_base.duplicate()
	for group: StringName in _modular_equipment:
		mounted.append_array(_modular_equipment[group])
	if not _modular_active and is_instance_valid(concept_sprite):
		mounted.append(concept_sprite)
	return mounted


func _advance_secondary_motion(actor: Player, delta: float) -> void:
	if not _modular_active:
		return
	var elapsed: float = maxf(0.0, delta)
	_secondary_clock += elapsed
	var facing: float = -1.0 if visual_facing_left else 1.0
	var motion: float = clampf(actor.velocity.x / maxf(actor.motor.run_speed, 1.0), -2.0, 2.0) * facing
	var hair_target: float = clampf(-motion * 0.07 + actor.velocity.y * 0.00006 + sin(_secondary_clock * 5.0) * 0.015, -0.16, 0.16)
	var sash_target: float = clampf(-motion * 0.13 + sin(_secondary_clock * 7.0) * 0.025 * absf(motion), -0.26, 0.26)
	if actor.health.current_health <= 0.0:
		hair_target = 0.0
		sash_target = 0.0
	_hair_angle = lerpf(_hair_angle, hair_target, 1.0 - exp(-10.0 * elapsed))
	_sash_angle = lerpf(_sash_angle, sash_target, 1.0 - exp(-8.0 * elapsed))


func _apply_secondary_motion() -> void:
	if not _modular_active:
		return
	for sprite: Sprite2D in _modular_base:
		if sprite.get_meta(&"part_id", &"") == &"hair":
			sprite.rotation = _hair_angle
	for group: StringName in _modular_equipment:
		for sprite: Sprite2D in _modular_equipment[group]:
			if sprite.get_meta(&"part_id", &"") == &"sash":
				sprite.rotation = _sash_angle


func _sync_hit_reaction(reaction: HitReactionComponent) -> void:
	# Reset value tracks, then apply a normalized, actor-owned reaction clock.
	# This is a visual pose only: impulse, recovery and interruption stay upstream.
	_seek(&"hurt", 0.0)
	displayed_animation = StringName("reaction_" + String(reaction.pose_id))
	displayed_time = reaction.pose_time
	var progress: float = clampf(reaction.pose_time / maxf(reaction.pose_duration, 0.000001), 0.0, 1.0)
	var root_bone: Bone2D = get_node("Skeleton2D/Root") as Bone2D
	var torso: Bone2D = get_modular_bone(&"torso") as Bone2D
	var hip: Bone2D = get_modular_bone(&"hip") as Bone2D
	var head: Bone2D = get_modular_bone(&"head") as Bone2D
	match reaction.pose_id:
		&"flinch":
			torso.rotation = -sin(progress * PI) * 0.22
			head.rotation = sin(progress * PI) * 0.12
		&"knockback":
			root_bone.rotation = -0.32 * sin(progress * PI * 0.75)
			torso.rotation = -0.12
		&"kneel":
			hip.position.y = 6.0 * sin(progress * PI * 0.75)
			torso.rotation = 0.3
			if _modular_active:
				get_modular_bone(&"shin_left").rotation = 0.9
				get_modular_bone(&"shin_right").rotation = 1.1
		&"thrown":
			root_bone.rotation = lerpf(-0.35, -1.15, progress)
			torso.rotation = -0.16
		&"get_up":
			root_bone.rotation = lerpf(-1.15, 0.0, progress)
			hip.position.y = (1.0 - progress) * 4.0
	if _modular_active:
		_constrain_dead_visual_to_floor()
	_apply_secondary_motion()


func _exit_tree() -> void:
	_disconnect_visual_hit()
	_stop_breathing()
	procedural.reset()
	_actor_id = 0
	_sprites.clear()
	_modular_base.clear()
	_modular_equipment.clear()
	_modular_joints.clear()
	_legacy_visibility.clear()
	_modular_material = null
	modular_skin = null
