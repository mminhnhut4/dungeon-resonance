extends "res://tests/tan_dang_compound_writer_test.gd"
## Execute against the frozen Part3 project to produce authentic NPC5 intent.
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or NpcWorldState.SCHEMA!=5:quit(2);return
	directory="user://verification/part4_legacy"
	var fixture: Dictionary=_fixture("pending")
	var profile: SanctuaryProfile=fixture["profile"];var npc: NpcWorldState=fixture["npc"]
	profile._writer.fault_plan={"compound_after_decision":true}
	var result: Dictionary=_commit(profile,npc,_gate(npc))
	_check(not result.get("ok",false) and FileAccess.file_exists(profile.save_path+".decision") and FileAccess.file_exists(npc.save_path+".compound.tmp"),"Frozen NPC5 writer leaves authentic decided compound participants")
	print("RESULT Part4LegacyNPC5Fixture checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
