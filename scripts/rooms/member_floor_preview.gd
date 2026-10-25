class_name MemberFloorPreview
extends MemberActorArena
## Explicit QA entry for viewing the authored floors; does not grant campaign proofs.
func reset_trial(index: int=0) -> void:
	selected=clampi(index,0,21);generation+=1;processed_deaths.clear();defeats=0;reward_events=0
	executor.clear_entities();gear.loot.clear()
	if is_instance_valid(room):remove_child(room);room.queue_free()
	room=MemberDungeonRoom.new();room.floor_number=9+selected;room.player=player;room.feedback=feedback
	room.member_enemy_defeated.connect(_defeated);add_child(room)
	player.reset_movement_at(Vector2(150,640));player.controls_enabled=true
	var camera:=player.get_node("Camera2D") as Camera2D
	camera.limit_left=32;camera.limit_right=roundi(MemberFloorCatalog.width(9+selected))-32;camera.limit_bottom=800
	camera.reset_smoothing();camera.force_update_scroll()
func _ready() -> void:
	super._ready();print("MEMBER_PREVIEW_STARTED floor=",9+selected)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_PAGEDOWN:reset_trial(selected+1);get_viewport().set_input_as_handled()
		elif event.keycode==KEY_PAGEUP:reset_trial(selected-1);get_viewport().set_input_as_handled()
		elif event.keycode==KEY_R:reset_trial(selected);get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
	heading.text="XEM THỬ TẦNG %d · %s"%[9+selected,MemberFloorCatalog.floor_data(9+selected)["name"]]
	detail.text="PageUp/PageDown: chọn tầng · R: dựng lại · Điều khiển/bùa gốc\nKhông lưu/không thưởng · HP %d/%d · Quái hạ %d · Cổng campaign mở theo nhiệm vụ"%[roundi(player.health.current_health),roundi(player.health.maximum_health),defeats]
