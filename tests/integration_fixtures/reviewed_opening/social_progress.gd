extends RefCounted
const NpcWorldState = preload("res://tests/integration_fixtures/reviewed_opening/social_life_owner.gd")
const NpcSocialCatalog = preload("res://tests/integration_fixtures/reviewed_opening/social_catalog.gd")
## Cost and help receipt live in the same canonical profile image. No life/clock.
const SCHEMA: int = 1

static func empty() -> Dictionary:
	return {"schema_version":SCHEMA, "receipts":{}}

static func event_id(id: String, life: String) -> String:
	return life + ":help:linen:1" if id in NpcSocialCatalog.IDS and life == NpcWorldState.life_id(id) else ""

static func valid(data: Variant) -> bool:
	if not data is Dictionary or data.size() != 2 or not (data.get("schema_version") is int or data.get("schema_version") is float) or data["schema_version"] != SCHEMA or not data.get("receipts") is Dictionary: return false
	if data["receipts"].size() > NpcSocialCatalog.IDS.size(): return false
	for id: Variant in data["receipts"]:
		if not id is String or id not in NpcSocialCatalog.IDS: return false
		var receipt: Variant = data["receipts"][id]
		if not receipt is Dictionary or receipt.size() != 2 or receipt.get("life_id") != NpcWorldState.life_id(id) or receipt.get("event_id") != event_id(id, receipt["life_id"]): return false
	return true

static func restored(data: Dictionary) -> Dictionary:
	return {"schema_version":SCHEMA,"receipts":data["receipts"].duplicate(true)} if valid(data) else empty()

static func future(data: Variant) -> bool:
	if not data is Dictionary: return false
	var schema: Variant = data.get("schema_version")
	return (schema is int or schema is float) and is_finite(float(schema)) and float(schema) > SCHEMA

static func helped(data: Dictionary, id: String) -> bool:
	return valid(data) and data["receipts"].has(id)

static func with_help(data: Dictionary, id: String, life: String) -> Dictionary:
	if not valid(data) or helped(data,id) or event_id(id,life).is_empty(): return {}
	var result: Dictionary = data.duplicate(true)
	result["receipts"][id] = {"life_id":life, "event_id":event_id(id,life)}
	return result

static func relationship(data: Dictionary, id: String, record: Dictionary) -> Dictionary:
	var spec: Dictionary = NpcSocialCatalog.definition(id) if helped(data,id) else {}
	return {"trust":clampi(int(record["trust"]) + int(spec.get("help_trust",0)),-100,100), "debt":mini(100,int(record["debt"]) + int(spec.get("help_debt",0))), "fear":int(record["fear"])}
