extends SceneTree
## Real Player motor/physics. Safety HP1 is a fixture; damage counts remain visible.
const Catalog=preload("res://data/member_floor_catalog.gd")
var checks: int=0
var failures: int=0
var world: Node2D
var player: Player
var feedback: CombatFeedback
var room: MemberDungeonRoom
var rows: Array[Dictionary]=[]
var hz: int=60
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func _step(count: int=1) -> void:
	for index: int in count:await physics_frame
func _seconds(value: float) -> void:await _step(roundi(value*hz))
func _release() -> void:
	for action: StringName in [&"move_left",&"move_right",&"jump",&"dash"]:Input.action_release(action)
func _new_room(number: int) -> void:
	_release()
	if is_instance_valid(room):world.remove_child(room);room.queue_free();await _step(2)
	room=MemberDungeonRoom.new();room.floor_number=number;room.player=player;room.feedback=feedback;world.add_child(room)
	player.health.reset_health();PlayerTravel.relocate(player,Catalog.ENTRY)
	await _step(5)
	# Intra-room travel deliberately preserves combat grace; wait it out through clocks.
	for index: int in hz*2:
		if player.damage_grace_remaining<=0 and player.action_state_machine.get_state_id()==&"ready":break
		await _step()
func _event(barrier: EnvironmentBarrier,spell: StringName=&"",fire: bool=false) -> DamageEvent:
	var e:=DamageEvent.new();e.source_id=player.get_instance_id();e.target_id=barrier.get_instance_id()
	e.source_team_id=1;e.attack_id=CombatIds.next_id();e.root_event_id=e.attack_id;e.hit_window_id=1;e.base_damage=1
	e.spell_id=spell;e.burn_damage=1 if fire else 0;return e
func _break_walls() -> void:
	for barrier: EnvironmentBarrier in room.barriers:
		if barrier.requires_fire:continue
		barrier.hurtbox.take_damage(_event(barrier));_check(not barrier.is_open,"Cracked wall survives first melee floor%d"%room.floor_number)
		barrier.hurtbox.take_damage(_event(barrier));_check(barrier.is_open,"Cracked wall opens second melee floor%d"%room.floor_number)
	await _step(2)
func _axis(value: float) -> void:
	if value>.1:Input.action_release(&"move_left");Input.action_press(&"move_right")
	elif value<-.1:Input.action_release(&"move_right");Input.action_press(&"move_left")
	else:Input.action_release(&"move_left");Input.action_release(&"move_right")
func _jump_to(point: Vector2,limit: int=240) -> bool:
	var held: int=0;var launched: bool=false
	for index: int in limit*hz/60:
		var dx: float=point.x-player.position.x
		_axis(signf(dx) if absf(dx)>5 else 0)
		# A safe upper rest/shelf is a valid landing; the pit bottom is below the target.
		if player.is_on_floor() and absf(dx)<14 and player.position.y<=point.y+8:
			_release();return true
		if not launched and player.is_on_floor():Input.action_press(&"jump");held=roundi(.36*hz);launched=true
		if held>0:held-=1
		else:Input.action_release(&"jump")
		if launched and index>hz and player.is_on_floor() and player.position.y>point.y+15:launched=false
		await _step()
	_release();return false
func _ride(platform: MemberDungeonPlatform,vertical: bool=false) -> bool:
	_release()
	for index: int in hz*7:
		if (platform.position.y>565 if vertical else platform.position.x<platform.start.x+35):break
		await _step()
	var landed: bool=false;var held: int=roundi(.36*hz)
	Input.action_press(&"jump")
	for index: int in hz*2:
		var dx: float=platform.position.x+platform.platform_size.x*.5-player.position.x
		_axis(signf(dx) if absf(dx)>6 else 0)
		if held>0:held-=1
		else:Input.action_release(&"jump")
		await _step()
		if player.is_on_floor() and absf(player.position.y-platform.position.y)<8 and player.position.x>platform.position.x and player.position.x<platform.position.x+platform.platform_size.x:
			landed=true;break
	_release()
	if not landed:return false
	if vertical:
		for index: int in hz*6:
			if platform.position.y<365:return true
			await _step()
	else:
		for index: int in hz*5:
			if platform.position.x>platform.finish.x-35:return true
			await _step()
	return false
func _walk_lane(target: float,limit_seconds: float=15.0) -> bool:
	var held: int=0
	for index: int in roundi(limit_seconds*hz):
		if player.position.x>=target-10:_release();return true
		var wait: bool=false;var jump: bool=false
		for trap: MemberDungeonTrap in room.traps:
			var left: float=trap.position.x-trap.width*.5
			var dx: float=left-player.position.x
			if trap.kind==&"fire" and dx<100 and dx>5 and trap.phase()!=&"hidden":wait=true
			if trap.kind in [&"fixed_spikes",&"spikes"] and dx<58 and dx>-trap.width-15 and trap.position.y<700:jump=true
			if trap.kind==&"pendulum" and absf(trap.global_position.x+trap.bell_center().x-player.position.x)<65:jump=true
		for raw: Array in room.member_data["rocks"]:
			if float(raw[0])-player.position.x<65 and float(raw[0])+float(raw[2])-player.position.x>0:jump=true
		_axis(0 if wait else 1)
		if jump and not wait and player.is_on_floor() and held==0:Input.action_press(&"jump");held=roundi(.37*hz)
		if held>0:held-=1
		else:Input.action_release(&"jump")
		await _step()
	_release();return false
func _traverse(number: int) -> bool:
	if number in [23,27,29]:
		var data: Dictionary=room.member_data
		var gap: Array=data["pits"][0]
		if not await _walk_lane(float(gap[0])-48):return false
		for raw: Array in data["collapse"]:
			if not await _jump_to(Vector2(float(raw[0])+float(raw[2])*.5,float(raw[1]))):return false
		if not await _jump_to(Vector2(float(gap[0])+float(gap[1])+65,640)):return false
	elif number==25:
		if not await _walk_lane(335):return false
		if not await _ride(room.platforms[0]):return false
		if not await _jump_to(Vector2(825,570)):return false
		# Approach second raft from the fixed mid-stream rest; wait for its near side.
		var second: MemberDungeonPlatform=room.platforms[1]
		for index: int in hz*6:
			if second.position.x<965:break
			await _step()
		if not await _jump_to(Vector2(second.position.x+60,600)):return false
		_release()
		for index: int in hz*5:
			if second.position.x>1165:break
			await _step()
		if not await _jump_to(Vector2(1340,640)):return false
	elif number==28:
		if not await _walk_lane(525):return false
		if not await _ride(room.platforms[0],true):return false
		if not await _jump_to(Vector2(855,360)):return false
	elif number==30:
		if not await _walk_lane(1290):return false
		if not await _ride(room.platforms[0]):return false
		if not await _jump_to(Vector2(1675,640)):return false
	return await _walk_lane(Catalog.exit_point(number).x)
func _trap_case(kind: StringName,damage: float,warning_start: float,active_start: float) -> void:
	await _new_room(18);PlayerTravel.relocate(player,Vector2(500,640));await _step(3)
	var trap:=MemberDungeonTrap.new();trap.kind=kind;trap.position=Vector2(500,640);trap.player=player;trap.feedback=feedback;room.add_child(trap)
	var before: float=player.health.current_health
	await _seconds(warning_start-.04)
	_check(trap.phase()==&"hidden" and is_equal_approx(player.health.current_health,before),"%s hidden interval cannot damage"%kind)
	await _seconds(.1)
	_check(trap.phase()==&"warning" and is_equal_approx(player.health.current_health,before),"%s warning precedes damage"%kind)
	await _seconds(active_start-warning_start+.01)
	_check(trap.damage_events==1 and is_equal_approx(before-player.health.current_health,damage),"%s active delivers authored damage once"%kind)
	_check(trap.last_event!=null and trap.last_event.knockback==Vector2.ZERO and trap.last_event.source_kind==DamageEvent.SourceKind.ENVIRONMENT,"%s damage has no impulse and correct ownership"%kind)
	trap.queue_free();await _step(2)
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):hz=int(arg.trim_prefix("--hz="))
	Engine.physics_ticks_per_second=hz
	world=Node2D.new();root.add_child(world);feedback=CombatFeedback.new();world.add_child(feedback)
	player=load("res://scenes/actors/player/player.tscn").instantiate() as Player;player.combat_feedback=feedback;world.add_child(player)
	player.health.minimum_health=1;player.hurtbox.damage_resolver.armor_rating=0
	for number: int in range(9,31):
		await _new_room(number)
		_check(player.is_on_floor() and absf(player.position.y-640)<3,"Safe grounded entry floor%d"%number)
		await _break_walls()
		var at_start: float=player.health.current_health
		var ok: bool=await _traverse(number)
		_check(ok and player.position.x>=Catalog.exit_point(number).x-15,"Actual motor traversal floor%d"%number)
		rows.append({"floor":number,"traversed":ok,"end":str(player.position),"damage":at_start-player.health.current_health,"hpSafetyFloor":1})
		print("TRAVERSE ",number," ",ok," at ",player.position)
	await _trap_case(&"spikes",10,1.4,1.85)
	await _trap_case(&"fire",12,1.6,2.2)
	await _new_room(18);PlayerTravel.relocate(player,Vector2(500,640));await _step(3)
	var fixed:=MemberDungeonTrap.new();fixed.position=Vector2(500,640);fixed.player=player;room.add_child(fixed)
	await _step(2);_check(fixed.damage_events==1 and is_equal_approx(player.health.maximum_health-player.health.current_health,10),"Fixed spikes deliver10 through real Hurtbox")
	await _seconds(.73);_check(fixed.damage_events>=2,"Standing on fixed spikes repeats damage")
	await _new_room(18);PlayerTravel.relocate(player,Vector2(500,640));await _step(3)
	var bell:=MemberDungeonTrap.new();bell.kind=&"pendulum";bell.position=Vector2(500,350);bell.player=player;room.add_child(bell)
	await _step(2);_check(bell.damage_events==1 and is_equal_approx(player.health.maximum_health-player.health.current_health,12),"Pendulum collision delivers12 at low arc")
	await _seconds(.85);var center: Vector2=bell.bell_center()
	_check(absf(center.x)>150 and center.y<160,"Pendulum endpoints clear the head-height lane")
	await _seconds(3.4);_check(bell.bell_center().distance_to(center)<5,"Pendulum completes a3.4s round trip")
	await _new_room(19)
	var bramble: EnvironmentBarrier=room.barriers.filter(func(b: EnvironmentBarrier)->bool:return b.requires_fire)[0]
	bramble.hurtbox.take_damage(_event(bramble));bramble.hurtbox.take_damage(_event(bramble,&"ice"))
	_check(not bramble.is_open,"Melee and non-fire spell cannot open fire bramble")
	bramble.hurtbox.take_damage(_event(bramble,&"fire",true));await _step(2)
	_check(bramble.is_open and bramble.body_shape.disabled,"Fire spell opens optional branch through standard barrier owner")
	await _new_room(18);PlayerTravel.relocate(player,Vector2(500,640));await _step(3)
	var sigil:=MemberDungeonTrap.new();sigil.kind=&"sigil";sigil.position=Vector2(500,640);sigil.player=player;room.add_child(sigil)
	await _seconds(.5);_check(sigil.damage_events==0 and sigil.phase()==&"warning","Triggered rune telegraphs before0.6s")
	await _seconds(.15);_check(sigil.damage_events==1 and is_equal_approx(player.health.maximum_health-player.health.current_health,14),"Triggered rune delivers14 after warning")
	await _seconds(.95);_check(sigil.phase()==&"cooldown" and sigil.damage_events==1,"Rune cannot rearm during rest")
	await _seconds(.88);_check(sigil.phase()==&"warning" and sigil.damage_events==1,"Rune rearms after1.8s from explosion, without extra active-duration delay")
	PlayerTravel.relocate(player,Vector2(200,640));await _seconds(2.5)
	_check(sigil.phase()==&"idle" and sigil.damage_events==1,"Rune resets without hitting departed player")
	await _new_room(18)
	var moving:=MemberDungeonPlatform.new();moving.start=Vector2(400,550);moving.finish=Vector2(700,550);moving.platform_size=Vector2(140,18);moving.player=player;world.add_child(moving)
	PlayerTravel.relocate(player,Vector2(470,550));await _step(6)
	var px: float=player.position.x;var mx: float=moving.position.x
	await _seconds(.9)
	_check(player.is_on_floor() and absf((player.position.x-px)-(moving.position.x-mx))<8 and player.position.x-px>50,"Horizontal platform physically carries stationary rider")
	moving.queue_free();await _step(2)
	var lift:=MemberDungeonPlatform.new();lift.start=Vector2(400,600);lift.finish=Vector2(400,360);lift.period=5;lift.player=player;world.add_child(lift)
	PlayerTravel.relocate(player,Vector2(460,600));await _step(5);var py: float=player.position.y;var ly: float=lift.position.y
	await _seconds(1)
	_check(player.is_on_floor() and absf((player.position.y-py)-(lift.position.y-ly))<8 and player.position.y<py-50,"Lift physically carries rider upward")
	lift.queue_free();await _step(2)
	var collapse:=MemberDungeonPlatform.new();collapse.kind=&"collapse";collapse.start=Vector2(400,550);collapse.platform_size=Vector2(140,18);collapse.player=player;world.add_child(collapse)
	PlayerTravel.relocate(player,Vector2(470,550));await _seconds(.15)
	_check(collapse.state==&"warning","Collapse arms when actual rider lands")
	Input.action_press(&"jump");await _seconds(.35);Input.action_release(&"jump");await _seconds(.32)
	_check(collapse.state==&"fallen" and collapse.shape.disabled,"Collapse still falls after early departure")
	await _seconds(2.5);_check(collapse.state==&"solid" and not collapse.shape.disabled,"Collapse restores collision after2.4s")
	collapse.queue_free();_release();world.queue_free();await _step(4)
	var out:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("physics.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks,"failures":failures,"hz":hz,"traversal":rows,"scope":"Actual Player/input/motor withHP1 safety, walls broken through real Hurtbox pipeline before traversal; not natural play or damage-free route. Separate timed damage and rider/collapse checks."},"\t"));out.close()
	await root.get_node("AudioManager").shutdown()
	print("RESULT MemberDungeonPhysics checks=%d failures=%d hz=%d"%[checks,failures,hz]);quit(0 if failures==0 else 1)
