extends "res://tests/member_dungeon_physics_test.gd"
## Independent acceptance values from the approved fixed-floor table.
const HP: Dictionary={9:[42],10:[56],11:[56],12:[42,8],13:[],14:[65],15:[178],16:[65],17:[49,65],18:[],19:[70],20:[],21:[53],22:[],23:[10,10],24:[53],25:[],26:[],27:[],28:[79],29:[216],30:[]}
const DAMAGE: Dictionary={9:[9],10:[10],11:[8],12:[9,3],14:[11],15:[16.5],16:[8.8],17:[9.9,11],19:[9.2],21:[10.35],23:[3.45,3.45],24:[10.35],28:[12.5],29:[18.75]}
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	world=Node2D.new();root.add_child(world);feedback=CombatFeedback.new();world.add_child(feedback)
	player=load("res://scenes/actors/player/player.tscn").instantiate() as Player;player.combat_feedback=feedback;world.add_child(player)
	var fights: int=0;var quiet: int=0
	for number: int in range(9,31):
		await _new_room(number)
		var actors: Array[MemberEnemy]=room.encounters.spawned
		_check(actors.size()==HP[number].size(),"Authored count retained floor%d"%number)
		if actors.is_empty():quiet+=1
		else:fights+=1
		for i: int in actors.size():
			var actor:=actors[i]
			_check(actor.balance_floor==number and actor.health.maximum_health==HP[number][i],"Floor stat bound before actor ready floor%d"%number)
			_check(is_equal_approx(actor.definition.attack_damage,DAMAGE[number][i]),"Accepted physical damage floor%d"%number)
			_check(actor.definition.windup>=.378 and actor.definition.cooldown>=.81,"Readable fixed tell/cooldown floor%d"%number)
		_check(not room.locked,"Clear remains optional floor%d"%number)
		if number in [11,16,19]:
			var mother: MemberEnemy=actors[0]
			mother.health.apply_damage(99999) # Death setup only; not combat telemetry.
			await _step(4)
			var children: Array[MemberEnemy]=room.encounters.spawned.filter(func(actor:MemberEnemy)->bool:return actor.member_type==&"member_spiderling")
			var expected: int=3 if number==11 else 4
			var child_hp: int=8 if number==11 else 10
			_check(children.size()==expected and mother.children_spawned==expected,"Actual brood count floor%d"%number)
			_check(children.all(func(child:MemberEnemy)->bool:return child.balance_floor==number and child.health.maximum_health==child_hp),"Actual brood inherits phase HP floor%d"%number)
			mother._on_died();await _step(2)
			_check(mother.children_spawned==expected,"Repeated death callback cannot duplicate brood floor%d"%number)
	_check(fights==14 and quiet==8,"Fourteen optional fight floors and eight rest/trap floors")
	var first: WorldEnemyData=MemberEnemyCatalog.definition(&"member_hellhound",9)
	first.maximum_hp=1;first.attack_damage=999
	_check(MemberEnemyCatalog.definition(&"member_hellhound",9).maximum_hp==42 and MemberEnemyCatalog.definition(&"member_hellhound",9).attack_damage==9,"Actor definition mutations never alter catalog or later actors")
	_check(MemberEnemyCatalog.definition(&"member_hellhound").maximum_hp==65,"Isolated arena keeps original comparison baseline")
	_check(MemberBalanceCatalog.brood_count(11)==3 and MemberBalanceCatalog.brood_count(16)==4 and MemberBalanceCatalog.brood_count(19)==4,"Early brood easing does not remove later brood challenge")
	world.queue_free();await _step(4);await root.get_node("AudioManager").shutdown()
	print("RESULT MemberBalanceContract checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
