extends "res://tests/tan_dang_flow_test.gd"
## Native presentation only. Canonical quest commands below are explicit setup;
## product E, page reveal, choices and render tree remain real.
func _run() -> void:
	capture = "--native-approved" in OS.get_cmdline_user_args()
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not capture or DisplayServer.get_name() == "headless" or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		quit(2); return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(1280,720)
	AudioServer.set_bus_mute(0,true)
	prefix = "user://verification/tan_presentation_%d" % Time.get_ticks_usec()
	path = prefix+"_gate.json"
	await _open()
	hub = flow.active_scene as ExteriorHub
	await _at(TanDangJourney.LAMP)
	await _picture("hub_weak_clean_labels")
	await _prepare("gate")
	_check(hub.tan_dang.progress.apply("install_core","","lamp").get("ok",false),"Fixture installs carried core through canonical transaction")
	hub.npc_population.refresh_actors()
	await _step(4)
	await _picture("hub_lit_clean_labels")
	await _close()
	path = prefix+"_rescue.json"
	await _open()
	hub = flow.active_scene as ExteriorHub
	await _prepare("rescue")
	hub.npc_population.refresh_actors()
	await _at(TanDangJourney.LAMP)
	await _picture("hub_broken_clean_labels")
	await _at(StringName(TanDangProgress.LAM))
	await _key(root,KEY_E)
	_reveal()
	await _step(4)
	_check(hub.dialogue.choice_list.get_node_or_null("Choice_td_assist") != null,"Grateful living NPC exposes real assistance choice")
	await _picture("gratitude_assistance_dialogue")
	await _close_dialogue()
	var id: String = TanDangProgress.DU
	_check(hub.npc_population.state.receive_hit(id,1.0,1400.0),"Fixture downs through canonical owner")
	_check(hub.npc_population.state.decide(id,hub.npc_population.state.decision_token(id),true,true),"Fixture confirms execution through canonical owner")
	hub.npc_population.refresh_actors()
	await _at(TanDangJourney.LEDGER)
	await _key(root,KEY_E)
	_reveal()
	await _step(4)
	_check(hub.dialogue.text_label.text.contains("Đã chết vĩnh viễn") and hub.dialogue.text_label.text.contains("Cáo thị truy cứu"),"Rendered ledger page exposes canonical victim and murder notice")
	_check(hub.dialogue.text_label.text.contains("trợ giúp chấm dứt") and not hub.dialogue.text_label.text.contains("có thể xin giúp"),"Dead grateful victim retains history without promising assistance")
	await _picture("murder_notice_ledger_full_text")
	await _close_dialogue()
	await _close()
	print("RESULT tan_dang_presentation checks=%d failures=%d captures=5" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _prepare(branch: String) -> void:
	var model: TanDangProgress = hub.tan_dang.progress
	for action: String in ["accept","observe_lamp","find_lam","inspect_core","q1_reward","choice_"+branch]:
		var place: String = "ledger" if action == "accept" else "lamp" if action == "observe_lamp" else "refuge"
		_check(model.apply(action,"",place).get("ok",false),"Canonical presentation setup "+action)

func _reveal() -> void:
	for index: int in 40:
		if not hub.dialogue.is_typing() and hub.dialogue.page_index == hub.dialogue.pages.size()-1: break
		hub.dialogue.advance()
