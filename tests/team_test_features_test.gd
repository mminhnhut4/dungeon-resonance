extends SceneTree
var checks: int=0
var failures: int=0
var lab: TeamTestLab
func _initialize() -> void:_run.call_deferred()
func _step(n: int=1) -> void:
	for i: int in n:await physics_frame
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func _picture(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(label+".png"))==OK,"Native image "+label)
func _g_activation(binding: OpeningStyleBinding,branch: String) -> void:
	_check(binding!=null,"Committed G binding is attached")
	if binding==null:return
	var runtime: CultivationStyleRuntime=binding.runtime
	var hits_before: int=runtime.accepted_hits
	var accepted: bool=false;var active: bool=false
	if branch=="cloud_return":
		_check(lab.equip_weapon(&"ancient_sword",0,0),"Cloud weapon prerequisite via inventory owner")
		var enemy: MemberEnemy=(lab.active_world() as MemberDungeonCampaign).room.encounters.spawned[0]
		PlayerTravel.relocate(lab.hero(),Vector2(500,640));await _step(8) # Controlled setup before the dodge segment.
		for i: int in 360:
			var motion:=InputEventMouseMotion.new();motion.position=lab.hero().get_canvas_transform()*(enemy.global_position-Vector2(0,22));lab.hero().aim._input(motion);lab.hero().aim.sample_cursor()
			if enemy.state_machine.get_state_id()==&"telegraph" and enemy.state_time>=enemy.definition.windup-.035 and not lab.hero().motor.is_dashing and lab.hero().motor.dash_cooldown_remaining<=0:
				var dash:=InputEventAction.new();dash.action=&"dash";dash.pressed=true;lab.hero()._unhandled_input(dash)
			if runtime.counter_remaining>0:
				var dx: float=enemy.global_position.x-lab.hero().global_position.x
				Input.action_release(&"move_left");Input.action_release(&"move_right")
				if not lab.hero().motor.is_dashing and absf(dx)>55:Input.action_press(&"move_right" if dx>0 else &"move_left")
				if not lab.hero().motor.is_dashing and absf(dx)<65 and enemy.state_machine.get_state_id()!=&"attack" and lab.hero().action_state_machine.get_state_id()==&"ready":
					Input.action_release(&"move_left");Input.action_release(&"move_right")
					accepted=binding.request_skill(enemy.global_position-Vector2(0,22));break
			await _step()
		_check(accepted,"Physical dodge opens real counter, G accepted: "+str(binding.last_error)+" / "+str(runtime.last_rejection))
	else:
		accepted=binding.request_skill(lab.hero().aim.global_position+Vector2(70,0))
		_check(accepted,"Tether placement uses clear above-ground aim: "+str(binding.last_error))
		await _step(45)
		_check(is_instance_valid(runtime.mark) and runtime.mark.is_armed(),"Real mark reaches armed state")
		if is_instance_valid(runtime.mark):_check(binding.request_skill(runtime.mark.global_position),"Second G activates armed pulse")
	if accepted:
		var cooldown: float=runtime.cooldowns[StringName(branch)]
		_check(cooldown>0,"G starts actual cooldown")
		for i: int in 30:
			active=(runtime.hitbox.active or runtime.accepted_hits>hits_before) if branch=="cloud_return" else is_instance_valid(runtime.mark) and runtime.mark.pulsing
			if active:break
			await _step()
		_check(active,"G effect reaches active physical phase; contacts=%d state=%s"%[runtime.accepted_hits-hits_before,lab.hero().action_state_machine.get_state_id()])
		print("METRIC G branch=%s contacts=%d cooldown=%.3f"%[branch,runtime.accepted_hits-hits_before,cooldown])
		await _picture("g_"+branch)
		await _step(30)
		_check(float(runtime.cooldowns[StringName(branch)])<cooldown and float(runtime.cooldowns[StringName(branch)])>0,"Cooldown advances without reset")
		_check(not binding.request_skill(lab.hero().aim.global_position+Vector2(70,0)),"Repeated G cannot bypass its prerequisites/cooldown")
		lab.set_godmode(true);lab.set_infinite_mana(true);await _step(2)
		_check(lab.hero().health.minimum_health==1 and lab.hero().energy.current==lab.hero().energy.maximum,"Cheat toggles explicit ON")
		lab.set_godmode(false);lab.set_infinite_mana(false);await _step(2)
		_check(lab.hero().health.minimum_health==0 and float(runtime.cooldowns[StringName(branch)])>0,"Cheats OFF restore damage and keep G cooldown")
func _run() -> void:
	if not TeamTestSeed.isolated():quit(2);return
	root.unfocusable=true;root.position=Vector2i(-30000,-30000);Engine.max_fps=120
	var preset: int=0;var branch: String="cloud_return"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--preset="):preset=int(arg.get_slice("=",1))
		if arg=="--tether":branch="tether_sigil"
	lab=load("res://scenes/team_test_lab.tscn").instantiate() as TeamTestLab;root.add_child(lab)
	for i: int in 600:
		if not lab.loading:break
		await _step()
	_check(lab.gear()!=null,"Fresh TEAM TEST boots")
	_check(await lab.select_preset(preset,branch),"Preset/branch loads "+str(preset)+" "+branch+" "+TeamTestSeed.last_error)
	if lab.gear()==null:quit(1);return
	_check(not lab.godmode and not lab.infinite_mana,"Preset keeps cheats OFF")
	_check(lab.gear().relics.equipped.is_empty(),"Relics available without automatically buffing weak build")
	if preset==3:
		_check(lab.flow.profile.cultivation_progress["actors"]["player"]["stage"]==3,"Truc Co reached through sealed cultivation commands")
		_check(lab.flow.profile.cultivation_abilities()["selected_id"]==branch,"Selected G branch persisted")
		_check(lab.hero().resonance_controller.foundation_resonance_enabled,"Foundation consumer enabled")
		_check(lab.hero().health.maximum_health==165 and lab.hero().energy.maximum==150,"Maximum existing permanent upgrades applied")
		var member: int=lab.maps.find(lab.maps.filter(func(e:Dictionary)->bool:return e["id"]=="member_9")[0])
		_check(await lab.load_map(member),"Max build enters real supported campaign room")
		lab.set_menu(false);await _step(10)
		var binding:=lab.hero().get_meta(&"opening_style_binding") as OpeningStyleBinding
		await _g_activation(binding,branch);lab.set_menu(true)
	await _picture("menu_preset_%d"%preset)
	var actor: int=lab.maps.find(lab.maps.filter(func(e:Dictionary)->bool:return e["id"]=="actor_0")[0])
	_check(await lab.load_map(actor),"Actor trial opens with same QA inventory")
	_check(lab.equip_weapon(&"ancient_sword",0,0),"Ordinary sword equip for contact proof")
	var recipe: int=TeamTestCatalog.RECIPES.find("res://data/resonances/firestorm.tres" if preset in [2,3] else "res://data/resonances/fire_bolt.tres" if preset==1 else "res://data/resonances/basic.tres")
	_check(lab.equip_recipe(recipe),"Representative exact recipe")
	var target: MemberEnemy
	for node: Node in get_nodes_in_group(&"member_enemies"):
		if lab.standalone.is_ancestor_of(node):target=node as MemberEnemy;break
	var before: float=target.health.current_health;var casts: int=lab.hero().resonance_controller.cast_count
	lab.set_menu(false)
	var motion:=InputEventMouseMotion.new();motion.position=lab.hero().get_canvas_transform()*(target.global_position-Vector2(0,25));lab.hero().aim._input(motion);lab.hero().aim.sample_cursor()
	var press:=InputEventAction.new();press.action=&"spell_cast";press.pressed=true;lab.hero()._unhandled_input(press)
	await _step(150)
	_check(lab.hero().resonance_controller.cast_count>casts,"Native/real FSM commits cast")
	_check(not is_instance_valid(target) or target.health.current_health<before,"Actual projectile/field damages live target")
	await _picture("cast_preset_%d"%preset)
	lab.set_menu(true)
	for relic: int in 4:_check(lab.equip_relic(relic) and lab.gear().relics.equipped.size()==1,"Relic selection "+str(relic))
	_check(lab.equip_relic(-1) and lab.gear().relics.equipped.is_empty(),"Relic OFF")
	for quality: int in 6:
		_check(lab.set_rune_quality(quality) and lab.gear().inventory.items[lab.gear().inventory.catalyst_uid].quality==quality,"Rune/Catalyst quality "+str(quality))
	var path: String=lab.profile_path()
	_check(lab.save_session(),"Save exact selected build")
	_check(await lab.load_map(actor),"Reload encounter")
	_check(lab.profile_path()==path,"Reload retains profile namespace")
	_check(lab.hero().resonance_controller.get_recipe().id==("firestorm" if preset in [2,3] else "fire_bolt" if preset==1 else "basic"),"Loadout survives cold owner reconstruction")
	if preset==0:
		for id: StringName in TeamTestCatalog.WEAPONS:_check(lab.equip_weapon(id,0,0),"All existing weapon definitions equip "+str(id))
		var old: String=lab.profile_path()
		_check(await lab.reset_profile(),"Reset QA to new slot")
		_check(old!=lab.profile_path() and FileAccess.file_exists(old),"Reset retains old save and creates new namespace")
		for path_equipment: String in TeamTestCatalog.EQUIPMENT:_check(lab.equip_equipment(path_equipment,1),"Every equipment definition accessible "+path_equipment.get_file())
	var result: Dictionary={"checks":checks,"failures":failures,"preset":preset,"branch":branch,"profile":lab.profile_path(),"isolated":TeamTestSeed.isolated()}
	var out:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("features.json"),FileAccess.WRITE);out.store_string(JSON.stringify(result,"\t"));out.close()
	lab.queue_free();await _step(4);await root.get_node("AudioManager").shutdown()
	print("RESULT TeamTestFeatures checks=%d failures=%d preset=%d branch=%s"%[checks,failures,preset,branch]);quit(0 if failures==0 else 1)
