extends "res://tests/tan_dang_living_state_test.gd"
## Explicit owner fixtures; dialogue facts/read-only contract, not native proof.
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not qa.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	directory="user://verification/living_copy_%d_%d"%[OS.get_process_id(),Time.get_ticks_usec()]
	var p: TanDangProgress=_ready("before_road","gate")
	var j:=TanDangJourney.new();j.progress=p;j.context=StringName(LAM)
	_check(p.life.start_living_event(p.state()),"Presentation fixture starts the real finite owner trip")
	var lines: Array[String]=j._living_lines(LAM,true)
	_check("\n".join(lines).contains("đang đi ra cửa") and not "\n".join(lines).contains("đã lên đường qua P01"),"Outbound text does not claim the NPC already reached P01")
	p=_danger("help_copy","gate");j.progress=p
	_check(p.life.credit_living_help(LAM) and p.life.resolve_living_event(LAM,"helped"),"Gate-branch NPC receives distinct real-owner event help")
	var aid: String=TanDangJourney._aid_offer_line(LAM,p.state(),p.life.karma(LAM),p.life.living_view(LAM))
	_check(aid.contains("con quái") and not aid.contains("dừng tay") and not aid.contains("chọn cứu"),"Event gratitude never invents mercy or the other core choice")
	var memory: Array[String]=j._living_memory_speech(LAM)
	_check("\n".join(memory).contains("Em sẽ mang") and not "\n".join(memory).contains("Em đã mang"),"Returning speech promises the remaining trip instead of claiming arrival")
	_check(j._living_memory_speech(DU).is_empty(),"A remote listener does not speak another person's event outcome")
	_home(p.life)
	_check("\n".join(j._living_memory_speech(LAM)).contains("Em đã mang"),"Finished home receipt permits past-tense event memory")
	_check(not j._living_lines(LAM,true)[0].contains("trước chuyến"),"Finished once-only trip returns to repair/rest without promising a nonexistent next event")
	var profile_bytes: PackedByteArray=_raw(p.profile.save_path);var npc_bytes: PackedByteArray=_raw(p.life.save_path);var before: Dictionary=p.life.snapshot()
	for _i: int in 4:
		j._living_lines(LAM,true);j._living_memory_speech(LAM);j._karma_lines();j.relation_rows()
	_check(_raw(p.profile.save_path)==profile_bytes and _raw(p.life.save_path)==npc_bytes and p.life.snapshot()==before,"Activity, memory and journal projections never write or acknowledge greeting")
	_check(p.life.receive_hit(LAM,NpcPilotCatalog.maximum_health(LAM)-1,1345,true),"Later actual owner harm is authoritative in dialogue fixture")
	_check(j._living_memory_speech(LAM).is_empty() and "\n".join(j._living_lines(LAM,true)).contains("ra tay chặn"),"Positive speech yields to harm while private history retains the actual earlier help")
	p=_danger("helped_retreat_copy","gate");j.progress=p
	_check(p.life.credit_living_help(LAM) and p.life.resolve_living_event(LAM,"withdrew"),"A real accepted assistance receipt can coexist with the NPC's withdrawal")
	var retreat_text: String="\n".join(j._living_lines(LAM,true))
	_check(retreat_text.contains("rút về giữ sức") and retreat_text.contains("Bạn đã ra tay lúc Lâm gặp nguy"),"History keeps both the actual withdrawal and help, without inventing victory")
	_check("\n".join(j._living_memory_speech(LAM)).contains("phải rút về giữ sức") and not "\n".join(j._living_memory_speech(LAM)).contains("đã mang"),"Assisted withdrawal speech does not claim a defeated monster or completed return")
	j.free()
	print("RESULT LivingPresentation checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
