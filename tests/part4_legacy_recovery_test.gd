extends "res://tests/tan_dang_compound_writer_test.gd"
## Only an explicitly seeded synthetic pending NPC5 fixture is read.
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	var path: String="user://verification/part4_legacy/pending/profile.json"
	if not FileAccess.file_exists(path+".decision"):print("FAIL: missing generated NPC5 QA fixture");quit(2);return
	var npc_path: String=path+".npc_v1.json"
	var expected_profile: PackedByteArray=FileAccess.get_file_as_bytes(path+".tmp")
	var expected_npc: PackedByteArray=FileAccess.get_file_as_bytes(npc_path+".compound.tmp")
	_check(JSON.parse_string(expected_npc.get_string_from_utf8())["npc_schema"]==5,"Fixture really uses historical NPC5 candidate bytes")
	var fixture: Dictionary=_cold(path)
	var profile: SanctuaryProfile=fixture["profile"];var npc: NpcWorldState=fixture["npc"]
	_check(fixture["loaded"] and not profile.read_only and not npc.read_only,"Current writer recovers old decided pair before life migration")
	_check(FileAccess.get_file_as_bytes(path)==expected_profile,"Recovery installs exact original sealed profile candidate without rewriting")
	_check(npc.snapshot()["npc_schema"]==NpcWorldState.SCHEMA and FileAccess.get_file_as_bytes(npc_path+".pre_causality_v5.json")==expected_npc,"Migration preserves the recovered NPC5 candidate byte-for-byte")
	_check(profile.extension_state(SCOPE)["choice"]=="gate" and npc.records[DU]["mode"]=="dead" and npc.records[DU]["death"]["killer_id"]=="core_reclaimed","Quest choice/contribution and terminal life remain one decision")
	_check(not FileAccess.file_exists(path+".decision") and not FileAccess.file_exists(npc_path+".compound.tmp"),"Original recovery cleans its intent only after both participants verify")
	var before: PackedByteArray=FileAccess.get_file_as_bytes(path)
	var cold: Dictionary=_cold(path)
	_check(cold["loaded"] and FileAccess.get_file_as_bytes(path)==before and (cold["npc"] as NpcWorldState).records[DU]==npc.records[DU],"Another cold load cannot replay grant, resurrection or migration")
	print("RESULT Part4LegacyRecovery checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
