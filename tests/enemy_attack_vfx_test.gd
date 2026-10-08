extends SceneTree
## Live FSM/contacts/landing plus geometry, caps, pause and teardown. No GPU claim.
var arena: Node2D
var hero: Player
var feedback: CombatFeedback
var guard: BaseEnemy
var boss: BossGolem
var skin: BossGolemSkin
var checks: int = 0
var failures: int = 0
var resolved: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"QA user:// is isolated before any gameplay scene")
	if failures > 0:
		quit(1)
		return
	AudioServer.set_bus_mute(0,true)
	arena = Node2D.new()
	root.add_child(arena)
	current_scene = arena
	var floor_body := StaticBody2D.new()
	floor_body.position = Vector2(800,680)
	floor_body.collision_layer = 1
	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(1600,80)
	floor_shape.shape = rectangle
	floor_body.add_child(floor_shape)
	arena.add_child(floor_body)
	hero = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	arena.add_child(hero)
	hero.reset_movement_at(Vector2(500,640))
	hero.controls_enabled = false
	feedback = CombatFeedback.new()
	feedback.hit_stop_seconds = 0.0
	arena.add_child(feedback)
	hero.combat_feedback = feedback
	hero.hurtbox.hit_resolved.connect(_observe)
	await _step(5)
	await _guard_live()
	await _stomp_live()
	await _caps_and_scope()
	await _cancel_and_teardown()
	var evidence := {"physics_hz":Engine.physics_ticks_per_second,"checks":checks,"failures":failures,"resolved_events":resolved,"gpu_acceptance":false,"new_gameplay_hazards":false}
	DirAccess.make_dir_recursive_absolute("user://verification")
	var file := FileAccess.open("user://verification/enemy_attack_vfx_%d.json"%Engine.physics_ticks_per_second,FileAccess.WRITE)
	_check(file != null,"VFX evidence is writable only in isolated user://")
	if file != null:
		evidence["checks"]=checks
		evidence["failures"]=failures
		file.store_string(JSON.stringify(evidence,"\t"))
		file.close()
	print("RESULT EnemyAttackVFX %d checks, %d failures; physics_hz=%d; GPU UNRUN"%[checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures==0 else 1)

func _guard_live() -> void:
	guard = _new_guard(Vector2(578,640),true)
	await _wait_guard(&"telegraph")
	var vfx: GuardSweepVFX = guard.visual.sweep_vfx
	_check(vfx != null and vfx.get_parent()==guard.visual,"Live guard installs its enemy-owned sweep module")
	_check(vfx.material is CanvasItemMaterial and (vfx.material as CanvasItemMaterial).blend_mode==CanvasItemMaterial.BLEND_MODE_MIX and (vfx.material as CanvasItemMaterial).light_mode==CanvasItemMaterial.LIGHT_MODE_UNSHADED,"Slash ink uses fixed mix/unshaded colors, no additive light plane")
	var body: CollisionShape2D = guard.get_node("BodyCollision")
	var shape_id: int = body.shape.get_instance_id()
	var transform_before: Transform2D = body.transform
	var hp_before: float = hero.health.current_health
	await _time(0.16)
	vfx.seek_actor()
	_check(vfx.phase==&"telegraph" and is_equal_approx(vfx.progress,guard.state_time/guard.definition.windup),"Windup seeks the authoritative scaled FSM clock")
	_check(not guard.attack_hitbox.active and hero.health.current_health==hp_before,"Visible windup precedes the unchanged damage window")
	var pause_clock: float = guard.state_time
	var pause_progress: float = vfx.progress
	paused=true
	await _process_steps(3)
	_check(guard.state_time==pause_clock and vfx.progress==pause_progress,"Tree pause holds guard tell and gameplay clocks")
	paused=false
	feedback.hit_stop_remaining=0.08
	await _step(2)
	pause_clock=guard.state_time
	pause_progress=vfx.progress
	await _step(2)
	_check(guard.state_time==pause_clock and vfx.progress==pause_progress,"Hitstop holds guard VFX with its existing motor/FSM")
	await _wait_guard(&"attack")
	vfx.seek_actor()
	_check(guard.attack_hitbox.active and vfx.phase==&"attack","Active slash appears only with the existing active hitbox")
	var hit_shape := guard.attack_hitbox._query_shape as RectangleShape2D
	_check(hit_shape.size==Vector2(96,26) and guard.attack_hitbox.position==Vector2(guard.facing*44,-16),"Sweep collider/range/offset remain exactly authored")
	_check(hero.health.current_health < hp_before and vfx.impact_count==1,"Accepted live DamageEvent emits exactly one contact star")
	_check(resolved.size()==1 and resolved[0]["source"]==guard.get_instance_id() and resolved[0]["damage"]==guard.definition.attack_damage,"Guard contact retains its original source and damage")
	var count_before: int = vfx.impact_count
	var duplicate := _event(hero,10001,guard.get_instance_id(),1.0)
	duplicate.physical_damage=true
	var rejected: DamageResult=hero.hurtbox.take_damage(duplicate)
	_check(rejected.blocked and vfx.impact_count==count_before,"Invulnerability rejection cannot emit a false contact flash")
	_check(body.shape.get_instance_id()==shape_id and body.transform==transform_before,"Guard VFX does not mutate body resources or transforms")
	await _wait_guard(&"recover")
	vfx.seek_actor()
	_check(not guard.attack_hitbox.active and vfx.phase==&"recover","Recovery closes damage and owns finite follow-through")
	await _time(0.13)
	_check(guard.state_machine.get_state_id()==&"recover" and guard.state_time>0.10,"Follow-through threshold is inside the unchanged recovery")
	guard.ai_enabled=false
	# Geometric inspection can seek a pose without creating another attack.
	for sign_x: float in [-1.0,1.0]:
		guard.facing=sign_x
		EnemySpriteArt.set_facing(guard.visual.sprite,guard.visual.geometry["foot_pixel"],sign_x<0)
		vfx.facing=sign_x
		for amount: float in [0.0,0.25,0.75,1.0]:
			var polygon: PackedVector2Array=vfx.ribbon_points(amount)
			_check(Geometry2D.triangulate_polygon(polygon).size()==72,"Closed saber contour triangulates at both committed facings")
			var within: bool=true
			for point: Vector2 in polygon:
				within=within and point.x*sign_x>=-4.0 and point.x*sign_x<=92.0 and point.y>=-29.0 and point.y<=-3.0
			_check(within,"Dangerous slash fill stays within the existing sweep lane")
	var incoming: DamageEvent=_event(guard,10002,hero.get_instance_id(),1.0)
	incoming.stun_seconds=0.2
	guard.hurtbox.take_damage(incoming)
	vfx.seek_actor()
	_check(vfx.phase.is_empty() and vfx.impact_remaining==0.0 and not guard.attack_hitbox.active,"Real stun interruption clears trails/cues and preserves hitbox cancellation")
	var listener: Callable=Callable(vfx,"_on_resolved")
	guard.queue_free()
	await _step(3)
	_check(not hero.hurtbox.hit_resolved.is_connected(listener) and get_nodes_in_group(&"guard_sweep_vfx").is_empty(),"Guard teardown disconnects the persistent Player result signal")

func _stomp_live() -> void:
	hero.reset_movement_at(Vector2(600,640))
	hero.controls_enabled=false
	resolved.clear()
	boss=preload("res://scenes/enemies/boss_golem.tscn").instantiate() as BossGolem
	boss.position=Vector2(800,640)
	boss.feedback=feedback
	arena.add_child(boss)
	await _step(3) # Real motor establishes floor contact.
	boss.ai_enabled=false
	boss.player=hero
	skin=BossGolemSkin.new()
	boss.add_child(skin)
	skin.bind(boss)
	var vfx: GolemStompVFX=skin.stomp_vfx
	_check(vfx!=null and vfx.z_index<0 and skin.art_rig!=null and skin.art_rig.is_visible_in_tree() and not skin.sprite.visible and skin.art_rig.get_node("Torso/PaintedStone") is MeshInstance2D,"Stomp ground cue lives behind the visible static UV mesh body")
	_check(vfx.material is CanvasItemMaterial and (vfx.material as CanvasItemMaterial).blend_mode==CanvasItemMaterial.BLEND_MODE_MIX,"Cracks/debris use normal alpha mix and no additive body flash")
	var body: CollisionShape2D=boss.get_node("Body")
	var shape_id: int=body.shape.get_instance_id()
	var body_before: Transform2D=body.transform
	boss.health.apply_damage(251.0)
	_check(boss.phase==2 and boss.health.current_health==249.0,"Fixture uses the real existing phase-two threshold")
	boss.fsm.transition_to(&"stomp")
	boss.ai_enabled=true
	await _time(0.18)
	vfx.seek_actor()
	_check(vfx.phase==&"windup" and not boss.launched and boss.shockwave_count==0,"Stomp tells before launch and before any ground wave")
	var clock_before: float=boss.state_time
	var cue_before: float=vfx.progress
	paused=true
	await _process_steps(3)
	_check(boss.state_time==clock_before and vfx.progress==cue_before,"Pause holds stomp marker and boss state")
	paused=false
	while not boss.launched and boss.fsm.get_state_id()==&"stomp":
		await _step(1)
	vfx.seek_actor()
	_check(boss.state_time>=0.5 and boss.state_time<0.5+2.0/Engine.physics_ticks_per_second and vfx.phase==&"flight","Flight pose begins on actual launch at the existing 0.50s")
	_check(vfx.impact_count==0 and boss.shockwave_count==0,"Airborne tell cannot manufacture a landing impact or damaging wave")
	while boss.fsm.get_state_id()==&"stomp" and boss.state_time<0.83:
		await _step(1)
	vfx.seek_actor()
	_check(vfx.phase==&"plunge" and boss.state_time>=0.82,"Plunge marker follows the actual >=0.82 threshold")
	var landing_deadline: int=Engine.physics_ticks_per_second*2
	for tick: int in landing_deadline:
		if boss.fsm.get_state_id()==&"recover": break
		await _step(1)
	await _step(2) # Deferred visual attachment after original hazard _ready.
	_check(boss.fsm.get_state_id()==&"recover" and boss.is_on_floor() and vfx.impact_count==1,"Cracks/debris start once at a real floor landing")
	_check(boss.shockwave_count==2 and vfx.linked_wave_count==2,"Exactly the two existing landing hazards receive detailed stone visuals")
	var waves: Array[EnemyHazard]=_boss_waves()
	_check(waves.size()==2,"VFX creates no third shockwave or damage emitter")
	for wave: EnemyHazard in waves:
		var detailed: GolemGroundWaveVFX=wave.get_node("GolemGroundWaveVFX") as GolemGroundWaveVFX
		var wave_shape := wave.hitbox._query_shape as CircleShape2D
		_check(detailed!=null and detailed.wave==wave and wave.self_modulate.a==0.0,"Wave skin replaces only the old glyph and follows its actual body")
		_check(detailed.material is CanvasItemMaterial and (detailed.material as CanvasItemMaterial).blend_mode==CanvasItemMaterial.BLEND_MODE_MIX,"Moving stone crest uses normal mix, not bloom/additive coverage")
		_check(wave_shape.radius==9.0 and wave.attack.source_id==boss.get_instance_id() and wave.kind==&"wave","Original wave radius, source and attack identity remain intact")
	_check(body.shape.get_instance_id()==shape_id and body.transform==body_before and boss.health.maximum_health==500.0,"Stomp VFX preserves 76x100 collision and 500HP definition")
	var wave_age: float=(waves[0].get_node("GolemGroundWaveVFX") as GolemGroundWaveVFX).age
	var impact_age: float=vfx.impact_age
	paused=true
	await _process_steps(3)
	_check((waves[0].get_node("GolemGroundWaveVFX") as GolemGroundWaveVFX).age==wave_age and vfx.impact_age==impact_age,"Pause freezes debris and attached wave foley shapes")
	paused=false
	for tick: int in Engine.physics_ticks_per_second:
		if not resolved.is_empty(): break
		await _step(1)
	_check(not resolved.is_empty() and resolved[0]["damage"]==22.0 and resolved[0]["source"]==boss.get_instance_id(),"Live wave contact retains its original 22 damage and boss source")
	boss.ai_enabled=false

func _caps_and_scope() -> void:
	var guards: Array[BaseEnemy]=[]
	for index: int in 10:
		guards.append(_new_guard(Vector2(1200+index*25,640),false))
	_check(get_nodes_in_group(&"guard_sweep_vfx").size()==GuardSweepVFX.MAX_OWNERS,"Guard visual allocation has an eight-owner cap")
	_check(guards[9].visual.sweep_vfx==null and guards[9].visual.sprite.visible,"Over-budget guard keeps readable existing art/tell fallback")
	for item: BaseEnemy in guards: item.queue_free()
	for wave: EnemyHazard in _boss_waves(): wave.queue_free()
	await _step(3)
	var samples: Array[EnemyHazard]=[]
	for index: int in 10:
		var wave:=EnemyHazard.new()
		wave.kind=&"wave"
		wave.source_id=boss.get_instance_id()
		wave.player=hero
		wave.feedback=feedback
		wave.position=Vector2(1450+index*20,620)
		arena.add_child(wave)
		samples.append(wave)
	var foreign:=EnemyHazard.new()
	foreign.kind=&"wave"
	foreign.source_id=hero.get_instance_id()
	foreign.player=hero
	foreign.position=Vector2(1550,620)
	arena.add_child(foreign)
	var orb:=EnemyHazard.new()
	orb.source_id=boss.get_instance_id()
	orb.player=hero
	orb.position=Vector2(1550,500)
	arena.add_child(orb)
	await _step(3)
	_check(get_nodes_in_group(&"golem_ground_wave_vfx").size()==GolemGroundWaveVFX.MAX_VISUALS,"Detailed wave skins have an eight-node global cap")
	_check(samples[9].self_modulate.a==1.0 and not samples[9].has_node("GolemGroundWaveVFX"),"Over-budget hazard retains its visible original glyph")
	_check(not foreign.has_node("GolemGroundWaveVFX") and not orb.has_node("GolemGroundWaveVFX"),"Module ignores other attackers and unchanged orb/projectile paths")
	for wave: EnemyHazard in samples: wave.queue_free()
	foreign.queue_free()
	orb.queue_free()
	await _step(3)
	_check(get_nodes_in_group(&"golem_ground_wave_vfx").is_empty(),"Wave teardown releases attached nodes and caps")

func _cancel_and_teardown() -> void:
	boss.ai_enabled=true
	boss.fsm.transition_to(&"stomp")
	await _time(0.10)
	var vfx: GolemStompVFX=skin.stomp_vfx
	var impacts: int=vfx.impact_count
	var waves: int=boss.shockwave_count
	var hit: DamageEvent=_event(boss,20001,hero.get_instance_id(),1.0)
	hit.stagger_force=100.0
	boss.hurtbox.take_damage(hit)
	vfx.seek_actor()
	_check(boss.fsm.get_state_id()==&"staggered" and vfx.phase.is_empty() and vfx.impact_age==GolemStompVFX.IMPACT_SECONDS,"Accepted stagger cancels the real tell and clears its pending impact")
	await _time(0.16)
	_check(vfx.impact_count==impacts and boss.shockwave_count==waves,"Cancelled prelaunch stomp cannot emit a fake impact or new wave")
	skin.bind(boss)
	skin.bind(boss)
	_check(boss.fsm.state_changed.get_connections().size()==2,"Repeated skin binding leaves one stomp listener and one combat-pose listener")
	var wave:=EnemyHazard.new()
	wave.kind=&"wave"
	wave.source_id=boss.get_instance_id()
	wave.player=hero
	wave.position=Vector2(1400,620)
	arena.add_child(wave)
	await _step(3)
	var original: Color=Color.WHITE
	_check(wave.self_modulate.a==0.0,"Owned active wave has a detailed visual before unbind")
	skin.queue_free()
	await _step(3)
	_check(wave.self_modulate==original and not wave.has_node("GolemGroundWaveVFX"),"Skin teardown restores the still-live damaging wave's visible fallback")
	_check(boss.fsm.state_changed.get_connections().is_empty(),"Skin teardown disconnects the boss FSM listener")
	# Tear down an intact room while a skinned boss and its live wave coexist.
	var sibling_room := Node2D.new()
	root.add_child(sibling_room)
	var sibling_boss := preload("res://scenes/enemies/boss_golem.tscn").instantiate() as BossGolem
	sibling_boss.ai_enabled=false
	sibling_room.add_child(sibling_boss)
	var sibling_skin := BossGolemSkin.new()
	sibling_boss.add_child(sibling_skin)
	sibling_skin.bind(sibling_boss)
	var sibling_wave := EnemyHazard.new()
	sibling_wave.kind=&"wave"
	sibling_wave.source_id=sibling_boss.get_instance_id()
	sibling_wave.player=hero
	sibling_wave.position=Vector2(1450,620)
	sibling_room.add_child(sibling_wave)
	await _step(2)
	_check(sibling_wave.has_node("GolemGroundWaveVFX"),"Live sibling-room wave attaches before intact room teardown")
	var room_weak: WeakRef=weakref(sibling_room)
	sibling_room.queue_free()
	await _step(4)
	_check(room_weak.get_ref()==null and get_nodes_in_group(&"golem_ground_wave_vfx").is_empty(),"Intact room teardown releases boss/wave visual siblings without mutation errors")
	arena.queue_free()
	await _step(4)
	_check(get_nodes_in_group(&"guard_sweep_vfx").is_empty() and get_nodes_in_group(&"golem_ground_wave_vfx").is_empty() and get_nodes_in_group(&"enemy_hazards").is_empty(),"Room teardown releases all effect owners and original hazards")
	root.get_node("AudioManager").stop_all()

func _new_guard(at: Vector2, ai: bool) -> BaseEnemy:
	var enemy:=preload("res://scenes/enemies/ancient_guard.tscn").instantiate() as BaseEnemy
	enemy.position=at
	enemy.player=hero
	enemy.combat_feedback=feedback
	enemy.ai_enabled=ai
	arena.add_child(enemy)
	return enemy

func _boss_waves() -> Array[EnemyHazard]:
	var result: Array[EnemyHazard]=[]
	for node: Node in get_nodes_in_group(&"enemy_hazards"):
		if node is EnemyHazard and (node as EnemyHazard).source_id==boss.get_instance_id() and (node as EnemyHazard).kind==&"wave":
			result.append(node as EnemyHazard)
	return result

func _event(target: Node2D, id: int, source: int, damage: float) -> DamageEvent:
	var event:=DamageEvent.new()
	event.source_id=source
	event.target_id=target.get_instance_id()
	event.source_team_id=1 if target!=hero else 2
	event.attack_id=id
	event.root_event_id=id
	event.hit_window_id=1
	event.base_damage=damage
	return event

func _observe(event: DamageEvent, result: DamageResult) -> void:
	if not result.blocked and result.actual_damage>0:
		resolved.append({"source":event.source_id,"root":event.root_event_id,"damage":result.actual_damage,"kind":int(event.source_kind)})

func _wait_guard(state: StringName) -> void:
	for tick: int in Engine.physics_ticks_per_second*2:
		if guard.state_machine.get_state_id()==state: return
		await _step(1)
	_check(false,"Guard reaches expected existing state "+String(state))

func _time(seconds: float) -> void:
	await _step(ceili(seconds*Engine.physics_ticks_per_second))

func _step(count: int) -> void:
	for tick: int in count: await physics_frame

func _process_steps(count: int) -> void:
	for tick: int in count: await process_frame

func _check(passed: bool, message: String) -> void:
	checks+=1
	if not passed:
		failures+=1
		print("FAIL: "+message)
