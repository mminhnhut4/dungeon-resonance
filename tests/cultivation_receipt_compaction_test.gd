extends SceneTree
## Isolated CPU/save-contract proof; does not claim native frame-time or art QA.
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
var checks: int = 0
var failures: int = 0
var serial: int = 0

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func _fixture(count: int = 1024) -> SanctuaryProfile:
	serial += 1
	var profile := SanctuaryProfile.new()
	profile.save_path = "user://compaction_%d_%d.json" % [OS.get_process_id(),serial]
	profile.profile_version = 2
	profile.cultivation_progress = Model.new_progress(4)
	profile.cultivation_progress["actors"]["player"]["mastery"] = count
	profile.cultivation_progress["actors"]["player"]["energy"] = 17
	profile.cultivation_progress["actors"]["player"]["insight_ids"] = ["explored"]
	profile.cultivation_progress["revision"] = count
	profile.cultivation_progress["next_event"] = count + 1
	for index: int in count:
		profile.cultivation_progress["receipts"].append({"id":"cult_%d" % (index+1),"kind":"mastery","arguments_sha256":Writer.canonical({}).sha256_text(),"revision":index+1})
	profile.material_stash[&"crystal"] = 23
	profile.material_stash[&"dust"] = 11
	profile.souls = 51
	profile._retained_fields["unknown_extension"] = {"tag":"keep", "numeric":1.0000000000000002, "nested":[-2.25,7]}
	var payload: Dictionary = Writer.sealed(profile._export_payload(),42)
	var file := FileAccess.open(profile.save_path,FileAccess.WRITE)
	file.store_string(Writer.canonical(payload)); file.close()
	check(profile.load_profile() and not profile.read_only,"Load sealed legacy fixture %d" % serial)
	return profile

func _proposal(profile: SanctuaryProfile, event_id: String = "") -> Dictionary:
	var id: String = event_id if not event_id.is_empty() else "cult_%d" % profile.cultivation_progress["next_event"]
	return Model.propose(profile.cultivation_progress,profile.material_stash,profile.souls,profile.boss_proofs,"mastery",{},id)

func _backup(profile: SanctuaryProfile, original: PackedByteArray) -> String:
	return profile.save_path + ".cultivation_v1." + original.hex_encode().sha256_text() + ".bak"

func _preservation_and_replay() -> void:
	var profile: SanctuaryProfile = _fixture()
	var original: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
	var old_payload: Dictionary = Writer.read_json(profile.save_path)
	var old_progress: Dictionary = profile.cultivation_progress.duplicate(true)
	check(not _proposal(profile).get("ok",false),"Legacy 1024 history reproduces command capacity blocker")
	check(profile.compact_cultivation_receipts(),"Atomic migration succeeds from full legacy history")
	var compacted: Dictionary = profile.cultivation_progress
	check(Model.valid(compacted,profile.material_stash) and compacted["schema_version"]==2 and compacted["receipt_floor"]==1016 and compacted["receipts"].size()==8,"Bounded 8 receipts plus monotonic watermark validate")
	for field: String in ["actors","origins","harvested_nodes","config","seed","revision","next_event","gameplay_tick"]:
		check(Writer.canonical(compacted[field])==Writer.canonical(old_progress[field]),"Migration preserves earned field "+field)
	var disk: Dictionary = Writer.read_json(profile.save_path)
	check(Writer.seal_valid(disk) and disk["profile_commit"]["revision"]==43,"Same writer advances sealed profile transaction exactly once")
	old_payload.erase("cultivation_progress");old_payload.erase("profile_commit")
	disk.erase("cultivation_progress");disk.erase("profile_commit")
	check(Writer.canonical(old_payload)==Writer.canonical(disk),"All resources, opaque numeric data and other profile fields survive migration")
	var backup: String = _backup(profile,original)
	check(FileAccess.get_file_as_bytes(backup)==original,"Immutable backup is the exact full pre-migration file")
	var migrated_bytes: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
	check(profile.compact_cultivation_receipts() and FileAccess.get_file_as_bytes(profile.save_path)==migrated_bytes,"Repeated migration is no-op without revision or reward")
	var replay: Dictionary = _proposal(profile,"cult_1024")
	check(replay.get("already_committed",false) and profile.commit_cultivation(replay),"Recent identical receipt remains idempotent")
	var conflict: Dictionary = Model.propose(compacted,profile.material_stash,profile.souls,profile.boss_proofs,"observe",{"insight_id":"golem_defeated"},"cult_1024")
	check(conflict.get("error")=="event_conflict","Same recent ID with changed command is rejected")
	for id: String in ["cult_1","cult_1008","arbitrary_old","cult_1026","cult_01025"]:
		check(not _proposal(profile,id).get("ok",false),"Evicted, arbitrary or non-current event fails closed: "+id)
	var first: Dictionary = _proposal(profile)
	check(profile.commit_cultivation(first) and profile.cultivation_progress["actors"]["player"]["mastery"]==1025,"Previously blocked next event commits and preserves earned mastery")
	for _index: int in 18:
		check(profile.commit_cultivation(_proposal(profile)),"Additional durable command remains available beyond old cap")
	check(profile.cultivation_progress["receipts"].size()==8 and profile.cultivation_progress["receipt_floor"]==1035,"Receipt history remains bounded after repeated durable hits")
	check(not profile.commit_cultivation(first),"Evicted old proposal cannot replay through profile gate")
	var cold := SanctuaryProfile.new(); cold.save_path=profile.save_path
	check(cold.load_profile() and not cold.read_only and cold.cultivation_progress["actors"]["player"]["mastery"]==1043,"Cold reader restores schema2 and every committed gain")
	check(not _proposal(cold,"cult_1").get("ok",false) and not _proposal(cold,"cult_1025").get("ok",false),"Evicted receipts stay rejected after cold reload")
	check(FileAccess.get_file_as_bytes(backup)==original,"Later commits never rewrite migration backup")

func _failures_and_retry() -> void:
	for point: String in ["write_candidate","commit","after_decision","after_commit"]:
		var profile: SanctuaryProfile = _fixture(20)
		var original: PackedByteArray = FileAccess.get_file_as_bytes(profile.save_path)
		profile._writer.fault_plan={point:true}
		check(not profile.compact_cultivation_receipts() and profile.cultivation_progress["schema_version"]==1,point+": unsuccessful migration rolls RAM back")
		check(FileAccess.get_file_as_bytes(_backup(profile,original))==original,point+": original full-history backup remains intact")
		if point in ["write_candidate","commit"]:
			check(FileAccess.get_file_as_bytes(profile.save_path)==original and not profile.read_only,point+": definitive failure leaves old authority and retry available")
			check(profile.compact_cultivation_receipts(),point+": retry commits migration exactly once")
		else:
			check(profile.read_only,point+": uncertain commit blocks live owner")
		var cold := SanctuaryProfile.new(); cold.save_path=profile.save_path
		check(cold.load_profile() and cold.cultivation_progress["schema_version"]==2 and cold.cultivation_progress["actors"]["player"]["mastery"]==20,point+": recovery keeps prior earned state with compact history")
	var conflict: SanctuaryProfile = _fixture(20)
	var original: PackedByteArray = FileAccess.get_file_as_bytes(conflict.save_path)
	var file := FileAccess.open(_backup(conflict,original),FileAccess.WRITE);file.store_string("foreign backup");file.close()
	check(not conflict.compact_cultivation_receipts() and conflict.last_commit.get("error")=="compaction_backup_conflict","Existing unequal backup fails closed")
	check(FileAccess.get_file_as_bytes(conflict.save_path)==original,"Backup conflict never changes main authority")
	var external: SanctuaryProfile = _fixture(20)
	var payload: Dictionary = Writer.read_json(external.save_path);payload["souls"]=99
	payload=Writer.sealed(payload,43)
	var text: String = Writer.canonical(payload)
	file=FileAccess.open(external.save_path,FileAccess.WRITE);file.store_string(text);file.close()
	check(not external.compact_cultivation_receipts() and external.last_commit.get("error")=="profile_changed_reload_required","External valid save change rejects stale migration owner")
	check(FileAccess.get_file_as_string(external.save_path)==text,"Stale migration preserves intervening external authority")
	var runtime: SanctuaryProfile = _fixture(20)
	check(runtime.compact_cultivation_receipts(),"Runtime fault fixture migrated")
	var proposal: Dictionary = _proposal(runtime)
	original=FileAccess.get_file_as_bytes(runtime.save_path)
	runtime._writer.fault_plan={"write_candidate":true}
	check(not runtime.commit_cultivation(proposal) and runtime.cultivation_progress["actors"]["player"]["mastery"]==20 and FileAccess.get_file_as_bytes(runtime.save_path)==original,"Failed mastery leaves RAM and durable earned amount unchanged")
	check(runtime.commit_cultivation(proposal) and runtime.cultivation_progress["actors"]["player"]["mastery"]==21,"Identical mastery retry grants exactly once")
	check(runtime.commit_cultivation(proposal) and runtime.cultivation_progress["actors"]["player"]["mastery"]==21,"Repeated successful mastery retry grants nothing twice")

func _model_bounds() -> void:
	var profile: SanctuaryProfile = _fixture(20)
	var legacy: Dictionary = profile.cultivation_progress.duplicate(true)
	legacy["receipts"][0]["id"]="arbitrary_legacy"
	check(not Model.compact_progress(legacy,profile.material_stash).is_empty(),"Legacy arbitrary IDs can migrate but cannot be newly issued")
	legacy["receipts"][0]["id"]="cult_21"
	check(Model.compact_progress(legacy,profile.material_stash).is_empty(),"Legacy future canonical ID cannot be evicted then regranted")
	var bounded: Dictionary = Model.compact_progress(profile.cultivation_progress,profile.material_stash)
	bounded["revision"]=Model.LIMIT;bounded["next_event"]=Model.LIMIT+1;bounded["receipt_floor"]=Model.LIMIT-8
	for index: int in bounded["receipts"].size():
		bounded["receipts"][index]["revision"]=Model.LIMIT-7+index
		bounded["receipts"][index]["id"]="cult_%d" % (Model.LIMIT-7+index)
	check(Model.valid(bounded,profile.material_stash),"Compact sequence validates explicitly bounded billion-event endpoint")
	check(Model.propose(bounded,profile.material_stash,profile.souls,profile.boss_proofs,"mastery",{},"cult_%d" % (Model.LIMIT+1)).get("error")=="event_sequence_exhausted","Counter exhaustion rejects without overflow or earned reset")
	bounded["receipt_floor"]-=1
	check(not Model.valid(bounded,profile.material_stash),"Tampered watermark cannot weaken eviction authority")

func _rich_preservation() -> void:
	var profile: SanctuaryProfile = _fixture(20)
	var progress: Dictionary = profile.cultivation_progress.duplicate(true)
	progress["config"]["herb_occurrence_bps"]=10000
	var materials: Dictionary = profile.material_stash.duplicate()
	var commands: Array = [["enroll",{"enabled":true}], ["train",{"actor_id":Model.NPC,"sessions":2,"target_tick":16}], ["harvest",{"node_id":"h00_courtyard_01"}], ["consume",{"actor_id":Model.NPC,"origin_id":"h00_courtyard_01"}], ["harvest",{"node_id":"o01_p04_01"}]]
	for command: Array in commands:
		var proposal: Dictionary = Model.propose(progress,materials,profile.souls,profile.boss_proofs,command[0],command[1],"cult_%d" % progress["next_event"])
		check(proposal.get("ok",false),"Build nonempty earned NPC/origin fixture: "+command[0])
		if not proposal.get("ok",false): return
		progress=proposal["progress"];materials=proposal["materials"]
	profile.cultivation_progress=progress
	for id: StringName in MaterialCatalog.IDS: profile.material_stash[id]=int(materials.get(id,0))
	var payload: Dictionary = Writer.sealed(profile._export_payload(),43)
	var file := FileAccess.open(profile.save_path,FileAccess.WRITE);file.store_string(Writer.canonical(payload));file.close()
	check(profile.load_profile(),"Load actual two-actor lineage fixture")
	var before: Dictionary = profile._export_payload().duplicate(true)
	check(profile.compact_cultivation_receipts(),"Compaction retains existing NPC state without a new life event")
	for field: String in ["actors","origins","harvested_nodes","gameplay_tick","config"]:
		check(Writer.canonical(profile.cultivation_progress[field])==Writer.canonical(before["cultivation_progress"][field]),"Nonempty lineage fixture preserves "+field)
	check(Writer.canonical(profile.material_stash)==Writer.canonical(before["material_stash"]),"Paid NPC training and consumed/unconsumed herb balances survive")

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name()!="headless" or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: isolated headless QA directory required");quit(2);return
	_preservation_and_replay()
	_failures_and_retry()
	_model_bounds()
	_rich_preservation()
	print("RESULT CultivationReceiptCompaction checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
