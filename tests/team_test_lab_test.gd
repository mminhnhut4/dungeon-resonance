extends SceneTree
var checks: int=0
var failures: int=0
var lab: TeamTestLab
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func _step(n: int=1) -> void:
	for i: int in n:await physics_frame
func _run() -> void:
	if not TeamTestSeed.isolated():quit(2);return
	root.unfocusable=true;root.position=Vector2i(-30000,-30000)
	var group: int=0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--group="):group=int(arg.get_slice("=",1))
	lab=load("res://scenes/team_test_lab.tscn").instantiate() as TeamTestLab;root.add_child(lab)
	for i: int in 600:
		if not lab.loading:break
		await _step()
	_check(lab.gear()!=null and lab.last_error.is_empty(),"Clean isolated boot creates valid profile "+lab.last_error)
	if lab.gear()==null:quit(1);return
	var count: int=0
	for i: int in lab.maps.size():
		if i/16!=group:continue
		_check(await lab.load_map(i),"Map adapter loads "+str(lab.maps[i]["id"])+" "+lab.last_error)
		_check(lab.hero()!=null and lab.hero().health.current_health>0,"Map has live playable Player "+str(lab.maps[i]["id"]))
		_check(lab.gear()!=null,"Map has inventory/session "+str(lab.maps[i]["id"]))
		count+=1;await _step(2)
	if group==0:
		_check(not lab.godmode and not lab.infinite_mana,"Cheats start OFF")
		lab.set_godmode(true);await _step();_check(lab.hero().health.minimum_health==1,"Explicit godmode floor")
		lab.set_godmode(false);await _step();_check(lab.hero().health.minimum_health==0,"Godmode OFF restores normal damage")
		lab.set_infinite_mana(true);lab.hero().energy.current=0;await _step(2)
		_check(is_equal_approx(lab.hero().energy.current,lab.hero().energy.maximum),"Infinite mana refills without cooldown changes")
		lab.set_infinite_mana(false)
		_check(lab.refill() and lab.flow.profile.coins==50000,"Explicit resources grant persists through owner")
		for recipe: int in TeamTestCatalog.RECIPES.size():_check(lab.equip_recipe(recipe),"Every authored recipe exact install "+str(recipe))
		_check(lab.equip_weapon(&"world_spear",0,1) and lab.hero().equipped_weapon.definition.id==&"world_spear","Gear-driven family equip")
		_check(lab.save_session(),"Manual QA save")
		var cold:=SanctuaryProfile.new();cold.save_path=lab.profile_path()
		_check(cold.load_profile() and GearInventoryCodec.valid(cold.hub_inventory),"Cold reader accepts sealed QA inventory")
	_check(count>0,"Nonempty map group")
	var out:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("coverage.json"),FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks":checks,"failures":failures,"group":group,"maps":count,"totalMaps":lab.maps.size(),"profile":lab.profile_path()},"\t"));out.close()
	lab.queue_free();await _step(4);await root.get_node("AudioManager").shutdown()
	print("RESULT TeamTestLab checks=%d failures=%d group=%d maps=%d"%[checks,failures,group,count]);quit(0 if failures==0 else 1)
