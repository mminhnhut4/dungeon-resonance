class_name TanDangJourney
extends Node
## One finite quest adapter. Life, karma, rewards and saves use existing owners.
const LEDGER: StringName = &"tan_ledger"
const LAMP: StringName = &"tan_lamp"
const REFUGE: StringName = &"tan_refuge"
const LEDGER_X: float = 870.0
const LAMP_X: float = 960.0
const REFUGE_X: float = 1320.0
var hub: ExteriorHub
var progress := TanDangProgress.new()
var context: StringName = &""
var context_room: StringName = &""
var offered: Dictionary = {}
var _notice_clock: float = 0.0
var _flame: Polygon2D
var _wreck: Line2D
var _decorated_room: WeakRef
var reporting: Dictionary={}

func initialize(owner: ExteriorHub) -> void:
	hub = owner
	progress.initialize(hub.profile,hub.npc_population.state)
	hub.dialogue.choice_selected.connect(_choice)
	hub.dialogue.closed.connect(_closed)
	hub.zone_changed.connect(_zone_changed)
	hub.profile.changed.connect(_refresh_art)
	(hub.gear.modal as InventoryScreen).journal.extension_rows_provider=relation_rows
	progress.life.activity_changed.connect(_relations_changed)
	_relations_changed("","")
	hub._station(LEDGER,Vector2(LEDGER_X,640),"SỔ TÀN ĐĂNG · NHIỆM VỤ / NHÂN QUẢ")
	hub._station(LAMP,Vector2(LAMP_X,640),"ĐÈN CỔNG · TÀN ĐĂNG")
	for id: StringName in [LEDGER,LAMP]:
		for child: Node in hub.stations[id].get_children():
			if child is Label:
				hub.stations[id].remove_child(child)
				child.queue_free()
	_marker(hub.yard,Vector2(LEDGER_X,640),"Sổ Tàn Đăng",false)
	var lamp: Node2D = _marker(hub.yard,Vector2(LAMP_X,640),"Đèn thiếu lõi",true)
	_flame = lamp.get_node("Flame") as Polygon2D
	_wreck = lamp.get_node("Wreck") as Line2D
	_refresh_art()
	_zone_changed(&"")

static func _marker(parent: Node2D, at: Vector2, label: String, lantern: bool) -> Node2D:
	var node := Node2D.new()
	node.name = "TanDangLantern" if lantern else "TanDangRecord"
	node.position = at
	# The P03 placard is added after resident actors. Keep its existing geometry
	# behind their hands/bodies instead of covering them at the same draw order.
	if parent is ExteriorRoom and (parent as ExteriorRoom).room_id == &"o01_p03" and not lantern:
		node.z_index = -1
	parent.add_child(node)
	var stand := Line2D.new()
	stand.points = PackedVector2Array([Vector2(-16,0),Vector2(-12,-45),Vector2(12,-45),Vector2(16,0)])
	stand.width = 5.0
	stand.default_color = Color("6c715e")
	node.add_child(stand)
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2(-22,-60),Vector2(22,-60),Vector2(22,-28),Vector2(-22,-28)])
	top.color = Color("aa956f")
	node.add_child(top)
	var paper := Line2D.new()
	paper.points = PackedVector2Array([Vector2(-13,-51),Vector2(13,-51),Vector2(-13,-42),Vector2(11,-42)])
	paper.width = 2.0
	paper.default_color = Color("e7dbac")
	node.add_child(paper)
	var caption := Label.new()
	caption.position = Vector2(-90,-92)
	caption.size.x = 180
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",12)
	caption.text = label
	# Nearby NPC names and the bottom E prompt already identify these stations.
	# Keep the marker itself; avoid stacking names over nearby residents.
	if parent is ExteriorRoom and (parent as ExteriorRoom).room_id != ExteriorRouteCatalog.HUB:
		caption.set_meta(&"debug_keep",true)
		# P03's nearest-station bottom prompt already identifies this placard.
		# Leave its physical marker and the nearby residents' captions intact.
		if (parent as ExteriorRoom).room_id == &"o01_p03" and label.begins_with("E ·"):
			caption.hide()
		node.add_child(caption)
	else:
		caption.free()
	if lantern:
		var flame := Polygon2D.new()
		flame.name = "Flame"
		flame.polygon = PackedVector2Array([Vector2(0,-55),Vector2(7,-40),Vector2(0,-34),Vector2(-7,-40)])
		node.add_child(flame)
		var wreck := Line2D.new()
		wreck.name = "Wreck"
		wreck.points = PackedVector2Array([Vector2(-27,-15),Vector2(24,-4),Vector2(10,-23),Vector2(31,-10)])
		wreck.width = 5.0
		wreck.default_color = Color("706c61")
		node.add_child(wreck)
	return node

func _refresh_art() -> void:
	if not is_instance_valid(_flame): return
	var lamp: String = progress.state()["lamp"]
	_flame.color = Color("ffc767") if lamp == "lit" else Color("766453")
	_flame.visible = lamp != "broken"
	_wreck.visible = lamp == "broken"

func _zone_changed(_id: StringName) -> void:
	_clear_reporting()
	if not hub.outside or not is_instance_valid(hub.exterior) or hub.exterior.room_id != &"o01_p03" or hub.exterior.route_id != ExteriorRouteCatalog.MAIN: return
	if _decorated_room != null and _decorated_room.get_ref() == hub.exterior: return
	_decorated_room = weakref(hub.exterior)
	var at := Vector2(REFUGE_X,hub.exterior.floor_y(REFUGE_X))
	hub.exterior.interactions[REFUGE] = at
	_marker(hub.exterior,at,"E · Ghi chép / lõi cổ phù",false)

func _room_id() -> StringName:
	return hub.exterior.room_id if hub.outside and is_instance_valid(hub.exterior) else ExteriorRouteCatalog.HUB

func _place() -> String:
	if context == LEDGER: return "ledger"
	if context == LAMP: return "lamp"
	if context == REFUGE or (String(context) in [TanDangProgress.LAM,TanDangProgress.DU] and _room_id() == &"o01_p03"): return "refuge"
	return String(context)

func handles(id: StringName) -> bool:
	return id in [LEDGER,LAMP,REFUGE] or String(id) in TanDangProgress.NPC_IDS

func interact(id: StringName) -> bool:
	if not handles(id) or not hub._can_travel() or id != hub.nearest_station() or not hub.player.motor.is_grounded(): return false
	if String(id) in TanDangProgress.NPC_IDS:
		if not progress.alive(String(id)): return false
		if progress.life.records[String(id)]["mode"] == "downed": return hub.npc_population.interact(String(id))
	context = id
	context_room = _room_id()
	_open()
	return true

func _offer(choices: Array[Dictionary], action: String, text: String, enabled: bool = true, confirmation: String = "") -> void:
	var id := StringName("td_"+action)
	var choice: Dictionary = {"id":id,"text":text,"enabled":enabled and progress.available()}
	if not confirmation.is_empty():
		choice["requires_confirmation"] = true
		choice["confirm_text"] = confirmation
	choices.append(choice)
	offered[id] = {"action":action,"enabled":choice["enabled"]}

func _speaker_lines() -> Array[String]:
	if not progress.available(): return ["Ghi chép chưa xác minh; chưa thể kết luận sống/chết. Hãy khôi phục hồ sơ trước khi tiếp tục."]
	var s: Dictionary = progress.state()
	if context == LEDGER:
		if not s["accepted"]: return ["Sổ việc còn để ngỏ: đèn cổng thiếu lõi. Hãy nhận việc, kiểm đèn rồi xem ghi chép ở trú ẩn."]
		if s["choice"] == "":
			if s["discoveries"].size() == 3: return ["Đã ghi đủ chuyện đèn, Lâm Tước và lõi cổ phù. Khép ghi chép trước khi quyết việc chiếc lõi."]
			return ["Đã nhận việc chiếc đèn. Cần ghi đủ chuyện đèn, Lâm Tước và lõi cổ phù ở trú ẩn."]
		if s["choice"] == "gate":
			var death: Dictionary = progress.life.records[TanDangProgress.DU]["death"]
			var event: String = ""
			if death.get("context","") == "core_withdrawal": event = "Dư Hành chết khi lõi được lấy đi."
			elif not progress.alive(TanDangProgress.DU): event = "Dư Hành đã chết trước lúc thu lõi."
			return ["Đã chọn giữ cổng và thu lõi. "+event]
		return ["Đã tiêu lõi cứu Dư Hành; đèn cổng hỏng. Người ấy còn sống." if progress.alive(TanDangProgress.DU) else "Đã tiêu lõi cứu Dư Hành; người ấy qua đời sau đó. Quyết định cũ vẫn được ghi."]
	if context == LAMP: return [{"weak":"Chỗ lắp lõi còn trống. Ánh đèn yếu trên lối vào.","lit":"Lõi đã lắp. Đèn cổng sáng lại; lối đi vẫn mở.","broken":"Đèn và đồ kê đã hỏng vì tàn khí. Lối vào vẫn thông."}[s["lamp"]]]
	if context == REFUGE:
		if s["choice"] == "gate":
			var next: String = "Việc chiếc đèn đã khép sổ. Ghi chép ở trú ẩn còn lưu quyết định."
			if s["core"] == "carried": next = "Mang lõi về lắp vào đèn cổng rồi báo phần của mình."
			elif not s["rewards"].has("q3"): next = "Lõi đã lắp ở căn cứ. Trở về ghi đủ phần báo cáo."
			return ["Đã chọn giữ cổng; lõi đã thu hồi.",next]
		if s["choice"] == "rescue":
			return ["Lõi đã tiêu để cứu Dư Hành; đèn cổng chịu thiệt hại.","Dư Hành còn sống. Lối đi vẫn thông." if progress.alive(TanDangProgress.DU) else "Dư Hành chết sau lần được cứu. Lõi không còn; quyết định trước vẫn được ghi."]
		return ["Ghi chép của Lâm Tước: lõi được mang tới cứu Dư Hành. Cũng lõi ấy vốn giữ đèn cổng.","Lõi còn bên Dư Hành. Thu lõi sẽ làm người ấy chết; dùng để cứu sẽ mất lõi. Không có đếm ngược." if progress.alive(TanDangProgress.DU) else "Dư Hành đã chết. Lõi vẫn còn; chỉ có thể thu về. Vật chứng còn đủ để khép việc."]
	if not progress.alive(String(context)): return ["Người này đã chết. Vật chứng và bàn sổ vẫn giữ đường tiến trình."]
	var id: String = String(context)
	var karma: Dictionary = progress.life.karma(id)
	var cause: Dictionary = progress.life.records[id]["causality"]
	if cause["peace_used"] and not cause["reconciled"]:
		return [_by_speaker(id,"Ngươi đã phá lời đình chiến. Ta không nhận lời ấy lần thứ hai.","Em đã tin lời dừng tay một lần. Anh lại làm em bị thương. Em không nhận lời lần nữa.","Ngươi lại gây thương tích sau đình chiến. Ta không nhận thêm một lời hứa như thế.")]
	if cause["reconciled"]:
		if id == TanDangProgress.DU:
			return ["Ta đã nhận lời dừng tay. Ơn cứu mạng và vết thương ngươi gây, ta nhớ cả hai." if karma.get("rescued",false) else "Ta đã nhận lời dừng tay. Vết thương ngươi gây vẫn là chuyện đã xảy ra."]
		return [_by_speaker(id,"Ta đã nhận lời đình chiến. Chuyện cũ còn trong sổ; lòng tin cần những việc về sau.","Em sẽ không trả đũa chuyện cũ. Nhưng em chưa thể coi mọi chuyện như trước.","")]
	if cause["harmed"] or karma.get("grievance","") == "attacked":
		if progress.can_reconcile(id):
			return [_by_speaker(id,"Ngươi đã trở lại nhận phần trách nhiệm. Ta có thể nghe một lời xin đình chiến.","Anh đã quay lại nhận phần mình. Nếu muốn dừng chuyện này, hãy nói cho rõ.","Ta đã qua lần dưỡng thương ấy. Nếu ngươi muốn đình chiến, hãy nhận lấy việc mình đã làm.")]
		if karma.get("spared",false):
			if id == TanDangProgress.DU and karma.get("rescued",false): return ["Ngươi từng dùng lõi cứu ta. Ta nhớ lần ngươi tha mạng, và cả vết thương ngươi gây."]
			return [_by_speaker(id,"Ngươi đã dừng tay. Ta ghi nhận việc ấy, không gạch đi vết thương.","Anh đã tha em. Nhưng dừng tay chưa khiến em hết sợ lần sau.","Ngươi đã để ta sống. Ta nhớ cả điều ấy, cả lần ngươi làm ta bị thương.")]
		if id == TanDangProgress.DU and karma.get("rescued",false): return ["Ngươi đã cứu mạng ta, cũng đã làm ta bị thương. Ta không quên chuyện nào."]
		return [_by_speaker(id,"Chuyện chiếc đèn vẫn phải làm. Còn vết thương ngươi gây, ta chưa bỏ qua.","Anh đã làm em bị thương. Em còn nhớ; đừng coi như chưa có chuyện gì.","Ta nhớ bàn tay đánh mình. Có việc thì nói, nhưng đừng xin ta coi như chưa xảy ra.")]
	var victim: String = _known_murder_victim(id)
	if id == TanDangProgress.MOC and s["choice"] == "rescue" and not progress.alive(TanDangProgress.DU) and _knows_victim(id,TanDangProgress.DU):
		return ["Ngươi đã cứu Dư Hành, rồi lại sát hại người ấy. Chuyện cứu người không xóa được chuyện về sau."]
	if not victim.is_empty(): return [("Em biết chuyện anh sát hại %s. Việc ngọn đèn cứ ghi cho đủ; còn lòng tin, đừng đòi lại bằng vài lời." if id == TanDangProgress.LAM else "Ta biết chuyện ngươi sát hại %s. Việc ngọn đèn cứ ghi cho đủ; còn lòng tin, đừng đòi lại bằng vài lời.") % NpcPilotCatalog.definition(victim).get("name",victim)]
	match String(context):
		TanDangProgress.MOC:
			if s["choice"] == "gate":
				if s["core"] == "carried": return ["Lõi đã mang về. Hãy lắp lại vào đèn cổng rồi báo phần của mình."]
				return ["Cổng còn sáng. Ta sẽ không gọi cái giá ấy là nhỏ.","Ngươi đã đem lõi về. Ta ghi nhận việc ấy, và cả cái giá của nó."]
			if s["choice"] == "rescue":
				var du: Dictionary = progress.life.records[TanDangProgress.DU]
				if progress.alive(TanDangProgress.DU) and du["room"] == String(ExteriorRouteCatalog.HUB) and du["mode"] not in ["downed","recovering"]: return ["Người được cứu đang ở đây. Phần thiệt hại cũng vậy.","Ta không phủ nhận một mạng người. Nhưng việc sửa lại chiếc đèn cũng cần người nhận lấy."]
				if progress.alive(TanDangProgress.DU): return ["Lần ấy ngươi đã chọn cứu người. Phần thiệt hại ở cổng vẫn còn."]
				return ["Lần ấy ngươi đã chọn cứu người. Ta chưa nhận được lời chứng mới về Dư Hành; phần thiệt hại ở cổng vẫn còn."]
			if progress.alive(TanDangProgress.LAM): return ["Đèn cổng đang yếu. Lâm Tước mang lõi đi rồi. Tìm nó trước. Nghe hết chuyện rồi hãy quyết.","Giữ cổng cũng là giữ chỗ trú cho người đi đường. Nhưng ta muốn ngươi xem phần việc ở trú ẩn trước khi quyết."]
			return ["Đèn cổng đang yếu. Lõi đã được mang tới trú ẩn. Hãy xem ghi chép ở đó, rồi mới quyết."]
		TanDangProgress.LAM:
			if s["choice"] == "gate": return ["Em sẽ sửa đèn. Chuyện còn lại, cho em chút thời gian.","Em hiểu vì sao anh đem lõi về. Hiểu được chưa có nghĩa là em đã nguôi."]
			if s["choice"] == "rescue": return ["Em sẽ ở lại sửa. Lần này em không bỏ đi.","Anh đã cùng em nhận lấy quyết định ấy. Em nhớ. Chiếc đèn hỏng, em cũng không quên."]
			return ["Em biết mình đã lấy thứ gì. Nhưng lúc tìm thấy người này, em không thể quay đi.","Lõi giữ được cổng, cũng đang giữ mạng anh ấy. Em chỉ xin anh nhìn người nằm cạnh nó." if progress.alive(TanDangProgress.DU) else "Em đã mang lõi tới cứu người. Chuyện lấy lõi, em không chối. Anh hãy kiểm vật chứng rồi quyết phần còn lại."]
		TanDangProgress.DU:
			if s["choice"] == "rescue": return ["Ta còn sống. Ta sẽ tự trả phần nợ của mình.","Ngươi đã để lõi cứu ta. Ta nhớ chuyện ấy và phần đèn cổng đã mất."]
			return ["Ta đã rời bên đó. Các người có quyền không tin. Đừng để cậu ấy gánh chuyện này một mình.","Lâm Tước mang lõi tới vì ta. Ngươi hãy nghe cả lời người giữ cổng; ta không có quyền xin ngươi bỏ qua họ."]
	return []

func _known_murder_victim(listener: String) -> String:
	for victim: String in TanDangProgress.NPC_IDS:
		if _knows_victim(listener,victim): return victim
	return ""

func _knows_victim(listener: String, victim: String) -> bool:
	if victim == listener or not progress.life.karma(victim).get("player_murdered",false): return false
	var seen: Array = progress.life.records[victim]["causality"]["witnesses"]["player_murder"]
	return listener in seen or TanDangCausality.knows(progress.life.records,victim,"player_murder",listener)

static func _by_speaker(id: String, moc: String, lam: String, du: String) -> String:
	if id == TanDangProgress.MOC: return moc
	if id == TanDangProgress.LAM: return lam
	return du

static func _aid_offer_line(id: String, s: Dictionary, karma: Dictionary, living: Dictionary = {}) -> String:
	if id == TanDangProgress.LAM and living.get("forage_help",false): return "Em nhớ anh đã chặn con quái trong chuyến tìm mảnh phù. Em có chút vải gửi anh mang đường."
	if id == TanDangProgress.MOC and s["choice"] == "gate" and karma.get("helped",false): return "Ta nhớ việc ngươi đem lõi về. Còn chút vải giúp người đi đường; cần thì nhận lấy."
	if id == TanDangProgress.LAM and s["choice"] == "rescue" and karma.get("helped",false): return "Anh đã cùng em chọn cứu người. Em có chút vải muốn gửi anh mang đường."
	if id == TanDangProgress.DU and s["choice"] == "rescue" and karma.get("rescued",false): return "Ta nhớ ngươi đã để lõi cứu ta. Chút vải này, nếu cần, ngươi cứ nhận."
	if karma.get("spared",false): return "Ta còn nhớ lần ngươi dừng tay. Nếu cần, ta có chút vải giúp ngươi đi đường."
	return "Ta có chút vải dành cho người đi đường. Cần thì nhận lấy."

func _living_lines(id: String, history: bool = false) -> Array[String]:
	var lines: Array[String] = []
	if not progress.available() or id not in TanDangProgress.NPC_IDS: return lines
	var view: Dictionary = progress.life.living_view(id)
	if view.is_empty(): return lines
	if progress.alive(id):
		var room_name: String = {"h00_traveler_hub":"sân căn cứ","o01_p01":"Đường Bộ P01","o01_p03":"trú ẩn P03"}.get(view.get("room",""),"đường đi")
		var activity: String = view.get("activity","Nghỉ")
		var mode: String = progress.life.records[id]["mode"]
		if mode == "walk": activity = "Đi tới chỗ "+activity.to_lower()
		if mode in ["downed","recovering"]: activity = "Dưỡng thương sau lần trọng thương"
		if view.get("convalescing",false): activity = "Dưỡng thương sau chuyến tìm vật liệu"
		if id == TanDangProgress.LAM:
			match view.get("event_phase","none"):
				"outbound": activity = "Đi ra cửa đường bộ"
				"collecting": activity = "Đi tới chỗ tìm mảnh phù" if mode == "walk" else "Tìm mảnh phù và đá kê đèn"
				"danger": activity = "Chống đỡ yêu thú trên đường"
				"returning": activity = "Trở về căn cứ" if mode == "walk" else activity
		lines.append("Đang làm: %s · %s." % [activity,room_name])
	var phase: String = view.get("event_phase","none")
	var outcome: String = view.get("outcome","none")
	if id == TanDangProgress.LAM:
		if phase == "outbound": lines.append("Chuyến tìm mảnh phù và đá kê đèn đã bắt đầu. Lâm Tước đang đi ra cửa đường bộ.")
		elif phase == "collecting": lines.append("Lâm Tước đang tìm mảnh phù và đá kê đèn trên Đường Bộ P01.")
		elif phase == "danger": lines.append("Lâm Tước đang gặp quái ở chỗ nhặt vật liệu P01, tự chống đỡ hoặc rút theo sức còn lại.")
		elif phase in ["returning","done"]:
			if outcome == "helped": lines.append("Bạn đã ra tay chặn con quái trong chuyến tìm vật liệu P01. Lâm Tước nhớ đúng lần giúp ấy.")
			elif outcome == "self": lines.append("Lâm Tước đã tự xử lý con quái trong chuyến tìm vật liệu P01.")
			elif outcome == "withdrew": lines.append("Chuyến tìm vật liệu P01 đã dừng; Lâm Tước chọn rút về giữ sức.")
			elif outcome == "interrupted": lines.append("Chuyến tìm vật liệu bị gián đoạn. Thương tích và ân oán vẫn theo ghi chép riêng.")
			if outcome == "withdrew" and view.get("forage_help",false): lines.append("Bạn đã ra tay lúc Lâm gặp nguy; Lâm vẫn phải rút về và nhớ đúng lần giúp ấy.")
			if phase == "returning" and progress.alive(id): lines.append("Đang trở về căn cứ sau chuyến tìm vật liệu.")
	if view.get("heard_materials",false): lines.append("Lâm Tước đã kể trực tiếp chuyện chuyến tìm vật liệu khi cùng ở căn cứ.")
	if not history and (progress.life.records[id]["causality"]["harmed"] or progress.life.karma(id).get("grievance","") != ""):
		# Injury speech remains first in intent; positive history belongs in M.
		while lines.size() > 1: lines.remove_at(lines.size()-1)
	return lines

func _living_memory_speech(id: String) -> Array[String]:
	var lines: Array[String] = []
	if not progress.available() or not progress.alive(id): return lines
	var view: Dictionary = progress.life.living_view(id)
	if view.is_empty() or progress.life.records[id]["causality"]["harmed"] or progress.life.karma(id).get("grievance","") != "": return lines
	if id == TanDangProgress.LAM and view.get("forage_help",false):
		lines.append("Em nhớ anh đã ra tay chặn con quái ở Đường Bộ.")
		if view.get("outcome","") == "withdrew":
			lines.append("Em đã rút về giữ sức. Em nhớ lần anh ra tay." if view.get("event_phase","") == "done" else "Em phải rút về giữ sức. Em nhớ lần anh ra tay.")
		else:
			lines.append("Em đã mang phần nhặt được về lo việc chiếc đèn." if view.get("event_phase","") == "done" else "Em sẽ mang phần nhặt được về lo việc chiếc đèn.")
	elif id != TanDangProgress.LAM and view.get("heard_materials",false): lines.append("Lâm Tước đã kể lại chuyến tìm vật liệu khi cùng ở căn cứ.")
	return lines

func _karma_lines(only_id: String = "") -> Array[String]:
	var lines: Array[String] = []
	if progress.life.read_only or progress.life.compound_locked:
		lines.append("Trạng thái NPC chưa xác minh; cần khôi phục trước khi kết luận đời sống hoặc nhân quả.")
		return lines
	for id: String in TanDangProgress.NPC_IDS:
		if not only_id.is_empty() and id != only_id: continue
		var k: Dictionary = progress.life.karma(id)
		var record: Dictionary = progress.life.records[id]
		var causal: Dictionary = record["causality"]
		var alive_now: bool = progress.alive(id)
		var facts: Array[String] = []
		facts.append_array(_living_lines(id,true))
		var next_step: String = ""
		if k.get("rescued",false): facts.append("Bạn đã tiêu lõi cứu Dư Hành.")
		elif k.get("helped",false): facts.append("Bạn đã đem lõi về giữ cổng; Mộc Yên ghi nhận việc ấy." if id == TanDangProgress.MOC else "Bạn đã cùng Lâm Tước chọn cứu Dư Hành.")
		if causal["harmed"]: facts.append("Bạn đã gây thương tích. Việc từng giúp không xóa chuyện này.")
		if k.get("spared",false): facts.append("Sau lần trọng thương, bạn đã tha người này.")
		if causal["reconciled"]: facts.append("Đã xác nhận đình chiến sau tha, dưỡng thương và nhận trách nhiệm. Hậu quả cũ còn được ghi; trợ giúp không mở lại.")
		elif causal["peace_used"]: facts.append("Đã gây hại sau đình chiến. Cơ hội hòa giải một lần đã hết.")
		if not alive_now:
			if record["death"].get("context","") == "core_withdrawal": facts.append("Dư Hành chết khi lõi được thu hồi.")
			elif k.get("player_murdered",false): facts.append("Bạn đã sát hại người này.")
			else: facts.append("Người này đã chết.")
		elif k.get("assistance_used",false): facts.append("Đã nhận 2 Sợi Vải Lanh vào kho; rút về túi nếu cần chế băng gạc.")
		elif int(k.get("gratitude",0)) > 0 and k.get("grievance","") == "" and not causal["harmed"] and record["mode"] not in ["downed","recovering"]: next_step = "Gặp người này để xin 2 Sợi Vải Lanh vào kho, một lần."
		if alive_now and k.get("grievance","") == "attacked" and k.get("spared",false) and not causal["peace_used"]:
			if record["mode"] in ["downed","recovering"]: next_step = "Để người này dưỡng thương qua một chuyến ngục được lưu rồi trở về."
			elif not progress.state()["rewards"].has("q3"): next_step = "Hoàn tất Nhận phần trách nhiệm."
			elif progress.knows_murder(id): next_step = "Vụ sát hại mà người này biết chặn hòa giải."
			elif progress.can_reconcile(id): next_step = "Gặp người này, E → Nhận lỗi; xác nhận để đình chiến."
		if facts.is_empty(): facts.append("Chưa ghi nhận ân oán với người này.")
		var witnesses: Array[String]=[]
		for witness: String in causal["witnesses"]["player_murder"]:witnesses.append(NpcPilotCatalog.definition(witness)["name"])
		if k.get("player_murdered",false): facts.append("Nhân chứng sát hại: "+(", ".join(witnesses) if not witnesses.is_empty() else "chưa có người được ghi nhận; người ở vùng khác không tự biết"))
		if causal["reports"].is_empty() and causal["harmed"]: facts.append("Chưa có báo tin công khai. Người đủ điều kiện cần bình tĩnh tại điểm báo đủ 3 giây; rời vùng hoặc bị đánh sẽ ngắt.")
		for report: Dictionary in causal["reports"]:
			facts.append("%s tại %s · %s báo tin. Chỉ công khai ở vùng này."%["CÁO THỊ SÁT HẠI" if report["reason"]=="player_murder" else "Bản ghi gây thương tích","sân căn cứ" if report["room"]==String(ExteriorRouteCatalog.HUB) else "trú ẩn P03",NpcPilotCatalog.definition(report["reporter"])["name"]])
		if not next_step.is_empty(): facts.append("Tiếp theo: "+next_step)
		lines.append(NpcPilotCatalog.definition(id).get("name",id)+" · "+("Còn sống" if alive_now else "Đã chết vĩnh viễn")+"\n"+"\n".join(facts))
	return lines

func relation_rows() -> Array[Dictionary]:
	if not progress.available():return []
	return [{"id":&"tan_dang_relations","title":"Nhật ký quan hệ · Tàn Đăng","body":"GHI CHÉP CỦA BẠN · Người ở vùng khác không tự biết chuyện đã xảy ra. Phản kích tối đa 20 giây; oán hận dài hạn và tin công khai là các việc riêng.\n\n"+"\n\n".join(_karma_lines()),"target":ExteriorRouteCatalog.HUB,"done":false,"next":false}]

func _relations_changed(_id: String,_mode: String) -> void:
	var journal: QuestJournal=(hub.gear.modal as InventoryScreen).journal
	journal._request_refresh()

func _quest_choices(choices: Array[Dictionary], s: Dictionary, place: String) -> void:
	if not s["accepted"]:
		if place in ["ledger",TanDangProgress.MOC,TanDangProgress.LAM,"refuge"]: _offer(choices,"accept","Nhận việc · Ngọn đèn thiếu lõi")
		return
	if place == "lamp" and "lamp" not in s["discoveries"]: _offer(choices,"observe_lamp","Kiểm đèn · Ghi chỗ thiếu lõi")
	if place == "refuge":
		if "lam" not in s["discoveries"]: _offer(choices,"find_lam","Nghe lời / đọc ghi chép của Lâm Tước")
		if "core" not in s["discoveries"]: _offer(choices,"inspect_core","Kiểm lõi cổ phù bên Dư Hành")
	if s["discoveries"].size() == 3 and not s["rewards"].has("q1"): _offer(choices,"q1_reward","Khép ghi chép · Nhận 2 cống hiến")
	if s["rewards"].has("q1") and s["choice"] == "" and place == "refuge":
		var warning: String = "Thu hồi lõi làm Dư Hành chết vĩnh viễn, rồi mang về lắp đèn. Mộc Yên tin hơn, Lâm Tước xa cách. Quyết định không đảo ngược; thưởng tiến trình bằng nhánh cứu." if progress.alive(TanDangProgress.DU) else "Dư Hành đã chết. Thu lại lõi còn bên người này để đem về; không hồi sinh hoặc gây thêm một cái chết."
		_offer(choices,"choice_gate","Giữ cổng · Thu hồi lõi",true,warning)
		_offer(choices,"choice_rescue","Cứu Dư Hành · Tiêu lõi",progress.alive(TanDangProgress.DU),"Tiêu lõi để cứu Dư Hành tại thời điểm quyết định. Tàn khí sẽ làm đèn/đồ gần cổng hỏng nhưng không chặn lối. Mộc Yên dè chừng, Lâm Tước và Dư Hành quý hơn. Không đảo ngược, không đếm ngược.")
	if s["core"] == "carried" and place == "lamp": _offer(choices,"install_core","Lắp lại lõi · Giữ lối đi thông")
	if s["choice"] != "" and s["core"] != "carried":
		if "moc" not in s["reports"] and (place == TanDangProgress.MOC or (place == "ledger" and not progress.alive(TanDangProgress.MOC))): _offer(choices,"report_moc","Báo phần của Mộc Yên" if progress.alive(TanDangProgress.MOC) else "Sổ · Ghi phần báo cáo Mộc Yên")
		if "moc" in s["reports"] and "lam" not in s["reports"] and (place == TanDangProgress.LAM or (place == "ledger" and not progress.alive(TanDangProgress.LAM))): _offer(choices,"report_lam","Báo phần của Lâm Tước" if progress.alive(TanDangProgress.LAM) else "Sổ · Ghi phần báo cáo Lâm Tước")
	if s["reports"].size() == 2 and not s["rewards"].has("q3"): _offer(choices,"q3_reward","Nhận phần trách nhiệm · 2 cống hiến")

func _reward_choices(choices: Array[Dictionary], s: Dictionary, place: String) -> void:
	if not s["rewards"].has("q3") or place not in ["ledger",TanDangProgress.MOC,TanDangProgress.LAM]: return
	if not s["recipe_claimed"]:
		var known: bool = progress.known_recipe()
		_offer(choices,"recipe","Ghi nhận Hồi Đăng · Đã biết, không trừ cống hiến" if known else "Đổi sách Hồi Đăng · 6 cống hiến",known or int(s["contribution"]) >= TanDangProgress.RECIPE_COST,"Ghi tri thức Bão Lửa (Hỏa + Phong) hiện có. %s Không trừ Tàn Hồn, không khóa cách ghép hoặc đổi damage/cooldown." % ("Đã biết nên không trừ cống hiến." if known else "Trừ 6 cống hiến một lần."))
	if not s["support_claimed"]: _offer(choices,"support","Nhận chỉ dẫn Trúc Cơ · Theo đúng bước thiếu")
	if s["membership"] == "guest" and place in [TanDangProgress.MOC,TanDangProgress.LAM]:
		_offer(choices,"join","Tự nguyện nhập môn",progress.can_join(place),"Gia nhập Tàn Đăng Môn? Class vẫn theo trang bị, bùa/công thức giữ nguyên. Khách và tán tu vẫn có đủ đường tiến trình.")
		if not s["declined"]: _offer(choices,"decline","Giữ thân phận tán tu · Vẫn nhận đủ thưởng")
	elif s["membership"] == "member": _offer(choices,"leave","Rời môn · Giữ công thức và cống hiến",true,"Rời môn tự nguyện không phải phản bội. Giữ gear/class, công thức, cống hiến và mọi hậu quả đã ghi.")

func _open(message: String = "") -> void:
	offered.clear()
	var s: Dictionary = progress.state()
	var place: String = _place()
	var lines: Array[String] = _speaker_lines()
	if String(context) in TanDangProgress.NPC_IDS and progress.alive(String(context)):
		var work: Array[String] = _living_lines(String(context))
		if not work.is_empty(): lines.insert(0,work[0])
		lines.append_array(_living_memory_speech(String(context)))
	var choices: Array[Dictionary] = []
	var who: String = "Sổ Tàn Đăng Môn" if context == LEDGER else "Đèn cổng Tàn Đăng" if context == LAMP else "Trú ẩn · Cổ phù" if context == REFUGE else NpcPilotCatalog.definition(String(context)).get("name","Tàn Đăng Môn")
	if not message.is_empty(): lines.insert(0,message)
	lines.append("Cống hiến %d · %s. M → Quan hệ để xem điều đã xảy ra." % [s["contribution"],{"guest":"Khách / tán tu","member":"Thành viên","left":"Đã rời môn"}[s["membership"]]])
	_quest_choices(choices,s,place)
	_reward_choices(choices,s,place)
	if String(context) in TanDangProgress.NPC_IDS and progress.alive(String(context)):
		var karma: Dictionary = progress.life.karma(String(context))
		var causal: Dictionary = progress.life.records[String(context)]["causality"]
		var can_ask_aid: bool = place == String(context) and int(karma.get("gratitude",0)) > 0 and karma.get("grievance","") == "" and not karma.get("player_murdered",false) and not causal["harmed"]
		if can_ask_aid and not karma.get("assistance_used",false):
			lines.append(_aid_offer_line(String(context),s,karma,progress.life.living_view(String(context))))
			_offer(choices,"assist","Nhờ vật tư · 2 Sợi Vải Lanh vào kho",true,"Nhận một lần trợ giúp của người này: 2 Sợi Vải Lanh vào kho căn cứ? Cần rút về túi trước khi chế băng gạc.")
		elif karma.get("assistance_used",false) and not causal["harmed"]: lines.append("Phần vải ta giúp đã vào kho. Nhớ lấy ra trước chuyến đi.")
		if place == String(context) and karma.get("spared",false) and karma.get("grievance","")=="attacked" and not causal["peace_used"]: _offer(choices,"reconcile","Nhận lỗi · Xin đình chiến một lần",progress.can_reconcile(String(context)),"Đình chiến sau lần tha mạng, dưỡng thương và nhận phần trách nhiệm? Tin cậy, lịch sử và bản tin không bị xóa. Không mở lại trợ giúp; gây hại nữa hết cơ hội.")
	if s["support_claimed"] and context == LEDGER: lines.append("TRÚC CƠ · "+OpeningProgressionGuide.cultivation_next_step(hub.profile,hub.gear.inventory))
	if not progress.available(): lines.append("Hồ sơ chưa sẵn sàng ghi hoặc cần khôi phục. Không thay quyết định/tài nguyên. Hãy dùng thông báo khôi phục hiện có.")
	choices.append({"id":&"td_later","text":"Để sau · Tiếp tục đi đường"})
	hub._dialogue_previous_controls = hub.player.controls_enabled
	hub.player.suspend_controls(true)
	(hub.gear.modal as InventoryScreen).open_button.hide()
	TimeScaleClaims.acquire(hub.dialogue,0.1)
	hub.dialogue.open(who,lines,choices)

func _choice(id: StringName) -> void:
	if context == &"" or not offered.has(id) or not offered[id]["enabled"]: return
	if _room_id() != context_room or hub.nearest_station() != context or not hub.player.motor.is_grounded() or not hub._can_travel(): return
	var action: String = offered[id]["action"]
	var result: Dictionary = progress.apply(action,String(context),_place())
	if result.get("ok",false):
		hub.npc_population.refresh_actors()
		_refresh_art()
		if String(context) in TanDangProgress.NPC_IDS and (not progress.alive(String(context)) or progress.life.records[String(context)]["room"] != String(_room_id())): context = REFUGE if _room_id() == &"o01_p03" else LEDGER
		var message: String = "Đã lưu. Mở M để xem bước tiếp theo."
		if action == "report_moc": message = "Đã ghi phần báo cáo Mộc Yên vào sổ. Mở M để xem bước tiếp theo."
		if action == "report_lam": message = "Đã ghi phần báo cáo Lâm Tước vào sổ. Mở M để xem bước tiếp theo."
		if action == "support" and context != LEDGER: message = "TRÚC CƠ · "+OpeningProgressionGuide.cultivation_next_step(hub.profile,hub.gear.inventory)
		if action=="reconcile":message="Đã lưu đình chiến. Lịch sử, tin cậy và bản tin vẫn giữ; trợ giúp không mở lại. Gây hại lần nữa không được hòa giải lần hai."
		if action == "assist": message = "Đã ghi một lần trợ giúp: 2 Sợi Vải Lanh vào KHO CĂN CỨ. Rút ra túi rồi chế băng gạc qua dịch vụ thuốc hiện có."
		_open(message)
	else:
		var failure: String = str(result.get("error",result.get("status","write_failed")))
		if result.get("recovery_required",false) or result.get("status","") == "quarantined":
			_open("Cần khôi phục giao dịch (%s). Quyết định hoặc phần thưởng có thể đã được ghi. Thao tác đã khóa; tải lại để hoàn tất khôi phục, không nhận lại hoặc quyết lần nữa." % failure)
		else:
			_open("Chưa lưu được giao dịch (%s). Trạng thái trước lựa chọn được giữ; chưa nhận thêm thưởng. Bạn có thể thử lại khi hồ sơ cho phép." % failure)

func _closed() -> void:
	_clear_closed.call_deferred()

func _clear_closed() -> void:
	if not hub.dialogue.is_open:
		context = &""
		context_room = &""
		offered.clear()

func navigation_target(id: StringName) -> Dictionary:
	var s: Dictionary = progress.state()
	var room: StringName = ExteriorRouteCatalog.HUB
	var x: float = LEDGER_X
	var hint: String = "Sổ Tàn Đăng tại căn cứ"
	if id == &"tan_dang_q1" and s["accepted"]:
		if "lamp" not in s["discoveries"]: x = LAMP_X; hint = "E · Kiểm đèn thiếu lõi"
		else: room = &"o01_p03"; x = REFUGE_X; hint = "E · Lời kể / ghi chép và lõi tại trú ẩn P03"
	elif id == &"tan_dang_q2": room = &"o01_p03"; x = REFUGE_X; hint = "Trú ẩn P03 · Nghe đủ rồi xác nhận một lựa chọn"
	elif id == &"tan_dang_q3":
		if s["core"] == "carried": x = LAMP_X; hint = "E · Lắp lõi vào đèn cổng"
		elif "moc" not in s["reports"]:
			if progress.alive(TanDangProgress.MOC): x = float(progress.life.records[TanDangProgress.MOC]["x"]); hint = "E · Báo Mộc Yên"
			else: hint = "E · Bàn sổ ghi phần báo cáo của Mộc Yên trước"
		elif "lam" not in s["reports"]:
			if progress.alive(TanDangProgress.LAM): x = float(progress.life.records[TanDangProgress.LAM]["x"]); hint = "E · Báo Lâm Tước"
			else: hint = "E · Bàn sổ ghi phần báo cáo của Lâm Tước"
	var y: float = 640.0 if room == ExteriorRouteCatalog.HUB else hub.exterior.floor_y(x) if hub.outside and is_instance_valid(hub.exterior) and hub.exterior.room_id == room else 0.0
	return {"room":room,"point":Vector2(x,y),"hint":hint}

func _process(delta: float) -> void:
	if not is_instance_valid(hub) or not is_instance_valid(hub.player):return
	if not hub._can_travel() or hub.inside_house or not progress.available():_clear_reporting();return
	var near: StringName = hub.nearest_station()
	if near in [LEDGER,LAMP,REFUGE]: hub.prompt.text = {LEDGER:"E · Sổ Tàn Đăng · Nhiệm vụ / nhân quả",LAMP:"E · Đèn cổng Tàn Đăng",REFUGE:"E · Trú ẩn · Lời kể / ghi chép / lõi cổ phù"}[near]
	_tick_reporting(delta)
	_notice_clock += delta
	if _notice_clock < 0.5: return
	_notice_clock = 0.0
	if not progress.available(): return
	var s: Dictionary = progress.state()
	for id: String in TanDangProgress.NPC_IDS:
		var reason: String = progress.life.karma(id).get("grievance","")
		if reason == "" or id+":"+reason in s["response_notices"]: continue
		for responder: String in [id,TanDangProgress.MOC,TanDangProgress.LAM,TanDangProgress.DU]:
			var actor: CultivatorActor=hub.npc_population.actors.get(responder) as CultivatorActor
			if not is_instance_valid(actor) or actor.global_position.distance_to(hub.player.global_position)>145.0:continue
			var already_reacting: bool=actor.is_responding_to(id)
			if not already_reacting and not actor.can_request_retaliation(reason,id):continue
			var committed: Dictionary=progress.apply("notice",id,responder)
			if committed.get("ok",false):
				var responded: bool=already_reacting or actor.request_retaliation(reason,id)
				hub.prompt.text=("Phản ứng cục bộ · " if responded else "Chưa thể phản ứng · ")+("Tin sát hại đã được báo ở đây" if reason=="player_murder" else "Ghi việc gây thương tích")+". Tối đa 20 giây; M → Nhật ký quan hệ."
			return

func _clear_reporting() -> void:
	reporting.clear()
	if not is_instance_valid(hub) or hub.npc_population==null:return
	for actor: NpcPilotActor in hub.npc_population.actors.values():
		if is_instance_valid(actor) and actor is CultivatorActor:(actor as CultivatorActor).report_hint=""

func _report_candidate() -> Dictionary:
	var room: String=String(_room_id())
	if room not in TanDangCausality.ROOMS:return {}
	for reason: String in ["player_murder","attacked"]:
		for victim: String in TanDangProgress.NPC_IDS:
			var reporters: Array[String]=[victim]
			for other: String in TanDangProgress.NPC_IDS:
				if other!=victim:reporters.append(other)
			for id: String in reporters:
				if not TanDangCausality.can_report(progress.life.records,victim,reason,id,room):continue
				var actor: CultivatorActor=hub.npc_population.actors.get(id) as CultivatorActor
				# Returned residents can speak from their existing courtyard rest
				# anchors. No new station, actor, travel or remote delivery is created.
				var point: Vector2=hub.stations[LEDGER].global_position if room==String(ExteriorRouteCatalog.HUB) else hub.exterior.to_global(Vector2(REFUGE_X,hub.exterior.floor_y(REFUGE_X)))
				if room==String(ExteriorRouteCatalog.HUB) and id!=TanDangProgress.MOC:point=hub.yard.to_global(Vector2(float(NpcPilotCatalog.STARTS[id]["x"]),640))
				if not is_instance_valid(actor) or actor.combat_phase!="idle" or actor.global_position.distance_to(point)>160.0 or not actor._clear_line(actor.global_position+Vector2(0,-26),point+Vector2(0,-26)):continue
				return {"victim":victim,"reason":reason,"reporter":id,"room":room,"hp":progress.life.records[id]["hp"],"episode":progress.life.records[id]["episode"]}
	return {}

func _tick_reporting(delta: float) -> void:
	var candidate: Dictionary=_report_candidate()
	if candidate.is_empty():_clear_reporting();return
	var same: bool=not reporting.is_empty()
	for key: String in candidate:
		if reporting.get(key)!=candidate[key]:same=false;break
	if not same:
		_clear_reporting();reporting=candidate;reporting["elapsed"]=0.0
	reporting["elapsed"]=float(reporting["elapsed"])+minf(delta,0.1)
	var actor: CultivatorActor=hub.npc_population.actors[reporting["reporter"]] as CultivatorActor
	actor.report_hint=("Báo tin trong sân · " if reporting["room"]==String(ExteriorRouteCatalog.HUB) else "Ghi lời chứng tại sổ · ")+"%.1f / 3 giây"%float(reporting["elapsed"])
	if float(reporting["elapsed"])<TanDangCausality.REPORT_SECONDS:return
	var saved: bool=progress.life.report_cause(reporting["victim"],reporting["reason"],reporting["reporter"],reporting["room"])
	_clear_reporting()
	if saved:hub.prompt.text="Đã báo tin tại nơi này · Chỉ Tàn Đăng ở cùng vùng biết. M → Nhật ký quan hệ."
