extends Node
## Feedback and an accessible mouse entry for the existing Hub portal.
## The existing router/GameFlow/writer still own input, departure and UID transfer.
const BUILD: String = "20261008-portal-feedback-r2"
var hub: PrologueHub
var panel: PanelContainer
var enter_button: Button
var notice: Label
var last_error: StringName = &""
var last_probe: Dictionary = {}
var last_key: Dictionary = {}

func initialize(owner_hub: PrologueHub) -> void:
	hub = owner_hub
	panel = PanelContainer.new()
	panel.name = "PortalEntrancePanel"
	AntiqueSkin.apply_panel(panel)
	hub.get_node("HubUI").add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	enter_button = Button.new()
	enter_button.name = "EnterDungeon"
	enter_button.text = "Vào hầm ngục · E"
	enter_button.focus_mode = Control.FOCUS_NONE
	enter_button.custom_minimum_size.y = 44.0
	enter_button.pressed.connect(_request_entry)
	content.add_child(enter_button)
	notice = DungeonUI.label("", 14, AntiqueSkin.TEXT)
	notice.name = "DepartureNotice"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(notice)
	panel.hide()
	hub.departure_failed.connect(_on_departure_failed)
	hub.interaction_requested.connect(_on_interaction)
	print("PORTAL_BUILD=", BUILD, " MAIN=", ProjectSettings.get_setting("application/run/main_scene"))

func _can_act() -> bool:
	return is_instance_valid(hub) and hub.is_inside_tree() and not hub.is_queued_for_deletion() and not get_tree().paused and is_instance_valid(hub.player) and hub.player.controls_enabled and hub.player.health.current_health > 0.0 and not hub.gear.modal.is_open and not hub.dialogue.is_open and not hub.station_open and (hub.player.hit_reaction == null or not hub.player.hit_reaction.blocks_controls())

func _at_portal() -> bool:
	return is_instance_valid(hub) and hub.is_inside_tree() and not hub.is_queued_for_deletion() and hub.nearest_station() == &"portal"

func _request_entry() -> void:
	if not _at_portal() or not _can_act(): return
	_trace("mouse_button")
	# Keep all custody/save checks; never call start_campaign directly.
	hub.interact_station(&"portal")

func _on_interaction(id: StringName, _owner_hub: PrologueHub) -> void:
	if id != &"portal": return
	last_error = &""
	_trace("portal_request")
	if hub.campaign_requested.get_connections().is_empty():
		_on_departure_failed(&"missing_game_flow")

func _on_departure_failed(reason: StringName) -> void:
	last_error = reason
	_trace("departure_blocked")
	if is_instance_valid(notice): notice.text = _message(reason)

func _input(event: InputEvent) -> void:
	if not is_instance_valid(hub) or not event is InputEventKey or not event.pressed or event.is_echo(): return
	if event.physical_keycode != KEY_E and event.keycode != KEY_E and not event.is_action_pressed(&"interact"): return
	last_key = {"device": event.device, "keycode": event.keycode, "physical_keycode": event.physical_keycode, "mapped_interact": event.is_action_pressed(&"interact")}
	_trace("key_e")
	if _at_portal() and not last_key["mapped_interact"]:
		last_error = &"interact_key_unmatched"
	# Observe only: consuming or forwarding this event would double the router.

func _trace(kind: String) -> void:
	if not is_instance_valid(hub) or not is_instance_valid(hub.player): return
	last_probe = {"kind": kind, "build": BUILD, "main": ProjectSettings.get_setting("application/run/main_scene"), "hub_scene": hub.scene_file_path, "flow_receivers": hub.campaign_requested.get_connections().size(), "nearest": String(hub.nearest_station()), "position": str(hub.player.global_position), "controls": hub.player.controls_enabled, "inventory_open": hub.gear.modal.is_open, "dialogue_open": hub.dialogue.is_open, "station_open": hub.station_open, "paused": get_tree().paused, "profile_read_only": hub.profile.read_only, "save_result": String(hub.profile.last_commit.get("error", "")), "departure_reason": String(last_error), "key": last_key.duplicate(), "userdata": OS.get_user_data_dir()}
	print("PORTAL_TRACE ", JSON.stringify(last_probe))

func _message(reason: StringName) -> String:
	match reason:
		&"missing_game_flow": return "Scene căn cứ đang chạy riêng. Mở CHAY_GAME.cmd hoặc chạy cả project bằng F5."
		&"interact_key_unmatched": return "Game nhận E nhưng chưa khớp phím tương tác. Hãy nhấp nút Vào hầm ngục."
		&"profile_changed_reload_required": return "Save đã đổi bởi phiên khác. Đóng phiên khác rồi mở lại game. Đồ đang mang được giữ."
		&"profile_read_only_or_invalid_path": return "Dữ liệu lưu đang được bảo vệ. Đồ vẫn được giữ. Mã: profile_read_only_or_invalid_path."
		_: return "Chưa lưu được hành trang; đồ vẫn được giữ. Thử lại hoặc gửi mã: %s." % String(reason)

func _process(_delta: float) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(hub): return
	var was_visible: bool = panel.visible
	var nearby: bool = _at_portal()
	panel.visible = nearby and _can_act()
	if not nearby: last_error = &""
	if not panel.visible:
		if was_visible and is_instance_valid(hub.prompt): hub.prompt.show()
		return
	if last_error == &"" and hub.campaign_requested.get_connections().is_empty():
		notice.text = _message(&"missing_game_flow")
	elif last_error == &"" and hub.profile.read_only:
		notice.text = _message(&"profile_read_only_or_invalid_path")
	else:
		notice.text = _message(last_error) if last_error != &"" else "Nhấn E hoặc nhấp nút. Hành trang chỉ chuyển khi lưu thành công."
	var extent: Vector2 = get_viewport().get_visible_rect().size
	var width: float = minf(480.0, maxf(240.0, extent.x - 32.0))
	panel.size = Vector2(width, maxf(132.0, panel.get_combined_minimum_size().y))
	panel.position = Vector2((extent.x - panel.size.x) * 0.5, maxf(16.0, extent.y - panel.size.y - 18.0))
	hub.prompt.hide()
