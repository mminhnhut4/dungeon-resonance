class_name OpeningCultivationPanel
extends RefCounted
## View and explicit commands only. Session/common writer remain authoritative.
## Build once per Hub station refresh; the Hub owns any ui_changed connection.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const STAGES: Array[String] = ["Luyện Khí sơ", "Luyện Khí trung", "Luyện Khí hậu", "Trúc Cơ sơ"]
const NPC_ID: String = "pilot_gatherer"
const NODE_LABELS: Dictionary = {"h00_courtyard_01": "Linh thảo ở sân căn cứ", "o01_p04_01": "Linh thảo ven đường"}

static func build(hub: Node, session: Node, panel: Container) -> void:
	if not is_instance_valid(hub) or not is_instance_valid(panel): return
	_text(hub, panel, "TU LUYỆN · Vòng đầu\nLuyện kiếm trên mộc nhân để tăng thông thạo; khám phá, gặp Thanh Vy và hạ Golem để lĩnh ngộ.")
	if not is_instance_valid(session) or not session.has_method("snapshot"):
		_text(hub, panel, "Chưa thể đọc tiến triển tu luyện trong phiên này.")
		return
	var view: Variant = session.call("snapshot")
	if not view is Dictionary or not view.get("ready", false):
		_text(hub, panel, _error_text(str(view.get("error", "not_ready"))) if view is Dictionary else _error_text("not_ready"))
		return
	var config: Dictionary = view.get("config", Model.default_config())
	var actors: Dictionary = view.get("actors", {})
	var materials: Dictionary = view.get("materials", {})
	var proofs: Dictionary = view.get("proofs", {})
	var souls: int = int(view.get("souls", 0))
	var npc_eligible: bool = bool(view.get("npc_eligible", false))
	var actor: Dictionary = actors.get("player", {})
	if actor.is_empty():
		_text(hub, panel, "Chưa thể đọc cảnh giới của nhân vật.")
		return
	var next_step: Label = _text(hub, panel, "VIỆC NÊN LÀM TIẾP\n" + OpeningProgressionGuide.cultivation_next_step(hub.profile))
	next_step.name = "CultivationNextStep"
	_text(hub, panel, "Tu vi tích lũy dùng để đột phá; mana trên thanh chiến đấu dùng tung chiêu. Muốn tăng máu/mana tối đa: gặp Thanh Vy → Tịnh hóa bằng Tàn Hồn.")
	if int(actor["stage"]) < 3:
		var notice: String = _breakthrough_hint(actor, config, materials, souls, proofs, true)
		if not notice.is_empty():
			var requirement: Label = _text(hub, panel, notice)
			# Keep the reason near the first native focus row; disabled branches are skipped.
			requirement.name = "CultivationRequirements_player"
	_text(hub, panel, "Thông số sơ bộ · %d năng lượng mỗi phiên %.1f giây · %d Tinh Thạch trong kho/phiên. Tư chất tăng tốc điều tức; lĩnh ngộ và thông thạo vẫn cần tự rèn luyện." % [config["training_gain"], float(config["training_session_ticks"]) / float(config["ticks_per_second"]), config["training_cost"]])
	_text(hub, panel, "Kho căn cứ: %d Tinh Thạch · %d Bột Phép · %d Tàn Hồn" % [materials.get("crystal", 0), materials.get("dust", 0), souls])
	_actor_summary(hub, panel, "Lữ khách", actor, config)
	var training_actor: String = str(view.get("training_actor", ""))
	if not training_actor.is_empty():
		_text(hub, panel, "Đang điều tức: %s. Mở bảng tạm dừng phiên luyện; đóng bảng để tiếp tục." % ("Lữ khách" if training_actor == "player" else "Người hái thuốc"))
		_button(hub, panel, "Dừng điều tức", _stop.bind(hub, session), "CultivationStop", true)
	_button(hub, panel, "Đóng bảng và bắt đầu điều tức", _start.bind(hub, session, "player"), "CultivationStartPlayer", int(actor["stage"]) < 3 and int(materials.get("crystal", 0)) >= int(config["training_cost"]))
	_breakthrough_button(hub, session, panel, "player", actor, config, materials, souls, proofs, true)
	_text(hub, panel, "NGƯỜI HÁI THUỐC · Tài trợ tự nguyện\nChỉ luyện khi người này còn sống và đang nghỉ. Mỗi phiên dùng Tinh Thạch trong kho chung; một đợt tài trợ tối đa %d phiên." % config["max_npc_sessions"])
	var npc: Dictionary = actors.get(NPC_ID, {})
	if not npc.is_empty():
		_actor_summary(hub, panel, "Người hái thuốc", npc, config)
		_text(hub, panel, "Còn %d phiên tài trợ · %s" % [npc["sessions_left"], "Đã đăng ký" if npc["enrolled"] else "Chưa đăng ký"])
	if not npc_eligible: _text(hub, panel, "Người hái thuốc chưa sẵn sàng nhận tài trợ: cần còn sống và hồ sơ cư dân hợp lệ.")
	_button(hub, panel, "Tài trợ một đợt luyện · Tinh Thạch được trả từng phiên", _perform.bind(hub, session, "enroll", {"enabled": true}), "CultivationEnrollNpc", npc_eligible and (npc.is_empty() or int(npc["stage"]) < 3))
	if not npc.is_empty() and npc["enrolled"]:
		_button(hub, panel, "Ngừng tài trợ người hái thuốc", _perform.bind(hub, session, "enroll", {"enabled": false}), "CultivationUnenrollNpc", true)
		_button(hub, panel, "Đóng bảng · Tài trợ luyện khi người hái thuốc nghỉ", _start.bind(hub, session, NPC_ID), "CultivationStartNpc", npc_eligible and int(npc["stage"]) < 3 and int(npc["sessions_left"]) > 0 and int(materials.get("crystal", 0)) >= int(config["training_cost"]))
		_breakthrough_button(hub, session, panel, NPC_ID, npc, config, materials, souls, proofs, npc_eligible)
	_origins(hub, session, panel, view, config, materials, npc_eligible and not npc.is_empty() and bool(npc.get("enrolled", false)))
	if not str(view.get("error", "")).is_empty(): _text(hub, panel, _error_text(str(view["error"])))

static func _actor_summary(hub: Node, panel: Container, caption: String, actor: Dictionary, config: Dictionary) -> void:
	var stage: int = clampi(int(actor.get("stage", 0)), 0, 3)
	var detail: String = "%s · %s · Tư chất %d" % [caption, STAGES[stage], actor.get("aptitude", 0)]
	if stage < 3:
		detail += "\nNăng lượng %d/%d · Thông thạo %d/%d · Lĩnh ngộ %d/%d" % [actor["energy"], config["energy_thresholds"][stage], actor["mastery"], config["mastery_thresholds"][stage], actor["insight_ids"].size(), config["insight_thresholds"][stage]]
	else:
		detail += "\nĐã hoàn thành vòng tu luyện đầu."
	_text(hub, panel, detail)

static func _breakthrough_button(hub: Node, session: Node, panel: Container, actor_id: String, actor: Dictionary, config: Dictionary, materials: Dictionary, souls: int, proofs: Dictionary, eligible: bool) -> void:
	var stage: int = int(actor["stage"])
	if stage >= 3: return
	var cost: int = int(config["final_dust_cost"] if stage == 2 else config["interim_dust_cost"])
	var text: String = "%s %s · %d Bột Phép" % ["Đột phá" if stage==2 else "Tiến tầng",STAGES[stage + 1], cost]
	if stage == 2: text += " + %d Tàn Hồn · Có %d · Thiếu %d · Cần chứng tích Golem" % [config["final_soul_cost"], souls, maxi(0, int(config["final_soul_cost"]) - souls)]
	var allowed: bool = eligible and bool(actor["enrolled"]) and int(actor["energy"]) >= int(config["energy_thresholds"][stage]) and int(actor["mastery"]) >= int(config["mastery_thresholds"][stage]) and actor["insight_ids"].size() >= int(config["insight_thresholds"][stage]) and int(materials.get("dust", 0)) >= cost
	if stage == 2: allowed = allowed and souls >= int(config["final_soul_cost"]) and int(proofs.get("golem", 0)) >= int(config["final_golem_proof"])
	var hint: String = _breakthrough_hint(actor, config, materials, souls, proofs, eligible) if not allowed else text
	if stage==2 and actor_id=="player":
		_text(hub,panel,"Chọn một nhánh khi đột phá. Trang bị và bộ bùa vẫn quyết định cách chơi; G dùng động tác đã chọn.")
		var cloud_return_button: Button = _button(hub,panel,text+" · Hồi Phong Kiếm",_perform.bind(hub,session,"breakthrough",{"actor_id":actor_id,"branch_id":"cloud_return"}),"CultivationBranch_cloud_return",allowed)
		if not allowed: cloud_return_button.tooltip_text = hint
		var tether_sigil_button: Button = _button(hub,panel,text+" · Tỏa Linh Ấn",_perform.bind(hub,session,"breakthrough",{"actor_id":actor_id,"branch_id":"tether_sigil"}),"CultivationBranch_tether_sigil",allowed)
		if not allowed: tether_sigil_button.tooltip_text = hint
		return
	var button: Button = _button(hub, panel, text, _perform.bind(hub, session, "breakthrough", {"actor_id": actor_id}), "CultivationBreakthrough_" + actor_id, allowed)
	if not allowed: button.tooltip_text = hint


static func _breakthrough_hint(actor: Dictionary, config: Dictionary, materials: Dictionary, souls: int, proofs: Dictionary, eligible: bool) -> String:
	var stage: int = int(actor["stage"])
	var missing: Array[String] = []
	if not eligible: missing.append("người hái thuốc còn sống và hồ sơ cư dân hợp lệ")
	if not bool(actor["enrolled"]): missing.append("đăng ký một đợt tài trợ")
	var energy: int = maxi(0, int(config["energy_thresholds"][stage]) - int(actor["energy"]))
	var mastery: int = maxi(0, int(config["mastery_thresholds"][stage]) - int(actor["mastery"]))
	var insight: int = maxi(0, int(config["insight_thresholds"][stage]) - actor["insight_ids"].size())
	var dust_cost: int = int(config["final_dust_cost"] if stage == 2 else config["interim_dust_cost"])
	var dust: int = maxi(0, dust_cost - int(materials.get("dust", 0)))
	if energy > 0: missing.append("%d năng lượng" % energy)
	if mastery > 0: missing.append("%d thông thạo" % mastery)
	if insight > 0: missing.append("%d lĩnh ngộ" % insight)
	if dust > 0: missing.append("%d Bột Phép trong kho" % dust)
	if stage == 2:
		var soul_count: int = maxi(0, int(config["final_soul_cost"]) - souls)
		var proof_count: int = maxi(0, int(config["final_golem_proof"]) - int(proofs.get("golem", 0)))
		if soul_count > 0: missing.append("%d Tàn Hồn" % soul_count)
		if proof_count > 0: missing.append("%d chứng tích Golem" % proof_count)
	if missing.is_empty(): return ""
	return "Còn thiếu: %s. Đột phá được xác nhận bằng nút này khi đủ điều kiện." % "; ".join(missing)

static func _origins(hub: Node, session: Node, panel: Container, view: Dictionary, config: Dictionary, materials: Dictionary, npc_enabled: bool) -> void:
	_text(hub, panel, "LINH THẢO VÀ ĐAN DƯỢC\nHái cây hiếm ở sân căn cứ hoặc ven đường. Chế đan giữ nguồn linh thảo; mỗi món chỉ được dùng một lần cho một người.")
	var origins: Dictionary = view.get("origins", {})
	var ids: Array = origins.keys()
	ids.sort()
	var found: bool = false
	for origin_id: String in ids:
		var origin: Dictionary = origins[origin_id]
		if not str(origin.get("consumer", "")).is_empty(): continue
		found = true
		var is_herb: bool = origin.get("kind") == "herb"
		var caption: String = str(NODE_LABELS.get(origin_id, "Linh thảo đã hái")) if is_herb else "Đan tư chất đã chế"
		var gain: int = int(config["aptitude_gains"]["herb" if is_herb else "pill"])
		_text(hub, panel, "%s · Tăng %d tư chất" % [caption, gain])
		_button(hub, panel, "Dùng cho lữ khách", _perform.bind(hub, session, "consume", {"actor_id": "player", "origin_id": origin_id}), "CultivationConsume_player_" + origin_id, true)
		if npc_enabled: _button(hub, panel, "Dùng cho người hái thuốc", _perform.bind(hub, session, "consume", {"actor_id": NPC_ID, "origin_id": origin_id}), "CultivationConsume_npc_" + origin_id, true)
		if is_herb:
			_button(hub, panel, "Chế Đan tư chất · %d Bột Phép" % config["pill_dust_cost"], _perform.bind(hub, session, "craft_pill", {"origin_id": origin_id}), "CultivationCraft_" + origin_id, int(materials.get("dust", 0)) >= int(config["pill_dust_cost"]))
	if not found: _text(hub, panel, "Chưa có linh thảo hoặc đan tư chất chưa dùng.")

static func _start(hub: Node, session: Node, actor_id: String) -> void:
	if not _active(hub, session) or not session.has_method("start_training"): return
	# Release the station's input/time claim before the session checks eligibility.
	if hub.has_method("_close_panel"): hub.call("_close_panel")
	elif hub.has_method("close_station"): hub.call("close_station")
	if bool(session.call("start_training", actor_id)): return
	if hub.has_method("open_station"): hub.call("open_station", &"training")
	var view: Variant = session.call("snapshot")
	_notice(hub, _error_text(str(view.get("error", "training_unavailable"))) if view is Dictionary else _error_text("training_unavailable"))

static func _stop(hub: Node, session: Node) -> void:
	if not _active(hub, session) or not session.has_method("stop_training"): return
	session.call("stop_training")
	_notice(hub, "Đã dừng điều tức. Tiến triển đã lưu được giữ nguyên.")

static func _perform(hub: Node, session: Node, kind: String, args: Dictionary) -> void:
	if not _active(hub, session) or not session.has_method("perform"): return
	var result: Variant = session.call("perform", kind, args.duplicate(true))
	if not result is Dictionary or not result.get("ok", false):
		_notice(hub, _error_text(str(result.get("error", "save_failed"))) if result is Dictionary else _error_text("save_failed"))
		return
	_notice(hub, "Thao tác này đã hoàn tất trước đó." if result.get("already_committed", false) else "Đã hoàn tất và lưu tiến triển.")

static func _active(hub: Node, session: Node) -> bool:
	return is_instance_valid(hub) and not hub.is_queued_for_deletion() and is_instance_valid(session) and not session.is_queued_for_deletion() and bool(hub.get("station_open")) and str(hub.get("current_station")) == "training"

static func _notice(hub: Node, text: String) -> void:
	if not is_instance_valid(hub) or hub.is_queued_for_deletion(): return
	hub.set("station_notice", text)
	if bool(hub.get("station_open")) and str(hub.get("current_station")) == "training" and hub.has_method("_refresh_station"):
		hub.call_deferred("_refresh_station")

static func _text(hub: Node, panel: Container, text: String) -> Label:
	var label: Label
	if hub.has_method("_label"): label = hub.call("_label", panel, Vector2.ZERO, text) as Label
	if label == null:
		label = Label.new()
		label.text = text
		panel.add_child(label)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

static func _button(hub: Node, panel: Container, text: String, action: Callable, name: String, enabled: bool) -> Button:
	var button: Button
	# The old view remains until its deferred rebuild. Give each quoted button
	# one callback so duplicate pressed delivery cannot cross two realm gates.
	var delivered: Array[bool] = [false]
	var once: Callable = func() -> void:
		if delivered[0]: return
		delivered[0]=true
		action.call()
	if hub.has_method("_button"): button = hub.call("_button", text, once) as Button
	if button == null:
		button = Button.new()
		button.text = text
		button.pressed.connect(once)
		panel.add_child(button)
	elif button.get_parent() != panel:
		button.reparent(panel)
	button.name = name
	button.disabled = not enabled
	button.tooltip_text = text
	button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	button.custom_minimum_size.y = 44.0
	return button

static func _error_text(error: String) -> String:
	var messages: Dictionary = {
		"energy_required": "Chưa tích đủ năng lượng để đột phá.",
		"mastery_required": "Chưa đủ thông thạo. Hãy luyện kiếm trên mộc nhân hoặc chiến đấu.",
		"insight_required": "Chưa đủ lĩnh ngộ. Hãy khám phá, gặp Thanh Vy và hạ Golem.",
		"training_resource_required": "Kho căn cứ chưa đủ Tinh Thạch cho phiên luyện.",
		"breakthrough_resource_required": "Kho căn cứ chưa đủ Bột Phép để đột phá.",
		"pill_resource_required": "Kho căn cứ chưa đủ Bột Phép để chế đan.",
		"golem_proof_required": "Cần chứng tích hạ Golem đã được ghi nhận.",
		"souls_required": "Chưa đủ Tàn Hồn để đột phá.",
		"actor_not_enrolled": "Hãy đăng ký một đợt tài trợ trước khi luyện cùng người hái thuốc.",
		"training_session_budget": "Đợt tài trợ đã hết phiên. Có thể đăng ký một đợt mới.",
		"origin_already_consumed": "Linh thảo hoặc đan này đã được dùng.",
		"stage_complete": "Đã hoàn thành vòng tu luyện đầu.",
		"aptitude_capacity_requires_review": "Chưa thể dùng món này với giới hạn tư chất đang cấu hình.",
		"event_conflict": "Thao tác này không còn khớp trạng thái hiện tại. Hãy đóng và mở lại bảng."
	}
	if messages.has(error): return messages[error]
	if "npc" in error or "life" in error: return "Người hái thuốc chưa đủ điều kiện: cần còn sống, đang nghỉ và trạng thái đã được lưu."
	if "quarant" in error or "invalid" in error or "schema" in error: return "Hồ sơ cần được kiểm tra trước khi lưu tiến triển tu luyện."
	return "Chưa thể hoàn tất. Hãy kiểm tra điều kiện và trạng thái lưu dữ liệu."
