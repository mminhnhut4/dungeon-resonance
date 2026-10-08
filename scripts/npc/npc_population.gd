class_name NpcPopulation
extends Node
## One registry per exterior Hub, room-owned representations and bounded 4Hz AI.
signal cue_requested(stable_id: String, cue: StringName, world_position: Vector2, lifetime_owner: Node)
var hub: ExteriorHub
var state := NpcWorldState.new()
var actors: Dictionary = {}
var accumulator: float = 0.0
var autosave_remaining: float = 30.0
var talking_id: String = ""
var pending_token: String = ""
var kill_confirmation: bool = false
var _dialogue_extensions: Dictionary = {}
var _offered_extension_choices: Dictionary = {}

## Bounded composition point for the courier/cultivation owners. Providers append
## detached content; only their own namespaced choices reach their own handler.
func register_dialogue_extension(scope_id: StringName, provider: Callable, handler: Callable) -> bool:
	if scope_id not in [&"courier",&"cultivation"] or _dialogue_extensions.has(scope_id) or _dialogue_extensions.size() >= 2 or not provider.is_valid() or not handler.is_valid(): return false
	_dialogue_extensions[scope_id] = {"provider":provider,"handler":handler}
	return true

func _compose_living_extensions(id: String, lines: Array[String], choices: Array[Dictionary]) -> void:
	for scope_id: StringName in [&"courier",&"cultivation"]:
		if not _dialogue_extensions.has(scope_id): continue
		var provider: Callable = _dialogue_extensions[scope_id]["provider"]
		if not provider.is_valid(): continue
		var extension: Variant = provider.call(id,state.records[id].duplicate(true))
		if not extension is Dictionary: continue
		var extra_lines: Variant = extension.get("lines",[])
		if extra_lines is Array and extra_lines.size() <= 4:
			for line: Variant in extra_lines:
				if line is String and not line.is_empty() and line.length() <= 768: lines.append(line)
		var extra_choices: Variant = extension.get("choices",[])
		if not extra_choices is Array or extra_choices.size() > 3: continue
		for choice: Variant in extra_choices:
			if not choice is Dictionary or not (choice.get("id") is String or choice.get("id") is StringName) or not choice.get("text") is String: continue
			var key := StringName(choice["id"])
			if not String(key).begins_with(String(scope_id)+"_") or String(key).length() > 64 or choice["text"].is_empty() or choice["text"].length() > 768 or _offered_extension_choices.has(key): continue
			choices.insert(choices.size()-1,choice.duplicate(true))
			_offered_extension_choices[key] = {"namespace":scope_id,"enabled":bool(choice.get("enabled",true))}

func _ready() -> void:
	name = "NpcPopulation"
	state.save_path = hub.profile.save_path + ".npc_v1.json"
	state.load_state()
	state.activity_changed.connect(_checkpoint_cultivation_rest)
	if hub.courier != null: register_dialogue_extension(&"courier", _courier_content, _courier_action)
	hub.zone_changed.connect(_region_changed)
	hub.dialogue.closed.connect(_dialogue_closed)
	hub.dialogue.choice_selected.connect(_choice_selected)
	_region_changed(&"")

func _region_changed(_region: StringName) -> void:
	clear_actors()
	state.save()
	if state.read_only or not hub.outside or not is_instance_valid(hub.exterior) or hub.exterior.route_id != ExteriorRouteCatalog.MAIN: return
	for id: String in NpcPilotCatalog.IDS:
		if state.records[id]["room"] != String(hub.exterior.room_id) or state.records[id]["mode"] in ["dead", "recovering"]: continue
		var actor: NpcPilotActor = preload("res://scripts/npc/cultivator_actor.gd").new() if id in NpcPilotCatalog.CULTIVATOR_IDS else NpcPilotActor.new()
		if id in NpcPilotCatalog.CULTIVATOR_IDS: actor.set("player",hub.player)
		actor.name = id.to_pascal_case()
		actor.stable_id = id
		actor.npc_id = StringName(id)
		actor.world_state = state
		actor.room = hub.exterior
		actor.bind_road_idle_art()
		actor.cue_requested.connect(_forward_cue)
		hub.exterior.add_child(actor)
		actors[id] = actor

func clear_actors() -> void:
	for actor: NpcPilotActor in actors.values():
		if is_instance_valid(actor):
			state.set_local_control(actor.stable_id,false)
			get_node("/root/AudioManager").stop_owner(actor)
			if actor.get_parent() != null: actor.get_parent().remove_child(actor)
			actor.queue_free()
	actors.clear()

func _remove_withdrawn_actor(id: String) -> void:
	state.set_local_control(id,false)
	var actor: NpcPilotActor = actors.get(id)
	actors.erase(id)
	if not is_instance_valid(actor): return
	get_node("/root/AudioManager").stop_owner(actor)
	if actor.get_parent() != null: actor.get_parent().remove_child(actor)
	actor.queue_free()

func _forward_cue(id: String, cue: StringName, at: Vector2, owner_node: Node) -> void:
	cue_requested.emit(id, cue, at, owner_node)

func nearest_id(distance: float) -> String:
	if state.read_only: return ""
	var best: String = ""
	for id: String in actors:
		var actor: NpcPilotActor = actors[id]
		if not is_instance_valid(actor) or state.records[id]["mode"] in ["dead", "recovering"]: continue
		var next: float = hub.player.global_position.distance_to(actor.global_position)
		if next < distance:
			distance = next
			best = id
	return best

func interact(id: String) -> bool:
	if state.read_only or not actors.has(id) or not hub._can_travel() or id != nearest_id(PrologueHub.INTERACTION_RANGE): return false
	var mode: String = state.records[id]["mode"]
	if mode in ["dead", "recovering"]: return false
	if mode != "downed" and not state.begin_talk(id): return false
	talking_id = id
	pending_token = state.decision_token(id)
	kill_confirmation = false
	hub._dialogue_previous_controls = hub.player.controls_enabled
	hub.player.suspend_controls(true)
	(hub.gear.modal as InventoryScreen).open_button.hide()
	TimeScaleClaims.acquire(hub.dialogue, 0.1)
	_open_dialogue(mode == "downed")
	return true

func _open_dialogue(downed: bool, error: String = "") -> void:
	var id: String = talking_id
	var spec: Dictionary = NpcPilotCatalog.definition(id)
	var lines: Array[String] = []
	var choices: Array[Dictionary] = []
	_offered_extension_choices.clear()
	if downed:
		lines = ["%s đang trọng thương và sẽ rút về dưỡng thương. Người này trở lại sau một chuyến hầm ngục của bạn, vẫn nhớ việc đã xảy ra. Dừng tay không xóa nỗi sợ hoặc tạo món nợ với người gây thương tích." % spec["name"]]
		choices = [{"id":&"pilot_withdraw", "text":"Để người này rút về dưỡng thương"}]
	else:
		var record: Dictionary = state.records[id]
		lines = [spec["goal"], "Ta chưa nhận lời đi hầm ngục. Một lần chào hỏi không đủ thành người đồng hành. Tin cậy %d · Thiện duyên %d · Sợ hãi %d." % [record["trust"],record["debt"],record["fear"]]]
		choices = [{"id":&"pilot_greet", "text":"Hỏi thăm", "enabled":not record["greeted"]}, {"id":&"pilot_leave", "text":"Để người này tiếp tục công việc"}]
		if id in NpcSocialCatalog.IDS:
			var social: Dictionary = NpcSocialCatalog.definition(id)
			var helped: bool = NpcSocialProgress.helped(OpeningSocialRuntime.state(hub.profile),id)
			var relation: Dictionary = NpcSocialProgress.relationship(OpeningSocialRuntime.state(hub.profile),id,record)
			lines = NpcSocialCatalog.memory_lines(id,record["trust"] < 0,record["debt"] > 0,helped,record["greeted"] or record["trust"] < 0 or record["debt"] > 0 or helped)
			lines.append("%s · Tin cậy %d · Món nợ %d · Sợ hãi %d." % [social["personality"],relation["trust"],relation["debt"],relation["fear"]])
			if helped and record["fear"] < 12:
				lines.append(social["hint"])
			elif record["fear"] >= 12:
				lines.append("Ta chưa bình tĩnh để nhận đồ hay chỉ đường. Hãy để ta có khoảng cách.")
			else:
				lines.append("Nếu nhường 2 Sợi Vải Lanh trong kho, ta có thể chuẩn bị đồ cho công việc và chỉ lối đi ở đây. Cũng số vải ấy, ngươi có thể giữ để chế 1 băng gạc cho mình. Việc giúp chỉ được ghi nhận một lần; không mua được tình bạn.")
			choices = [{"id":&"pilot_greet", "text":"Hỏi thăm", "enabled":not record["greeted"]}, {"id":&"pilot_help", "text":"Nhường 2 Sợi Vải Lanh từ kho", "enabled":hub.economy.quote_social_help(state,id)["can_help"], "requires_confirmation":true, "confirm_text":"Dùng 2 Sợi Vải Lanh trong kho giúp người này? Bạn sẽ còn ít vật liệu chế băng gạc hơn. Không có cam kết đồng hành."}, {"id":&"pilot_leave", "text":"Giữ vật liệu · Để người này tiếp tục công việc"}]
	if not downed:
		if id in NpcPilotCatalog.CULTIVATOR_IDS: lines.append_array(CultivatorCatalog.dialogue_lines(id))
		_compose_living_extensions(id,lines,choices)
	if not error.is_empty(): lines.insert(0, error)
	hub.dialogue.open(spec["name"], lines, choices)

func _dialogue_closed() -> void:
	# Dialogue closes before emitting a choice; preserve the stable token until
	# that synchronous signal finishes, then clean up on the deferred boundary.
	call_deferred("_finish_closed_dialogue")

func _finish_closed_dialogue() -> void:
	if hub.dialogue.is_open: return
	state.end_talk(talking_id)
	talking_id = ""
	pending_token = ""
	kill_confirmation = false
	state.save()

func _choice_selected(choice: StringName) -> void:
	# Old saved UI callbacks cannot bypass the nonlethal life owner.
	if choice in [&"pilot_ask_kill", &"pilot_cancel_kill", &"pilot_confirm_kill"]: return
	if not talking_id.is_empty() and state.records[talking_id]["mode"] in ["dead", "recovering"]:
		_offered_extension_choices.clear()
		# A stale modal callback reconciles its own room representation immediately;
		# cleanup must not depend on the next population process tick being enabled.
		_remove_withdrawn_actor(talking_id)
		hub.dialogue.close()
		return
	# A delayed living choice cannot outrank a new authoritative downed episode.
	if not talking_id.is_empty() and state.records[talking_id]["mode"] == "downed" and pending_token.is_empty():
		pending_token = state.decision_token(talking_id)
		kill_confirmation = false
		_relock()
		_open_dialogue(true)
		return
	if _offered_extension_choices.has(choice):
		if talking_id.is_empty() or not pending_token.is_empty() or state.records[talking_id]["mode"] != "talk" or not _offered_extension_choices[choice]["enabled"]: return
		var scope_id: StringName = _offered_extension_choices[choice]["namespace"]
		var handler: Callable = _dialogue_extensions[scope_id]["handler"]
		if not handler.is_valid(): return
		var response: Variant = handler.call(talking_id,choice)
		if response is Dictionary and response.get("handled",false):
			_relock()
			_open_dialogue(false,str(response.get("message","")))
		return
	if talking_id.is_empty() or not String(choice).begins_with("pilot_"): return
	var success: bool = true
	if choice == &"pilot_greet": success = state.greet(talking_id)
	elif choice == &"pilot_help":
		success = hub.economy.help_resident(state,talking_id)
		if success:
			_relock()
			_open_dialogue(false,"Đã lưu việc nhường vải. Người này ghi nhận; lựa chọn tiếp theo vẫn thuộc về bạn.")
			return
	elif choice in [&"pilot_withdraw", &"pilot_spare"]: success = state.decide(talking_id, pending_token, false)
	if not success:
		_relock()
		_open_dialogue(not pending_token.is_empty(), "Chưa lưu được quyết định. Trạng thái trước lựa chọn được giữ; hãy thử lại hoặc đóng để lui lại.")
		return
	if state.records[talking_id]["mode"] in ["dead", "recovering"]: _remove_withdrawn_actor(talking_id)

func _relock() -> void:
	hub.player.suspend_controls(true)
	(hub.gear.modal as InventoryScreen).open_button.hide()
	TimeScaleClaims.acquire(hub.dialogue, 0.1)

func _process(delta: float) -> void:
	if state.read_only:
		if not actors.is_empty(): clear_actors()
		if is_instance_valid(hub.prompt): hub.prompt.text = "Không thể khôi phục trạng thái cư dân từ hồ sơ này."
		return
	for id: String in actors.keys():
		if state.records[id]["mode"] in ["dead", "recovering"]:
			if id == talking_id and hub.dialogue.is_open:
				_offered_extension_choices.clear()
				hub.dialogue.close()
			_remove_withdrawn_actor(id)
	var playing: bool = hub.player.controls_enabled and not hub.station_open and not hub.dialogue.is_open and not hub.gear.modal.is_open and not get_tree().paused
	if playing:
		accumulator = minf(accumulator + delta, NpcWorldState.STEP * 8)
		while accumulator + 0.0000001 >= NpcWorldState.STEP:
			accumulator -= NpcWorldState.STEP
			state.advance_ticks(1)
		autosave_remaining -= delta
		if autosave_remaining <= 0:
			autosave_remaining = 30.0
			state.save()
	for actor: NpcPilotActor in actors.values():
		if is_instance_valid(actor):
			actor.social_activity = NpcSocialCatalog.definition(actor.stable_id).get("help_activity","") if NpcSocialProgress.helped(OpeningSocialRuntime.state(hub.profile),actor.stable_id) else ""
			actor.sync_record(playing, accumulator, delta)
	var near: String = nearest_id(PrologueHub.INTERACTION_RANGE)
	if not near.is_empty() and playing and hub.nearest_station() == StringName(near): hub.prompt.text = "E · %s · %s" % [NpcPilotCatalog.definition(near)["name"], NpcPilotCatalog.MODE_LABELS[state.records[near]["mode"]]]
	if not state.last_save_ok: hub.prompt.text += " · Chưa lưu được trạng thái NPC"

func _exit_tree() -> void:
	state.end_talk(talking_id)
	state.save()
	for actor: NpcPilotActor in actors.values():
		if is_instance_valid(actor): get_node("/root/AudioManager").stop_owner(actor)
	actors.clear()

func _checkpoint_cultivation_rest(id: String, mode: String) -> void:
	# This is the actual life owner, not the cultivation adapter. Checkpoint
	# only the sponsored exemplar entering rest; no copied life/death ledger.
	if not state.emitting_recovery and id=="pilot_gatherer" and mode=="rest" and hub.cultivation_session!=null and hub.profile.cultivation_progress.get("actors",{}).get(id,{}).get("enrolled",false): state.save()

func _courier_content(id: String, record: Dictionary) -> Dictionary:
	if id != "pilot_pilgrim" or hub.courier == null or record["mode"] != "talk" or not record["death"].is_empty(): return {}
	hub.courier.arm(&"pilgrim")
	return {"lines":hub.courier.lines(&"pilgrim"), "choices":hub.courier.choices(&"pilgrim")}

func _courier_action(id: String, choice: StringName) -> Dictionary:
	if id != "pilot_pilgrim" or hub.courier == null or hub.courier.context != &"pilgrim" or not pending_token.is_empty() or state.records[id]["mode"] != "talk": return {"handled":false}
	return hub.courier.apply_action(choice)
