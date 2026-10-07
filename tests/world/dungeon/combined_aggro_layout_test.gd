extends SceneTree
## Combined acceptance: unedited map-worker generator + actual AI and native motor.
var checks: int=0
var failures: int=0
var world: Node2D
var rows: Array[Dictionary]=[]
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated combined user://")
	if failures: quit(2);return
	AudioServer.set_bus_mute(0,true)
	world=Node2D.new();root.add_child(world);current_scene=world
	for number: int in [1,2,3]:
		var room:=DungeonRoom.new();room.room_number=number;world.add_child(room)
		await _frames(4)
		_check(room.architecture!=null,"Exact map-owner architecture active for room"+str(number))
		for scene: PackedScene in [preload("res://scenes/enemies/ancient_guard.tscn"),preload("res://scenes/enemies/runic_champion.tscn")]:
			for direction: int in [-1,1]: await _pursue(room,scene,direction)
		room.queue_free();await _frames(5)
	world.queue_free();await _frames(6);root.get_node("AudioManager").stop_all()
	_check(get_nodes_in_group(&"enemies").is_empty(),"Combined owner teardown releases enemies")
	var file:=FileAccess.open("user://combined_aggro_layout_%d.json"%Engine.physics_ticks_per_second,FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"rows":rows,"physics_hz":Engine.physics_ticks_per_second,"map_script_sha256":FileAccess.get_sha256("res://scripts/rooms/dungeon_room.gd"),"architecture_sha256":FileAccess.get_sha256("res://scripts/presentation/dungeon_architecture.gd"),"scope":"Actual Guard50 and Champion75 AI cross old low-slab obstruction footprint in all3 map-owner layouts, both directions. Native gameplay clocks and damage; no motor/FSM/geometry edits."},"\t"));file.close()
	print("RESULT CombinedAggroLayout %d checks, %d failures"%[checks,failures]);quit(0 if failures==0 else 1)
func _pursue(room: DungeonRoom,scene: PackedScene,direction: int) -> void:
	var hero: Player=preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	world.add_child(hero);hero.reset_movement_at(Vector2(70 if direction<0 else 1130,640));hero.controls_enabled=false
	var feedback:=CombatFeedback.new();world.add_child(feedback);feedback.hit_stop_seconds=0
	var enemy: BaseEnemy=scene.instantiate() as BaseEnemy
	enemy.position=Vector2(650 if direction<0 else 200,640);enemy.player=hero;enemy.combat_feedback=feedback;room.add_child(enemy)
	await _frames(3)
	var before: Vector2=enemy.global_position
	var event:=DamageEvent.new();event.source_id=hero.get_instance_id();event.source_team_id=1;event.target_id=enemy.get_instance_id();event.attack_id=CombatIds.next_id();event.root_event_id=event.attack_id;event.hit_window_id=1;event.base_damage=1.0;event.physical_damage=true
	var result: DamageResult=enemy.hurtbox.take_damage(event)
	_check(not result.blocked and result.actual_damage>0 and enemy.hit_aggro.active() and enemy.player==hero,"Accepted real hit starts memory for "+String(enemy.enemy_type))
	var seconds: float=6.0 if direction<0 else 7.2
	await _frames(roundi(seconds*Engine.physics_ticks_per_second))
	var crossed: bool=enemy.global_position.x<451 if direction<0 else enemy.global_position.x>499
	_check(crossed and enemy.is_on_floor() and absf(enemy.global_position.y-640)<2,"Actual "+String(enemy.enemy_type)+" AI/motor crosses former center-slab obstruction, room"+str(room.room_number)+" direction"+str(direction))
	_check(enemy.hit_aggro.active() and enemy.player==hero and enemy.hit_aggro.remaining>12.0 and enemy.hit_aggro.remaining<15.0,"Memory advances on real gameplay ticks while traversing candidate geometry")
	_check(hero.health.current_health>0 and enemy.health.current_health>0,"Combined route remains alive without invulnerability or HP floors")
	rows.append({"room":room.room_number,"type":String(enemy.enemy_type),"physical_height":enemy.definition.body_size.y,"direction":direction,"before":before,"after":enemy.global_position,"memory_seconds":enemy.hit_aggro.remaining,"state":String(enemy.state_machine.get_state_id()),"hero_hp":hero.health.current_health})
	enemy.queue_free();hero.queue_free();feedback.queue_free();await _frames(6)
func _frames(count: int) -> void:
	for tick: int in count: await physics_frame;await process_frame
func _check(passed: bool,message: String) -> void:
	checks+=1
	if not passed: failures+=1;print("FAIL: "+message)
