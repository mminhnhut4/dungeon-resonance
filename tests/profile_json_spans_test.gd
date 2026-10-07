extends SceneTree
## Pure text contracts: no file IO, profile mutations, actors or runtime clocks.
const Spans = preload("res://scripts/runtime/profile_json_spans.gd")
const SOCIAL: Array[String] = ["event_extensions", "namespaces", "npc_social"]
const LEGACY: Array[String] = ["npc_social_progress"]

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_exact_transport()
	_value_types()
	_authority_duplicates()
	_invalid_json()
	_absence_and_bounds()
	_unique_transaction_values()
	_many_leaves()
	print("RESULT profile_json_spans checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + label)
	else:
		print("PASS: " + label)

func _document(span: String) -> String:
	return " \n{\"event_extensions\":{\"schema_version\":1,\"namespaces\":{\"npc_social\":" + span + ",\"courier\":{\"revision\":0}}},\"souls\":7} \r\n"

func _exact_transport() -> void:
	var raw: String = " \t\r\n{\"schema_version\":2,\"n\":1.2300e+02,\"receipt\":{\"id\":\"first\",\"id\":\"second\"},\"v\":\"\\u0054hanh Vy\",\"utf\":\"Hán 🌿 漢字\"} \r\n\t"
	var legacy: String = "\n {\"receipt\":1,\"receipt\":2,\"escaped\":\"a\\\"b\\\\c\\/d\"} \t"
	var text: String = " \n {\"event_extensions\":{\"schema_version\":1,\"namespaces\":{\"npc_social\":" + raw + ",\"courier\":{\"revision\":0}}},\"souls\":7,\"npc_social_progress\":" + legacy + "} \r\n"
	var field_span: Dictionary = Spans.extract(text, SOCIAL)
	_check(field_span["ok"] and field_span["present"] and field_span["span"] == raw, "Opaque namespace preserves exact whitespace, UTF-8, escapes, exponent spelling and duplicate receipt keys")
	_check(field_span["start"] >= 0 and field_span["end"] > field_span["start"] and text.substr(field_span["start"], field_span["end"] - field_span["start"]) == raw, "Half-open offsets describe the exact opaque span")
	var legacy_span_info: Dictionary = Spans.extract(text, LEGACY)
	_check(legacy_span_info["ok"] and legacy_span_info["present"] and legacy_span_info["span"] == legacy, "Legacy and namespace opaque values coexist without rejecting inner duplicates")
	_check(Spans.replace(text, SOCIAL, raw) == text and Spans.replace(text, LEGACY, legacy) == text, "Extract and replace are byte-equivalent after UTF-8 encoding")
	var replacement: String = "\t {\"schema_version\":2,\"n\":9.00E-02,\"utf\":\"Thư 漢🌿\"} \n"
	var swapped: String = Spans.replace(text, SOCIAL, replacement)
	var expected: String = " \n {\"event_extensions\":{\"schema_version\":1,\"namespaces\":{\"npc_social\":" + replacement + ",\"courier\":{\"revision\":0}}},\"souls\":7,\"npc_social_progress\":" + legacy + "} \r\n"
	_check(swapped == expected and Spans.extract(swapped, LEGACY)["span"] == legacy, "Replacement changes only the selected leaf and its included whitespace")
	var unicode_text: String = "{\"préface\":\"漢🌿\",\"npc_social_progress\": 1e+02 \t}"
	var unicode_span: Dictionary = Spans.extract(unicode_text, LEGACY)
	_check(unicode_span["ok"] and unicode_span["span"] == " 1e+02 \t" and unicode_text.substr(0, unicode_span["start"]).to_utf8_buffer().size() > unicode_span["start"], "String offsets remain correct when UTF-8 byte offsets differ")
	var escaped_key: String = "{\"event_extensions\":{\"namespaces\":{\"npc_\\u0073ocial\": " + raw + "}}}"
	_check(Spans.extract(escaped_key, SOCIAL)["span"] == " " + raw, "Escaped authority key spelling resolves semantically without rewriting its source")
	_check(Spans.replace(escaped_key, SOCIAL, raw).contains("\"npc_\\u0073ocial\""), "Replacement preserves the original escaped authority key")

func _value_types() -> void:
	var values: Array[String] = ["null", "true", "false", "-0", "-0.00", "1e+02", "-1.2300E-09", "900719925474099312345", "\"brace } comma , slash \\/ quote \\\"\"", "[1,{\"id\":1,\"id\":2},false]", "{\"x\":0,\"x\":1}"]
	for value: String in values:
		var span: String = " \t" + value + "\r\n "
		var text: String = _document(span)
		var extracted: Dictionary = Spans.extract(text, SOCIAL)
		_check(extracted["ok"] and extracted["present"] and extracted["span"] == span, "Every JSON value type retains its raw spelling: " + value)
		_check(Spans.replace(text, SOCIAL, span) == text, "Value transport leaves the complete source unchanged: " + value)
	var original: String = _document(" {\"x\":1} ")
	_check(Spans.replace(original, SOCIAL, " null ") == _document(" null "), "Transport permits a valid replacement while the caller owns semantic matching")
	_check(Spans.replace(original, SOCIAL, " \n") == "" and Spans.replace(original, SOCIAL, "{broken") == "", "Empty or invalid replacement value cannot alter an enclosing profile")

func _authority_duplicates() -> void:
	var ambiguous: Array[String] = [
		"{\"npc_social_progress\":{},\"npc_social_progress\":{}}",
		"{\"npc_social_progress\":{},\"npc_\\u0073ocial_progress\":{}}",
		"{\"souls\":1,\"souls\":2,\"npc_social_progress\":{}}",
		"{\"event_extensions\":{},\"event_extensions\":{\"namespaces\":{\"npc_social\":{}}}}",
		"{\"event_extensions\":{\"namespaces\":{},\"namespaces\":{\"npc_social\":{}}}}",
		"{\"event_extensions\":{\"namespaces\":{\"npc_social\":{},\"npc_social\":{}}}}",
		"{\"event_extensions\":{\"namespaces\":{\"npc_social\":{},\"npc_\\u0073ocial\":{}}}}",
		"{\"event_extensions\":{\"namespaces\":{\"npc_social\":{},\"courier\":{\"revision\":1,\"revision\":2}}}}",
		"{\"rows\":[{\"id\":1,\"id\":2}],\"npc_social_progress\":{}}"
	]
	for text: String in ambiguous:
		_check(not Spans.extract(text, SOCIAL)["ok"] and not Spans.extract(text, LEGACY)["ok"], "Duplicate nonopaque authority keys make the entire enclosure ambiguous")
		_check(Spans.replace(text, SOCIAL, "{}") == "" and Spans.replace(text, LEGACY, "{}") == "", "Replacement cannot choose among duplicate authority fields")

func _invalid_json() -> void:
	var malformed: Array[String] = [
		"", "{", "{} trailing", "[1,]", "{\"x\":1,}", "{\"x\":01}", "{\"x\":+1}", "{\"x\":1.}", "{\"x\":1e}", "{\"x\":1e+}", "{\"x\":NaN}", "{\"x\":Infinity}", "{\"x\":\"\\q\"}", "{\"x\":\"\\u00xz\"}", "{\"x\":\"line\nbreak\"}", "{\"x\":/*comment*/1}", "{\"x\":[1,2}}"
	]
	for text: String in malformed:
		_check(not Spans.extract(text, SOCIAL)["ok"] and Spans.replace(text, SOCIAL, "{}") == "", "Invalid enclosing JSON is rejected without a partial value: " + text)
	var valid: String = _document(" {} ")
	for span: String in ["[1,]", "1.", "+1", "01", "true false", "{\"x\":1,}", "\"\\q\""]:
		_check(Spans.replace(valid, SOCIAL, span) == "", "Replacement grammar rejects non-JSON spelling: " + span)

func _absence_and_bounds() -> void:
	for text: String in ["{}", "{\"event_extensions\":{}}", "{\"event_extensions\":null}", "{\"event_extensions\":{\"namespaces\":[]}}", "[]", "1", "true"]:
		_check(Spans.extract(text, SOCIAL) == {"ok": true, "present": false, "span": "", "start": -1, "end": -1}, "Valid JSON with no matching object path reports absence explicitly")
		_check(Spans.replace(text, SOCIAL, "{}") == "", "Existing-leaf transport cannot append an absent authority")
	var array_path: String = "{\"event_extensions\":{\"namespaces\":[{\"npc_social\":{\"x\":1}}]}}"
	_check(not Spans.extract(array_path, SOCIAL)["present"], "String-key paths never select an object inside an array index")
	var empty: Array[String] = []
	_check(not Spans.extract("{}", empty)["ok"], "An empty authority path is not a root overwrite request")
	var deep: String = "[".repeat(66) + "0" + "]".repeat(66)
	_check(not Spans.extract(_document(deep), SOCIAL)["ok"], "Depth bound rejects excessive nesting without recursion growth")
	_check(not Spans.extract(" ".repeat(1048577) + "{}", SOCIAL)["ok"], "Oversized source is rejected before JSON parsing")

func _unique_transaction_values() -> void:
	for span: String in [" {} ", "null", " [1,{\"id\":\"a\"}] ", "{\"schema_version\":2,\"revision\":0,\"state\":{},\"receipts\":[]}"]:
		_check(Spans.unique_value(span), "Unambiguous standalone JSON may proceed to the caller's semantic validator")
	for span: String in ["{\"revision\":0,\"revision\":1}", "{\"state\":{\"help\":1,\"help\":2}}", "{\"state\":{\"help\":1,\"\\u0068elp\":2}}", "{\"receipts\":[{\"id\":\"a\",\"id\":\"b\"}]}", "{\"npc_social_progress\":{\"x\":1,\"x\":2}}", "{\"event_extensions\":{\"namespaces\":{\"npc_social\":{\"x\":1,\"x\":2}}}}", "{broken", "[1,]"]:
		_check(not Spans.unique_value(span), "Duplicate inner semantic keys are blocked for transactions even when transport preserves them")
	var duplicate: String = " {\"schema_version\":2,\"revision\":0,\"state\":{\"help\":1,\"help\":2},\"receipts\":[]} "
	_check(Spans.extract(_document(duplicate), SOCIAL)["span"] == duplicate and not Spans.unique_value(duplicate), "Opaque preservation and transaction uniqueness remain separate contracts")

func _many_leaves() -> void:
	var paths: Dictionary={"social":SOCIAL,"legacy":LEGACY}
	var raw: String="{\"event_extensions\":{\"namespaces\":{\"npc_social\": {\"n\":1e+02,\"id\":1,\"id\":2} }} ,\"npc_social_progress\": [\"漢🌿\"] }"
	var fields: Dictionary=Spans.extract_many(raw,paths)
	_check(fields["ok"] and fields["social"]==Spans.extract(raw,SOCIAL) and fields["legacy"]==Spans.extract(raw,LEGACY),"Single scan retains the same two exact opaque spans")
	var replacements: Dictionary={"social":" {\"z\":9,\"z\":10} ","legacy":" null "}
	var edited: String=Spans.replace_many(raw,paths,replacements)
	_check(not edited.is_empty() and Spans.extract(edited,SOCIAL)["span"]==replacements["social"] and Spans.extract(edited,LEGACY)["span"]==replacements["legacy"],"Descending replacements preserve both leaves without shifted offsets")
	_check(not Spans.extract_many("{\"souls\":1,\"souls\":2}",paths)["ok"] and Spans.replace_many("{}",paths,replacements).is_empty(),"Combined scan still rejects duplicate authority and absent replacements")
	_check(Spans.replace_many(raw,paths,{"legacy":"[1,]"}).is_empty(),"Combined replacement denies malformed opaque input")
