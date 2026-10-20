extends "res://tests/combat_readability_gameplay_probe.gd"
class EncounterBot:
	extends Node
	var run: DungeonRun
	var harrier: SlimeEnemy
	var enabled: bool=false
	var gap: float=150
	var approach_side: int=0
	var aim_harrier: bool=false
	var tick: int=0
	var jump_until: int=0
	func action(id: StringName,down: bool) -> void:
		var e:=InputEventAction.new();e.action=id;e.pressed=down;Input.parse_input_event(e)
	func stop() -> void:
		enabled=false
		for id: StringName in [&"attack",&"spell_cast",&"jump",&"dash",&"move_left",&"move_right"]:action(id,false)
	func _physics_process(_delta: float) -> void:
		if not enabled or not is_instance_valid(run) or not is_instance_valid(harrier) or harrier.health.current_health<=0 or run.player.health.current_health<=0:return
		tick+=1;action(&"jump",tick<jump_until)
		var dx: float=harrier.global_position.x-run.player.global_position.x
		var correction: float=absf(dx)-gap
		if approach_side!=0:
			dx=harrier.global_position.x+gap*approach_side-run.player.global_position.x;correction=absf(dx)
		action(&"move_left",absf(correction)>9 and signf(dx)*signf(correction)<0);action(&"move_right",absf(correction)>9 and signf(dx)*signf(correction)>0)
		if aim_harrier:
			var motion:=InputEventMouseMotion.new();motion.position=harrier.get_global_transform_with_canvas()*Vector2(0,-14);get_tree().root.push_input(motion,true)
		for enemy: Node2D in run.living_enemies():
			if enemy is BaseEnemy and enemy.definition.id==&"ancient_guard" and enemy.global_position.distance_to(run.player.global_position)<170:
				if enemy.state_machine.get_state_id()==&"attack" or (enemy.state_machine.get_state_id()==&"telegraph" and enemy.state_time>enemy.definition.windup-.15):
					if run.player.motor.is_grounded():action(&"jump",true);jump_until=tick+12
var interrupt_from_far_side: bool=false
var hud_rows: Array[Dictionary]=[]
var scout: EncounterBot
var run_scene: DungeonRun
var ranged: SlimeEnemy
var harrier_rows: Array[Dictionary]=[]
var hit_rows: Array[Dictionary]=[]
var hero_hits: Array[Dictionary]=[]
var pending: Dictionary={}
var any_guard_with_tell: bool=false
func incoming(event: DamageEvent) -> void:pending[event.attack_id]={"windup":float(ranged.get("ranged_windup")),"hp":ranged.health.current_health}
func resolved(event: DamageEvent,result: DamageResult) -> void:
	var before: Dictionary=pending.get(event.attack_id,{});pending.erase(event.attack_id)
	hit_rows.append({"before":before,"kind":event.source_kind,"spell":String(event.spell_id),"damage":result.actual_damage,"blocked":result.blocked,"windup_after":float(ranged.get("ranged_windup")),"hp_after":ranged.health.current_health,"wall_usec":Time.get_ticks_usec()})
func hero_received(event: DamageEvent,result: DamageResult) -> void:hero_hits.append({"source":event.source_id,"attack":event.attack_id,"amount":result.actual_damage,"blocked":result.blocked,"wall_usec":Time.get_ticks_usec()})
func observe() -> void:
	super.observe()
	if not is_instance_valid(ranged) or not is_instance_valid(run_scene):return
	var hud: ArtHUD=run_scene.presentation.art_hud
	if hud_rows.size()<2400:hud_rows.append({"phase":phase,"spell":hud.spell_status.text,"dash":hud.dash_status.text,"recipe":String(run_scene.player.resonance_controller.get_recipe().id),"energy":run_scene.player.energy.current,"cooldown":run_scene.player.resonance_controller.cooldown_remaining()})
	var guards: int=run_scene.living_enemies().filter(func(e: Node2D)->bool:return e is BaseEnemy and e.definition.id==&"ancient_guard").size()
	var tell: float=ranged.get("ranged_windup")
	any_guard_with_tell=any_guard_with_tell or (guards>0 and tell>0)
	if harrier_rows.size()<2400:harrier_rows.append({"phase":phase,"tell":tell,"shots":ranged.get("shots_fired"),"cancelled":ranged.get("tells_cancelled"),"guards":guards,"hero_hp":run_scene.player.health.current_health,"x_gap":absf(run_scene.player.global_position.x-ranged.global_position.x),"projectiles":get_nodes_in_group(&"runic_harrier_bolts").size(),"wall_usec":Time.get_ticks_usec()})
func dungeon() -> bool:
	_stage("ordinary_portal_to_existing_encounter")
	if not await _walk(hub.player,hub.stations[&"portal"].global_position.x):return false
	await _key(KEY_E);await _step(12);run_scene=flow.active_scene as DungeonRun
	if not _check(run_scene!=null and not flow.qa_tools_enabled,"Physical portal enters the ordinary connected opening"):return false
	var prototypes: Array[Node2D]=run_scene.living_enemies().filter(func(e: Node2D)->bool:return e.get_script().resource_path=="res://scripts/actors/enemies/runic_slime_harrier.gd")
	if not _check(prototypes.size()==1 and run_scene.living_enemies().size()==4,"Exactly one prototype in the existing four-enemy encounter"):return false
	ranged=prototypes[0] as SlimeEnemy
	_check(ranged.health.maximum_health==60 and run_scene.living_enemies().filter(func(e: Node2D)->bool:return e is BaseEnemy and e.definition.id==&"ancient_guard").size()==2,"Same60HP slot alongside both original Guards")
	ranged.hurtbox.damage_received.connect(incoming);ranged.hurtbox.hit_resolved.connect(resolved);run_scene.player.hurtbox.hit_resolved.connect(hero_received)
	# Base probe already connects the virtual observe callback before entering hub.
	scout=EncounterBot.new();scout.run=run_scene;scout.harrier=ranged;root.add_child(scout);scout.enabled=true
	_stage("approach_under_melee_pressure_then_read_tell")
	for i: int in 900:
		if ranged.get("shots_fired")>0 or run_scene.player.health.current_health<=0:break
		await _step(1)
	if not _check(run_scene.player.health.current_health>0 and ranged.get("shots_fired")>0 and any_guard_with_tell,"Live ranged tell/shot occurs alongside active melee enemies"):return false
	await _shot("ranged_lane_with_guards");await pause(.7)
	_stage("close_gap_and_interrupt_the_caster")
	scout.gap=95;scout.aim_harrier=true
	if interrupt_from_far_side:scout.approach_side=1
	var requested: bool=false
	for i: int in 1800:
		if not is_instance_valid(ranged) or ranged.health.current_health<=0 or run_scene.player.health.current_health<=0:break
		if (not interrupt_from_far_side or run_scene.player.global_position.x>ranged.global_position.x+80) and float(ranged.get("ranged_windup"))>.28 and run_scene.player.motor.is_grounded() and run_scene.player.action_state_machine.get_state_id()==&"ready" and run_scene.player.resonance_controller.can_cast() and run_scene.player.global_position.distance_to(ranged.global_position)<115:
			await _key(KEY_I);requested=true
			await _step(24)
			if hit_rows.any(func(h: Dictionary)->bool:return h["before"].get("windup",0)>0 and h["spell"]=="thermal_shock" and h["damage"]>0 and h["hp_after"]>0 and h["windup_after"]==0):break
		await _step(1)
	_check(requested,"Ordinary input targets the caster during its readable windup")
	_check(hit_rows.any(func(h: Dictionary)->bool:return h["before"].get("windup",0)>0 and h["kind"]!=DamageEvent.SourceKind.DOT and h["spell"]=="thermal_shock" and h["damage"]>0 and h["hp_after"]>0 and h["windup_after"]==0),"A real nonlethal direct spell hit cancels the caster tell")
	await _shot("actual_caster_interrupted");scout.stop();await pause(.6)
	_check(run_scene.player.health.current_health>0,"Player survives the prototype observation without HP/stat overrides")

	scout.stop();bot.run=run_scene;bot.enabled=true;_stage("clear_existing_opening_with_merged_combat")
	for i: int in 10800:
		if run_scene.outcome!=&"" or (run_scene.living_enemies().is_empty() and not run_scene.room.locked):break
		await _step(1)
	bot.stop()
	if not _check(run_scene.outcome==&"" and not run_scene.room.locked,"Real mixed opening clears without stat/AI/HP overrides"):return false
	await pause(.6)
	if not await _walk(run_scene.player,1240):return false
	await _key(KEY_E);await pause(.5)
	if not _check(run_scene.floor_exit.is_open,"Normal physical exit opens return UI"):return false
	await _click(run_scene.floor_exit.return_button);await _step(16);hub=flow.active_scene as ExteriorHub
	if not _check(hub!=null and realm()==3,"Normal return retains earned realm"):return false
	await _key(KEY_M);await pause(.8)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	if not screen.journal._supply_open:await _click(screen.journal.supply_button)
	await pause(.5);await _shot("combined_quest_M_after_return")
	_check(screen.journal.supply_board.visible and not hub.player.controls_enabled,"Quest/source panel remains available with proper modal lock on combined branch")
	await _key(KEY_ESCAPE);await pause(.3)
	return true
func finish_combat(complete: bool) -> void:
	if is_instance_valid(scout):scout.stop();scout.queue_free()
	var f:=FileAccess.open(evidence.path_join("combined-combat.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"complete":complete,"checks":checks,"failures":failures,"guard_with_tell":any_guard_with_tell,"caster_hits":hit_rows,"hero_hits":hero_hits,"harrier_rows":harrier_rows,"hud_rows":hud_rows,"scope":"Real earned H7 input: owned IceFire training, dash, portal, two Guards and one ranged Runic, interrupt then clear/return/M. No grants/warp/HP/AI/RNG overrides."},"\t"));f.close()
	await super.finish_combat(complete)
