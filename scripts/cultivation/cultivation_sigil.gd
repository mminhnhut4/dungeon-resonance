class_name CultivationSigil
extends Node2D
## One planned mark; no automatic damage/tick/proc. Owned by current room.
var runtime: CultivationStyleRuntime
var age: float = 0.0
var pulse_remaining: float = 0.0
var attempts: int = 0
var accepted_hits: int = 0
var root_id: int = 0
var hitbox: Hitbox
var data: CultivationStyleData
var pulsing: bool = false
func _ready() -> void:
	add_to_group(&"cultivation_sigils")
	hitbox = ActorCombatRig.hitbox(self, 16)
	hitbox.contact_detected.connect(_contact)
	process_physics_priority = 25
	z_index = 6
func is_armed() -> bool:
	return age >= data.mark_arm_seconds and age < data.mark_lifetime and not pulsing and not is_queued_for_deletion()
func begin_pulse() -> void:
	if not is_armed(): return
	pulsing = true
	pulse_remaining = data.pulse_active
	var attack := AttackSnapshot.new()
	attack.source_id = runtime.actor.get_instance_id()
	attack.source_team_id = 1
	attack.attack_id = root_id
	attack.root_event_id = root_id
	var shape := CircleShape2D.new()
	shape.radius = data.radius
	hitbox.activate(attack, shape, Vector2.ZERO)
func _physics_process(delta: float) -> void:
	if not is_instance_valid(runtime) or not is_instance_valid(runtime.actor) or runtime.actor.health.current_health <= 0:
		cancel()
		return
	if runtime.is_frozen(): return
	age += delta
	if pulsing:
		pulse_remaining -= delta
		if pulse_remaining > 0: hitbox.sample_contacts()
		else:
			hitbox.deactivate()
			queue_free()
	elif age >= data.mark_lifetime: cancel()
	queue_redraw()
func _contact(target: Hurtbox, attack: AttackSnapshot) -> void:
	if attempts >= data.maximum_targets: return
	if not runtime.clear_line(global_position, target.global_position): return
	attempts += 1
	var event: DamageEvent = runtime.make_event(target, attack, data.damage)
	event.slow_multiplier = data.slow_multiplier
	event.slow_seconds = data.slow_seconds
	event.cosmetic_element = &"wind"
	var result: DamageResult = target.take_damage(event)
	if not result.blocked:
		accepted_hits += 1
		runtime.confirm_hit(event, result)
	if attempts >= data.maximum_targets: hitbox.deactivate()
func cancel() -> void:
	if is_instance_valid(hitbox): hitbox.deactivate()
	queue_free()
func _draw() -> void:
	var color: Color = data.tint
	var opacity: float = 1.0 if is_armed() else 0.45
	draw_circle(Vector2.ZERO, data.radius, Color(color, 0.08 if not pulsing else 0.20))
	draw_arc(Vector2.ZERO, data.radius, 0, TAU, 36, Color(color, opacity), 2.0 if not pulsing else 4.0)
	draw_line(Vector2(-12, -12), Vector2(12, 12), color, 2)
	draw_line(Vector2(-12, 12), Vector2(12, -12), color, 2)
