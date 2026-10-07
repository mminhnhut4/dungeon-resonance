class_name RunSaveRecovery
extends CanvasLayer
## Minimal nonmodal retry affordance; tracker/UI can observe the same state.
var run: DungeonRun
var panel: PanelContainer
var message: Label
var retry_button: Button

func initialize(owner_run: DungeonRun) -> void:
	run = owner_run
	layer = 25
	panel = PanelContainer.new()
	AntiqueSkin.apply_panel(panel)
	panel.position = Vector2(24, 210)
	panel.custom_minimum_size = Vector2(300, 0)
	add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	message = Label.new()
	message.custom_minimum_size.x = 300
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(message)
	retry_button = Button.new()
	retry_button.text = "Thử lưu lại"
	retry_button.pressed.connect(run.retry_pending_save)
	column.add_child(retry_button)
	run.pending_save_changed.connect(refresh)
	refresh()

func refresh() -> void:
	var state: Dictionary = run.pending_reward_state()
	panel.visible = run.has_pending_save() and not (is_instance_valid(run.floor_exit) and run.floor_exit.is_open)
	message.text = "Linh Thạch trong căn cứ đã đầy. Phần thưởng vẫn đang giữ." if state["return_error"] == &"coin_capacity" else "Chưa lưu được tiến triển. Chứng tích, phần thưởng và đồ đang mang vẫn được giữ trong phiên này."
	retry_button.disabled = bool(state["busy"])
