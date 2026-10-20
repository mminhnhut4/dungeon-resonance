extends SceneTree
const Model=preload("res://scripts/cultivation/opening_cultivation_state.gd")
var flow: GameFlow
var checks: int=0
var failures: int=0
var captures: Array[String]=[]
func _initialize() -> void:_run.call_deferred()
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func step(count: int=3) -> void:
	for _i: int in count:await physics_frame;await process_frame
func key(code: Key) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;Input.parse_input_event(event);await step(2)
func click(button: Button) -> void:
	check(button!=null and button.is_visible_in_tree() and not button.disabled,"Real visible enabled button available")
	var point: Vector2=button.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down;root.push_input(event,true);await step(3)
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(name+".png"))==OK,"Runtime screenshot captured")
	captures.append(name)
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args() or qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=120;AudioServer.set_bus_mute(0,true)
	var profile:=SanctuaryProfile.new();profile.save_path="user://part3-ui-probe/profile.json"
	profile.opening_progress=OpeningProgress.with_event(profile.opening_progress,&"explored")
	profile.material_stash[&"crystal"]=66;profile.material_stash[&"dust"]=66
	var inventory: GearInventory=HubPreparation.starter_inventory(profile)
	inventory.add_rune(&"fire");inventory.add_rune(&"wind");inventory.equip(0,&"fire");inventory.equip(1,&"wind")
	profile.hub_inventory=GearInventoryCodec.encode(inventory);check(profile.save(),"Synthetic legacy before-image exists before v2 migration")
	profile.cultivation_progress=Model.new_progress(4);profile.profile_version=2
	var actor: Dictionary=profile.cultivation_progress["actors"]["player"]
	actor["stage"]=2;actor["energy"]=8;actor["mastery"]=4;actor["insight_ids"]=["explored"]
	check(profile.save(),"Synthetic earned stage uses a valid existing v2 save")
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=profile.save_path;root.add_child(flow);await step(14)
	var screen: InventoryScreen=flow.active_scene.gear.modal as InventoryScreen
	var journal: QuestJournal=screen.journal
	await key(KEY_M);await click(journal.power_button)
	check(journal.selected_id==PowerProgressionGuide.ID and screen.is_open,"Actual M and power click expose the guidance")
	for dims: Vector2i in [Vector2i(1152,648),Vector2i(800,600)]:
		if dims.x==800:root.content_scale_size=dims # Explicit compact logical viewport variant, not a project setting change.
		root.size=dims;await step(6)
		check(root.get_visible_rect().grow(2).encloses(screen.panel.get_global_rect()),"Whole modal stays inside its logical viewport %s"%str(root.get_visible_rect().size))
		check(screen.panel.get_global_rect().encloses(journal.power_button.get_global_rect()),"Power entry remains inside the frame")
		journal.detail_scroll.scroll_vertical=0;await step(3);await shot("power_top_%d"%dims.x)
		for field: StringName in [&"requirements",&"reward"]:
			if field==&"reward":journal.power_scroll.ensure_control_visible(journal.power_preview)
			journal.detail_scroll.ensure_control_visible(journal.detail_headers[field]);await step(2)
			journal.detail_scroll.scroll_vertical+=int(journal.detail_headers[field].get_global_rect().position.y-journal.detail_scroll.get_global_rect().position.y)
			await step(3);await shot("power_%s_%d"%[field,dims.x])
			if field==&"reward":check(journal.power_scroll.get_global_rect().grow(1).encloses(journal.power_preview.get_global_rect()),"Complete before/after example remains reachable in the left scroll viewport")
	var file:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("ui_probe.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":captures,"scope":"Synthetic stage/resource fixture; real M/mouse selection. First native1152 uses product stretch; second800 explicitly sets logical content_scale_size800x600 to inspect compact layout. No project setting change, manual play or audio claim."},"\t"));file.close()
	screen.close();flow.queue_free();await step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT Part3PowerUI checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
