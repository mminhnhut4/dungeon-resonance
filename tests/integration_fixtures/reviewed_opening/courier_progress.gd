extends RefCounted
## One optional supply opportunity. No main-letter completion or ending flags.

const RECEIPT: String = "opening_courier_supply_v1"
const CHOICES: Array[StringName] = [&"prepare", &"help"]
const SOURCES: Array[String] = ["pilgrim", "shrine"]

static func empty() -> Dictionary:
	return {"version": 1, "accepted": false, "contact_recorded": false, "contact_source": "", "outcome": ""}

static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5: return false
	if not value.get("version") is int and not value.get("version") is float: return false
	if float(value["version"]) != 1.0 or not value.get("accepted") is bool or not value.get("contact_recorded") is bool: return false
	if not value.get("contact_source") is String or not value.get("outcome") is String: return false
	if value["outcome"] not in ["", "prepare", "help"]: return false
	if value["contact_recorded"]:
		if not value["accepted"] or value["contact_source"] not in SOURCES: return false
	elif value["contact_source"] != "" or value["outcome"] != "": return false
	return true

static func future(value: Variant) -> bool:
	return value is Dictionary and (value.get("version") is int or value.get("version") is float) and float(value["version"]) > 1.0

static func used(value: Dictionary) -> bool:
	return valid(value) and value["accepted"]

static func with_contact(value: Dictionary, source: StringName) -> Dictionary:
	if not valid(value) or not value["accepted"] or String(source) not in SOURCES: return {}
	var result: Dictionary = value.duplicate(true)
	if not result["contact_recorded"]:
		result["contact_recorded"] = true
		result["contact_source"] = String(source)
	return result

static func with_choice(value: Dictionary, choice: StringName) -> Dictionary:
	# The resource owner stages this inside its own atomic transaction.
	if not valid(value) or not value["contact_recorded"] or choice not in CHOICES: return {}
	if value["outcome"] != "" and value["outcome"] != String(choice): return {}
	var result: Dictionary = value.duplicate(true)
	result["outcome"] = String(choice)
	return result

static func snapshot(value: Dictionary, quarantined: bool = false) -> Dictionary:
	var result: Dictionary = value.duplicate(true)
	result["available"] = not quarantined and valid(value)
	result["next_id"] = "unavailable" if not result["available"] else "offer" if not value["accepted"] else "contact" if not value["contact_recorded"] else "choice" if value["outcome"] == "" else "complete"
	result["committed_event"] = committed_event(value) if not quarantined else {}
	return result

static func committed_event(value: Dictionary) -> Dictionary:
	if not valid(value) or value["outcome"] == "": return {}
	# source_id denotes the first recorded contact, not a living witness.
	return {"receipt": RECEIPT, "outcome": value["outcome"], "source_id": "pilot_pilgrim" if value["contact_source"] == "pilgrim" else "p03_shrine_register", "recipient_id": "npc_healer"}
