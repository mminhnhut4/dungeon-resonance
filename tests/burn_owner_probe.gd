extends "res://tests/survival_test_base.gd"
## Isolated status/lifetime fixture. Never a natural-play or FPS claim.
var trace: Array[Dictionary] = []
var cycle_id: int = 0
var phase_start: int = 0
var cpu_expected: bool = false

func _init() -> void:
	suite = "burn_owner"
	use_neutral_equipment = false

func _initialize() -> void:
	root.unfocusable = true
	root.current_screen = mini(1, DisplayServer.get_screen_count() - 1) if DisplayServer.get_name() != "headless" else 0
	root.size = Vector2i(1152,648)
	Engine.max_fps = 120
	AudioServer.set_bus_mute(0,true)
	super._initialize()

func _contact(event: DamageEvent, result: DamageResult) -> void:
	trace.append({"cycle":cycle_id,"tick":Engine.get_physics_frames()-phase_start,"kind":event.source_kind,"base":event.base_damage,"actual":result.actual_damage,"blocked":result.blocked,"resonance":event.allow_resonance})

func test_system() -> void:
	var visual: ElementAfflictionVFX = player.get_node("ElementAfflictionVFX") as ElementAfflictionVFX
	var status: StatusController = player.hurtbox.damage_resolver.status_controller
	var cpu: CPUParticles2D = visual.get_node_or_null("BurnEmbersCompatibility") as CPUParticles2D
	cpu_expected = CompatibilityParticleBurst.supported() and not "--baseline" in OS.get_cmdline_user_args()
	_check((cpu != null) == cpu_expected,"Backend selection is native Compatibility only; baseline/headless retain original nodes")
	_check(visual.burn.amount==9 and visual.burn.lifetime==0.8 and visual.burn.fixed_fps==60 and not visual.burn.local_coords,"Authored burn stays nine world-space particles,0.8s lifetime,60Hz simulation")
	_check(visual.poison.amount==7 and visual.get_node_or_null("PoisonWispsCompatibility")==null,"Poison backend and seven-particle budget remain unchanged")
	if cpu != null:
		var material: ParticleProcessMaterial = visual.burn.process_material as ParticleProcessMaterial
		_check(cpu.amount==9 and cpu.lifetime==visual.burn.lifetime and cpu.fixed_fps==visual.burn.fixed_fps and cpu.local_coords==visual.burn.local_coords,"CPU conversion preserves amount/lifetime/fixed rate/world coordinates")
		_check(cpu.texture==visual.burn.texture and cpu.material==visual.burn.material and cpu.transform==visual.burn.transform,"CPU conversion preserves authored stamp/additive material/anchor")
		_check(cpu.color==material.color and cpu.color_ramp==(material.color_ramp as GradientTexture1D).gradient,"CPU keeps tint and all authored alpha-gradient stops")
		_check(cpu.direction==Vector2(material.direction.x,material.direction.y) and cpu.gravity==Vector2.ZERO and cpu.spread==material.spread,"CPU keeps authored direction/spread/no gravity")
		_check(cpu.initial_velocity_min==material.initial_velocity_min and cpu.initial_velocity_max==material.initial_velocity_max and cpu.scale_amount_min==material.scale_min and cpu.scale_amount_max==material.scale_max,"CPU keeps speed and flame size range")
		_check(cpu.emission_shape==CPUParticles2D.EMISSION_SHAPE_RECTANGLE and cpu.emission_rect_extents==Vector2(11,16),"CPU conversion preserves the actor-local11×16 emission box")
	var initial_children: int = visual.get_child_count()
	var burn_id: int = visual.burn.get_instance_id()
	var cpu_id: int = cpu.get_instance_id() if cpu != null else 0
	player.hurtbox.hit_resolved.connect(_contact)
	for repeat: int in 6:
		cycle_id=repeat;phase_start=Engine.get_physics_frames()
		var fire: DamageEvent = _damage(player.hurtbox,1.0)
		fire.burn_damage=0.75;fire.burn_duration=0.45;fire.burn_interval=0.15
		player.hurtbox.set_invulnerable(false);player.damage_grace_remaining=0.0
		var result: DamageResult = player.hurtbox.take_damage(fire)
		visual.refresh_visual()
		_check(not result.blocked and visual.burn_visible and status.burn_remaining>0.0,"Accepted real Hurtbox damage activates burn on each re-trigger")
		_check(visual.burn.emitting==(DisplayServer.get_name()!="headless" and cpu==null),"Exactly one burn backend emits; GPU source stays inactive on CPU path")
		if cpu != null:_check(cpu.emitting and cpu.visible and not visual.burn.visible,"Re-trigger shows live CPU flames rather than hiding the effect")
		var hp: float=player.health.current_health
		var clock: float=status.burn_remaining
		var tick: float=status._burn_tick
		for _i: int in 120:visual.refresh_visual()
		_check(player.health.current_health==hp and status.burn_remaining==clock and status._burn_tick==tick,"Repeated presentation refresh never applies damage or advances authoritative clocks")
		await _step(3)
		var global_freeze: bool=level.combat_feedback.global_hitstop_enabled
		if global_freeze:
			level.combat_feedback.hitstop_manager.regular_seconds=0.25
			level.combat_feedback.hitstop_manager.request_hitstop()
		else:
			level.combat_feedback.set_physics_process(false)
			level.combat_feedback._frozen_this_tick=true
		visual.refresh_visual();hp=player.health.current_health;clock=status.burn_remaining
		_check(visual.burn.speed_scale==0.0 and (cpu==null or cpu.speed_scale==0.0),"Source and CPU simulation freeze on original feedback clock")
		if global_freeze:
			for _i: int in 3:await process_frame
		else:await _step(4)
		_check(player.health.current_health==hp and status.burn_remaining==clock,"While the original feedback clock is frozen neither DOT nor burn clock advance")
		if global_freeze:
			while level.combat_feedback.hitstop_manager.is_active():await process_frame
		else:level.combat_feedback.reset_feedback();level.combat_feedback.set_physics_process(true)
		visual.refresh_visual()
		_check(visual.burn.speed_scale==1.0 and (cpu==null or cpu.speed_scale==1.0),"Burn resumes on the same feedback release")
		await _time(0.65)
		visual.refresh_visual()
		_check(not visual.burn_visible and not visual.burn.emitting and (cpu==null or not cpu.emitting and not cpu.visible),"Actual finite status expiry stops and hides the active backend")
		_check(visual.get_child_count()==initial_children and visual.burn.get_instance_id()==burn_id and (cpu==null or cpu.get_instance_id()==cpu_id),"Six on/off cycles reuse emitter identities without pool growth")
	trace.append({"final_hp":player.health.current_health,"final_burn":status.burn_remaining})
	var f:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("behavior.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"physics_hz":Engine.physics_ticks_per_second,"cpu":cpu!=null,"trace":trace},"\t"));f.close()
	var fatal: DamageEvent=_damage(player.hurtbox,1.0);fatal.burn_damage=1.0;fatal.burn_duration=1.0
	status.apply(fatal);visual.refresh_visual();player.health.apply_damage(999.0);visual.refresh_visual()
	_check(not visual.burn_visible and (cpu==null or not cpu.emitting and not cpu.visible),"Actor death cancels burn immediately without waiting for particle lifetime")
	var ids: Array[int]=[player.get_instance_id(),visual.get_instance_id(),burn_id]
	if cpu_id>0:ids.append(cpu_id)
	level.queue_free();level=null;await _step(5)
	_check(ids.all(func(id: int)->bool:return not is_instance_id_valid(id)),"Owner teardown frees source and CPU emitter, without orphan retention")
