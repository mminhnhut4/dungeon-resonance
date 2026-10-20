extends SceneTree
var flow: GameFlow
var hub: ExteriorHub
var checks: int=0
var failures: int=0
var observations: Dictionary={}
var evidence: String
var PROFILE: String="user://verification/warehouse_quantity_%s.json" % ("120" if "--hz=120" in OS.get_cmdline_user_args() else "60")
var EXPECTED: String="user://verification/warehouse_quantity_expected_%s.json" % ("120" if "--hz=120" in OS.get_cmdline_user_args() else "60")

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step(n: int=5) -> void:
	for _i: int in n:await physics_frame;await process_frame
func _shot(label: String) -> void:
	if DisplayServer.get_name()=="headless":return
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"Capture "+label)
func _key(code: Key) -> void:
	for down: bool in [true,false]:
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=down
		root.push_input(event,true);await _step(2)
func _click(control: Control) -> void:
	var point: Vector2=control.get_global_rect().get_center()
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true);await _step(2)
	for down: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
		root.push_input(event,true);await _step(2)
func _enter_amount(amount: int) -> void:
	var spin: SpinBox=hub.station_content.find_child("WithdrawAmount_metal",true,false) as SpinBox
	_check(spin!=null, "Material quantity input exists")
	if spin==null: return
	var line: LineEdit=spin.get_line_edit()
	await _click(line);line.select_all()
	print("ENTRY_BEFORE editable=%s editing=%s max=%s" % [line.editable,line.is_editing(),spin.max_value])
	for character: String in str(amount):
		var event:=InputEventKey.new();event.unicode=character.unicode_at(0);event.keycode=character.unicode_at(0);event.physical_keycode=character.unicode_at(0);event.pressed=true
		root.push_input(event,true);await _step(1);event.pressed=false;root.push_input(event,true)
	var enter:=InputEventKey.new();enter.keycode=KEY_ENTER;enter.physical_keycode=KEY_ENTER;enter.pressed=true
	root.push_input(enter,true);await _step(2);enter.pressed=false;root.push_input(enter,true)
	print("ENTRY amount=%d text=%s value=%s focus=%s" % [amount,line.text,spin.value,root.gui_get_focus_owner()])
	_check(int(spin.value)==amount, "Real keyboard input selects amount %d" % amount)

func _widgets(node: Node,kind: String) -> int:
	var count: int=1 if node.is_class(kind) else 0
	for child: Node in node.get_children():count+=_widgets(child,kind)
	return count
func _snapshot() -> Dictionary:
	return {"coins":flow.profile.coins,"souls":flow.profile.souls,"stash":flow.profile.material_stash.duplicate(),"inventory":GearInventoryCodec.encode(hub.gear.inventory)}
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated warehouse QA user data")
	if failures:quit(2);return
	if DisplayServer.get_name()!="headless":
		root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1)
		root.position=DisplayServer.screen_get_position(root.current_screen)+Vector2i(20,20)
	root.size=Vector2i(1280,720);root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED;root.content_scale_size=Vector2i.ZERO
	Engine.max_fps=120 if "--hz=120" in OS.get_cmdline_user_args() else 60;Engine.physics_ticks_per_second=Engine.max_fps;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");DirAccess.make_dir_recursive_absolute(evidence)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=PROFILE
	root.add_child(flow);current_scene=flow;await _step(10)
	flow.cultivation_session.set_physics_process(false);hub=flow.active_scene as ExteriorHub
	if "--cold" in OS.get_cmdline_user_args():
		var expected: Variant=JSON.parse_string(FileAccess.get_file_as_string(EXPECTED))
		_check(expected is Dictionary,"Expected producer record available to new process")
		if expected is Dictionary:
			var now: Dictionary=_snapshot()
			_check(now["coins"]==expected["coins"] and now["souls"]==expected["souls"],"Cold process restores exact money/souls")
			_check(JSON.parse_string(JSON.stringify(now["stash"]))==expected["stash"],"Cold process restores exact warehouse material counts")
			_check(JSON.parse_string(JSON.stringify(now["inventory"]))==expected["inventory"],"Cold process restores complete UID/item/bag inventory")
			observations["cold_current"]=now
		await _finish();return
	PlayerTravel.relocate(hub.player,hub.stations[&"stash"].global_position);await _step(8);await _key(KEY_E);await _step(8)
	_check(hub.station_open and hub.current_station==&"stash","Actual E input opens warehouse")
	_check(hub.station_content.find_child("StashEmpty",true,false)!=null,"Fresh warehouse explicitly displays empty")
	_check(hub.station_content.find_child("WithdrawMaterial_*",true,false)==null,"Empty warehouse has no fake withdrawal row")
	await _shot("warehouse_empty")
	hub.close_station();await _step()
	var inventory: GearInventory=hub.gear.inventory
	flow.profile.coins=4321;flow.profile.souls=17
	flow.profile.material_stash[&"metal"]=8;inventory.materials[&"metal"]=5
	_check(hub.economy._save_safe(),"Synthetic finite warehouse fixture committed by existing writer")
	var items_before: Variant=GearInventoryCodec.encode(inventory)["items"]
	await _key(KEY_E);await _step(8)
	var button: Button=hub.station_content.find_child("WithdrawMaterial_metal",true,false) as Button
	_check(button!=null and button.text.begins_with("Rút 1") and not button.disabled,"Existing UI offers enabled Rút 1")
	observations["quantity_inputs"]={"spinboxes":_widgets(hub.station_content,"SpinBox"),"lineedits":_widgets(hub.station_content,"LineEdit"),"withdraw_label":button.text if button!=null else "missing"}
	button.grab_focus()
	var tab_event:=InputEventAction.new();tab_event.action=&"ui_focus_next";tab_event.pressed=true
	root.push_input(tab_event,true);await _step(2);tab_event.pressed=false;root.push_input(tab_event,true)
	_check(root.gui_get_focus_owner()==(hub.station_content.find_child("WithdrawAmount_metal",true,false) as SpinBox).get_line_edit(), "Keyboard Tab reaches quantity entry from Rút 1")
	await _shot("warehouse_stocked")
	if button!=null:await _click(button);await _step(8)
	_check(flow.profile.material_stash[&"metal"]==7 and inventory.materials[&"metal"]==6,"Real UI click transfers exactly one material")
	_check(flow.profile.coins==4321 and flow.profile.souls==17 and GearInventoryCodec.encode(inventory)["items"]==items_before,"Rút 1 preserves money, souls and every gear UID/item")
	await _shot("warehouse_after_withdraw_one")
	await _enter_amount(3)
	var selected: Button=hub.station_content.find_child("WithdrawQuantity_metal",true,false) as Button
	_check(selected!=null and selected.text=="Rút 3" and not selected.disabled, "Chosen quantity has a separate enabled Rút 3 action")
	await _shot("warehouse_select_three")
	await _click(selected);await _step(8)
	_check(flow.profile.material_stash[&"metal"]==4 and inventory.materials[&"metal"]==9,"Quantity three conserves total materials")
	var before: Dictionary=_snapshot();var bytes: PackedByteArray=FileAccess.get_file_as_bytes(PROFILE)
	for amount: int in [0,-1,5,MaterialCatalog.MAX_COUNT+1]:
		_check(not hub.economy.withdraw(&"metal",amount),"Reject invalid/excess quantity %d" % amount)
	_check(_snapshot()==before and FileAccess.get_file_as_bytes(PROFILE)==bytes,"Rejected amounts preserve all state and save bytes")
	flow.profile._writer.fault_plan={"write_candidate":true}
	await _enter_amount(2)
	await _click(hub.station_content.find_child("WithdrawQuantity_metal",true,false) as Button);await _step(8)
	_check(hub.station_notice.begins_with("Chưa rút"),"Injected save failure is reported by chosen-quantity UI")
	_check(_snapshot()==before and FileAccess.get_file_as_bytes(PROFILE)==bytes,"Failed save rolls back stash, bag, UIDs, money and save bytes")
	await _click(hub.station_content.find_child("WithdrawQuantity_metal",true,false) as Button);await _step(8)
	_check(hub.station_notice.begins_with("Đã rút 2"),"Chosen-quantity retry succeeds once")
	_check(flow.profile.material_stash[&"metal"]==2 and inventory.materials[&"metal"]==11,"Retry does not duplicate transfer")
	_check(flow.profile.coins==4321 and flow.profile.souls==17 and GearInventoryCodec.encode(inventory)["items"]==items_before,"All transfers preserve money and gear identities")
	# A live owner transaction changes stock after the UI quote was built.
	_check(hub.economy.withdraw(&"metal",1),"Fixture changes stock through the same transaction owner")
	before=_snapshot();bytes=FileAccess.get_file_as_bytes(PROFILE)
	await _click(hub.station_content.find_child("WithdrawQuantity_metal",true,false) as Button);await _step(8)
	_check(_snapshot()==before and FileAccess.get_file_as_bytes(PROFILE)==bytes,"Stale quantity two cannot withdraw the last one or write save")
	root.size=Vector2i(800,600);await _step(8)
	var small: Control=hub.station_content.find_child("WithdrawControls_metal",true,false) as Control
	_check(small!=null and small.get_global_rect().size.x<=hub.station_scroll.size.x and root.get_visible_rect().encloses(small.get_global_rect()),"Quantity controls stay inside warehouse panel at 800px")
	await _shot("warehouse_quantity_800")
	hub.close_station();await _step()
	observations["final"]=_snapshot();observations["native_ui_quantity_selection_present"]=true
	var file:=FileAccess.open(EXPECTED,FileAccess.WRITE);file.store_string(JSON.stringify(_snapshot()));file.close()
	await _finish()
func _finish() -> void:
	flow.queue_free();current_scene=null;await _step(8);root.get_node("AudioManager").stop_all()
	observations["checks"]=checks;observations["failures"]=failures
	var file:=FileAccess.open(evidence.path_join("warehouse.json"),FileAccess.WRITE);file.store_string(JSON.stringify(observations,"\t"));file.close()
	print("RESULT Warehouse checks=%d failures=%d" % [checks,failures]);quit(0 if failures==0 else 1)
