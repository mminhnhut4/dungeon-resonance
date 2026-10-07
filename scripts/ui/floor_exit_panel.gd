class_name FloorExitPanel
extends CanvasLayer
## Presents a completed-floor choice; GameFlow remains the return/save owner.
var run: DungeonRun
var is_open: bool = false
var panel: PanelContainer
var heading: Label
var notice: Label
var continue_button: Button
var return_button: Button
var cancel_button: Button
var exit_hint: PanelContainer
var _previous_controls: bool = true
var _previous_focus: WeakRef
var _controller_axes: Dictionary = {}

func initialize(owner_run: DungeonRun) -> void:
	run = owner_run
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	var overlay := ColorRect.new()
	overlay.name = "FloorExitOverlay"
	overlay.color = Color(0.04, 0.025, 0.015, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	var margins := MarginContainer.new()
	margins.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 24)
	overlay.add_child(margins)
	var center := CenterContainer.new()
	margins.add_child(center)
	panel = PanelContainer.new()
	panel.name = "CompletedFloorChoice"
	AntiqueSkin.apply_panel(panel)
	center.add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	heading = DungeonUI.label("TẦNG ĐÃ HOÀN THÀNH", 24, AntiqueSkin.WARM)
	column.add_child(heading)
	column.add_child(AntiqueSkin.divider())
	notice = DungeonUI.label("", 16)
	column.add_child(notice)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	column.add_child(row)
	continue_button = _button("Tiếp tục xuống tầng", _continue)
	return_button = _button("Trở về sảnh", _return_or_retry)
	row.add_child(continue_button)
	row.add_child(return_button)
	cancel_button = _button("Ở lại nhặt đồ · Esc / B", close)
	column.add_child(cancel_button)
	column.add_child(DungeonUI.label("Enter / A: chọn · Mũi tên / D-pad: đổi lựa chọn", 14, AntiqueSkin.MUTED))
	run.pending_save_changed.connect(refresh)
	set_process_input(false)
	overlay.hide()
	exit_hint = PanelContainer.new()
	exit_hint.name = "CompletedFloorExitHint"
	exit_hint.theme = AntiqueSkin.make_theme()
	exit_hint.add_theme_stylebox_override("panel", AntiqueSkin.panel_style(10))
	exit_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	exit_hint.offset_left = -210
	exit_hint.offset_right = 210
	exit_hint.offset_top = -118
	exit_hint.offset_bottom = -70
	exit_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(exit_hint)
	exit_hint.add_child(DungeonUI.label("E · Chọn lối ra: đi tiếp / trở về sảnh", 16, AntiqueSkin.WARM))
	exit_hint.hide()

func _process(_delta: float) -> void:
	exit_hint.visible = not is_open and run.player.controls_enabled and run.can_choose_floor_exit()
	if exit_hint.visible:
		(exit_hint.get_child(0) as Label).text = "E · Trở về sảnh" if run.portal_active else "E · Chọn lối ra: đi tiếp / trở về sảnh"

func _button(text: String, command: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(command)
	return button

func open() -> bool:
	if is_open or not run.can_choose_floor_exit() or not run.player.controls_enabled:
		return false
	is_open = true
	_previous_controls = run.player.controls_enabled
	var focused: Control = get_viewport().gui_get_focus_owner()
	_previous_focus = weakref(focused) if focused != null else null
	_controller_axes.clear()
	TimeScaleClaims.acquire(self, 0.001)
	run.player.suspend_controls(true)
	panel.custom_minimum_size.x = minf(600, get_viewport().get_visible_rect().size.x - 48)
	get_child(0).show()
	set_process_input(true)
	refresh()
	(continue_button if continue_button.visible else return_button).grab_focus()
	return true

func close() -> void:
	# Once return was requested, saving/retry must finish before this run is freed.
	if not is_open or run.outcome != &"": return
	is_open = false
	TimeScaleClaims.release(self)
	run.player.suspend_controls(not _previous_controls or run.player.health.current_health <= 0.0)
	get_child(0).hide()
	set_process_input(false)
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused != null and panel.is_ancestor_of(focused): focused.release_focus()
	if _previous_focus != null:
		var previous: Control = _previous_focus.get_ref() as Control
		if is_instance_valid(previous) and previous.is_visible_in_tree(): previous.grab_focus()
	_previous_focus = null
	run.pending_save_changed.emit()

func refresh() -> void:
	if not is_open: return
	var waiting: bool = run.outcome != &""
	heading.text = "CHIẾN LỢI PHẨM ĐANG ĐƯỢC GIỮ" if waiting else "ĐÃ HẠ GOLEM" if run.portal_active else "TẦNG ĐÃ HOÀN THÀNH"
	continue_button.visible = not waiting and not run.portal_active
	cancel_button.visible = not waiting
	return_button.text = "Thử lưu lại và trở về sảnh" if waiting else "Trở về sảnh"
	return_button.disabled = bool(run.pending_reward_state()["busy"])
	if waiting:
		notice.text = "Linh Thạch trong căn cứ đã đầy. Đồ và phần thưởng vẫn được giữ trong lượt này." if run.pending_reward_state()["return_error"] == &"coin_capacity" else "Chưa lưu được. Đồ và phần thưởng vẫn được giữ trong lượt này. Thử lưu lại để trở về sảnh."
		return_button.grab_focus()
	else:
		notice.text = "Mang về đồ đã nhặt và Linh Thạch đang mang. Đồ còn trên đất không tự thu. Trở về kết thúc lượt này; lượt sau bắt đầu lại từ đầu."
		if not run.portal_active: notice.text += "\nChưa hạ Golem: không tính chiến thắng toàn hầm ngục."

func _continue() -> void:
	if not is_open or run.outcome != &"" or run.portal_active: return
	close()
	run.advance_room()

func _return_or_retry() -> void:
	if not is_open: return
	if run.outcome != &"": run.retry_pending_save()
	else: run.request_floor_return()

func _input(event: InputEvent) -> void:
	if not is_open: return
	# Space is the gameplay jump key and also an engine UI default. Never let it
	# select a floor outcome, including releases/echoes from the entry frame.
	if (event is InputEventKey and event.keycode == KEY_SPACE) or event.is_echo():
		get_viewport().set_input_as_handled()
		return
	if DungeonUI.dispatch_controller(get_viewport(), event, _controller_axes):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode == KEY_TAB:
		if event.pressed:
			var focused: Control = get_viewport().gui_get_focus_owner()
			if focused != null:
				var next: Control = focused.find_prev_valid_focus() if event.shift_pressed else focused.find_next_valid_focus()
				if next != null: next.grab_focus()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if DungeonUI.is_navigation(event) or event is InputEventMouse: return
	get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	TimeScaleClaims.release(self)
