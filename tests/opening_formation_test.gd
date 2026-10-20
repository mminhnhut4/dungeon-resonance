extends SceneTree
var checks: int=0
var failures: int=0
var seed_value: int=137
var observed: Array[Dictionary]=[]
func _initialize() -> void:call_deferred("run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func step(n: int) -> void:
	for i: int in n:await physics_frame;await process_frame
func born(node: Node) -> void:
	if node is WorldCampaign:node.run_seed=seed_value
	if node.get_parent() is DungeonRoom and (node is BaseEnemy or node is SlimeEnemy):
		observed.append({"role":String(node.definition.id) if node is BaseEnemy else "runic_slime","position":node.position})
func legacy_draws(rng: RandomNumberGenerator) -> Array[float]:
	var result: Array[float]=[560,715,870,1020]
	for index: int in range(result.size()-1,0,-1):
		var other: int=rng.randi_range(0,index)
		var old: float=result[index];result[index]=result[other];result[other]=old
	return result
func run() -> void:
	AudioServer.set_bus_mute(0,true)
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated QA userdata")
	node_added.connect(born)
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate()
	flow.save_path_override="user://formation/profile.json";root.add_child(flow);await step(12)
	observed.clear();flow.start_campaign()
	var campaign: WorldCampaign=flow.active_scene as WorldCampaign
	check(campaign!=null and campaign.stage==1,"Actual canonical opening loaded")
	check(observed.size()==4,"Exactly four actors, no extra wave or enemy")
	check(observed[0]["role"]=="ancient_guard" and observed[0]["position"]==Vector2(560,640),"Near Guard keeps existing ground anchor")
	check(observed[1]["role"]=="ancient_guard" and observed[1]["position"]==Vector2(870,640),"Rear Guard uses separate existing anchor")
	check(observed[2]["role"]=="bloodwing_bat" and observed[2]["position"]==Vector2(715,500),"Bat supports the near group at existing flight height")
	check(observed[3]["role"]=="runic_slime" and observed[3]["position"]==Vector2(1020,640),"Runic stays in rear group")
	var reference:=RandomNumberGenerator.new();reference.seed=seed_value
	legacy_draws(reference)
	check(reference.state==campaign.spawn_rng.state,"Opening preserves legacy random-stream consumption")
	check(campaign.room.get_node_or_null("OpeningAttackWindow")!=null,"Existing timing coordinator remains attached")
	for enemy: Node2D in campaign.living_enemies():
		check(enemy.health.maximum_health==(60.0 if enemy is SlimeEnemy else 70.0 if enemy.definition.id==&"bloodwing_bat" else 90.0),"Role HP unchanged")
		if enemy is BaseEnemy:
			check(enemy.attack_cooldown==0 and enemy.attack_hitbox.attack_snapshot==null,"No forced attack or preactivated hitbox from formation")
		else:
			check(not enemy.contact_damage_enabled and enemy.get_script().get_script_constant_map().get("WINDUP")==.55,"Runic warned damage contract retained")
	var expected_next: Array[float]=legacy_draws(reference)
	observed.clear();check(campaign.enter_stage(3),"Existing later combat stage remains reachable in focused fixture")
	check(observed.size()==4,"Later wave retains four authored actors")
	for i: int in 4:check(observed[i]["position"].x==expected_next[i],"Later wave keeps legacy shuffled anchor "+str(i))
	check(campaign.spawn_rng.state==reference.state,"Later wave keeps exact RNG state")
	check(campaign.room.get_node_or_null("OpeningAttackWindow")==null,"Formation does not expand coordinator to other rooms")
	node_added.disconnect(born);flow.queue_free();current_scene=null;await step(8)
	check(get_nodes_in_group(&"runic_harrier_bolts").is_empty(),"Room teardown retains projectile cleanup")
	await root.get_node("AudioManager").shutdown()
	print("RESULT Formation checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
