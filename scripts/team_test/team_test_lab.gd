class_name TeamTestLab
extends Node2D
## This scene is never referenced by the normal main scene. Its launcher redirects
## the complete process user directory before any autoload starts.
var flow: GameFlow
var standalone: Node2D
var maps: Array[Dictionary]=[]
var selected: int=0
var preset: int=0
var branch: String="cloud_return"
var slot: int=0
var godmode: bool=false
var infinite_mana: bool=false
var relic_index: int=-1
var loading: bool=false
var last_error: String=""
var meta:=ConfigFile.new()
var panel: PanelContainer
var badge: Label
var notice: Label
var map_picker: OptionButton
var weapon_picker: OptionButton
var equipment_picker: OptionButton
var recipe_picker: OptionButton
var preset_picker: OptionButton
var branch_picker: OptionButton
var quality_picker: OptionButton
var enhancement: SpinBox
var god_button: CheckBox
var mana_button: CheckBox
var _previous_controls: bool=true
func _ready() -> void:
	if not TeamTestSeed.isolated():
		var message:=Label.new();message.text="TEAM TEST cần launcher CHAY_TEAM_TEST.cmd để tách save. Không nạp profile.";add_child(message);return
	maps=TeamTestCatalog.maps()
	meta.load("user://team_test_session.cfg")
	selected=clampi(int(meta.get_value("session","map",0)),0,maps.size()-1)
	preset=clampi(int(meta.get_value("session","preset",0)),0,3)
	slot=maxi(0,int(meta.get_value("session","slot",0)))
	branch=str(meta.get_value("session","branch","cloud_return"))
	relic_index=clampi(int(meta.get_value("session","relic",-1)),-1,3)
	if branch not in ["cloud_return","tether_sigil"]:branch="cloud_return"
	_build_ui();load_map(selected)
func profile_path() -> String:return "user://team_test_%d_p%d_%s.json"%[slot,preset,branch]
func active_world() -> Node2D:return standalone if is_instance_valid(standalone) else flow.active_scene if is_instance_valid(flow) else null
func hero() -> Player:
	var view: Node2D=active_world()
	return view.get("player") as Player if is_instance_valid(view) else null
func gear() -> GearSession:
	var view: Node2D=active_world()
	return view.get("gear") as GearSession if is_instance_valid(view) else null
func _message(text: String,ok: bool=true) -> bool:
	last_error="" if ok else text
	if notice!=null:notice.text=text
	return ok
func save_session() -> bool:
	if not TeamTestSeed.isolated():return false
	meta.set_value("session","map",selected);meta.set_value("session","preset",preset)
	meta.set_value("session","slot",slot);meta.set_value("session","branch",branch)
	meta.set_value("session","relic",relic_index)
	if meta.save("user://team_test_session.cfg")!=OK:return _message("Không lưu được cấu hình TEAM TEST",false)
	if is_instance_valid(flow) and gear()!=null:
		flow.profile.hub_inventory=GearInventoryCodec.encode(gear().inventory)
		if not flow.profile.save():return _message("Profile QA từ chối ghi; giữ scene hiện tại",false)
	return true
func _clear_world() -> void:
	for node: Node in [flow,standalone]:
		if is_instance_valid(node):
			TimeScaleClaims.release_subtree(node);remove_child(node);node.queue_free()
	flow=null;standalone=null
	await get_tree().process_frame;await get_tree().process_frame
func load_map(index: int) -> bool:
	if loading or not TeamTestSeed.isolated() or index<0 or index>=maps.size():return false
	loading=true
	if not save_session():loading=false;return false
	await _clear_world()
	selected=index
	var saved: SanctuaryProfile=TeamTestSeed.prepare(profile_path(),preset,branch)
	if saved==null:loading=false;return _message("Không tạo/nạp được profile QA hợp lệ",false)
	flow=load("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override=profile_path();add_child(flow)
	var entry: Dictionary=maps[index];var kind: String=entry["kind"];var value: Variant=entry["value"]
	var ok: bool=true
	var hub:=flow.active_scene as ExteriorHub
	if kind in ["hub","home"]:
		if hub.outside:ok=hub.return_to_hub()
		if kind=="home" and ok:ok=hub.enter_house()
	elif kind in ["exterior","corridor"]:
		ok=hub.enter_exterior(StringName(value) if kind=="exterior" else &"o01_p02",&"main" if kind=="exterior" else &"guard_corridor")
	elif kind=="opening":
		flow.start_campaign();ok=flow.active_scene is DepthCampaign
		if ok and int(value)>1:ok=(flow.active_scene as DepthCampaign).enter_stage(int(value))
	elif kind in ["depth","member"]:
		ok=flow.start_depth_campaign(int(value) if kind=="depth" else 1)
		if ok and kind=="member":
			# Deliberate debug entry in a separately seeded profile. Production gate
			# code and its sequential/quest checks are unchanged.
			var run:=flow.active_scene as MemberDungeonCampaign
			run.member_active=true;run.member_floor=int(value)-1
			ok=run._enter_member_floor(int(value))
	else:
		var path: String="res://scenes/dungeon_run.tscn" if kind=="alpha" else "res://scenes/linear_campaign.tscn" if kind=="linear" else "res://scenes/world_campaign.tscn" if kind=="world" else "res://scenes/test_level.tscn" if kind=="training" else "res://scenes/rooms/member_actor_arena.tscn"
		if kind=="style_lab":path="res://scenes/cultivation/style_lab.tscn"
		flow._clear()
		standalone=load(path).instantiate() as Node2D
		if kind=="style_lab":standalone.set("fixture_unlocks",false)
		if standalone is DungeonRun:
			standalone.set("profile",flow.profile);standalone.set("world_building_enabled",true)
			standalone.set("starting_inventory",GearInventoryCodec.decode(flow.profile.hub_inventory))
			if standalone is LinearCampaign:standalone.set("initial_stage",int(value))
		add_child(standalone)
		if kind=="alpha" and int(value)>1:ok=(standalone as DungeonRun).enter_room(int(value))
		if kind=="actor":(standalone as MemberActorArena).reset_trial(int(value))
		if gear()!=null and kind in ["training","style_lab","actor"]:
			GearInventoryCodec.copy_into(gear().inventory,GearInventoryCodec.decode(flow.profile.hub_inventory))
			var progression:=PermanentProgressionComponent.new();standalone.add_child(progression);progression.initialize(gear(),flow.profile)
			if kind in ["training","style_lab"]:standalone.get("survival").profile=flow.profile
		if kind=="style_lab":
			var styles: Array[StringName]=[&"cloud_return",&"tether_sigil"]
			standalone.get("techniques").apply_progress_snapshot(styles,StringName(branch))
			standalone.get("candidate_hint").hide()
		if flow.cultivation_session!=null:flow.cultivation_session.bind_scene(standalone)
	loading=false
	if hero()!=null:
		_bind_relics()
		if panel.visible:active_world().process_mode=Node.PROCESS_MODE_DISABLED
	map_picker.select(selected)
	preset_picker.select(preset);branch_picker.select(0 if branch=="cloud_return" else 1)
	if gear()!=null:
		var item: GearItem=gear().inventory.items[gear().inventory.equipped_weapon_uid]
		var weapon_index: int=TeamTestCatalog.WEAPONS.find(item.definition_id)
		if weapon_index>=0:weapon_picker.select(weapon_index)
		quality_picker.select(item.quality);enhancement.value=item.enhancement_level
	meta.set_value("session","map",selected);meta.save("user://team_test_session.cfg")
	if ok:print("TEAM_TEST_READY map=%s preset=%d slot=%d"%[entry["id"],preset,slot])
	return _message("Đã mở: "+str(entry["label"]),ok)
func _bind_relics() -> void:
	var g: GearSession=gear()
	if g.relics==null:
		g.relics=RelicRuntime.new();g.add_child(g.relics);g.relics.initialize(hero(),hero().resonance_controller.executor)
	for item: GearItem in g.inventory.items.values():
		if item.kind==&"relic":g.relics.acquire(item.definition_id)
	g.relics.clear_equipped()
	if relic_index>=0:g.relics.equip(RelicRuntime.CATALOG[relic_index].id,0)
func select_preset(value: int,next_branch: String="") -> bool:
	if loading:return false
	if not save_session():return false
	loading=true
	preset=clampi(value,0,3)
	if next_branch in ["cloud_return","tether_sigil"]:branch=next_branch
	godmode=false;infinite_mana=false;relic_index=-1;god_button.set_pressed_no_signal(false);mana_button.set_pressed_no_signal(false)
	# Release the old flow before saving under the newly selected namespace.
	await _clear_world()
	loading=false
	return await load_map(selected)
func reset_profile() -> bool:
	if loading:return false
	if not save_session():return false
	loading=true;await _clear_world();slot+=1;loading=false
	godmode=false;infinite_mana=false;god_button.set_pressed_no_signal(false);mana_button.set_pressed_no_signal(false)
	return await load_map(selected) # Old slot files stay intact for recovery.
func set_godmode(enabled: bool) -> void:
	godmode=enabled
	if hero()!=null:hero().health.minimum_health=1.0 if enabled else 0.0
func set_infinite_mana(enabled: bool) -> void:infinite_mana=enabled
func refill() -> bool:
	if gear()==null or hero()==null or loading:return false
	flow.profile.coins=50000;flow.profile.souls=50000
	for id: StringName in MaterialCatalog.IDS:
		if id in [&"aptitude_herb",&"aptitude_pill"]:continue # Lineage stays with harvest/craft owner.
		flow.profile.material_stash[id]=200;gear().inventory.materials[id]=200
	for id: StringName in gear().inventory.consumables:gear().inventory.consumables[id]=20
	gear().inventory.changed.emit();hero().health.reset_health();hero().energy.reset()
	return _message("Đã nạp HP/mana, tiền, vật liệu và vật phẩm QA",save_session())
func equip_weapon(id: StringName,quality: int,level: int) -> bool:
	if gear()==null or hero()==null or hero().health.current_health<=0:return false
	var inv: GearInventory=gear().inventory;var item: GearItem
	for candidate: GearItem in inv.items.values():
		if candidate.kind==&"weapon" and candidate.definition_id==id:item=candidate;break
	if item==null:
		if inv.equipment_bag_uids().size()>=GearInventory.EQUIPMENT_BAG_CAPACITY:return _message("Túi20món: tháo/dỡ đồ trước khi cấp món mới",false)
		item=inv.add_item(&"weapon",id)
	item.quality=clampi(quality,0,5);item.enhancement_level=clampi(level,0,12);item.source=&"";item.broken=false
	return _message("Đã chọn vũ khí · "+str(id),inv.equip_equipment(item.uid) and save_session())
func equip_equipment(path: String,quality: int) -> bool:
	if gear()==null:return false
	var inv: GearInventory=gear().inventory;var definition:=load(path) as EquipmentData;var item: GearItem
	for candidate: GearItem in inv.items.values():
		if candidate.equipment_definition==definition:item=candidate;break
	if item==null:item=inv.add_equipment(definition,quality)
	if item==null:return _message("Túi đầy; tháo/dỡ món trước",false)
	item.quality=clampi(quality,0,5);item.source=&"";item.broken=false
	return _message("Đã mặc · "+definition.item_name,inv.equip_equipment(item.uid) and save_session())
func equip_recipe(index: int) -> bool:
	if gear()==null or index<0 or index>=TeamTestCatalog.RECIPES.size():return false
	var recipe:=load(TeamTestCatalog.RECIPES[index]) as ResonanceDefinition
	var inv: GearInventory=gear().inventory
	if recipe.recipe_rune_ids.size()>inv.catalyst_capacity:
		# Explicit TEAM TEST slot grant only; preserve normal slot/cost logic.
		flow.profile.permanent_upgrades[&"rune_capacity"]=2
		inv.permanent_rune_capacity=2;flow.profile.changed.emit();gear().sync_quality()
	for rune: RuneData in GearInventory.RUNES:
		if inv.bag[rune.id]<5:
			for i: int in 5-inv.bag[rune.id]:inv.add_rune(rune.id)
	return _message("Ghép exact · "+str(recipe.id),inv.equip_catalyst_set(recipe.recipe_rune_ids) and save_session())
func equip_relic(index: int) -> bool:
	if gear()==null:return false
	relic_index=index
	_bind_relics()
	return _message("Đã chọn cổ vật / tắt cổ vật")
func set_rune_quality(value: int) -> bool:
	if gear()==null:return false
	for item: GearItem in gear().inventory.items.values():
		if item.kind in [&"rune",&"catalyst"]:item.quality=clampi(value,0,5)
	gear().inventory.changed.emit();gear().sync_quality()
	return _message("Đã đổi quality Bùa/Catalyst · "+GearItem.NAMES[clampi(value,0,5)],save_session())
func open_service(id: StringName) -> bool:
	if not is_instance_valid(flow) or not flow.active_scene is PrologueHub:return _message("Chọn bản đồ Căn cứ để mở dịch vụ",false)
	set_menu(false);(flow.active_scene as PrologueHub).open_station(id);return true
func set_menu(visible: bool) -> void:
	if panel==null:return
	panel.visible=visible
	var view: Node2D=active_world()
	if not is_instance_valid(view):return
	view.process_mode=Node.PROCESS_MODE_DISABLED if visible else Node.PROCESS_MODE_INHERIT
	if hero()!=null:
		if visible:_previous_controls=hero().controls_enabled;hero().controls_enabled=false
		else:hero().controls_enabled=_previous_controls and hero().health.current_health>0
func _input(event: InputEvent) -> void:
	if panel!=null and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_F10:
		set_menu(not panel.visible);get_viewport().set_input_as_handled()
func _unhandled_key_input(event: InputEvent) -> void:
	if selected<maps.size() and maps[selected]["kind"]=="style_lab" and not panel.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_G:
		standalone.get("techniques").request_skill(hero().aim.target_position);get_viewport().set_input_as_handled()
func _physics_process(_delta: float) -> void:
	if hero()==null:return
	hero().health.minimum_health=1.0 if godmode else 0.0
	if infinite_mana:hero().energy.reset()
func _process(_delta: float) -> void:
	if badge==null:return
	badge.text="TEAM TEST · F10 menu · %s · Bất tử:%s · Mana∞:%s"%[["Yếu","Vừa","Mạnh","Tối đa"][preset],"BẬT" if godmode else "tắt","BẬT" if infinite_mana else "tắt"]
	if hero()!=null:badge.text+=" · HP%.0f/%.0f · Mana%.0f/%.0f"%[hero().health.current_health,hero().health.maximum_health,hero().energy.current,hero().energy.maximum]
func _button(parent: Node,text: String,action: Callable) -> Button:
	var button:=Button.new();button.text=text;button.pressed.connect(action);parent.add_child(button);return button
func _label(parent: Node,text: String) -> Label:
	var label:=Label.new();label.text=text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;parent.add_child(label);return label
func _picker(parent: Node,items: Array[String]) -> OptionButton:
	var picker:=OptionButton.new();picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	for text: String in items:picker.add_item(text)
	parent.add_child(picker);return picker
func _build_ui() -> void:
	var canvas:=CanvasLayer.new();canvas.layer=100;add_child(canvas)
	badge=Label.new();badge.position=Vector2(12,0);badge.add_theme_color_override("font_color",Color("ffce71"));badge.add_theme_font_size_override("font_size",12);canvas.add_child(badge)
	panel=PanelContainer.new();panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE);panel.offset_left=-390;panel.offset_top=28;panel.offset_bottom=-8
	var background:=StyleBoxFlat.new();background.bg_color=Color("121820");background.content_margin_left=12;background.content_margin_right=12;background.content_margin_top=10;background.content_margin_bottom=10
	panel.add_theme_stylebox_override("panel",background);canvas.add_child(panel)
	var scroll:=ScrollContainer.new();panel.add_child(scroll)
	var box:=VBoxContainer.new();box.custom_minimum_size.x=340;box.size_flags_horizontal=Control.SIZE_EXPAND_FILL;scroll.add_child(box)
	_label(box,"TEAM TEST · save riêng · cheat mặc định TẮT")
	_button(box,"Đóng menu / F10",func()->void:set_menu(false))
	var names: Array[String]=[]
	for entry: Dictionary in maps:names.append(entry["label"])
	map_picker=_picker(box,names);map_picker.select(selected)
	_button(box,"Mở bản đồ / tầng đã chọn",func()->void:load_map(map_picker.selected))
	_button(box,"Reset encounter (giữ build)",func()->void:load_map(selected))
	preset_picker=_picker(box,["Yếu · kiếm+0/basic","Vừa · kiếm+1/Hỏa","Mạnh · trượng+2/BăngPhong","Tối đa · Divine+12/Trúc Cơ"])
	preset_picker.select(preset)
	branch_picker=_picker(box,["G · Hồi Phong Kiếm","G · Tỏa Linh Ấn"]);branch_picker.select(0 if branch=="cloud_return" else 1)
	_button(box,"Chọn preset / nhánh G",func()->void:select_preset(preset_picker.selected,"cloud_return" if branch_picker.selected==0 else "tether_sigil"))
	_label(box,"Hồi Phong: kiếm cổ, lướt né trúng đòn vật lý rồi G. Tỏa Linh: G đặt ấn, đợi ấn chín rồi G phát xung.")
	god_button=CheckBox.new();god_button.text="Bất tử (HP tối thiểu1)";god_button.toggled.connect(set_godmode);box.add_child(god_button)
	mana_button=CheckBox.new();mana_button.text="Mana vô hạn · vẫn giữ cooldown";mana_button.toggled.connect(set_infinite_mana);box.add_child(mana_button)
	_button(box,"Nạp HP/mana + tiền/vật liệu/vật phẩm",refill)
	_label(box,"Vũ khí / class · cấp thử theo UID, không cần loot")
	var weapon_names: Array[String]=[]
	for id: StringName in TeamTestCatalog.WEAPONS:weapon_names.append(str(id))
	weapon_picker=_picker(box,weapon_names);quality_picker=_picker(box,GearItem.NAMES)
	enhancement=SpinBox.new();enhancement.min_value=0;enhancement.max_value=12;enhancement.prefix="Cường hóa +";box.add_child(enhancement)
	_button(box,"Trang bị vũ khí / quality / +level",func()->void:equip_weapon(TeamTestCatalog.WEAPONS[weapon_picker.selected],quality_picker.selected,int(enhancement.value)))
	var equip_names: Array[String]=[]
	for path: String in TeamTestCatalog.EQUIPMENT:equip_names.append((load(path) as EquipmentData).item_name)
	equipment_picker=_picker(box,equip_names)
	_button(box,"Mặc trang bị (dùng quality đã chọn)",func()->void:equip_equipment(TeamTestCatalog.EQUIPMENT[equipment_picker.selected],quality_picker.selected))
	var recipe_names: Array[String]=[]
	for path: String in TeamTestCatalog.RECIPES:recipe_names.append(str((load(path) as ResonanceDefinition).id))
	recipe_picker=_picker(box,recipe_names)
	_button(box,"Lắp bộ bùa (cấp ô QA nếu cần)",func()->void:equip_recipe(recipe_picker.selected))
	_button(box,"Quality Bùa/Catalyst theo bậc đã chọn",func()->void:set_rune_quality(quality_picker.selected))
	var relic_names: Array[String]=["Không cổ vật"]
	for relic: RelicData in RelicRuntime.CATALOG:relic_names.append(str(relic.id))
	var relic_picker:=_picker(box,relic_names)
	_button(box,"Chọn cổ vật thử (slot1)",func()->void:equip_relic(relic_picker.selected-1))
	_label(box,"Dịch vụ thật tại Căn cứ; Tab/M/E và cơ chế gốc vẫn dùng được")
	for pair: Array in [["Tu luyện / G / dược",&"training"],["Kho",&"stash"],["Học/chế bùa",&"rune_learning"],["Rèn",&"smith_forge"],["Cường hóa",&"smith_enhance"],["Ghép đá",&"smith_stones"],["Dược phẩm",&"healer_consumables"],["Mua/bán",&"merchant"]]:
		_button(box,pair[0],open_service.bind(pair[1]))
	_button(box,"Lưu build QA",save_session)
	_button(box,"Reset save QA → slot mới (giữ bản cũ)",reset_profile)
	_label(box,"Progression bình thường: dùng CHAY_TIEN_TRINH_QA.cmd (profile khác). Không có tính năng ngoài runtime hiện có; tông môn quản trị/đồng hành chưa triển khai đầy đủ. Khựng/crash lịch sử vẫn còn mở.")
	notice=_label(box,"")
