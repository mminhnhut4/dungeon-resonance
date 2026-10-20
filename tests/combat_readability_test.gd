extends "res://tests/survival_test_base.gd"
## Explicit isolated fixture; never a naturally earned gameplay/FPS claim.
var trace: Array[Dictionary] = []
var evidence: String
var baseline: bool

func _init() -> void:
	suite="combat_readability";use_neutral_equipment=false
func _initialize() -> void:
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	super._initialize()
func has_property(object: Object, key: StringName) -> bool:
	for entry: Dictionary in object.get_property_list():
		if entry["name"]==key:return true
	return false
func test_system() -> void:
	baseline="--baseline" in OS.get_cmdline_user_args();evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	session.set_enabled(false)
	var enemy: SlimeEnemy=level.enemies[0]
	enemy.global_position=Vector2(900,640);enemy.motor.reset_motion()
	enemy.health.maximum_health=200;enemy.health.reset_health()
	var status: ElementStatusController=enemy.statuses as ElementStatusController
	var visual: ElementAfflictionVFX=enemy.get_node("ElementAfflictionVFX") as ElementAfflictionVFX
	var ice_feedback_present: bool=has_property(visual,&"ice_progress")
	_check(status!=null and visual!=null,"Existing live enemy has shared elemental owner and presentation adapter")
	for n: int in 3:
		var ice: DamageEvent=_damage(enemy.hurtbox,1);ice.freeze_points=35;ice.spell_id=&"ice_bolt"
		var r: DamageResult=enemy.hurtbox.take_damage(ice);visual.refresh_visual()
		trace.append({"kind":"ice","amount":r.actual_damage,"meter":status.freeze_meter,"frozen":status.freeze_remaining,"hp":enemy.health.current_health})
		_check(not r.blocked and status.freeze_meter==minf((n+1)*35,100),"Accepted ice contact builds the original35-point freeze meter")
	_check(status.freeze_remaining==1.5 and status.stun_remaining>=1.5,"Third original ice hit opens the authored1.5s freeze window")
	if not baseline:
		_check(visual.get("ice_progress")==1.0 and visual.get("ice_frozen")==true,"Presentation exposes setup completion from the actual owner")
	if DisplayServer.get_name()!="headless":
		await process_frame;await process_frame
		get_root().get_texture().get_image().save_png(evidence.path_join("frozen-fixture.png"))
	var shock: DamageEvent=_damage(enemy.hurtbox,20);shock.thermal_shock=true;shock.spell_id=&"thermal_shock"
	var result: DamageResult=enemy.hurtbox.take_damage(shock)
	visual.refresh_visual()
	trace.append({"kind":"thermal","amount":result.actual_damage,"meter":status.freeze_meter,"frozen":status.freeze_remaining,"hp":enemy.health.current_health})
	_check(result.actual_damage==60 and status.freeze_remaining==0 and status.freeze_meter==0,"Existing thermal hit consumes freeze once for60, preserving original3x rule")
	if not baseline:
		_check(result.get("reaction_id")==&"thermal_shock" and visual.get("reaction_remaining")>0,"Only the accepted consuming hit yields an authoritative thermal reaction receipt")
	if DisplayServer.get_name()!="headless":
		await process_frame;await process_frame
		get_root().get_texture().get_image().save_png(evidence.path_join("thermal-fixture.png"))
	var repeat_hit: DamageEvent=_damage(enemy.hurtbox,20);repeat_hit.thermal_shock=true
	var repeat_result: DamageResult=enemy.hurtbox.take_damage(repeat_hit)
	trace.append({"kind":"repeat","amount":repeat_result.actual_damage,"meter":status.freeze_meter,"frozen":status.freeze_remaining,"hp":enemy.health.current_health})
	_check(repeat_result.actual_damage==20,"Repeated thermal without a new freeze cannot repeat the3x trigger")
	var duplicate: DamageResult=enemy.hurtbox.take_damage(repeat_hit)
	_check(duplicate.blocked and duplicate.actual_damage==0,"Duplicate contact remains rejected by the same damage pipeline")
	if not baseline:_check(repeat_result.get("reaction_id")==&"" and duplicate.get("reaction_id")==&"","Unprimed/duplicate contacts cannot manufacture combo reactions")
	var hud: ArtHUD=level.presentation.art_hud
	var controller: ResonanceController=player.resonance_controller
	controller.catalyst_a.install_runes([load("res://data/runes/IceRune.tres"),load("res://data/runes/FireRune.tres")])
	controller.loadout_state.cooldowns_by_recipe_id[&"thermal_shock"]=0.8
	player.energy.current=10;hud.refresh_hud()
	var has_readiness: bool=has_property(hud,&"spell_status") and has_property(hud,&"dash_status")
	if not baseline:
		_check(has_readiness,"Essential combat readiness is in the product HUD, independent of debug")
		_check((hud.get("spell_status") as Label).text.contains("0.8"),"HUD reads actual recipe cooldown before energy shortage")
		_check((hud.get("combo_hint") as Label).visible and (hud.get("combo_hint") as Label).text.contains("đóng băng"),"Selected existing thermal recipe exposes its setup-consume decision")
		controller.loadout_state.cooldowns_by_recipe_id[&"thermal_shock"]=0;hud.refresh_hud()
		_check((hud.get("spell_status") as Label).text.contains("30") and (hud.get("dash_status") as Label).text.contains("25"),"Spell/dash report their actual shared-energy requirements")
		player.energy.current=100;player.motor.dash_cooldown_remaining=0.4;hud.refresh_hud()
		_check((hud.get("dash_status") as Label).text.contains("0.4"),"Dash readiness follows its actual cooldown")
		player.motor.dash_cooldown_remaining=0.01;hud.refresh_hud()
		_check((hud.get("dash_status") as Label).text.contains("0.1"),"Last cooldown fraction never misleadingly displays zero while blocked")
		player.controls_enabled=false;player.motor.dash_cooldown_remaining=0;hud.refresh_hud()
		_check((hud.get("spell_status") as Label).text.contains("mở bảng") and (hud.get("dash_status") as Label).text.contains("mở bảng"),"Modal control lock does not advertise available inputs")
		player.controls_enabled=true
		var hp: float=enemy.health.current_health;var energy: float=player.energy.current;var meter: float=status.freeze_meter
		for n: int in 80:visual.refresh_visual();hud.refresh_hud()
		_check(enemy.health.current_health==hp and player.energy.current==energy and status.freeze_meter==meter,"Repeated presentation samples cannot advance clocks, consume energy or deal damage")
		await _time(0.7)
		_check(visual.get("reaction_remaining")==0,"Actor-owned thermal reaction expires without adding a spell entity")
		var child_count: int=visual.get_child_count()
		var visual_id: int=visual.get_instance_id()
		for cycle: int in 4:
			status.clear()
			for i: int in 3:
				var build: DamageEvent=_damage(enemy.hurtbox,1);build.freeze_points=35
				enemy.hurtbox.take_damage(build)
			enemy.hurtbox.set_invulnerable(true)
			var blocked: DamageEvent=_damage(enemy.hurtbox,1);blocked.thermal_shock=true
			var count_before: int=int(visual.get("reaction_count"))
			var denied: DamageResult=enemy.hurtbox.take_damage(blocked)
			_check(denied.blocked and denied.reaction_id==&"" and status.freeze_remaining==1.5 and int(visual.get("reaction_count"))==count_before,"Invulnerable contact preserves setup and cannot emit a fake thermal cue")
			enemy.hurtbox.set_invulnerable(false)
			var accepted: DamageEvent=_damage(enemy.hurtbox,1);accepted.thermal_shock=true
			enemy.hurtbox.take_damage(accepted)
			_check(int(visual.get("reaction_count"))==count_before+1 and visual.get_child_count()==child_count,"Repeated setup/consume reuses actor-owned visuals with exactly one cue")
		status.clear();visual.refresh_visual()
		_check(visual.get("ice_progress")==0 and not visual.get("ice_frozen"),"Clear/death reset cannot retain a frozen setup display")
		enemy.queue_free();await _step(3)
		_check(not is_instance_id_valid(visual_id),"Freeing the actor frees its receipt subscriber and visual state")
	var f:=FileAccess.open(evidence.path_join("combat-readability.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"baseline":baseline,"physics_hz":Engine.physics_ticks_per_second,"trace":trace,"readiness_present":has_readiness,"ice_feedback_present":ice_feedback_present,"scope":"Isolated synthetic owner fixture; HP200 is fixture only. Native product video is separate."},"\t"));f.close()
