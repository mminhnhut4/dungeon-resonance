class_name DepthGuide
extends Node2D
## Hub-owned guide: concrete next action and five-floor progress, no new save owner.
signal expedition_requested
const Progress = preload("res://scripts/runtime/depth_progress.gd")
const Catalog = preload("res://data/depth_floor_catalog.gd")
const PORTRAIT: Texture2D = preload("res://assets/sprites/npc/depth_v1/lac_an.png")
var hub: PrologueHub
var progress: RefCounted
var npc: HubNpc
var prompt: Label
var panel: Panel
var heading: Label
var objective: Label
var notice: Label
var action: Button
var back: Button
var floor_scroll: ScrollContainer
var floor_column: VBoxContainer
var floor_rows: Array[Label] = []
var opened: bool = false
var previous_controls: bool = true
var previous_launcher: bool = true
var _prompt_key: String = ""

func initialize(owner: PrologueHub) -> void:
	hub = owner
	progress = Progress.new()
	progress.initialize(hub.profile)
	npc = HubNpc.new()
	npc.name = "LacAn"
	npc.position = Vector2(1055, 640)
	npc.set_approved_portrait(PORTRAIT)
	hub.yard.add_child(npc)
	var nameplate := Label.new()
	nameplate.text = "LẠC ẤN · Dẫn đường xuống sâu"
	nameplate.position = Vector2(-115, -98)
	nameplate.add_theme_font_size_override("font_size", 15)
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc.add_child(nameplate)
	prompt = Label.new()
	prompt.position = Vector2(-110, -122)
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	npc.add_child(prompt)
	_build_panel()
	hub.profile.changed.connect(refresh)
	get_viewport().size_changed.connect(_resize)
	refresh()

func near() -> bool:
	if not is_instance_valid(hub) or hub.inside_house: return false
	if hub is ExteriorHub and (hub as ExteriorHub).outside: return false
	return hub.player.global_position.distance_to(npc.global_position) < 85.0

func _process(_delta: float) -> void:
	var key: String = "E · Xem hành trình năm tầng" if near() and not opened else ""
	if key != _prompt_key:
		_prompt_key = key
		prompt.text = key
		prompt.visible = not key.is_empty()

func _input(event: InputEvent) -> void:
	if event.is_echo(): return
	if opened and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"inventory")):
		get_viewport().set_input_as_handled()
		close()
	elif not opened and near() and event.is_action_pressed(&"interact"):
		if hub.station_open or hub.gear.modal.is_open or hub.dialogue.is_open or not hub.player.controls_enabled: return
		get_viewport().set_input_as_handled()
		open()

func open() -> bool:
	if opened or not near() or hub.station_open or hub.gear.modal.is_open or hub.dialogue.is_open: return false
	previous_controls = hub.player.controls_enabled
	previous_launcher = hub.gear.modal.open_button.visible
	hub.gear.modal.open_button.hide()
	hub.player.suspend_controls(true)
	opened = true
	panel.show()
	refresh()
	action.grab_focus()
	return true

func close() -> void:
	if not opened: return
	opened = false
	panel.hide()
	if is_instance_valid(hub.gear.modal): hub.gear.modal.open_button.visible = previous_launcher
	if is_instance_valid(hub.player):
		hub.player.suspend_controls(false)
		hub.player.controls_enabled = previous_controls

func refresh() -> void:
	if progress == null or panel == null: return
	var state: Dictionary = progress.state()
	var unlocked: bool = progress.unlocked()
	heading.text = "LẠC ẤN · NGŨ TẦNG PHONG ẤN"
	objective.text = "Hạ Golem Cổ Bảo trong hầm ngục mở đầu, quay về gặp Lạc Ấn tại sân căn cứ." if not unlocked else "Nhận bản đồ từ Lạc Ấn, xuống năm tầng. Dọn quái để mở cửa E; có thể quay về sau mỗi tầng đã dọn." if not state["accepted"] else "Đã nhận hành trình · Dọn từng tầng, nhặt thưởng, hạ Huyền Uyên Chấp Ấn ở tầng 5 rồi quay về." if not state["boss_defeated"] else "Đã phá Ngũ Tầng Phong Ấn. Bạn có thể quay lại để luyện cách đánh và tìm hốc thưởng."
	for index: int in 5:
		var complete: bool = int(state["cleared"]) > index
		floor_rows[index].text = "%s %d · %s\n%s" % ["✓" if complete else "→" if int(state["cleared"]) == index else "○", index + 1, Catalog.FLOORS[index]["name"], Catalog.FLOORS[index]["tactic"]]
		floor_rows[index].modulate = Color(.65, .83, .72) if complete else Color(1, .91, .72) if int(state["cleared"]) == index else Color(.78, .82, .88)
	action.text = "Hạ Golem để mở hành trình" if not unlocked else "Nhận bản đồ · Lưu nhiệm vụ" if not state["accepted"] else "Xuống tầng 1 · Mang trang bị đang chuẩn bị"
	action.disabled = not unlocked or not progress.available()
	_resize()

func _act() -> void:
	if not progress.unlocked(): return
	if not progress.state()["accepted"]:
		if not progress.accept():
			notice.text = "Chưa lưu được nhiệm vụ. Tiến độ và đồ của bạn được giữ; có thể thử lại."
		else: notice.text = "Đã lưu bản đồ. Chuẩn bị bùa và trang bị rồi chọn xuống tầng."
		refresh()
	else:
		close()
		expedition_requested.emit()

func _build_panel() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 32
	add_child(canvas)
	# A fixed viewport-sized shell must not inherit wrapped text's cached
	# minimum height while hidden. Only the five-floor body is scrollable.
	panel = Panel.new()
	panel.name = "DepthJourneyPanel"
	panel.clip_contents = true
	canvas.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("111923")
	style.border_color = Color("b99862")
	style.set_border_width_all(2)
	style.content_margin_left = 20; style.content_margin_right = 20
	style.content_margin_top = 16; style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	heading = _label(panel, 23)
	objective = _label(panel, 16)
	floor_scroll = ScrollContainer.new()
	floor_scroll.name = "FloorScroll"
	floor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(floor_scroll)
	floor_column = VBoxContainer.new()
	floor_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	floor_column.add_theme_constant_override("separation", 12)
	floor_scroll.add_child(floor_column)
	for index: int in 5: floor_rows.append(_label(floor_column, 15))
	notice = _label(panel, 15)
	action = Button.new()
	action.custom_minimum_size.y = 38
	action.pressed.connect(_act)
	panel.add_child(action)
	back = Button.new()
	back.text = "Quay lại chuẩn bị · Esc"
	back.pressed.connect(close)
	panel.add_child(back)
	panel.hide()

func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	# These are actionable quest UI, not world debugging labels.
	label.set_meta(&"debug_keep", true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _resize() -> void:
	if panel == null: return
	var extent: Vector2 = get_viewport_rect().size
	panel.size = Vector2(minf(700, extent.x - 32), minf(600, extent.y - 32))
	panel.position = (extent - panel.size) * .5
	var width: float = panel.size.x - 40.0
	heading.position = Vector2(20, 16)
	heading.size = Vector2(width, 34)
	objective.position = Vector2(20, 60)
	objective.size = Vector2(width, 66)
	var action_y: float = panel.size.y - 98.0
	var notice_height: float = 48.0 if not notice.text.is_empty() else 0.0
	notice.visible = notice_height > 0.0
	notice.position = Vector2(20, action_y - notice_height - 10.0)
	notice.size = Vector2(width, notice_height)
	floor_scroll.position = Vector2(20, 136)
	floor_scroll.size = Vector2(width, maxf(48.0, action_y - notice_height - 20.0 - 136.0))
	floor_column.custom_minimum_size.x = width - 16.0
	floor_column.size.x = width - 16.0
	for row: Label in floor_rows: row.size.x = width - 16.0
	floor_scroll.queue_sort()
	floor_column.queue_sort()
	action.position = Vector2(20, action_y)
	action.size = Vector2(width, 38)
	back.position = Vector2(20, panel.size.y - 50.0)
	back.size = Vector2(width, 34)

func _exit_tree() -> void:
	if opened and is_instance_valid(hub) and not hub.is_queued_for_deletion(): close()
	if is_instance_valid(hub) and is_instance_valid(hub.profile) and hub.profile.changed.is_connected(refresh): hub.profile.changed.disconnect(refresh)
