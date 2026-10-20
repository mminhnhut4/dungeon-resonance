class_name NpcWorldState
extends RefCounted
## Pure bounded records: no Node, instance ID, wall clock or inventory rewards.
signal activity_changed(id: String, activity: String)
const STEP: float = 0.25
const MAX_TICKS: int = 1000000000
const SCHEMA: int = 8
const NPC_SUFFIX: String = ".npc_v1.json"
var tick: int = 0
var records: Dictionary = {}
var save_path: String = ""
var read_only: bool = false
var last_save_ok: bool = true
var io: SanctuaryProfile = SanctuaryProfile.new()
var _snapshot_schema: int = SCHEMA
var emitting_recovery: bool = false
var _local_control: Dictionary[String, bool] = {}
var compound_locked: bool = false
var active_room: String = ""

func _init() -> void:
	for id: String in NpcPilotCatalog.IDS: records[id] = NpcPilotCatalog.initial_record(id)
	for id: String in NpcPilotCatalog.TAN_DANG_IDS: records[id]["living"] = TanDangLivingState.empty()

func snapshot() -> Dictionary:
	return {"npc_schema":_snapshot_schema, "tick":tick, "records":records.duplicate(true)}

## Recovery preserves the same authored life. Legacy terminal facts are archived,
## never used to mint another generation or repeat social/cultivation rewards.
static func life_id(id: String) -> String:
	return id + ":opening:1" if id in NpcPilotCatalog.IDS else ""

## Read fence for a same-thread profile transaction. It never writes the sidecar
## and deliberately excludes x, schedule phase and clock from the fingerprint.
func social_fence(id: String) -> Dictionary:
	if read_only or id not in NpcSocialCatalog.IDS or not records.has(id) or not valid(snapshot()): return {}
	var durable: Variant = _read(save_path)
	if not valid(durable) or not durable["records"].has(id): return {}
	var live: Dictionary = records[id]
	var saved: Dictionary = durable["records"][id]
	for record: Dictionary in [live,saved]:
		if not record["death"].is_empty() or record["mode"] in ["dead","downed","recovering","flee"] or record["hp"] < 1: return {}
	return {"actor_id":id, "life_id":life_id(id), "npc_path":save_path, "live_fingerprint":_social_fingerprint(id,live), "durable_fingerprint":_social_fingerprint(id,saved)}

func social_fence_matches(fence: Dictionary) -> bool:
	if fence.size() != 5 or fence.get("npc_path") != save_path or fence.get("life_id") != life_id(str(fence.get("actor_id",""))): return false
	var current: Dictionary = social_fence(str(fence.get("actor_id","")))
	return not current.is_empty() and current == fence

static func _social_fingerprint(id: String, record: Dictionary) -> String:
	return JSON.stringify({"life_id":life_id(id), "room":record["room"], "episode":int(record["episode"]), "hp":float(record["hp"]), "trust":int(record["trust"]), "fear":int(record["fear"]), "debt":int(record["debt"]), "death":record["death"]},"",true,true).sha256_text()

func advance_ticks(count: int) -> void:
	if read_only or compound_locked or _compound_pending(): return
	for _index: int in clampi(count, 0, 8):
		tick = mini(tick + 1, MAX_TICKS)
		for id: String in NpcPilotCatalog.IDS:
			if _local_control.has(id): continue
			if id in NpcPilotCatalog.TAN_DANG_IDS:
				if records[id]["room"]==active_room: _advance_living_tick(id)
				continue
			var record: Dictionary = records[id]
			var spec: Dictionary = NpcPilotCatalog.definition(id)
			match record["mode"]:
				"walk", "flee":
					var speed: float = float(spec["speed"]) * (1.8 if record["mode"] == "flee" else 1.0)
					record["x"] = move_toward(float(record["x"]), float(record["target"]), speed * STEP)
					if is_equal_approx(record["x"], record["target"]):
						if record["mode"] == "flee":
							_set_mode(id, "rest", 12)
						else:
							var point: Dictionary = NpcPilotCatalog.stop(id, int(record["schedule_index"]))
							_set_mode(id, point["mode"], point["ticks"])
				"rest", "work":
					record["remaining"] = maxi(0, int(record["remaining"]) - 1)
					if record["remaining"] == 0:
						var point: Dictionary = NpcPilotCatalog.stop(id, int(record["schedule_index"]))
						if is_equal_approx(record["x"], point["x"]):
							record["schedule_index"] = (int(record["schedule_index"]) + 1) % NpcPilotCatalog.SCHEDULES[id].size()
						# Recovery and fleeing can rest between stops. Resume the
						# pending stop instead of waiting forever for x to match it.
						record["target"] = NpcPilotCatalog.stop(id, int(record["schedule_index"]))["x"]
						_set_mode(id, "walk")

## A local cultivator controller can temporarily own motion. This is not saved:
## leaving a room or loading a profile resumes the authored patrol schedule.
func set_local_control(id: String, active: bool) -> bool:
	if id not in NpcPilotCatalog.CULTIVATOR_IDS: return false
	if not active:
		_local_control.erase(id)
		return true
	if read_only or compound_locked or _compound_pending() or not records.has(id) or records[id]["mode"] in ["dead", "downed", "recovering", "talk"]: return false
	_local_control[id] = true
	return true

func update_local_position(id: String, local_x: float) -> bool:
	if read_only or compound_locked or _compound_pending() or not _local_control.has(id) or not is_finite(local_x) or not records.has(id) or records[id]["mode"] in ["dead", "downed", "recovering", "talk"]: return false
	var limits: Vector2 = _motion_bounds(id,records[id])
	records[id]["x"] = clampf(local_x,limits.x,limits.y)
	return true

func set_active_room(room: String) -> void:
	active_room = room

static func _motion_bounds(id: String, record: Dictionary) -> Vector2:
	if id in NpcPilotCatalog.TAN_DANG_IDS: return TanDangLivingCatalog.bounds(id,record["room"])
	var spec: Dictionary = NpcPilotCatalog.definition(id)
	return Vector2(spec["left"],spec["right"])

## Read-only view: acknowledgements are bounded receipts, never render writes.
func living_view(id: String) -> Dictionary:
	if id not in NpcPilotCatalog.TAN_DANG_IDS or not records.has(id) or not records[id].has("living"): return {}
	var record: Dictionary = records[id]
	var view: Dictionary = record["living"].duplicate(true)
	view["room"] = record["room"]
	view["routine_phase"] = int(record["schedule_index"])
	view["activity"] = str(TanDangLivingCatalog.stop(id,record["room"],int(record["schedule_index"])).get("label",""))
	if view["convalescing"]: view["activity"] = "Dưỡng thương sau chuyến tìm vật liệu"
	view["quest_help"] = record["karma"]["rescued"] or record["karma"]["helped"]
	view["forage_help"] = TanDangLivingState.has_assistance(view)
	view["heard_outcome"] = str(records[TanDangLivingState.LAM]["living"]["outcome"]) if view["heard_materials"] else ""
	return view

## Runtime proves an actual calm conversation/LOS; owner checks local facts.
func report_living_event(listener: String) -> bool:
	if listener not in ["tan_dang_moc_yen","tan_dang_du_hanh"] or not _living_available(listener) or not _living_available(TanDangLivingState.LAM): return false
	var speaker: Dictionary = records[TanDangLivingState.LAM]
	var record: Dictionary = records[listener]
	if speaker["room"]!=TanDangLivingState.HUB or record["room"]!=speaker["room"] or speaker["living"]["event_phase"] not in ["returning","done"] or record["living"]["heard_materials"]: return false
	if speaker["mode"] not in ["walk","rest","work"] or record["mode"] not in ["walk","rest","work"] or absf(float(speaker["x"])-float(record["x"]))>160.0: return false
	var before: Dictionary = snapshot()
	record["living"]["heard_materials"] = true
	return _commit_living_change(before,listener)

func _living_available(id: String, require_active: bool = true) -> bool:
	return not read_only and not compound_locked and not _compound_pending() and _snapshot_schema==SCHEMA and id in NpcPilotCatalog.TAN_DANG_IDS and records.has(id) and records[id]["death"].is_empty() and records[id]["mode"] not in ["dead","downed","recovering","talk"] and (not require_active or records[id]["room"]==active_room)

## The adapter proves a playable, physically present encounter. RAM only: the
## existing room/exit/autosave and finite commits checkpoint this same owner.
func advance_living_danger(delta: float) -> bool:
	var id: String = TanDangLivingState.LAM
	if not is_finite(delta) or delta<=0.0 or not _living_available(id): return false
	var record: Dictionary = records[id]
	if record["room"]!=TanDangLivingState.P01 or record["living"]["event_phase"]!="danger": return false
	record["living"]["danger_elapsed"] = minf(TanDangLivingState.DANGER_HORIZON,float(record["living"]["danger_elapsed"])+minf(delta,0.1))
	return true

func mark_living_greeted(id: String, reason: String) -> bool:
	# Talking is an explicit interaction, but must not grant old greet() trust.
	if read_only or compound_locked or _compound_pending() or id not in NpcPilotCatalog.TAN_DANG_IDS or not records.has(id) or not records[id].has("living") or reason not in TanDangLivingState.REASONS: return false
	var record: Dictionary = records[id]
	if record["mode"] in ["dead","downed","recovering"] or not record["death"].is_empty() or record["room"]!=active_room or record["causality"]["harmed"] or not record["karma"]["grievance"].is_empty(): return false
	var view: Dictionary = living_view(id)
	if not view[reason] or record["living"]["acknowledged"][reason]: return false
	var before: Dictionary = snapshot()
	record["living"]["acknowledged"][reason] = true
	return _commit_living_change(before,id)

func start_living_event(story: Dictionary) -> bool:
	var id: String = TanDangLivingState.LAM
	if not _living_available(id) or not TanDangProgress.valid(story) or "q3" not in story["rewards"]: return false
	var record: Dictionary = records[id]
	if record["room"]!=TanDangLivingState.HUB or record["mode"]=="flee" or record["living"]["event_phase"]!="none": return false
	var before: Dictionary = snapshot()
	record["living"]["event_phase"] = "outbound"
	record["target"] = 740.0
	record["mode"] = "walk"
	record["remaining"] = 0
	return _commit_living_change(before,id)

func advance_living_event(id: String, expected_phase: String, next_phase: String) -> bool:
	if id!=TanDangLivingState.LAM or not _living_available(id) or expected_phase!="collecting" or next_phase!="danger": return false
	var record: Dictionary = records[id]
	if record["living"]["event_phase"]!=expected_phase or record["room"]!=TanDangLivingState.P01 or absf(float(record["x"])-500.0)>1.0 or record["mode"]!="work" or record["remaining"]!=0: return false
	var before: Dictionary = snapshot()
	record["living"]["event_phase"] = next_phase
	return _commit_living_change(before,id)

## Adapter calls only after a real accepted player hit on this event's threat.
func credit_living_help(id: String) -> bool:
	if id!=TanDangLivingState.LAM or not _living_available(id): return false
	var record: Dictionary = records[id]
	if record["living"]["event_phase"]!="danger" or record["living"]["help_credited"] or record["causality"]["harmed"] or not record["karma"]["grievance"].is_empty(): return false
	var before: Dictionary = snapshot()
	record["living"]["help_credited"] = true
	return _commit_living_change(before,id)

func resolve_living_event(id: String, outcome: String) -> bool:
	if id!=TanDangLivingState.LAM or not _living_available(id) or outcome not in ["self","helped","withdrew"]: return false
	var record: Dictionary = records[id]
	if record["living"]["event_phase"]!="danger": return false
	if outcome=="helped" and (not record["living"]["help_credited"] or record["causality"]["harmed"] or not record["karma"]["grievance"].is_empty()): return false
	var before: Dictionary = snapshot()
	_begin_living_return(record,outcome)
	if not _commit_or_restore(before): return false
	_local_control.erase(id)
	activity_changed.emit(id,record["mode"])
	return true

static func _begin_living_return(record: Dictionary, outcome: String) -> void:
	var first_result: bool = record["living"]["outcome"]==""
	record["living"]["event_phase"] = "returning"
	record["living"]["outcome"] = outcome
	# Both deliberate retreat and the monster HP floor use this same boundary.
	# A later hit/return cannot replay gratitude or erase an earlier offense.
	if first_result and TanDangLivingState.has_assistance(record["living"]) and not record["causality"]["harmed"] and record["karma"]["grievance"].is_empty():
		record["karma"]["gratitude"] = mini(100,int(record["karma"]["gratitude"])+1)
	record["target"] = 140.0 if record["room"]==TanDangLivingState.P01 else 1345.0
	record["mode"] = "walk"
	record["remaining"] = 0
	record["interrupted"] = {}

## NPC door handoff: no player warp, no off-room advancement and no new life.
func transfer_lam(destination: String) -> bool:
	var id: String = TanDangLivingState.LAM
	if not _living_available(id): return false
	var record: Dictionary = records[id]
	var outbound: bool = destination==TanDangLivingState.P01 and record["room"]==TanDangLivingState.HUB and record["living"]["event_phase"]=="outbound" and float(record["x"])<=750.0
	var returning: bool = destination==TanDangLivingState.HUB and record["room"]==TanDangLivingState.P01 and record["living"]["event_phase"]=="returning" and float(record["x"])<=150.0
	if not outbound and not returning: return false
	var before: Dictionary = snapshot()
	record["room"] = destination
	record["x"] = 150.0 if outbound else 750.0
	record["target"] = 500.0 if outbound else 1345.0
	record["schedule_index"] = 0
	record["mode"] = "walk"
	record["remaining"] = 0
	if outbound: record["living"]["event_phase"] = "collecting"
	if not _commit_or_restore(before): return false
	_local_control.erase(id)
	activity_changed.emit(id,"walk")
	return true

func _advance_living_tick(id: String) -> void:
	var record: Dictionary = records[id]
	if record["mode"] not in ["walk","rest","work","flee"]: return
	if record["living"]["convalescing"] and record["mode"]!="flee": return
	var phase: String = record["living"]["event_phase"]
	if id==TanDangLivingState.LAM and phase not in ["none","done"]:
		if phase=="danger": return # Actual combat adapter owns the encounter.
		if record["mode"]=="flee":
			record["x"] = move_toward(float(record["x"]),float(record["target"]),TanDangLivingCatalog.speed(id,record["room"])*STEP*1.8)
			if is_equal_approx(record["x"],record["target"]): _begin_living_return(record,record["living"]["outcome"])
		elif record["mode"]=="walk":
			record["x"] = move_toward(float(record["x"]),float(record["target"]),TanDangLivingCatalog.speed(id,record["room"])*STEP)
			if is_equal_approx(record["x"],record["target"]):
				if phase=="collecting": _set_mode(id,"work",24)
				elif phase=="returning" and record["room"]==TanDangLivingState.HUB:
					var before: Dictionary = snapshot()
					record["living"]["event_phase"] = "done"
					record["mode"] = "rest"
					record["remaining"] = 12
					record["schedule_index"] = 0
					if float(record["hp"])<NpcPilotCatalog.maximum_health(id):
						record["living"]["convalescing"] = true
						record["mode"] = "recovering" if record["hp"]==1.0 else "rest"
						record["remaining"] = 0
					_commit_living_change(before,id)
		elif phase=="collecting" and record["mode"]=="work": record["remaining"] = maxi(0,int(record["remaining"])-1)
		return
	# Dư cannot walk away from the sustaining core before the authored choice.
	if id=="tan_dang_du_hanh" and (record["room"]!=TanDangLivingState.HUB or not record["karma"]["rescued"]): return
	var speed: float = TanDangLivingCatalog.speed(id,record["room"])
	if speed<=0.0: return
	match record["mode"]:
		"walk","flee":
			record["x"] = move_toward(float(record["x"]),float(record["target"]),speed*STEP*(1.8 if record["mode"]=="flee" else 1.0))
			if is_equal_approx(record["x"],record["target"]):
				var point: Dictionary = TanDangLivingCatalog.stop(id,record["room"],int(record["schedule_index"]))
				_set_mode(id,"rest" if record["mode"]=="flee" else point["mode"],12 if record["mode"]=="flee" else int(point["ticks"]))
		"rest","work":
			record["remaining"] = maxi(0,int(record["remaining"])-1)
			if record["remaining"]==0:
				var point: Dictionary = TanDangLivingCatalog.stop(id,record["room"],int(record["schedule_index"]))
				if is_equal_approx(record["x"],point["x"]): record["schedule_index"] = (int(record["schedule_index"])+1)%TanDangLivingCatalog.count(id,record["room"])
				record["target"] = TanDangLivingCatalog.stop(id,record["room"],int(record["schedule_index"]))["x"]
				_set_mode(id,"walk")

func _set_mode(id: String, mode: String, remaining: int = 0) -> void:
	records[id]["mode"] = mode
	records[id]["remaining"] = remaining
	activity_changed.emit(id, mode)

func begin_talk(id: String) -> bool:
	if read_only or compound_locked or _compound_pending() or not records.has(id) or records[id]["mode"] in ["talk", "downed", "dead", "recovering"]: return false
	records[id]["interrupted"] = {"mode":records[id]["mode"], "remaining":records[id]["remaining"]}
	_set_mode(id, "talk")
	return true

func end_talk(id: String) -> void:
	if compound_locked or _compound_pending() or not records.has(id) or records[id]["mode"] != "talk": return
	var interrupted: Dictionary = records[id]["interrupted"].duplicate()
	records[id]["interrupted"] = {}
	_set_mode(id, interrupted["mode"], int(interrupted["remaining"]))

func greet(id: String) -> bool:
	if read_only or compound_locked or _compound_pending() or not records.has(id) or records[id]["mode"] != "talk" or records[id]["greeted"]: return false
	var before: Dictionary = snapshot()
	records[id]["greeted"] = true
	records[id]["trust"] = mini(100, records[id]["trust"] + 1)
	return _commit_or_restore(before)

func damage_health_floor(_id: String) -> float:
	return 1.0

func karma(id: String) -> Dictionary:
	return records.get(id,{}).get("karma",{}).duplicate(true)

func retaliation_reason(id: String) -> String:
	return str(karma(id).get("grievance",""))

func receive_hit(id: String, hp: float, origin_x: float, player_caused: bool = true, actor_x: float = NAN, record_cause: bool = true, witnesses: Array[String] = []) -> bool:
	if read_only or compound_locked or _compound_pending() or not is_finite(hp) or not records.has(id) or records[id]["mode"] in ["downed", "dead", "recovering"]: return false
	var before: Dictionary = snapshot()
	var local_before: Dictionary[String,bool] = _local_control.duplicate()
	var record: Dictionary = records[id]
	var limits: Vector2 = _motion_bounds(id,record)
	record["interrupted"] = {}
	record["hp"] = clampf(hp, 1.0, NpcPilotCatalog.maximum_health(id))
	# Withdrawal never erases violence or rewards the attacker with gratitude.
	if record_cause:
		record["fear"] = mini(100, int(record["fear"]) + 6)
		if player_caused: record["trust"] = maxi(-100, int(record["trust"]) - 2)
	if player_caused and id in NpcPilotCatalog.TAN_DANG_IDS:
		if record["karma"]["grievance"].is_empty(): record["karma"]["grievance"] = "attacked"
		TanDangCausality.observe(records,id,"attacked",witnesses)
	if hp <= 1.0:
		_local_control.erase(id)
		record["episode"] = mini(1000000, int(record["episode"]) + 1)
		record["mode"] = "downed" if id in NpcPilotCatalog.TAN_DANG_IDS else "recovering"
		record["remaining"] = 0
	else:
		# A local actor may have moved between decisions. Use its contact sample
		# only for this reaction; offscreen/pure callers keep the record fallback.
		var contact_x: float = clampf(actor_x, limits.x, limits.y) if is_finite(actor_x) else float(record["x"])
		record["target"] = limits.y if origin_x <= contact_x else limits.x
		record["mode"] = "flee"
		record["remaining"] = 0
	if id==TanDangLivingState.LAM and record["living"]["event_phase"] not in ["none","done"]:
		if player_caused:
			# A later assault never rewrites an already committed help receipt.
			if record["living"]["outcome"]=="": record["living"]["outcome"] = "interrupted"
			if hp<=1.0: record["living"]["event_phase"] = "done"
			else:
				var reaction_target: float = float(record["target"])
				_begin_living_return(record,record["living"]["outcome"])
				record["target"] = reaction_target
				record["mode"] = "flee"
		elif hp<=1.0:
			# A monster cannot trigger the player's spare/execute decision.
			_begin_living_return(record,"withdrew" if record["living"]["outcome"]=="" else record["living"]["outcome"])
	if not _commit_or_restore(before):
		_local_control=local_before
		return false
	activity_changed.emit(id, record["mode"])
	return true

func decision_token(id: String) -> String:
	return "%s:%d" % [id, records[id]["episode"]] if records.has(id) and records[id]["mode"] == "downed" else ""

func decide(id: String, token: String, kill: bool, _confirmed: bool = false, witnesses: Array[String] = []) -> bool:
	if read_only or compound_locked or _compound_pending() or token.is_empty() or token != decision_token(id): return false
	if kill and (id not in NpcPilotCatalog.TAN_DANG_IDS or not _confirmed): return false
	var before: Dictionary = snapshot()
	var record: Dictionary = records[id]
	record["mode"] = "dead" if kill else "recovering"
	record["remaining"] = 0
	record["interrupted"] = {}
	if id in NpcPilotCatalog.TAN_DANG_IDS:
		if kill:
			record["hp"] = 0.0
			record["living"]["convalescing"] = false
			record["death"] = {"event_id":token,"killer_id":"player","tick":tick,"room":record["room"],"context":"explicit_execution"}
			record["karma"]["player_murdered"] = true
			record["karma"]["grievance"] = "player_murder"
			TanDangCausality.observe(records,id,"player_murder",witnesses)
		else:
			var first_spare: bool=not record["karma"]["spared"]
			record["karma"]["spared"] = true
			# Sparing one's own victim records the fact, never buys forgiveness.
			if first_spare and record["karma"]["grievance"].is_empty() and not record["causality"]["harmed"]: record["karma"]["gratitude"] = mini(100,int(record["karma"]["gratitude"])+1)
	if not _commit_or_restore(before): return false
	activity_changed.emit(id, record["mode"])
	return true

func report_cause(victim: String, reason: String, reporter: String, room: String) -> bool:
	if read_only or compound_locked or _compound_pending() or not TanDangCausality.can_report(records,victim,reason,reporter,room):return false
	var before: Dictionary=snapshot()
	records[victim]["causality"]["reports"].append({"reason":reason,"reporter":reporter,"room":room})
	if not _commit_or_restore(before):return false
	activity_changed.emit(victim,records[victim]["mode"])
	return true

## Trusted GameFlow calls only after an actual dungeon expedition returns.
## A failed write restores every resident; ordinary ticks/doors/load never heal.
func recover_after_expedition() -> bool:
	if read_only or compound_locked or _compound_pending() or _snapshot_schema != SCHEMA: return false
	var before: Dictionary = snapshot()
	var recovered: Array[String] = []
	for id: String in NpcPilotCatalog.IDS:
		var record: Dictionary = records[id]
		var convalescing: bool = id==TanDangLivingState.LAM and record["living"]["convalescing"] and record["mode"] not in ["dead","downed"]
		if not convalescing and (record["mode"] not in ["downed", "recovering"] or (id in NpcPilotCatalog.TAN_DANG_IDS and record["mode"] == "downed")): continue
		record["mode"] = "rest"
		var recovered_hp: float = NpcPilotCatalog.maximum_health(id) * 0.5
		record["hp"] = maxf(float(record["hp"]),recovered_hp) if convalescing else recovered_hp
		if convalescing: record["living"]["convalescing"] = false
		record["remaining"] = 12
		record["interrupted"] = {}
		if id==TanDangLivingState.LAM and record["room"]==TanDangLivingState.P01 and record["living"]["event_phase"]=="done": _begin_living_return(record,record["living"]["outcome"])
		recovered.append(id)
	if recovered.is_empty(): return true
	if not _commit_or_restore(before): return false
	# Do not emit rest until the single recovery commit has succeeded.
	emitting_recovery = true
	for id: String in recovered: activity_changed.emit(id, "rest")
	emitting_recovery = false
	return true

func _commit_or_restore(before: Dictionary) -> bool:
	if save(): return true
	records = before["records"]
	tick = int(before["tick"])
	return false

## Finite event/knowledge publication also invalidates the existing journal.
## Ambient positions keep their old schedule signals; no per-tick refresh.
func _commit_living_change(before: Dictionary, id: String) -> bool:
	if not _commit_or_restore(before): return false
	activity_changed.emit(id,records[id]["mode"])
	return true

## Only the existing profile writer coordinates a joint commit. A surviving
## compound decision fences ambient saves and loads until that writer recovers.
func _compound_pending() -> bool:
	if not save_path.ends_with(NPC_SUFFIX): return false
	var journal: String = save_path.trim_suffix(NPC_SUFFIX) + ".decision"
	if not FileAccess.file_exists(journal):
		return FileAccess.file_exists(save_path+".compound.previous")
	var decision: Variant = _read(journal)
	return not decision is Dictionary or decision.get("commit_schema") != 1

static func _state_hash(data: Dictionary) -> String:
	return JSON.stringify(data,"",true,true).sha256_text()

static func _byte_hash(path: String) -> String:
	return FileAccess.get_file_as_bytes(path).hex_encode().sha256_text() if FileAccess.file_exists(path) else ""

func propose_sect_changes(edits: Dictionary) -> Dictionary:
	if read_only or compound_locked or _compound_pending() or not valid(snapshot()): return {}
	var durable: Variant = _read(save_path)
	if not valid(durable) or durable["npc_schema"] != SCHEMA: return {}
	var before: Dictionary = snapshot()
	var after: Dictionary = _edited_snapshot(before,edits)
	if after.is_empty(): return {}
	return {"proposal_schema":1,"npc_path":save_path,"live_sha256":_state_hash(before),"durable_sha256":_byte_hash(save_path),"before":before,"after":after,"edits":edits.duplicate(true)}

static func valid_sect_proposal(proposal: Dictionary) -> bool:
	if proposal.size()!=7 or proposal.get("proposal_schema")!=1 or not proposal.get("npc_path") is String or not proposal.get("before") is Dictionary or not proposal.get("after") is Dictionary or not proposal.get("edits") is Dictionary: return false
	if not valid(proposal["before"]) or not valid(proposal["after"]) or proposal["before"]["npc_schema"]!=SCHEMA or proposal["after"]["npc_schema"]!=SCHEMA: return false
	if proposal.get("live_sha256")!=_state_hash(proposal["before"]) or not proposal.get("durable_sha256") is String or proposal["durable_sha256"].length()!=64: return false
	var expected: Dictionary = _edited_snapshot(proposal["before"],proposal["edits"])
	return not expected.is_empty() and expected == proposal["after"]

func sect_proposal_matches(proposal: Dictionary) -> bool:
	return not read_only and valid_sect_proposal(proposal) and proposal["npc_path"]==save_path and proposal["live_sha256"]==_state_hash(snapshot()) and proposal["durable_sha256"]==_byte_hash(save_path)

func apply_after_commit(proposal: Dictionary) -> bool:
	# This API can only publish a primary that the writer has already installed.
	if not valid_sect_proposal(proposal) or proposal["npc_path"]!=save_path: return false
	var durable: Variant = _read(save_path)
	var writer_script = load("res://scripts/runtime/profile_commit_writer.gd")
	# The JSON wire normalizes integer-valued floats. Verify the exact candidate
	# representation rather than comparing native Dictionary number types.
	if not valid(durable) or FileAccess.get_file_as_string(save_path)!=writer_script.canonical(proposal["after"]): return false
	var before: Dictionary = records.duplicate(true)
	var local_before: Dictionary[String,bool] = _local_control.duplicate()
	_restore(proposal["after"])
	for id: String in local_before:
		if records.has(id) and records[id]["mode"] not in ["dead","downed","recovering","talk"]: _local_control[id]=true
	last_save_ok = true
	for id: String in NpcPilotCatalog.TAN_DANG_IDS:
		if before.get(id) != records[id]: activity_changed.emit(id,records[id]["mode"])
	return true

static func _edited_snapshot(before: Dictionary, edits: Dictionary) -> Dictionary:
	if edits.size()>3: return {}
	var after: Dictionary = before.duplicate(true)
	for id: Variant in edits:
		if not id is String or id not in NpcPilotCatalog.TAN_DANG_IDS or not edits[id] is Dictionary: return {}
		var edit: Dictionary = edits[id]
		for key: Variant in edit:
			if key not in ["trust_delta","gratitude_delta","gratitude_reason","grievance","death_context","killer_id","consume_assistance","return_home","reconcile"]: return {}
		var record: Dictionary = after["records"][id]
		var facts: Dictionary = record["karma"]
		if edit.has("trust_delta") and not _integer(edit["trust_delta"],-10,10): return {}
		if edit.has("gratitude_delta") and not _integer(edit["gratitude_delta"],0,3): return {}
		if edit.has("grievance"):
			if edit["grievance"] not in ["attacked","player_murder"]: return {}
			if facts["grievance"] != "player_murder": facts["grievance"] = edit["grievance"]
			if edit["grievance"]=="attacked":TanDangCausality.observe(after["records"],id,"attacked",[])
		if edit.has("reconcile"):
			if edit["reconcile"]!=true or not TanDangCausality.can_reconcile(record):return {}
			facts["grievance"]="";record["causality"]["peace_used"]=true;record["causality"]["reconciled"]=true
		var terminal: bool = record["mode"] == "dead"
		if edit.has("death_context") or edit.has("killer_id"):
			if terminal or id!="tan_dang_du_hanh" or edit.get("death_context")!="core_withdrawal" or edit.get("killer_id")!="core_reclaimed" or record["episode"]>=1000000: return {}
			record["episode"] += 1
			record["mode"] = "dead"; record["hp"] = 0.0; record["remaining"] = 0; record["interrupted"] = {}
			record["death"] = {"event_id":"%s:%d" % [id,record["episode"]],"killer_id":"core_reclaimed","tick":after["tick"],"room":record["room"],"context":"core_withdrawal"}
			terminal = true
		if edit.has("return_home"):
			if edit["return_home"] != true or id not in ["tan_dang_lam_tuoc","tan_dang_du_hanh"] or terminal: return {}
			record["room"] = "h00_traveler_hub"
			if record.has("living"):
				record["x"] = 1345.0 if id==TanDangLivingState.LAM else 1385.0
				record["target"] = record["x"]
				record["schedule_index"] = 0
		var trust_delta: int = int(edit.get("trust_delta",0))
		var gratitude_delta: int = int(edit.get("gratitude_delta",0))
		if terminal and (trust_delta!=0 or gratitude_delta!=0 or edit.has("gratitude_reason") or edit.has("consume_assistance")): return {}
		# Harm has priority over later story rewards, never reset by a timer.
		var grateful: bool = facts["grievance"].is_empty() and not facts["player_murdered"] and not record["causality"]["harmed"]
		if trust_delta<=0 or grateful: record["trust"] = clampi(int(record["trust"])+trust_delta,-100,100)
		if edit.has("gratitude_reason"):
			var reason: Variant = edit["gratitude_reason"]
			if reason not in ["rescued","helped","spared"] or (reason=="rescued" and id!="tan_dang_du_hanh"): return {}
			if facts[reason]: gratitude_delta = 0
			facts[reason] = true
		elif gratitude_delta>0: return {}
		if grateful: facts["gratitude"] = mini(100,int(facts["gratitude"])+gratitude_delta)
		if edit.has("consume_assistance"):
			if edit["consume_assistance"]!=true or not grateful or facts["gratitude"]<1 or facts["assistance_used"]: return {}
			facts["assistance_used"] = true
	return after if valid(after) else {}

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 3 or not _integer(data.get("npc_schema"), 1, SCHEMA) or not data.get("records") is Dictionary: return false
	var legacy: bool = int(data["npc_schema"]) == 1
	var nonlethal: bool = int(data["npc_schema"]) >= 3
	var current: bool = int(data["npc_schema"]) >= 5
	var causal: bool = int(data["npc_schema"]) >= 6
	var living: bool = int(data["npc_schema"]) >= 7
	var ids: Array[String] = NpcPilotCatalog.IDS if current else NpcPilotCatalog.LEGACY_IDS if legacy else NpcPilotCatalog.SCHEMA_FOUR_IDS if int(data["npc_schema"])==4 else NpcPilotCatalog.SCHEMA_THREE_IDS if nonlethal else NpcPilotCatalog.SCHEMA_TWO_IDS
	if not _integer(data.get("tick"), 0, MAX_TICKS) or data["records"].size() != ids.size(): return false
	for id: String in ids:
		var record: Variant = data["records"].get(id)
		var spec: Dictionary = NpcPilotCatalog.definition(id)
		var sect: bool = current and id in NpcPilotCatalog.TAN_DANG_IDS
		if not record is Dictionary or record.size() != (18 if sect and living else 17 if sect and causal else 16 if sect else 12 if legacy else 15 if nonlethal else 14): return false
		if record.get("room") != spec["room"] and not (sect and id in ["tan_dang_lam_tuoc","tan_dang_du_hanh"] and record.get("room")=="h00_traveler_hub") and not (living and id==TanDangLivingState.LAM and record.get("room")==TanDangLivingState.P01): return false
		if sect and not _valid_karma(record.get("karma")): return false
		if sect and causal and not TanDangCausality.valid(record.get("causality"),id):return false
		if sect and living and not TanDangLivingState.valid(record.get("living"),id,record,int(data["npc_schema"])): return false
		if sect and record["karma"]["player_murdered"] and record.get("mode")!="dead": return false
		if record.get("mode") not in NpcPilotCatalog.MODE_LABELS and ((nonlethal and not current) or record.get("mode") != "dead"): return false
		var low: float = 520.0 if legacy and id == "pilot_traveler" else float(spec["left"])
		var high: float = 870.0 if legacy and id == "pilot_traveler" else float(spec["right"])
		if sect and living:
			var limits: Vector2 = TanDangLivingCatalog.bounds(id,record["room"])
			low = limits.x
			high = limits.y
		for field: String in ["x", "target"]:
			if not _number(record.get(field), low, high): return false
		if not _number(record.get("hp"), 0, NpcPilotCatalog.maximum_health(id) if current else NpcPilotCatalog.MAX_HEALTH) or not _integer(record.get("remaining"), 0, 80): return false
		for field: String in ["trust", "debt", "fear"]:
			if not _integer(record.get(field), -100 if field == "trust" else 0, 100): return false
		if not record.get("greeted") is bool or not _integer(record.get("episode"), 0, 1000000) or not record.get("death") is Dictionary: return false
		if record["mode"] == "dead":
			var death: Dictionary = record["death"]
			if (nonlethal and not current) or record["hp"] != 0: return false
			if current:
				if not _valid_death(death,id,record,int(data["tick"])): return false
			elif not _valid_legacy_death(death,id,record,int(data["tick"])) or death["event_id"] != "%s:%d" % [id,record["episode"]]: return false
			if sect and (record["karma"]["player_murdered"] != (death["killer_id"] == "player")): return false
		elif record["hp"] < 1 or not record["death"].is_empty(): return false
		if record["mode"] in ["downed", "recovering"] and record["hp"] != 1: return false
		if record["mode"] in ["downed", "recovering"] and record["episode"] < 1 and not (nonlethal and record.get("legacy_death") is Dictionary and not record["legacy_death"].is_empty()): return false
		if nonlethal:
			if not record.get("legacy_death") is Dictionary: return false
			if not record["legacy_death"].is_empty() and not _valid_legacy_death(record["legacy_death"],id,record,int(data["tick"])): return false
			if current and not record["legacy_death"].is_empty() and (record["mode"]!="dead" or record["death"]!=record["legacy_death"]): return false
			if record["mode"] == "recovering" and record["remaining"] != 0: return false
		if not legacy:
			var stop_count: int = TanDangLivingCatalog.count(id,record["room"]) if sect and living else NpcPilotCatalog.SCHEDULES[id].size()
			if not _integer(record.get("schedule_index"), 0, stop_count-1) or not record.get("interrupted") is Dictionary: return false
			var interrupted: Dictionary = record["interrupted"]
			if record["mode"] == "talk":
				if interrupted.size() != 2 or interrupted.get("mode") not in ["walk", "rest", "work", "flee"] or not _integer(interrupted.get("remaining"), 0, 80): return false
			elif not interrupted.is_empty(): return false
	if living:
		for listener: String in ["tan_dang_moc_yen","tan_dang_du_hanh"]:
			if data["records"][listener]["living"]["heard_materials"] and data["records"][TanDangLivingState.LAM]["living"]["outcome"]=="": return false
	return true

static func _valid_karma(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=7 or value.get("grievance") not in ["","attacked","player_murder"] or not _integer(value.get("gratitude"),0,100): return false
	for key: String in ["assistance_used","player_murdered","spared","rescued","helped"]:
		if not value.get(key) is bool: return false
	return not value["player_murdered"] or value["grievance"] == "player_murder"

static func _valid_death(death: Dictionary, id: String, record: Dictionary, world_tick: int) -> bool:
	if _valid_legacy_death(death,id,record,world_tick): return true
	return id == "tan_dang_du_hanh" and death.size()==5 and death.get("event_id")=="%s:%d" % [id,record["episode"]] and death.get("killer_id")=="core_reclaimed" and death.get("context")=="core_withdrawal" and death.get("room")==record["room"] and _integer(death.get("tick"),0,world_tick)

static func _valid_legacy_death(death: Dictionary, id: String, record: Dictionary, world_tick: int) -> bool:
	if death.size() != 5 or not death.get("event_id") is String or death.get("killer_id") != "player" or death.get("room") != record["room"] or death.get("context") != "explicit_execution" or not _integer(death.get("tick"),0,world_tick): return false
	var parts: PackedStringArray = death["event_id"].split(":")
	return parts.size() == 2 and parts[0] == id and parts[1].is_valid_int() and str(int(parts[1])) == parts[1] and int(parts[1]) >= 0 and int(parts[1]) <= int(record["episode"])

static func _number(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= low and float(value) <= high

static func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value, low, high) and float(value) == floorf(float(value))

func _read(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 32768: return null
	var parser := JSON.new()
	return parser.data if parser.parse(file.get_as_text()) == OK else null

func _restore(data: Dictionary) -> void:
	# JSON numbers arrive as floats. Restore the authored scalar types explicitly.
	records = data["records"].duplicate(true)
	tick = int(data["tick"])
	_snapshot_schema = SCHEMA
	_local_control.clear()
	for id: String in records:
		for field: String in ["remaining", "trust", "debt", "fear", "episode"]: records[id][field] = int(records[id][field])
		for field: String in ["x", "target", "hp"]: records[id][field] = float(records[id][field])
		if not records[id]["death"].is_empty(): records[id]["death"]["tick"] = int(records[id]["death"]["tick"])
		if records[id].has("legacy_death") and not records[id]["legacy_death"].is_empty(): records[id]["legacy_death"]["tick"] = int(records[id]["legacy_death"]["tick"])
		if records[id].has("karma"): records[id]["karma"]["gratitude"] = int(records[id]["karma"]["gratitude"])
		if int(data["npc_schema"]) == 1:
			# Preserve every old scalar/tombstone. Only add schedule ownership fields.
			var closest: int = 0
			var distance: float = INF
			for index: int in NpcPilotCatalog.SCHEDULES[id].size():
				var next: float = absf(float(records[id]["target"]) - float(NpcPilotCatalog.stop(id,index)["x"]))
				if next < distance:
					closest = index
					distance = next
			records[id]["schedule_index"] = closest
			records[id]["interrupted"] = {"mode":"rest", "remaining":16} if records[id]["mode"] == "talk" else {}
		else:
			records[id]["schedule_index"] = int(records[id]["schedule_index"])
			if not records[id]["interrupted"].is_empty(): records[id]["interrupted"]["remaining"] = int(records[id]["interrupted"]["remaining"])
		if int(data["npc_schema"]) < 3: records[id]["legacy_death"] = records[id]["death"].duplicate(true)
		# Archived terminal facts remain the same authored life, never a new actor.
		if int(data["npc_schema"]) < 7 and not records[id]["legacy_death"].is_empty():
			records[id]["death"] = records[id]["legacy_death"].duplicate(true)
			records[id]["mode"] = "dead"
			records[id]["hp"] = 0.0
			records[id]["remaining"] = 0
			records[id]["interrupted"] = {}
	if int(data["npc_schema"]) == 1: records["pilot_bridge_keeper"] = NpcPilotCatalog.initial_record("pilot_bridge_keeper")
	if int(data["npc_schema"]) < 3:
		for id: String in NpcPilotCatalog.ORIGINAL_CULTIVATOR_IDS: records[id] = NpcPilotCatalog.initial_record(id)
	if int(data["npc_schema"]) < 4:
		for id: String in NpcPilotCatalog.SECT_STEWARD_IDS: records[id] = NpcPilotCatalog.initial_record(id)
	if int(data["npc_schema"]) < 5:
		for id: String in NpcPilotCatalog.TAN_DANG_IDS: records[id] = NpcPilotCatalog.initial_record(id)
	if int(data["npc_schema"]) < 6:
		for id: String in NpcPilotCatalog.TAN_DANG_IDS:
			var harmed: bool=not records[id]["karma"]["grievance"].is_empty()
			records[id]["causality"]=TanDangCausality.empty(harmed)
			if records[id]["karma"]["grievance"]=="attacked":records[id]["causality"]["witnesses"]["attacked"].append(id)
	if int(data["npc_schema"]) < 7:
		for id: String in NpcPilotCatalog.TAN_DANG_IDS: records[id]["living"] = TanDangLivingState.empty()
	# NPC7 never stored elapsed time. Zero means unknown pre-migration history,
	# not a reconstruction from world ticks or wall time. Preserve every old fact.
	for id: String in NpcPilotCatalog.TAN_DANG_IDS:
		records[id]["living"]["danger_elapsed"] = 0.0 if int(data["npc_schema"])<8 else float(records[id]["living"]["danger_elapsed"])

func load_state() -> bool:
	if compound_locked or _compound_pending():
		read_only = true
		return false
	if not FileAccess.file_exists(save_path):
		# A valid tmp can still be an execution whose commit was reported failed.
		# An older backup can predate a committed death. Neither proves history.
		for suffix: String in [".previous", ".tmp", ".bak", ".compound.tmp", ".compound.previous", ".pre_nonlethal_v1.json", ".pre_nonlethal_v2.json", ".pre_sect_v3.json", ".pre_tan_dang_v4.json", ".pre_causality_v5.json", ".pre_living_v6.json", ".pre_horizon_v7.json"]:
			if not FileAccess.file_exists(save_path + suffix): continue
			read_only = true
			return false
		return true # Existing profiles without an NPC sidecar are compatible.
	var data: Variant = _read(save_path)
	if not valid(data):
		read_only = true
		return false
	if int(data["npc_schema"]) < SCHEMA and not _preserve_legacy_source(data):
		_refuse_migration(data)
		return false
	_restore(data)
	for id: String in NpcPilotCatalog.IDS: end_talk(id)
	if int(data["npc_schema"]) < SCHEMA and not save():
		# No new authority is exposed if migration did not commit. Preserve the
		# full old view for diagnostics and leave the primary/backup under IO's
		# existing interrupted-replace rules; a fresh load can retry later.
		_refuse_migration(data)
		return false
	return true

func _refuse_migration(data: Dictionary) -> void:
	records = data["records"].duplicate(true)
	tick = int(data["tick"])
	_snapshot_schema = int(data["npc_schema"])
	last_save_ok = false
	read_only = true

func _preserve_legacy_source(data: Dictionary) -> bool:
	# This immutable copy survives ordinary .bak rotation. A pre-existing file
	# with different bytes is evidence to preserve, never permission to replace.
	var original: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	if original.is_empty() or JSON.parse_string(original.get_string_from_utf8()) != data: return false
	var backup_path: String = save_path + (".pre_horizon_v7.json" if int(data["npc_schema"])==7 else ".pre_living_v6.json" if int(data["npc_schema"])==6 else ".pre_causality_v5.json" if int(data["npc_schema"])==5 else ".pre_tan_dang_v4.json" if int(data["npc_schema"])==4 else ".pre_sect_v3.json" if int(data["npc_schema"])==3 else ".pre_nonlethal_v%d.json" % int(data["npc_schema"]))
	if FileAccess.file_exists(backup_path):
		return FileAccess.get_file_as_bytes(backup_path) == original
	if io._copy_file(save_path,backup_path) != OK: return false
	return FileAccess.get_file_as_bytes(backup_path) == original and FileAccess.get_file_as_bytes(save_path) == original

func save() -> bool:
	last_save_ok = false
	if read_only or compound_locked or _compound_pending() or _snapshot_schema != SCHEMA or save_path.is_empty() or not valid(snapshot()): return false
	if FileAccess.file_exists(save_path) and not valid(_read(save_path)):
		read_only = true
		return false
	if DirAccess.make_dir_recursive_absolute(save_path.get_base_dir()) != OK: return false
	var file: FileAccess = io._open_writer(save_path + ".tmp")
	if file == null: return false
	file.store_string(JSON.stringify(snapshot()))
	file.flush()
	var write_ok: bool = file.get_error() == OK
	file.close()
	if not write_ok or not valid(_read(save_path + ".tmp")): return false
	if FileAccess.file_exists(save_path):
		if io._copy_file(save_path, save_path + ".bak.tmp") != OK or not io._replace_file(save_path + ".bak.tmp", save_path + ".bak"): return false
	last_save_ok = io._replace_file(save_path + ".tmp", save_path)
	return last_save_ok
