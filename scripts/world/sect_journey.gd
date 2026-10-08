class_name SectJourney
extends Node
## Geographical quest interaction only. Existing dialogue owns focus/time; profile owns writes.
var hub: ExteriorHub
var progress:=SectJourneyProgress.new()
var context: StringName=&""
var context_room: StringName=&""
var offered: StringName=&""

func initialize(owner: ExteriorHub) -> void:
	hub=owner
	progress.initialize(hub.profile)
	hub.dialogue.choice_selected.connect(_choice)
	hub.dialogue.closed.connect(_closed)

func can_enter(room: StringName) -> bool:
	return progress.can_enter(room)

func interact(id: StringName) -> bool:
	if id not in [&"sect_register",&"sect_marker_west",&"sect_marker_east",&"sect_history"] or not hub.outside or not is_instance_valid(hub.exterior) or hub.nearest_station()!=id or not hub._can_travel() or not hub.player.motor.is_grounded(): return false
	context=id; context_room=hub.exterior.room_id
	_open()
	return true

func _faction() -> String:
	var id: String=SectRouteCatalog.faction(context_room)
	if not id.is_empty(): return id
	for key: String in SectRouteCatalog.FACTIONS:
		if context_room==SectRouteCatalog.ROAD_ROOMS[key]: return key
	return ""

func _open(message: String="") -> void:
	var id: String=_faction()
	if id.is_empty(): return
	var entry: Dictionary=progress.state()[id]
	var lines: Array[String]=[]
	var choices: Array[Dictionary]=[]
	offered=&""
	var name: String="Sổ tiếp nhận · "+String(SectRouteCatalog.LABELS[id])
	if context==&"sect_history":
		name="Bia lời thề · "+String(SectRouteCatalog.LABELS[id])
		lines=["Giữ đường thông để còn người trở về. Hai bản ghi khác nhau không đủ để kết tội cả một môn phái." if id=="thanh_van" else "Giữ dòng nước để lò còn làm việc. Ghi đúng phần mình nhìn thấy; đừng biến suy đoán thành lời kết tội.","Quyền khách cho phép tham quan sân này. Nghi thức gia nhập, truyền công và kế nhiệm chưởng môn chưa được mở; không có khoản phí hay phần thưởng ẩn tại đây."]
	elif context in [&"sect_marker_west",&"sect_marker_east"]:
		var side: String="west" if context==&"sect_marker_west" else "east"
		name="Mốc đường tây" if side=="west" else "Mốc đường đông"
		lines=[SectRouteCatalog.DESCRIPTIONS[id][0 if side=="west" else 1],"Ghi lại tại chỗ rồi trở về sổ tiếp nhận phía đông. Chọn Để sau sẽ không ghi tiến độ."]
		if entry["accepted"] and not entry["markers"].has(side):
			offered=StringName("sect_"+side)
			choices.append({"id":offered,"text":"Ghi quan sát này vào nhiệm vụ","enabled":progress.available()})
		else: lines.append("Quan sát này đã được ghi." if entry["markers"].has(side) else "Hãy nhận việc ở sổ tiếp nhận trước.")
	else:
		lines=["Thanh Vân giữ đường núi; Xích Lô giữ đường hàng và nước làm nguội. Dấu niêm đang không khớp, nhưng chưa có bằng chứng để quy lỗi cho ai."]
		if not entry["accepted"]:
			lines.append("Nhận việc để mở lối vào "+("Vân Quan" if id=="thanh_van" else "Đê Đất Đỏ")+". Đọc hai mốc có đèn ở phía tây và đông bằng phím E, rồi nộp ở sổ cạnh chấp sự trong khuôn viên. Không cần đánh hoặc nộp tiền.")
			offered=&"sect_accept"
			choices.append({"id":offered,"text":"Nhận việc · Mở lối vào môn phái","enabled":progress.available()})
		elif entry["guest"]:
			lines.append("Đã đối chiếu đủ hai quan sát. Bạn có quyền khách; cửa đông trong khuôn viên dẫn vào "+("Tùng Đình" if id=="thanh_van" else "Sân Dẫn Thủy")+". Cửa tây là đường về. Quyền khách không phải chức chưởng môn.")
		else:
			lines.append("Đã ghi %d/2 mốc. %s" % [entry["markers"].size(),"Đọc mốc tây và đông tại khuôn viên, rồi trở lại sổ tiếp nhận trong đó. Mở M để xem nhiệm vụ." if entry["markers"].size()<2 else "Trở lại sổ tiếp nhận cạnh chấp sự trong khuôn viên để trình ghi chép."])
			if entry["markers"].size()==2 and context_room==SectRouteCatalog.first(id):
				offered=&"sect_guest"
				choices.append({"id":offered,"text":"Trình hai ghi chép · Nhận quyền khách","enabled":progress.available()})
	if not message.is_empty(): lines.insert(0,message)
	if not progress.available(): lines.append("Hồ sơ tông môn chưa sẵn sàng để ghi. Không có tiến độ hoặc tài nguyên nào bị trừ.")
	choices.append({"id":&"sect_later","text":"Để sau · Tiếp tục đi đường"})
	hub._dialogue_previous_controls=hub.player.controls_enabled
	hub.player.suspend_controls(true)
	TimeScaleClaims.acquire(hub.dialogue,.1)
	(hub.gear.modal as InventoryScreen).open_button.hide()
	hub.dialogue.open(name,lines,choices)

func _choice(id: StringName) -> void:
	if context==&"" or id!=offered or not String(id).begins_with("sect_"): return
	# A stale callback cannot remotely accept/submit a quest after a door or movement.
	if not hub.outside or not is_instance_valid(hub.exterior) or hub.exterior.room_id!=context_room or hub.nearest_station()!=context or not hub.player.motor.is_grounded(): return
	var faction_id: String=_faction()
	var event: String=String(id).trim_prefix("sect_")
	if event in ["west","east"] and context_room!=SectRouteCatalog.first(faction_id): return
	if event=="guest" and context_room!=SectRouteCatalog.first(faction_id): return
	var accepted: bool=progress.record(faction_id,event)
	_open("Đã lưu. Mở M để xem bước tiếp theo." if accepted else "Chưa ghi được nhiệm vụ. Các mốc, hành trang và tài nguyên cũ được giữ; bạn có thể thử lại.")

func _closed() -> void:
	_clear_closed.call_deferred()

func _clear_closed() -> void:
	if not hub.dialogue.is_open: context=&""; context_room=&""; offered=&""

static func author_room(room: ExteriorRoom) -> void:
	var faction_id: String=SectRouteCatalog.faction(room.room_id)
	if faction_id.is_empty():
		for id: String in SectRouteCatalog.FACTIONS:
			if room.room_id!=SectRouteCatalog.ROAD_ROOMS[id]: continue
			var x: float=SectRouteCatalog.ROAD_X[id]
			room.interactions[&"sect_branch"]=Vector2(x,room.floor_y(x))
			room.anchors[&"sect"]=room.interactions[&"sect_branch"]
			room.interactions[&"sect_register"]=Vector2(x-180,room.floor_y(x-180))
			room._door(room.interactions[&"sect_branch"],"E · "+String(SectRouteCatalog.LABELS[id]))
			room._sign(room.interactions[&"sect_register"],"E · Sổ tiếp nhận môn phái",true)
		return
	if room.room_id==SectRouteCatalog.first(faction_id):
		room.interactions[&"sect_register"]=Vector2(room.width-300,room.floor_y(room.width-300))
		room._sign(room.interactions[&"sect_register"],"E · Trình ghi chép / quyền khách",true)
		for index: int in 2:
			var x: float=SectRouteCatalog.MARKERS[faction_id][index]
			var key: StringName=&"sect_marker_west" if index==0 else &"sect_marker_east"
			room.interactions[key]=Vector2(x,room.floor_y(x))
			room._lamp(room.interactions[key])
			room._sign(room.interactions[key],"E · Quan sát mốc "+("tây" if index==0 else "đông"),true)
	else:
		var x: float=room.width*.55
		room.interactions[&"sect_history"]=Vector2(x,room.floor_y(x))
		room._sign(room.interactions[&"sect_history"],"E · Đọc lời thề giữ đường",true)
		room._branch(3,.4,"Điểm nhìn sân trong")
