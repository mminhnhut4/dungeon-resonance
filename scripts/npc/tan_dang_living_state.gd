class_name TanDangLivingState
extends RefCounted
## Finite facts only. NpcWorldState is the sole writer and life authority.
const LAM: String = "tan_dang_lam_tuoc"
const HUB: String = "h00_traveler_hub"
const P01: String = "o01_p01"
const PHASES: Array[String] = ["none","outbound","collecting","danger","returning","done"]
const OUTCOMES: Array[String] = ["","self","helped","withdrew","interrupted"]
const REASONS: Array[String] = ["quest_help","forage_help"]
const DANGER_HORIZON: float = 35.0

static func empty() -> Dictionary:
	return {"event_phase":"none","outcome":"","help_credited":false,"acknowledged":{"quest_help":false,"forage_help":false},"heard_materials":false,"convalescing":false,"danger_elapsed":0.0}

## Assistance is a historical fact even when the resident must withdraw.
## Current harm/grievance still independently blocks gratitude and greetings.
static func has_assistance(value: Dictionary) -> bool:
	return value.get("event_phase","") in ["returning","done"] and value.get("help_credited",false)==true and value.get("outcome","") in ["helped","withdrew"]

static func valid(value: Variant, id: String, record: Dictionary, schema: int = 8) -> bool:
	# Historical compound participants keep their exact six-key NPC7 shape.
	if schema not in [7,8] or not value is Dictionary or value.size()!=(7 if schema==8 else 6) or value.get("event_phase") not in PHASES or value.get("outcome") not in OUTCOMES or not value.get("help_credited") is bool or not value.get("heard_materials") is bool or not value.get("convalescing") is bool: return false
	if schema==7 and value.has("danger_elapsed"): return false
	if schema==8:
		var elapsed: Variant = value.get("danger_elapsed")
		if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or float(elapsed)<0.0 or float(elapsed)>DANGER_HORIZON: return false
		if (id!=LAM or value["event_phase"] in ["none","outbound","collecting"]) and float(elapsed)!=0.0: return false
	if id==LAM and value["heard_materials"]: return false
	var ack: Variant = value.get("acknowledged")
	if not ack is Dictionary or ack.size()!=2: return false
	for reason: String in REASONS:
		if not ack.get(reason) is bool: return false
	var phase: String = value["event_phase"]
	var outcome: String = value["outcome"]
	if value["convalescing"]:
		var hp: Variant = record.get("hp")
		if not (hp is int or hp is float) or not is_finite(float(hp)): return false
		if id!=LAM or phase!="done" or record["room"]!=HUB or float(hp)<1.0 or float(hp)>=NpcPilotCatalog.maximum_health(id): return false
	if id!=LAM and (phase!="none" or outcome!="" or value["help_credited"] or ack["forage_help"]): return false
	if phase in ["none","outbound","collecting","danger"] and outcome!="": return false
	if phase in ["returning","done"] and outcome=="": return false
	if phase in ["none","outbound","collecting"] and value["help_credited"]: return false
	if outcome=="helped" and not value["help_credited"]: return false
	if ack["forage_help"] and not has_assistance(value): return false
	if ack["quest_help"] and not (record["karma"]["rescued"] or record["karma"]["helped"]): return false
	if phase=="outbound" and record["room"]!=HUB: return false
	if phase in ["collecting","danger"] and record["room"]!=P01: return false
	if phase in ["returning","done"] and record["room"] not in [HUB,P01]: return false
	if id==LAM and record["room"]==P01 and phase in ["none","outbound"]: return false
	return true
