class_name Hitbox
extends Area2D
## Detection belongs here; damage calculation belongs in DamageResolver.

signal contact_detected(target: Hurtbox, snapshot: AttackSnapshot)
var attack_snapshot: AttackSnapshot
@export var collision_shape: CollisionShape2D
@export var maximum_query_results: int = 32
var active: bool = false
var _query_shape: Shape2D
var _hit_targets: Dictionary[int, bool] = {}


func activate(snapshot: AttackSnapshot, shape: Shape2D, offset: Vector2) -> void:
	assert(snapshot != null and shape != null and collision_shape != null)
	attack_snapshot = snapshot
	_query_shape = shape
	position = offset
	_hit_targets.clear()
	active = true
	collision_shape.set_deferred("shape", shape)
	collision_shape.set_deferred("disabled", false)


func deactivate() -> void:
	active = false
	attack_snapshot = null
	_query_shape = null
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)


func sample_contacts() -> void:
	if not active or attack_snapshot == null:
		return
	# Query the current authored shape/transform, avoiding the one-tick overlap
	# cache delay after opening, moving or flipping an Area2D hitbox.
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _query_shape
	query.transform = global_transform
	query.collision_mask = collision_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var contacts: Array[Dictionary] = get_world_2d().direct_space_state.intersect_shape(query, maximum_query_results)
	for contact: Dictionary in contacts:
		var target := contact.collider as Hurtbox
		if target == null:
			continue
		var target_id: int = target.get_actor_id()
		if target_id == attack_snapshot.source_id or _hit_targets.has(target_id):
			continue
		if target.team_id != 0 and target.team_id == attack_snapshot.source_team_id:
			continue
		# One delivery attempt per actor/window, including invulnerable targets.
		_hit_targets[target_id] = true
		contact_detected.emit(target, attack_snapshot)
		if not active:
			break
