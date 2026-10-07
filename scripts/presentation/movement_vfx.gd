class_name MovementVFX
extends Node2D
## Finite room-owned movement pictures. No collisions, lights, damage or inputs.

const MAX_GHOSTS: int = 5
const GHOST_SECONDS: float = 0.25
const MAX_MARKS: int = 8
const MARK_SECONDS: float = 0.32
const DUST: Texture2D = preload("res://assets/vfx/movement/regions/dust_cloud.tres")
const TAKEOFF: Texture2D = preload("res://assets/vfx/movement/regions/takeoff_ring.tres")
const LANDING: Texture2D = preload("res://assets/vfx/movement/regions/landing_wave.tres")
const WIND: Texture2D = preload("res://assets/vfx/movement/regions/wind_streak.tres")

var ghosts: Node2D
var marks: Node2D
var ghost_count: int = 0
var wind_count: int = 0
var takeoff_count: int = 0
var landing_count: int = 0
var skid_count: int = 0
var heavy_landing_count: int = 0
var _actor_id: int = 0
var _feedback_id: int = 0
var _material: CanvasItemMaterial
var _lifetimes: Dictionary[int, float] = {}
var _durations: Dictionary[int, float] = {}
var _dash_seen: bool = false
var _dash_captures: int = 0
var _was_grounded: bool = false
var _last_velocity: Vector2 = Vector2.ZERO
var _last_position: Vector2 = Vector2.ZERO
var _tracking: bool = false
var _run_seconds: float = 0.0
var _fall_distance: float = 0.0


func initialize(actor: Player, feedback: CombatFeedback) -> void:
	process_physics_priority = 30
	_actor_id = actor.get_instance_id()
	_feedback_id = feedback.get_instance_id()
	_material = CanvasItemMaterial.new()
	_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ghosts = Node2D.new()
	ghosts.name = "FiniteDashAfterimages"
	add_child(ghosts)
	marks = Node2D.new()
	marks.name = "FiniteMovementMarks"
	add_child(marks)
	clear()


func clear() -> void:
	for pool: Node2D in [ghosts, marks]:
		if not is_instance_valid(pool):
			continue
		for effect: Node in pool.get_children():
			pool.remove_child(effect)
			effect.queue_free()
	_lifetimes.clear()
	_durations.clear()
	_dash_seen = false
	_dash_captures = 0
	_was_grounded = false
	_last_velocity = Vector2.ZERO
	_tracking = false
	_run_seconds = 0.0
	_fall_distance = 0.0


func _physics_process(delta: float) -> void:
	var actor: Player = instance_from_id(_actor_id) as Player if is_instance_id_valid(_actor_id) else null
	var feedback: CombatFeedback = instance_from_id(_feedback_id) as CombatFeedback if is_instance_id_valid(_feedback_id) else null
	if not is_instance_valid(actor):
		clear()
		return
	if is_instance_valid(feedback) and feedback.is_frozen():
		return
	advance_lifetimes(delta)
	var grounded: bool = actor.motor.is_grounded()
	if not _tracking or actor.global_position.distance_to(_last_position) > maxf(32.0, actor.velocity.length() * maxf(delta, 0.0) * 2.0 + 1.0):
		_tracking = true
		_was_grounded = grounded
		_last_velocity = actor.velocity
		_run_seconds = 0.0
		_fall_distance = 0.0
	elif not grounded:
		_fall_distance += maxf(0.0, actor.global_position.y - _last_position.y)
	_last_position = actor.global_position
	var alive: bool = actor.health.current_health > 0.0
	var active_dash: bool = alive and actor.motor.is_dashing
	if active_dash:
		if not _dash_seen:
			_dash_captures = 0
			spawn_mark(WIND, actor.global_position + Vector2(-signf(actor.velocity.x) * 18.0, -22.0), 0.13, 0.20, 0.45)
			wind_count += 1
		var elapsed: float = actor.motor.dash_duration - actor.motor.dash_remaining
		var desired: int = mini(MAX_GHOSTS, 1 + int(floor(elapsed / maxf(actor.motor.dash_duration / MAX_GHOSTS, 0.000001))))
		# At 60/120 Hz this produces five distinct snapshots over the real dash.
		while _dash_captures < desired:
			spawn_afterimage(actor)
			_dash_captures += 1
	_dash_seen = active_dash
	if alive and actor.controls_enabled:
		var foot: Vector2 = _physical_foot(actor)
		if _was_grounded and not grounded and actor.velocity.y < -100.0 and actor.locomotion_state_machine.get_state_id() == &"jump":
			spawn_mark(TAKEOFF, foot, 0.10, 0.22, 0.28)
			takeoff_count += 1
		if grounded and not _was_grounded and _last_velocity.y > 100.0:
			spawn_mark(LANDING, foot, 0.11, 0.24, 0.36)
			landing_count += 1
			if _last_velocity.y >= 650.0 and _fall_distance >= 180.0:
				var camera: PlayerCamera = actor.get_node_or_null("Camera2D") as PlayerCamera
				if camera != null:
					camera.add_shake(0.12)
				heavy_landing_count += 1
		if grounded and not active_dash and actor.locomotion_state_machine.get_state_id() == &"run" and absf(actor.velocity.x) > actor.motor.run_speed * 0.6:
			_run_seconds += maxf(0.0, delta)
		elif grounded:
			# Real braking after sustained travel, never idle/wall pressure or warp.
			if _run_seconds >= 0.22 and absf(_last_velocity.x) > 100.0 and absf(actor.velocity.x) < 100.0:
				spawn_skid(foot, _last_velocity)
			if absf(actor.velocity.x) < 100.0 or active_dash or actor.is_on_wall():
				_run_seconds = 0.0
	if grounded:
		_fall_distance = 0.0
	_was_grounded = grounded
	_last_velocity = actor.velocity


func spawn_afterimage(actor: Player) -> Node2D:
	_prune_pool(ghosts, MAX_GHOSTS)
	var image := Node2D.new()
	image.name = "DashAfterimage"
	image.modulate = Color(0.5, 0.8, 0.8, 0.22)
	ghosts.add_child(image)
	image.global_transform = Transform2D.IDENTITY
	var rig: PlayerVisualRig = actor.get_node_or_null("Visuals") as PlayerVisualRig
	if rig != null:
		for source: Sprite2D in rig.get_mounted_part_sprites():
			_copy_sprite(source, image)
		var equipped: EquipmentVisual = rig.get_node_or_null("EquipmentVisual") as EquipmentVisual
		if equipped != null and equipped.visible:
			_copy_sprite(equipped.weapon_sprite, image, "HeldWeapon")
	_register(image, GHOST_SECONDS)
	ghost_count += 1
	return image


func _copy_sprite(source: Sprite2D, container: Node2D, label: String = "Part") -> void:
	if not is_instance_valid(source) or not source.is_visible_in_tree() or source.texture == null:
		return
	var copy := Sprite2D.new()
	copy.name = label
	copy.texture = source.texture
	copy.centered = source.centered
	copy.offset = source.offset
	copy.flip_h = source.flip_h
	copy.flip_v = source.flip_v
	copy.region_enabled = source.region_enabled
	copy.region_rect = source.region_rect
	copy.texture_filter = source.texture_filter
	copy.z_index = source.z_index
	copy.self_modulate = source.self_modulate
	copy.material = _material
	container.add_child(copy)
	copy.global_transform = source.global_transform


func spawn_mark(texture: Texture2D, location: Vector2, display_scale: float, duration: float, alpha: float) -> Sprite2D:
	_prune_pool(marks, MAX_MARKS)
	var mark := Sprite2D.new()
	mark.name = "MovementMark"
	mark.texture = texture
	mark.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mark.material = _material
	mark.scale = Vector2.ONE * display_scale
	mark.modulate = Color(1.0, 1.0, 1.0, alpha)
	mark.set_meta(&"initial_alpha", alpha)
	marks.add_child(mark)
	mark.global_position = location
	_register(mark, duration)
	return mark


func spawn_skid(location: Vector2, travel: Vector2) -> GPUParticles2D:
	_prune_pool(marks, MAX_MARKS)
	var puff := GPUParticles2D.new()
	puff.name = "SkidDust"
	puff.set_meta(&"initial_alpha", 1.0)
	puff.texture = DUST
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	puff.material = _material
	puff.amount = 3
	puff.lifetime = 0.28
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.local_coords = false
	puff.fixed_fps = 60
	puff.visibility_rect = Rect2(-64, -48, 128, 96)
	var motion := ParticleProcessMaterial.new()
	motion.direction = Vector3(-signf(travel.x), -0.35, 0.0)
	motion.spread = 15.0
	motion.gravity = Vector3(0.0, -12.0, 0.0)
	motion.initial_velocity_min = 10.0
	motion.initial_velocity_max = 24.0
	motion.scale_min = 0.025
	motion.scale_max = 0.045
	motion.color = Color(0.75, 0.8, 0.8, 0.22)
	puff.process_material = motion
	marks.add_child(puff)
	puff.global_position = location + Vector2(0.0, -3.0)
	puff.emitting = DisplayServer.get_name() != "headless"
	_register(puff, MARK_SECONDS)
	skid_count += 1
	return puff


func advance_lifetimes(delta: float) -> void:
	for id: int in _lifetimes.keys():
		var effect: Node2D = instance_from_id(id) as Node2D if is_instance_id_valid(id) else null
		_lifetimes[id] = float(_lifetimes[id]) - maxf(0.0, delta)
		if not is_instance_valid(effect) or _lifetimes[id] <= 0.0:
			_lifetimes.erase(id)
			_durations.erase(id)
			if is_instance_valid(effect):
				effect.get_parent().remove_child(effect)
				effect.queue_free()
			continue
		var alpha: float = float(effect.get_meta(&"initial_alpha", 0.22))
		effect.modulate.a = alpha * clampf(float(_lifetimes[id]) / float(_durations[id]), 0.0, 1.0)


func _register(effect: Node2D, duration: float) -> void:
	_lifetimes[effect.get_instance_id()] = maxf(duration, 0.01)
	_durations[effect.get_instance_id()] = maxf(duration, 0.01)


func _prune_pool(pool: Node2D, maximum: int) -> void:
	while pool.get_child_count() >= maximum:
		var old: Node = pool.get_child(0)
		_lifetimes.erase(old.get_instance_id())
		_durations.erase(old.get_instance_id())
		pool.remove_child(old)
		old.queue_free()


func _physical_foot(actor: Player) -> Vector2:
	var collision: CollisionShape2D = actor.get_node("BodyCollision") as CollisionShape2D
	return collision.to_global(Vector2(0.0, collision.shape.get_rect().end.y))


func _exit_tree() -> void:
	clear()
	_actor_id = 0
	_feedback_id = 0
	_material = null
