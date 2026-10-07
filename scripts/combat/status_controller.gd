class_name StatusController
extends Node
## Per-target burn/stun clocks; child DOT never reapplies runes/resonance.

signal damage_requested(event: DamageEvent)

@export var health: HealthComponent
@export var accepts_stun: bool = true
var combat_feedback: CombatFeedback
var burn_remaining: float = 0.0
var stun_remaining: float = 0.0
var _burn_damage: float = 0.0
var _burn_interval: float = 0.5
var _burn_tick: float = 0.0
var _burn_source: DamageEvent
var movement_multiplier: float = 1.0
var attack_speed_multiplier: float = 1.0


func modify_damage(event: DamageEvent) -> float:
	return event.base_damage


func apply(event: DamageEvent) -> void:
	if event.burn_damage > 0.0 and event.burn_duration > 0.0:
		_burn_source = event
		_burn_damage = maxf(_burn_damage, event.burn_damage)
		_burn_interval = maxf(0.1, event.burn_interval)
		if burn_remaining <= 0.0:
			_burn_tick = _burn_interval
		burn_remaining = maxf(burn_remaining, event.burn_duration)
	if accepts_stun:
		stun_remaining = maxf(stun_remaining, event.stun_seconds)


func _physics_process(delta: float) -> void:
	if health == null or health.current_health <= 0.0:
		clear()
		return
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen():
		return
	stun_remaining = maxf(0.0, stun_remaining - delta)
	if burn_remaining <= 0.0 or _burn_source == null:
		return
	var elapsed: float = minf(delta, burn_remaining)
	burn_remaining = maxf(0.0, burn_remaining - delta)
	_burn_tick -= elapsed
	while _burn_tick <= 0.000001 and _burn_source != null and health.current_health > 0.0:
		_burn_tick += _burn_interval
		var event := DamageEvent.new()
		event.source_id = _burn_source.source_id
		event.source_team_id = _burn_source.source_team_id
		event.target_id = health.get_parent().get_instance_id()
		event.attack_id = CombatIds.next_id()
		event.root_event_id = _burn_source.root_event_id
		event.parent_event_id = _burn_source.attack_id
		event.hit_window_id = 1
		event.source_kind = DamageEvent.SourceKind.DOT
		event.allow_resonance = false
		event.base_damage = _burn_damage
		damage_requested.emit(event)
	if burn_remaining <= 0.0:
		_burn_source = null
		_burn_damage = 0.0


func is_stunned() -> bool:
	return stun_remaining > 0.0


func clear() -> void:
	burn_remaining = 0.0
	stun_remaining = 0.0
	_burn_source = null
	_burn_damage = 0.0
	_burn_tick = 0.0
