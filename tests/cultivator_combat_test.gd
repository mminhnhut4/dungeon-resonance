extends SceneTree
## Focused isolated realm/skill/retaliation regression. No personal save input.
var checks: int = 0
var failures: int = 0
var room: ExteriorRoom
var hero: Player
var state: NpcWorldState
var actor: CultivatorActor
var observed: Array[Dictionary] = []
var incoming_result: DamageResult
var incoming_event: DamageEvent

class RefusingWorld extends NpcWorldState:
	func receive_hit(_id: String, _hp: float, _origin_x: float, _player_caused: bool = true, _actor_x: float = NAN, _record_cause: bool = true, _witnesses: Array[String] = []) -> bool:
		return false

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if allowed.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: isolated DUNGEON_QA_DATA_ROOT required"); quit(2); return
	_scaling()
	room = ExteriorRoom.new()
	room.room_id = &"o01_p03"
	room.route_id = ExteriorRouteCatalog.MAIN
	room.width = 2600.0
	room.surface = PackedVector2Array([Vector2(0,400),Vector2(2600,400)])
	root.add_child(room)
	current_scene = room
	_block(Vector2(1300,440),Vector2(2600,80))
	hero = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	room.add_child(hero)
	hero.set_physics_process(false)
	hero.health.maximum_health = 10000.0
	hero.health.current_health = 10000.0
	hero.health.minimum_health = 1.0
	hero.hurtbox.hit_resolved.connect(_observe)
	await _step(3)
	for id: String in CultivatorCatalog.TAN_DANG_IDS: await _skill(id)
	await _retaliation()
	await _institutional_response()
	await _walls()
	await _canonical_floor()
	await _cleanup_actor()
	room.queue_free()
	await _step(4)
	_check(get_nodes_in_group(&"npc_pilot_actor").is_empty(),"Room teardown frees every local fighter")
	await root.get_node("AudioManager").shutdown()
	print("RESULT CultivatorCombat checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)

func _scaling() -> void:
	var config: Dictionary = OpeningCultivationState.default_config()
	var previous_hp: float = 0.0
	var previous_damage: float = 0.0
	for index: int in config["stages"].size():
		var stage_id: String = str(config["stages"][index])
		var hp: float = NpcPilotCatalog.MAX_HEALTH*CultivatorCombatScaling.health_multiplier(stage_id)
		var damage: float = CultivatorCombatScaling.outgoing_damage(stage_id,10.0)
		_check(CultivatorCombatScaling.stage_index(stage_id) == index and hp > previous_hp and damage > previous_damage,"Combat scaling reads the actual ordered cultivation stage "+stage_id)
		_check(hp <= 100.0 and damage <= CultivatorCombatScaling.MAX_DAMAGE,"Existing realm scaling stays bounded")
		previous_hp = hp; previous_damage = damage
	_check(CultivatorCombatScaling.stage_index("invented_realm") == -1 and CultivatorCombatScaling.health_multiplier("invented_realm") == 1.0,"Unknown realm cannot mint stronger stats")
	_check(CultivatorCombatScaling.outgoing_damage("truc_co_so_ky",INF) == 0.0 and CultivatorCombatScaling.outgoing_damage("truc_co_so_ky",10000.0) == 32.0,"Invalid or excessive authored damage stays finite and capped")
	for id: String in CultivatorCatalog.IDS:
		_check(NpcPilotCatalog.maximum_health(id) == 40.0 and NpcPilotCatalog.cultivation_stage(id) == "luyen_khi_i","Legacy identity retains compatible stage-zero HP: "+id)
	var patterns: Array[String] = []
	for id: String in CultivatorCatalog.TAN_DANG_IDS:
		var spec: Dictionary = CultivatorCatalog.definition(id)
		patterns.append(str(spec["pattern"]))
		_check(spec["stage_id"] == NpcPilotCatalog.cultivation_stage(id) and spec["aggro"] == 20.0,"New identity reads canonical realm and 20-second retaliation: "+id)
	_check(patterns == ["seal","double_cut","lunge"],"The three new identities have different spatial/temporal skill patterns")

func _spawn(id: String, refuse_hits: bool = false) -> void:
	await _cleanup_actor()
	state = RefusingWorld.new() if refuse_hits else NpcWorldState.new()
	state.save_path = "user://verification/cultivator_combat_%d_%d.json" % [OS.get_process_id(),Time.get_ticks_usec()]
	_check(state.save(),"Isolated canonical fixture saves before contact")
	actor = CultivatorActor.new()
	actor.stable_id = id
	actor.npc_id = StringName(id)
	actor.world_state = state
	actor.room = room
	actor.player = hero
	actor.bind_road_idle_art()
	room.add_child(actor)
	actor.set_physics_process(false)
	actor.sync_record(true)
	hero.reset_movement_at(actor.global_position+Vector2(-32,0))
	hero.hurtbox.invulnerable = false
	hero.damage_grace_remaining = 0.0
	observed.clear()
	await _step(3)
	_check(actor.health.maximum_health == NpcPilotCatalog.maximum_health(id) and actor.health.current_health == state.records[id]["hp"],"Live HP agrees with the canonical per-ID realm ceiling")

func _skill(id: String) -> void:
	await _spawn(id)
	_incoming(hero,1.0)
	_check(incoming_result.actual_damage == 1.0 and actor.combat_phase == "hurt" and actor.aggro_remaining == 20.0,"Accepted Player injury begins bounded self-defense: "+id)
	_advance_until("tell",1.0)
	_check(actor.combat_phase == "tell" and not actor.strike_hitbox.active and actor.caption.text.contains(str(actor._combat_spec["skill"])),"Named tell is visible before the first damage window: "+id)
	var root_id: int = actor._strike.root_event_id
	var cooldown: float = actor.cooldown_remaining
	var pattern: String = str(actor._combat_spec["pattern"])
	if pattern == "seal":
		var locked: Vector2 = actor._strike_center
		hero.reset_movement_at(actor.global_position+Vector2(36,0))
		await _step(2)
		_advance_until("active",2.0)
		_check(actor._strike_center == locked and observed.is_empty(),"Leaving the marked point avoids the locked seal")
		_advance(0.3)
	else:
		_advance_until("active",2.0)
		_check(not observed.is_empty() and observed[0]["root"] == root_id and observed[0]["source"] == actor.get_instance_id() and observed[0]["team"] == actor.hurtbox.team_id,"Actual query contact retains source, allegiance and committed root: "+id)
		if pattern == "double_cut":
			_advance(float(actor._combat_spec["active"])+0.02)
			_check(actor.combat_phase == "tell" and actor._strike_window == 2 and not actor.strike_hitbox.active,"Second cut has its own readable, harmless tell")
			_advance_until("active",1.0)
			_check(observed.size() == 2 and observed[1]["root"] == root_id and observed[1]["window"] == 2,"Two finite windows share one root and each deliver at most once")
			actor.strike_hitbox.sample_contacts()
			_check(observed.size() == 2,"Repeated samples cannot add a third hit")
		else:
			var before_x: float = actor.position.x
			_advance(0.05)
			_check(actor.position.x < before_x and actor.position.x >= float(NpcPilotCatalog.definition(id)["left"]),"Lunge advances a short physical step inside authored bounds")
	_check(cooldown > 0.0 and actor.cooldown_remaining > 0.0,"Committed skill keeps a bounded cooldown")
	var preserved_cooldown: float = actor.cooldown_remaining
	actor.sync_record(false)
	_check(not actor.strike_hitbox.active and actor._strike == null and actor.cooldown_remaining == preserved_cooldown,"Pause cancels damage without refunding the cooldown")
	actor.sync_record(true)
	actor.cooldown_remaining = 0.0 # Fixture isolates hurt cancellation from cooldown.
	actor._commit_strike()
	var cancelled_root: int = actor._strike.root_event_id
	_incoming(hero,1.0)
	_check(actor.combat_phase == "hurt" and actor._strike == null and not actor.strike_hitbox.active and actor.cooldown_remaining > 0.0,"New injury cancels a committed skill and keeps its cooldown")
	_check(not observed.any(func(item: Dictionary) -> bool: return item["root"] == cancelled_root),"Cancelled root has no leaked contact")

func _retaliation() -> void:
	await _spawn("tan_dang_lam_tuoc")
	_check(not actor.request_retaliation(),"A neutral NPC cannot invent a persisted grievance")
	var bystander := Node2D.new()
	room.add_child(bystander)
	bystander.global_position = hero.global_position
	_incoming(bystander,1.0)
	_check(incoming_result.actual_damage == 1.0 and actor.combat_phase == "idle" and state.karma(actor.stable_id)["grievance"] == "","A live fake team-one source does not provoke Player retaliation")
	bystander.queue_free()
	_incoming(hero,1.0)
	_check(state.karma(actor.stable_id)["grievance"] == "attacked","Actual harm records canonical grievance")
	actor._set_phase("recover",30.0) # Hold position/attacks while exercising the real timer.
	_advance(19.0)
	_check(actor.combat_phase != "idle" and actor.aggro_remaining > 0.0,"Retaliation lasts past the obsolete eight-second limit")
	_incoming(hero,0.5,DamageEvent.SourceKind.DOT)
	_check(actor.aggro_remaining == 20.0,"Accepted Player-caused DOT retains its causal attack and resets the timer")
	actor._set_phase("recover",30.0)
	_advance(3.0)
	var remaining: float = actor.aggro_remaining
	hero.hurtbox.invulnerable = true
	actor.hurtbox.invulnerable = true
	_incoming(hero,1.0)
	_check(incoming_result.blocked and actor.aggro_remaining == remaining,"Blocked incoming contact does not reset retaliation")
	actor.hurtbox.invulnerable = false
	hero.hurtbox.invulnerable = false
	_advance(17.1)
	_check(actor.combat_phase == "idle" and actor.aggro_remaining == 0.0 and not actor.strike_hitbox.active,"Twenty seconds without another accepted attack ends local retaliation")
	_check(state.karma(actor.stable_id)["grievance"] == "attacked" and actor.request_retaliation(),"Timer expiry preserves grievance for an explicit future response")
	actor._stop_defense("fixture")
	state.read_only = true
	_check(not actor.request_retaliation(),"Quarantined canonical state refuses a new retaliation request")
	state.read_only = false
	await _spawn("tan_dang_lam_tuoc",true)
	var rejected_health: float = actor.health.current_health
	_incoming(hero,2.0)
	_check(incoming_result.blocked and incoming_result.block_reason == &"npc_commit_failed" and actor.health.current_health == rejected_health and actor.combat_phase == "idle","Rejected canonical hit restores local HP and cannot provoke retaliation")

func _walls() -> void:
	await _spawn("xich_lo_guard_01")
	var wall := _block(actor.position+Vector2(30,-30),Vector2(8,100))
	await _step(3)
	var blocked: Vector2 = actor._safe_position(actor.position,actor.position+Vector2(100,0))
	_check(blocked.x < wall.position.x-8.0 and blocked.x >= actor.position.x,"Swept body stops before a solid instead of teleporting across it")
	state.records[actor.stable_id]["x"] = actor.position.x+100.0
	actor.sync_record(true)
	_check(actor.position.x < wall.position.x and state.records[actor.stable_id]["x"] == actor.position.x,"Visible patrol correction also preserves the owner position at a wall")
	hero.reset_movement_at(actor.global_position+Vector2(48,0))
	await _step(2)
	_incoming(hero,1.0)
	actor._commit_strike() # Wall appeared after a hypothetical prior commitment.
	actor._open_strike()
	_check(observed.is_empty(),"A broad-phase melee overlap cannot damage through a solid")
	actor._stop_defense("fixture")
	wall.queue_free()
	await _step(3)
	var shelf := _block(actor.position+Vector2(30,-35),Vector2(12,8),true)
	actor._collect_one_way_solids()
	await _step(3)
	var under_shelf: Vector2 = actor._safe_position(actor.position,actor.position+Vector2(60,0))
	_check(is_equal_approx(under_shelf.x,actor.position.x+60.0),"Grounded movement can pass below an explicitly one-way optional shelf")
	shelf.queue_free()
	await _step(3)

func _institutional_response() -> void:
	await _spawn("tan_dang_moc_yen")
	var victim: String = "tan_dang_du_hanh"
	_check(not actor.request_retaliation("player_murder",victim),"Institutional response cannot invent a missing victim grievance")
	# Declared canonical same-room/public-report setup for this AI geometry bench.
	state.records[victim]["room"]=state.records[actor.stable_id]["room"]
	_check(state.receive_hit(victim,1.0,0.0,true),"Canonical life owner accepts the victim's downed fixture")
	_check(state.decide(victim,state.decision_token(victim),true,true,[actor.stable_id]),"Explicit confirmed execution establishes the canonical murder fact")
	_check(not actor.can_request_retaliation("player_murder",victim),"Private witnessed fact alone does not authorize a public institutional response")
	_check(state.report_cause(victim,"player_murder",actor.stable_id,state.records[actor.stable_id]["room"]),"Declared living witness publishes a local report before AI eligibility tests")
	_check(not actor.request_retaliation("attacked",victim) and not actor.request_retaliation("player_murder","pilot_traveler"),"Institutional response rejects wrong reasons and identities outside the faction")
	var untouched: Dictionary = state.snapshot()
	var engagement: float = actor._engagement_x
	var prior_reason: String = actor.reason
	# x+100 is inside Mộc's new Hub route; x-100 remains within the
	# prospective engagement distance but beyond its authored lower edge.
	hero.reset_movement_at(actor.global_position+Vector2(-100,0))
	_check(not actor.can_request_retaliation("player_murder",victim) and not actor.request_retaliation("player_murder",victim) and actor._engagement_x == engagement and actor.aggro_remaining == 0.0 and actor.combat_phase == "idle" and actor.reason == prior_reason and state.snapshot() == untouched and state._local_control.is_empty(),"Outside-leash preflight/request cannot mutate engagement, clocks, reason, ownership or canonical state")
	hero.reset_movement_at(actor.global_position+Vector2(-32,0))
	_check(actor.can_request_retaliation("player_murder",victim) and actor._engagement_x == engagement and actor.aggro_remaining == 0.0 and actor.combat_phase == "idle" and state.snapshot() == untouched and state._local_control.is_empty(),"Ready within-leash eligibility is pure and uses the prospective actor engagement origin")
	_check(actor.request_retaliation("player_murder",victim) and actor.reason.contains("Đồng môn") and actor.aggro_remaining == 20.0,"A living faction member can make one local response to a persisted victim fact")
	var own_karma: Dictionary = state.karma(actor.stable_id)
	_check(own_karma["grievance"] == "" and not own_karma["player_murdered"] and state.records[victim]["mode"] == "dead","Institutional response does not copy victim life or karma onto the responding actor")
	_advance(0.2)
	var observed_timer: float = actor.aggro_remaining
	untouched = state.snapshot()
	_check(actor.is_responding_to(victim) and not actor.is_responding_to(actor.stable_id) and actor.response_owner_id == victim and actor.aggro_remaining == observed_timer and observed_timer < 20.0 and state.snapshot() == untouched,"Institutional-response query matches the victim and cannot renew its timer or mutate canonical facts")
	_incoming(hero,1.0)
	_check(actor.response_owner_id == actor.stable_id and actor.is_responding_to(actor.stable_id) and not actor.is_responding_to(victim) and actor.aggro_remaining == 20.0,"A newly accepted actual Player hit changes local response ownership to the actor's own injury")
	actor._set_phase("recover",30.0)
	_advance(20.1)
	_check(actor.combat_phase == "idle" and actor.response_owner_id == "" and not actor.is_responding_to(victim) and state.karma(victim)["grievance"] == "player_murder","Response expiry clears local ownership while the canonical murder grievance remains")
	_incoming(hero,10000.0)
	untouched = state.snapshot()
	engagement = actor._engagement_x
	prior_reason = actor.reason
	_check(not actor.can_request_retaliation("player_murder",victim) and not actor.request_retaliation("player_murder",victim) and actor._engagement_x == engagement and actor.aggro_remaining == 0.0 and actor.combat_phase == "idle" and actor.reason == prior_reason and state.snapshot() == untouched and state._local_control.is_empty(),"Downed preflight/request cannot consume a response or mutate actor/canonical state")

func _canonical_floor() -> void:
	await _spawn("tan_dang_du_hanh")
	_incoming(hero,10000.0)
	_check(not incoming_result.killed and actor.health.current_health == 1.0 and state.records[actor.stable_id]["mode"] == "downed","New NPC physical damage stops at canonical downed, awaiting explicit kill/spare")
	_check(not actor.request_retaliation() and not actor.strike_hitbox.active,"Downed actors cannot retaliate or retain an active attack")
	await _spawn("thanh_van_disciple_01")
	_incoming(hero,10000.0)
	_check(not incoming_result.killed and actor.health.current_health == 1.0 and state.records[actor.stable_id]["mode"] == "recovering","Legacy protected actor retains its nonlethal withdrawal contract")
	await _spawn("tan_dang_lam_tuoc")
	var previous_hp: float = actor.health.current_health
	state.save_path = "user://verification/missing_parent_%d/profile/npc.json" % Time.get_ticks_usec()
	state.read_only = true
	_incoming(hero,1.0)
	_check(incoming_result.blocked and actor.health.current_health == previous_hp and actor.combat_phase == "idle","Read-only owner prevents injury and local retaliation")
	state.read_only = false

func _incoming(source: Node2D, damage: float, kind: DamageEvent.SourceKind = DamageEvent.SourceKind.DIRECT) -> void:
	incoming_event = DamageEvent.new()
	incoming_event.source_id = source.get_instance_id()
	incoming_event.source_team_id = 1
	incoming_event.target_id = actor.get_instance_id()
	incoming_event.attack_id = CombatIds.next_id()
	incoming_event.root_event_id = incoming_event.attack_id
	incoming_event.hit_window_id = 1
	incoming_event.base_damage = damage
	incoming_event.attack_origin = source.global_position
	incoming_event.source_kind = kind
	incoming_result = actor.hurtbox.take_damage(incoming_event)

func _observe(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked: return
	observed.append({"source":event.source_id,"team":event.source_team_id,"root":event.root_event_id,"window":event.hit_window_id,"damage":result.actual_damage})

func _advance(seconds: float) -> void:
	var frame_count: int = int(ceil(seconds*Engine.physics_ticks_per_second))
	for _index: int in frame_count: _tick_actor()

func _advance_until(phase: String, seconds: float) -> void:
	for _index: int in int(ceil(seconds*Engine.physics_ticks_per_second)):
		if actor.combat_phase == phase: return
		_tick_actor()

func _tick_actor() -> void:
	var delta: float = 1.0/Engine.physics_ticks_per_second
	# The stationary QA Player has its motor disabled; advance its existing
	# damage grace separately so the second cut still respects the real 0.6s gate.
	hero.damage_grace_remaining = maxf(0.0,hero.damage_grace_remaining-delta)
	hero.hurtbox.invulnerable = hero.damage_grace_remaining > 0.0
	actor._physics_process(delta)

func _block(center: Vector2, size: Vector2, one_way: bool = false) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = center
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision.shape = rectangle
	collision.one_way_collision = one_way
	body.add_child(collision)
	room.add_child(body)
	return body

func _cleanup_actor() -> void:
	if is_instance_valid(actor):
		actor.queue_free()
		await _step(3)
	actor = null

func _step(count: int) -> void:
	for _index: int in count: await physics_frame; await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1; print("FAIL: "+label)
