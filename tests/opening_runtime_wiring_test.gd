extends SceneTree
## Actual product GameFlow/dialogue composition, with unique isolated saves.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const Spans = preload("res://scripts/runtime/profile_json_spans.gd")
const ID: String = "pilot_traveler"
var checks: int = 0
var failures: int = 0
var flow: GameFlow
var directory: String
var capture: bool = false
var captures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: " + label)

func _step(count: int = 4) -> void:
	for _index: int in count: await physics_frame

func _fixture(label: String, seed_value: int = 4) -> SanctuaryProfile:
	var value := SanctuaryProfile.new()
	value.save_path = directory + "/" + label + "/profile.json"
	value.souls = 25; value.material_stash[&"linen_fiber"] = 8
	value.material_stash[&"dust"] = 10; value.material_stash[&"crystal"] = 20
	_check(value.save(), label + ": durable isolated format1 fixture")
	_check(value.commit_cultivation(Model.initial_proposal(Model.new_progress(seed_value),value.material_stash,value.souls,value.boss_proofs)), label + ": canonical format2 initialized")
	return value

func _open(path: String) -> ExteriorHub:
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path; root.add_child(flow); current_scene = flow
	await _step(10)
	var hub: ExteriorHub = flow.active_scene as ExteriorHub
	if hub != null and hub.npc_population != null: hub.npc_population.set_process(false)
	return hub

func _cleanup() -> void:
	flow.queue_free(); await _step(6); flow = null
	_check(is_equal_approx(Engine.time_scale,1.0), "Product teardown releases all modal claims")

func _finish_pages(dialogue: DialogueBox) -> void:
	for _index: int in 24:
		if not dialogue.is_open or (not dialogue.is_typing() and dialogue.page_index == dialogue.pages.size()-1): return
		dialogue.advance()

func _choose(hub: ExteriorHub, id: StringName, confirm: bool = false) -> void:
	_finish_pages(hub.dialogue)
	hub.dialogue.select_choice(id)
	if confirm:
		_check(hub.dialogue.pending_choice == id, "Real confirmation is required for " + String(id))
		hub.dialogue.confirm_choice()
	await _step()

func _has(dialogue: DialogueBox, id: StringName) -> bool:
	for row: Dictionary in dialogue.choices:
		if StringName(row.get("id","")) == id: return true
	return false

func _key(code: Key) -> void:
	var event := InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = true
	root.push_input(event,true); await _step(2)
	event = InputEventKey.new(); event.physical_keycode = code; event.keycode = code; event.pressed = false
	root.push_input(event,true); await _step(2)

func _run() -> void:
	capture = OS.get_cmdline_user_args().has("--capture")
	if capture:
		if DisplayServer.get_name() == "headless": print("FAIL: Runtime images require an assigned renderer"); quit(2); return
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(1280,720)
		DisplayServer.window_set_title("Dungeon Resonance · Product social/courier QA")
		AudioServer.set_bus_mute(0,true)
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="): Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: Product runtime QA requires isolated user data"); quit(2); return
	directory = "user://verification/runtime_wiring_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	await _product_social_and_courier()
	await _product_cold_recovery()
	await _product_migration_and_quarantine()
	print("RESULT OpeningRuntimeWiring checks=%d failures=%d hz=%d captures=%d" % [checks,failures,Engine.physics_ticks_per_second,captures])
	quit(0 if failures == 0 else 1)

func _shot(tag: String) -> void:
	if not capture: return
	_finish_pages((flow.active_scene as ExteriorHub).dialogue)
	await _step(4); await RenderingServer.frame_post_draw
	var destination: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").replace("\\","/") + "/product_runtime"
	DirAccess.make_dir_recursive_absolute(destination)
	var picture: Image = root.get_texture().get_image()
	_check(not picture.is_empty() and picture.save_png(destination + "/" + tag + ".png") == OK, "Actual product viewport saved: " + tag)
	captures += 1

func _product_social_and_courier() -> void:
	# Seed57 has both existing authored herb sources under unchanged tuning.
	# Other recovery/migration fixtures keep their previous seed4 and costs.
	var fixture: SanctuaryProfile = _fixture("product",57)
	var hub: ExteriorHub = await _open(fixture.save_path)
	_check(hub != null and flow.profile.social_transactions_available() and hub.courier != null, "Actual main scene enables reviewed social and courier owners")
	if hub == null: await _cleanup(); return
	var actor_id: int = hub.player.get_instance_id()
	var ledger: Dictionary = GearInventoryCodec.encode(hub.gear.inventory)
	_check(hub.enter_exterior(&"o01_p01"), "Product travels to the actual social resident room")
	await _step()
	var pop: NpcPopulation = hub.npc_population
	var life: NpcWorldState = pop.state
	hub.player.relocate(pop.actors[ID].global_position + Vector2(-20,0)); await _step()
	_check(pop.interact(ID) and _has(hub.dialogue,&"pilot_help"), "Living resident offers reviewed cloth alternative through real dialogue")
	var npc_bytes: PackedByteArray = FileAccess.get_file_as_bytes(life.save_path)
	await _choose(hub,&"pilot_help",true)
	_check(flow.profile.material_stash[&"linen_fiber"] == 6 and NpcSocialProgress.helped(OpeningSocialRuntime.state(flow.profile),ID), "Confirmation commits exactly two cloth and one canonical life receipt")
	_check(FileAccess.get_file_as_bytes(life.save_path) == npc_bytes, "Social commit does not rewrite the NPC primary sidecar")
	await _shot("social_help_committed")
	pop._choice_selected(&"pilot_help")
	_check(flow.profile.material_stash[&"linen_fiber"] == 6, "Duplicate living callback cannot pay the social cost twice")
	hub.dialogue.close(); await _step()
	_check(hub.return_to_hub(), "Product retains the same actor and gear when returning")
	await _step()
	_check(hub.open_npc(NpcCatalog.HEALER,"",true) and _has(hub.dialogue,&"courier_accept"), "Thanh Vy exposes the canonical optional supply offer")
	await _shot("healer_supply_offer")
	await _choose(hub,&"courier_accept")
	_check(flow.profile.courier_objectives().get("accepted",false), "Real healer callback records one canonical offer")
	hub.dialogue.close(); await _step()
	_check(hub.enter_exterior(&"o01_p03"), "Product travels to the real shrine contact")
	await _step()
	hub.player.relocate(pop.actors["pilot_pilgrim"].global_position + Vector2(-20,0)); await _step()
	_check(pop.interact("pilot_pilgrim") and _has(hub.dialogue,&"courier_contact"), "Living pilgrim composes namespaced courier choices with social dialogue")
	life.receive_hit("pilot_pilgrim",1.0,hub.player.global_position.x)
	pop._choice_selected(&"courier_contact")
	await _step()
	_check(not hub.dialogue.is_open and not pop.actors.has("pilot_pilgrim") and hub.player.controls_enabled, "New withdrawal closes stale living choices and releases the dialogue lock")
	_check(not flow.profile.courier_objectives()["contact_recorded"], "Withdrawn callback cannot record a courier contact")
	pop._choice_selected(&"pilot_ask_kill")
	pop._choice_selected(&"pilot_confirm_kill")
	_check(life.records["pilot_pilgrim"]["mode"] == "recovering" and life.records["pilot_pilgrim"]["death"].is_empty() and not pop.actors.has("pilot_pilgrim"), "Legacy execution callbacks cannot turn withdrawal into permanent death")
	var tombstone: PackedByteArray = FileAccess.get_file_as_bytes(life.save_path)
	hub.player.relocate(ExteriorHub.ORIGIN + hub.exterior.interactions[&"shrine"]); await _step()
	_check(hub.open_courier_register() and _has(hub.dialogue,&"courier_contact"), "Stationary shrine remains a real fallback while the contact recovers")
	await _choose(hub,&"courier_contact")
	_check(flow.profile.courier_objectives()["contact_source"] == "shrine" and _has(hub.dialogue,&"courier_help"), "Shrine contact advances the same canonical choice")
	var dust: int = flow.profile.material_stash[&"dust"]
	var linen: int = flow.profile.material_stash[&"linen_fiber"]
	var souls: int = flow.profile.souls
	await _choose(hub,&"courier_help",true)
	_check(flow.profile.material_stash[&"dust"] == dust-1 and flow.profile.material_stash[&"linen_fiber"] == linen and flow.profile.souls == souls, "Supply confirmation spends one dust, zero social cloth and zero Souls")
	_check(flow.profile.courier_choice_event().get("source_id") == "p03_shrine_register" and FileAccess.get_file_as_bytes(life.save_path) == tombstone, "Courier event identifies the register and leaves withdrawal evidence intact")
	await _shot("shrine_supply_committed_during_recovery")
	var committed: PackedByteArray = FileAccess.get_file_as_bytes(flow.profile.save_path)
	_check(hub.courier.apply_action(&"courier_help")["success"] and not hub.courier.apply_action(&"courier_prepare")["success"] and FileAccess.get_file_as_bytes(flow.profile.save_path) == committed, "Replay stays read-only and the other supply outcome remains blocked")
	hub.dialogue.close(); await _step()
	await _key(KEY_M)
	var modal: InventoryScreen = hub.gear.modal as InventoryScreen
	_check(modal.is_open and modal.tabs.current_tab == 2 and not hub.player.controls_enabled, "Actual M input opens one unified MapQuest modal")
	await _shot("product_map_modal")
	var progress: Dictionary = flow.profile.cultivation_progress.duplicate(true)
	for key: Key in [KEY_G,KEY_F,KEY_BACKSPACE,KEY_E]: await _key(key)
	flow.cultivation_session._physics_process(600.0)
	_check(GearInventoryCodec.encode(hub.gear.inventory) == ledger and flow.profile.cultivation_progress == progress, "Map shortcuts preserve the exact gear/rune ledger and freeze cultivation")
	await _key(KEY_ESCAPE)
	_check(not modal.is_open and hub.player.controls_enabled and is_equal_approx(Engine.time_scale,1.0), "Map closes through real input and restores its single claim")
	_check(hub.player.get_instance_id() == actor_id, "All composition keeps the same product player")
	_check(hub.return_to_hub(), "Canonical product profile returns to its existing services")
	await _step()
	hub.player.relocate(hub.stations[&"training"].global_position); await _step()
	hub.open_station(&"training")
	_check(hub.station_content.columns == 1 and hub.station_content.find_child("CultivationStartPlayer",true,false) != null, "Actual product cultivation panel fits the shared Container as one column")
	await _shot("product_training_panel")
	hub.close_station()
	# Controlled positive stock must include its canonical lineage origins;
	# directly assigning bank counts would invalidate the common format2 codec.
	var lineage_dust_before: int = flow.profile.material_stash[&"dust"]
	for node_id: String in Model.NODE_IDS:
		var harvest_event: String = "cult_%d" % int(flow.profile.cultivation_progress["next_event"])
		var harvest: Dictionary = Model.propose(flow.profile.cultivation_progress,flow.profile.material_stash,flow.profile.souls,flow.profile.boss_proofs,"harvest",{"node_id":node_id},harvest_event)
		_check(flow.profile.commit_cultivation(harvest), "Controlled stash fixture commits real origin/stock together: " + node_id)
	var pill_event: String = "cult_%d" % int(flow.profile.cultivation_progress["next_event"])
	var pill: Dictionary = Model.propose(flow.profile.cultivation_progress,flow.profile.material_stash,flow.profile.souls,flow.profile.boss_proofs,"craft_pill",{"origin_id":Model.NODE_IDS[0]},pill_event)
	_check(flow.profile.commit_cultivation(pill) and flow.profile.material_stash[&"aptitude_herb"] == 1 and flow.profile.material_stash[&"aptitude_pill"] == 1 and flow.profile.material_stash[&"dust"] == lineage_dust_before-2 and Model.valid(flow.profile.cultivation_progress,flow.profile.material_stash), "Controlled positive lineage rows use actual harvest/craft receipts and exact two-dust cost")
	hub.open_station(&"stash"); await _step()
	_check(hub.station_content.columns == 2 and flow.profile.profile_version == 2, "Two-column stash uses the actual common format2 owner")
	var lineage_before: Dictionary = flow.profile.material_stash.duplicate()
	var lineage_carried_before: Dictionary = hub.gear.inventory.materials.duplicate()
	var lineage_bytes: PackedByteArray = FileAccess.get_file_as_bytes(flow.profile.save_path)
	for id: StringName in [&"aptitude_herb",&"aptitude_pill"]:
		var row: Button = hub.station_content.find_child("WithdrawMaterial_"+String(id),true,false) as Button
		_check(row != null and row.disabled and row.get_signal_connection_list("pressed").is_empty(), "Lineage-bound product stash row has no transfer callback: " + String(id))
		if row != null: row.pressed.emit()
	_check(flow.profile.material_stash == lineage_before and hub.gear.inventory.materials == lineage_carried_before and FileAccess.get_file_as_bytes(flow.profile.save_path) == lineage_bytes, "Forced lineage UI presses preserve banked/carried counts and exact canonical save bytes")
	await _shot("product_stash_v2")
	hub.close_station()
	await _cleanup()
	hub = await _open(fixture.save_path)
	_check(NpcSocialProgress.helped(OpeningSocialRuntime.state(flow.profile),ID) and flow.profile.material_stash[&"linen_fiber"] == 6 and flow.profile.courier_objectives()["outcome"] == "help", "Cold product scene retains both canonical receipts and their exact costs")
	_check(hub.npc_population.state.records["pilot_pilgrim"]["mode"] == "recovering" and not hub.npc_population.actors.has("pilot_pilgrim"), "Cold product load does not prematurely restore its withdrawn contact")
	await _cleanup()

func _product_cold_recovery() -> void:
	for point: String in ["after_candidate","after_decision","after_old_rename","after_commit"]:
		var fixture: SanctuaryProfile = _fixture(point)
		var runtime := OpeningSocialRuntime.new(); _check(runtime.configure(fixture), "Product registration is trusted before pending recovery")
		var life := NpcWorldState.new(); life.save_path = fixture.save_path + ".npc_v1.json"
		_check(life.save(), "Actual schema3 primary is durable before interrupted social commit")
		fixture._writer.fault_plan = {point:true}
		_check(not OpeningSocialRuntime.help(fixture,life,ID), point + ": caller does not publish interrupted success")
		var npc_bytes: PackedByteArray = FileAccess.get_file_as_bytes(life.save_path)
		var hub: ExteriorHub = await _open(fixture.save_path)
		var recovered: bool = point != "after_candidate"
		_check(not flow.profile.read_only and flow.profile.social_transactions_available(), point + ": actual GameFlow registers the reader before cold load")
		_check(flow.profile.material_stash[&"linen_fiber"] == (6 if recovered else 8) and NpcSocialProgress.helped(OpeningSocialRuntime.state(flow.profile),ID) == recovered, point + ": product cold recovery keeps debit and receipt together")
		_check(FileAccess.get_file_as_bytes(hub.npc_population.state.save_path) == npc_bytes, point + ": recovery preserves the actual life owner")
		await _cleanup()

func _write(fixture: SanctuaryProfile, text: String) -> void:
	_check(fixture.save_path.begins_with(directory+"/"), "Raw test writes stay within this unique fixture")
	var file: FileAccess = FileAccess.open(fixture.save_path,FileAccess.WRITE)
	file.store_string(text); file.flush(); _check(file.get_error() == OK, "Raw fixture is durable"); file.close()

func _product_migration_and_quarantine() -> void:
	for kind: String in ["legacy_social","legacy_courier","future_social","duplicate_social","future_courier"]:
		var fixture: SanctuaryProfile = _fixture(kind)
		var payload: Dictionary = Writer.read_json(fixture.save_path)
		var path: Array[String] = []
		var span: String = ""
		if kind == "legacy_social":
			payload["npc_social_progress"] = NpcSocialProgress.with_help(NpcSocialProgress.empty(),ID,NpcWorldState.life_id(ID))
		elif kind == "legacy_courier":
			payload["courier_opportunity"] = {"version":1,"accepted":true,"contact_recorded":true,"contact_source":"shrine","outcome":"help"}
		elif kind == "future_courier":
			payload["event_extensions"] = {"schema_version":1,"namespaces":{"courier":{"revision":0,"state":{"version":99,"future":"keep me"},"receipts":[]}}}
		elif kind == "future_social":
			span = " \n{\"revision\":0,\"state\":{\"schema_version\":99,\"receipts\":{}},\"receipts\":[]} \t"
			payload["event_extensions"] = {"schema_version":1,"namespaces":{"npc_social":JSON.parse_string(span)}}
			path.assign(["event_extensions","namespaces","npc_social"])
		else:
			span = "{\"schema_version\":1,\"receipts\":{\"pilot_traveler\":{\"life_id\":\"pilot_traveler:opening:1\",\"event_id\":\"ambiguous\",\"event_id\":\"pilot_traveler:opening:1:help:linen:1\"}}}"
			payload["npc_social_progress"] = JSON.parse_string(span); path.assign(["npc_social_progress"])
		var text: String = Writer.canonical(Writer.sealed(payload,2))
		if not span.is_empty(): text = Spans.replace(text,path,span)
		_write(fixture,text)
		var hub: ExteriorHub = await _open(fixture.save_path)
		_check(not flow.profile.read_only and flow.profile.material_stash[&"linen_fiber"] == 8 and flow.profile.material_stash[&"dust"] == 10, kind + ": product load does not repay old costs")
		if kind == "legacy_social":
			_check(flow.profile.social_transactions_available() and NpcSocialProgress.helped(OpeningSocialRuntime.state(flow.profile),ID) and not Writer.read_json(flow.profile.save_path).has("npc_social_progress"), "Actual GameFlow migrates social once with no authoritative root mirror")
		elif kind == "legacy_courier":
			_check(flow.profile.courier_objectives()["outcome"] == "help" and not Writer.read_json(flow.profile.save_path).has("courier_opportunity"), "Actual GameFlow migrates the old supply result to one namespace")
		elif kind == "future_courier":
			_check(not hub.courier.objectives()["available"] and flow.profile.try_add_souls(1) and Writer.read_json(flow.profile.save_path)["event_extensions"]["namespaces"]["courier"] == payload["event_extensions"]["namespaces"]["courier"], "Future courier is disabled in the product UI while ordinary saves preserve its unknown state")
		else:
			_check(not flow.profile.social_transactions_available() and flow.profile.try_add_souls(1) and Spans.extract(FileAccess.get_file_as_string(flow.profile.save_path),path).get("span") == span, kind + ": only social is quarantined and an unrelated save preserves every evidence byte")
		await _cleanup()
