class_name InventoryScreen
extends GearInventoryModal
## Equipment UI over the existing rune modal, sharing its slowdown/input owner.

const SLOT_NAMES: Array[String] = EquipmentData.SLOT_NAMES
var tabs: TabContainer
var equipment_buttons: Array[Button] = []
var bag_buttons: Array[Button] = []
var bag_uids: Array[int] = []
var status: Label
var balances: Label
var carried_page: VBoxContainer
var _balance_profile: SanctuaryProfile
var tooltip: PanelContainer
var tooltip_name: Label
var tooltip_body: Label
var veil: ColorRect
var page: int = 0
var pager: Label
var open_button: Button
var map_button: Button
var content_scroll: ScrollContainer
var tooltip_scroll: ScrollContainer
var journal: QuestJournal
var tracker: PanelContainer
var tracker_label: Label
var selected_equipment_slot: int = 0
var _tooltip_anchor: Vector2
var _tooltip_control: WeakRef
var bag_grid: GridContainer
var rune_column: Control
var _progress_world: WeakRef
var _map_held: Dictionary = {}
var _map_detail_axis: float = 0.0
var _map_scroll_tick: int = 0


func _ready() -> void:
	super._ready()
	AntiqueSkin.apply_panel(panel)
	veil = ColorRect.new()
	veil.color = Color(0.025, 0.045, 0.065, 0.82)
	veil.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	add_child(veil)
	move_child(veil, 0)
	veil.hide()
	rune_column = panel.get_child(0) as Control
	panel.remove_child(rune_column)
	var rune_close: Button = rune_column.get_child(rune_column.get_child_count() - 1) as Button
	if rune_close != null:
		rune_column.remove_child(rune_close)
		rune_close.queue_free()
	var shell := VBoxContainer.new()
	panel.add_child(shell)
	content_scroll = ScrollContainer.new()
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.follow_focus = true
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.custom_minimum_size.y = 120
	shell.add_child(content_scroll)
	tabs = TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.add_child(tabs)
	var equipment_page := VBoxContainer.new()
	equipment_page.name = "Trang bị"
	equipment_page.add_theme_constant_override("separation", 12)
	tabs.add_child(equipment_page)
	var title := Label.new()
	title.text = "HÀNH TRANG"
	title.add_theme_font_size_override("font_size", 25)
	equipment_page.add_child(title)
	balances = DungeonUI.label("", 15, DungeonUI.WARM)
	balances.name = "InventoryBalances"
	balances.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipment_page.add_child(balances)
	var help := Label.new()
	help.text = "Túi: click / Enter / A để mặc hoặc đổi · Ô đang mặc: chuột phải / Backspace để tháo\nTab / Esc: tiếp tục · Thời gian 10% khi mở túi"
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", DungeonUI.MUTED)
	help.add_theme_font_size_override("font_size", 15)
	equipment_page.add_child(help)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	equipment_page.add_child(row)
	var left := GridContainer.new()
	left.columns = 2
	left.custom_minimum_size.x = 226
	left.add_theme_constant_override("h_separation", 6)
	left.add_theme_constant_override("v_separation", 7)
	row.add_child(left)
	equipment_buttons.resize(EquipmentData.SLOT_COUNT)
	for slot: int in [0, 1, 4, 5, 6, 2, 3]:
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 2)
		var label := Label.new()
		label.text = SLOT_NAMES[slot]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 12)
		cell.add_child(label)
		var button: Button = _item_button(Vector2(110, 55))
		button.add_theme_constant_override("icon_max_width", 38)
		button.gui_input.connect(_equipment_input.bind(slot))
		button.mouse_entered.connect(_equipment_hover.bind(slot))
		button.focus_entered.connect(_equipment_focus.bind(slot))
		button.pressed.connect(_equipment_focus.bind(slot))
		cell.add_child(button)
		left.add_child(cell)
		equipment_buttons[slot] = button
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	right.add_child(DungeonUI.label("TÚI ĐỒ · 20 ô", 16, DungeonUI.JADE))
	var grid := GridContainer.new()
	bag_grid = grid
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 7)
	grid.add_theme_constant_override("v_separation", 7)
	right.add_child(grid)
	for index: int in 20:
		var button: Button = _item_button(Vector2(100, 73))
		button.add_theme_constant_override("icon_max_width", 32)
		button.gui_input.connect(_bag_input.bind(index))
		button.pressed.connect(_equip_bag.bind(index))
		button.mouse_entered.connect(_bag_hover.bind(index))
		button.focus_entered.connect(_bag_focus.bind(index))
		grid.add_child(button)
		bag_buttons.append(button)
	var paging := HBoxContainer.new()
	right.add_child(paging)
	for step: int in [-1, 1]:
		var button := Button.new()
		button.text = "‹" if step < 0 else "›"
		button.pressed.connect(_change_page.bind(step))
		paging.add_child(button)
	pager = Label.new()
	paging.add_child(pager)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.y = 40
	status.text = "Bộ khởi đầu Thường: áo, quần, giày, găng tay, nhẫn và dây chuyền riêng."
	equipment_page.add_child(status)
	var unequip_button := Button.new()
	unequip_button.text = "Tháo ô trang bị đang chọn · Backspace"
	unequip_button.pressed.connect(_unequip_selected)
	equipment_page.add_child(unequip_button)
	var close_button := Button.new()
	close_button.text = "Tiếp tục · Tab / Esc"
	close_button.pressed.connect(close)
	shell.add_child(close_button)
	rune_column.name = "Bùa"
	tabs.add_child(rune_column)
	journal = QuestJournal.new()
	journal.name = "Bản đồ & Nhiệm vụ"
	tabs.add_child(journal)
	# Append after journal to preserve the existing map tab index/input routes.
	carried_page = VBoxContainer.new()
	carried_page.name = "Vật phẩm"
	carried_page.add_theme_constant_override("separation", 10)
	tabs.add_child(carried_page)
	tabs.tab_changed.connect(_tab_changed)
	_build_tooltip()
	_build_tracker()
	open_button = Button.new()
	# Gameplay launchers use clicks/shortcuts, never ui_accept after a modal closes.
	open_button.focus_mode = Control.FOCUS_NONE
	open_button.theme = panel.theme
	open_button.text = "Hành trang · Tab"
	open_button.position = Vector2(1020, 20)
	open_button.custom_minimum_size = Vector2(220, 38)
	open_button.pressed.connect(open)
	add_child(open_button)
	map_button = Button.new()
	map_button.focus_mode = Control.FOCUS_NONE
	map_button.theme = panel.theme
	map_button.text = "Bản đồ & Nhiệm vụ · M"
	map_button.custom_minimum_size = Vector2(220,38)
	map_button.add_theme_font_size_override("font_size",14)
	map_button.pressed.connect(open_map)
	add_child(map_button)
	_resize()
	panel.minimum_size_changed.connect(_schedule_layout)
	get_viewport().size_changed.connect(_resize)
	refresh()
	_bind_progress.call_deferred()


func _resize() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not is_instance_valid(panel):
		return
	var extent: Vector2 = get_viewport().get_visible_rect().size
	var compact: bool = extent.x < 820
	if is_instance_valid(journal) and is_instance_valid(journal.graph): journal.set_compact_layout(compact or extent.y < 680)
	if is_instance_valid(bag_grid): bag_grid.columns = 4 if compact else 5
	if is_instance_valid(rune_column):
		for child: Node in rune_column.get_children():
			if child is GridContainer: (child as GridContainer).columns = 3 if compact else 4 if child.get_child_count() == 8 else 3
	panel.size = Vector2(minf(900, extent.x - 32), minf(650, extent.y - 32))
	panel.position = (extent - panel.size) * 0.5
	var action_top: float = 80.0 if extent.x < 980 else 20.0
	open_button.position = Vector2(extent.x - 240, action_top)
	map_button.position = Vector2(extent.x - 240,action_top+44)
	veil.position = Vector2.ZERO
	veil.size = extent
	if is_instance_valid(tracker):
		tracker.size = Vector2(280, 110)
		tracker.position = Vector2(maxf(16, extent.x - tracker.size.x - 24), action_top + 52)
	if is_instance_valid(tooltip) and tooltip.visible: _place_tooltip()


func _item_button(extent: Vector2) -> Button:
	var button := Button.new()
	button.custom_minimum_size = extent
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 44)
	button.add_theme_font_size_override("font_size", 12)
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	for state: StringName in [&"normal", &"hover", &"pressed", &"focus"]:
		var style: StyleBoxFlat = DungeonUI.panel_style(5)
		style.bg_color = DungeonUI.SURFACE if state == &"normal" else Color("304957")
		style.border_color = Color("577c86") if state == &"normal" else DungeonUI.WARM
		style.set_border_width_all(1)
		if state == &"focus":
			style.bg_color = Color.TRANSPARENT
			style.set_border_width_all(3)
		style.set_corner_radius_all(3)
		style.set_content_margin_all(5)
		button.add_theme_stylebox_override(state, style)
	return button


func open() -> void:
	if not is_open and tabs.current_tab == 2: tabs.current_tab = 0
	super.open()
	if is_open and is_instance_valid(veil):
		veil.show()
		open_button.hide()
		map_button.hide()
		tracker.hide()
		_focus_tab()


func close() -> void:
	var was_open: bool = is_open
	super.close()
	_map_detail_axis = 0.0
	if is_instance_valid(veil):
		veil.hide()
		open_button.visible = is_instance_valid(player) and player.health.current_health > 0.0
		map_button.visible = open_button.visible
	if was_open:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if is_instance_valid(focused) and is_ancestor_of(focused): focused.release_focus()
	_hide_tooltip()
	_update_tracker()


func refresh() -> void:
	super.refresh()
	if equipment_buttons.is_empty():
		return
	bag_uids = inventory.equipment_grid_uids()
	page = clampi(page, 0, maxi(0, ceili(bag_uids.size() / 20.0) - 1))
	var count: int = inventory.equipment_bag_uids().size()
	pager.text = "Trang %d / %d · %d/20 món%s" % [page + 1, maxi(1, ceili(bag_uids.size() / 20.0)), count, " · ĐẦY" if count >= 20 else " · TRỐNG" if count == 0 else ""]
	for slot: int in equipment_buttons.size():
		var uid: int = inventory.equipped_weapon_uid if slot == 0 else inventory.equipment_uids[slot]
		_fill_button(equipment_buttons[slot], uid, SLOT_NAMES[slot])
	for index: int in 20:
		var offset: int = page * 20 + index
		_fill_button(bag_buttons[index], bag_uids[offset] if offset < bag_uids.size() else 0, "Trống")
	_hide_tooltip()
	if is_instance_valid(player) and player.equipped_weapon.definition != null:
		var damage: float = player.equipped_weapon.definition.base_damage * player.equipped_weapon.damage_multiplier
		status.text = "HP tối đa %d · Giáp %s · Sức đánh cơ bản %s\nĐang chọn ô %s · Hover / focus món đồ để xem chỉ số và so sánh." % [roundi(player.health.maximum_health), String.num(player.hurtbox.damage_resolver.armor_rating, 1), String.num(damage, 1), SLOT_NAMES[selected_equipment_slot]]
	_refresh_balances()
	_refresh_carried_items()
	if journal != null: journal.refresh()
	_update_tracker()
	_resize.call_deferred()


func _refresh_balances() -> void:
	if balances == null: return
	balances.visible = _balance_profile != null
	if _balance_profile != null:
		balances.text = "Tàn Hồn %d · Linh Thạch %d · Linh Thạch đang mang %d" % [_balance_profile.souls, _balance_profile.coins, inventory.run_coins]

func _refresh_carried_items() -> void:
	if carried_page == null: return
	for node: Node in carried_page.get_children():
		carried_page.remove_child(node)
		node.queue_free()
	carried_page.add_child(DungeonUI.label("VẬT PHẨM ĐANG MANG", 18, DungeonUI.WARM))
	var hint: Label = DungeonUI.label("Đồ nhặt vào hành trang. Cất vật liệu tại kho hoặc bán món hợp lệ cho Kael; Tàn Hồn là tài nguyên riêng.", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	carried_page.add_child(hint)
	var found: bool = false
	for id: StringName in MaterialCatalog.IDS:
		var count: int = inventory.materials.get(id, 0)
		if count <= 0: continue
		found = true
		var card: ServiceItemCard = ServiceItemCard.create(ItemArtCatalog.icon(id), MaterialCatalog.DISPLAY_NAMES[id], "Trong hành trang", "Số lượng %d" % count, "", Callable(), false)
		card.name = "BagMaterial_" + String(id)
		card.set_display_only()
		carried_page.add_child(card)
	for id: StringName in inventory.consumables:
		var count: int = inventory.consumables[id]
		if count <= 0: continue
		found = true
		var card: ServiceItemCard = ServiceItemCard.create(ItemArtCatalog.icon(id), ItemArtCatalog.display_name(id), "Vật phẩm tiêu hao trong hành trang", "Số lượng %d" % count, "", Callable(), false)
		card.name = "BagConsumable_" + String(id)
		card.set_display_only()
		carried_page.add_child(card)
	if not found: carried_page.add_child(DungeonUI.label("Chưa có vật liệu hoặc vật phẩm tiêu hao đang mang.", 15))

func _schedule_layout() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		_resize.call_deferred()


func _fill_button(button: Button, uid: int, empty_text: String) -> void:
	var item: GearItem = inventory.items.get(uid)
	button.icon = null
	button.text = empty_text
	button.add_theme_color_override("font_color", DungeonUI.MUTED)
	button.tooltip_text = empty_text
	if item == null:
		return
	var display: String = _item_name(item)
	button.text = "%s\n%s" % [display, GearItem.NAMES[item.quality]]
	if not item.can_equip(): button.text += " · Hỏng" if item.broken else " · Phôi"
	button.icon = ItemArtCatalog.gear_icon(item)
	button.add_theme_color_override("font_color", DungeonUI.TEXT)
	button.tooltip_text = "%s · %s" % [display, GearItem.NAMES[item.quality]]


func _item_name(item: GearItem) -> String:
	if item.broken:
		return ItemArtCatalog.gear_name(item)
	if item.equipment_definition != null:
		return item.equipment_definition.item_name
	var path: String = "res://data/weapons/%s.tres" % item.definition_id
	if item.kind == &"weapon" and ResourceLoader.exists(path):
		return (load(path) as WeaponDefinition).display_name
	return String(item.definition_id).replace("_", " ")


func _bag_input(event: InputEvent, index: int) -> void:
	if not is_open or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_RIGHT:
		return
	_equip_bag(index)
	bag_buttons[index].accept_event()


func _equip_bag(index: int) -> void:
	if not is_open: return
	var offset: int = page * 20 + index
	if offset < bag_uids.size():
		var uid: int = bag_uids[offset]
		var ok: bool = inventory.equip_equipment(uid)
		status.text = "Đã trang bị. Món cũ trở về túi." if ok else "Không thể trang bị món này."


func _equipment_input(event: InputEvent, slot: int) -> void:
	if not is_open or not event is InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		selected_equipment_slot = slot
		_unequip_selected()
		equipment_buttons[slot].accept_event()


func _unequip_selected() -> void:
	if not is_open: return
	var ok: bool = inventory.unequip_equipment(selected_equipment_slot)
	status.text = "Đã tháo. Tay không có đòn đấm cơ bản." if ok and selected_equipment_slot == 0 else "Đã tháo trang bị." if ok else "Ô trống hoặc túi đã đầy; trang bị được giữ nguyên."


func _build_tooltip() -> void:
	tooltip = PanelContainer.new()
	tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.theme = DungeonUI.make_theme()
	add_child(tooltip)
	tooltip_scroll = ScrollContainer.new()
	tooltip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tooltip_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip.add_child(tooltip_scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tooltip_scroll.add_child(box)
	tooltip_name = DungeonUI.label("", 18, DungeonUI.WARM)
	box.add_child(tooltip_name)
	tooltip_body = Label.new()
	tooltip_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tooltip_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tooltip_body)
	tooltip.hide()


func _bag_hover(index: int) -> void:
	_tooltip_control = null
	_tooltip_anchor = get_viewport().get_mouse_position() + Vector2(18, 18)
	var offset: int = page * 20 + index
	_show_tooltip(bag_uids[offset] if offset < bag_uids.size() else 0)


func _equipment_hover(slot: int) -> void:
	_tooltip_control = null
	_tooltip_anchor = get_viewport().get_mouse_position() + Vector2(18, 18)
	_show_tooltip(inventory.equipped_weapon_uid if slot == 0 else inventory.equipment_uids[slot])


func _show_tooltip(uid: int) -> void:
	if not is_open:
		return
	var item: GearItem = inventory.items.get(uid)
	if item == null:
		_hide_tooltip()
		return
	var data: EquipmentData = item.equipment_definition
	tooltip_name.text = "%s · %s" % [_item_name(item), GearItem.NAMES[item.quality]]
	tooltip_name.add_theme_color_override("font_color", DungeonUI.WARM)
	var details: String = ""
	if item.enhancement_level > 0:
		details += "Cường hóa +%d · +%d%% sát thương nền\n" % [item.enhancement_level, item.enhancement_level * 3]
	if item.broken:
		details += "Hỏng · Cần sửa tại thợ rèn trước khi dùng.\n"
	if item.is_forging_blank():
		details += "Phôi phẩm cấp cao · Cần công thức và rèn phục hồi.\n"
	if item.drop_bonus > 0.0:
		details += "Sát thương nền từ đồ rơi: +%s%%\n" % String.num(clampf(item.drop_bonus, 0.0, 0.08) * 100.0, 1)
	var affix: float = LootAffixCatalog.bounded_value(item.affix_id, item.affix_value)
	if affix > 0.0:
		var percent: bool = item.affix_id in [&"stride", &"precision"]
		details += "%s: +%s%s\n" % [LootAffixCatalog.NAMES[item.affix_id], String.num(affix * 100.0 if percent else affix, 1), "%" if percent else ""]
	if data != null:
		for pair: Array in [["HP", data.bonus_hp], ["Giáp", data.bonus_armor], ["Năng lượng", data.bonus_mana], ["Sát thương", data.bonus_atk], ["Tốc chạy %", data.bonus_speed * 100.0], ["Chí mạng %", data.bonus_crit * 100.0]]:
			if not is_zero_approx(float(pair[1])):
				details += "%s: %s%s\n" % [pair[0], "+" if float(pair[1]) > 0 else "", String.num(float(pair[1]), 2)]
	tooltip_body.text = "%s\n%s%s\n\n%s" % [SLOT_NAMES[inventory.equipment_slot(uid)], details if details != "" else "Không cộng chỉ số trang bị.\n", data.description if data != null else "", _comparison_text(item)]
	tooltip.show()
	_place_tooltip.call_deferred()


func _hide_tooltip() -> void:
	if is_instance_valid(tooltip):
		tooltip.hide()
	_tooltip_control = null


func _change_page(step: int) -> void:
	page = clampi(page + step, 0, maxi(0, ceili(bag_uids.size() / 20.0) - 1))
	refresh()


func _tab_changed(_index: int) -> void:
	_hide_tooltip()
	# Nested quest/detail scrolls own focus; the outer scroll must retain the header.
	content_scroll.follow_focus = _index != 2
	if _index == 2: content_scroll.scroll_vertical = 0
	if is_open: _focus_tab.call_deferred()


func _equipment_focus(slot: int) -> void:
	selected_equipment_slot = slot
	if is_instance_valid(status): status.text = "Đang chọn ô %s · Chuột phải / Backspace để tháo.\nHover / focus món trong túi để xem so sánh trước khi mặc." % SLOT_NAMES[slot]
	_tooltip_anchor = equipment_buttons[slot].get_global_rect().end + Vector2(8, 8)
	_tooltip_control = weakref(equipment_buttons[slot])
	_show_tooltip(inventory.equipped_weapon_uid if slot == 0 else inventory.equipment_uids[slot])


func _bag_focus(index: int) -> void:
	_tooltip_anchor = bag_buttons[index].get_global_rect().end + Vector2(8, 8)
	_tooltip_control = weakref(bag_buttons[index])
	var offset: int = page * 20 + index
	_show_tooltip(bag_uids[offset] if offset < bag_uids.size() else 0)


func _focus_tab() -> void:
	if not is_open or not is_inside_tree(): return
	if tabs.current_tab == 0: equipment_buttons[selected_equipment_slot].grab_focus()
	elif tabs.current_tab == 1: slots[selected_slot].grab_focus()
	else:
		content_scroll.scroll_vertical = 0
		journal.focus_recommended()

func open_map() -> void:
	if get_tree().paused or not is_instance_valid(player) or player.health.current_health <= 0 or (not is_open and not player.controls_enabled) or _other_ui_open(): return
	if not is_open: open()
	if not is_open: return
	tabs.current_tab = 2
	_hide_tooltip()
	journal.focus_recommended.call_deferred()

func _other_ui_open() -> bool:
	var owner_world: Node = _progress_world.get_ref() as Node if _progress_world != null else null
	if not is_instance_valid(owner_world): return false
	for property: Dictionary in owner_world.get_property_list():
		var name: String = property.get("name","")
		if name == "station_open" and bool(owner_world.get(name)): return true
		if name == "dialogue":
			var dialogue: Node = owner_world.get(name) as Node
			if is_instance_valid(dialogue) and bool(dialogue.get("is_open")): return true
	return false

func _map_context() -> Dictionary:
	var owner_world: Node = _progress_world.get_ref() as Node if _progress_world != null else null
	if is_instance_valid(owner_world):
		var properties: Dictionary = {}
		for property: Dictionary in owner_world.get_property_list(): properties[String(property.get("name",""))] = true
		for property: Dictionary in owner_world.get_property_list():
			if property.get("name","") == "inside_house":
				if journal.profile == null or journal.profile.exterior_progress_quarantined or not ExteriorProgress.valid(journal.profile.exterior_progress): return {"room":&"","label":"Vị trí chưa khả dụng"}
				var room: StringName = ExteriorRouteCatalog.HUB
				if properties.has("outside") and bool(owner_world.get("outside")) and properties.has("exterior"):
					var exterior: Node = owner_world.get("exterior") as Node
					if is_instance_valid(exterior): room = StringName(exterior.get("room_id"))
				return {"room":room,"label":MapQuestProjection.room_name(room)}
	return {"room":&"","label":"Hầm ngục · ngoài sơ đồ đường bộ"}


func _input(event: InputEvent) -> void:
	if (event is InputEventKey and (event.physical_keycode == KEY_M or event.keycode == KEY_M)) or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_BACK):
		var latch: String = "key" if event is InputEventKey else "joy:%d" % event.device
		if not event.is_pressed(): _map_held.erase(latch)
		elif not event.is_echo() and not _map_held.has(latch):
			_map_held[latch] = true
			if is_open and tabs.current_tab == 2: close()
			else: open_map()
		get_viewport().set_input_as_handled()
		return
	if is_open and DungeonUI.dispatch_controller(get_viewport(), event, _controller_axes):
		get_viewport().set_input_as_handled()
		return
	if is_open and tabs.current_tab == 2:
		if event.is_action_pressed(&"inventory") or event.is_action_pressed(&"ui_cancel"):
			super._input(event)
		elif event is InputEventKey and event.pressed and (event.physical_keycode in [KEY_PAGEUP,KEY_PAGEDOWN] or event.keycode in [KEY_PAGEUP,KEY_PAGEDOWN]):
			journal.scroll_detail(-96 if event.physical_keycode == KEY_PAGEUP or event.keycode == KEY_PAGEUP else 96)
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_Y:
			_map_detail_axis = event.axis_value
			get_viewport().set_input_as_handled()
		elif event.is_action(&"ui_accept"):
			# Space is also jump. Route acceptance once before unhandled gameplay.
			var focused: BaseButton = get_viewport().gui_get_focus_owner() as BaseButton
			if event.is_pressed() and not event.is_echo() and is_instance_valid(focused) and panel.is_ancestor_of(focused) and not focused.disabled: focused.pressed.emit()
			get_viewport().set_input_as_handled()
		elif not DungeonUI.is_navigation(event) and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
			get_viewport().set_input_as_handled()
		return
	if is_open and event is InputEventKey and event.pressed and not event.echo:
		var code: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if (code >= KEY_1 and code <= KEY_8) or code in [KEY_F, KEY_G, KEY_H, KEY_B, KEY_V]:
			tabs.current_tab = 1
			super._input(event)
			return
	if is_open and tooltip.visible and event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and tooltip.get_global_rect().has_point(event.position):
		tooltip_scroll.scroll_vertical += -48 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 48
		get_viewport().set_input_as_handled()
		return
	if not is_open or tabs.current_tab == 1 or event.is_action_pressed(&"inventory") or event.is_action_pressed(&"ui_cancel"):
		super._input(event)
		return
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_BACKSPACE or event.physical_keycode == KEY_BACKSPACE) and tabs.current_tab == 0:
		_unequip_selected()
		get_viewport().set_input_as_handled()
	elif not DungeonUI.is_navigation(event) and (event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		get_viewport().set_input_as_handled()


func _place_tooltip() -> void:
	if not is_inside_tree() or is_queued_for_deletion() or not tooltip.visible: return
	var extent: Vector2 = get_viewport().get_visible_rect().size
	var bounds: Rect2 = content_scroll.get_global_rect().intersection(Rect2(Vector2(12, 12), extent - Vector2(24, 24)))
	tooltip.size = Vector2(minf(360, bounds.size.x), minf(420, bounds.size.y))
	if _tooltip_control != null:
		var target: Control = _tooltip_control.get_ref() as Control
		if is_instance_valid(target):
			var target_rect: Rect2 = target.get_global_rect()
			_tooltip_anchor = target_rect.end + Vector2(8, 8)
			if _tooltip_anchor.x + tooltip.size.x > bounds.end.x:
				_tooltip_anchor.x = target_rect.position.x - tooltip.size.x - 8
	tooltip.position = _tooltip_anchor.clamp(bounds.position, (bounds.end - tooltip.size).max(bounds.position))


func _comparison_text(item: GearItem) -> String:
	var slot: int = inventory.equipment_slot(item.uid)
	var worn_uid: int = inventory.equipped_weapon_uid if slot == 0 else inventory.equipment_uids[slot]
	if item.uid == worn_uid: return "ĐANG TRANG BỊ · Chuột phải / Backspace để tháo."
	if not item.can_equip(): return "CHƯA THỂ MẶC · Đến Thiết Lão để sửa hoặc rèn phục hồi."
	var worn: GearItem = inventory.items.get(worn_uid)
	var incoming: Dictionary = _comparison_values(item)
	var current: Dictionary = _comparison_values(worn)
	if worn == null and slot == 0 and is_instance_valid(player) and player.equipped_weapon.definition != null:
		current["Sát thương vũ khí"] = player.equipped_weapon.definition.base_damage
	var lines: Array[String] = ["SO VỚI ĐANG MẶC · " + (_item_name(worn) if worn != null else "Tay không" if slot == 0 else "Ô trống")]
	for stat: String in incoming:
		var change: float = float(incoming[stat]) - float(current.get(stat, 0.0))
		if not is_zero_approx(change):
			lines.append("%s: %s%s (%s)" % [stat, "+" if change > 0 else "", String.num(change, 2), "tăng" if change > 0 else "giảm"])
	if lines.size() == 1: lines.append("Không đổi các chỉ số được so sánh.")
	if item.kind == &"weapon":
		lines.append("Sát thương vũ khí so sánh riêng phần nền; bonus các món khác giữ nguyên.")
		lines.append("Ô bùa thêm %d · Proc phẩm cấp %s%%" % [item.bonus_slots(), String.num(item.proc_chance() * 100, 1)])
	lines.append("Click / Enter / A · Trang bị. Cuộn chuột để xem thêm.")
	return "\n".join(lines)


func _comparison_values(item: GearItem) -> Dictionary:
	var result: Dictionary = {"HP": 0.0, "Giáp": 0.0, "Năng lượng": 0.0, "Sát thương trang bị": 0.0, "Tốc chạy %": 0.0, "Chí mạng %": 0.0, "Sát thương vũ khí": 0.0}
	if item == null or not item.can_equip(): return result
	var data: EquipmentData = item.equipment_definition
	if data != null:
		result["HP"] = data.bonus_hp
		result["Giáp"] = data.bonus_armor
		result["Năng lượng"] = data.bonus_mana
		result["Sát thương trang bị"] = data.bonus_atk
		result["Tốc chạy %"] = data.bonus_speed * 100.0
		result["Chí mạng %"] = data.bonus_crit * 100.0
	result["HP"] += item.affix_bonus(&"vitality")
	result["Giáp"] += item.affix_bonus(&"ward")
	result["Năng lượng"] += item.affix_bonus(&"focus")
	result["Tốc chạy %"] += item.affix_bonus(&"stride") * 100.0
	result["Chí mạng %"] += item.affix_bonus(&"precision") * 100.0
	if item.kind == &"weapon":
		var moveset: WeaponDefinition = data.moveset if data != null else null
		var path: String = "res://data/weapons/%s.tres" % item.definition_id
		if moveset == null and ResourceLoader.exists(path): moveset = load(path) as WeaponDefinition
		if moveset != null: result["Sát thương vũ khí"] = moveset.base_damage * item.damage_factor()
	return result


func _build_tracker() -> void:
	tracker = PanelContainer.new()
	tracker.name = "QuestTracker"
	tracker.theme = DungeonUI.make_theme()
	tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tracker)
	tracker_label = DungeonUI.label("", 14)
	tracker.add_child(tracker_label)
	tracker.hide()


func _bind_progress() -> void:
	if not is_inside_tree() or is_queued_for_deletion(): return
	var ancestor: Node = get_parent()
	var source: SanctuaryProfile
	while ancestor != null:
		# Presentation reads a supplied profile without loading world scripts back
		# through GearSession's preloaded UI scene (a script/resource cycle).
		for property: Dictionary in ancestor.get_property_list():
			if property.get("name", "") == "profile":
				source = ancestor.get("profile") as SanctuaryProfile
				break
		if source != null: break
		ancestor = ancestor.get_parent()
	_balance_profile = source
	if source != null and not source.changed.is_connected(_refresh_balances): source.changed.connect(_refresh_balances)
	_refresh_balances()
	journal.bind_progress(source, inventory)
	_progress_world = weakref(ancestor) if ancestor != null else null
	journal.context_provider = _map_context
	journal.quest_action_provider = _quest_action
	journal.refresh()
	# Navigation reads this supplied world/profile, with no HUD/save ownership.
	var navigator := QuestNavigator.new()
	navigator.name = "QuestNavigator"
	add_child(navigator)
	navigator.initialize(source,inventory,ancestor,player,self,journal)
	journal.navigation_provider = navigator.track
	if source != null: source.changed.connect(_update_tracker)
	_update_tracker()

func _quest_action(command: StringName) -> Dictionary:
	var world: Node = _progress_world.get_ref() as Node if _progress_world != null else null
	if not is_instance_valid(world) or world.is_queued_for_deletion() or not is_open or _map_context()["room"] != ExteriorRouteCatalog.HUB or not is_instance_valid(player) or player.health.current_health <= 0:
		return {"ok":false,"notice":"Về căn cứ và mở lại bảng nhiệm vụ để thực hiện."}
	var properties: Dictionary = {}
	for property: Dictionary in world.get_property_list(): properties[String(property.get("name",""))] = true
	if not properties.has("profile") or world.get("profile") != journal.profile or journal.profile == null or journal.profile.read_only or journal.profile.hub_inventory_quarantined:
		return {"ok":false,"notice":"Hồ sơ chưa sẵn sàng lưu phần thưởng."}
	if command == &"retry_insights":
		if not properties.has("cultivation_session"): return {"ok":false,"notice":"Chưa có phiên tu luyện hợp lệ."}
		var session: Node = world.get("cultivation_session") as Node
		if not is_instance_valid(session) or not session.has_method("_sync_insights") or session.get("profile") != journal.profile or session.get("scene") != world: return {"ok":false,"notice":"Chưa có phiên tu luyện hợp lệ."}
		session.call("_sync_insights")
		var earned: bool = OpeningQuestCards.insights_ready(journal.profile)
		return {"ok":earned,"notice":"Đã nhận lĩnh ngộ từ các mốc đã lưu." if earned else "Lĩnh ngộ chưa lưu được; phần thưởng vẫn chờ để thử lại."}
	if command not in [&"bounty_accept",&"bounty_claim"] or not properties.has("economy"): return {"ok":false,"notice":"Thao tác này chưa khả dụng."}
	var owner: EconomySession = world.get("economy") as EconomySession
	if owner == null or owner.profile != journal.profile or owner.inventory != inventory or not owner.hub_access: return {"ok":false,"notice":"Phiên hành trang đã thay đổi. Mở lại bảng."}
	var success: bool = owner.accept_bounty(WorldProgressionCatalog.BOUNTY_ID) if command == &"bounty_accept" else owner.claim_bounty(WorldProgressionCatalog.BOUNTY_ID)
	return {"ok":success,"notice":("Đã nhận lời hẹn. Vào cổng hầm ngục để tiếp tục." if command == &"bounty_accept" else "Đã nhận Kiếm Lữ Hành · Liên Thức vào túi. Mở Hành trang để trang bị.") if success else "Chưa nhận: kiểm tra chứng tích, một ô túi trống và trạng thái lưu. Có thể thử lại."}


func _update_tracker() -> void:
	if not is_instance_valid(tracker): return
	tracker_label.text = ""
	tracker.hide()


func _process(_delta: float) -> void:
	if is_open: _refresh_balances()
	if is_instance_valid(tracker):
		tracker.hide()
	if is_instance_valid(map_button): map_button.visible = not is_open and is_instance_valid(player) and player.controls_enabled and not get_tree().paused
	if is_open and tabs.current_tab == 2 and absf(_map_detail_axis) >= .55:
		var now: int = Time.get_ticks_msec()
		if now >= _map_scroll_tick:
			journal.scroll_detail(int(signf(_map_detail_axis))*48)
			_map_scroll_tick = now+100
	else:
		_map_detail_axis = 0.0
		_map_scroll_tick = 0
