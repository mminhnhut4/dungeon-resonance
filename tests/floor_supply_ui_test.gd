extends SceneTree
var checks: int=0
var failures: int=0
var flow: GameFlow
var attacks: int=0
func _initialize() -> void:call_deferred("run")
func step(n: int) -> void:
	for i: int in n:await physics_frame;await process_frame
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+message)
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true);await step(2)
func click(control: Control) -> void:
	var point: Vector2=control.get_global_rect().get_center();var move:=InputEventMouseMotion.new();move.position=point;root.push_input(move,true)
	for down: bool in [true,false]:
		var e:=InputEventMouseButton.new();e.position=point;e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;root.push_input(e,true);await step(2)
func picture(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(name+".png"))
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	root.unfocusable=true;Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	# Product stretch keeps a16:9 canvas (800x450 inside an800x600 window).
	# Also exercise an exact800x600 canvas as a layout fixture; no project setting changes.
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override="user://floor-supply-ui/profile.json";root.add_child(flow);current_scene=flow;await step(12)
	var hub: PrologueHub=flow.active_scene as PrologueHub;var screen: InventoryScreen=hub.gear.modal as InventoryScreen;var journal: QuestJournal=screen.journal
	flow.profile.record_boss_defeat("supply_ui_history_fixture");flow.depth_progress.accept();flow.depth_progress.record(&"depth_floor_1",1);flow.depth_progress.record(&"depth_floor_2",2)
	var before: PackedByteArray=FileAccess.get_file_as_bytes(flow.profile.save_path)
	hub.player.equipped_weapon.attack_committed.connect(func(_snapshot: AttackSnapshot) -> void:attacks+=1)
	for size: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size=size;await step(8);await key(KEY_M);await step(5)
		check(root.get_visible_rect().size.is_equal_approx(Vector2(size)),"Requested canvas dimensions are the actual tested dimensions")
		check(screen.is_open and screen.tabs.current_tab==2,"M opens the existing map modal")
		if not journal._supply_open:await click(journal.supply_button)
		await step(6)
		check(journal.supply_board.visible and not journal.columns.visible,"Sources occupy their own page rather than covering gameplay")
		check(not hub.player.controls_enabled and is_equal_approx(Engine.time_scale,.1),"Sources reuse the inventory control/time claim")
		check(root.get_visible_rect().encloses(screen.panel.get_global_rect()),"Map shell fits the actual viewport")
		check(screen.panel.get_global_rect().encloses(journal.supply_button.get_global_rect()) and screen.panel.get_global_rect().encloses(journal.supply_board.get_global_rect()),"Page toggle and scroll remain inside modal at both viewport sizes")
		var board: VBoxContainer=journal.supply_board
		check(board.get("cells").size()==3 and board.get("service_hint").text.contains(NpcCatalog.NAMES[NpcCatalog.HEALER]),"All three source rows point to the actual existing service owner")
		check((board.get("cells")[0]["source"] as Label).text.contains("100%") and (board.get("cells")[1]["unlock"] as Label).text.contains("Đã hoàn tất"),"Guaranteed chance and canonical completion are visible")
		await picture("supply_board_%d"%size.x)
		board.get("scroll").scroll_vertical=1000;await step(5);await picture("supply_use_%d"%size.x)
		check(FileAccess.get_file_as_bytes(flow.profile.save_path)==before,"Opening/scrolling source rows cannot save or grant")
		check(attacks==0,"Source-page clicks do not leak into a gameplay attack")
		await key(KEY_ESCAPE);await step(5)
		check(not screen.is_open and hub.player.controls_enabled and is_equal_approx(Engine.time_scale,1),"Esc returns controls and time to gameplay")
	await key(KEY_M);await step(4);await click(journal.power_button);await step(4)
	check(not journal._supply_open and journal.columns.visible and not journal.supply_board.visible,"Existing power action cleanly leaves the source page")
	await key(KEY_ESCAPE);flow.queue_free();current_scene=null;await step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT FloorSupplyUI checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
