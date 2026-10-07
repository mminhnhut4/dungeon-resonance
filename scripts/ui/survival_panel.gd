class_name SurvivalPanel
extends CanvasLayer

var session: Node
var panel: PanelContainer
var shell: VBoxContainer
var content_root: Control
var footer_stack: VBoxContainer
var details: Label
var item_list: ItemList
var button_row: HBoxContainer
var previous_controls: bool = true
var is_open: bool = false
var selected_uid: int = 0
var can_craft: bool = false
var status: Label
var tabs: TabContainer
var heading: Label
var selected_title: Label
var selected_state: Label
var selected_description: Label
var selected_image: TextureRect
var selected_pending: Label
var upgrade_cost: Label
var equip_button: Button
var dismantle_button: Button
var upgrade_button: Button
var close_button: Button
var inventory_button: Button
var relic_list: ItemList
var relic_selected: Label
var relic_description: Label
var resource_counts: Dictionary = {}
var craft_cards: Dictionary = {}
var use_cards: Dictionary = {}
var relic_cards: Array[ServiceItemCard] = []
var _equipment_uid: int = 0
var _relic_uid: int = 0

func _ready() -> void:
	layer = 35
	panel = PanelContainer.new()
	AntiqueSkin.apply_panel(panel)
	add_child(panel)
	content_root = Control.new()
	content_root.clip_contents = true
	panel.add_child(content_root)
	shell = VBoxContainer.new()
	shell.add_theme_constant_override("separation", 8)
	content_root.add_child(shell)
	var header := PanelContainer.new()
	header.add_theme_stylebox_override("panel", AntiqueSkin.texture_style(AntiqueSkin.HEADER,18,10))
	shell.add_child(header)
	var heading_column := VBoxContainer.new()
	heading_column.add_theme_constant_override("separation",3)
	header.add_child(heading_column)
	heading = DungeonUI.label("LỬA TRẠI",23,AntiqueSkin.WARM)
	heading_column.add_child(heading)
	details = DungeonUI.label("",14)
	heading_column.add_child(details)
	var resources := HBoxContainer.new()
	resources.add_theme_constant_override("separation",8)
	shell.add_child(resources)
	for id: StringName in [&"metal",&"dust",&"crystal",&"slime_essence"]:
		resources.add_child(_resource_chip(id))
	shell.add_child(AntiqueSkin.divider())
	tabs = TabContainer.new()
	tabs.name = "CampfireGroups"
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.clip_contents = true
	tabs.get_tab_bar().custom_minimum_size.y = 44
	content_root.add_child(tabs)
	_build_equipment_tab()
	_build_craft_tab()
	_build_use_tab()
	_build_relic_tab()
	tabs.tab_changed.connect(_tab_changed)
	footer_stack = VBoxContainer.new()
	footer_stack.add_theme_constant_override("separation",8)
	content_root.add_child(footer_stack)
	status = DungeonUI.label("",14,AntiqueSkin.WARM)
	status.custom_minimum_size.y = 20
	footer_stack.add_child(status)
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	footer_stack.add_child(footer)
	inventory_button = _button(footer,"Mở hành trang · Tab",_open_inventory)
	close_button = _button(footer,"Tiếp tục · C",close)
	close_button.name = "CloseCampfire"
	get_viewport().size_changed.connect(_resize)
	panel.minimum_size_changed.connect(_schedule_resize)
	shell.minimum_size_changed.connect(_schedule_resize)
	footer_stack.minimum_size_changed.connect(_schedule_resize)
	tabs.minimum_size_changed.connect(_schedule_resize)
	_resize.call_deferred()
	panel.hide()
	session.gear.inventory.changed.connect(refresh)
	if is_instance_valid(session.gear.relics): session.gear.relics.changed.connect(refresh)

func _resource_chip(id: StringName) -> Control:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.add_theme_stylebox_override("panel",AntiqueSkin.texture_style(AntiqueSkin.CARD,18,6))
	chip.tooltip_text = ItemArtCatalog.display_name(id) + " đang mang theo"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",6)
	chip.add_child(row)
	var art := TextureRect.new()
	art.texture = ItemArtCatalog.icon(id)
	art.custom_minimum_size = Vector2(32,32)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(art)
	var label := DungeonUI.label("",14,AntiqueSkin.JADE)
	resource_counts[id] = label
	row.add_child(label)
	return chip

func _build_equipment_tab() -> void:
	var row := HBoxContainer.new()
	row.name = "Trang bị"
	row.add_theme_constant_override("separation",12)
	tabs.add_child(row)
	item_list = _item_list()
	item_list.name = "EquipmentList"
	item_list.custom_minimum_size = Vector2(240,160)
	item_list.size_flags_stretch_ratio = 1.0
	item_list.item_selected.connect(_selected)
	row.add_child(item_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.3
	right.add_theme_constant_override("separation",6)
	row.add_child(right)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation",8)
	right.add_child(top)
	var slot := PanelContainer.new()
	slot.custom_minimum_size = Vector2(64,64)
	slot.add_theme_stylebox_override("panel",AntiqueSkin.texture_style(AntiqueSkin.SLOT,18,6))
	top.add_child(slot)
	selected_image = TextureRect.new()
	selected_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	selected_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(selected_image)
	selected_pending = DungeonUI.label("Chưa có\nảnh riêng",12,AntiqueSkin.MUTED)
	selected_pending.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot.add_child(selected_pending)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text)
	selected_title = DungeonUI.label("",18)
	text.add_child(selected_title)
	selected_state = DungeonUI.label("",14,AntiqueSkin.JADE)
	text.add_child(selected_state)
	var scroll := _scroll()
	scroll.custom_minimum_size.y = 80
	right.add_child(scroll)
	var selected_column := _scroll_column(scroll)
	selected_description = DungeonUI.label("",14,AntiqueSkin.MUTED)
	selected_column.add_child(selected_description)
	button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation",8)
	selected_column.add_child(button_row)
	equip_button = _button(button_row,"Trang bị",_equip_item)
	equip_button.name = "EquipSelected"
	dismantle_button = _button(button_row,"Rã món thừa",_dismantle)
	dismantle_button.name = "DismantleSelected"
	dismantle_button.add_theme_stylebox_override("normal",AntiqueSkin.texture_style(AntiqueSkin.HEADER,18,8))
	upgrade_cost = DungeonUI.label("",14,AntiqueSkin.MUTED)
	selected_column.add_child(upgrade_cost)
	upgrade_button = _button(selected_column,"Rèn lên Hiếm",_craft.bind(&"upgrade"))
	upgrade_button.name = "UpgradeSelected"

func _build_craft_tab() -> void:
	var scroll := _scroll()
	scroll.name = "Chế tạo"
	tabs.add_child(scroll)
	var column := _scroll_column(scroll)
	column.add_theme_constant_override("separation",8)
	column.add_child(DungeonUI.label("Chế tạo dùng nguyên liệu đang mang theo. Cần đứng tại lửa trại.",14,AntiqueSkin.MUTED))
	for id: StringName in [&"potion",&"bandage",&"trap"]:
		var card := ServiceItemCard.create(ItemArtCatalog.icon(id),OpeningItemPresentation.CONSUMABLE_NAMES[id],"","","Chế 1",_craft.bind(id))
		card.name = "Craft_" + String(id)
		craft_cards[id] = card
		column.add_child(card)

func _build_use_tab() -> void:
	var scroll := _scroll()
	scroll.name = "Sử dụng"
	tabs.add_child(scroll)
	var column := _scroll_column(scroll)
	column.add_theme_constant_override("separation",8)
	column.add_child(DungeonUI.label("Chỉ tiêu hao khi dùng được. Thuốc cần thiếu máu; băng gạc và giải độc cần đúng trạng thái.",14,AntiqueSkin.MUTED))
	for id: StringName in [&"potion",&"bandage",&"antidote",&"trap"]:
		var card := ServiceItemCard.create(ItemArtCatalog.icon(id),OpeningItemPresentation.CONSUMABLE_NAMES[id],OpeningItemPresentation.CONSUMABLE_DETAILS[id],"","Dùng 1",_use.bind(id))
		card.name = "Use_" + String(id)
		use_cards[id] = card
		column.add_child(card)

func _build_relic_tab() -> void:
	var row := HBoxContainer.new()
	row.name = "Cổ vật"
	row.add_theme_constant_override("separation",12)
	tabs.add_child(row)
	relic_list = _item_list()
	relic_list.name = "OwnedRelics"
	relic_list.custom_minimum_size = Vector2(240,160)
	relic_list.item_selected.connect(_relic_selected)
	row.add_child(relic_list)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	relic_selected = DungeonUI.label("Chọn cổ vật để gắn vào một trong ba ô.",16)
	right.add_child(relic_selected)
	relic_description = DungeonUI.label("",14,AntiqueSkin.MUTED)
	right.add_child(relic_description)
	var scroll := _scroll()
	right.add_child(scroll)
	var column := _scroll_column(scroll)
	column.add_theme_constant_override("separation",8)
	for index: int in 3:
		var card := ServiceItemCard.create(null,"Ô %d · Trống" % (index+1),"","","Gắn",_equip_relic.bind(index),true)
		card.name = "RelicSlot_%d" % index
		relic_cards.append(card)
		column.add_child(card)

func _item_list() -> ItemList:
	var list := ItemList.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.fixed_icon_size = Vector2i(48,48)
	list.icon_mode = ItemList.ICON_MODE_LEFT
	list.add_theme_constant_override("v_separation",8)
	return list

func _scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.follow_focus = true
	scroll.get_v_scroll_bar().custom_minimum_size.x = 12
	return scroll

func _scroll_column(scroll: ScrollContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right",14)
	scroll.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",6)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(column)
	return column

func _button(parent_node: Node, text: String, callable: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.pressed.connect(callable)
	parent_node.add_child(button)
	return button

func _resize() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	var extent: Vector2 = get_viewport().get_visible_rect().size
	panel.size = Vector2(minf(920,extent.x-32),minf(680,extent.y-32))
	panel.position = (extent-panel.size)*0.5
	var frame: StyleBox = panel.get_theme_stylebox("panel")
	var space: Vector2 = panel.size-Vector2(frame.get_content_margin(SIDE_LEFT)+frame.get_content_margin(SIDE_RIGHT),frame.get_content_margin(SIDE_TOP)+frame.get_content_margin(SIDE_BOTTOM))
	content_root.size = space
	shell.position = Vector2.ZERO
	shell.size = Vector2(space.x,shell.get_combined_minimum_size().y)
	footer_stack.size = Vector2(space.x,footer_stack.get_combined_minimum_size().y)
	footer_stack.position = Vector2(0,space.y-footer_stack.size.y)
	tabs.position = Vector2(0,shell.size.y+8)
	tabs.size = Vector2(space.x,maxf(0,footer_stack.position.y-tabs.position.y-8))
	panel.queue_sort()
	shell.queue_sort()
	footer_stack.queue_sort()
	tabs.queue_sort()

func _schedule_resize() -> void:
	if is_inside_tree() and not is_queued_for_deletion(): _resize.call_deferred()

func open(crafting: bool = false) -> void:
	if is_open or session.player.health.current_health <= 0: return
	session.gear.modal.close()
	is_open = true
	can_craft = crafting
	previous_controls = session.player.controls_enabled
	session.player.suspend_controls(true)
	status.text = ""
	panel.show()
	refresh()
	_resize.call_deferred()

func close() -> void:
	if not is_open: return
	is_open = false
	session.player.suspend_controls(not previous_controls or session.player.health.current_health <= 0)
	panel.hide()

func _open_inventory() -> void:
	close()
	session.gear.modal.open()

func _process(_delta: float) -> void:
	if is_open: refresh(false)

func refresh(rebuild_items: bool = true) -> void:
	if details == null: return
	var inventory: GearInventory = session.gear.inventory
	heading.text = "LỬA TRẠI · NGHỈ & CHẾ TẠO" if can_craft else "DÃ CHIẾN · CHĂM SÓC & TRANG BỊ"
	details.text = "%s · Áp lực %d/100 · Tàn Hồn %d · Linh Thạch %d (mang %d)" % [session.condition.summary(),roundi(session.condition.stress),session.profile.souls,session.profile.coins,inventory.run_coins]
	var captions: Dictionary = {&"metal":"Kim loại",&"dust":"Bột phép",&"crystal":"Tinh thạch",&"slime_essence":"Tinh chất"}
	for id: StringName in resource_counts: resource_counts[id].text = "%s\n%d" % [captions[id],inventory.materials.get(id,0)]
	if rebuild_items:
		item_list.clear()
		relic_list.clear()
		var uids: Array = inventory.items.keys()
		uids.sort()
		for uid: int in uids:
			var item: GearItem = inventory.items[uid]
			var list: ItemList = relic_list if item.kind == &"relic" else item_list
			var icon: Texture2D = OpeningItemPresentation.item_icon(item)
			var caption: String = "%s · %s" % [OpeningItemPresentation.item_name(item),GearItem.NAMES[item.quality]]
			if icon == null: caption += " · Chưa có ảnh riêng"
			list.add_item(caption,icon if icon != null else OpeningItemPresentation.MISSING_ICON)
			list.set_item_metadata(list.item_count-1,uid)
			list.set_item_tooltip(list.item_count-1,OpeningItemPresentation.description(item)+"\n"+OpeningItemPresentation.state(item,inventory))
		if not inventory.items.has(_equipment_uid) or inventory.items[_equipment_uid].kind == &"relic": _equipment_uid = inventory.equipped_weapon_uid if inventory.items.has(inventory.equipped_weapon_uid) else int(item_list.get_item_metadata(0)) if item_list.item_count > 0 else 0
		if not inventory.items.has(_relic_uid): _relic_uid = int(relic_list.get_item_metadata(0)) if relic_list.item_count > 0 else 0
		_select_uid(item_list,_equipment_uid)
		_select_uid(relic_list,_relic_uid)
		selected_uid = _relic_uid if tabs.current_tab == 3 else _equipment_uid
	_refresh_selected(inventory)
	_refresh_cards(inventory)

func _select_uid(list: ItemList, uid: int) -> void:
	for index: int in list.item_count:
		if int(list.get_item_metadata(index)) == uid:
			list.select(index)
			return

func _selected(index: int) -> void:
	selected_uid = int(item_list.get_item_metadata(index))
	_equipment_uid = selected_uid
	refresh(false)

func _relic_selected(index: int) -> void:
	selected_uid = int(relic_list.get_item_metadata(index))
	_relic_uid = selected_uid
	refresh(false)

func _tab_changed(index: int) -> void:
	selected_uid = _relic_uid if index == 3 else _equipment_uid
	refresh(false)
	_schedule_resize()

func _refresh_selected(inventory: GearInventory) -> void:
	var item: GearItem = inventory.items.get(_equipment_uid)
	selected_title.text = OpeningItemPresentation.item_name(item)
	selected_image.texture = OpeningItemPresentation.item_icon(item)
	selected_pending.visible = selected_image.texture == null
	selected_state.text = "%s · %s\n%s" % [OpeningItemPresentation.KIND_NAMES.get(item.kind,"Vật phẩm"),GearItem.NAMES[item.quality],OpeningItemPresentation.state(item,inventory)] if item != null else "Chưa chọn món"
	selected_description.text = OpeningItemPresentation.description(item)
	var equip_allowed: bool = item != null and item.can_equip() and item.kind in [&"weapon",&"catalyst",&"rune"]
	if item != null and item.kind == &"rune":
		var slot: int = session.gear.modal.selected_slot
		equip_allowed = equip_allowed and slot >= 0 and slot < inventory.slots.size() and not inventory.slot_uids.has(item.uid) and inventory.bag.get(item.definition_id,0)>0 and (slot not in [4,5] or GearInventory.CATALYST_INDICES.find(slot)<inventory.catalyst_capacity) and (slot not in [6,7] or slot-5<inventory.weapon_capacity)
	equip_button.disabled = not equip_allowed
	equip_button.tooltip_text = "Trang bị đúng món đang chọn." if equip_allowed else "Đồ hỏng/phôi cần thợ rèn. Áo, quần và phụ kiện được thay trong hành trang (Tab)."
	dismantle_button.disabled = not can_craft or not OpeningItemPresentation.dismantle_allowed(item,inventory)
	dismantle_button.tooltip_text = "Rã đúng món đang chọn để nhận nguyên liệu; món bị tiêu hao." if not dismantle_button.disabled else "Cần lửa trại và món chưa trang bị/khảm. Cổ vật được giữ nguyên."
	var quote: Dictionary = OpeningItemPresentation.craft_quote(inventory,&"upgrade",_equipment_uid)
	upgrade_button.disabled = not can_craft or not quote["allowed"]
	upgrade_cost.text = OpeningItemPresentation.cost_text(quote,inventory) if quote["metal"]>0 or quote["dust"]>0 else quote["reason"]
	upgrade_button.tooltip_text = "Cần lửa trại." if not can_craft else quote["reason"] if not quote["allowed"] else "Rèn đúng vũ khí Thường đang chọn lên Hiếm; giữ nguyên món và trạng thái hỏng."

func _refresh_cards(inventory: GearInventory) -> void:
	for id: StringName in craft_cards:
		var card: ServiceItemCard = craft_cards[id]
		var quote: Dictionary = OpeningItemPresentation.craft_quote(inventory,id)
		var cost: String = OpeningItemPresentation.cost_text(quote,inventory)
		card.detail_label.text = cost
		card.detail_label.show()
		card.quantity_label.text = "Trong túi %d" % inventory.consumables.get(id,0)
		card.quantity_label.show()
		card.disabled = not can_craft or not quote["allowed"]
		card.tooltip_text = "%s\n%s\n%s" % [card.item_title.text,cost,"Cần lửa trại." if not can_craft else quote["reason"] if not quote["allowed"] else "Chế một món vào túi; không tự sử dụng."]
	for id: StringName in use_cards:
		var card: ServiceItemCard = use_cards[id]
		var reason: String = _use_reason(id,inventory)
		card.quantity_label.text = "Trong túi %d" % inventory.consumables.get(id,0)
		card.quantity_label.show()
		card.disabled = not reason.is_empty()
		card.tooltip_text = card.item_title.text+"\n"+OpeningItemPresentation.CONSUMABLE_DETAILS[id]+("\n"+reason if not reason.is_empty() else "")
	var chosen: GearItem = inventory.items.get(_relic_uid)
	relic_selected.text = "Đang chọn: "+OpeningItemPresentation.item_name(chosen) if chosen != null else "Chưa có cổ vật trong túi."
	relic_description.text = OpeningItemPresentation.description(chosen) if chosen != null else "Chọn cổ vật để xem công dụng trước khi gắn."
	for index: int in relic_cards.size():
		var card: ServiceItemCard = relic_cards[index]
		var current: RelicData = session.gear.relics.equipped[index] if is_instance_valid(session.gear.relics) and index < session.gear.relics.equipped.size() else null
		card.item_title.text = "Ô %d · %s" % [index+1,current.display_name if current != null else "Trống"]
		card.text = "Gắn " + card.item_title.text
		card.item_icon.texture = ItemArtCatalog.icon(current.id) if current != null else null
		for child: Node in card.item_icon.get_parent().get_children():
			if child is Label:
				child.text = "Ô trống" if current == null else "Chưa có\nảnh riêng"
				child.visible = card.item_icon.texture == null
		card.quantity_label.text = "Đang gắn" if current != null else "Chưa gắn cổ vật"
		card.quantity_label.show()
		var allowed: bool = chosen != null and chosen.can_equip() and is_instance_valid(session.gear.relics)
		if allowed:
			allowed = session.gear.relics.owned.any(func(relic: RelicData) -> bool: return relic.id == chosen.definition_id) and not session.gear.relics.equipped.any(func(relic: RelicData) -> bool: return relic.id == chosen.definition_id) and index <= session.gear.relics.equipped.size()
		card.disabled = not allowed
		card.tooltip_text = (current.description if current != null else "Ô cổ vật trống.")+"\n"+("Gắn cổ vật đang chọn vào ô này." if allowed else "Chọn cổ vật đã sở hữu, chưa gắn; lấp ô theo thứ tự.")

func _use_reason(id: StringName, inventory: GearInventory) -> String:
	if session.player.health.current_health <= 0: return "Không thể dùng khi đã gục."
	if inventory.consumables.get(id,0)<=0: return "Trong túi chưa có món này."
	match id:
		&"potion":
			if session.player.health.current_health >= session.player.health.maximum_health: return "Máu đang đầy."
		&"bandage":
			if not session.condition.bleeding: return "Không bị chảy máu."
		&"antidote":
			var effects: ElementStatusController = session.player.hurtbox.damage_resolver.status_controller as ElementStatusController
			if effects == null or effects.poison_count <= 0: return "Không bị nhiễm độc."
		&"trap":
			if not session.player.is_on_floor(): return "Cần đứng trên mặt đất."
			if get_tree().get_nodes_in_group(&"floor_traps").size()>=8: return "Đã có 8 bẫy trên sàn."
	return ""

func _dismantle() -> void:
	var ok: bool = can_craft and session.gear.inventory.dismantle(selected_uid)
	status.text = "Đã rã món thừa." if ok else "Cần lửa trại và món chưa trang bị."
	refresh()


func _equip_item() -> void:
	var inventory: GearInventory = session.gear.inventory
	if not inventory.items.has(selected_uid):
		return
	var item: GearItem = inventory.items[selected_uid]
	if not item.can_equip():
		status.text = "Phôi cần thợ rèn chế tạo." if item.is_forging_blank() else "Trang bị hỏng: cần sửa trước khi dùng."
		return
	if item.kind == &"catalyst":
		inventory.catalyst_uid = selected_uid
	elif item.kind == &"weapon":
		inventory.explicit_weapon_selection = false
		inventory.equipped_weapon_uid = selected_uid
		session.player.equipped_weapon.equip(session.weapon_definition(item.definition_id))
	elif item.kind == &"relic":
		status.text = "Chọn ô cổ vật 1–3 ở hàng bên dưới."
		return
	else:
		status.text = "Đã khảm vào ô được chọn ở Tab." if inventory.equip_uid(session.gear.modal.selected_slot, selected_uid) else "Ô bị khóa hoặc bùa đang gắn."
		return
	inventory.changed.emit()
	status.text = "Đã trang bị %s." % GearItem.NAMES[item.quality]


func _craft(id: StringName) -> void:
	status.text = "Đã chế tạo / rèn." if can_craft and session.gear.inventory.craft(id, selected_uid) else "Thiếu nguyên liệu hoặc món không phù hợp."
	refresh()


func _use(id: StringName) -> void:
	status.text = "Đã sử dụng." if session.use_consumable(id) else "Không có vật phẩm / không cần dùng."
	refresh()


func _equip_relic(slot: int) -> void:
	var inventory: GearInventory = session.gear.inventory
	if not inventory.items.has(selected_uid) or inventory.items[selected_uid].kind != &"relic":
		status.text = "Hãy chọn một cổ vật trong túi."
		return
	var ok: bool = session.gear.relics.equip(inventory.items[selected_uid].definition_id, slot)
	status.text = "Đã gắn cổ vật ô %d." % (slot + 1) if ok else "Cổ vật đang gắn hoặc ô chưa hợp lệ."
