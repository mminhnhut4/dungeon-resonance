extends "res://tests/tan_dang_quest_test.gd"
## Real sealed owners, bounded reward, legacy absence, fault recovery; no real saves.
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	directory="user://verification/part5_model"
	for branch: String in ["gate","rescue"]:
		var p: TanDangProgress=_fixture(branch);var cache:=OpeningExplorationProgress.new();cache.initialize(p.profile)
		var original: PackedByteArray=_raw(p.profile.save_path)
		_check(not cache.state_for(p.profile)["cache_claimed"] and _raw(p.profile.save_path)==original,"Legacy absent cache is read-only default, no forced migration/write")
		_check(not OpeningExplorationProgress.shortcut_open(p.profile),"Fresh existing SC01 gate remains locked")
		_q1(p);_apply(p,"choice_"+branch,"refuge")
		_check(not OpeningExplorationProgress.shortcut_open(p.profile),"Choice alone does not open the completion shortcut")
		_kill(p,MOC);_kill(p,LAM);_finish(p)
		_check(OpeningExplorationProgress.shortcut_open(p.profile) and not p.profile.exterior_progress["sc01_open"],"Dead-NPC ledger fallback opens physical SC01 by committed q3, no new flag")
		var before: int=p.profile.material_stash[&"dust"]
		_check(cache.claim().get("ok",false) and p.profile.material_stash[&"dust"]==before+2 and cache.state_for(p.profile)["cache_claimed"],"One optional cache commits exactly 2 existing dust into stash with its receipt")
		original=_raw(p.profile.save_path)
		_check(not cache.claim().get("ok",false) and _raw(p.profile.save_path)==original and p.profile.material_stash[&"dust"]==before+2,"Duplicate cannot write or farm reward")
		p=_cold(p);cache.initialize(p.profile)
		_check(cache.state_for(p.profile)["cache_claimed"] and p.profile.material_stash[&"dust"]==before+2 and OpeningExplorationProgress.shortcut_open(p.profile) and not p.alive(DU),"Cold sealed cache/shortcut/death agree in both branch fixtures") if branch=="gate" else _check(cache.state_for(p.profile)["cache_claimed"] and p.profile.material_stash[&"dust"]==before+2 and OpeningExplorationProgress.shortcut_open(p.profile) and p.alive(DU),"Rescue history and one cache survive cold load")
	for fault: String in ["write_candidate","after_decision"]:
		var p: TanDangProgress=_fixture(fault);var cache:=OpeningExplorationProgress.new();cache.initialize(p.profile)
		var before: int=p.profile.material_stash[&"dust"];var original: PackedByteArray=_raw(p.profile.save_path)
		p.profile._writer.fault_plan={fault:true}
		_check(not cache.claim().get("ok",false) and p.profile.material_stash[&"dust"]==before and not cache.state_for(p.profile)["cache_claimed"],"Refusal/uncertainty publishes no RAM reward or claim: "+fault)
		if fault=="write_candidate":_check(_raw(p.profile.save_path)==original,"Pre-decision write failure preserves exact source bytes")
		p=_cold(p);cache.initialize(p.profile)
		var decided: bool=fault=="after_decision"
		_check(cache.state_for(p.profile)["cache_claimed"]==decided and p.profile.material_stash[&"dust"]==before+(2 if decided else 0),"Existing recovery rolls forward a decided reward+receipt together, or keeps old state")
		_check(cache.claim().get("ok",false)!=decided and p.profile.material_stash[&"dust"]==before+2,"Retry produces exactly one grant at either fault boundary")
	var p: TanDangProgress=_fixture("limits");var cache:=OpeningExplorationProgress.new();cache.initialize(p.profile)
	p.profile.material_stash[&"dust"]=MaterialCatalog.MAX_COUNT-1
	_check(not cache.claim().get("ok",false) and not cache.state_for(p.profile)["cache_claimed"],"Full stash refuses without consuming the opportunity")
	p.profile.read_only=true
	_check(not cache.claim().get("ok",false),"Read-only owner cannot claim")
	_check(not OpeningExplorationProgress.valid({"version":2,"cache_claimed":true}) and not OpeningExplorationProgress.valid({"version":1,"cache_claimed":1}),"Future/malformed cache data rejected")
	p.profile.exterior_progress["sc01_open"]=true
	_check(OpeningExplorationProgress.shortcut_open(p.profile),"Historical manually opened SC01 stays open without quest")
	_check(not OpeningExplorationProgress.valid({"version":true,"cache_claimed":false}),"Boolean is not a numeric cache schema version")
	p=_fixture("future_scope")
	_check(p.profile.commit_extension_event(OpeningExplorationProgress.SCOPE,"future_qa",{},0,{"version":2,"cache_claimed":true}).get("ok",false),"Older unregistered generic owner retains an opaque future fixture")
	var original: PackedByteArray=_raw(p.profile.save_path)
	var future:=SanctuaryProfile.new();future.save_path=p.profile.save_path;future.register_extension_validator(OpeningExplorationProgress.SCOPE,OpeningExplorationProgress.valid)
	_check(future.load_profile(),"New cold owner retains the envelope without deleting unsupported state")
	cache.initialize(future)
	_check(not cache.available() and not cache.claim().get("ok",false) and _raw(future.save_path)==original and future.extension_state(OpeningExplorationProgress.SCOPE).is_empty(),"Unsupported scope is fenced, never reset/rewarded/overwritten")
	_layouts()
	print("RESULT Part5ExplorationModel checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)

func _layouts() -> void:
	var output: String=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	for spec: Array in [[&"o01_p03",ExteriorRouteCatalog.MAIN],[&"o01_p02",ExteriorRouteCatalog.MAIN],[&"o01_p02",ExteriorRouteCatalog.TUNNEL]]:
		var room:=ExteriorRoom.new();_check(room.configure(spec[0],spec[1],true),"Native author exports the geometry, not a reconstructed diagram")
		var points: Array=[]
		for point: Vector2 in room.surface:points.append([point.x,point.y])
		var props: Array=[]
		var exits: Array=[{"id":"east","x":room.anchors[&"east"].x,"y":room.anchors[&"east"].y}]
		if spec[0]==&"o01_p03":
			for i: int in OpeningExploration.LEDGES.size():
				var r: Rect2=OpeningExploration.LEDGES[i];props.append({"id":"recess%d"%i,"kind":"platform","x0":r.position.x,"x1":r.end.x,"y":r.position.y,"thickness":r.size.y})
			props.append({"id":"chest","x":OpeningExploration.CACHE_POINT.x,"y":OpeningExploration.CACHE_POINT.y,"w":32})
			exits.append({"id":"secret","x":OpeningExploration.CACHE_POINT.x,"y":OpeningExploration.CACHE_POINT.y})
		var data: Dictionary={"schema":"generate2dmap.layout.v1","segments":[[0,ceili(room.width),"ground"]],"surface":points,"physics":{"jumpHeight":120,"jumpDistance":230,"maxSlopeDeg":10,"stepUp":1,"colliderSubstep":6,"minDeckThickness":8,"groundTolerance":1},"props":props,"spawns":[{"id":"west","x":room.anchors[&"west"].x,"y":room.anchors[&"west"].y}],"exits":exits,"viewport":{"width":1152,"height":648}}
		var file:=FileAccess.open(output.path_join(String(spec[0])+"_"+String(spec[1])+".layout.json"),FileAccess.WRITE);file.store_string(JSON.stringify(data,"\t"));file.close()
		room.free()
