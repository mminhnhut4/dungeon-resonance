extends RefCounted
const CourierProgress = preload("res://tests/integration_fixtures/reviewed_opening/courier_progress.gd")
## Content adapter. The injected resource owner alone commits an economic choice.

signal choice_committed(event: Dictionary)
var profile: SanctuaryProfile
var transaction_owner: Object
var context: StringName = &""
var busy: bool = false

func initialize(source: SanctuaryProfile, owner: Object = null) -> void:
	profile = source
	transaction_owner = owner

func arm(source: StringName) -> void:
	context = source if source in [&"healer", &"pilgrim", &"shrine"] else &""

func objectives() -> Dictionary:
	# One canonical getter supplies both the UI projection and commit signal.
	# Schema2 may return the five-key namespace state; v1 returns a projection.
	if profile == null: return CourierProgress.snapshot(CourierProgress.empty(), true)
	var value: Dictionary = profile.courier_objectives()
	if value.has("available") and not value["available"] is bool: return CourierProgress.snapshot(CourierProgress.empty(), true)
	var state: Dictionary = {}
	for key: String in CourierProgress.empty(): state[key] = value.get(key)
	if not CourierProgress.valid(state): return CourierProgress.snapshot(CourierProgress.empty(), true)
	return CourierProgress.snapshot(state, not bool(value.get("available", true)))

func lines(source: StringName) -> Array[String]:
	var state: Dictionary = objectives()
	if not state["available"]: return ["Phiếu tiếp tế chưa thể đối chiếu. Đường đi và việc tịnh hóa tại Thanh Vy vẫn mở."]
	if source == &"healer":
		if not state["accepted"]: return ["Ngươi làm nghề đưa thư; ta có một phiếu nhờ chuyển vật tư. Lá thư ngươi đang mang vẫn là việc riêng, phiếu này không xác nhận đã giao thư.", "Người hành hương ở miếu trên Đường Hành Hương là một liên lạc môn phái. Họ chỉ cho người mới đường học điều tức; ngươi có thể hỏi rồi tự quyết có đóng góp hay không. Nếu không gặp người ấy, đọc bảng tiếp nhận cạnh miếu."]
		if state["outcome"] == "help": return ["Phiếu đã ghi phần đóng góp cho trạm chữa. Ta nhớ việc ngươi đã giúp. Việc tu luyện riêng và lá thư chính vẫn còn phía trước."]
		if state["outcome"] == "prepare": return ["Phiếu đã ghi lựa chọn chuẩn bị tu luyện cho bản thân. Ngươi không mắc nợ ta vì đã chọn đường ấy; khi sẵn sàng vẫn có thể giúp người khác."]
		return ["Phiếu tiếp tế vẫn chờ lựa chọn. Hỏi liên lạc ở miếu hoặc đọc bảng tiếp nhận; không cần chờ ta để tiếp tục lên đường."]
	var result: Array[String] = []
	result.append("Bảng tiếp nhận ở miếu lưu lời hướng dẫn và phiếu đóng góp. Nó không đại diện lời nói hay mạng sống của người liên lạc." if source == &"shrine" else "Ta nhận việc liên lạc của môn phái trên đường này. Người mới cần học cách điều tức và chuẩn bị trước chuyến đi; Thanh Vy có thể giúp ngươi tịnh hóa.")
	if not state["accepted"]: result.append("Nếu muốn thử một việc đưa vật tư, hỏi Thanh Vy ở căn cứ để nhận phiếu. Ngươi vẫn tự do đi tiếp.")
	elif state["outcome"] != "": result.append("Phiếu đã được chốt: %s. Một phiếu chỉ có một lựa chọn; không nhận lại khi đổi vùng hay tải hồ sơ." % ("giúp trạm chữa" if state["outcome"] == "help" else "chuẩn bị tu luyện"))
	else: result.append("Phiếu cho một lựa chọn: giữ phần chuẩn bị tu luyện cho mình hoặc góp cho trạm chữa của Thanh Vy. Hãy đọc hậu quả trước khi xác nhận; có thể để sau. Đây không phải lời gia nhập môn phái.")
	return result

func quote(choice: StringName) -> Dictionary:
	if not objectives()["available"] or choice not in CourierProgress.CHOICES: return {}
	if transaction_owner == null or not is_instance_valid(transaction_owner) or not transaction_owner.has_method(&"quote_courier_choice") or not transaction_owner.has_method(&"commit_courier_choice"): return {}
	var value: Variant = transaction_owner.call(&"quote_courier_choice", choice)
	if not value is Dictionary or not value.get("available") is bool or not value.get("consequence") is String or value["consequence"].is_empty(): return {}
	return value.duplicate(true)

func choices(source: StringName) -> Array[Dictionary]:
	var state: Dictionary = objectives()
	var result: Array[Dictionary] = []
	if not state["available"]: return result
	if source == &"healer":
		if not state["accepted"]: result.append({"id": &"courier_accept", "text": "Nhận phiếu chuyển vật tư · Việc phụ, có thể để sau"})
		return result
	if not state["accepted"] or state["outcome"] != "": return result
	if not state["contact_recorded"]:
		result.append({"id": &"courier_contact", "text": "Đối chiếu phiếu và nghe hướng học điều tức"})
		return result
	for choice: StringName in CourierProgress.CHOICES:
		var offer: Dictionary = quote(choice)
		var consequence: String = offer.get("consequence", "Lựa chọn này chưa khả dụng. Vẫn có thể tịnh hóa tại Thanh Vy và tiếp tục hành trình.")
		result.append({"id": StringName("courier_" + String(choice)), "text": ("Chuẩn bị tu luyện cho mình" if choice == &"prepare" else "Góp vật tư cho trạm chữa của Thanh Vy") + " · " + consequence, "enabled": offer.get("available", false), "requires_confirmation": true, "confirm_text": consequence + " Một phiếu chỉ chọn một lần. Có thể quay lại trước khi xác nhận."})
	return result

func apply_action(action: StringName) -> Dictionary:
	var response: Dictionary = {"handled": false, "success": false, "source": context, "message": ""}
	if busy or context == &"" or not objectives()["available"]: return response
	if action == &"courier_accept" and context == &"healer":
		busy = true
		response["handled"] = true
		response["success"] = profile.accept_courier_opportunity()
	elif action == &"courier_contact" and context in [&"pilgrim", &"shrine"]:
		busy = true
		response["handled"] = true
		response["success"] = profile.record_courier_contact(context)
	elif action in [&"courier_prepare", &"courier_help"] and context in [&"pilgrim", &"shrine"]:
		var choice := StringName(String(action).trim_prefix("courier_"))
		var state: Dictionary = objectives()
		if not state["contact_recorded"]: return response
		response["handled"] = true
		busy = true
		if state["outcome"] != "": response["success"] = state["outcome"] == String(choice)
		elif quote(choice).get("available", false):
			var committed: bool = bool(transaction_owner.call(&"commit_courier_choice", choice))
			var committed_state: Dictionary = objectives()
			response["success"] = committed and committed_state["available"] and committed_state["outcome"] == String(choice)
			if response["success"]: choice_committed.emit(committed_state["committed_event"].duplicate(true))
	else: return response
	response["message"] = "Phiếu đã được ghi. Có thể tiếp tục đi đường hoặc trở về Thanh Vy." if response["success"] else "Chưa chốt được phiếu. Lựa chọn trước đó được giữ; thử lại hoặc đóng để tiếp tục đi đường."
	busy = false
	return response
