extends "res://tests/runic_harrier_test.gd"
## Synthetic interaction fixture: all real owners, no gameplay/video claim.
func fresh() -> void:
	await super.fresh()
	# Standalone arena has no SlicePresentation; initialize its same adapter contract.
	var visual:=ElementAfflictionVFX.new();visual.name="ElementAfflictionVFX"
	actor.add_child(visual);visual.initialize(actor,actor.hurtbox,feedback)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	root.unfocusable=true;Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if not check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated QA root"):quit(2);return
	arena=Node2D.new();root.add_child(arena);floor_box(Vector2(1500,650),Vector2(4000,20))
	hero=preload("res://scenes/actors/player/player.tscn").instantiate();arena.add_child(hero);hero.set_physics_process(false);hero.controls_enabled=false
	feedback=CombatFeedback.new();feedback.hit_stop_seconds=0;arena.add_child(feedback)
	await fresh()
	var v: ElementAfflictionVFX=actor.get_node("ElementAfflictionVFX") as ElementAfflictionVFX
	check(v!=null,"Merged Runic has the HUD candidate elemental adapter")
	var burn: DamageEvent=damage(1);burn.burn_damage=1;burn.burn_duration=3;burn.burn_interval=.2
	actor.hurtbox.take_damage(burn)
	check(await wait_tell(),"Burning Runic reaches its real tell")
	var tells: int=actor.get("tells_cancelled")
	await seconds(.45)
	check(dot_during_tell>0 and actor.get("shots_fired")>0 and actor.get("tells_cancelled")==tells,"Actual burn ticks preserve ranged tell and release a shot with VFX present")
	v.refresh_visual();check(v.reaction_count==0,"Burn does not manufacture thermal receipt or reaction")
	await fresh();v=actor.get_node("ElementAfflictionVFX") as ElementAfflictionVFX
	check(await wait_tell(),"Ice fixture reaches real ranged tell")
	var status: ElementStatusController=actor.statuses as ElementStatusController
	for i: int in 3:
		var ice: DamageEvent=damage(1);ice.freeze_points=35;actor.hurtbox.take_damage(ice);v.refresh_visual()
		check(is_equal_approx(v.ice_progress,minf((i+1)*.35,1)),"Ice visual reads exact owner buildup on Runic")
	check(actor.get("ranged_windup")==0 and status.freeze_remaining==1.5 and v.ice_frozen,"Direct ice/freeze cancels tell and shows actual frozen window")
	var dot: DamageEvent=damage(1);dot.source_kind=DamageEvent.SourceKind.DOT
	var d: DamageResult=actor.hurtbox.take_damage(dot);v.refresh_visual()
	check(d.actual_damage==1 and d.reaction_id==&"" and status.freeze_remaining==1.5 and v.ice_frozen,"DOT damage leaves freeze setup and thermal feedback untouched")
	actor.hurtbox.set_invulnerable(true)
	var denied: DamageEvent=damage(1);denied.thermal_shock=true
	check(actor.hurtbox.take_damage(denied).blocked and status.freeze_remaining==1.5 and v.reaction_count==0,"Rejected thermal contact cannot consume setup or fake a receipt")
	actor.hurtbox.set_invulnerable(false)
	var thermal: DamageEvent=damage(1);thermal.thermal_shock=true
	var r: DamageResult=actor.hurtbox.take_damage(thermal);v.refresh_visual()
	check(r.actual_damage==3 and r.reaction_id==&"thermal_shock" and status.freeze_remaining==0,"Accepted thermal consumes actual Runic freeze exactly once")
	check(v.reaction_count==1 and v.reaction_remaining>0 and not v.ice_frozen,"Merged subscriber renders one receipt and clears frozen HUD state")
	check(actor.hurtbox.take_damage(thermal).blocked and v.reaction_count==1,"Duplicate thermal hit cannot repeat receipt")
	var hp: float=actor.health.current_health
	for i: int in 40:v.refresh_visual()
	check(actor.health.current_health==hp and v.reaction_count==1,"Presentation reads have no damage or reaction side effect")
	var plain: DamageEvent=damage(1);plain.thermal_shock=true
	var p: DamageResult=actor.hurtbox.take_damage(plain)
	check(p.actual_damage==1 and p.reaction_id==&"" and v.reaction_count==1,"Unprimed thermal after consumption cannot retrigger")
	await seconds(.8);check(v.reaction_remaining==0,"Receipt visual expires on the same actor")
	check(await wait_tell(),"Real caster resumes after genuine control expires")
	actor.hurtbox.take_damage(damage(1))
	check(actor.get("ranged_windup")==0 and actor.state_machine.get_state_id()==&"hurt","Direct contact still interrupts after DOT/freeze/thermal cycle")
	var visual_id: int=v.get_instance_id();var actor_id: int=actor.get_instance_id()
	actor.hurtbox.take_damage(damage(100));await seconds(.7)
	check(not is_instance_id_valid(actor_id) and not is_instance_id_valid(visual_id) and get_nodes_in_group(&"runic_harrier_bolts").is_empty(),"Death frees merged visual subscriber and owned ranged bolts")
	arena.queue_free();await step(5);await root.get_node("AudioManager").shutdown()
	print("RESULT CombatQuestInteraction checks=%d failures=%d hz=%d"%[checks,failures,Engine.physics_ticks_per_second]);quit(0 if failures==0 else 1)
