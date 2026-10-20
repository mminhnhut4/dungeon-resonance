extends "res://tests/linked_gameplay_probe.gd"
## Actual earned H7, one ordinary Fire cast at the product's active training Slime.
var target: SlimeEnemy
var events: Array[Dictionary]=[]
var samples: Array[Dictionary]=[]
var pending_hits: Dictionary[int,Dictionary]={}
var burning_bites: int=0
var previous_bite: bool=false
var dodge_done: bool=false
func incoming_dot(hit: DamageEvent) -> void:
	pending_hits[hit.attack_id]={"before":String(target.state_machine.get_state_id()),"active_before":target.bite_hitbox.active,"state_time_before":target._state_time,"hp_before":target.health.current_health}
func received_dot(hit: DamageEvent,result: DamageResult) -> void:
	var row: Dictionary=pending_hits.get(hit.attack_id,{}).duplicate();pending_hits.erase(hit.attack_id)
	row.merge({"kind":hit.source_kind,"blocked":result.blocked,"amount":result.actual_damage,"after":String(target.state_machine.get_state_id()),"active_after":target.bite_hitbox.active,"state_time_after":target._state_time,"hp_after":target.health.current_health,"wall_usec":Time.get_ticks_usec()},true);events.append(row)
func observe_dot() -> void:
	if not is_instance_valid(target):return
	var active: bool=target.bite_hitbox.active
	if active and not previous_bite and target.statuses.burn_remaining>0:burning_bites+=1
	previous_bite=active
	if samples.size()<1800:samples.append({"state":String(target.state_machine.get_state_id()),"active":active,"burn":target.statuses.burn_remaining,"hp":target.health.current_health,"x":target.global_position.x,"wall_usec":Time.get_ticks_usec()})
func single_fire() -> bool:
	_stage("owned_single_fire_ui");await _key(KEY_TAB);await pause(.5)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	var tabs: TabBar=screen.tabs.get_tab_bar();await _mouse(tabs.get_global_transform()*tabs.get_tab_rect(1).get_center());await pause(.4)
	_check(hub.gear.inventory.slots[GearInventory.CATALYST_INDICES[0]]==&"fire","Original H7 genuinely owns/equips its Fire rune")
	await _click(screen.slots[GearInventory.CATALYST_INDICES[1]])
	var remove: Button
	for node: Node in screen.find_children("*","Button",true,false):
		if (node as Button).text=="Tháo bùa ở ô đang chọn":remove=node as Button;break
	if not _check(remove!=null,"Existing inventory removal action is present"):return false
	await _click(remove);await pause(.5)
	_check(hub.player.resonance_controller.catalyst_a.runtime_state.installed_rune_ids==[&"fire"],"Actual removal click leaves exactly the owned Fire rune, no direct loadout edit")
	await _key(KEY_ESCAPE);await pause(.5)
	return _check(hub.player.resonance_controller.get_recipe().id==&"fire_bolt" and is_equal_approx(Engine.time_scale,1.0),"Product owner resolves Fire Bolt and restores normal gameplay time")
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or not "--qa-seed-h7" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");profile_path="user://newcomer-item1/profile.json"
	_check(FileAccess.get_sha256(profile_path)==OS.get_environment("FOLLOWUP_SOURCE_PROFILE") and FileAccess.get_sha256(profile_path+".npc_v1.json")==OS.get_environment("FOLLOWUP_SOURCE_NPC"),"Exact earned H7 save pair before ordinary startup")
	bot=CombatBot.new();root.add_child(bot);flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow;await _step(30);hub=flow.active_scene as ExteriorHub
	target=hub.training_slime
	_check(not flow.qa_tools_enabled and target!=null and target.ai_enabled and target.health.current_health>0,"Product Hub supplies its real active training Slime without a fixture actor")
	recorder=preload("res://tests/newcomer_capture.gd").new();root.add_child(recorder);recorder.begin(evidence)
	if not await single_fire():await finish_dot(false);return
	if not await _walk(hub.player,target.global_position.x+100):await finish_dot(false);return
	target.hurtbox.damage_received.connect(incoming_dot);target.hurtbox.hit_resolved.connect(received_dot);process_frame.connect(observe_dot)
	_stage("one_fire_cast_then_natural_burn")
	var aim:=InputEventMouseMotion.new();aim.position=hub.player.get_canvas_transform()*target.hurtbox.global_position;root.push_input(aim,true);await _step(2)
	var casts: int=hub.player.resonance_controller.cast_count
	await _key(KEY_I)
	_check(hub.player.resonance_controller.cast_count==casts+1,"Exactly one ordinary I commits Fire Bolt")
	for i: int in 480:
		if burning_bites>0 and not dodge_done:
			_stage("burning_slime_bites_player_dashes")
			await _shot("burning_bite")
			var before_energy: float=hub.player.energy.current
			await _key(KEY_SHIFT);dodge_done=true
			_check(hub.player.motor.is_dashing or hub.player.motor.dash_cooldown_remaining>0,"Ordinary Shift still performs the existing dash")
			_check(hub.player.energy.current<before_energy,"Dash still pays existing shared energy")
		if i>60 and target.statuses.burn_remaining<=0 and events.any(func(r: Dictionary)->bool:return r["kind"]==DamageEvent.SourceKind.DOT):break
		await _step(1)
	var ticks: Array[Dictionary]=events.filter(func(r: Dictionary)->bool:return r["kind"]==DamageEvent.SourceKind.DOT and not r["blocked"])
	_check(ticks.size()>0 and ticks.all(func(r: Dictionary)->bool:return r["amount"]>0 and r["hp_after"]<r["hp_before"]),"Actual Fire DOT continues reducing real Slime HP")
	_check(ticks.all(func(r: Dictionary)->bool:return r["before"]==r["after"] and r["state_time_before"]==r["state_time_after"] and r["active_before"]==r["active_after"]),"Natural DOT callbacks cannot insert hurt or close the bite window")
	_check(burning_bites>0 and dodge_done,"While visibly burning the real Slime executes its bite and ordinary player dash remains usable")
	_check(target.health.current_health>0 and hub.player.resonance_controller.cast_count==casts+1,"Slime survives the single authored cast/ticks; no HP/damage/stat override or extra cast")
	await _shot("burn_ended_without_stagger");await finish_dot(true)
func finish_dot(complete: bool) -> void:
	await pause(.5);var cap: Dictionary=recorder.finish()
	var state: Dictionary={"checks":checks,"failures":failures,"complete":complete,"burning_bite_starts":burning_bites,"dodge_done":dodge_done,"events":events,"samples":samples,"source_profile":OS.get_environment("FOLLOWUP_SOURCE_PROFILE"),"capture":{"wall_seconds":cap["wall_seconds"],"frames":cap["frames"].size(),"audio":cap["audio"]},"scope":"Real earned H7 + inventory removal click, one ordinary Fire Bolt at product Hub training Slime, natural AI/ticks and Shift. Hub is a safe training zone; not proof enemy damage was avoided by iframes. No grants/HP/damage/stat/warp/AI/RNG fixtures,1x continuous, no FPS/audio-audition claim."}
	var f:=FileAccess.open(evidence.path_join("slime-dot-gameplay.json"),FileAccess.WRITE);f.store_string(JSON.stringify(state,"\t"));f.close()
	if process_frame.is_connected(observe_dot):process_frame.disconnect(observe_dot)
	bot.queue_free();flow.queue_free();recorder.queue_free();current_scene=null;await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT SlimeDotGameplay checks=%d failures=%d complete=%s wall=%.3f"%[checks,failures,complete,cap["wall_seconds"]]);quit(0 if complete and failures==0 else 1)
