class_name DialogueBox
extends CanvasLayer
## One responsive modal. Typewriter uses wall time, not slowed gameplay delta.

signal closed
signal choice_selected(id: StringName)

@export_range(1.0, 100.0) var characters_per_second: float = 38.0
var is_open: bool = false
var auto_input: bool = true
var panel: PanelContainer
var body_scroll: ScrollContainer
var speaker_label: Label
var portrait: TextureRect
var text_label: Label
var choice_list: VBoxContainer
var close_button: Button
var hint: Label
var pages: Array[String] = []
var choices: Array[Dictionary] = []
var page_index: int = 0
var _revealed: float = 0.0
var _last_msec: int = 0
var _resize_queued: bool = false
var page_label: Label
var confirmation: VBoxContainer
var confirmation_text: Label
var confirm_button: Button
var cancel_button: Button
var pending_choice: StringName = &""
var _previous_focus: WeakRef
var _choices_revealed: bool = false
var _controller_axes: Dictionary = {}

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.theme = DungeonUI.make_theme()
	add_child(panel)
	var shell := VBoxContainer.new()
	shell.add_theme_constant_override("separation", 10)
	panel.add_child(shell)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	shell.add_child(header)
	portrait = TextureRect.new()
	portrait.name = "NpcPortrait"
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(78, 84)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_child(portrait)
	speaker_label = Label.new()
	speaker_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	speaker_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	speaker_label.add_theme_color_override("font_color", DungeonUI.WARM)
	speaker_label.add_theme_font_size_override("font_size", 22)
	speaker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(speaker_label)
	page_label = DungeonUI.label("", 14, DungeonUI.MUTED)
	page_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	page_label.size_flags_horizontal = Control.SIZE_SHRINK_END
	header.add_child(page_label)
	body_scroll = ScrollContainer.new()
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body_scroll.follow_focus = true
	body_scroll.custom_minimum_size.y = 64
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.add_child(body_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	body_scroll.add_child(content)
	text_label = Label.new()
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_label.add_theme_font_size_override("font_size", 18)
	text_label.add_theme_constant_override("line_spacing", 5)
	content.add_child(text_label)
	choice_list = VBoxContainer.new()
	choice_list.add_theme_constant_override("separation", 6)
	content.add_child(choice_list)
	confirmation = VBoxContainer.new()
	confirmation.add_theme_constant_override("separation", 10)
	content.add_child(confirmation)
	confirmation.add_child(DungeonUI.label("XÁC NHẬN LỰA CHỌN", 18, DungeonUI.WARM))
	confirmation_text = DungeonUI.label("")
	confirmation.add_child(confirmation_text)
	cancel_button = Button.new()
	cancel_button.text = "Quay lại · Esc"
	cancel_button.pressed.connect(cancel_confirmation)
	confirmation.add_child(cancel_button)
	confirm_button = Button.new()
	confirm_button.text = "Xác nhận"
	confirm_button.pressed.connect(confirm_choice)
	confirmation.add_child(confirm_button)
	cancel_button.focus_neighbor_bottom = cancel_button.get_path_to(confirm_button)
	cancel_button.focus_neighbor_top = cancel_button.get_path_to(confirm_button)
	confirm_button.focus_neighbor_top = confirm_button.get_path_to(cancel_button)
	confirm_button.focus_neighbor_bottom = confirm_button.get_path_to(cancel_button)
	confirmation.hide()
	hint = Label.new()
	hint.text = "Space / E · Hiện hết hoặc tiếp tục"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", DungeonUI.MUTED)
	shell.add_child(hint)
	close_button = Button.new()
	close_button.name = "CloseDialogue"
	close_button.text = "Kết thúc trò chuyện"
	close_button.custom_minimum_size.y = 42
	close_button.pressed.connect(close)
	shell.add_child(close_button)
	# Wrapped labels can briefly report a tall minimum before their width is laid
	# out. Reapply the viewport bounds after those container minima settle.
	panel.minimum_size_changed.connect(_queue_resize)
	get_viewport().size_changed.connect(_queue_resize)
	_resize()
	panel.hide()

func open(speaker: String, lines: Array[String], menu: Array[Dictionary] = [], portrait_texture: Texture2D = null) -> void:
	if not is_open:
		var focused: Control = get_viewport().gui_get_focus_owner()
		_previous_focus = weakref(focused) if focused != null else null
	pending_choice = &""
	_controller_axes.clear()
	confirmation.hide()
	text_label.show()
	pages.assign(lines)
	if pages.is_empty(): pages.append("")
	choices.assign(menu)
	page_index = 0
	speaker_label.text = speaker
	portrait.texture = portrait_texture
	portrait.visible = portrait_texture != null
	for child: Node in choice_list.get_children():
		choice_list.remove_child(child)
		child.queue_free()
	for choice: Dictionary in choices:
		var button := Button.new()
		button.name = "Choice_" + String(choice.get("id", "continue"))
		button.text = str(choice.get("text", "Tiếp tục")) + (" · Chưa khả dụng" if not bool(choice.get("enabled", true)) else "")
		button.tooltip_text = button.text
		button.custom_minimum_size.y = 44
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.disabled = not bool(choice.get("enabled", true))
		button.pressed.connect(select_choice.bind(StringName(choice.get("id", ""))))
		choice_list.add_child(button)
	is_open = true
	panel.show()
	_start_page()
	_resize()
	close_button.grab_focus()

func _start_page() -> void:
	text_label.text = pages[page_index]
	text_label.visible_characters = 0
	_revealed = 0.0
	_last_msec = Time.get_ticks_msec()
	choice_list.hide()
	_choices_revealed = false
	page_label.text = "%d / %d" % [page_index + 1, pages.size()]
	hint.text = "Space / E · Hiện hết hoặc tiếp tục"
	body_scroll.scroll_vertical = 0

func _process(_delta: float) -> void:
	if not is_open: return
	var now: int = Time.get_ticks_msec()
	_revealed += float(now - _last_msec) * 0.001 * characters_per_second
	_last_msec = now
	text_label.visible_characters = mini(int(_revealed), text_label.text.length())
	if pending_choice == &"" and not is_typing() and page_index == pages.size() - 1:
		_reveal_choices()

func _reveal_choices() -> void:
	if _choices_revealed: return
	_choices_revealed = true
	choice_list.show()
	hint.text = "↑ ↓ / tay cầm · Chọn    Enter / A · Xác nhận    Tab / Esc · Đóng" if not choices.is_empty() else "Space / E · Kết thúc    Esc · Đóng"
	for child: Button in choice_list.get_children():
		if not child.disabled:
			child.grab_focus()
			break

func is_typing() -> bool:
	return text_label.visible_characters >= 0 and text_label.visible_characters < text_label.text.length()

func advance() -> void:
	if not is_open or pending_choice != &"": return
	if is_typing():
		_revealed = float(text_label.text.length())
		text_label.visible_characters = text_label.text.length()
		if page_index == pages.size() - 1:
			_reveal_choices()
	elif page_index < pages.size() - 1:
		page_index += 1
		_start_page()
	elif choices.is_empty():
		close()

func select_choice(id: StringName) -> void:
	if not is_open or is_typing() or page_index != pages.size() - 1 or pending_choice != &"": return
	for choice: Dictionary in choices:
		if StringName(choice.get("id", "")) == id and bool(choice.get("enabled", true)):
			if bool(choice.get("destructive", false)) or bool(choice.get("requires_confirmation", false)):
				pending_choice = id
				confirmation_text.text = str(choice.get("confirm_text", choice.get("text", "Xác nhận lựa chọn này?")))
				text_label.hide()
				choice_list.hide()
				confirmation.show()
				hint.text = "Enter / A · Chọn nút    Esc / B · Quay lại"
				body_scroll.scroll_vertical = 0
				cancel_button.grab_focus()
			else:
				_commit_choice(id)
			return

func confirm_choice() -> void:
	if not is_open or pending_choice == &"": return
	for choice: Dictionary in choices:
		if StringName(choice.get("id", "")) == pending_choice and bool(choice.get("enabled", true)):
			_commit_choice(pending_choice)
			return
	cancel_confirmation()

func _commit_choice(id: StringName) -> void:
	close()
	choice_selected.emit(id)

func cancel_confirmation() -> void:
	if pending_choice == &"": return
	var id: StringName = pending_choice
	pending_choice = &""
	confirmation.hide()
	text_label.show()
	choice_list.show()
	hint.text = "↑ ↓ / tay cầm · Chọn    Enter / A · Xác nhận    Tab / Esc · Đóng"
	var button: Button = choice_list.get_node_or_null("Choice_" + String(id)) as Button
	if button != null: button.grab_focus()

func close() -> void:
	if not is_open: return
	is_open = false
	pending_choice = &""
	panel.hide()
	if _previous_focus != null:
		var previous: Control = _previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()
	_previous_focus = null
	closed.emit()

func handle_input(event: InputEvent) -> bool:
	if not is_open: return false
	if DungeonUI.dispatch_controller(get_viewport(), event, _controller_axes): return true
	if event.is_action_pressed(&"ui_cancel"):
		if pending_choice != &"": cancel_confirmation()
		else: close()
		return true
	if event.is_action_pressed(&"inventory"):
		close()
		return true
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode in [KEY_SPACE, KEY_E] or event.physical_keycode in [KEY_SPACE, KEY_E]):
		advance()
		return true
	if pending_choice == &"" and is_typing() and event.is_action_pressed(&"ui_accept"):
		advance()
		return true
	if DungeonUI.is_navigation(event): return false
	# Mouse buttons pass through to GUI; all world keys remain inside this modal.
	return event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion or event is InputEventAction

func _input(event: InputEvent) -> void:
	# Hub routers inherit world pause; the modal remains its own route while paused.
	if (auto_input or get_tree().paused) and handle_input(event): get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
	if (auto_input or get_tree().paused) and is_open: get_viewport().set_input_as_handled()

func _resize() -> void:
	_resize_queued = false
	if not is_inside_tree() or panel == null or is_queued_for_deletion(): return
	var extent: Vector2 = get_viewport().get_visible_rect().size
	var available: Vector2 = (extent - Vector2(40, 48)).max(Vector2(160, 180))
	panel.custom_minimum_size = Vector2.ZERO
	panel.size = Vector2(minf(840, available.x), minf(460, available.y))
	panel.position = Vector2((extent.x - panel.size.x) * 0.5, maxf(16, extent.y - panel.size.y - 24))

func _queue_resize() -> void:
	if _resize_queued or is_queued_for_deletion(): return
	_resize_queued = true
	_resize.call_deferred()
