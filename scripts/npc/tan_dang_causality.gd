class_name TanDangCausality
extends RefCounted
## Bounded facts inside the existing NPC sidecar, never another save owner.
const ROOMS: Array[String]=["h00_traveler_hub","o01_p03"]
const REASONS: Array[String]=["attacked","player_murder"]
const REPORT_SECONDS: float=3.0

static func empty(harmed: bool=false) -> Dictionary:
	return {"harmed":harmed,"reconciled":false,"peace_used":false,"witnesses":{"attacked":[],"player_murder":[]},"reports":[]}

static func valid(value: Variant, victim: String) -> bool:
	if not value is Dictionary or value.size()!=5:return false
	for key: String in ["harmed","reconciled","peace_used"]:
		if not value.get(key) is bool:return false
	if value["reconciled"] and (not value["peace_used"] or not value["harmed"]):return false
	var witnesses: Variant=value.get("witnesses")
	if not witnesses is Dictionary or witnesses.size()!=2:return false
	for reason: String in REASONS:
		if not witnesses.get(reason) is Array or witnesses[reason].size()>3:return false
		var seen: Array[String]=[]
		for id: Variant in witnesses[reason]:
			if not id is String or id not in NpcPilotCatalog.TAN_DANG_IDS or id in seen or (reason=="player_murder" and id==victim):return false
			seen.append(id)
	if not value.get("reports") is Array or value["reports"].size()>4:return false
	var keys: Array[String]=[]
	for report: Variant in value["reports"]:
		if not report is Dictionary or report.size()!=3 or report.get("reason") not in REASONS or report.get("room") not in ROOMS or report.get("reporter") not in witnesses[report["reason"]]:return false
		var key: String=report["reason"]+":"+report["room"]
		if key in keys:return false
		keys.append(key)
	return true

static func observe(records: Dictionary,victim: String,reason: String,observers: Array[String]) -> void:
	var memory: Dictionary=records[victim]["causality"]
	memory["harmed"]=true;memory["reconciled"]=false
	if reason=="attacked":
		if victim not in memory["witnesses"][reason]:memory["witnesses"][reason].append(victim)
	for id: String in observers:
		if id not in NpcPilotCatalog.TAN_DANG_IDS or id==victim or id in memory["witnesses"][reason]:continue
		var witness: Dictionary=records[id]
		if witness["room"]!=records[victim]["room"] or witness["mode"] in ["dead","downed","recovering"]:continue
		memory["witnesses"][reason].append(id)

static func can_report(records: Dictionary,victim: String,reason: String,reporter: String,room: String) -> bool:
	if victim not in NpcPilotCatalog.TAN_DANG_IDS or reporter not in NpcPilotCatalog.TAN_DANG_IDS or reason not in REASONS or room not in ROOMS:return false
	var record: Dictionary=records[reporter]
	var target: Dictionary=records[victim]
	if record["room"]!=room or record["mode"] not in ["rest","work","walk","flee"] or record["hp"]<=1:return false
	var memory: Dictionary=target["causality"]
	if reporter not in memory["witnesses"][reason]:return false
	if reason=="player_murder" and not target["karma"]["player_murdered"]:return false
	if reason=="attacked" and (not memory["harmed"] or memory["reconciled"]):return false
	return not public_in(target,reason,room)

static func public_in(record: Dictionary,reason: String,room: String) -> bool:
	for report: Dictionary in record.get("causality",{}).get("reports",[]):
		if report["reason"]==reason and report["room"]==room:return true
	return false

static func knows(records: Dictionary,victim: String,reason: String,listener: String) -> bool:
	if victim not in NpcPilotCatalog.TAN_DANG_IDS or listener not in NpcPilotCatalog.TAN_DANG_IDS or reason not in REASONS:return false
	var target: Dictionary=records[victim]
	if target["karma"]["grievance"]!=reason:return false
	return victim==listener or public_in(target,reason,records[listener]["room"])

static func can_reconcile(record: Dictionary) -> bool:
	return record["mode"] not in ["dead","downed","recovering"] and record["hp"]>1 and record["karma"]["spared"] and record["karma"]["grievance"]=="attacked" and not record["causality"]["peace_used"]
