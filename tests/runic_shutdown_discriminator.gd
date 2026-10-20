extends SceneTree
## Targeted synthetic arena; real inherited stats, AI, status, projectile and lease.
const PROTO: PackedScene=preload("res://scenes/enemies/runic_slime_harrier.tscn")
var checks: int=0
var failures: int=0
var arena: Node2D
var hero: Player
var actor: SlimeEnemy
var feedback: CombatFeedback
var wall: StaticBody2D
var hits: Array[Dictionary]=[]
var metrics: Dictionary={}
var dot_during_tell: int=0
func _initialize() -> void:call_deferred("run")
func step(n: int) -> void:
	for i: int in n:await physics_frame;await process_frame
func seconds(s: float) -> void:await step(ceili(s*Engine.physics_ticks_per_second))
func check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
	return ok
func floor_box(at: Vector2,size: Vector2) -> StaticBody2D:
	var box:=StaticBody2D.new();box.position=at;box.collision_layer=1
	var collider:=CollisionShape2D.new();var shape:=RectangleShape2D.new();shape.size=size;collider.shape=shape;box.add_child(collider);arena.add_child(box);return box
func fresh() -> void:
	if is_instance_valid(actor):actor.queue_free();await step(2)
	if is_instance_valid(wall):wall.queue_free();await step(2)
	hero.global_position=Vector2(1000,640);hero.motor.reset_motion();hero.health.reset_health();hero.hurtbox.set_invulnerable(true);hero.damage_grace_remaining=0;hero.action_state_machine.transition_to(&"ready")
	actor=PROTO.instantiate() as SlimeEnemy;actor.position=Vector2(800,640);actor.player=hero;actor.combat_feedback=feedback;arena.add_child(actor);actor.statuses.combat_feedback=feedback
	actor.hurtbox.damage_received.connect(incoming)
	await step(3)
func incoming(event: DamageEvent) -> void:
	if event.source_kind==DamageEvent.SourceKind.DOT and float(actor.get("ranged_windup"))>0:dot_during_tell+=1
func damage(amount: float) -> DamageEvent:
	var e:=DamageEvent.new();e.source_id=hero.get_instance_id();e.source_team_id=1;e.target_id=actor.get_instance_id();e.attack_id=CombatIds.next_id();e.root_event_id=e.attack_id;e.hit_window_id=1;e.base_damage=amount;return e
func wait_tell() -> bool:
	for i: int in Engine.physics_ticks_per_second*4:
		if float(actor.get("ranged_windup"))>0:return true
		await step(1)
	return false
func wait_shot() -> EnemyHazard:
	for i: int in Engine.physics_ticks_per_second*4:
		for n: Node in get_nodes_in_group(&"runic_harrier_bolts"):
			if not n.is_queued_for_deletion():return n as EnemyHazard
		await step(1)
	return null
func hero_hit(event: DamageEvent,result: DamageResult) -> void:hits.append({"base":event.base_damage,"actual":result.actual_damage,"blocked":result.blocked,"attack":event.attack_id,"poison":event.poison_stacks})
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if not check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated QA user root"):quit(2);return
	arena=Node2D.new();root.add_child(arena);floor_box(Vector2(1500,650),Vector2(4000,20))
	hero=preload("res://scenes/actors/player/player.tscn").instantiate();arena.add_child(hero);hero.set_physics_process(false);hero.controls_enabled=false;hero.hurtbox.hit_resolved.connect(hero_hit)
	feedback=CombatFeedback.new();feedback.hit_stop_seconds=0;arena.add_child(feedback)
	await fresh()
	var baseline: SlimeEnemy=preload("res://scenes/enemies/slime_enemy.tscn").instantiate();baseline.position=Vector2(2000,640);baseline.player=hero;arena.add_child(baseline);baseline.ai_enabled=false
	for prop: String in ["patrol_speed","chase_speed","aggro_radius","attack_range","telegraph_seconds","contact_damage_enabled"]:check(actor.get(prop)==baseline.get(prop),"Inherited baseline stat:"+prop)
	check(actor.health.maximum_health==baseline.health.maximum_health and actor.health.maximum_health==60,"Prototype inherits60HP rather than Mutant120HP")
	baseline.queue_free()
	check(await wait_tell(),"Actual AI starts the authored ranged tell")
	var lock: Vector2=actor.get("locked_ranged_direction");var x: float=actor.position.x
	await seconds(.1);check(is_equal_approx(actor.position.x,x),"Ranged tell stops approach while melee remains a separate choice")
	hero.global_position.y-=130
	var bolt: EnemyHazard=await wait_shot()
	check(bolt!=null,"One valid tell commits a projectile")
	if bolt!=null:
		check(bolt.direction.is_equal_approx(lock),"Projectile keeps the windup aim instead of homing at a dodge")
		var hp: float=hero.health.current_health;await seconds(.7);check(hero.health.current_health==hp,"Moving off the locked trajectory avoids the shot")
		await seconds(.35);check(not is_instance_valid(bolt),"Missed shot expires within its authored range instead of crossing the room for five seconds")
	await fresh();check(await wait_tell(),"Feedback-freeze fixture reaches tell")
	feedback.set_physics_process(false);feedback._frozen_this_tick=true
	var held_windup: float=actor.get("ranged_windup");var held_cooldown: float=actor.get("ranged_remaining")
	await step(5)
	check(actor.get("ranged_windup")==held_windup and actor.get("ranged_remaining")==held_cooldown and actor.get("shots_fired")==0,"Original feedback freeze pauses tell/cooldown without releasing a shot")
	feedback.reset_feedback();feedback.set_physics_process(true)
	await fresh();check(await wait_tell(),"Direct-interrupt fixture reaches tell")
	actor.hurtbox.take_damage(damage(1));check(float(actor.get("ranged_windup"))==0 and actor.state_machine.get_state_id()==&"hurt","Direct hit cancels pending ranged commit and retains flinch")
	await seconds(.7);check(actor.get("shots_fired")==0,"Canceled windup has no delayed shot")
	await fresh();check(await wait_tell(),"Freeze fixture reaches tell")
	var ice: DamageEvent=damage(1);ice.freeze_points=100;actor.hurtbox.take_damage(ice)
	check(actor.statuses.is_stunned() and float(actor.get("ranged_windup"))==0,"Genuine freeze immediately cancels windup")
	await seconds(1);check(actor.get("shots_fired")==0,"Frozen caster cannot release hidden delayed shots")
	await fresh();check(await wait_tell(),"Stun fixture reaches tell")
	var stun: DamageEvent=damage(1);stun.stun_seconds=.6;actor.hurtbox.take_damage(stun);await seconds(.3)
	check(actor.statuses.is_stunned() and actor.get("shots_fired")==0 and float(actor.get("ranged_windup"))==0,"Explicit stun cancels ranged commit")
	await fresh()
	var fire: DamageEvent=damage(1);fire.burn_damage=1;fire.burn_duration=3;fire.burn_interval=.5;actor.hurtbox.take_damage(fire)
	await seconds(2)
	check(dot_during_tell>0 and actor.get("shots_fired")>0 and actor.get("tells_cancelled")==0,"Real burn tick inside windup does not fake-stagger the DOT-based prototype")
	check(is_equal_approx(actor.health.current_health,55),"Burn damage/ticks remain direct1 plus four original ticks")
	await fresh();wall=floor_box(Vector2(900,580),Vector2(20,300));await seconds(3)
	check(actor.get("shots_fired")==0,"Solid wall blocks ranged acquisition and fire")
	await fresh();check(await wait_tell(),"Mid-tell wall fixture reaches windup")
	wall=floor_box(Vector2(900,580),Vector2(20,300));await seconds(.5)
	check(actor.get("shots_fired")==0 and float(actor.get("ranged_windup"))==0,"LOS lost during tell cancels commit")
	await fresh();bolt=await wait_shot();check(bolt!=null,"Wall-flight fixture gets a committed shot")
	hero.hurtbox.set_invulnerable(false);var hp: float=hero.health.current_health
	wall=floor_box(Vector2(900,580),Vector2(20,300));await seconds(.8)
	check(hero.health.current_health==hp and get_nodes_in_group(&"runic_harrier_bolts").is_empty(),"In-flight projectile collides with wall and cannot reach through it")
	await fresh();check(await wait_tell(),"Death-during-tell fixture reaches windup")
	actor.hurtbox.take_damage(damage(100));await seconds(.6)
	check(not is_instance_valid(actor) and get_nodes_in_group(&"runic_harrier_bolts").is_empty(),"Dead caster cannot complete pending fire")
	await fresh();bolt=await wait_shot();check(bolt!=null,"Owner-death cleanup fixture gets a shot")
	var bolt_id: int=bolt.get_instance_id() if bolt!=null else 0
	actor.hurtbox.take_damage(damage(100));await step(3)
	check(not is_instance_id_valid(bolt_id),"Owner death frees already-owned projectile before further hit sampling")
	await fresh();check(await wait_tell(),"Target-death fixture reaches tell")
	hero.health.apply_damage(10000);await step(3)
	check(actor.player==null and float(actor.get("ranged_windup"))==0 and actor.get("shots_fired")==0,"Dead target revokes the pending shot")
	await fresh();check(await wait_tell(),"Inactive-room fixture reaches tell")
	actor.visible=false;await seconds(1)
	check(float(actor.get("ranged_windup"))==0 and actor.get("shots_fired")==0,"Hidden/inactive room owner cannot attack")
	await fresh();check(await wait_tell(),"Disabled-AI fixture reaches tell")
	actor.ai_enabled=false;await seconds(.6)
	check(float(actor.get("ranged_windup"))==0 and actor.get("shots_fired")==0,"Disabled actor revokes the pending tell rather than firing on a stale clock")
	await fresh();check(await wait_tell(),"Different-scene target fixture reaches tell")
	var other_scope:=Node2D.new();root.add_child(other_scope);hero.reparent(other_scope);await seconds(.4)
	check(actor.player==null and float(actor.get("ranged_windup"))==0 and actor.get("shots_fired")==0,"Target in another scene revokes ranged and melee pursuit")
	hero.reparent(arena);other_scope.queue_free()
	await fresh()
	var seen_shots: int=0;var peak_bolts: int=0
	for i: int in Engine.physics_ticks_per_second*7:
		await step(1)
		peak_bolts=maxi(peak_bolts,get_nodes_in_group(&"runic_harrier_bolts").size())
		if int(actor.get("shots_fired"))>seen_shots:
			seen_shots=actor.get("shots_fired");hero.global_position.y=500 if hero.global_position.y>600 else 640
	check(seen_shots>=3 and peak_bolts<=3,"Repeated dodged shots remain within three live owner slots")
	metrics["peak_live_bolts"]=peak_bolts
	await fresh();hero.hurtbox.set_invulnerable(false);hits.clear();bolt=await wait_shot()
	await seconds(.8)
	check(hits.size()==1 and hits[0]["base"]==15 and hits[0]["poison"]==0,"A projectile attempts one baseline15damage hit without adding poison")
	await fresh();actor.hurtbox.take_damage(damage(1));check(actor.hit_aggro.active(),"Accepted Player hit starts existing20s target memory")
	hero.global_position=Vector2(3000,640);await seconds(20.1)
	check(not actor.hit_aggro.active() and actor.player==null,"Actual existing20s lease expires")
	var shots: int=actor.get("shots_fired");hero.global_position=actor.global_position+Vector2(150,0);await seconds(2.5)
	check(actor.get("shots_fired")==shots and not actor.get("ranged_windup")>0,"Expired target cannot be immediately reacquired or spammed")
	metrics.merge({"physics_hz":Engine.physics_ticks_per_second,"dot_during_tell":dot_during_tell,"max_bolts_authored":3,"baseline_hp":60,"last_lease_remaining":actor.hit_aggro.remaining})
	arena.queue_free();await step(4)
	check(get_nodes_in_group(&"runic_harrier_bolts").is_empty(),"Arena/room teardown leaves no projectile owner or callback")
	var file:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("harrier-tests.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"metrics":metrics,"scope":"Synthetic arena/stat comparison and real AI/status/lease; not earned gameplay."},"\t"));file.close()
	var audio_owner: Node=root.get_node("AudioManager")
	var before: Dictionary={"driver":AudioServer.get_driver_name(),"voices":audio_owner.get_active_voice_count(),"children":audio_owner.get_child_count(),"bolts":get_nodes_in_group(&"runic_harrier_bolts").size(),"arena_valid":is_instance_valid(arena),"hero_valid":is_instance_valid(hero),"actor_valid":is_instance_valid(actor),"feedback_valid":is_instance_valid(feedback)}
	print("SHUTDOWN_PROBE before="+JSON.stringify(before))
	await audio_owner.shutdown()
	var after: Dictionary={"voices":audio_owner.get_active_voice_count(),"children":audio_owner.get_child_count(),"bolts":get_nodes_in_group(&"runic_harrier_bolts").size()}
	print("SHUTDOWN_PROBE after="+JSON.stringify(after))
	var receipt:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("shutdown-discriminator.json"),FileAccess.WRITE)
	receipt.store_string(JSON.stringify({"before":before,"after":after,"checks":checks,"failures":failures,"single_change":"Call existing AudioManager.shutdown after the unchanged49assertions/arena cleanup, before quit; no production change"},"\t"));receipt.close()
	print("RESULT Harrier checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
