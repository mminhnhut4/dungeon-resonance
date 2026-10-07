class_name BodyConditionComponent
extends Node
## Actor-owned wounds and stress. No permanent modification of movement data.

signal mental_break_started(kind: StringName)
var actor: CharacterBody2D
var health: HealthComponent
var hurtbox: Hurtbox
var feedback: CombatFeedback
var enabled: bool = true
var bleeding: bool = false
var bleed_motion: float = 0.0
var still_time: float = 0.0
var bleed_tick: float = 1.0
var cripple_remaining: float = 0.0
var burn_remaining: float = 0.0
var stress: float = 0.0
var break_kind: StringName = &""
var break_remaining: float = 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	health = actor.health
	hurtbox = actor.hurtbox
	hurtbox.hit_resolved.connect(_on_hit)
	if actor is Player:
		actor.equipped_weapon.swing_resolved.connect(_on_swing)
		actor.resonance_controller.resonance_triggered.connect(_on_cast)


func _on_hit(event: DamageEvent, result: DamageResult) -> void:
	if not enabled or result.blocked or health.current_health <= 0.0 or event.source_kind == DamageEvent.SourceKind.DOT:
		return
	if event.heavy_hit or event.critical:
		var choices: Array[StringName] = [&"bleeding", &"crippled", &"severe_burn"]
		inflict(choices[rng.randi_range(0, 2)])


func inflict(id: StringName) -> void:
	if not enabled:
		return
	match id:
		&"bleeding":
			bleeding = true
			bleed_tick = 1.0
			still_time = 0.0
		&"crippled": cripple_remaining = 5.0
		&"severe_burn": burn_remaining = 8.0
	_apply_modifiers()


func _physics_process(delta: float) -> void:
	if not enabled or health.current_health <= 0.0 or (is_instance_valid(feedback) and feedback.is_frozen()):
		return
	cripple_remaining = maxf(0.0, cripple_remaining - delta)
	burn_remaining = maxf(0.0, burn_remaining - delta)
	if bleeding:
		var moving: bool = actor.velocity.length() > 8.0
		still_time = 0.0 if moving else still_time + delta
		if moving:
			bleed_motion = minf(3.0, bleed_motion + delta * 0.4)
		if still_time >= 1.5:
			bandage()
		else:
			bleed_tick -= delta
			if bleed_tick <= 0.0:
				bleed_tick += 1.0
				_internal_damage(1.0 + bleed_motion)
	if break_remaining > 0.0:
		break_remaining = maxf(0.0, break_remaining - delta)
		if break_remaining <= 0.0:
			break_kind = &""
			stress = minf(stress, 60.0)
	_apply_modifiers()


func bandage() -> void:
	bleeding = false
	bleed_motion = 0.0
	still_time = 0.0
	bleed_tick = 1.0


func add_stress(amount: float, forced_break: StringName = &"") -> void:
	if not enabled or not is_finite(amount):
		return
	stress = clampf(stress + amount, 0.0, 100.0)
	if stress >= 100.0 and break_remaining <= 0.0:
		break_kind = forced_break if forced_break in [&"phantoms", &"berserk"] else &"phantoms" if rng.randf() < 0.5 else &"berserk"
		break_remaining = 12.0
		mental_break_started.emit(break_kind)
		_apply_modifiers()


func _on_cast(_attack_id: int) -> void:
	if enabled and actor is Player and not actor.resonance_controller.catalyst_a.runtime_state.installed_runes.is_empty():
		add_stress(4.0 + actor.resonance_controller.catalyst_a.runtime_state.installed_runes.size())


func _on_swing(hit_any: bool) -> void:
	if enabled and break_kind == &"berserk" and not hit_any:
		_internal_damage(5.0)


func _internal_damage(amount: float) -> void:
	var event := DamageEvent.new()
	event.source_id = get_instance_id()
	event.source_team_id = 0
	event.target_id = actor.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.source_kind = DamageEvent.SourceKind.DOT
	event.ignore_damage_grace = true
	event.base_damage = amount
	hurtbox.take_internal_damage(event)


func _apply_modifiers() -> void:
	health.healing_multiplier = 0.5 if enabled and burn_remaining > 0.0 else 1.0
	if actor is Player:
		actor.motor.condition_speed_multiplier = 0.6 if enabled and cripple_remaining > 0.0 else 1.0
		actor.motor.air_dash_blocked = enabled and cripple_remaining > 0.0
		actor.resonance_controller.cooldown_multiplier = 1.5 if enabled and burn_remaining > 0.0 else 1.0
		actor.equipped_weapon.outgoing_multiplier = 1.5 if enabled and break_kind == &"berserk" else 1.0
	elif actor is SlimeEnemy or actor is BossGolem or actor is BaseEnemy:
		actor.condition_speed_multiplier = 0.6 if enabled and cripple_remaining > 0.0 else 1.0


func clear() -> void:
	bandage()
	cripple_remaining = 0.0
	burn_remaining = 0.0
	stress = 0.0
	break_kind = &""
	break_remaining = 0.0
	_apply_modifiers()


func summary() -> String:
	return "%s%s%s%s" % ["CHẢY MÁU · " if bleeding else "", "CHÂN %.1fs · " % cripple_remaining if cripple_remaining > 0.0 else "", "BỎNG %.1fs · " % burn_remaining if burn_remaining > 0.0 else "", break_kind.to_upper() if break_remaining > 0.0 else ""]
