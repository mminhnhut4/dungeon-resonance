class_name NpcPilotCatalog
extends RefCounted
## Stable authored roles, placement and realm IDs; NpcWorldState owns life.
const LEGACY_IDS: Array[String] = ["pilot_traveler", "pilot_pilgrim", "pilot_gatherer", "pilot_courier", "pilot_apprentice"]
const SCHEMA_TWO_IDS: Array[String] = ["pilot_traveler", "pilot_pilgrim", "pilot_gatherer", "pilot_courier", "pilot_apprentice", "pilot_bridge_keeper"]
const ORIGINAL_CULTIVATOR_IDS: Array[String] = ["thanh_van_disciple_01", "xich_lo_guard_01"]
const SECT_STEWARD_IDS: Array[String] = ["thanh_van_steward_01", "xich_lo_steward_01"]
const TAN_DANG_IDS: Array[String] = ["tan_dang_moc_yen", "tan_dang_lam_tuoc", "tan_dang_du_hanh"]
const HOME_OFFICER_IDS: Array[String] = ["tan_dang_leader", "tan_dang_deputy"]
const CULTIVATOR_IDS: Array[String] = ["thanh_van_disciple_01", "xich_lo_guard_01", "thanh_van_steward_01", "xich_lo_steward_01", "tan_dang_moc_yen", "tan_dang_lam_tuoc", "tan_dang_du_hanh", "tan_dang_leader", "tan_dang_deputy"]
const SCHEMA_THREE_IDS: Array[String] = ["pilot_traveler", "pilot_pilgrim", "pilot_gatherer", "pilot_courier", "pilot_apprentice", "pilot_bridge_keeper", "thanh_van_disciple_01", "xich_lo_guard_01"]
const SCHEMA_FOUR_IDS: Array[String] = ["pilot_traveler", "pilot_pilgrim", "pilot_gatherer", "pilot_courier", "pilot_apprentice", "pilot_bridge_keeper", "thanh_van_disciple_01", "xich_lo_guard_01", "thanh_van_steward_01", "xich_lo_steward_01"]
## Frozen schema5..8 roster; old saves and compound participants retain thirteen lives.
const SCHEMA_EIGHT_IDS: Array[String] = ["pilot_traveler", "pilot_pilgrim", "pilot_gatherer", "pilot_courier", "pilot_apprentice", "pilot_bridge_keeper", "thanh_van_disciple_01", "xich_lo_guard_01", "thanh_van_steward_01", "xich_lo_steward_01", "tan_dang_moc_yen", "tan_dang_lam_tuoc", "tan_dang_du_hanh"]
const IDS: Array[String] = ["pilot_traveler", "pilot_pilgrim", "pilot_gatherer", "pilot_courier", "pilot_apprentice", "pilot_bridge_keeper", "thanh_van_disciple_01", "xich_lo_guard_01", "thanh_van_steward_01", "xich_lo_steward_01", "tan_dang_moc_yen", "tan_dang_lam_tuoc", "tan_dang_du_hanh", "tan_dang_leader", "tan_dang_deputy"]
const MAX_HEALTH: float = 40.0
const DEFINITIONS: Dictionary = {
	"tan_dang_leader": {"name":"Đỗ Thanh Đăng", "role":"Tông chủ · Tàn Đăng Môn", "goal":"Giữ lời đã nhận với người còn sống và việc đã ghi trong sổ.", "room":"td01_lantern_court", "left":1480.0,"right":1620.0,"speed":30.0,"activity":"Trông đèn chính điện","tint":"d3b376"},
	"tan_dang_deputy": {"name":"Hà Nghi", "role":"Phó tông chủ · Tàn Đăng Môn", "goal":"Việc nhận và phần thưởng đều có trong sổ; hãy hỏi rõ trước khi lên đường.", "room":"td01_lantern_court", "left":630.0,"right":770.0,"speed":34.0,"activity":"Đối chiếu sổ công việc","tint":"9ebbb6"},
	"tan_dang_moc_yen": {"name":"Mộc Yên", "role":"Chấp sự · Tàn Đăng Môn", "goal":"Đèn cổng đang yếu. Lâm Tước mang lõi đi rồi.", "room":"h00_traveler_hub", "left":860.0,"right":1030.0,"speed":32.0,"activity":"Giữ sổ Tàn Đăng","tint":"bdb090"},
	"tan_dang_lam_tuoc": {"name":"Lâm Tước", "role":"Đệ tử · Tàn Đăng Môn", "goal":"Em biết mình đã lấy thứ gì.", "room":"o01_p03", "left":120.0,"right":1500.0,"speed":42.0,"activity":"Giữ lõi cứu người","tint":"c3ba8b"},
	"tan_dang_du_hanh": {"name":"Dư Hành", "role":"Kẻ đào ngũ bị thương", "goal":"Ta đã rời bên đó. Các người có quyền không tin.", "room":"o01_p03", "left":1040.0,"right":1410.0,"speed":30.0,"activity":"Nghỉ bên lõi cổ phù","tint":"af9dc6"},
	"thanh_van_steward_01": {"name":"Phùng Yên Trúc", "role":"Chấp sự · Thanh Vân", "goal":"Ta ghi điều người đi đường thực sự nhìn thấy. Sổ tiếp nhận bên phải luôn ở đó, kể cả khi ta phải dưỡng thương.", "room":"tv01_cloud_gate", "left":1990.0,"right":2150.0,"speed":32.0,"activity":"Kiểm sổ đường núi","tint":"8eccc9"},
	"xich_lo_steward_01": {"name":"Tống Hồng Diệp", "role":"Chấp sự · Xích Lô", "goal":"Nước thông thì lò mới yên. Đọc hai mốc trên đê rồi trình bản ghi vào sổ phía đông; đừng buộc tội từ một dấu cặn.", "room":"xl01_red_causeway", "left":2290.0,"right":2390.0,"speed":30.0,"activity":"Kiểm tuyến dẫn thủy","tint":"cba178"},
	"pilot_traveler": {"name":"Khách đường xa", "role":"Lữ hành", "goal":"Xem đèn bên mái miếu, lên ghế nghỉ rồi quay lại đường núi.", "room":"o01_p01", "left":360.0, "right":1420.0, "speed":48.0, "activity":"Quan sát đường", "tint":"95b7b5"},
	"pilot_pilgrim": {"name":"Người hành hương", "role":"Hành hương", "goal":"Chăm đèn ở miếu rồi trở về đường khô.", "room":"o01_p03", "left":1560.0, "right":1820.0, "speed":30.0, "activity":"Chăm đèn", "tint":"c3ba8b"},
	"pilot_gatherer": {"name":"Người hái thuốc", "role":"Hái thuốc", "goal":"Tìm cây thuốc ven đường và giữ sức để về bến.", "room":"o01_p04", "left":580.0, "right":900.0, "speed":36.0, "activity":"Tìm cây thuốc", "tint":"9cba86"},
	"pilot_courier": {"name":"Người đưa tin", "role":"Đưa tin", "goal":"Đối chiếu đường thư ở bưu trạm cũ.", "room":"o02_b03", "left":1320.0, "right":1660.0, "speed":56.0, "activity":"Đọc bảng thư", "tint":"af9dc6"},
	"pilot_apprentice": {"name":"Học việc ở bến", "role":"Học việc đóng thuyền", "goal":"Kiểm dây buộc ở xưởng rồi nghỉ trước ca tiếp.", "room":"o02_b04", "left":1120.0, "right":1450.0, "speed":40.0, "activity":"Kiểm dây buộc", "tint":"c3977f"},
	"pilot_bridge_keeper": {"name":"Người chăm cầu", "role":"Chăm cầu", "goal":"Xem dây buộc hai đầu cầu rồi nghỉ cạnh đường khô.", "room":"o01_p02", "left":2450.0, "right":2790.0, "speed":42.0, "activity":"Xem dây cầu", "tint":"a4b7a0"},
	"thanh_van_disciple_01": {"name":"Đệ tử Thanh Vân", "role":"Tu sĩ tuần tra · Thanh Vân", "goal":"Ta tuần tra đoạn đường núi này. Có chuyện thì dừng kiếm mà nói; kẻ cố tình gây thương tích sẽ gặp sự chống trả.", "room":"o01_p01", "left":1500.0, "right":1760.0, "speed":42.0, "activity":"Tuần tra đường núi", "tint":"8eccc9"},
	"xich_lo_guard_01": {"name":"Hộ vệ Xích Lô", "role":"Tu sĩ tuần tra · Xích Lô", "goal":"Ta giữ đường qua cầu. Ta không truy đuổi người đã rút khỏi khu vực, nhưng vẫn nhớ kẻ gây thương tích.", "room":"o01_p02", "left":1550.0, "right":1820.0, "speed":34.0, "activity":"Tuần tra đường cầu", "tint":"cba178"}
}
## Stop durations use gameplay ticks (4 Hz). These are existing room landmarks.
const SCHEDULES: Dictionary = {
	"tan_dang_leader":[{"x":1550.0,"mode":"work","ticks":80,"label":"Trông đèn chính điện"}],
	"tan_dang_deputy":[{"x":700.0,"mode":"work","ticks":80,"label":"Đối chiếu sổ công việc"}],
	"tan_dang_moc_yen":[{"x":900.0,"mode":"work","ticks":80,"label":"Giữ sổ Tàn Đăng"}],
	"tan_dang_lam_tuoc":[{"x":1345.0,"mode":"rest","ticks":80,"label":"Giữ lõi cứu người"}],
	"tan_dang_du_hanh":[{"x":1385.0,"mode":"rest","ticks":80,"label":"Dưỡng thương"}],
	"thanh_van_steward_01":[{"x":2000.0,"mode":"work","ticks":10,"label":"Đối chiếu ghi chép"},{"x":2140.0,"mode":"rest","ticks":10,"label":"Quan sát lối vào"}],
	"xich_lo_steward_01":[{"x":2300.0,"mode":"work","ticks":10,"label":"Ghi mực nước"},{"x":2380.0,"mode":"rest","ticks":10,"label":"Kiểm đường hàng"}],
	"pilot_traveler": [{"x":380.0,"mode":"work","ticks":6,"label":"Xem đèn bên mái miếu"},{"x":980.0,"mode":"work","ticks":8,"label":"Xem đèn nghiêng"},{"x":1380.0,"mode":"rest","ticks":12,"label":"Nghỉ cạnh ghế"},{"x":900.0,"mode":"rest","ticks":4,"label":"Nhìn lại đường núi"}],
	"pilot_pilgrim": [{"x":1570.0,"mode":"work","ticks":9,"label":"Chăm đèn"},{"x":1705.0,"mode":"work","ticks":7,"label":"Xem mái miếu"},{"x":1800.0,"mode":"rest","ticks":11,"label":"Nghỉ bên miếu"}],
	"pilot_gatherer": [{"x":610.0,"mode":"work","ticks":7,"label":"Xem cây ven đường"},{"x":880.0,"mode":"work","ticks":10,"label":"Tìm cây thuốc"},{"x":740.0,"mode":"rest","ticks":8,"label":"Nghỉ trên đường khô"}],
	"pilot_courier": [{"x":1340.0,"mode":"rest","ticks":6,"label":"Sắp lại thư"},{"x":1570.0,"mode":"work","ticks":9,"label":"Đọc bảng thư"},{"x":1640.0,"mode":"work","ticks":5,"label":"Đối chiếu đường thư"}],
	"pilot_apprentice": [{"x":1140.0,"mode":"work","ticks":8,"label":"Kiểm dây buộc"},{"x":1430.0,"mode":"work","ticks":6,"label":"Xem mép cầu tàu"},{"x":1280.0,"mode":"rest","ticks":10,"label":"Nghỉ trước ca tiếp"}],
	"pilot_bridge_keeper": [{"x":2470.0,"mode":"work","ticks":5,"label":"Xem dây đầu cầu"},{"x":2720.0,"mode":"work","ticks":9,"label":"Xem dây cuối cầu"},{"x":2780.0,"mode":"rest","ticks":10,"label":"Nghỉ cạnh cầu"}],
	"thanh_van_disciple_01": [{"x":1520.0,"mode":"work","ticks":8,"label":"Quan sát đường núi"},{"x":1740.0,"mode":"work","ticks":6,"label":"Tuần tra Thanh Vân"},{"x":1640.0,"mode":"rest","ticks":10,"label":"Điều tức bên đường"}],
	"xich_lo_guard_01": [{"x":1570.0,"mode":"work","ticks":7,"label":"Canh lối qua cầu"},{"x":1800.0,"mode":"work","ticks":8,"label":"Tuần tra Xích Lô"},{"x":1680.0,"mode":"rest","ticks":12,"label":"Nghỉ bên đường cầu"}]
}
const STARTS: Dictionary = {
	"tan_dang_leader":{"x":1550.0,"index":0,"mode":"work","remaining":80},
	"tan_dang_deputy":{"x":700.0,"index":0,"mode":"work","remaining":80},
	"tan_dang_moc_yen":{"x":900.0,"index":0,"mode":"work","remaining":80},
	"tan_dang_lam_tuoc":{"x":1345.0,"index":0,"mode":"rest","remaining":80},
	"tan_dang_du_hanh":{"x":1385.0,"index":0,"mode":"rest","remaining":80},
	"thanh_van_steward_01":{"x":2000.0,"index":0,"mode":"work","remaining":5},
	"xich_lo_steward_01":{"x":2300.0,"index":0,"mode":"work","remaining":5},
	"pilot_traveler":{"x":520.0,"index":1,"mode":"walk"},
	"pilot_pilgrim":{"x":1705.0,"index":1,"mode":"work","remaining":5},
	"pilot_gatherer":{"x":660.0,"index":1,"mode":"walk"},
	"pilot_courier":{"x":1340.0,"index":0,"mode":"rest","remaining":4},
	"pilot_apprentice":{"x":1370.0,"index":0,"mode":"walk"},
	"pilot_bridge_keeper":{"x":2530.0,"index":1,"mode":"walk"},
	"thanh_van_disciple_01":{"x":1590.0,"index":1,"mode":"walk"},
	"xich_lo_guard_01":{"x":1680.0,"index":0,"mode":"walk"}
}
const MODE_LABELS: Dictionary = {"walk":"Đi đường", "rest":"Nghỉ", "work":"Làm việc", "talk":"Trò chuyện", "flee":"Rút lui", "downed":"Trọng thương · Chờ rút lui", "recovering":"Đã rút về dưỡng thương"}

static func cultivation_stage(id: String) -> String:
	return {"tan_dang_moc_yen":"truc_co_so_ky", "tan_dang_lam_tuoc":"luyen_khi_ii", "tan_dang_du_hanh":"luyen_khi_iii", "tan_dang_leader":"truc_co_so_ky", "tan_dang_deputy":"luyen_khi_iii"}.get(id,"luyen_khi_i")

static func maximum_health(id: String) -> float:
	return MAX_HEALTH * CultivatorCombatScaling.health_multiplier(cultivation_stage(id)) if id in CULTIVATOR_IDS else MAX_HEALTH

static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id, {}).duplicate(true)

static func initial_record(id: String) -> Dictionary:
	var spec: Dictionary = definition(id)
	var start: Dictionary = STARTS[id]
	var stop: Dictionary = SCHEDULES[id][start["index"]]
	var record: Dictionary = {"room":spec["room"], "mode":start["mode"], "x":start["x"], "target":stop["x"], "remaining":start.get("remaining",0), "hp":maximum_health(id), "trust":0, "debt":0, "fear":0, "greeted":false, "episode":0, "death":{}, "schedule_index":start["index"], "interrupted":{}, "legacy_death":{}}
	if id in TAN_DANG_IDS: record["karma"] = {"grievance":"","gratitude":0,"assistance_used":false,"player_murdered":false,"spared":false,"rescued":false,"helped":false}
	if id in TAN_DANG_IDS: record["causality"]=TanDangCausality.empty()
	return record

static func stop(id: String, index: int) -> Dictionary:
	return SCHEDULES[id][index].duplicate(true)

static func activity_label(id: String, record: Dictionary) -> String:
	var point: Dictionary = TanDangLivingCatalog.stop(id,str(record["room"]),int(record["schedule_index"])) if id in TAN_DANG_IDS else stop(id, int(record["schedule_index"]))
	if point.is_empty(): return MODE_LABELS.get(str(record["mode"]),"Đang nghỉ")
	if record["mode"] in ["rest", "work"] and is_equal_approx(record["x"], point["x"]): return point["label"]
	if record["mode"] == "walk": return "Đi tới · " + String(point["label"])
	return MODE_LABELS[record["mode"]]
