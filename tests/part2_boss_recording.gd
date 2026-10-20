extends SceneTree
## Fresh synthetic first loop through viewport inputs. No grants, warps, HP
## floors, direct damage, enemy clock edits or forced loot/quest outcomes.
const Sink = preload("res://tests/part1_timing_sink.gd")
class CombatBot:
	extends Node
	var run: DungeonRun
	var tick: int = 0
	var enabled: bool = false
	var jump_until: int=0
	var releases: Array[StringName] = []
	func action(id: StringName, down: bool) -> void:
		var event := InputEventAction.new();event.action=id;event.pressed=down;Input.parse_input_event(event)
	func stop() -> void:
		enabled=false
		for id: StringName in [&"attack",&"spell_cast",&"jump",&"dash",&"move_left",&"move_right"]:action(id,false)
		releases.clear()
	func _physics_process(_delta: float) -> void:
		for id: StringName in releases:action(id,false)
		releases.clear()
		if not enabled or not is_instance_valid(run) or run.outcome!=&"" or not run.player.controls_enabled:return
		tick+=1
		if tick>=jump_until:action(&"jump",false)
		var enemies: Array[Node2D]=run.living_enemies()
		if enemies.is_empty():action(&"move_left",false);action(&"move_right",false);return
		var target: Node2D=enemies[0]
		for enemy: Node2D in enemies:
			if enemy.global_position.distance_squared_to(run.player.global_position)<target.global_position.distance_squared_to(run.player.global_position):target=enemy
		var difference: Vector2=target.global_position-run.player.global_position
		var event := InputEventMouseMotion.new();event.position=target.get_global_transform_with_canvas()*Vector2(0,-26);get_tree().root.push_input(event,true)
		var direction: float=signf(difference.x)
		var move: bool=absf(difference.x)>42.0
		action(&"move_left",move and direction<0);action(&"move_right",move and direction>0)
		if tick%12==0 and absf(difference.x)<105 and absf(difference.y)<100:
			action(&"attack",true);releases.append(&"attack")
		if tick%90==10 and run.player.energy.current>=30.0:
			action(&"spell_cast",true);releases.append(&"spell_cast")
		if difference.y < -55 and tick%45==0:
			action(&"jump",true);jump_until=tick+12
		var dangerous: bool=false
		for enemy: Node2D in enemies:
			if enemy is BaseEnemy and enemy.global_position.distance_to(run.player.global_position)<170:
				var mob: BaseEnemy=enemy as BaseEnemy
				if mob.state_machine.get_state_id()==&"attack" or (mob.state_machine.get_state_id()==&"telegraph" and mob.state_time>=mob.definition.windup-0.13):dangerous=true
			elif enemy is BossGolem:
				var boss: BossGolem=enemy as BossGolem
				dangerous=boss.fsm.get_state_id() in [&"sweep",&"orbs",&"stomp"] and boss.state_time>0.28
		if dangerous and run.player.motor.is_grounded():action(&"jump",true);jump_until=tick+12
		if dangerous and absf(difference.x)<180 and run.player.motor.can_dash() and run.player.energy.current>=25.0:
			action(&"move_left",direction<0);action(&"move_right",direction>=0);action(&"dash",true);releases.append(&"dash")


var run: WorldCampaign
var bot: CombatBot
var contacts: Array[Dictionary]=[]
var phase: String="boss_room_fixture"
var checks: int=0
var failures: int=0
var samples: Array[Dictionary]=[]
var evidence: String
func _initialize() -> void:_run.call_deferred()
func _step(count: int) -> void:
	for _i: int in count:await physics_frame;await process_frame
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") and "--native-approved" in OS.get_cmdline_user_args(),"Explicit native approval and synthetic save directory")
	if failures:quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	node_added.connect(_track_hurtbox)
	bot=CombatBot.new();root.add_child(bot)
	run=preload("res://scenes/world_campaign.tscn").instantiate() as WorldCampaign
	run.profile=SanctuaryProfile.new();run.profile.save_path="user://part2-boss-recording/profile.json";run.run_seed=20261016
	root.add_child(run);await _step(5)
	_check(run.enter_stage(4),"Fixture selects existing boss room; no enemy edits")
	await _step(5);bot.run=run
	_check(run.player.health.minimum_health==0.0 and run.player.health.current_health==115.0 and run.boss.health.current_health==500.0,"Original lethal 115HP starter and original 500HP Golem")
	print("MOVIE_STAGE "+JSON.stringify({"label":"golem_ai_approach","frame":Engine.get_process_frames()}))
	process_frame.connect(_observe)
	await _step(168)
	bot.enabled=true;phase="input_combat"
	print("MOVIE_STAGE "+JSON.stringify({"label":"input_combat","frame":Engine.get_process_frames()}))
	for _i: int in 60*180:
		if not is_instance_valid(run.boss) or run.boss.health.current_health<=0.0 or run.player.health.current_health<=0.0:break
		await _step(1)
	bot.stop()
	var defeated: bool=not is_instance_valid(run.boss) or run.boss.health.current_health<=0.0
	_check(defeated,"Golem dies from actual player input attacks")
	print("MOVIE_STAGE "+JSON.stringify({"label":"golem_dead" if defeated else "player_defeat","frame":Engine.get_process_frames()}))
	await _step(180)
	process_frame.disconnect(_observe)
	var file:=FileAccess.open(evidence.path_join("boss_recording.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"defeated":defeated,"contacts":contacts,"samples":samples,"scope":"Room-selection fixture only; actual AI/motors/viewport combat inputs, default starter/HP/damage/loot. No warps, grants, forced FSM poses, hitbox edits or direct damage. Muted. Movie capture is not FPS proof."},"\t"));file.close()
	bot.queue_free();run.queue_free();await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT Part2BossRecording checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
func _observe() -> void:
	if not is_instance_valid(run.boss):return
	var boss: BossGolem=run.boss
	var rig: Node2D=(boss.get_node("GolemStoneSkin") as BossGolemSkin).art_rig
	var info: Dictionary=rig.motion_snapshot()
	samples.append({"frame":Engine.get_process_frames(),"boss":[boss.position.x,boss.position.y],"hp":boss.health.current_health,"player_hp":run.player.health.current_health,"facing":boss.facing,"state":String(boss.fsm.get_state_id()),"state_time":boss.state_time,"active":boss.attack_hitbox.active,"pose":String(info["pose"]),"phase":boss.phase,"left_sole":[info["left_sole"].x,info["left_sole"].y],"right_sole":[info["right_sole"].x,info["right_sole"].y],"planted":info["planted"]})
func _track_hurtbox(node: Node) -> void:
	if node is Hurtbox:(node as Hurtbox).hit_resolved.connect(_record_contact)
func _record_contact(event: DamageEvent,result: DamageResult) -> void:
	if result.blocked or result.actual_damage<=0:return
	var source: Node=instance_from_id(event.source_id) as Node if is_instance_id_valid(event.source_id) else null
	var entry: Dictionary={"movie_frame":Engine.get_process_frames(),"source_id":event.source_id,"target_id":event.target_id,"damage":result.actual_damage,"attack_id":event.attack_id,"hit_window":event.hit_window_id,"phase":phase}
	if source is BaseEnemy:
		var mob: BaseEnemy=source as BaseEnemy
		entry.merge({"source":"guard" if mob.enemy_type==&"ancient_guard" else String(mob.enemy_type),"state":String(mob.state_machine.get_state_id()),"state_time":mob.state_time,"active":mob.attack_hitbox.active,"body_frame":mob.visual.body_frames.frame_index if mob.visual.body_frames!=null else -1})
	elif source is BossGolem:
		var boss: BossGolem=source as BossGolem
		entry.merge({"source":"golem","state":String(boss.fsm.get_state_id()),"state_time":boss.state_time,"active":boss.attack_hitbox.active})
	else:entry["source"]=source.get_class() if source!=null else "released-owner"
	contacts.append(entry)
