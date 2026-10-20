extends SceneTree
## QA-only geometry scene translated -1200y so dungeon Guard's existing kill
## plane stays valid. Relative collider/surface/player/enemy positions unchanged.
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("_run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func frames(n: int) -> void:
	for i: int in n:await physics_frame;await process_frame
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	AudioServer.set_bus_mute(0,true)
	for kind: String in ["closed","open","open_reverse","under_recess","under_recess_reverse"]:
		var recess: bool=kind.begins_with("under_recess")
		var reverse: bool=kind.ends_with("reverse")
		var room:=ExteriorRoom.new()
		check(room.configure(&"o01_p03" if recess else &"o01_p02",ExteriorRouteCatalog.MAIN if recess else ExteriorRouteCatalog.TUNNEL,kind!="closed"),"Actual room config, no reconstructed collider")
		room.position.y=-1200;root.add_child(room)
		var player: Player=preload("res://scenes/actors/player/player.tscn").instantiate() as Player
		var target: float=(1840 if reverse else 2200) if recess else (520 if reverse else 900)
		player.position=Vector2(target,room.floor_y(target));room.add_child(player)
		await frames(8)
		var enemy: BaseEnemy=preload("res://scenes/enemies/base_enemy.tscn").instantiate() as BaseEnemy
		var start: float=(2240 if reverse else 1800) if recess else (900 if reverse else 520)
		enemy.player=player;enemy.position=Vector2(start,room.floor_y(start));room.add_child(enemy)
		await frames(ceili(6.2*Engine.physics_ticks_per_second))
		check(is_instance_valid(enemy) and enemy.health.current_health>0,"Unmodified Guard remains alive within its existing kill plane")
		if is_instance_valid(enemy):
			var at: Vector2=room.to_local(enemy.global_position)
			check(at.x<640 if kind=="closed" else (at.x<(2040 if recess else 700) if reverse else at.x>(1995 if recess else 700)),"Actual AI blocked by closed gate / crosses open gate / walks under upper landings: "+kind)
			check(absf(at.y-room.floor_y(at.x))<3 and enemy.is_on_floor(),"Enemy feet follow ramp/joins without sinking or floating: "+kind)
			print("METRIC "+JSON.stringify({"fixture":kind,"from":start,"to":at,"player":room.to_local(player.global_position),"geometry_translation_y":-1200,"ai_state":enemy.state_machine.get_state_id()}))
		check(player.motor.is_grounded() and absf(room.to_local(player.global_position).y-room.floor_y(target))<3,"Player footprint has floor/head clearance in same geometry")
		root.remove_child(room);room.queue_free();await frames(6)
	await root.get_node("AudioManager").shutdown()
	print("RESULT Part5ExplorationGeometry checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
