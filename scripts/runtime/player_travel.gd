class_name PlayerTravel
extends RefCounted
## Relocation within the same session. Ending/restarting a run remains GameFlow's job.
enum Kind { SAFE, INTRA_EXPEDITION, END_EXPEDITION }

static func relocate(actor: Player, location: Vector2, kind: Kind = Kind.SAFE) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or actor.is_queued_for_deletion():
		return false
	if kind not in [Kind.SAFE, Kind.INTRA_EXPEDITION] or not location.is_finite() or actor.health.current_health <= 0.0:
		return false
	# Cancel old-room movement/actions without refunding a committed dash or
	# granting an extra airborne charge. HP/energy/recipe clocks already remain
	# on the same Player. The original reset/respawn APIs keep their semantics.
	var cooldown: float = actor.motor.dash_cooldown_remaining
	var air_available: bool = actor.motor.air_dash_available
	var build_motor: BuildPlayerMotor = actor.motor as BuildPlayerMotor
	var used_air_dashes: int = build_motor.air_dashes_used if build_motor != null else 0
	var style_binding: Variant = actor.get_meta(&"opening_style_binding") if actor.has_meta(&"opening_style_binding") else null
	if is_instance_valid(style_binding): style_binding.before_travel()
	actor.relocate(location)
	actor.motor.dash_cooldown_remaining = cooldown
	actor.motor.air_dash_available = air_available
	if build_motor != null:
		build_motor.air_dashes_used = used_air_dashes
	if is_instance_valid(style_binding): style_binding.refresh_room()
	return true
