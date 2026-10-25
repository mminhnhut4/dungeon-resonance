extends "res://tests/member_dungeon_physics_test.gd"
## Live entry, safe lanes, cleanup and cancellation; fixtures explicitly isolate AI.
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	world=Node2D.new();root.add_child(world);feedback=CombatFeedback.new();world.add_child(feedback)
	player=load("res://scenes/actors/player/player.tscn").instantiate() as Player;player.combat_feedback=feedback;world.add_child(player)
	for number: int in range(9,31):
		await _new_room(number);var hp: float=player.health.current_health
		_check(is_equal_approx(hp,player.health.maximum_health),"No damage even in initial entry frames floor%d"%number)
		await _step(30)
		_check(is_equal_approx(player.health.current_health,hp),"Authored entry is safe before input floor%d"%number)
		var live: Array=get_nodes_in_group(&"member_enemies").filter(func(n:Node)->bool:return room.is_ancestor_of(n))
		_check(live.size()==MemberEncounterCatalog.entries(number).size(),"Live actor population floor%d"%number)
		for node: Node in live:
			var enemy:=node as MemberEnemy
			_check(enemy.state_machine.get_state_id()==&"patrol" and enemy.campaign_lane,"No spawn aggro through entry buffer floor%d"%number)
			for direction: float in [-1,1]:
				enemy.facing=direction;var rect: Rect2=enemy._current_attack_rect()
				_check(rect.size.x>0 and rect.position.x+enemy.global_position.x>=enemy.lane_limits.x-.01 and rect.end.x+enemy.global_position.x<=enemy.lane_limits.y+.01,"Warned/physical attack stays in safe lane floor%d"%number)
			PlayerTravel.relocate(player,Vector2(enemy.lane_limits.x-25,640))
			_check(not enemy._can_see_target(),"Leash prevents pulling enemies into trap/entry route floor%d"%number)
		PlayerTravel.relocate(player,MemberFloorCatalog.ENTRY)
	# Deferred brood cannot survive room teardown/reentry.
	await _new_room(11);var spider:=room.encounters.spawned[0]
	spider.health.apply_damage(99999);world.remove_child(room);room.queue_free();await _step(4)
	_check(get_nodes_in_group(&"member_enemies").is_empty(),"Room teardown cancels pending brood and releases every actor")
	await _new_room(11);await _step(3)
	_check(room.encounters.spawned.size()==1 and room.encounters.deaths.is_empty(),"Reentry resets original spider without children/death ledger")
	world.queue_free();await _step(4);await root.get_node("AudioManager").shutdown()
	print("RESULT MemberEncounterSafety checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
