extends "res://tests/sword_counter_native.gd"
## One frozen native pair: ordinary post-dash movement tests an existing window.
## Inherits the exact earned-source/native/route setup; never changes actors.

var reentry_commits: Dictionary = {}
var reentry_active: Dictionary = {}
var reentry_active_during_dash: int = 0

func reentry_geometry() -> Dictionary:
	var actor: Player = campaign.player
	var weapon: Weapon = actor.equipped_weapon
	var step: AttackStepDefinition = weapon.definition.combo_steps[0]
	var center: Vector2 = counter_target.hurtbox.global_position
	return {
		"player_x":actor.global_position.x, "player_y":actor.global_position.y,
		"player_v":actor.velocity, "weapon_origin":weapon.global_position,
		"guard_id":counter_target.get_instance_id(),
		"guard_x":counter_target.global_position.x, "guard_y":counter_target.global_position.y,
		"guard_v":counter_target.velocity, "hurtbox_center":center,
		"center_distance":weapon.global_position.distance_to(center), "reach":step.reach,
		"original_side":(actor.global_position.x-counter_target.global_position.x)*float(counter_cycle.get("facing",counter_target.facing)),
		"action":String(actor.action_state_machine.get_state_id()),
		"motor_dash":actor.motor.is_dashing, "grounded":actor.motor.is_grounded()
	}

func observe_reentry_active(observation: String) -> void:
	var weapon: Weapon = campaign.player.equipped_weapon
	if not weapon.hitbox.active or weapon.hitbox.attack_snapshot==null: return
	if campaign.player.motor.is_dashing: reentry_active_during_dash+=1
	var attack_id: int = weapon.hitbox.attack_snapshot.attack_id
	if reentry_active.has(attack_id): return
	var row: Dictionary = reentry_geometry()
	row.merge({
		"attack_id":attack_id, "observation":observation,
		"guard_state":String(counter_target.state_machine.get_state_id()),
		"guard_time":counter_target.state_time,
		"original_guard_attack_id":counter_cycle.get("original_guard_attack_id",0),
		"intervening_telegraph":counter_cycle.get("intervening_telegraph",false)
	},true)
	if reentry_commits.has(attack_id):
		row["since_commit_game_s"]=counter_clock()-float(reentry_commits[attack_id]["game_s"])
		row["since_commit_physics_ticks"]=Engine.get_physics_frames()-int(reentry_commits[attack_id]["physics_frame"])
	reentry_active[attack_id]=counter_event("first_active",row)

func counter_tick() -> void:
	var driver: CounterBot = bot as CounterBot
	if not is_instance_valid(campaign) or not is_instance_valid(counter_target):
		counter_done="target_unavailable"
		driver.stop()
		return
	var actor: Player = campaign.player
	var weapon: Weapon = actor.equipped_weapon
	var row: Dictionary = reentry_geometry()
	row.merge({
		"physics_frame":Engine.get_physics_frames(), "usec":Time.get_ticks_usec(),
		"game_s":counter_clock(), "phase":counter_phase, "frozen":campaign.feedback.is_frozen(),
		"hp":actor.health.current_health, "mana":actor.energy.current,
		"dash_remaining":actor.motor.dash_remaining, "iframe_remaining":actor.motor.invulnerability_remaining,
		"damage_grace":actor.damage_grace_remaining,
		"weapon_phase":weapon.phase, "weapon_remaining":weapon._phase_remaining,
		"weapon_duration":weapon._phase_duration, "weapon_hitbox":weapon.hitbox.active,
		"weapon_attack_id":weapon.hitbox.attack_snapshot.attack_id if weapon.hitbox.attack_snapshot!=null else 0,
		"guard_hp":counter_target.health.current_health,
		"guard_state":String(counter_target.state_machine.get_state_id()), "guard_time":counter_target.state_time,
		"guard_facing":counter_target.facing, "guard_locked_direction":counter_target.locked_direction,
		"guard_hitbox":counter_target.attack_hitbox.active,
		"guard_attack_id":counter_target.attack_hitbox.attack_snapshot.attack_id if counter_target.attack_hitbox.attack_snapshot!=null else 0,
		"guard_attack_rate":counter_target.attack_rate_multiplier,
		"guard_status_attack_speed":counter_target.statuses.attack_speed_multiplier,
		"motor_invulnerable":actor.motor.is_invulnerable(), "hurtbox_invulnerable":actor.hurtbox.invulnerable
	},true)
	counter_samples.append(row)
	observe_reentry_active("physics_sample")
	if weapon.phase!=_last_weapon_phase or weapon.hitbox.active!=_last_player_box or counter_target.attack_hitbox.active!=_last_guard_box:
		counter_event("phase_or_hitbox",row.duplicate(true))
		_last_weapon_phase=weapon.phase
		_last_player_box=weapon.hitbox.active
		_last_guard_box=counter_target.attack_hitbox.active
	if actor.health.current_health<=0.0 or campaign.outcome==&"defeat":
		counter_done="player_defeat"; driver.stop(); return
	if counter_target.health.current_health<=0.0:
		counter_done="target_dead"; driver.stop(); return
	if counter_clock()>=45.0:
		counter_done="gameplay_timeout"; driver.stop(); return
	if campaign.feedback.is_frozen() or not actor.controls_enabled: return
	var aim_event := InputEventMouseMotion.new()
	aim_event.position=counter_target.hurtbox.get_global_transform_with_canvas()*Vector2.ZERO
	root.push_input(aim_event,true)
	if not counter_cycle.is_empty() and counter_cycle.get("dash_accepted",false):
		if float(row["original_side"])<0.0:
			if not counter_cycle["crossed_behind"]: counter_event("crossed_behind",reentry_geometry())
			counter_cycle["crossed_behind"]=true
	match counter_phase:
		"approach":
			var difference: float = counter_target.global_position.x-actor.global_position.x
			driver.move(signf(difference) if absf(difference)>70.0 else 0.0)
			if visible_counter_cue():
				driver.move(0.0)
				counter_cycle={
					"index":counter_cycles.size()+1, "cue_s":counter_clock(),
					"guard_id":counter_target.get_instance_id(), "facing":counter_target.facing,
					"cue_guard_time":counter_target.state_time,
					"began_in_front":(actor.global_position.x-counter_target.global_position.x)*counter_target.facing>0.0,
					"dash_requested":false, "dash_request_grounded":false, "dash_accepted":false,
					"dash_accepted_grounded":false, "dash_normal_exit":false,
					"tap":false, "late_tap":false, "tap_after_exit":false, "tap_inside_range":false,
					"crossed_behind":false, "commit_ids":[], "commit_during_dash":false,
					"recovery_hit":false, "recovery_hit_after_cross":false,
					"original_guard_attack_id":0, "original_recovery_started":false,
					"intervening_telegraph":false, "intervening_attack":false,
					"iframe_avoided":false, "iframe_records":[],
					"full_windup_at_commit":true, "reentry_hit":false,
					"failure_reason":""
				}
				counter_cycles.append(counter_cycle)
				var cue: Dictionary = counter_cycle.duplicate(true)
				cue.merge(reentry_geometry(),true)
				counter_event("visible_tell",cue)
				counter_picture("cycle%d-tell"%counter_cycles.size())
				counter_phase="cue_wait"
		"cue_wait":
			driver.move(0.0)
			if counter_clock()-float(counter_cycle["cue_s"])>=REACTION_SECONDS:
				driver.move(-float(counter_cycle["facing"]))
				counter_cycle["dash_requested"]=true
				counter_cycle["dash_request_s"]=counter_clock()
				counter_cycle["dash_request_grounded"]=actor.motor.is_grounded()
				var request: Dictionary = reentry_geometry()
				request.merge({"direction":-float(counter_cycle["facing"]),"can_dash":actor.motor.can_dash(),"mana":actor.energy.current},true)
				counter_event("dash_request",request)
				driver.pulse(&"dash")
				counter_phase="dash_wait"
		"dash_wait":
			if counter_cycle["dash_accepted"] and not actor.motor.is_dashing:
				if counter_cycle["dash_normal_exit"]:
					counter_phase="reenter"
					counter_event("reentry_begin",reentry_geometry())
					reentry_input()
				else:
					counter_cycle["failure_reason"]="dash_cancelled"
					resolve_counter_cycle()
			elif not counter_cycle["dash_accepted"] and counter_clock()-float(counter_cycle["dash_request_s"])>=RESOLVE_SECONDS:
				counter_cycle["failure_reason"]="dash_not_accepted"
				counter_event("dash_not_accepted")
				resolve_counter_cycle()
		"reenter":
			reentry_input()
		"resolve":
			driver.move(0.0)
			if counter_clock()-float(counter_cycle["tap_s"])>=RESOLVE_SECONDS: resolve_counter_cycle()

func reentry_input() -> void:
	var driver: CounterBot = bot as CounterBot
	var actor: Player = campaign.player
	var geometry: Dictionary = reentry_geometry()
	if counter_clock()-float(counter_cycle["dash_exit_s"])>=RESOLVE_SECONDS:
		driver.move(0.0)
		counter_cycle["failure_reason"]="reentry_timeout"
		counter_event("reentry_timeout",geometry)
		resolve_counter_cycle()
		return
	# Geometry and the Player's available action alone choose the tap.
	# Guard phase/time/HP observations above never control this decision.
	if not actor.motor.is_dashing and actor.action_state_machine.get_state_id()==&"ready" and float(geometry["center_distance"])<=float(geometry["reach"]):
		driver.move(0.0)
		counter_cycle["tap"]=true
		counter_cycle["tap_s"]=counter_clock()
		counter_cycle["tap_after_exit"]=counter_cycle["dash_normal_exit"] and not actor.motor.is_dashing
		counter_cycle["tap_inside_range"]=true
		geometry["since_dash_exit_s"]=counter_clock()-float(counter_cycle["dash_exit_s"])
		counter_event("attack_tap",geometry)
		driver.pulse(&"attack")
		counter_phase="resolve"
	else:
		var direction: float = signf(counter_target.global_position.x-actor.global_position.x)
		driver.move(direction)
		geometry["direction"]=direction
		counter_event("reentry_input",geometry)

func player_changed(previous: StringName,next: StringName) -> void:
	super.player_changed(previous,next)
	if not counter_cycle.is_empty() and (next==&"dash" or previous==&"dash"):
		counter_event("dash_accepted_geometry" if next==&"dash" else "dash_exit_geometry",reentry_geometry())

func counter_weapon_commit(attack: AttackSnapshot) -> void:
	super.counter_weapon_commit(attack)
	var weapon: Weapon = campaign.player.equipped_weapon
	var step: AttackStepDefinition = weapon.definition.combo_steps[0]
	var full: bool = weapon.combo_index==0 and weapon.phase==Weapon.Phase.WINDUP and is_equal_approx(weapon._phase_remaining,step.windup_seconds) and is_equal_approx(weapon._phase_duration,step.windup_seconds)
	if not counter_cycle.is_empty():
		counter_cycle["full_windup_at_commit"]=counter_cycle["full_windup_at_commit"] and full
	var row: Dictionary = reentry_geometry()
	row.merge({"attack_id":attack.attack_id,"windup":step.windup_seconds,"phase_remaining":weapon._phase_remaining,"full_windup_at_commit":full,"attack_direction":attack.attack_direction,"aim_position":attack.aim_position},true)
	reentry_commits[attack.attack_id]=counter_event("commit_geometry",row)

func changed(previous: StringName,next: StringName,enemy: Node2D) -> void:
	super.changed(previous,next,enemy)
	if enemy!=counter_target or counter_cycle.is_empty(): return
	if next==&"telegraph":
		counter_cycle["intervening_telegraph"]=true
		counter_event("intervening_guard_telegraph",{"original_guard_attack_id":counter_cycle["original_guard_attack_id"]})
	elif next==&"attack":
		var attack: AttackSnapshot = counter_target.attack_hitbox.attack_snapshot
		if int(counter_cycle["original_guard_attack_id"])==0 and not counter_cycle["intervening_telegraph"] and attack!=null:
			counter_cycle["original_guard_attack_id"]=attack.attack_id
			counter_event("original_guard_attack",{"guard_id":counter_target.get_instance_id(),"attack_id":attack.attack_id,"facing":counter_target.facing})
		else:
			counter_cycle["intervening_attack"]=true
	elif next==&"recover" and previous==&"attack":
		if int(counter_cycle["original_guard_attack_id"])>0 and not counter_cycle["intervening_telegraph"] and not counter_cycle["intervening_attack"]:
			counter_cycle["original_recovery_started"]=true
			counter_event("original_guard_recovery",{"guard_id":counter_target.get_instance_id(),"attack_id":counter_cycle["original_guard_attack_id"]})

func player_hit(event: DamageEvent,result: DamageResult) -> void:
	super.player_hit(event,result)
	if counter_cycle.is_empty() or not is_instance_valid(counter_target): return
	var actor: Player = campaign.player
	var original: bool = event.source_id==counter_target.get_instance_id() and event.target_id==actor.get_instance_id() and event.attack_id==int(counter_cycle["original_guard_attack_id"]) and event.source_kind==DamageEvent.SourceKind.DIRECT
	var avoided: bool = original and result.blocked and result.block_reason==&"invulnerable" and actor.motor.is_dashing and actor.motor.invulnerability_remaining>0.0 and actor.damage_grace_remaining<=0.0 and not actor.hurtbox.sanctuary_safe
	if avoided:
		counter_cycle["iframe_avoided"]=true
		var row: Dictionary = reentry_geometry()
		row.merge({"source_id":event.source_id,"target_id":event.target_id,"attack_id":event.attack_id,"iframe_remaining":actor.motor.invulnerability_remaining,"damage_grace":actor.damage_grace_remaining,"block_reason":String(result.block_reason)},true)
		counter_cycle["iframe_records"].append(counter_event("original_guard_iframe_avoided",row))

func before_hit(event: DamageEvent,target: Node2D) -> void:
	super.before_hit(event,target)
	if not is_instance_valid(counter_target) or not is_instance_valid(campaign): return
	observe_reentry_active("before_hit")
	var key: String = "%d:%d:%d:%d"%[event.source_id,event.attack_id,event.hit_window_id,event.target_id]
	var before: Dictionary = counter_before[key]
	before["geometry"]=reentry_geometry()
	before["guard_state_time"]=counter_target.state_time
	before["guard_authored_recovery"]=counter_target.definition.recovery
	before["guard_attack_rate"]=counter_target.attack_rate_multiplier
	before["guard_status_attack_speed"]=counter_target.statuses.attack_speed_multiplier
	var rate: float = counter_target.attack_rate_multiplier*counter_target.statuses.attack_speed_multiplier
	before["guard_recovery_seconds_remaining_at_current_rate"]=maxf(0.0,counter_target.definition.recovery-counter_target.state_time)/rate if counter_target.state_machine.get_state_id()==&"recover" and rate>0.0 else -1.0
	before["player_action"]=String(campaign.player.action_state_machine.get_state_id())
	before["weapon_phase"]=campaign.player.equipped_weapon.phase
	before["weapon_phase_remaining"]=campaign.player.equipped_weapon._phase_remaining
	before["weapon_phase_duration"]=campaign.player.equipped_weapon._phase_duration
	before["since_dash_exit_s"]=counter_clock()-float(counter_cycle["dash_exit_s"]) if counter_cycle.has("dash_exit_s") else -1.0
	before["since_tap_s"]=counter_clock()-float(counter_cycle["tap_s"]) if counter_cycle.has("tap_s") else -1.0
	before["since_commit_s"]=counter_clock()-float(reentry_commits[event.attack_id]["game_s"]) if reentry_commits.has(event.attack_id) else -1.0
	before["original_guard_attack_id"]=counter_cycle.get("original_guard_attack_id",0)
	before["original_recovery_started"]=counter_cycle.get("original_recovery_started",false)
	before["intervening_telegraph"]=counter_cycle.get("intervening_telegraph",false)
	before["intervening_attack"]=counter_cycle.get("intervening_attack",false)

func after_hit(event: DamageEvent,result: DamageResult,target: Node2D) -> void:
	var key: String = "%d:%d:%d:%d"%[event.source_id,event.attack_id,event.hit_window_id,event.target_id]
	var before: Dictionary = counter_before.get(key,{}).duplicate(true)
	super.after_hit(event,result,target)
	if counter_cycle.is_empty() or target!=counter_target: return
	var direct: bool = event.source_id==campaign.player.get_instance_id() and event.source_kind==DamageEvent.SourceKind.DIRECT and event.physical_damage and event.spell_id==&"" and event.attack_id in counter_cycle["commit_ids"]
	var original_recover: bool = before.get("state","")=="recover" and before.get("original_recovery_started",false) and not before.get("intervening_telegraph",false) and not before.get("intervening_attack",false) and int(before.get("original_guard_attack_id",0))==int(counter_cycle["original_guard_attack_id"])
	var geometry: Dictionary = before.get("geometry",{})
	if direct and original_recover and float(geometry.get("original_side",0.0))<0.0 and not result.blocked and not result.killed and result.actual_damage>0.0:
		counter_cycle["reentry_hit"]=true
		counter_event("original_guard_recovery_contact",{"attack_id":event.attack_id,"guard_attack_id":counter_cycle["original_guard_attack_id"],"damage":result.actual_damage,"before":before,"after_hp":target.health.current_health})

func finish_counter(valid: bool) -> void:
	if is_instance_valid(bot): bot.stop()
	for _index: int in 4:
		if _pending_pictures==0: break
		await _step(1)
	var witnesses: int = 0
	var commits_during_dash: bool = false
	for cycle: Dictionary in counter_cycles:
		var ground_dash: bool = cycle["dash_request_grounded"] and cycle["dash_accepted_grounded"] and cycle["dash_normal_exit"]
		var witness: bool = ground_dash and cycle["began_in_front"] and cycle["crossed_behind"] and cycle["iframe_avoided"] and cycle["tap_after_exit"] and cycle["tap_inside_range"] and cycle["commit_ids"].size()==1 and not cycle["commit_during_dash"] and cycle["full_windup_at_commit"] and cycle["reentry_hit"]
		cycle["witness"]=witness
		if witness: witnesses+=1
		commits_during_dash=commits_during_dash or cycle["commit_during_dash"]
	_check(not commits_during_dash and reentry_active_during_dash==0,"Post-dash policy never commits or activates a sword hitbox during dash")
	var result: Dictionary = {
		"valid":valid and failures==0,"checks":checks,"failures":failures,
		"expectation_met":witnesses>0,"status":"WITNESS_RECORDED" if witnesses>0 and valid and failures==0 else "HOLD_MISSING_WITNESS",
		"seed":137,"reaction_seconds":REACTION_SECONDS,"reentry_timeout_seconds":RESOLVE_SECONDS,
		"policy":"full_ground_dash_then_first_ready_in_authored_range_tap",
		"initial":initial,"cycles":counter_cycles,"events":counter_events,"physics_samples":counter_samples,
		"pictures":pictures,"existing_window_witnesses":witnesses,
		"active_during_dash":reentry_active_during_dash,"commits_during_dash":commits_during_dash,
		"terminal_reason":counter_done,"combat_start_usec":combat_start,"combat_end_usec":combat_end,
		"source_profile_sha256":OS.get_environment("MINE_SOURCE_PROFILE"),"source_npc_sha256":OS.get_environment("MINE_SOURCE_NPC"),
		"scope":"Same earned Common+1 and visible-cue policy on both builds. Ordinary post-dash movement and one ready/in-range tap; no late-buffer exercise. No actor/HP/velocity/timer edits, casts or grants. Baseline witness establishes an existing window; candidate-only success does not prove buffer benefit. Not human playtest/balance/crash proof."
	}
	if is_instance_valid(campaign): result["final"]=snapshot()
	var file := FileAccess.open(evidence.path_join("sword-reentry-native.json"),FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(result,"\t")); file.close()
	else:
		_check(false,"Reentry receipt is writable")
	if node_added.is_connected(born): node_added.disconnect(born)
	counter_target=null; counter_before.clear()
	if is_instance_valid(bot):
		(bot as CounterBot).harness=null; bot.run=null; bot.queue_free()
	if is_instance_valid(flow): flow.queue_free()
	current_scene=null; campaign=null
	await _step(8)
	await root.get_node("AudioManager").shutdown()
	print("RESULT SwordReentryNative checks=%d failures=%d valid=%s status=%s witnesses=%d"%[checks,failures,result["valid"],result["status"],witnesses])
	quit(0 if valid and failures==0 else 1)
