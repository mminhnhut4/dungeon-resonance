class_name SectJourneyProgress
extends RefCounted
## Eight finite facts, one sealed extension owner; no currency or actor ownership.
const SCOPE: String="sect_journey_v1"
var profile: SanctuaryProfile

func initialize(owner: SanctuaryProfile) -> void:
	profile=owner
	profile.register_extension_validator(SCOPE,valid)

static func empty() -> Dictionary:
	return {"version":1,"thanh_van":{"accepted":false,"markers":[],"guest":false},"xich_lo":{"accepted":false,"markers":[],"guest":false}}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size()!=3 or value.get("version")!=1: return false
	for id: String in SectRouteCatalog.FACTIONS:
		var record: Variant=value.get(id)
		if not record is Dictionary or record.size()!=3 or not record.get("accepted") is bool or not record.get("guest") is bool or not record.get("markers") is Array: return false
		var seen: Array=[]
		for marker: Variant in record["markers"]:
			if not marker is String or marker not in ["west","east"] or marker in seen: return false
			seen.append(marker)
		if not record["accepted"] and (not seen.is_empty() or record["guest"]): return false
		if record["guest"] and seen.size()!=2: return false
	return true

func state() -> Dictionary:
	var saved: Dictionary=profile.extension_state(SCOPE)
	return empty() if saved.is_empty() else saved

func available() -> bool:
	return profile!=null and profile.profile_version==2 and profile.extension_transactions_available(SCOPE)

func can_enter(room: StringName) -> bool:
	var id: String=SectRouteCatalog.faction(room)
	if id.is_empty(): return true
	if not available(): return false
	var record: Dictionary=state()[id]
	return record["accepted"] and (room==SectRouteCatalog.first(id) or record["guest"])

func record(id: String, event: String) -> bool:
	if id not in SectRouteCatalog.FACTIONS or not available(): return false
	var next: Dictionary=state()
	var entry: Dictionary=next[id]
	match event:
		"accept":
			if entry["accepted"]: return true
			entry["accepted"]=true
		"west","east":
			if not entry["accepted"]: return false
			if entry["markers"].has(event): return true
			entry["markers"].append(event)
		"guest":
			if not entry["accepted"] or entry["markers"].size()!=2: return false
			if entry["guest"]: return true
			entry["guest"]=true
		_: return false
	return bool(profile.commit_extension_event(SCOPE,id+"_"+event,{},0,next,profile.extension_revision(SCOPE)).get("ok",false))

static func rows(owner: SanctuaryProfile) -> Array[Dictionary]:
	var result: Array[Dictionary]=[]
	var state_value: Dictionary=owner.extension_state(SCOPE)
	if state_value.is_empty() or not valid(state_value): return result
	for id: String in SectRouteCatalog.FACTIONS:
		var entry: Dictionary=state_value[id]
		if not entry["accepted"]: continue
		var instructions: String="Đọc hai mốc có đèn ở lối tây và đông, rồi trở lại sổ tiếp nhận cạnh chấp sự."
		if entry["markers"].size()==2: instructions="Đã ghi đủ hai mốc. Quay về sổ tiếp nhận cạnh chấp sự, chọn Trình hai ghi chép để mở sân trong."
		if entry["guest"]: instructions="Đã có quyền khách. Qua cửa đông để thăm sân trong; cửa tây đưa về đường bộ cũ."
		result.append({"id":StringName("sect_"+id),"title":("Đường phải còn người về" if id=="thanh_van" else "Giữ dòng nước thông")+" · "+str(entry["markers"].size())+"/2","body":String(SectRouteCatalog.LABELS[id])+" — "+instructions+" Quyền khách không đồng nghĩa đã gia nhập hoặc làm chưởng môn.","target":SectRouteCatalog.first(id),"done":entry["guest"],"next":not entry["guest"]})
	return result
