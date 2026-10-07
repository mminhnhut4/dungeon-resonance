extends SceneTree
## Actual common-writer IO, exact decimal loot, legacy seals, tamper and recovery.
const Writer = preload("res://scripts/runtime/profile_commit_writer.gd")
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
var checks: int = 0
var failures: int = 0
var directory: String

func _initialize() -> void: _run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks += 1
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures += 1
func _bits(value: float) -> String:
	var raw := PackedByteArray()
	raw.resize(8)
	raw.encode_double(0,value)
	return raw.hex_encode()
func _problem_float() -> float: return PackedByteArray([0,0,0,0,162,168,139,63]).decode_double(0)
func _write(path: String,text: String) -> bool:
	if not path.begins_with(directory+"/"): return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null:return false
	file.store_string(text);file.flush()
	var ok: bool = file.get_error()==OK
	file.close()
	return ok
func _fixture(id: String) -> SanctuaryProfile:
	var bank := SanctuaryProfile.new()
	bank.save_path = directory+"/"+id+"/profile.json"
	_check(bank.save(),id+": existing legacy profile commits")
	_check(bank.commit_cultivation(Model.initial_proposal(Model.new_progress(4),bank.material_stash,bank.souls,bank.boss_proofs)),id+": current profile-format2 migration commits")
	return bank
func _loot(bank: SanctuaryProfile) -> Dictionary:
	var kit: GearInventory = HubPreparation.starter_inventory(bank)
	var weapon: GearItem = kit.items[kit.equipped_weapon_uid]
	weapon.source = &"drop";weapon.loot_rolled = true
	weapon.affix_id = &"precision";weapon.affix_value = _problem_float()
	weapon.drop_bonus = 0.040947075933218
	return GearInventoryCodec.encode(kit)
func _legacy_sealed(payload: Dictionary,revision: int) -> Dictionary:
	# Exact untouched seal1 protocol, independent of new sealed() table creation.
	var result: Dictionary = Writer.normalized(payload)
	result["profile_commit"] = {"schema_version":1,"revision":revision,"seal":""}
	result["profile_commit"]["seal"] = Writer.canonical(result).sha256_text()
	return result
func _reader(path: String) -> SanctuaryProfile:
	var bank := SanctuaryProfile.new();bank.save_path=path
	_check(bank.load_profile() and not bank.read_only,"Cold current reader accepts legitimate committed data")
	return bank
func _reject(payload: Dictionary,id: String) -> void:
	var path: String = directory+"/tamper_"+id+"/profile.json"
	var text: String = Writer.canonical(payload)
	_check(_write(path,text),id+": isolated tamper fixture written")
	var bank := SanctuaryProfile.new();bank.save_path=path
	_check(not bank.load_profile() and bank.read_only and FileAccess.get_file_as_string(path)==text,id+": altered/invalid data quarantines without rewriting or losing old bytes")

func _decimal_and_legacy() -> void:
	var bank: SanctuaryProfile = _fixture("decimal")
	bank.hub_inventory = _loot(bank)
	var before: Dictionary = bank.hub_inventory.duplicate(true)
	_check(GearInventoryCodec.valid(before) and bank.save(),"Actual rolled decimal affix now commits through native common writer")
	var committed: Dictionary = Writer.read_json(bank.save_path)
	_check(committed["version"]==2 and committed["profile_commit"]["schema_version"]==2 and Writer.seal_valid(committed),"Current profile schema stays2 and exact-numeric metadata is fully sealed")
	_check(Writer.canonical(committed["hub_inventory"])==Writer.canonical(before),"Every UID/equipment/quality/enhancement/stat survives with exact float64 values")
	var raw: String = FileAccess.get_file_as_string(bank.save_path)
	var raw_payload: Dictionary = JSON.parse_string(raw)
	_check(not Writer.seal_valid(raw_payload),"Lossy raw JSON without exact-bit restoration cannot bypass the seal")
	var cold: SanctuaryProfile = _reader(bank.save_path)
	_check(_bits(float(cold.hub_inventory["items"][0]["affix_value"]))==_bits(_problem_float()) and Writer.canonical(cold.hub_inventory)==Writer.canonical(before),"Cold supported loader restores exact decimal rather than rounding or dropping gear")
	var stable: Dictionary = _loot(cold)
	stable["items"][0]["affix_value"] = 0.01
	var payload: Dictionary = cold._export_payload();payload["hub_inventory"]=stable
	var old: Dictionary = _legacy_sealed(payload,3)
	var old_path: String = directory+"/old_seal1/profile.json"
	_check(_write(old_path,Writer.canonical(old)) and Writer.seal_valid(Writer.read_json(old_path)),"Legitimate prior seal1 save remains readable with its exact original checksum")
	var old_bytes: PackedByteArray = FileAccess.get_file_as_bytes(old_path)
	var legacy: SanctuaryProfile = _reader(old_path)
	_check(FileAccess.get_file_as_bytes(old_path)==old_bytes and Writer.canonical(legacy.hub_inventory)==Writer.canonical(stable),"Reading old legitimate save neither migrates nor edits its bytes")
	legacy.hub_inventory=before
	_check(legacy.save() and Writer.read_json(old_path)["profile_commit"]["revision"]==4,"Explicit old-save commit upgrades only needed numeric seal metadata once")
	var changed: Dictionary = committed.duplicate(true)
	changed["coins"] = int(changed.get("coins",0))+1
	_reject(changed,"coins")
	changed=committed.duplicate(true);changed["hub_inventory"]["items"][0]["affix_value"]=0.012
	_reject(changed,"numeric_wire")
	changed=committed.duplicate(true);changed["profile_commit"]["float64"][0]["bits"]="0000000000000000"
	_reject(changed,"bits")
	changed=committed.duplicate(true);changed["profile_commit"]["float64"].append(changed["profile_commit"]["float64"][0].duplicate(true))
	_reject(changed,"duplicate_path")
	changed=committed.duplicate(true);changed["profile_commit"]["float64"][0]["path"]=["profile_commit","revision"]
	_reject(changed,"metadata_path")
	changed=committed.duplicate(true);changed["profile_commit"]["schema_version"]=3
	_reject(changed,"future_seal")
	changed=committed.duplicate(true);changed["profile_commit"]["schema_version"]=1;changed["profile_commit"].erase("float64")
	_reject(changed,"stripped_numeric_metadata")
	var exact_index: int = -1
	for index: int in committed["profile_commit"]["float64"].size():
		var path_parts: Array = committed["profile_commit"]["float64"][index]["path"]
		if path_parts[0]=="hub_inventory" and path_parts[-1]=="affix_value": exact_index=index
	_check(exact_index>=0,"Exact metadata references the real decimal gear stat")
	if exact_index>=0:
		changed=committed.duplicate(true)
		changed["hub_inventory"]["items"][0]["affix_value"]=0.012
		changed["profile_commit"]["float64"][exact_index]["bits"]=_bits(0.012)
		_reject(changed,"coordinated_bits_and_stat")
	changed=committed.duplicate(true);changed["profile_commit"]["schema_version"]=true
	_reject(changed,"boolean_schema")
	changed=committed.duplicate(true);changed["profile_commit"]["schema_version"]="2"
	_reject(changed,"string_schema")
	changed=committed.duplicate(true);changed["profile_commit"]["float64"][0]["path"]=[0]
	_reject(changed,"integer_root_path")
	var unknown: Dictionary = Writer.sealed(bank._export_payload(),10,{"unsupported":"0".repeat(64)})
	_check(not Writer.seal_valid(unknown),"Unsupported opaque namespace rejects without trusting its numeric path")

func _broad_numeric_boundaries() -> void:
	var bank: SanctuaryProfile = _fixture("nested")
	var rng := RandomNumberGenerator.new();rng.seed=4242
	var numbers: Array = [_problem_float(),PackedByteArray([1,0,0,0,0,0,0,0]).decode_double(0),-0.0000000030253374576568604,0,1,-1,0.1]
	for _i: int in 200: numbers.append((rng.randf()-0.5)*pow(10,rng.randi_range(-20,12)))
	bank._retained_fields["numeric_fixture"] = {"arrays":[numbers],"tag":"keep extension"}
	_check(bank.save(),"Nested arbitrary finite decimal extensions commit without a stringify/parse convergence loop")
	var current: Dictionary = Writer.read_json(bank.save_path)
	_check(Writer.seal_valid(current) and Writer.canonical(current["numeric_fixture"])==Writer.canonical(bank._retained_fields["numeric_fixture"]),"Negative/scientific/subnormal values and integer structure round-trip exactly")
	var cold: SanctuaryProfile = _reader(bank.save_path)
	_check(Writer.canonical(cold._retained_fields["numeric_fixture"])==Writer.canonical(bank._retained_fields["numeric_fixture"]),"Unknown legitimate extension values survive cold restore")

func _faults_and_recovery() -> void:
	for point: String in ["commit","after_decision","after_old_rename","after_commit"]:
		var bank: SanctuaryProfile = _fixture(point)
		var before: PackedByteArray = FileAccess.get_file_as_bytes(bank.save_path)
		bank.hub_inventory=_loot(bank)
		var expected: Dictionary = bank.hub_inventory.duplicate(true)
		bank._writer.fault_plan={point:true}
		_check(not bank.save(),point+": decimal candidate fault reports failure")
		if point=="commit":
			_check(FileAccess.get_file_as_bytes(bank.save_path)==before and not bank.read_only,point+": definitive rollback retains previous save bytes")
			_check(bank.save(),point+": explicit retry saves decimal gear once")
		var cold: SanctuaryProfile = _reader(bank.save_path)
		_check(Writer.canonical(cold.hub_inventory)==Writer.canonical(expected) and Writer.seal_valid(Writer.read_json(cold.save_path)),point+": recovery/retry keeps exact UID loot and valid numeric seal")

func _run() -> void:
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if DisplayServer.get_name()!="headless" or not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/"):
		print("FAIL: private headless profile required");quit(2);return
	directory="user://verification/numeric_seal_%d" % OS.get_process_id()
	_decimal_and_legacy()
	_broad_numeric_boundaries()
	_faults_and_recovery()
	print("RESULT ProfileNumericSeal checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
