extends "res://tests/survival_test_base.gd"
## Synthetic owner fixture; ordinary Slime scene/stats and real AI/DoT pipeline.
var enemy: SlimeEnemy
var stage: String
var before_patch: bool
var trace: Array[Dictionary]=[]
var pending: Dictionary[int,Dictionary]={}
var metrics: Dictionary={}
func _init() -> void:
	suite="slime_dot_control";use_neutral_equipment=false
func _initialize() -> void:
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	super._initialize()
func fresh(label: String) -> void:
	if is_instance_valid(enemy):enemy.queue_free();await _step(2)
	pending.clear();stage=label
	player.set_physics_process(false);player.controls_enabled=false
	player.global_position=Vector2(880,640);player.motor.reset_motion();player.hurtbox.set_invulnerable(true)
	enemy=preload("res://scenes/enemies/slime_enemy.tscn").instantiate() as SlimeEnemy
	enemy.position=Vector2(850,640);enemy.player=player;enemy.combat_feedback=level.combat_feedback
	level.add_child(enemy);enemy.statuses.combat_feedback=level.combat_feedback
	enemy.hurtbox.damage_received.connect(incoming);enemy.hurtbox.hit_resolved.connect(resolved)
	await _step(3)
func event(amount: float) -> DamageEvent:
	var hit:=DamageEvent.new();hit.source_id=player.get_instance_id();hit.source_team_id=1;hit.target_id=enemy.get_instance_id();hit.attack_id=CombatIds.next_id();hit.root_event_id=hit.attack_id;hit.hit_window_id=1;hit.base_damage=amount;return hit
func incoming(hit: DamageEvent) -> void:
	pending[hit.attack_id]={"before":String(enemy.state_machine.get_state_id()),"active_before":enemy.bite_hitbox.active,"hp_before":enemy.health.current_health,"state_time_before":enemy._state_time}
func resolved(hit: DamageEvent,result: DamageResult) -> void:
	var record: Dictionary=pending.get(hit.attack_id,{}).duplicate()
	record.merge({"stage":stage,"frame":Engine.get_physics_frames(),"kind":hit.source_kind,"attack":hit.attack_id,"root":hit.root_event_id,"amount":result.actual_damage,"blocked":result.blocked,"killed":result.killed,"after":String(enemy.state_machine.get_state_id()),"active_after":enemy.bite_hitbox.active,"hp_after":enemy.health.current_health,"state_time_after":enemy._state_time},true)
	trace.append(record);pending.erase(hit.attack_id)
func ticks(label: String) -> Array[Dictionary]:
	return trace.filter(func(r: Dictionary)->bool:return r["stage"]==label and r["kind"]==DamageEvent.SourceKind.DOT and not r["blocked"])
func wait_attack() -> bool:
	for i: int in Engine.physics_ticks_per_second*3:
		if enemy.state_machine.get_state_id()==&"attack" and not enemy.bite_hitbox.active:return true
		await _step(1)
	return false
func test_system() -> void:
	before_patch="--before" in OS.get_cmdline_user_args();session.set_enabled(false)
	await fresh("burn")
	var maximum: float=enemy.health.maximum_health
	var fire: DamageEvent=event(1);fire.burn_damage=3;fire.burn_duration=3;fire.burn_interval=.5
	enemy.hurtbox.take_damage(fire)
	var bite_starts: int=0;var was_active: bool=false
	for i: int in ceili(3.2*Engine.physics_ticks_per_second):
		await _step(1)
		var active: bool=enemy.bite_hitbox.active
		if active and not was_active:bite_starts+=1
		was_active=active
	var burn: Array[Dictionary]=ticks("burn")
	var cancelled: Array[Dictionary]=burn.filter(func(r: Dictionary)->bool:return r["before"]=="attack" and r["after"]=="hurt")
	_check(burn.size()==6 and is_equal_approx(enemy.health.current_health,maximum-19),"Original burn delivers exactly six3damage ticks plus direct1, with unchanged scene HP")
	_check(burn.all(func(r: Dictionary)->bool:return r["amount"]==3 and r["root"]==fire.root_event_id),"Each burn tick retains authored amount and the original root")
	var unique: Dictionary={}
	for r: Dictionary in burn:unique[r["attack"]]=true
	_check(unique.size()==6,"No duplicate DOT callback or attack ID is manufactured")
	if before_patch:_check(cancelled.size()>0,"Baseline reproduction: real burn tick cancels AI bite windup into hurt")
	else:
		_check(burn.all(func(r: Dictionary)->bool:return r["after"]==r["before"] and r["active_after"]==r["active_before"] and r["state_time_after"]==r["state_time_before"]),"Burn tick never creates contact stagger or cancels an active bite")
		_check(bite_starts>0,"Burning ordinary Slime retains real tell-to-lunge execution")
	metrics["burn"]={"ticks":burn.size(),"windup_cancels":cancelled.size(),"bite_starts":bite_starts,"remaining_hp":enemy.health.current_health,"maximum_hp":maximum}
	await fresh("chilled_burn")
	var mixed: DamageEvent=event(1);mixed.burn_damage=3;mixed.burn_duration=3;mixed.burn_interval=.5
	var authored_ice: RuneData=load("res://data/runes/IceRune.tres")
	mixed.slow_multiplier=authored_ice.slow_multiplier;mixed.slow_seconds=authored_ice.slow_seconds
	enemy.hurtbox.take_damage(mixed);await _time(1.2)
	var chilled: Array[Dictionary]=ticks("chilled_burn")
	var windup_cancels: int=chilled.filter(func(r: Dictionary)->bool:return r["before"]=="attack" and not r["active_before"] and r["after"]=="hurt").size()
	_check(chilled.size()==2 and enemy.health.current_health==maximum-7,"Existing Ice slow changes no burn amount or tick count")
	if before_patch:_check(windup_cancels>0,"Baseline reproduction: burn with authored Ice slow cancels windup before bite opens")
	else:_check(windup_cancels==0 and chilled.all(func(r: Dictionary)->bool:return r["before"]==r["after"]),"Burn cannot manufacture a flinch inside the slowed windup")
	metrics["chilled_burn"]={"ticks":chilled.size(),"windup_cancels":windup_cancels,"remaining_hp":enemy.health.current_health}
	await fresh("poison")
	var poison: DamageEvent=event(1);poison.poison_stacks=1;poison.poison_percent=.01;poison.poison_seconds=2.1
	enemy.hurtbox.take_damage(poison);await _time(2.3)
	var poison_ticks: Array[Dictionary]=ticks("poison")
	_check(poison_ticks.size()==2 and poison_ticks.all(func(r: Dictionary)->bool:return is_equal_approx(r["amount"],maximum*.01)),"Poison keeps its original two1percent ticks")
	if not before_patch:_check(poison_ticks.all(func(r: Dictionary)->bool:return r["before"]==r["after"] and r["state_time_before"]==r["state_time_after"]),"Poison ticks also preserve the current AI phase")
	metrics["poison"]={"ticks":poison_ticks.size(),"remaining_hp":enemy.health.current_health}
	await fresh("direct")
	_check(await wait_attack(),"Actual unmodified AI reaches bite windup")
	var direct: DamageEvent=event(1);var result: DamageResult=enemy.hurtbox.take_damage(direct)
	_check(not result.blocked and enemy.state_machine.get_state_id()==&"hurt" and not enemy.bite_hitbox.active and enemy._hurt_remaining==.18,"Direct contact still cancels windup and keeps authored flinch")
	var hp: float=enemy.health.current_health;var hit_count: int=enemy.hit_count
	_check(enemy.hurtbox.take_damage(direct).blocked and enemy.health.current_health==hp and enemy.hit_count==hit_count,"Duplicate direct contact cannot deal damage or restart hurt")
	await fresh("freeze")
	var ice: DamageEvent=event(1);ice.freeze_points=100;enemy.hurtbox.take_damage(ice)
	var elemental: ElementStatusController=enemy.statuses as ElementStatusController
	_check(elemental.freeze_remaining==1.5 and enemy.statuses.is_stunned(),"Genuine freeze still opens the original1.5s control window")
	await _time(.4)
	_check(enemy.state_machine.get_state_id()==&"hurt" and not enemy.bite_hitbox.active and elemental.freeze_remaining>1,"Freeze continues to stop attacks rather than being treated as cosmetic DOT")
	await _time(1.4)
	_check(elemental.freeze_remaining==0 and not enemy.statuses.is_stunned(),"Freeze expires on the unchanged owner clock")
	await fresh("stun")
	var stun: DamageEvent=event(1);stun.stun_seconds=.6;enemy.hurtbox.take_damage(stun);await _time(.3)
	_check(enemy.statuses.is_stunned() and enemy.state_machine.get_state_id()==&"hurt" and not enemy.bite_hitbox.active,"Explicit stun remains genuine control")
	await _time(.5);_check(not enemy.statuses.is_stunned(),"Explicit stun expires normally")
	await fresh("death")
	var lethal_setup: DamageEvent=event(enemy.health.current_health-.5);lethal_setup.burn_damage=1;lethal_setup.burn_duration=2;lethal_setup.burn_interval=.5
	enemy.hurtbox.take_damage(lethal_setup)
	var actor_id: int=enemy.get_instance_id();var status_id: int=enemy.statuses.get_instance_id()
	for i: int in Engine.physics_ticks_per_second:
		if ticks("death").size()>0:break
		await _step(1)
	var deaths: Array[Dictionary]=ticks("death");var callbacks: int=trace.size()
	_check(deaths.size()==1 and deaths[0]["killed"] and deaths[0]["after"]=="dead" and is_equal_approx(deaths[0]["amount"],.5),"Lethal DOT still kills exactly once and does not resurrect hurt state")
	await _time(.8)
	_check(trace.size()==callbacks and not is_instance_id_valid(actor_id) and not is_instance_id_valid(status_id),"After lethal tick no delayed damage callback remains and actor/status are freed")
	enemy=null
	var f:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("slime-dot.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"before_patch":before_patch,"physics_hz":Engine.physics_ticks_per_second,"metrics":metrics,"trace":trace,"scope":"Synthetic DamageEvents, real Slime scene HP/stats and actual AI; Player stationary/invulnerable fixture only. Not natural gameplay or FPS evidence."},"\t"));f.close()
