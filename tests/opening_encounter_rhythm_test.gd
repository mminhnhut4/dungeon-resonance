extends SceneTree
const WINDOW: Script=preload("res://scripts/combat/opening_attack_window.gd")
const GUARD: PackedScene=preload("res://scenes/enemies/ancient_guard.tscn")
const RANGED: PackedScene=preload("res://scenes/enemies/runic_slime_harrier.tscn")
var checks: int=0
var failures: int=0
var arena: Node2D
var hero: Player
var gate: Node
var feedback: CombatFeedback
var enemies: Array[Node2D]=[]
var timeline: Array[Dictionary]=[]
var tick: int=0
var max_pressure: int=0
var early_hitboxes: int=0
var hero_hits: int=0
var world_flight_samples: int=0
var wrong_flight_owner: int=0
var bite_samples: int=0
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
	return ok
func step(n: int) -> void:
	for i: int in n:
		await physics_frame;await process_frame;tick+=1;observe()
func seconds(s: float) -> void:await step(ceili(s*Engine.physics_ticks_per_second))
func observe() -> void:
	var active: Array[int]=[]
	for e: Node2D in enemies:
		if not is_instance_valid(e) or e.is_queued_for_deletion():continue
		if bool(e.call("opening_attack_committed")):active.append(e.get_instance_id())
		if e is BaseEnemy and e.state_machine.get_state_id()==&"telegraph" and e.attack_hitbox.active:early_hitboxes+=1
		if e is SlimeEnemy and e.bite_hitbox.active:bite_samples+=1
		if e is SlimeEnemy and e.state_machine.get_state_id()==&"attack" and e._state_time<e.telegraph_seconds and e.bite_hitbox.active:early_hitboxes+=1
	for group: StringName in [&"world_enemy_hazards",&"runic_harrier_bolts"]:
		for h: Node in get_nodes_in_group(group):
			if not h.is_queued_for_deletion() and h.get_parent()==arena:
				if not active.has(h.source_id):active.append(h.source_id)
				if group==&"world_enemy_hazards":
					world_flight_samples+=1
					if gate!=null and gate.call("current_source_id")!=h.source_id:wrong_flight_owner+=1
	max_pressure=maxi(max_pressure,active.size())
	if timeline.size()<6000:timeline.append({"tick":tick,"active":active,"quiet":gate.get("quiet_remaining") if is_instance_valid(gate) else -1})
func fresh(with_gate: bool=true) -> void:
	if is_instance_valid(arena):arena.queue_free();await step(4)
	enemies.clear();timeline.clear();tick=0;max_pressure=0;early_hitboxes=0;world_flight_samples=0;wrong_flight_owner=0;bite_samples=0
	arena=Node2D.new();root.add_child(arena)
	var ground:=StaticBody2D.new();ground.position=Vector2(1000,650);ground.collision_layer=1
	var cs:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=Vector2(3000,20);cs.shape=shape;ground.add_child(cs);arena.add_child(ground)
	feedback=CombatFeedback.new();feedback.hit_stop_seconds=0;arena.add_child(feedback)
	hero=preload("res://scenes/actors/player/player.tscn").instantiate();hero.position=Vector2(900,640);arena.add_child(hero);hero.set_physics_process(false);hero.controls_enabled=false;hero.hurtbox.set_invulnerable(true)
	gate=WINDOW.new() if with_gate else null
	if gate!=null:gate.set("feedback",feedback);arena.add_child(gate)
	await step(2)
func guard_at(x: float) -> BaseEnemy:
	var e: BaseEnemy=GUARD.instantiate();e.position=Vector2(x,640);e.player=hero;e.combat_feedback=feedback;e.opening_attack_window=gate;arena.add_child(e);enemies.append(e);return e
func runic_at(x: float) -> SlimeEnemy:
	var e: SlimeEnemy=RANGED.instantiate();e.position=Vector2(x,640);e.player=hero;e.combat_feedback=feedback;e.opening_attack_window=gate;arena.add_child(e);enemies.append(e);return e
func event_for(e: Node,amount: float=1) -> DamageEvent:
	var hit:=DamageEvent.new();hit.source_id=hero.get_instance_id();hit.source_team_id=1;hit.target_id=e.get_instance_id();hit.attack_id=CombatIds.next_id();hit.root_event_id=hit.attack_id;hit.hit_window_id=1;hit.base_damage=amount;return hit
func wait_state(e: BaseEnemy,state: StringName) -> bool:
	for i: int in Engine.physics_ticks_per_second*5:
		if e.state_machine.get_state_id()==state:return true
		await step(1)
	return false
func wait_tell(e: SlimeEnemy) -> bool:
	for i: int in Engine.physics_ticks_per_second*5:
		if float(e.get("ranged_windup"))>0:return true
		await step(1)
	return false
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	root.unfocusable=true;Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if not check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"QA isolation"):quit(2);return
	await fresh();var left: BaseEnemy=guard_at(840);var right: BaseEnemy=guard_at(960);var ranged: SlimeEnemy=runic_at(1100)
	await seconds(12)
	check(max_pressure==1,"Three real AI owners never overlap tells, active hitboxes or flying Runic bolts")
	check(early_hitboxes==0,"No hitbox activates inside a melee telegraph")
	check(left.attacks_started>0 and right.attacks_started>0 and int(ranged.get("shots_fired"))>0,"Both Guards and ranged role get real turns; no starvation in the bounded arena")
	check(left.health.maximum_health==90 and ranged.health.maximum_health==60 and left.definition.attack_damage==24,"Authoring preserves original HP and Guard damage")
	var previous: int=0;var empty_since: int=-1;var gaps: Array[int]=[]
	for row: Dictionary in timeline:
		var active: Array=row["active"]
		if active.is_empty():
			if previous!=0 and empty_since<0:empty_since=row["tick"]
		else:
			if empty_since>=0:gaps.append(int(row["tick"])-empty_since);empty_since=-1
			previous=int(active[0])
	check(not gaps.is_empty() and gaps.min()>=floori(.35*Engine.physics_ticks_per_second)-1,"Every measured handoff leaves at least0.35s counter beat within one physics tick")
	var mixed_metrics: Dictionary={"left_attacks":left.attacks_started,"right_attacks":right.attacks_started,"shots":ranged.get("shots_fired"),"gap_ticks":gaps,"peak":max_pressure,"samples":timeline.duplicate(true)}
	await fresh()
	var bat: BaseEnemy=preload("res://scenes/enemies/bloodwing_bat.tscn").instantiate();bat.position=Vector2(1220,510);bat.player=hero;bat.combat_feedback=feedback;bat.opening_attack_window=gate;arena.add_child(bat);enemies.append(bat)
	left=guard_at(840);await seconds(8)
	check(world_flight_samples>0 and bat.attacks_started>0 and left.attacks_started>0,"Actual Bat jade flight and Guard both receive turns")
	check(max_pressure==1 and wrong_flight_owner==0,"Actual Bat flight holds its owner without Guard overlap")
	await fresh()
	var slime: SlimeEnemy=preload("res://scenes/enemies/slime_enemy.tscn").instantiate();slime.position=Vector2(930,640);slime.player=hero;slime.combat_feedback=feedback;slime.opening_attack_window=gate;arena.add_child(slime);enemies.append(slime)
	left=guard_at(840);await seconds(6)
	check(bite_samples>0 and left.attacks_started>0 and max_pressure==1 and early_hitboxes==0,"Ordinary Slime bite preserves tell and shares lane without overlap")
	await fresh();left=guard_at(840);ranged=runic_at(1100);await step(5);ranged.ai_enabled=false;await seconds(2)
	check(gate.call("current_source_id")!=ranged.get_instance_id() and left.attacks_started>0,"Disabled queued actor expires and cannot block eligible attacks")
	ranged.ai_enabled=true;check(await wait_tell(ranged),"Reenabled actor reenters queue and receives a new legitimate turn")
	await fresh(false);left=guard_at(840);right=guard_at(960);await seconds(.3)
	check(max_pressure==2,"Non-opt-in rooms retain independent legacy attacks")
	await fresh();left=guard_at(840);right=guard_at(960);check(await wait_state(left,&"telegraph"),"Guard begins natural tell")
	var begun: int=left.attacks_started;var ice: DamageEvent=event_for(left);ice.freeze_points=100;left.hurtbox.take_damage(ice);await step(2)
	check(left.statuses.is_stunned() and left.state_machine.get_state_id()==&"hurt" and not left.attack_hitbox.active,"Actual freeze cancels pending Guard attack")
	check(float(gate.get("quiet_remaining"))>0 and gate.call("current_source_id")==0,"Cancellation releases lane and starts counter beat")
	await seconds(.22);check(right.attacks_started==0 and right.state_machine.get_state_id()!=&"telegraph","Other owner does not steal canceled tell's counter beat")
	await seconds(.7);check(left.attacks_started==begun and right.attacks_started>0,"Frozen owner cannot fire late; waiting owner progresses after beat")
	await fresh();ranged=runic_at(1100);check(await wait_tell(ranged),"Ranged starts natural tell")
	var start: int=tick;var locked: Vector2=ranged.get("locked_ranged_direction");hero.position.y-=120
	await seconds(.4);check(int(ranged.get("shots_fired"))==0 and float(ranged.get("ranged_windup"))>0,"Ranged cannot fire within first0.4s of new0.55s tell")
	for i: int in Engine.physics_ticks_per_second:
		if int(ranged.get("shots_fired"))>0:break
		await step(1)
	check(int(ranged.get("shots_fired"))==1 and tick-start>=floori(.55*Engine.physics_ticks_per_second)-1,"Ranged commit follows full authored tell")
	var bolts: Array[Node]=get_nodes_in_group(&"runic_harrier_bolts")
	check(bolts.size()==1 and (bolts[0] as EnemyHazard).direction.is_equal_approx(locked),"Shot uses original committed direction, not moved target")
	check(gate.call("current_source_id")==ranged.get_instance_id(),"Shot flight keeps lane after tell reaches zero")
	await seconds(1);check(get_nodes_in_group(&"runic_harrier_bolts").is_empty(),"Missed bolt expires at existing authored distance")
	await fresh();ranged=runic_at(1100);check(await wait_tell(ranged),"Direct interrupt reaches tell")
	ranged.hurtbox.take_damage(event_for(ranged));await step(1)
	check(float(ranged.get("ranged_windup"))==0 and float(gate.get("quiet_remaining"))>0,"Direct flinch cancels tell and opens beat")
	await seconds(1);check(int(ranged.get("shots_fired"))==0,"Canceled shot has no delayed commit")
	await fresh();ranged=runic_at(1100);check(await wait_tell(ranged),"DOT fixture reaches tell")
	var dot: DamageEvent=event_for(ranged);dot.source_kind=DamageEvent.SourceKind.DOT;ranged.hurtbox.take_damage(dot)
	check(float(ranged.get("ranged_windup"))>0 and gate.call("current_source_id")==ranged.get_instance_id(),"DOT damage neither fakes flinch nor releases owned lane")
	feedback.set_physics_process(false);feedback._frozen_this_tick=true
	var held: float=ranged.get("ranged_windup");var cd: float=ranged.get("ranged_remaining");await step(4)
	check(ranged.get("ranged_windup")==held and ranged.get("ranged_remaining")==cd,"Hitstop freezes telegraph and cooldown")
	feedback.reset_feedback();feedback.set_physics_process(true)
	var stun: DamageEvent=event_for(ranged);stun.stun_seconds=.6;ranged.hurtbox.take_damage(stun);await step(2)
	check(float(ranged.get("ranged_windup"))==0 and gate.call("current_source_id")==0,"Stun revokes lane without hidden projectile")
	var quiet: float=gate.get("quiet_remaining");feedback.set_physics_process(false);feedback._frozen_this_tick=true;await step(4)
	check(gate.get("quiet_remaining")==quiet,"Counter beat does not elapse during hitstop")
	feedback.reset_feedback();feedback.set_physics_process(true)
	await fresh();ranged=runic_at(1100);check(await wait_tell(ranged),"Target-loss fixture reaches tell")
	hero.health.apply_damage(10000);await step(3)
	check(ranged.player==null and gate.call("current_source_id")==0 and int(ranged.get("shots_fired"))==0,"Target death cancels pending lane/shot")
	await fresh();ranged=runic_at(1100);check(await wait_tell(ranged),"Owner-death fixture reaches tell")
	ranged.hurtbox.take_damage(event_for(ranged,100));await step(3)
	check(gate.call("current_source_id")==0 and get_nodes_in_group(&"runic_harrier_bolts").is_empty(),"Owner death releases without orphan shot")
	await fresh();ranged=runic_at(1100);check(await wait_tell(ranged),"Scene-loss fixture reaches tell")
	var elsewhere:=Node2D.new();root.add_child(elsewhere);hero.reparent(elsewhere);await step(3)
	check(ranged.player==null and gate.call("current_source_id")==0,"Target reparent leaves no cross-room attack ownership")
	hero.reparent(arena);elsewhere.queue_free()
	await fresh();ranged=runic_at(1100);check(await wait_tell(ranged),"Aggro memory fixture reaches tell")
	ranged.hurtbox.take_damage(event_for(ranged));check(ranged.hit_aggro.active(),"Accepted damage retains original target-memory owner")
	hero.position.x=3000;await seconds(20.1)
	check(not ranged.hit_aggro.active() and ranged.player==null and gate.call("current_source_id")==0,"Existing20s lease expiry still revokes pursuit and lane")
	var room_id: int=arena.get_instance_id();var gate_id: int=gate.get_instance_id();arena.queue_free();await step(4);enemies.clear()
	check(not is_instance_id_valid(room_id) and not is_instance_id_valid(gate_id) and get_nodes_in_group(&"runic_harrier_bolts").is_empty(),"Room teardown frees coordinator and pending flight")
	var file:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("encounter-tests.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"hz":Engine.physics_ticks_per_second,"mixed":mixed_metrics,"scope":"Synthetic real AI/physics/status arena; invulnerable stationary hero for timing. Not a player playtest or farm benchmark."},"\t"));file.close()
	await root.get_node("AudioManager").shutdown()
	print("RESULT EncounterRhythm checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
