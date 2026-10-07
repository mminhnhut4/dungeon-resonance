class_name ElementStatusController
extends StatusController
## Per-actor state. Poison/freeze use finite clocks and the shared damage pipeline.

var slow_remaining: float = 0.0
var slow_factor: float = 1.0
var freeze_meter: float = 0.0
var freeze_remaining: float = 0.0
var armor_break_remaining: float = 0.0
var poison_count: int = 0
var poison_remaining: float = 0.0
var poison_tick: float = 1.0
var poison_percent: float = 0.01
var poison_source: DamageEvent


func apply(event: DamageEvent) -> void:
	super.apply(event)
	if event.slow_seconds > 0.0:
		slow_factor = minf(slow_factor, clampf(event.slow_multiplier, 0.2, 1.0))
		slow_remaining = maxf(slow_remaining, event.slow_seconds)
	if accepts_stun and event.freeze_points > 0.0:
		freeze_meter = minf(100.0, freeze_meter + event.freeze_points)
		if freeze_meter >= 100.0:
			freeze_remaining = 1.5
			stun_remaining = maxf(stun_remaining, freeze_remaining)
	armor_break_remaining = maxf(armor_break_remaining, event.armor_break_seconds)
	if accepts_stun and event.interrupt_seconds > 0.0:
		stun_remaining = maxf(stun_remaining, event.interrupt_seconds)
	if event.poison_stacks > 0:
		poison_source = event
		poison_count = mini(5, poison_count + event.poison_stacks)
		poison_percent = clampf(event.poison_percent, 0.001, 0.03)
		poison_remaining = maxf(poison_remaining, event.poison_seconds)


func modify_damage(event: DamageEvent) -> float:
	var amount: float = event.base_damage
	if event.physical_damage and armor_break_remaining > 0.0:
		amount *= 1.25
	if event.thermal_shock and freeze_remaining > 0.0:
		amount *= 3.0
		freeze_remaining = 0.0
		freeze_meter = 0.0
		stun_remaining = 0.0
		event.freeze_points = 0.0
	if event.consume_poison and poison_count > 0:
		amount += health.maximum_health * poison_percent * poison_count * minf(4.0, poison_remaining)
		poison_count = 0
		poison_remaining = 0.0
		poison_source = null
	if event.consume_poison:
		event.poison_stacks = 0
	return amount


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if health == null or health.current_health <= 0.0:
		return
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen():
		return
	slow_remaining = maxf(0.0, slow_remaining - delta)
	freeze_remaining = maxf(0.0, freeze_remaining - delta)
	armor_break_remaining = maxf(0.0, armor_break_remaining - delta)
	if slow_remaining <= 0.0:
		slow_factor = 1.0
	movement_multiplier = slow_factor
	attack_speed_multiplier = slow_factor
	if freeze_remaining <= 0.0 and freeze_meter >= 100.0:
		freeze_meter = 0.0
	if poison_count > 0 and poison_source != null:
		var elapsed: float = minf(delta, poison_remaining)
		poison_remaining = maxf(0.0, poison_remaining - delta)
		poison_tick -= elapsed
		while poison_tick <= 0.000001 and health.current_health > 0.0:
			poison_tick += 1.0
			var tick := DamageEvent.new()
			tick.source_id = poison_source.source_id
			tick.source_team_id = poison_source.source_team_id
			tick.target_id = health.get_parent().get_instance_id()
			tick.attack_id = CombatIds.next_id()
			tick.root_event_id = poison_source.root_event_id
			tick.parent_event_id = poison_source.attack_id
			tick.hit_window_id = 1
			tick.source_kind = DamageEvent.SourceKind.DOT
			tick.base_damage = health.maximum_health * poison_percent * poison_count
			damage_requested.emit(tick)
		if poison_remaining <= 0.0:
			poison_count = 0
			poison_source = null
			poison_tick = 1.0


func clear() -> void:
	super.clear()
	slow_remaining = 0.0
	slow_factor = 1.0
	movement_multiplier = 1.0
	attack_speed_multiplier = 1.0
	freeze_meter = 0.0
	freeze_remaining = 0.0
	armor_break_remaining = 0.0
	clear_poison()


func clear_poison() -> bool:
	var was_poisoned: bool = poison_count > 0
	poison_count = 0
	poison_remaining = 0.0
	poison_tick = 1.0
	poison_source = null
	return was_poisoned
