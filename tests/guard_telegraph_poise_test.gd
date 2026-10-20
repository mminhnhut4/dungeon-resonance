extends "res://tests/world_enemy_test.gd"
## Synthetic resolver/FSM regression, separate from input-only native evidence.
func _guard() -> void:
	await super._guard()
	var guard: BaseEnemy=await _fresh(&"ancient_guard",Vector2(578,640))
	guard.ai_enabled=true
	await _time(.10)
	_check(guard.state_machine.get_state_id()==&"telegraph" and guard.has_poise(),"Guard's existing slow warning has poise")
	var clock_before: float=guard.state_time
	var hp_before: float=guard.health.current_health
	var hit: DamageEvent=_damage(guard,8)
	hit.knockback=Vector2(500,-100)
	guard.hurtbox.take_damage(hit)
	_check(guard.health.current_health==hp_before-8 and guard.state_machine.get_state_id()==&"telegraph" and guard.state_time==clock_before and guard.motor._pending_impulse.is_zero_approx(),"Ordinary sword hit damages but does not reset committed tell or add knockback")
	await _time(.38)
	_check(guard.attacks_started==1 and guard.attack_hitbox.active,"The damaged tell completes its authored windup into one real attack")
	guard=await _fresh(&"ancient_guard",Vector2(578,640))
	guard.ai_enabled=true
	await _time(.10)
	var interrupt: DamageEvent=_damage(guard,12)
	interrupt.source_kind=DamageEvent.SourceKind.RESONANCE
	interrupt.spell_id=&"overload"
	interrupt.stun_seconds=.5
	guard.hurtbox.take_damage(interrupt)
	_check(guard.health.current_health==78 and guard.statuses.is_stunned() and guard.state_machine.get_state_id()==&"hurt" and not guard.attack_hitbox.active,"Nonlethal resonance stun interrupts telegraph through the shared resolver")
	await _time(.25)
	_check(guard.attacks_started==0 and not guard.attack_hitbox.active,"Interrupted tell cannot open a stale hit window during stun")
	await _time(.80)
	_check(not guard.statuses.is_stunned() and guard.state_machine.get_state_id()!=&"hurt","Stun and hurt finish without a permanent lock")
	guard=await _fresh(&"ancient_guard",Vector2(800,640))
	guard.state_machine.transition_to(&"chase")
	guard.hurtbox.take_damage(_damage(guard,8))
	_check(guard.state_machine.get_state_id()==&"hurt" and not guard.has_poise(),"Chase remains interruptible; no blanket Guard immunity")
	guard=await _fresh(&"ancient_guard",Vector2(578,640))
	guard.ai_enabled=true
	await _time(.10)
	guard.hurtbox.take_damage(_damage(guard,1000))
	_check(guard.health.current_health<=0 and guard.state_machine.get_state_id()==&"dead" and not guard.attack_hitbox.active,"Lethal damage still cancels the warning and deactivates collision")
	var bat: BaseEnemy=await _fresh(&"bloodwing_bat",Vector2(590,550))
	bat.state_machine.transition_to(&"telegraph")
	bat.hurtbox.take_damage(_damage(bat,8))
	_check(bat.state_machine.get_state_id()==&"hurt" and not bat.has_poise(),"Other movesets retain existing ordinary-hit interruption")
