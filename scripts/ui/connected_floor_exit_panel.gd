extends FloorExitPanel
## Same run and same escrow; this adds only the post-Golem continuation choice.
func initialize(owner_run: DungeonRun) -> void:
	super.initialize(owner_run)
	notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
func _offers_depth() -> bool:
	return run.has_method("can_continue_to_depth") and bool(run.call("can_continue_to_depth"))
func refresh() -> void:
	continue_button.text="Tiếp tục xuống tầng"
	super.refresh()
	if not is_open or not _offers_depth(): return
	continue_button.visible=true
	continue_button.text="Đi sâu · Tầng 4/8"
	continue_button.disabled=run.has_pending_rewards()
	notice.text="Golem đã gục. Đi tiếp cùng nhân vật, đồ và Linh Thạch đang mang; máu, mana và hồi chiêu được giữ. Hoặc trở về sảnh để kết thúc chuyến đi."
	if run.has_pending_rewards(): notice.text+="\nPhần thưởng đang chờ lưu: thử lưu và trở về, hoặc ở lại rồi thử tiếp."
func _continue() -> void:
	if not _offers_depth():
		super._continue(); return
	if not is_open or run.has_pending_rewards(): return
	close()
	if not run.advance_room():
		open()
		notice.text="Chưa lưu được lối đi sâu. Nhân vật và đồ vẫn ở đây; chọn đi sâu để thử lại, hoặc ở lại nhặt đồ."
func _process(delta: float) -> void:
	super._process(delta)
	if exit_hint.visible and _offers_depth(): (exit_hint.get_child(0) as Label).text="E · Đi sâu tầng 4 / trở về sảnh"
