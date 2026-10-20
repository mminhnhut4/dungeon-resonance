extends SceneTree
var flow: GameFlow
var hub: ExteriorHub
var checks: int = 0
var failures: int = 0
var report: Dictionary = {}
var destination: String
var profile_path: String = "user://audit/native_probe.json"

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + text)

func _step(n: int = 5) -> void:
	for _i: int in n:
		await physics_frame
		await process_frame

func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(destination.path_join(label + ".png")) == OK, "Capture " + label)

func _key(code: Key) -> void:
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code;event.physical_keycode=code;event.pressed=down
		root.push_input(event,true)
		await _step(2)

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	await _step(2)
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await _step(2)

func _open() -> void:
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override=profile_path;root.add_child(flow);current_scene=flow
	await _step(20)
	hub=flow.active_scene as ExteriorHub
	flow.cultivation_session.set_physics_process(false)
	_check(hub != null, "Actual main boots to ExteriorHub")

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(DisplayServer.get_name()!="headless" and not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Native renderer and isolated user data")
	if failures: quit(2);return
	root.unfocusable=true
	root.current_screen=mini(1,DisplayServer.get_screen_count()-1)
	root.position=DisplayServer.screen_get_position(root.current_screen)+Vector2i(20,20)
	root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	Engine.max_fps=120 if "--hz=120" in OS.get_cmdline_user_args() else 60;Engine.physics_ticks_per_second=Engine.max_fps
	AudioServer.set_bus_mute(0,true)
	destination=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");DirAccess.make_dir_recursive_absolute(destination)
	report={"engine":Engine.get_version_info(),"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),"resolution":root.size,"physics_hz":Engine.physics_ticks_per_second,"render_cap":Engine.max_fps,"automated_native":true,"audio_listened":false,"fixture_notes":"Fresh QA profile; direct existing travel owner calls. Seeded Legendary catalyst and five owned runes for HUD coverage, not natural acquisition."}
	await _open()
	_check(not flow.qa_tools_enabled,"Main QA cheats default off")
	await _shot("01_hub_fresh")
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	var nav: QuestNavigator=screen.get_node("QuestNavigator") as QuestNavigator
	screen.open_map();await _step(8)
	var quest: Button=screen.journal.quest_buttons[&"explored"] as Button
	await _click(quest)
	screen.close();await _step(6);nav.update_navigation()
	var tracked_before: StringName=nav.tracked_id()
	var visits: Array[Dictionary]=[]
	for i: int in 3:
		var initial_coins: int=flow.profile.coins
		var initial_inventory: Dictionary=GearInventoryCodec.encode(hub.gear.inventory)
		var start_usec: int=Time.get_ticks_usec()
		_check(hub.enter_exterior(&"o01_p01"),"Road entry %d" % (i+1))
		var entry_ms: float=(Time.get_ticks_usec()-start_usec)/1000.0
		await _step(20);nav.update_navigation()
		if i==0:
			report["navigation"]={"tracked_before":tracked_before,"completed":flow.profile.opening_progress["completed"].has("explored"),"tracked_after":nav.tracked_id(),"arrow_visible":nav.visible,"state":nav.state.duplicate(true)}
			_check(nav.tracked_id()==&"" and not nav.visible,"Completed road quest clears navigation while panel remains closed")
			await _shot("02_road_completed_arrow")
		start_usec=Time.get_ticks_usec()
		_check(hub.return_to_hub(),"Road return %d" % (i+1))
		var return_ms: float=(Time.get_ticks_usec()-start_usec)/1000.0
		await _step(24)
		var visible: bool=hub.presentation.atmosphere.room_art.is_visible_in_tree()
		visits.append({"round":i+1,"dungeon_room_art_visible_in_yard":visible,"entry_call_ms":entry_ms,"return_call_ms":return_ms,"coins_before":initial_coins,"coins_after":flow.profile.coins,"inventory_same":GearInventoryCodec.encode(hub.gear.inventory)==initial_inventory,"yard_visible":hub.yard.is_visible_in_tree(),"outside":hub.outside})
		_check(not visible,"Dungeon backdrop stays hidden after road return %d" % (i+1))
		_check(flow.profile.coins==initial_coins and GearInventoryCodec.encode(hub.gear.inventory)==initial_inventory,"Travel preserves currency and inventory %d" % (i+1))
		await _shot("03_hub_return_%d" % (i+1))
		_check(hub.enter_house(), "Home entry after road round %d" % (i+1))
		await _step(6)
		_check(hub.house.is_visible_in_tree() and not hub.yard.is_visible_in_tree() and not hub.presentation.atmosphere.room_art.is_visible_in_tree() and hub.presentation.foyer_art.decoration==null, "Home owns art after road round %d" % (i+1))
		if i==0: await _shot("03_home_after_road")
		_check(hub.leave_house(), "Home exit after road round %d" % (i+1))
		await _step(6)
		_check(hub.yard.is_visible_in_tree() and not hub.presentation.atmosphere.room_art.is_visible_in_tree(), "Yard remains painted after home exit %d" % (i+1))
	report["road_returns"]=visits
	screen.open_map();await _step(6);screen.close();await _step(6);nav.update_navigation()
	report["navigation_after_reopening"]={"tracked":nav.tracked_id(),"arrow_visible":nav.visible}
	var inventory: GearInventory=hub.gear.inventory
	var catalyst: GearItem=inventory.items[inventory.catalyst_uid] as GearItem
	catalyst.quality=GearItem.Quality.LEGENDARY;inventory.changed.emit()
	for id: StringName in [&"fire",&"fire",&"wind",&"lightning",&"lightning"]: inventory.add_rune(id)
	_check(inventory.equip_catalyst_set([&"fire",&"fire",&"wind",&"lightning",&"lightning"]),"Fixture equips five owned runes using inventory owner")
	hub.gear.sync_loadout();await _step(6)
	var hud: ArtHUD=hub.presentation.art_hud
	hud.refresh_hud()
	var installed: Array[RuneData]=hub.player.resonance_controller.catalyst_a.runtime_state.installed_runes
	var ids: Array[String]=[]
	for rune: RuneData in installed:ids.append(String(rune.id))
	var recipe: ResonanceDefinition=hub.player.resonance_controller.get_recipe()
	report["five_runes"]={"installed":ids,"hud_icons":hud.rune_icons.size(),"hud_ids":hud.rune_ids.duplicate(),"recipe":String(recipe.id) if recipe!=null else "none"}
	_check(installed.size()==5,"Five runes exist in runtime catalyst")
	_check(hud.rune_icons.size()>=installed.size(),"HUD shows all installed rune slots")
	await _shot("04_hud_five_runes")
	_check(hud.rune_ids==[&"fire",&"fire",&"wind",&"lightning",&"lightning"], "HUD preserves all five identities and duplicate order")
	root.size=Vector2i(800,600);await _step(8)
	_check(hud.rune_icons.all(func(icon: TextureRect) -> bool: return icon.is_visible_in_tree() and root.get_visible_rect().encloses(icon.get_global_rect())), "Five visible rune icons fit the 800px viewport")
	await _shot("04_hud_five_runes_800")
	root.size=Vector2i(1280,720);await _step(8)
	await _key(KEY_TAB);await _step(6)
	_check(screen.is_open,"Real Tab input opens inventory")
	await _shot("05_inventory_five_runes")
	screen.close();await _step(6)
	flow.queue_free();current_scene=null;await _step(8)
	root.get_node("AudioManager").stop_all()
	report["checks"]=checks;report["failures"]=failures
	var file:=FileAccess.open(destination.path_join("observations.json"),FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("RESULT NativeFocused checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
