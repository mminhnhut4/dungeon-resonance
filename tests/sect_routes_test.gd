extends "res://tests/depth_floor_selection_test.gd"
## Actual player/dialogue/geography owners. Road start relocation is a fixture, not a played expedition.
var hub: ExteriorHub

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
		if arg=="--native-approved": capture=true
	var allowed: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or capture!=(DisplayServer.get_name()!="headless"):
		quit(2); return
	path="user://verification/sect_routes_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size=Vector2i.ZERO; root.size=Vector2i(1280,720)
	await _open()
	hub=flow.active_scene as ExteriorHub
	_check(hub!=null and hub.sect_journey!=null,"Actual product owns the sect quest component")
	if hub==null or hub.sect_journey==null: await _close(); _finish(); return
	var actor: Node2D=hub.player
	var uid_snapshot: Array=hub.gear.inventory.items.keys()
	_check(ExteriorRouteCatalog.ROOMS.size()==8 and ExteriorRouteCatalog.all_rooms().size()==12,"Eight stable roads plus four actual branches")
	for faction_id: String in SectRouteCatalog.FACTIONS:
		var first: StringName=SectRouteCatalog.first(faction_id)
		var inner: StringName=SectRouteCatalog.link(first,&"door_east")["room"]
		_check(not hub.enter_exterior(first) and not hub.enter_exterior(inner),"Unaccepted first and inner gates reject: "+faction_id)
		_check(hub.enter_exterior(SectRouteCatalog.ROAD_ROOMS[faction_id]),"Fixture enters existing parent road")
		await _at(&"sect_register")
		_check(hub.nearest_station()==&"sect_register","Register remains reachable beside original road interactions")
		await _key(root,KEY_E)
		_check(hub.dialogue.is_open and not hub.player.controls_enabled,"E opens sect offer through the real modal")
		var before_bytes: PackedByteArray=FileAccess.get_file_as_bytes(path)
		flow.profile._writer.fault_plan={"write_candidate":true}
		await _choose(&"sect_accept")
		_check(not hub.sect_journey.progress.state()[faction_id]["accepted"] and FileAccess.get_file_as_bytes(path)==before_bytes,"Failed accept preserves disk bytes and locked gate")
		await _choose(&"sect_accept")
		_check(hub.sect_journey.progress.state()[faction_id]["accepted"],"Same dialogue can retry a failed accept")
		hub.dialogue.close(); await _step(3)
		_check(hub.player.controls_enabled and is_equal_approx(Engine.time_scale,1.0),"Quest closes without stuck controls or time claim")
		await _at(&"sect_branch")
		await _key(root,KEY_E)
		_check(hub.exterior.room_id==first and hub.player==actor,"Physical branch enters first map with the same player")
		_check(uid_snapshot==hub.gear.inventory.items.keys() and not hub.enter_exterior(inner),"Travel keeps UIDs; inner gate still requires observations")
		await _step(3)
		_check(hub.exterior.get_node_or_null("SectRoomArt/PaintedSectBackdrop")!=null,"Generated background is actually bound to the current room")
		_check(hub.npc_population.actors.has(SectRouteCatalog.STEWARDS[faction_id]),"Unique nonlethal steward is loaded in its own room")
		await _quest_tracking(faction_id)
		await _walk_to(300.0)
		await _picture(String(first)+"_west")
		for side: String in ["west","east"]:
			var key:=StringName("sect_marker_"+side)
			await _walk_to(hub.exterior.interactions[key].x)
			_check(hub.nearest_station()==key,"Walking reaches actual "+side+" observation")
			await _key(root,KEY_E)
			_check(hub.dialogue.is_open,"Marker opens through E")
			await _choose(StringName("sect_"+side))
			_check(hub.sect_journey.progress.state()[faction_id]["markers"].has(side),"Explicit marker choice stores the observed fact")
			hub.dialogue.close(); await _step(3)
		var revision: int=flow.profile.extension_revision(SectJourneyProgress.SCOPE)
		_check(hub.sect_journey.progress.record(faction_id,"east") and flow.profile.extension_revision(SectJourneyProgress.SCOPE)==revision,"Repeated observation cannot create another receipt")
		var steward: String=SectRouteCatalog.STEWARDS[faction_id]
		hub.npc_population.state.receive_hit(steward,1.0,0.0)
		await _step(4)
		await _walk_to(hub.exterior.interactions[&"sect_register"].x)
		await _key(root,KEY_E)
		_check(hub.dialogue.is_open and hub.npc_population.state.records[steward]["mode"]=="recovering","Physical register works while its steward is recovering")
		await _choose(&"sect_guest")
		_check(hub.sect_journey.progress.can_enter(inner),"Submitting two real observations unlocks only this inner court")
		hub.dialogue.close(); await _step(3)
		await _picture(String(first)+"_register")
		await _walk_to(hub.exterior.interactions[&"door_east"].x)
		await _key(root,KEY_E)
		_check(hub.exterior.room_id==inner and hub.player==actor,"Actual east door enters the distinct inner map")
		await _walk_to(hub.exterior.width*.55)
		await _picture(String(inner)+"_center")
		_check(not hub.exterior.interactions.has(&"door_east"),"Inner map has a real return route and no fake onward door")
		await _key(root,KEY_E)
		_check(hub.dialogue.is_open,"Inner story monument is an actual readable interaction")
		hub.dialogue.close(); await _step(3)
		await _walk_to(90.0)
		await _key(root,KEY_E)
		_check(hub.exterior.room_id==first,"Inner west door returns to the first map")
		await _walk_to(90.0)
		await _key(root,KEY_E)
		_check(hub.exterior.room_id==SectRouteCatalog.ROAD_ROOMS[faction_id] and hub.last_entry==&"sect","Sect west door returns to its exact parent branch anchor")
		_check(hub.player==actor and uid_snapshot==hub.gear.inventory.items.keys(),"Round trip never replaces actor or carried UIDs")
		_check(not hub.profile.exterior_progress["sc01_open"],"Sect path never opens the independent SC01 shortcut")
	await _journal()
	_check(hub.return_to_hub(),"Geographic return reaches the same hub")
	await _close(); await _open(); hub=flow.active_scene as ExteriorHub
	for faction_id: String in SectRouteCatalog.FACTIONS:
		_check(hub.sect_journey.progress.state()[faction_id]["guest"],"Cold product load retains guest permission: "+faction_id)
		_check(hub.npc_population.state.records[SectRouteCatalog.STEWARDS[faction_id]]["mode"]=="recovering","Ordinary walking/load does not heal a withdrawn steward")
	_check(hub.enter_exterior(&"tv02_pine_court"),"Saved guest permission permits its known inner map")
	await _close(); await _open(); hub=flow.active_scene as ExteriorHub
	_check(hub.outside and hub.exterior.room_id==&"tv02_pine_court","Cold launch restores the real sect geographical anchor")
	await _close()
	print("RESULT sect_routes checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures==0 else 1)

func _at(key: StringName) -> void:
	PlayerTravel.relocate(hub.player,hub.exterior.to_global(hub.exterior.interactions[key]))
	hub.door_latched=false
	await _step(4)

func _choose(id: StringName) -> void:
	for _index: int in 30:
		if not hub.dialogue.is_typing() and hub.dialogue.page_index==hub.dialogue.pages.size()-1: break
		hub.dialogue.advance()
	hub.dialogue.select_choice(id)
	await _step(3)

func _walk_to(x: float) -> void:
	var action: StringName=&"move_right" if hub.exterior.to_local(hub.player.global_position).x<x else &"move_left"
	var direction: float=1.0 if action==&"move_right" else -1.0
	Input.action_press(action)
	for _index: int in Engine.physics_ticks_per_second*18:
		if (x-hub.exterior.to_local(hub.player.global_position).x)*direction<8: break
		await _step(1)
	Input.action_release(action)
	await _step(3)
	_check(absf(hub.exterior.to_local(hub.player.global_position).x-x)<45 and hub.player.motor.is_grounded(),"Main terrain is traversable on foot to x=%.0f in %s" % [x,hub.exterior.room_id])

func _journal() -> void:
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size=extent
		await _key(root,KEY_M)
		var screen: InventoryScreen=hub.gear.modal as InventoryScreen
		await _step(4)
		var journal: QuestJournal=screen.journal
		_check(screen.is_open and journal.graph.buttons.size()==13,"Map journal includes all thirteen locations at %s" % extent)
		_check(SectJourneyProgress.rows(flow.profile).size()==2,"Both completed sect quests remain readable")
		_check(root.get_visible_rect().encloses(screen.panel.get_global_rect()),"Inventory/map panel fits viewport")
		journal.select_quest(&"sect_xich_lo")
		await _step(2)
		var regions: Array[Rect2]=[]
		for button: Button in journal.graph.buttons.values():
			_check(Rect2(Vector2.ZERO,journal.graph.size).encloses(button.get_rect()),"Map location stays inside graph")
			for prior: Rect2 in regions: _check(not prior.intersects(button.get_rect()),"Map locations do not overlap")
			regions.append(button.get_rect())
		await _picture("sect_journal_%d" % extent.x)
		screen.close(); await _step(3)

func _quest_tracking(faction_id: String) -> void:
	await _key(root,KEY_M)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	var journal: QuestJournal=screen.journal
	journal.select_quest(StringName("sect_"+faction_id))
	var navigator: QuestNavigator=screen.get_node("QuestNavigator") as QuestNavigator
	navigator.track(StringName("sect_"+faction_id))
	_check(navigator.resolve().get("anchor")==&"sect_marker_west","Tracked sect mission points to first unobserved physical marker")
	_check(journal.detail_fields[&"objective"].text.contains(SectRouteCatalog.title(SectRouteCatalog.first(faction_id))),"Quest detail identifies the actual sect map")
	await _picture("sect_quest_"+faction_id)
	screen.close(); await _step(3)
	_check(navigator.visible,"Quest arrow actually appears after closing the map")
