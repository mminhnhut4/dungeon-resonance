extends FloorExitPanel
## Only copy and available choices differ; return/retry uses the existing owner.
func refresh() -> void:
	super.refresh()
	if not is_open: return
	continue_button.hide()
	if run.outcome == &"":
		heading.text = "RỜI MỎ LINH THẠCH VỠ"
		notice.text = "Mang về đồ đã nhặt. Đồ còn trên đất không tự thu.\nĐây là mẫu mỏ riêng; trở về không hoàn thành tầng chính hay hạ Golem."
		return_button.grab_focus()

func _process(delta: float) -> void:
	super._process(delta)
	if exit_hint.visible:
		(exit_hint.get_child(0) as Label).text = "E · Rời mỏ, mang đồ về căn cứ"
