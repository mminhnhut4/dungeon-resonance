extends SceneTree
## Explicit geometry/edge-case fixtures. Product input footage is a separate test.
const ROOM = preload("res://scripts/rooms/shattered_mine_room.gd")
const RUN: PackedScene = preload("res://scenes/shattered_mine.tscn")
var checks: int = 0
var failures: int = 0
var run: DungeonRun
var actor: Player
var probe: CharacterBody2D
var probe_motor: KnockbackMotor

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):
		quit(2)
		return
	if DisplayServer.get_name() != "headless" and not "--native-approved" in OS.get_cmdline_user_args():
		quit(2)
		return
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	root.unfocusable = true
	AudioServer.set_bus_mute(0,true)
	for index: int in range(ROOM.SURFACE.size()-1):
		var segment: Vector2 = ROOM.SURFACE[index+1]-ROOM.SURFACE[index]
		_check(segment.x>0 and absf(rad_to_deg(segment.angle()))<=10,"Continuous ordered floor segment uses walkable slope")
	run = RUN.instantiate() as DungeonRun
	run.profile = SanctuaryProfile.new()
	run.profile.save_path = "user://shattered-mine-geometry/profile.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(run.profile.save_path.get_base_dir()))
	Input.action_press(&"interact") # Same held E that opened the Hub portal.
	root.add_child(run)
	current_scene = run
	actor = run.player
	run.feedback.hit_stop_seconds = 0
	run.feedback.enable_global_hitstop(false)
	actor.health.minimum_health = 1
	await _step(12)
	_check(not run.floor_exit.is_open and not run.can_choose_floor_exit(),"Held portal E cannot immediately open the new mine exit")
	Input.action_release(&"interact")
	await _step(3)
	_check(not run.floor_exit.is_open,"Releasing portal E only arms a future new interaction")
	_check(actor.motor.is_grounded() and actor.position.distance_to(ROOM.ENTRY)<3,"Actual Player settles at upper entrance")
	_check(run.can_choose_floor_exit(),"Early retreat is available before combat completion")
	_check(not run.enter_room(1),"Repeated room API cannot refill source or respawn enemies in this visit")
	_check(not run.advance_room(),"Sample cannot advance production floor IDs")
	_check(run.living_enemies().size()==3,"Exactly three existing ground Slimes")
	_check(not run.call("activate_shortcut"),"Remote lever activation is refused")
	var camera: Camera2D = actor.get_node("Camera2D") as Camera2D
	_check(camera.limit_right==int(ROOM.WIDTH) and camera.limit_bottom>=640,"Camera covers the full long room and lower floor")
	await _step(120)
	for enemy: Node2D in run.living_enemies():
		_check(enemy is SlimeEnemy and enemy.is_on_floor() and absf(enemy.position.y-640)<3,"Actual Slime patrol stays grounded on wide lower floor")
		(enemy as SlimeEnemy).ai_enabled = false
	# Actual Player input/motor crosses all seams in both directions, without jump/dash.
	await _walk_actor(ROOM.SUPPLY.x)
	_check(absf(actor.position.x-ROOM.SUPPLY.x)<20 and actor.motor.is_grounded() and absf(actor.position.y-360)<3,"Player walks down and back up to optional resource spur")
	_check(not bool(run.room.get("shortcut_open")),"Lower walk never implicitly opens shortcut")
	await _walk_actor(ROOM.LEVER.x)
	_check(not run.call("activate_shortcut"),"Lever refuses while ground enemies remain")
	await _walk_actor(ROOM.ENTRY.x)
	_check(absf(actor.position.x-ROOM.ENTRY.x)<20 and absf(actor.position.y-360)<3,"Player walks the complete lower route back without unlock")
	# Every relevant collider envelope uses the same real world floor/motor.
	for size: Vector2 in [Vector2(20,36),Vector2(28,24),Vector2(76,100)]:
		_create_probe(size)
		await _move_probe(5060)
		_check(absf(probe.position.x-5060)<5 and probe.is_on_floor() and probe.position.y<645,"Ground collider walks east: "+str(size))
		await _move_probe(180)
		_check(absf(probe.position.x-180)<5 and probe.is_on_floor(),"Ground collider walks west: "+str(size))
		probe.queue_free()
		await _step(2)
	# Actual Slime motor over the whole map, isolated from its FSM (geometry test).
	var slime: SlimeEnemy = run.living_enemies()[0] as SlimeEnemy
	probe = slime
	probe_motor = slime.motor
	await _move_probe(5060)
	_check(slime.is_on_floor() and absf(slime.position.x-5060)<5,"Existing Slime motor reaches upper east ledge")
	await _move_probe(180)
	_check(slime.is_on_floor() and absf(slime.position.x-180)<5,"Existing Slime motor reaches upper west ledge")
	# Synthetic clear fixture only; root probe separately proves actual combat.
	for enemy: Node2D in run.living_enemies(): enemy.health.apply_damage(99999)
	await _step(8)
	run.gear.loot.clear()
	await _walk_actor(ROOM.LEVER.x)
	_check(run.call("activate_shortcut"),"Grounded interaction after actual death signals opens bridge")
	_check(not run.call("activate_shortcut"),"Repeated lever activation cannot duplicate bridge")
	var bridge: StaticBody2D = run.room.get("shortcut") as StaticBody2D
	_check((bridge.get_node("Shape") as CollisionShape2D).one_way_collision,"Return bridge remains one-way and cannot enclose a lower actor")
	await _walk_actor(ROOM.SUPPLY.x)
	await _source_cases()
	await _walk_actor(2500)
	_check(actor.motor.is_grounded() and absf(actor.position.y-360)<3,"Actual Player returns along elevated shortcut")
	await _walk_actor(ROOM.ENTRY.x)
	_check(run.can_choose_floor_exit(),"Returned Player can choose safe return")
	_check(run.floor_exit.open(),"Existing floor choice opens at mine entrance")
	_check(not run.floor_exit.continue_button.visible and run.floor_exit.return_button.visible,"Mine return choice cannot claim a new production floor")
	run.floor_exit.close()
	_check(not run.request_floor_return(),"Standalone fixture without GameFlow cannot invent a return writer")
	await _layout_cases()
	_release()
	run.queue_free()
	current_scene = null
	await _step(12)
	print("RESULT ShatteredMine %d checks, %d failures; hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	await root.get_node("AudioManager").shutdown()
	quit(0 if failures==0 else 1)

func _source_cases() -> void:
	var cache: TreasureChest = run.get("supply_cache") as TreasureChest
	var source_id: StringName = &"shattered_mine_private_cache"
	_check(cache.get_meta(&"shattered_mine_source")==source_id,"Source identity belongs only to private mine")
	var cap: int = run.gear.loot.maximum_pickups
	run.gear.loot.maximum_pickups = 1
	_check(not cache.interact() and not cache.is_open and not bool(run.get("supply_claimed")),"Pickup cap refusal leaves unopened cache retryable")
	run.gear.loot.maximum_pickups = cap
	actor.suspend_controls(true)
	_check(not cache.interact(),"Suspended input cannot open cache")
	actor.suspend_controls(false)
	_check(cache.interact(),"Existing E chest contract creates actual material pickups")
	_check(not cache.interact() and bool(run.get("supply_claimed")),"Opened cache cannot create duplicate pickups")
	var inventory: GearInventory = run.gear.inventory
	for pickup: LootPickup in run.gear.loot.get_children():
		_check(pickup.get_meta(&"shattered_mine_source")==source_id and pickup.quantity==RuneLearningService.CRAFT_COST[pickup.item_id],"Pickup metadata and quantity match real rune-crafting consumer")
		pickup.automatic = false
		inventory.materials[pickup.item_id] = MaterialCatalog.MAX_COUNT
		_check(not pickup.collect() and not pickup.collected_once and not pickup.is_queued_for_deletion(),"Full material bag keeps uncollected pickup for retry")
		inventory.spend_material(pickup.item_id,MaterialCatalog.MAX_COUNT)
		_check(pickup.collect(),"Making material space permits collection through existing owner")
		_check(not pickup.collect(),"Pickup collection is idempotent")
	_check(inventory.materials[&"dust"]==2 and inventory.materials[&"crystal"]==1,"One visit yields exactly one real 2/1 crafting recipe from this cache")
	_check(not run.enter_room(1) and cache.is_open,"Source remains consumed after forbidden reentry call")
	await _step(3)

func _layout_cases() -> void:
	for size: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size = Vector2i.ZERO
		root.size = size
		await _step(2)
		run.call("_layout_mine_hud")
		var label: Label = run.get("mine_title") as Label
		var hint: Label = run.get("route_hint") as Label
		var visible: Vector2 = root.get_visible_rect().size
		_check(visible==Vector2(size),"Layout fixture uses the exact requested canvas: "+str(size))
		_check(label.position.x>=420 and label.position.x+label.size.x<=visible.x+1,"Title bounds preserve existing ornate HUD at "+str(size))
		_check(hint.position.x+hint.size.x<=visible.x+1 and hint.position.y+hint.size.y<visible.y,"Route hint remains inside viewport at "+str(size))

func _walk_actor(x: float) -> void:
	var direction: float = signf(x-actor.position.x)
	var action: StringName = &"move_right" if direction>0 else &"move_left"
	Input.action_press(action)
	for tick: int in int(25*Engine.physics_ticks_per_second):
		await _step(1)
		if direction*(actor.position.x-x)>=0: break
	Input.action_release(action)
	await _step(15)

func _create_probe(size: Vector2) -> void:
	probe = CharacterBody2D.new()
	probe.collision_layer = 4
	probe.collision_mask = 1
	probe.floor_snap_length = 1
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0,-size.y*0.5)
	probe.add_child(collision)
	probe_motor = KnockbackMotor.new()
	probe_motor.body = probe
	probe.add_child(probe_motor)
	probe.position = ROOM.ENTRY
	run.add_child(probe)

func _move_probe(x: float) -> void:
	for tick: int in int(30*Engine.physics_ticks_per_second):
		await physics_frame
		probe_motor.step(1.0/Engine.physics_ticks_per_second,INF,clampf((x-probe.position.x)*10,-500,500))
		await process_frame
		if absf(x-probe.position.x)<3 and probe.is_on_floor(): break

func _step(count: int) -> void:
	for tick: int in count:
		await physics_frame
		await process_frame

func _release() -> void:
	for action: StringName in [&"move_left",&"move_right",&"jump",&"dash",&"interact"]: Input.action_release(action)

func _check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		print("FAIL: "+message)
