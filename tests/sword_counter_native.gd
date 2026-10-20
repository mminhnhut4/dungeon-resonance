extends "res://tests/opening_tactics_native.gd"
## Frozen input-only late-dash counter; --expect-buffer changes analysis only.
const REACTION_SECONDS: float = 0.42
const TAP_SECONDS: float = 0.12
const RESOLVE_SECONDS: float = 0.80
const MAX_CYCLES: int = 3
class CounterBot:
	extends CombatBot
	var harness
	var clock_s: float = 0.0
	func pulse(id: StringName) -> void:
		action(id,true)
		releases.append(id)
	func move(direction: float) -> void:
		action(&"move_left",direction<0.0)
		action(&"move_right",direction>0.0)
	func _physics_process(delta: float) -> void:
		for id: StringName in releases: action(id,false)
		releases.clear()
		if not enabled or not is_instance_valid(run): return
		tick+=1
		if not run.feedback.is_frozen(): clock_s+=delta
		harness.counter_tick()

var counter_target: BaseEnemy
var counter_cycles: Array[Dictionary] = []
var counter_events: Array[Dictionary] = []
var counter_samples: Array[Dictionary] = []
var counter_cycle: Dictionary = {}
var counter_before: Dictionary = {}
var counter_phase: String = "approach"
var counter_done: String = ""
var expect_buffer: bool = false
var _last_weapon_phase: int = -1
var _last_player_box: bool = false
var _last_guard_box: bool = false
var _pending_pictures: int = 0
var pictures: Array[Dictionary] = []

func counter_clock() -> float:
	return (bot as CounterBot).clock_s if is_instance_valid(bot) else 0.0

func counter_event(kind: String, extra: Dictionary = {}) -> Dictionary:
	var row: Dictionary = {"event":kind,"physics_frame":Engine.get_physics_frames(),"usec":Time.get_ticks_usec(),"game_s":counter_clock(),"cycle":counter_cycles.size()}
	row.merge(extra,true)
	counter_events.append(row)
	return row

func counter_picture(label: String) -> void:
	_pending_pictures+=1
	var request: Dictionary = counter_event("picture_requested",{"label":label}).duplicate(true)
	_capture_counter.call_deferred(label,request)

func _capture_counter(label: String, request: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var path: String = evidence.path_join(label+".png")
	var error: Error = root.get_texture().get_image().save_png(path)
	_check(error==OK,"Native counter screenshot saved: "+label)
	request.merge({"path":path,"save_error":error,"capture_physics_frame":Engine.get_physics_frames(),"capture_usec":Time.get_ticks_usec()},true)
	pictures.append(request)
	_pending_pictures-=1

func visible_counter_cue() -> bool:
	if not is_instance_valid(counter_target) or counter_target.health.current_health<=0.0: return false
	if counter_target.state_machine.get_state_id()!=&"telegraph" or not counter_target.visual.is_visible_in_tree(): return false
	if counter_target.global_position.distance_to(campaign.player.global_position)>=170.0: return false
	var screen_point: Vector2 = counter_target.get_global_transform_with_canvas()*Vector2(0,-26)
	if not root.get_visible_rect().has_point(screen_point): return false
	return counter_target._target_path_clear()

func counter_tick() -> void:
	var driver: CounterBot = bot as CounterBot
	if not is_instance_valid(campaign) or not is_instance_valid(counter_target): counter_done="target_unavailable"; return
	var actor: Player = campaign.player
	var weapon: Weapon = actor.equipped_weapon
	var row: Dictionary = {"physics_frame":Engine.get_physics_frames(),"usec":Time.get_ticks_usec(),"game_s":counter_clock(),"phase":counter_phase,"frozen":campaign.feedback.is_frozen(),"player_x":actor.global_position.x,"player_y":actor.global_position.y,"player_v":actor.velocity,"hp":actor.health.current_health,"mana":actor.energy.current,"action":String(actor.action_state_machine.get_state_id()),"dash":actor.motor.is_dashing,"dash_remaining":actor.motor.dash_remaining,"iframe_remaining":actor.motor.invulnerability_remaining,"damage_grace":actor.damage_grace_remaining,"weapon_phase":weapon.phase,"weapon_remaining":weapon._phase_remaining,"weapon_duration":weapon._phase_duration,"weapon_hitbox":weapon.hitbox.active,"guard_id":counter_target.get_instance_id(),"guard_x":counter_target.global_position.x,"guard_y":counter_target.global_position.y,"guard_v":counter_target.velocity,"guard_hp":counter_target.health.current_health,"guard_state":String(counter_target.state_machine.get_state_id()),"guard_time":counter_target.state_time,"guard_facing":counter_target.facing,"guard_locked_direction":counter_target.locked_direction,"guard_hitbox":counter_target.attack_hitbox.active}
	row.merge({"weapon_attack_id":weapon.hitbox.attack_snapshot.attack_id if weapon.hitbox.attack_snapshot!=null else 0,"guard_attack_id":counter_target.attack_hitbox.attack_snapshot.attack_id if counter_target.attack_hitbox.attack_snapshot!=null else 0,"guard_attack_rate":counter_target.attack_rate_multiplier,"guard_status_attack_speed":counter_target.statuses.attack_speed_multiplier,"motor_invulnerable":actor.motor.is_invulnerable(),"hurtbox_invulnerable":actor.hurtbox.invulnerable},true)
	counter_samples.append(row)
	if weapon.phase!=_last_weapon_phase or weapon.hitbox.active!=_last_player_box or counter_target.attack_hitbox.active!=_last_guard_box:
		counter_event("phase_or_hitbox",row.duplicate(true))
		_last_weapon_phase=weapon.phase; _last_player_box=weapon.hitbox.active; _last_guard_box=counter_target.attack_hitbox.active
	if actor.health.current_health<=0.0 or campaign.outcome==&"defeat": counter_done="player_defeat"; driver.stop(); return
	if counter_target.health.current_health<=0.0: counter_done="target_dead"; driver.stop(); return
	if counter_clock()>=45.0: counter_done="gameplay_timeout"; driver.stop(); return
	if campaign.feedback.is_frozen() or not actor.controls_enabled: return
	var aim_event := InputEventMouseMotion.new()
	aim_event.position=counter_target.get_global_transform_with_canvas()*Vector2(0,-26)
	root.push_input(aim_event,true)
	if not counter_cycle.is_empty() and counter_cycle.get("dash_accepted",false):
		if (actor.global_position.x-counter_target.global_position.x)*float(counter_cycle["facing"])<0.0:
			if not counter_cycle["crossed_behind"]: counter_event("crossed_behind",{"guard_id":counter_target.get_instance_id()})
			counter_cycle["crossed_behind"]=true
	match counter_phase:
		"approach":
			var difference: float = counter_target.global_position.x-actor.global_position.x
			driver.move(signf(difference) if absf(difference)>70.0 else 0.0)
			if visible_counter_cue():
				driver.move(0.0)
				counter_cycle={"index":counter_cycles.size()+1,"cue_s":counter_clock(),"guard_id":counter_target.get_instance_id(),"facing":counter_target.facing,"cue_guard_time":counter_target.state_time,"cue_player_x":actor.global_position.x,"cue_guard_x":counter_target.global_position.x,"began_in_front":(actor.global_position.x-counter_target.global_position.x)*counter_target.facing>0.0,"dash_requested":false,"dash_request_grounded":false,"dash_accepted":false,"dash_accepted_grounded":false,"dash_normal_exit":false,"tap":false,"late_tap":false,"crossed_behind":false,"commit_ids":[],"commit_during_dash":false,"recovery_hit":false,"recovery_hit_after_cross":false}
				counter_cycles.append(counter_cycle)
				counter_event("visible_tell",counter_cycle.duplicate(true))
				counter_picture("cycle%d-tell"%counter_cycles.size())
				counter_phase="cue_wait"
		"cue_wait":
			driver.move(0.0)
			if counter_clock()-float(counter_cycle["cue_s"])>=REACTION_SECONDS:
				driver.move(-float(counter_cycle["facing"]))
				counter_cycle["dash_requested"]=true; counter_cycle["dash_request_s"]=counter_clock()
				counter_cycle["dash_request_grounded"]=actor.motor.is_grounded()
				counter_event("dash_request",{"direction":-float(counter_cycle["facing"]),"guard_id":counter_target.get_instance_id(),"grounded":actor.motor.is_grounded(),"can_dash":actor.motor.can_dash(),"mana":actor.energy.current,"action":String(actor.action_state_machine.get_state_id())})
				driver.pulse(&"dash")
				counter_phase="dash_wait"
		"dash_wait":
			if not actor.motor.is_dashing: driver.move(0.0)
			if counter_cycle["dash_accepted"] and not counter_cycle["tap"] and counter_clock()-float(counter_cycle["dash_s"])>=TAP_SECONDS:
				counter_cycle["tap"]=true; counter_cycle["tap_s"]=counter_clock()
				counter_cycle["late_tap"]=actor.motor.is_dashing and actor.motor.dash_remaining>0.0
				counter_event("attack_tap",{"guard_id":counter_target.get_instance_id(),"since_accepted_dash":counter_clock()-float(counter_cycle["dash_s"]),"dash_remaining":actor.motor.dash_remaining,"action":String(actor.action_state_machine.get_state_id()),"late_tap":counter_cycle["late_tap"]})
				driver.pulse(&"attack")
				counter_phase="resolve"
			elif not counter_cycle["dash_accepted"] and counter_clock()-float(counter_cycle["dash_request_s"])>=RESOLVE_SECONDS:
				counter_event("dash_not_accepted")
				resolve_counter_cycle()
		"resolve":
			if not actor.motor.is_dashing: driver.move(0.0)
			if counter_clock()-float(counter_cycle["tap_s"])>=RESOLVE_SECONDS: resolve_counter_cycle()

func resolve_counter_cycle() -> void:
	counter_event("cycle_resolved",counter_cycle.duplicate(true))
	(bot as CounterBot).move(0.0)
	if counter_cycles.size()>=MAX_CYCLES:
		counter_done="cycle_limit"
		bot.stop()
	else:
		counter_cycle={}
		counter_phase="approach"

func player_changed(previous: StringName,next: StringName) -> void:
	counter_event("player_action",{"from":String(previous),"to":String(next),"motor_dash":campaign.player.motor.is_dashing,"dash_remaining":campaign.player.motor.dash_remaining,"mana":campaign.player.energy.current})
	if next==&"dash" and not counter_cycle.is_empty() and counter_cycle["dash_requested"] and not counter_cycle["dash_accepted"]:
		counter_cycle["dash_accepted"]=true; counter_cycle["dash_s"]=counter_clock()
		counter_cycle["dash_accepted_grounded"]=campaign.player.motor.is_grounded()
		counter_event("dash_accepted",{"guard_id":counter_target.get_instance_id(),"dash_remaining":campaign.player.motor.dash_remaining,"mana":campaign.player.energy.current})
	if previous==&"dash":
		(bot as CounterBot).move(0.0)
		if not counter_cycle.is_empty():
			counter_cycle["dash_normal_exit"]=counter_cycle["dash_accepted"] and next in [&"ready",&"attack"] and not campaign.player.is_on_wall() and counter_clock()-float(counter_cycle["dash_s"])>=campaign.player.motor.dash_duration-0.001
			counter_cycle["dash_exit_s"]=counter_clock()
		counter_event("dash_exit",{"to":String(next),"wall":campaign.player.is_on_wall()})
		counter_picture("cycle%d-dash-end"%counter_cycles.size())

func counter_weapon_commit(attack: AttackSnapshot) -> void:
	var during_dash: bool = campaign.player.motor.is_dashing
	if not counter_cycle.is_empty():
		counter_cycle["commit_ids"].append(attack.attack_id)
		counter_cycle["commit_during_dash"]=counter_cycle["commit_during_dash"] or during_dash
	counter_event("weapon_commit",{"attack_id":attack.attack_id,"root_event_id":attack.root_event_id,"guard_id":counter_target.get_instance_id(),"motor_dash":during_dash,"phase":campaign.player.equipped_weapon.phase,"authored_phase_duration":campaign.player.equipped_weapon._phase_duration,"attack_direction":attack.attack_direction,"attack_origin":attack.attack_origin,"aim_position":attack.aim_position})
	counter_picture("cycle%d-attack%d"%[counter_cycles.size(),attack.attack_id])

func changed(previous: StringName,next: StringName,enemy: Node2D) -> void:
	super.changed(previous,next,enemy)
	counter_event("enemy_state",{"id":enemy.get_instance_id(),"from":String(previous),"to":String(next),"state_time":enemy.state_time if enemy is BaseEnemy else -1.0,"facing":enemy.facing if enemy is BaseEnemy else 0.0})

func before_hit(event: DamageEvent,target: Node2D) -> void:
	super.before_hit(event,target)
	var key: String = "%d:%d:%d:%d"%[event.source_id,event.attack_id,event.hit_window_id,event.target_id]
	counter_before[key]={"state":String(target.state_machine.get_state_id()),"hp":target.health.current_health,"physics_frame":Engine.get_physics_frames(),"game_s":counter_clock()}

func after_hit(event: DamageEvent,result: DamageResult,target: Node2D) -> void:
	var key: String = "%d:%d:%d:%d"%[event.source_id,event.attack_id,event.hit_window_id,event.target_id]
	var before: Dictionary = counter_before.get(key,{})
	super.after_hit(event,result,target)
	counter_event("enemy_hit",{"source_id":event.source_id,"target_id":target.get_instance_id(),"attack_id":event.attack_id,"root_event_id":event.root_event_id,"parent_event_id":event.parent_event_id,"window":event.hit_window_id,"kind":event.source_kind,"spell":String(event.spell_id),"physical":event.physical_damage,"damage":result.actual_damage,"blocked":result.blocked,"block_reason":String(result.block_reason),"killed":result.killed,"before":before,"after_state":String(target.state_machine.get_state_id()),"hp":target.health.current_health})
	if not counter_cycle.is_empty() and target==counter_target and event.source_id==campaign.player.get_instance_id() and event.source_kind==DamageEvent.SourceKind.DIRECT and event.physical_damage and event.spell_id==&"" and event.attack_id in counter_cycle["commit_ids"] and before.get("state","")=="recover" and not result.blocked and not result.killed and result.actual_damage>0.0:
		var first_recovery_hit: bool = not counter_cycle["recovery_hit"]
		counter_cycle["recovery_hit"]=true
		var behind_at_hit: bool = (campaign.player.global_position.x-counter_target.global_position.x)*float(counter_cycle["facing"])<0.0
		counter_cycle["recovery_hit_after_cross"]=counter_cycle["recovery_hit_after_cross"] or behind_at_hit
		counter_event("same_guard_recovery_hit",{"attack_id":event.attack_id,"crossed_behind":counter_cycle["crossed_behind"],"behind_at_hit":behind_at_hit,"damage":result.actual_damage})
		if first_recovery_hit: counter_picture("cycle%d-recovery-hit-after-contact"%counter_cycles.size())
	counter_before.erase(key)

func player_hit(event: DamageEvent,result: DamageResult) -> void:
	counter_event("player_hit",{"source_id":event.source_id,"target_id":event.target_id,"attack_id":event.attack_id,"root_event_id":event.root_event_id,"parent_event_id":event.parent_event_id,"window":event.hit_window_id,"kind":event.source_kind,"spell":String(event.spell_id),"damage":result.actual_damage,"blocked":result.blocked,"block_reason":String(result.block_reason),"killed":result.killed,"hp":campaign.player.health.current_health,"motor_dash":campaign.player.motor.is_dashing,"iframe_remaining":campaign.player.motor.invulnerability_remaining,"damage_grace":campaign.player.damage_grace_remaining})

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--expect-buffer="): expect_buffer=arg.get_slice("=",1)=="true"
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	native=DisplayServer.get_name()!="headless"
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or not native or not "--native-approved" in OS.get_cmdline_user_args(): quit(2); return
	root.unfocusable=true; root.current_screen=mini(1,DisplayServer.get_screen_count()-1); root.size=Vector2i(1152,648)
	Engine.max_fps=60; Engine.physics_ticks_per_second=60; AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT"); profile_path="user://newcomer-item1/profile.json"; start_usec=Time.get_ticks_usec()
	seed_value=137
	if not _check(not evidence.is_empty() and not OS.get_environment("COMMON_PAIR_SOURCE").is_empty() and FileAccess.get_sha256(profile_path)==OS.get_environment("MINE_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("MINE_SOURCE_NPC"),"Exact earned pair QA source and native evidence root are required"): quit(2); return
	node_added.connect(born)
	bot=CounterBot.new(); (bot as CounterBot).harness=self; root.add_child(bot)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate(); flow.save_path_override=profile_path; root.add_child(flow); current_scene=flow
	await _step(30)
	var home: ExteriorHub = flow.active_scene as ExteriorHub
	if not _check(home!=null and not flow.qa_tools_enabled,"Normal earned hub without QA grants"): await finish_counter(false); return
	if not await _walk(home.player,home.stations[&"portal"].global_position.x): await finish_counter(false); return
	await _key(KEY_E); await _step(8); campaign=flow.active_scene as WorldCampaign
	if not _check(campaign!=null and campaign.stage==1 and campaign.living_enemies().size()==4,"Ordinary portal enters four unchanged actors"): await finish_counter(false); return
	initial=snapshot()
	var common: bool = true
	for item: Dictionary in initial["items"]: common=common and item["quality"]==0 and item["affix"]=="" and item["drop_bonus"]==0
	var inv: GearInventory = campaign.gear.inventory
	var exact: bool = inv.equipped_weapon_uid==1 and inv.items[1].enhancement_level==1 and inv.slot_uids[0]==113 and inv.slot_uids[1]==496 and initial["recipe"]=="overload"
	var untouched: bool = true
	for enemy: Node2D in campaign.living_enemies():
		var role: String = String(enemy.definition.id) if enemy is BaseEnemy else "runic_slime"
		untouched=untouched and enemy.health.current_health=={"ancient_guard":90,"bloodwing_bat":70,"runic_slime":60}[role] and enemy.state_machine.get_state_id() not in [&"telegraph",&"attack",&"hurt",&"recover"]
		if enemy is BaseEnemy and enemy.enemy_type==&"ancient_guard" and (counter_target==null or enemy.global_position.x<counter_target.global_position.x): counter_target=enemy
	if not _check(common and exact and untouched and attack_counts.is_empty() and initial["hp"]==115 and initial["armor"]==11 and initial["mana"]==100 and counter_target!=null,"Chosen earned Common+1 pair, HP115 armor11 mana100, untouched opening"): await finish_counter(false); return
	campaign.player.equipped_weapon.critical_rng.seed=seed_value*101+3
	campaign.player.resonance_controller.quality_rng.seed=seed_value*101+7
	campaign.player.hurtbox.hit_resolved.connect(player_hit)
	campaign.player.action_state_machine.state_changed.connect(player_changed)
	campaign.player.equipped_weapon.attack_committed.connect(counter_weapon_commit)
	initial["counter_guard_id"]=counter_target.get_instance_id()
	initial["critical_rng_state"]=campaign.player.equipped_weapon.critical_rng.state
	initial["quality_rng_state"]=campaign.player.resonance_controller.quality_rng.state
	combat_start=Time.get_ticks_usec(); bot.run=campaign; bot.enabled=true
	for _index: int in 60*45:
		if not counter_done.is_empty(): break
		await _step(1)
	if counter_done.is_empty(): counter_done="observation_limit"
	bot.stop(); combat_end=Time.get_ticks_usec()
	await finish_counter(true)

func finish_counter(valid: bool) -> void:
	if is_instance_valid(bot): bot.stop()
	for _index: int in 4:
		if _pending_pictures==0: break
		await _step(1)
	var lost_taps: int = 0
	var witnesses: int = 0
	for cycle: Dictionary in counter_cycles:
		var ground_dash: bool = cycle["dash_request_grounded"] and cycle["dash_accepted_grounded"] and cycle["dash_normal_exit"]
		if cycle["late_tap"] and ground_dash and cycle["commit_ids"].is_empty(): lost_taps+=1
		if cycle["late_tap"] and ground_dash and cycle["began_in_front"] and cycle["commit_ids"].size()==1 and not cycle["commit_during_dash"] and cycle["recovery_hit_after_cross"]: witnesses+=1
	var expectation_met: bool = witnesses>0 if expect_buffer else lost_taps>0
	var result: Dictionary = {"valid":valid and failures==0,"checks":checks,"failures":failures,"expect_buffer":expect_buffer,"expectation_met":expectation_met,"status":"WITNESS_RECORDED" if expectation_met and valid and failures==0 else "HOLD_MISSING_WITNESS","seed":137,"reaction_seconds":REACTION_SECONDS,"tap_after_accepted_dash_seconds":TAP_SECONDS,"initial":initial,"cycles":counter_cycles,"events":counter_events,"physics_samples":counter_samples,"pictures":pictures,"lost_late_taps":lost_taps,"recovery_counter_witnesses":witnesses,"terminal_reason":counter_done,"combat_start_usec":combat_start,"combat_end_usec":combat_end,"source_profile_sha256":OS.get_environment("MINE_SOURCE_PROFILE"),"source_npc_sha256":OS.get_environment("MINE_SOURCE_NPC"),"scope":"Identical frozen state-aware visible-cue input policy on earned Common+1 TrucCo-history QA; no casts/grants/warps/HP/state edits. Expected-buffer flag is analysis only. Missing witness remains HOLD; not novice playtest/balance/crash proof."}
	if is_instance_valid(campaign): result["final"]=snapshot()
	var file := FileAccess.open(evidence.path_join("sword-counter-native.json"),FileAccess.WRITE)
	if file!=null: file.store_string(JSON.stringify(result,"\t")); file.close()
	else: _check(false,"Counter receipt is writable")
	if node_added.is_connected(born): node_added.disconnect(born)
	counter_target=null; counter_before.clear()
	if is_instance_valid(bot):
		(bot as CounterBot).harness=null; bot.run=null; bot.queue_free()
	if is_instance_valid(flow): flow.queue_free()
	current_scene=null; campaign=null
	await _step(8)
	await root.get_node("AudioManager").shutdown()
	print("RESULT SwordCounterNative checks=%d failures=%d valid=%s status=%s lost=%d recovery=%d"%[checks,failures,valid,result["status"],lost_taps,witnesses])
	quit(0 if valid and failures==0 else 1)
