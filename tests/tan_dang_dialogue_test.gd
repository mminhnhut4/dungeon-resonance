extends "res://tests/tan_dang_quest_test.gd"
## Presentation reads the real isolated quest and life owners without writing.

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: dedicated QA data root required"); quit(2); return
	directory = "user://verification/tan_dang_dialogue_%d_%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	_initial_and_gate()
	_spared_gratitude_without_story()
	_rescue_and_reconciliation()
	_harm_before_rescue()
	_unreported_murder()
	_rescue_then_death()
	print("RESULT tan_dang_dialogue checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)

func _view(progress: TanDangProgress, id: StringName) -> TanDangJourney:
	var journey := TanDangJourney.new()
	journey.progress = progress
	journey.context = id
	return journey

func _says(lines: Array, words: String) -> bool:
	var spoken: String = ""
	for line: Variant in lines: spoken += str(line)+" "
	return spoken.contains(words)

func _row(progress: TanDangProgress, id: StringName) -> String:
	for row: Dictionary in TanDangProgress.rows(progress.profile):
		if row["id"] == id: return row["body"]
	return ""

func _read_only(progress: TanDangProgress, journey: TanDangJourney) -> void:
	var quest_before: Dictionary = progress.state()
	var npc_before: Dictionary = progress.life.snapshot()
	var profile_bytes: PackedByteArray = _raw(progress.profile.save_path)
	var npc_bytes: PackedByteArray = _raw(progress.life.save_path)
	var spoken: Array[String] = journey._speaker_lines()
	_check(not spoken.is_empty(),"Speaker pages satisfy the real DialogueBox typed-array contract")
	journey._karma_lines(); journey.relation_rows(); TanDangProgress.rows(progress.profile)
	_check(progress.state() == quest_before and progress.life.snapshot() == npc_before and _raw(progress.profile.save_path) == profile_bytes and _raw(progress.life.save_path) == npc_bytes,"Dialogue and journal reads do not change owners or save bytes")

func _initial_and_gate() -> void:
	var progress: TanDangProgress = _fixture("gate_words")
	var journey: TanDangJourney = _view(progress,TanDangJourney.LEDGER)
	_check(_says(journey._speaker_lines(),"nhận việc") and _row(progress,&"tan_dang_q1").contains("Tiếp theo"),"Unmet quest speaks as an open ledger and gives a first step")
	journey.context = StringName(TanDangProgress.MOC)
	_check(_says(journey._speaker_lines(),"Giữ cổng cũng là giữ chỗ trú") and not _says(journey._speaker_lines(),"Ta nhớ việc ngươi"),"Mộc Yên explains the gate without inventing a prior meeting")
	_read_only(progress,journey)
	_q1(progress)
	_check(_row(progress,&"tan_dang_q1").contains("Đã khép") and _row(progress,&"tan_dang_q2").contains("Không có đếm ngược"),"Journal records the completed investigation and the unmade choice")
	var quest_bytes: PackedByteArray = _raw(progress.profile.save_path)
	var npc_bytes: PackedByteArray = _raw(progress.life.save_path)
	journey.context = TanDangJourney.REFUGE
	journey._speaker_lines(); TanDangProgress.rows(progress.profile)
	_check(progress.state()["choice"] == "" and _raw(progress.profile.save_path) == quest_bytes and _raw(progress.life.save_path) == npc_bytes,"Reading the two consequences before confirmation leaves choice and bytes unchanged")
	_apply(progress,"choice_gate","refuge")
	journey.context = StringName(TanDangProgress.DU)
	_check(not progress.alive(TanDangProgress.DU) and not _says(journey._speaker_lines(),"Ta còn sống") and _says(journey._karma_lines(TanDangProgress.DU),"chết khi lõi"),"Gate death has no living Dư Hành speech or aid path")
	_unchanged_rejection(progress,"assist",TanDangProgress.DU,TanDangProgress.DU)
	_check(_row(progress,&"tan_dang_q2").contains("Đã chọn giữ cổng") and _row(progress,&"tan_dang_q3").contains("Đã thu lõi") and not _row(progress,&"tan_dang_q3").contains("Đã mang lõi về"),"Gate journal records the choice without claiming the core already reached the hub")
	journey.context = StringName(TanDangProgress.MOC)
	_apply(progress,"install_core","lamp")
	_check(_says(journey._speaker_lines(),"cái giá") and _row(progress,&"tan_dang_q2").contains("đèn sáng"),"Mộc Yên acknowledges the price after the lamp is restored")
	_unchanged_rejection(progress,"choice_gate","refuge")
	_read_only(progress,journey)
	_kill(progress,TanDangProgress.MOC)
	_kill(progress,TanDangProgress.LAM)
	var fallback: Array[Dictionary] = []
	journey._quest_choices(fallback,progress.state(),"ledger")
	_check(fallback.any(func(choice: Dictionary) -> bool: return choice["text"] == "Sổ · Ghi phần báo cáo Mộc Yên"),"Dead recipient is represented by the ledger's own report label")
	_finish(progress)
	_check(progress.state()["rewards"].has("q3") and _row(progress,&"tan_dang_q3").contains("Đã khép việc"),"All-dead ledger path keeps the final progress reward and past-tense journal")
	_unchanged_rejection(progress,"q3_reward","ledger")
	journey.free()

func _spared_gratitude_without_story() -> void:
	var moc: TanDangProgress = _fixture("moc_spare_words")
	_check(moc.life.receive_hit(TanDangProgress.MOC,1.0,900.0,false) and moc.life.decide(TanDangProgress.MOC,moc.life.decision_token(TanDangProgress.MOC),false) and moc.life.recover_after_expedition(),"Non-player injury and mercy give living Mộc Yên gratitude without a core choice")
	var moc_line: String = TanDangJourney._aid_offer_line(TanDangProgress.MOC,moc.state(),moc.life.karma(TanDangProgress.MOC))
	_check(moc.life.karma(TanDangProgress.MOC)["gratitude"] > 0 and moc_line.contains("dừng tay") and not moc_line.contains("đem lõi"),"Mộc Yên's aid line does not invent a gate decision")
	var lam: TanDangProgress = _fixture("lam_spare_words")
	_q1(lam); _apply(lam,"choice_gate","refuge")
	_check(lam.life.receive_hit(TanDangProgress.LAM,1.0,1300.0,false) and lam.life.decide(TanDangProgress.LAM,lam.life.decision_token(TanDangProgress.LAM),false) and lam.life.recover_after_expedition(),"Non-player injury and mercy give Lâm Tước gratitude after a gate choice")
	var lam_line: String = TanDangJourney._aid_offer_line(TanDangProgress.LAM,lam.state(),lam.life.karma(TanDangProgress.LAM))
	_check(lam.life.karma(TanDangProgress.LAM)["gratitude"] > 0 and lam_line.contains("dừng tay") and not lam_line.contains("cùng em chọn cứu"),"Lâm Tước's aid line does not replace the gate branch with rescue")

func _rescue_and_reconciliation() -> void:
	var progress: TanDangProgress = _fixture("rescue_words")
	_q1(progress); _apply(progress,"choice_rescue","refuge")
	var journey: TanDangJourney = _view(progress,StringName(TanDangProgress.DU))
	_check(_says(journey._speaker_lines(),"Ta còn sống") and _says(journey._speaker_lines(),"đèn cổng đã mất"),"Living Dư Hành remembers the consumed core and damaged gate")
	_check(_row(progress,&"tan_dang_q2").contains("Đã tiêu lõi") and not _row(progress,&"tan_dang_q2").contains("còn sống"),"Profile-only journal records rescue without assuming current life")
	var linen: int = int(progress.profile.material_stash.get(&"linen_fiber",0))
	_apply(progress,"assist",TanDangProgress.DU,TanDangProgress.DU)
	_check(int(progress.profile.material_stash.get(&"linen_fiber",0)) == linen + 2 and progress.life.karma(TanDangProgress.DU)["assistance_used"],"Existing aid commits exactly two linen once")
	_unchanged_rejection(progress,"assist",TanDangProgress.DU,TanDangProgress.DU)
	progress = _cold(progress); journey.progress = progress
	_check(_says(journey._karma_lines(TanDangProgress.DU),"Đã nhận 2 Sợi Vải Lanh"),"Cold journal remembers an aid grant already delivered")
	_check(progress.life.receive_hit(TanDangProgress.DU,1.0,1300.0,true),"Real owner records later player injury")
	_check(progress.life.decide(TanDangProgress.DU,progress.life.decision_token(TanDangProgress.DU),false),"Real owner records mercy without clearing injury")
	_check(_says(journey._speaker_lines(),"vết thương ngươi gây") and not _says(journey._speaker_lines(),"Ta còn sống"),"Spared injured recipient remembers harm before earlier gratitude")
	_check(_says(journey._karma_lines(TanDangProgress.DU),"dưỡng thương") and not _says(journey._karma_lines(TanDangProgress.DU),"Tiếp theo: gặp người này, E"),"Recovery step precedes any peace offer")
	_check(progress.life.recover_after_expedition(),"Saved expedition recovery restores the same living person")
	_check(_says(journey._karma_lines(TanDangProgress.DU),"Hoàn tất Nhận phần trách nhiệm") and not _says(journey._karma_lines(TanDangProgress.DU),"Tiếp theo: để người này"),"Recovered person now points to unfinished responsibility")
	_finish(progress)
	_check(progress.can_reconcile(TanDangProgress.DU) and _says(journey._speaker_lines(),"ngươi muốn đình chiến"),"Eligible person can hear an apology without claiming peace already happened")
	var before: PackedByteArray = _raw(progress.life.save_path)
	journey._speaker_lines(); journey._karma_lines(TanDangProgress.DU)
	_check(_raw(progress.life.save_path) == before and not progress.life.records[TanDangProgress.DU]["causality"]["reconciled"],"Reading an apology offer does not confirm peace")
	_apply(progress,"reconcile",TanDangProgress.DU,TanDangProgress.DU)
	_check(_says(journey._speaker_lines(),"Ta đã nhận lời dừng tay") and not _says(journey._karma_lines(TanDangProgress.DU),"Tiếp theo: gặp người này, E"),"Committed peace preserves rescue and injury without a second offer")
	_check(progress.life.receive_hit(TanDangProgress.DU,NpcPilotCatalog.maximum_health(TanDangProgress.DU)-1.0,1300.0,true),"Real owner records renewed harm")
	_check(_says(journey._speaker_lines(),"không nhận thêm") and _says(journey._karma_lines(TanDangProgress.DU),"Cơ hội hòa giải một lần đã hết"),"Reoffense ends the one peace chance in speech and journal")
	_read_only(progress,journey)
	journey.free()

func _harm_before_rescue() -> void:
	var progress: TanDangProgress = _fixture("harm_first_words")
	_check(progress.life.receive_hit(TanDangProgress.DU,NpcPilotCatalog.maximum_health(TanDangProgress.DU)-1.0,1300.0,true),"Player injury predates the core decision in a real owner fixture")
	_q1(progress); _apply(progress,"choice_rescue","refuge")
	var journey: TanDangJourney = _view(progress,StringName(TanDangProgress.DU))
	var words: Array[String] = journey._speaker_lines()
	_check(progress.life.karma(TanDangProgress.DU)["rescued"] and progress.life.records[TanDangProgress.DU]["causality"]["harmed"] and _says(words,"cứu mạng ta, cũng đã làm ta bị thương") and not _says(words,"Rồi"),"Harm before rescue preserves both facts without inventing their order")
	journey.free()

func _unreported_murder() -> void:
	var progress: TanDangProgress = _fixture("unknown_murder_words")
	_q1(progress); _apply(progress,"choice_rescue","refuge")
	_check(progress.life.receive_hit(TanDangProgress.DU,1.0,1300.0,true),"Later victim downed for unreported murder fixture")
	var none: Array[String] = []
	_check(progress.life.decide(TanDangProgress.DU,progress.life.decision_token(TanDangProgress.DU),true,true,none),"Murder commits without nearby witness or report")
	var journey: TanDangJourney = _view(progress,StringName(TanDangProgress.MOC))
	_check(not journey._knows_victim(TanDangProgress.MOC,TanDangProgress.DU) and _says(journey._speaker_lines(),"chưa nhận được lời chứng") and not _says(journey._speaker_lines(),"sát hại người ấy"),"Mộc Yên does not learn a remote unreported murder from the player's ledger")
	journey.free()

func _rescue_then_death() -> void:
	var progress: TanDangProgress = _fixture("rescued_death_words")
	_q1(progress); _apply(progress,"choice_rescue","refuge")
	var journey: TanDangJourney = _view(progress,TanDangJourney.LEDGER)
	_check(progress.life.receive_hit(TanDangProgress.DU,1.0,1300.0,true),"Victim downed after rescue")
	var witnesses: Array[String] = [TanDangProgress.MOC]
	_check(progress.life.decide(TanDangProgress.DU,progress.life.decision_token(TanDangProgress.DU),true,true,witnesses),"Confirmed murder records a direct Mộc Yên witness")
	_check(_says(journey._speaker_lines(),"qua đời sau đó") and _says(journey._karma_lines(TanDangProgress.DU),"Bạn đã tiêu lõi cứu") and not _says(journey._karma_lines(TanDangProgress.DU),"Tiếp theo: gặp"),"Ledger keeps rescue history, later death, and no dead aid advice")
	journey.context = StringName(TanDangProgress.MOC)
	_check(_says(journey._speaker_lines(),"sát hại người ấy") and progress.life.records[TanDangProgress.DU]["causality"]["reports"].is_empty(),"Direct witness knows this murder without a public report")
	_check(progress.life.receive_hit(TanDangProgress.LAM,1.0,1300.0,true) and progress.life.decide(TanDangProgress.LAM,progress.life.decision_token(TanDangProgress.LAM),true,true),"Second victim dies without this listener witnessing or receiving a report")
	_check(journey._knows_victim(TanDangProgress.MOC,TanDangProgress.DU) and not journey._knows_victim(TanDangProgress.MOC,TanDangProgress.LAM) and journey._known_murder_victim(TanDangProgress.MOC) == TanDangProgress.DU and not _says(journey._speaker_lines(),"Lâm Tước"),"Knowledge of one witnessed victim does not disclose a second victim")
	_check(_row(progress,&"tan_dang_q2").contains("Đã tiêu lõi") and not _row(progress,&"tan_dang_q2").contains("còn sống"),"Quest projection does not revive a later victim")
	_read_only(progress,journey)
	journey.free()
