extends "res://tests/combined_combat_gameplay_probe.gd"
## One bounded earned-save native loop; all gameplay mutations come from UI/input.
const Guide=preload("res://scripts/ui/rune_preparation.gd")
var craft_receipt: Dictionary={}
var quest_views: Array[Dictionary]=[]
func scroll_click(button: Button) -> void:
	if button==null:await _click(button);return
	var parent: Node=button.get_parent()
	while parent!=null and not parent is ScrollContainer:parent=parent.get_parent()
	if parent is ScrollContainer:
		var scroll: ScrollContainer=parent as ScrollContainer
		for i: int in 24:
			var area: Rect2=scroll.get_global_rect().grow(-5)
			var point: Vector2=button.get_global_rect().get_center()
			if area.has_point(point):break
			for down: bool in [true,false]:
				var e:=InputEventMouseButton.new();e.position=area.get_center();e.button_index=MOUSE_BUTTON_WHEEL_DOWN if point.y>area.end.y else MOUSE_BUTTON_WHEEL_UP;e.pressed=down;root.push_input(e,true)
			await _step(3)
	await _click(button)
func _run() -> void:
	native=DisplayServer.get_name()!="headless"
	await super._run()
func dungeon() -> bool:
	if not await paid_preparation():return false
	var completed: bool=await super.dungeon()
	if completed:
		var view: Dictionary=Guide.view(flow.profile,hub.gear.inventory,hub.rune_learning)
		quest_views.append({"where":"after_opening_return","view":view})
		_check(view["state"]=="crafted_this_session" and view["owned"]>=2,"Actual paid preparation notice and owned rune survive ordinary combat scene replacement")
	return completed
func paid_preparation() -> bool:
	_stage("optional_preparation_then_paid_craft")
	if not await _talk(hub,NpcCatalog.HEALER):return false
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_rune_preparation") as Button);await pause(.6)
	var panel: VBoxContainer=hub.station_content.get_node_or_null("RunePreparationPanel") as VBoxContainer
	if not _check(panel!=null and panel.get("last_view")["state"]=="choose_rune","Guide opens without automatic goal or reward"):return false
	await _click(panel.get("choice") as OptionButton);await pause(.2)
	for code: Key in [KEY_DOWN,KEY_DOWN,KEY_ENTER]:
		for down: bool in [true,false]:
			var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=down;root.push_input(e,true);await _step(2)
	await pause(.4)
	if not _check(panel.get("last_view")["state"]=="already_prepared","Selecting owned Fire recognizes preparation without requiring another craft"):return false
	await _shot("combined_quest_owned_fire")
	await _click(panel.get("extra_button") as Button);await pause(.4)
	if not _check(panel.get("last_view")["state"]=="ready_to_craft","Explicit extra craft uses genuinely carried earned materials"):return false
	quest_views.append({"where":"before_paid_craft","view":panel.get("last_view").duplicate(true)})
	await scroll_click(panel.get("service_button") as Button);await pause(.6)
	if not _check(hub.current_station==&"rune_learning" and hub.rune_learning.quote(&"fire")["can_craft"],"Guide opens existing canonical craft service"):return false
	var inv: GearInventory=hub.gear.inventory
	var before: Dictionary=GearInventoryCodec.encode(inv);var ids: Array=inv.items.keys();var count: int=Guide.owned(inv,&"fire")
	await _click(hub.station_content.find_child("RuneService_fire",true,false) as Button);await pause(.5)
	var confirm: Button=hub.station_content.find_child("ConfirmPurchase",true,false) as Button
	if not _check(confirm!=null and Guide.owned(inv,&"fire")==count,"Craft confirmation does not grant early"):return false
	await _click(confirm);await pause(.8)
	var added: Array=inv.items.keys().filter(func(uid: int)->bool:return not ids.has(uid))
	craft_receipt={"before":before,"after":GearInventoryCodec.encode(inv),"new_uids":added}
	for id: StringName in RuneLearningService.CRAFT_COST:
		_check(inv.materials[id]==int(before["materials"][String(id)])-RuneLearningService.CRAFT_COST[id],"Real craft charges exact cost:"+String(id))
	_check(added.size()==1 and inv.items[added[0]].kind==&"rune" and inv.items[added[0]].definition_id==&"fire" and inv.items[added[0]].source==&"crafted" and Guide.owned(inv,&"fire")==count+1,"Existing owner saves exactly one new Fire UID")
	var view: Dictionary=Guide.view(flow.profile,inv,hub.rune_learning)
	quest_views.append({"where":"after_paid_craft","view":view})
	_check(view["state"]=="crafted_this_session","Guide completion follows the successful paid commit")
	await _shot("combined_paid_craft_confirmation");await _key(KEY_ESCAPE);await pause(.4)
	if not await _talk(hub,NpcCatalog.HEALER):return false
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_rune_preparation") as Button);await pause(.6)
	await _shot("combined_saved_rune_and_use_step");await pause(.8);await _key(KEY_ESCAPE);await pause(.3)
	return failures==0
func finish_combat(complete: bool) -> void:
	var f:=FileAccess.open(evidence.path_join("combined-quest-receipt.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"complete":complete,"checks":checks,"failures":failures,"craft":craft_receipt,"views":quest_views,"profile_sha256_before_teardown":FileAccess.get_sha256(profile_path),"npc_sha256_before_teardown":FileAccess.get_sha256(profile_path+".npc_v1.json"),"scope":"H7 earned QA; guide selection, explicit extra, paid Fire craft before unchanged IceThermal/Runic opening loop; no grant or save edit"},"\t"));f.close()
	await super.finish_combat(complete)
