class_name ExteriorHub
extends PrologueHub
## The approved quiet exploration slice retains the Hub's one actor/session.
const ORIGIN := Vector2(8000,0)
var exterior: ExteriorRoom
var outside: bool = false
var door_latched: bool = false
var reject_next_load: bool = false
var last_entry: StringName = &"west"
var pending_note: StringName = &""
var transition_count: int = 0
var npc_population: NpcPopulation
var sect_journey: SectJourney
var entry_card: RegionEntryCard
var _entry_controller_device: int = -1

func _ready() -> void:
	super._ready()
	if world_building_enabled:
		sect_journey=SectJourney.new()
		add_child(sect_journey)
		sect_journey.initialize(self)
		npc_population = NpcPopulation.new()
		npc_population.hub = self
		add_child(npc_population)
	_station(&"exterior_road",Vector2(750,640),"ĐƯỜNG BỘ · BẾN TRẦM →")
	entry_card = RegionEntryCard.new()
	add_child(entry_card)
	# A new process uses the existing GameFlow startup contract. Geographic
	# progress is restored separately; ordinary doors never create another actor.
	if world_building_enabled and not from_defeat and not profile.exterior_progress_quarantined and profile.exterior_progress["room_id"] != String(ExteriorRouteCatalog.HUB):
		call_deferred("restore_exterior_anchor")

func _can_travel() -> bool:
	return is_instance_valid(player) and player.is_inside_tree() and not player.is_queued_for_deletion() and player.health.current_health > 0 and player.controls_enabled and not gear.modal.is_open and not station_open and not dialogue.is_open and (player.hit_reaction == null or not player.hit_reaction.blocks_controls())

func enter_exterior(room: StringName, route: StringName = ExteriorRouteCatalog.MAIN, entry: StringName = &"west", commit: bool = true) -> bool:
	if not _can_travel() or not ExteriorRouteCatalog.valid_anchor(room,route,entry): return false
	if room == ExteriorRouteCatalog.HUB: return return_to_hub(commit)
	if room in SectRouteCatalog.ROOMS and (sect_journey==null or not sect_journey.can_enter(room)):
		prompt.text="Lối môn phái chưa mở. Đọc sổ tiếp nhận gần cổng; sân trong cần đủ hai ghi chép và quyền khách."
		return false
	if reject_next_load:
		reject_next_load = false
		return false
	var target := ExteriorRoom.new()
	if not target.configure(room,route,bool(profile.exterior_progress["sc01_open"])) or not target.dry_anchor(entry):
		target.free()
		return false
	var previous: Dictionary = profile.exterior_progress.duplicate(true)
	var previous_opening: Dictionary = profile.opening_progress
	var next: Dictionary = previous.duplicate(true)
	next["room_id"] = String(room)
	next["region_id"] = String(ExteriorRouteCatalog.region(room))
	next["route_id"] = String(route)
	next["anchor_id"] = String(entry)
	if not next["discovered_rooms"].has(String(room)): next["discovered_rooms"].append(String(room))
	profile.exterior_progress = next
	if commit and world_building_enabled: profile.opening_progress = OpeningProgress.with_event(profile.opening_progress, &"explored")
	if commit and not profile.save():
		profile.exterior_progress = previous
		profile.opening_progress = previous_opening
		target.free()
		return false
	_clear_room_presentation()
	if is_instance_valid(exterior):
		TimeScaleClaims.release_subtree(exterior)
		remove_child(exterior)
		exterior.queue_free()
	target.position = ORIGIN
	add_child(target)
	exterior = target
	outside = true
	last_entry = entry
	yard.hide()
	yard.process_mode = Node.PROCESS_MODE_DISABLED
	house.hide()
	house.process_mode = Node.PROCESS_MODE_DISABLED
	if has_node("PrologueHubArt"): get_node("PrologueHubArt").process_mode = Node.PROCESS_MODE_DISABLED
	PlayerTravel.relocate(player,ORIGIN+target.anchors[entry])
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = int(ORIGIN.x)
	camera.limit_right = int(ORIGIN.x+target.width)
	camera.limit_top = int(target.bounds.position.y)
	camera.limit_bottom = int(target.bounds.end.y)
	camera.reset_smoothing()
	camera.force_update_scroll()
	door_latched = true
	transition_count += 1
	refresh_summary()
	zone_changed.emit(ExteriorRouteCatalog.region(room))
	if commit and world_building_enabled: profile.changed.emit()
	return true

func return_to_hub(commit: bool = true) -> bool:
	if not _can_travel(): return false
	var previous: Dictionary = profile.exterior_progress.duplicate(true)
	var next: Dictionary = previous.duplicate(true)
	next["room_id"] = String(ExteriorRouteCatalog.HUB)
	next["region_id"] = String(ExteriorRouteCatalog.HUB)
	next["route_id"] = "main"
	next["anchor_id"] = "road"
	profile.exterior_progress = next
	if commit and not profile.save():
		profile.exterior_progress = previous
		return false
	_clear_room_presentation()
	if is_instance_valid(exterior):
		TimeScaleClaims.release_subtree(exterior)
		remove_child(exterior)
		exterior.queue_free()
	exterior = null
	outside = false
	inside_house = false
	yard.process_mode = Node.PROCESS_MODE_INHERIT
	house.process_mode = Node.PROCESS_MODE_INHERIT
	yard.show()
	house.hide()
	if has_node("PrologueHubArt"): get_node("PrologueHubArt").process_mode = Node.PROCESS_MODE_INHERIT
	PlayerTravel.relocate(player,stations[&"exterior_road"].global_position)
	_set_camera_bounds(false)
	presentation.atmosphere.show()
	presentation.rebuild()
	set_training_aggression(training_aggression)
	door_latched = true
	transition_count += 1
	refresh_summary()
	zone_changed.emit(&"yard")
	return true

func _clear_room_presentation() -> void:
	var style_binding: Variant = player.get_meta(&"opening_style_binding") if player.has_meta(&"opening_style_binding") else null
	if is_instance_valid(style_binding): style_binding.before_travel()
	executor.clear_entities()
	feedback.reset_feedback()
	presentation.rebuild()
	presentation.atmosphere.hide()
	presentation.foyer_art.clear()
	get_node("/root/AudioManager").stop_owner(presentation)

func nearest_station() -> StringName:
	if cultivation_session!=null and cultivation_session.herb_near(INTERACTION_RANGE): return &"aptitude_herb"
	if not outside: return super.nearest_station()
	if not is_instance_valid(exterior): return &""
	var best: StringName = &""
	var distance: float = INTERACTION_RANGE
	for id: StringName in exterior.interactions:
		var next: float = player.global_position.distance_to(ORIGIN+exterior.interactions[id])
		if next < distance:
			distance = next
			best = id
	if is_instance_valid(npc_population):
		var pilot_id: String = npc_population.nearest_id(distance)
		if not pilot_id.is_empty(): return StringName(pilot_id)
	return best

func interact_station(id: StringName) -> bool:
	if id==&"aptitude_herb": return cultivation_session!=null and cultivation_session.harvest_near()
	if is_instance_valid(npc_population) and String(id) in NpcPilotCatalog.IDS: return npc_population.interact(String(id))
	if not outside:
		if id == &"exterior_road":
			if id != nearest_station() or not _can_travel() or inside_house or not player.motor.is_grounded() or door_latched: return false
			return enter_exterior(ExteriorRouteCatalog.ROOMS[0])
		return super.interact_station(id)
	if not _can_travel() or id != nearest_station() or not player.motor.is_grounded(): return false
	if id in [&"sect_register",&"sect_marker_west",&"sect_marker_east",&"sect_history"]: return sect_journey!=null and sect_journey.interact(id)
	if id in [&"door_west",&"door_east",&"tunnel",&"sect_branch"]:
		if door_latched: return false
		var destination: Dictionary = ExteriorRouteCatalog.link(exterior.room_id,exterior.route_id,id)
		if destination.is_empty(): return false
		return enter_exterior(destination["room"],destination["route"],destination["anchor"])
	match id:
		&"sc01_lever": return open_sc01()
		&"shrine":
			if not set_geographic_anchor(&"shrine"): return false
			return open_courier_register() if courier != null else true
		&"water": return set_geographic_anchor(&"water")
		&"water_record": return open_exterior_note(&"water_marks")
		&"post_record": return open_exterior_note(&"post_office_record")
		&"shipyard_record": return open_exterior_note(&"shipyard_record")
		&"hanh": return open_exterior_note(&"hanh_encounter")
	return false

func open_sc01() -> bool:
	if not outside or exterior.room_id != &"o01_p03" or nearest_station() != &"sc01_lever" or not _can_travel(): return false
	if profile.exterior_progress["sc01_open"]: return true
	var previous: Dictionary = profile.exterior_progress.duplicate(true)
	profile.exterior_progress["sc01_open"] = true
	if not profile.save():
		profile.exterior_progress = previous
		return false
	refresh_summary()
	return true

func set_geographic_anchor(id: StringName) -> bool:
	if not outside or not _can_travel() or not exterior.dry_anchor(id): return false
	var previous: Dictionary = profile.exterior_progress.duplicate(true)
	profile.exterior_progress["anchor_id"] = String(id)
	if not profile.save():
		profile.exterior_progress = previous
		return false
	last_entry = id
	return true

func restore_exterior_anchor() -> bool:
	if not _can_travel() or not ExteriorProgress.valid(profile.exterior_progress): return false
	var saved: Dictionary = profile.exterior_progress.duplicate(true)
	return enter_exterior(StringName(saved["room_id"]),StringName(saved["route_id"]),StringName(saved["anchor_id"]),false)

func open_exterior_note(id: StringName) -> bool:
	var sources: Dictionary[StringName,StringName] = {&"water_marks":&"water_record",&"post_office_record":&"post_record",&"shipyard_record":&"shipyard_record",&"hanh_encounter":&"hanh"}
	if not outside or id not in ExteriorRouteCatalog.NOTES or not _can_travel() or nearest_station() != sources[id]: return false
	pending_note = id
	_dialogue_previous_controls = player.controls_enabled
	player.suspend_controls(true)
	TimeScaleClaims.acquire(dialogue,0.1)
	(gear.modal as InventoryScreen).open_button.hide()
	var lines: Array[String] = []
	var speaker: String = "Dấu tích đường nước"
	match id:
		&"water_marks": lines = ["Vạch thấp đánh dấu mực nước hiện tại. Vạch cao còn lưu dấu một mùa lũ cũ.","Đường khô qua quảng trường dẫn tới bưu trạm. Có thể đối chiếu dấu nước với hồ sơ ở đó."]
		&"post_office_record":
			speaker = "Hồ sơ bưu trạm"
			lines = ["Tủ hồ sơ vẫn nằm trên nền cao, ngoài phần phố thấp bị ngập.","Đây là một nơi đối chiếu dấu tích và đường thư. Chưa kết luận người viết, nguyên nhân nước hay số phận người nhận từ một mảnh hồ sơ."]
		&"shipyard_record":
			speaker = "Ghi chép xưởng"
			lines = ["Bản ghi ở xưởng giúp đối chiếu công trình trên bờ với đường nước ngoài cầu tàu.","Thuyền chưa sẵn sàng rời bến. Đường bộ qua bưu trạm vẫn thông."]
		&"hanh_encounter":
			speaker = "Hạnh"
			lines = ["Ta là Hạnh, thợ đóng thuyền ở bến này.","Ghi chép trong xưởng vẫn còn. Nếu muốn đối chiếu, hãy bắt đầu ở bưu trạm cũ rồi theo đường khô trở lại đây."]
	var choices: Array[Dictionary] = [{"id":StringName("exterior_note_"+String(id)),"text":"Ghi lại dấu mốc"},{"id":&"exterior_later","text":"Để sau"}]
	dialogue.open(speaker,lines,choices)
	return true

func _dialogue_closed() -> void:
	super._dialogue_closed()
	# select_choice closes, then emits its choice synchronously. Cancellation
	# clears the pending record on this same frame's deferred boundary.
	call_deferred("_clear_pending_note")

func _clear_pending_note() -> void:
	if not dialogue.is_open: pending_note = &""

func _dialogue_choice(id: StringName) -> void:
	if String(id).begins_with("courier_") and courier != null and courier.context == &"shrine":
		var response: Dictionary = courier.apply_action(id)
		if response["handled"]: open_courier_register(response["message"])
		return
	if id == &"exterior_later":
		pending_note = &""
		return
	if String(id).begins_with("exterior_note_"):
		var note := StringName(String(id).trim_prefix("exterior_note_"))
		if note != pending_note or note not in ExteriorRouteCatalog.NOTES: return
		pending_note = &""
		if profile.exterior_progress["notes"].has(String(note)): return
		var previous: Dictionary = profile.exterior_progress.duplicate(true)
		profile.exterior_progress["notes"].append(String(note))
		if not profile.save(): profile.exterior_progress = previous
		refresh_summary()
		return
	super._dialogue_choice(id)

func refresh_summary() -> void:
	if not outside or not is_instance_valid(exterior):
		super.refresh_summary()
		return
	if summary == null: return
	summary.text = "%s\nĐường khô · %s" % [ExteriorRouteCatalog.title(exterior.room_id,exterior.route_id),"SC01 đã mở" if profile.exterior_progress["sc01_open"] else "Khám phá"]

func _process(delta: float) -> void:
	var controller_held: bool = _entry_controller_device >= 0 and Input.is_joy_button_pressed(_entry_controller_device,JOY_BUTTON_X)
	if not Input.is_action_pressed(&"interact") and not controller_held: door_latched = false
	if not outside:
		super._process(delta)
		if nearest_station() == &"exterior_road": prompt.text = "E · Đi bộ ra Đường Hành Hương / Bến Trầm"
		_update_entry_card()
		return
	var id: StringName = nearest_station()
	prompt.text = "Space / E · Tiếp tục thoại" if dialogue.is_open else "E · Qua cửa đường bộ" if id in [&"door_west",&"door_east"] else "E · Vào hầm đường giữ đèn" if id == &"tunnel" else "E · Mở cổng đường giữ đèn" if id == &"sc01_lever" else "E · Ghi mốc địa lý (không hồi / bank)" if id in [&"shrine",&"water"] else "E · Trò chuyện với Hạnh" if id == &"hanh" else "E · Đọc dấu tích" if id != &"" else "A/D: Đi bộ · Space: Nhảy · Shift: Dash · Tab: Hành trang"
	if player.global_position.y > ORIGIN.y+exterior.bounds.end.y+80 and player.health.current_health > 0:
		executor.clear_entities()
		PlayerTravel.relocate(player,ORIGIN+exterior.anchors[last_entry])
	_update_entry_card()

func _entry_destination(id: StringName) -> Dictionary:
	if not outside:
		return {"room":ExteriorRouteCatalog.ROOMS[0],"route":ExteriorRouteCatalog.MAIN,"anchor":&"west"} if id == &"exterior_road" and not inside_house else {}
	return ExteriorRouteCatalog.link(exterior.room_id,exterior.route_id,id) if is_instance_valid(exterior) and id in [&"door_west",&"door_east",&"tunnel",&"sect_branch"] else {}

func _update_entry_card() -> void:
	if entry_card == null: return
	var id: StringName = nearest_station()
	var target: Dictionary = _entry_destination(id)
	if target.is_empty():
		entry_card.hide_preview(true)
		prompt.show()
		return
	if target["room"] in SectRouteCatalog.ROOMS and not sect_journey.can_enter(target["room"]):
		entry_card.hide_preview(true)
		prompt.text="Lối chưa mở · E đọc sổ tiếp nhận gần cổng; sân trong cần trình đủ hai ghi chép."
		prompt.show()
		return
	if not _can_travel() or not player.motor.is_grounded() or door_latched or get_tree().paused:
		entry_card.hide_preview()
		prompt.show()
		return
	var door: Vector2 = ORIGIN+exterior.interactions[id] if outside else stations[id].global_position
	var key: String = "%d:%s:%s:%s" % [transition_count,id,target["room"],target["route"]]
	var reserved: Array[Rect2] = []
	var inventory_screen: InventoryScreen = gear.modal as InventoryScreen
	if inventory_screen != null:
		for control: Control in [inventory_screen.open_button,inventory_screen.tracker,inventory_screen.map_button]:
			if is_instance_valid(control) and control.is_visible_in_tree(): reserved.append(control.get_global_rect())
	entry_card.set_reserved_rects(reserved)
	entry_card.show_destination(key,target,profile.exterior_progress["discovered_rooms"].has(String(target["room"])),door,player.global_position)
	prompt.visible = not entry_card.panel.visible

func route_world_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X and not event.pressed:
		_entry_controller_device = -1
	# E keeps the inherited routing. A controller uses the same guarded station
	# dispatch only at an eligible visible doorway, without editing the Input Map.
	var candidate: Dictionary = _entry_destination(nearest_station())
	if entry_card != null and entry_card.panel.visible and _can_travel() and player.motor.is_grounded() and not door_latched and not get_tree().paused and not candidate.is_empty() and candidate == entry_card.destination:
		if event.is_action_pressed(&"ui_cancel") or (event is InputEventJoypadButton and event.button_index == JOY_BUTTON_B and event.pressed):
			entry_card.dismiss()
			prompt.show()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_X and event.pressed:
			_entry_controller_device = event.device
			get_viewport().set_input_as_handled()
			interact_station(nearest_station())
			return
	super.route_world_input(event)

func open_courier_register(message: String = "") -> bool:
	if courier == null or not outside or exterior.room_id != &"o01_p03" or nearest_station() != &"shrine" or not _can_travel(): return false
	courier.arm(&"shrine")
	_dialogue_previous_controls = player.controls_enabled
	player.suspend_controls(true)
	TimeScaleClaims.acquire(dialogue, 0.1)
	(gear.modal as InventoryScreen).open_button.hide()
	var lines: Array[String] = courier.lines(&"shrine")
	if not message.is_empty(): lines.insert(0, message)
	var choices: Array[Dictionary] = courier.choices(&"shrine")
	choices.append({"id": &"courier_later", "text": "Để sau · Tiếp tục hành trình"})
	dialogue.open("Bảng tiếp nhận tại miếu", lines, choices)
	return true

