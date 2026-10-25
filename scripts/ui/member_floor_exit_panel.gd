extends "res://scripts/ui/connected_floor_exit_panel.gd"
func refresh() -> void:
	super.refresh()
	if not is_open or not run.has_method("can_continue_after_warden") or run.outcome!=&"":return
	# Capability lookup avoids a strong script reference back to the preloading run.
	var member: Variant=run
	if member.can_continue_after_warden():
		continue_button.visible=true;continue_button.text="Đi sâu · Tầng 9/30"
		continue_button.disabled=run.has_pending_rewards()
		heading.text="PHONG ẤN TẦNG 8 ĐÃ MỞ"
		notice.text="Đi sâu cùng nhân vật, đồ, máu, năng lượng và hồi chiêu hiện tại. Các tầng mới có chướng ngại và cạm bẫy; hoặc trở về để kết thúc chuyến đi."
	elif member.member_active:
		heading.text="ĐÀI VỌNG ÂM · LỐI TRỞ VỀ" if member.member_floor==30 else "LỐI RA TẦNG %d/30"%member.member_floor
		continue_button.visible=member.member_floor<30 and run.outcome==&""
		var only_member_pending: bool=int(run.pending_reward_state().get("member_objective_count",0))>0 and not bool(run.pending_reward_state()["boss_proof_pending"]) and int(run.pending_reward_state()["pickup_count"])==0
		continue_button.disabled=run.has_pending_rewards() and not only_member_pending
		continue_button.text="Đi sâu · Tầng %d/30"%(member.member_floor+1)
		notice.text="Mang về đồ đã nhặt; đồ trên đất không tự thu. Tiến độ được xác nhận khi chọn lối ra. Rương sau rào lửa là nhánh tùy chọn."
		if only_member_pending:continue_button.text="Thử lưu tiến độ và đi tiếp"
		if run.has_pending_rewards():notice.text+="\nChưa lưu được tiến độ: chọn thử lưu hoặc ở lại. Nhân vật và đồ vẫn được giữ."
func _continue() -> void:
	if int(run.pending_reward_state().get("member_objective_count",0))>0:
		if not run.retry_pending_rewards():refresh();return
	super._continue()
func _return_or_retry() -> void:
	if int(run.pending_reward_state().get("member_objective_count",0))>0:
		if not run.retry_pending_rewards():refresh();return
	super._return_or_retry()
func _process(delta: float) -> void:
	super._process(delta)
	if exit_hint.visible and run.has_method("can_continue_after_warden"):
		var member: Variant=run
		if member.can_continue_after_warden():(exit_hint.get_child(0) as Label).text="E · Đi sâu tầng 9 / trở về sảnh"
