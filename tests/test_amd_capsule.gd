extends SceneTree
var checks: int = 0
var failures: int = 0
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func _run() -> void:
	check(AmdSlotStore.isolated(),"separate QA userdata")
	var store := AmdSlotStore.new()
	var user: String = AmdSlotStore.new_id()
	var original: String = store.create_slot(user)
	var profile := SanctuaryProfile.new(); profile.save_path = original; profile.souls = 77
	check(profile.save(),"real profile writer fixture")
	var npc := NpcWorldState.new(); npc.save_path = original + NpcWorldState.NPC_SUFFIX
	check(npc.save(),"real NPC writer fixture")
	check(store.activate(user,original,2),"active fixture")
	var files: Dictionary = {}
	for key: String in ["profile","npc"]:
		var text: String = FileAccess.get_file_as_string(original + (NpcWorldState.NPC_SUFFIX if key == "npc" else ""))
		files[key] = {"text":text,"sha256":text.sha256_text()}
	var native: Dictionary = {"schemaVersion":1,"profileSchema":1,"gameBuild":"synthetic-wire-test","files":files}
	var wire: Dictionary = JSON.parse_string(JSON.stringify(native,"",true,true))
	check(typeof(wire["profileSchema"]) == TYPE_FLOAT,"wire parser numeric representation")
	var capsule := AmdCapsule.new()
	var staged: String = capsule.stage(wire,user,store)
	check(staged != "" and staged != original,"valid wire roundtrip stages new slot: " + capsule.error)
	check(store.read_active(user)["path"] == original,"staging does not activate by itself")
	if staged != "":
		var restored := SanctuaryProfile.new(); restored.save_path = staged
		check(restored.load_profile() and restored.souls == 77,"existing reader restores exact fixture")
	# Pad real writer documents with legal JSON whitespace; reader/seal checks
	# still run, and the accepted bytes must remain exact at each boundary.
	for key: String in ["profile","npc"]:
		for offset: int in [-1,0,1]:
			var boundary: Dictionary = wire.duplicate(true)
			var size: int = AmdCapsule.file_limit(key) + offset
			var text: String = str(files[key]["text"])
			text += " ".repeat(size - text.to_utf8_buffer().size())
			boundary["files"][key] = {"text":text,"sha256":text.sha256_text()}
			var result: String = capsule.stage(boundary,user,store)
			if offset <= 0:
				var target: String = result + (NpcWorldState.NPC_SUFFIX if key == "npc" else "")
				check(result != "" and FileAccess.get_file_as_string(target) == text,"accept exact " + key + " byte boundary " + str(size) + ": " + capsule.error)
			else:
				check(result == "" and capsule.error == "capsule_digest_or_size","reject " + key + " one byte over without activation")
	for key: String in ["schemaVersion","profileSchema"]:
		for wrong: Variant in [null,true,false,"1",1.5,0,-1,999,INF,NAN]:
			var broken: Dictionary = wire.duplicate(true); broken[key] = wrong
			check(capsule.stage(broken,user,store) == "","reject invalid " + key + " type=" + str(typeof(wrong)))
	var broken: Dictionary = wire.duplicate(true); broken["files"]["npc"]["text"] += "corrupt"
	check(capsule.stage(broken,user,store) == "","digest guard remains")
	broken = wire.duplicate(true); broken["files"]["other"] = {}
	check(capsule.stage(broken,user,store) == "","no arbitrary files")
	broken = wire.duplicate(true); broken["profileSchema"] = 2.0
	check(capsule.stage(broken,user,store) == "","declared schema must match document")
	check(store.read_active(user)["path"] == original and FileAccess.file_exists(original),"all rejection paths retain local authority")
	print("RESULT AMD_CAPSULE checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
