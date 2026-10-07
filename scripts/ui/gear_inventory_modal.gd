class_name GearInventoryModal
extends CanvasLayer
## Owns slowdown and restores it on every exit path; UI consumes attack clicks.

var player: Player
var inventory: GearInventory
var is_open: bool = false
var selected_slot: int = 0
var panel: PanelContainer
var slots: Array[Button] = []
var rune_buttons: Array[Button] = []
var preview: Label
var previous_scale: float = 1.0
var previous_controls: bool = true
var secondary_panel: SurvivalPanel
var _previous_focus: WeakRef
var _controller_axes: Dictionary = {}


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.position = Vector2(280, 95)
	panel.size = Vector2(720, 585)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.06, 0.075, 0.11)
	background.border_color = Color(0.3, 0.5, 0.65)
	background.set_border_width_all(2)
	background.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "TRANG BỊ BÙA · thời gian 10%"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var help := Label.new()
	help.text = "1–3, 5–6: Catalyst · 4, 7–8: Vũ khí · F/G/H/B/V: 5 nguyên tố\nÔ bổ sung cần phẩm cấp cao · Shift + chọn ô: đổi hai ô\nBackspace: tháo · Tab: đóng"
	column.add_child(help)
	var row := GridContainer.new()
	row.columns = 4
	column.add_child(row)
	for index: int in 8:
		var button := Button.new()
		button.custom_minimum_size = Vector2(165, 46)
		button.pressed.connect(_select.bind(index))
		row.add_child(button)
		slots.append(button)
	var runes_row := GridContainer.new()
	runes_row.columns = 3
	column.add_child(runes_row)
	for index: int in GearInventory.RUNES.size():
		var button := Button.new()
		button.custom_minimum_size = Vector2(180, 40)
		button.pressed.connect(equip_selected.bind(GearInventory.RUNES[index].id))
		runes_row.add_child(button)
		rune_buttons.append(button)
	var remove := Button.new()
	remove.text = "Tháo bùa ở ô đang chọn"
	remove.pressed.connect(equip_selected.bind(&""))
	column.add_child(remove)
	preview = Label.new()
	column.add_child(preview)
	var close_button := Button.new()
	close_button.text = "Tiếp tục · Tab"
	close_button.pressed.connect(close)
	column.add_child(close_button)
	panel.hide()
	inventory.changed.connect(refresh)
	AntiqueSkin.apply_tree.call_deferred(panel)
	refresh()


func open() -> void:
	if is_open or player.health.current_health <= 0.0:
		return
	if is_instance_valid(secondary_panel):
		secondary_panel.close()
	is_open = true
	_controller_axes.clear()
	previous_scale = Engine.time_scale
	previous_controls = player.controls_enabled
	var focused: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focused) if focused != null else null
	TimeScaleClaims.acquire(self, 0.1)
	player.suspend_controls(true)
	panel.show()
	refresh()


func close() -> void:
	if not is_open:
		return
	is_open = false
	TimeScaleClaims.release(self)
	if is_instance_valid(player):
		player.suspend_controls(not previous_controls or player.health.current_health <= 0.0)
	panel.hide()
	if _previous_focus != null:
		var previous: Control = _previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()
	_previous_focus = null


func _exit_tree() -> void:
	TimeScaleClaims.release(self)


func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if is_open and DungeonUI.dispatch_controller(get_viewport(), event, _controller_axes):
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"inventory"):
		if is_open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif is_open and event is InputEventKey and event.pressed and not event.echo:
		if event.is_action_pressed(&"ui_cancel"):
			close()
			get_viewport().set_input_as_handled()
			return
		if DungeonUI.is_navigation(event): return
		var code: int = event.physical_keycode
		if code >= KEY_1 and code <= KEY_8:
			_select(code - KEY_1)
		elif code in [KEY_F, KEY_G, KEY_H, KEY_B, KEY_V]:
			var index: int = [KEY_F, KEY_G, KEY_H, KEY_B, KEY_V].find(code)
			equip_selected(GearInventory.RUNES[index].id)
		elif code == KEY_BACKSPACE:
			equip_selected(&"")
		get_viewport().set_input_as_handled()
	elif is_open and (event is InputEventMouseButton or event is InputEventMouseMotion):
		# Let Controls handle clicks; Player is gated until the next physics frame.
		pass
	elif is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif is_open and not DungeonUI.is_navigation(event) and (event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction):
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if is_open: get_viewport().set_input_as_handled()


func _select(index: int) -> void:
	if Input.is_physical_key_pressed(KEY_SHIFT):
		inventory.swap_slots(selected_slot, index)
	selected_slot = index
	refresh()


func equip_selected(id: StringName) -> void:
	inventory.equip(selected_slot, id)
	refresh()


func refresh() -> void:
	if slots.is_empty():
		return
	inventory._ensure_slots()
	for index: int in 8:
		var rune: RuneData = inventory.get_rune(inventory.slots[index])
		var is_catalyst: bool = index in GearInventory.CATALYST_INDICES
		var number: int = GearInventory.CATALYST_INDICES.find(index) + 1 if is_catalyst else 1 if index == 3 else index - 4
		slots[index].visible = number <= (inventory.catalyst_capacity if is_catalyst else inventory.weapon_capacity)
		slots[index].text = "%s%d · %s %d\n%s" % ["▶ " if selected_slot == index else "", index + 1, "Catalyst" if is_catalyst else "Vũ khí", number, rune.display_name if rune != null else "Trống"]
	for index: int in GearInventory.RUNES.size():
		var rune: RuneData = GearInventory.RUNES[index]
		rune_buttons[index].text = "%s × %d" % [rune.display_name, inventory.bag[rune.id]]
		rune_buttons[index].disabled = inventory.bag[rune.id] <= 0
	var recipe: ResonanceDefinition = player.resonance_controller.get_recipe()
	preview.text = "Cộng hưởng: %s\nĐổi bùa giữ hồi chiêu và phép đã phóng." % [recipe.display_name if recipe != null else "Tổ hợp chưa hợp lệ — không thể niệm"]
	AntiqueSkin.update_rune_art(slots, rune_buttons, inventory)
