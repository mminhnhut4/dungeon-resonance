class_name AmdBootBeforeUi
extends Node
## Dedicated opt-in entrypoint. Normal launch and TEAM TEST are unchanged.
var api: AmdApiClient
var store := AmdSlotStore.new()
var capsule := AmdCapsule.new()
var flow: GameFlow
var user_id: String = ""
var account_email: String = ""
var busy: bool = false
var needs_cloud_load: bool = false
var local_slot: Dictionary = {}
var status: Label
var account: Label
var email: LineEdit
var password: LineEdit
var auth_box: VBoxContainer
var controls: VBoxContainer
var menu: PanelContainer
var buttons: Array[Button] = []
signal signed_in
signal cloud_saved
signal cloud_loaded

func _ready() -> void:
	api = AmdApiClient.new(); add_child(api)
	api.completed.connect(_response)
	_build_ui()
	var url: String = OS.get_environment("AMD201_API_URL")
	if url == "": url = "http://127.0.0.1:5086"
	if not AmdSlotStore.isolated() or not api.configure(url):
		_set_status("Hãy mở bằng Run-AMD201.ps1: cần vùng lưu riêng và API HTTPS hoặc loopback.")
		for button: Button in buttons: button.disabled = true
		return
	_set_status("AMD201 · tiến trình riêng từng tài khoản. Mật khẩu tối thiểu 12 ký tự.")

func _build_ui() -> void:
	var layer := CanvasLayer.new(); layer.layer = 90; add_child(layer)
	var toggle := Button.new(); toggle.text = "AMD201 · Tài khoản / Cloud"; toggle.position = Vector2(820, 8)
	layer.add_child(toggle)
	menu = PanelContainer.new(); menu.position = Vector2(784,48); menu.custom_minimum_size = Vector2(470,0); layer.add_child(menu)
	var margin := MarginContainer.new()
	for key: String in ["margin_left","margin_right","margin_top","margin_bottom"]: margin.add_theme_constant_override(key,16)
	menu.add_child(margin)
	var column := VBoxContainer.new(); column.add_theme_constant_override("separation",10); margin.add_child(column)
	account = Label.new(); account.text = "DUNGEON RESONANCE · AMD201"; column.add_child(account)
	status = Label.new(); status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; status.custom_minimum_size = Vector2(430,70); column.add_child(status)
	auth_box = VBoxContainer.new(); column.add_child(auth_box)
	email = LineEdit.new(); email.placeholder_text = "Email tài khoản thử"; auth_box.add_child(email)
	password = LineEdit.new(); password.secret = true; password.placeholder_text = "Mật khẩu (12–128 ký tự)"; auth_box.add_child(password)
	_button(auth_box,"Đăng nhập",func() -> void: authenticate(false))
	_button(auth_box,"Đăng ký",func() -> void: authenticate(true))
	controls = VBoxContainer.new(); controls.visible = false; column.add_child(controls)
	_button(controls,"Lưu Hub lên cloud / thử lại hàng chờ",upload)
	_button(controls,"Tải cloud · giữ bản local cũ",download)
	_button(controls,"Xem trạng thái cloud",refresh)
	_button(controls,"Đăng xuất (ở Hub)",logout)
	var help := Label.new(); help.text = "Chơi bằng WASD / Space / chuột như bản thường.\nLưu/tải cloud ở Hub; không lưu HP/cooldown của lượt đi.\nBản cũ và save cá nhân được giữ riêng."; help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; controls.add_child(help)
	toggle.pressed.connect(func() -> void: menu.visible = not menu.visible)

func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new(); button.text = text; button.pressed.connect(action); parent.add_child(button); buttons.append(button)

func _set_status(text: String) -> void:
	status.text = text

func _busy(value: bool) -> void:
	busy = value
	for button: Button in buttons: button.disabled = value

func authenticate(register: bool) -> void:
	if busy or user_id != "": return
	var credentials: Dictionary = {"email":email.text.strip_edges(),"password":password.text}
	_busy(true)
	if not api.send("register" if register else "login", "/api/auth/register" if register else "/api/auth/login", HTTPClient.METHOD_POST, credentials):
		_busy(false); _set_status("Không khởi tạo được yêu cầu.")
	else: _set_status("Đang kết nối… game không chờ đồng bộ mạng.")
	password.clear()

func _start_slot(path: String) -> void:
	if is_instance_valid(flow):
		remove_child(flow); flow.queue_free()
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path
	add_child(flow)

func _open_account() -> bool:
	local_slot = store.read_active(user_id)
	if local_slot.is_empty():
		var path: String = store.create_slot(user_id)
		if path == "" or not store.activate(user_id,path,0): return false
		local_slot = store.read_active(user_id)
	_start_slot(str(local_slot["path"]))
	auth_box.visible = false; controls.visible = true
	account.text = "AMD201 · " + account_email
	return true

func upload() -> void:
	if busy or user_id == "": return
	if needs_cloud_load: _set_status("Cloud đã có bản mới hơn. Tải cloud trước; bản local cũ vẫn được giữ."); return
	if not AmdCapsule.safe_hub(flow): _set_status("Trở về Hub, đóng hội thoại rồi lưu cloud."); return
	var pending: Dictionary = store.pending(user_id)
	if pending.is_empty():
		var captured: Dictionary = capsule.capture(flow,user_id)
		if captured.is_empty(): _set_status("Chưa lưu: " + capsule.error); return
		pending = store.set_pending(user_id,{"expectedRevision":int(local_slot.get("baseRevision",0)),"capsule":captured})
		if pending.is_empty(): _set_status("Không ghi được hàng chờ: " + store.error); return
	_busy(true)
	if not api.send("save","/api/progress",HTTPClient.METHOD_PUT,pending["body"],pending["operation"]):
		_busy(false); _set_status("Mạng chưa sẵn sàng; hàng chờ được giữ để thử lại đúng giao dịch.")
	else: _set_status("Đang lưu cloud; bạn có thể tiếp tục di chuyển.")

func download() -> void:
	if busy or user_id == "" or not AmdCapsule.safe_hub(flow): _set_status("Tải cloud tại Hub sau khi đóng hội thoại."); return
	if capsule.capture(flow,user_id).is_empty(): _set_status("Giữ local: " + capsule.error); return
	_busy(true)
	if not api.send("load","/api/progress"): _busy(false); _set_status("Không bắt đầu được yêu cầu tải.")
	else: _set_status("Đang tải. Chỉ kích hoạt slot mới sau kiểm seal/schema/NPC; bản local cũ được giữ.")

func refresh() -> void:
	if busy or user_id == "": return
	_busy(true)
	if not api.send("summary","/api/progress/summary"): _busy(false)

func logout() -> void:
	if busy or user_id == "": return
	if not AmdCapsule.safe_hub(flow): _set_status("Trở về Hub trước khi đổi tài khoản để giữ kết quả lượt đi."); return
	# Commit the local Hub before disposing its world, even if the server is offline.
	if capsule.capture(flow,user_id).is_empty(): _set_status("Chưa đăng xuất: " + capsule.error); return
	_busy(true)
	if not api.send("logout","/api/auth/logout",HTTPClient.METHOD_POST): _finish_logout(false)

func _finish_logout(revoked: bool) -> void:
	api.forget_account()
	if is_instance_valid(flow): remove_child(flow); flow.queue_free()
	flow = null; user_id = ""; account_email = ""; local_slot = {}; needs_cloud_load = false
	controls.visible = false; auth_box.visible = true; account.text = "DUNGEON RESONANCE · AMD201"
	_busy(false)
	_set_status("Đã đăng xuất và thu hồi phiên server." if revoked else "Đã xóa phiên trên máy. Server chưa xác nhận thu hồi; phiên cũ hết hạn sau tối đa 8 giờ.")

func _response(tag: String, code: int, data: Dictionary, problem: String) -> void:
	_busy(false)
	if tag == "logout": _finish_logout(problem == ""); return
	if problem != "":
		if code == 409 and tag == "save": needs_cloud_load = true
		_set_status(("Chưa có tiến trình cloud; bản local vẫn giữ." if code == 404 else "Chưa hoàn tất: " + problem) + (" · Có thể thử lại đúng hàng chờ." if tag == "save" and code != 409 else ""))
		if code == 401 and user_id != "":
			api.access_token = ""
			# Keep the local world. Reauthentication to the SAME account is required.
			_set_status("Phiên hết hạn. Trở về Hub và đăng xuất để đăng nhập lại; tiến trình local vẫn giữ.")
		return
	match tag:
		"register": _set_status("Đã tạo tài khoản. Nhập lại mật khẩu rồi đăng nhập.")
		"login":
			if not data.get("user") is Dictionary: _set_status("Phản hồi đăng nhập không hợp lệ."); return
			var identity: Dictionary = data.get("user",{})
			if not AmdSlotStore.valid_user(str(identity.get("id",""))) or not data.get("accessToken") is String: _set_status("Phản hồi đăng nhập không hợp lệ."); return
			user_id = str(identity["id"]); account_email = str(identity.get("email",email.text)); api.access_token = data["accessToken"]
			if not _open_account():
				api.forget_account(); user_id = ""; _set_status("Không mở được slot riêng: " + store.error); return
			_set_status("Đã đăng nhập. Dùng Tải cloud trên máy mới; local không tự ghi đè cloud.")
			signed_in.emit()
		"summary":
			_set_status("Cloud revision %d · tầng %d · %d Tàn Hồn. Local giữ revision gốc %d." % [int(data.get("revision",0)),int(data.get("summary",{}).get("clearedFloor",0)),int(data.get("summary",{}).get("souls",0)),int(local_slot.get("baseRevision",0))])
		"save":
			if not AmdCapsule.integer_in(data.get("revision"),1,9007199254740991) or not AmdCapsule.integer_in(data.get("currentRevision"),1,9007199254740991): _set_status("Phản hồi lưu không hợp lệ; hàng chờ vẫn giữ."); return
			var revision: int = int(data.get("revision",-1))
			var current: int = int(data.get("currentRevision",-1))
			if revision < 1 or current < revision: _set_status("Phản hồi lưu không hợp lệ; hàng chờ vẫn giữ."); return
			if not store.activate(user_id,str(local_slot["path"]),revision): _set_status("Cloud đã lưu nhưng metadata local lỗi; thử lại hàng chờ."); return
			local_slot = store.read_active(user_id)
			if not store.clear_pending(user_id): _set_status("Cloud đã lưu; chưa xóa được hàng chờ local, hãy thử lại."); return
			needs_cloud_load = current > revision
			_set_status("Đã lưu cloud revision %d.%s" % [revision," Có bản mới hơn trên máy khác; cần tải lại." if needs_cloud_load else ""])
			cloud_saved.emit()
		"load":
			if not AmdCapsule.safe_hub(flow): _set_status("Đã nhận dữ liệu; trở về Hub và bấm tải lại để kích hoạt an toàn."); return
			if not data.get("capsule") is Dictionary or not AmdCapsule.integer_in(data.get("revision"),1,9007199254740991): _set_status("Phản hồi cloud không hợp lệ."); return
			if int(data["revision"]) < int(local_slot.get("baseRevision",0)): _set_status("Giữ local: cloud revision cũ hơn bản đã đồng bộ."); return
			var path: String = capsule.stage(data["capsule"],user_id,store)
			if path == "": _set_status("Giữ nguyên local; từ chối cloud: " + capsule.error); return
			if not store.activate(user_id,path,int(data["revision"])): _set_status("Giữ nguyên local: " + store.error); return
			local_slot = store.read_active(user_id)
			needs_cloud_load = not store.clear_pending(user_id)
			_start_slot(path)
			if needs_cloud_load: _set_status("Đã tải slot mới nhưng chưa xóa được hàng chờ cũ; sửa quyền ghi local rồi tải lại trước khi lưu."); return
			_set_status("Đã tải cloud vào slot mới, giữ bản local trước đó. Không khôi phục HP/cooldown giữa chuyến.")
			cloud_loaded.emit()
