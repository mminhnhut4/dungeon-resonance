extends RefCounted
## Pure opaque-value transport. No IO, schemas, executable content or ownership.
## Spans include whitespace after ':' and before the following ',' or '}'.
## start/end are half-open String character offsets, not UTF-8 byte offsets.
## Duplicate keys are denied outside opaque social leaves; both social locations
## remain opaque when either is selected, so legacy and namespace data can coexist.
const MAX_CHARS: int = 1048576
const MAX_DEPTH: int = 64
const MAX_VALUES: int = 65536
const SOCIAL_PATHS: Array = [
	["event_extensions", "namespaces", "npc_social"],
	["npc_social_progress"]
]

class Scanner extends RefCounted:
	var text: String
	var wanted: Array[String] = []
	var cursor: int = 0
	var values: int = 0
	var found_start: int = -1
	var found_end: int = -1
	var social_opaque: bool = true
	var wanted_many: Dictionary = {}
	var found_many: Dictionary = {}

	func scan(opaque_root: bool = false) -> bool:
		if text.length() > MAX_CHARS:
			return false
		# Quiet parser validation also handles Unicode string decoding. Its parsed
		# dictionaries are never used to choose among duplicate authority keys.
		var parser := JSON.new()
		if parser.parse(text) != OK:
			return false
		var route: Array[String] = []
		if not _value(route, opaque_root, true, 0):
			return false
		_space()
		return cursor == text.length()

	func _space() -> void:
		while cursor < text.length():
			var code: int = text.unicode_at(cursor)
			if code != 32 and code != 9 and code != 13 and code != 10: break
			cursor += 1

	func _value(route: Array[String], opaque: bool, selectable: bool, depth: int) -> bool:
		values += 1
		if depth > MAX_DEPTH or values > MAX_VALUES:
			return false
		_space()
		if cursor >= text.length():
			return false
		match text[cursor]:
			"{": return _object(route, opaque, selectable, depth)
			"[": return _array(route, opaque, depth)
			"\"":
				var end: int = _string_end(cursor)
				if end < 0:
					return false
				cursor = end
				return true
			"t": return _literal("true")
			"f": return _literal("false")
			"n": return _literal("null")
			_: return _number()

	func _object(route: Array[String], opaque: bool, selectable: bool, depth: int) -> bool:
		cursor += 1
		_space()
		if cursor < text.length() and text[cursor] == "}":
			cursor += 1
			return true
		var seen: Dictionary = {}
		while cursor < text.length():
			_space()
			var key_start: int = cursor
			var key_end: int = _string_end(cursor)
			if key_end < 0:
				return false
			var key_parser := JSON.new()
			if key_parser.parse(text.substr(key_start, key_end - key_start)) != OK or not key_parser.data is String:
				return false
			var key: String = key_parser.data
			if not opaque:
				if seen.has(key):
					return false
				seen[key] = true
			cursor = key_end
			_space()
			if cursor >= text.length() or text[cursor] != ":":
				return false
			cursor += 1
			var start: int = cursor
			var child_route: Array[String] = route.duplicate()
			child_route.append(key)
			var target: bool = selectable and child_route == wanted
			var targets: Array[String] = []
			if selectable:
				for name: String in wanted_many:
					if child_route == wanted_many[name]: targets.append(name)
			var social: bool = social_opaque and selectable and child_route in SOCIAL_PATHS
			if not _value(child_route, opaque or target or not targets.is_empty() or social, selectable, depth + 1):
				return false
			_space()
			if target:
				if found_start >= 0:
					return false
				found_start = start
				found_end = cursor
			for name: String in targets:
				if found_many.has(name): return false
				found_many[name] = {"ok":true,"present":true,"span":text.substr(start,cursor-start),"start":start,"end":cursor}
			if cursor >= text.length():
				return false
			if text[cursor] == "}":
				cursor += 1
				return true
			if text[cursor] != ",":
				return false
			cursor += 1
		return false

	func _array(route: Array[String], opaque: bool, depth: int) -> bool:
		cursor += 1
		_space()
		if cursor < text.length() and text[cursor] == "]":
			cursor += 1
			return true
		while cursor < text.length():
			# Key paths do not traverse array indices, but duplicate-key validation
			# still applies to nonopaque objects contained in an array.
			if not _value(route, opaque, false, depth + 1):
				return false
			_space()
			if cursor >= text.length():
				return false
			if text[cursor] == "]":
				cursor += 1
				return true
			if text[cursor] != ",":
				return false
			cursor += 1
		return false

	func _literal(value: String) -> bool:
		if text.substr(cursor, value.length()) != value:
			return false
		cursor += value.length()
		return true

	func _digit(at: int) -> bool:
		return at < text.length() and text.unicode_at(at) >= 48 and text.unicode_at(at) <= 57

	func _number() -> bool:
		var start: int = cursor
		if text[cursor] == "-":
			cursor += 1
		if not _digit(cursor):
			return false
		if text[cursor] == "0":
			cursor += 1
		else:
			while _digit(cursor):
				cursor += 1
		if cursor < text.length() and text[cursor] == ".":
			cursor += 1
			if not _digit(cursor):
				return false
			while _digit(cursor):
				cursor += 1
		if cursor < text.length() and text[cursor] in ["e", "E"]:
			cursor += 1
			if cursor < text.length() and text[cursor] in ["+", "-"]:
				cursor += 1
			if not _digit(cursor):
				return false
			while _digit(cursor):
				cursor += 1
		return cursor > start

	func _string_end(start: int) -> int:
		if start >= text.length() or text[start] != "\"":
			return -1
		var at: int = start + 1
		while at < text.length():
			var character: int = text.unicode_at(at)
			if character == 34:
				return at + 1
			if character < 32:
				return -1
			if character == 92:
				at += 1
				if at >= text.length():
					return -1
				if text[at] == "u":
					if at + 4 >= text.length():
						return -1
					for offset: int in range(1, 5):
						if text[at + offset] not in "0123456789abcdefABCDEF":
							return -1
					at += 4
				elif text[at] not in ["\"", "\\", "/", "b", "f", "n", "r", "t"]:
					return -1
			at += 1
		return -1

static func extract(text: String, path: Array[String]) -> Dictionary:
	if path.is_empty() or path.size() > MAX_DEPTH:
		return _result(false)
	var scanner := Scanner.new()
	scanner.text = text
	scanner.wanted.assign(path)
	if not scanner.scan():
		return _result(false)
	if scanner.found_start < 0:
		return _result(true)
	return {
		"ok": true, "present": true,
		"span": text.substr(scanner.found_start, scanner.found_end - scanner.found_start),
		"start": scanner.found_start, "end": scanner.found_end
	}

static func replace(text: String, path: Array[String], span: String) -> String:
	var existing: Dictionary = extract(text, path)
	if not existing["ok"] or not existing["present"]:
		return ""
	var replacement := Scanner.new()
	replacement.text = span
	if not replacement.scan(true):
		return ""
	var result: String = text.substr(0, existing["start"]) + span + text.substr(existing["end"])
	var checked: Dictionary = extract(result, path)
	return result if checked["ok"] and checked["present"] and checked["span"] == span else ""

## One bounded validation pass for multiple leaves in the same document.
## Duplicate authority/Unicode/opaque rules use the identical scanner above.
static func extract_many(text: String, paths: Dictionary) -> Dictionary:
	var scanner := Scanner.new()
	scanner.text = text
	for name: String in paths:
		if not paths[name] is Array or paths[name].is_empty() or paths[name].size() > MAX_DEPTH: return {"ok":false}
		scanner.wanted_many[name] = paths[name]
	if not scanner.scan(): return {"ok":false}
	var result: Dictionary = {"ok":true}
	for name: String in paths: result[name] = scanner.found_many.get(name,_result(true))
	return result

static func replace_many(text: String, paths: Dictionary, spans: Dictionary) -> String:
	var existing: Dictionary = extract_many(text,paths)
	if not existing["ok"]: return ""
	var edits: Array[Dictionary] = []
	for name: String in spans:
		if not existing.has(name) or not existing[name]["present"]: return ""
		var replacement := Scanner.new()
		replacement.text = spans[name]
		if not replacement.scan(true): return ""
		edits.append({"start":existing[name]["start"],"end":existing[name]["end"],"span":spans[name]})
	edits.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a["start"] > b["start"])
	var previous_start: int = text.length()
	for edit: Dictionary in edits:
		if edit["end"] > previous_start: return ""
		text = text.substr(0,edit["start"]) + edit["span"] + text.substr(edit["end"])
		previous_start = edit["start"]
	var checked: Dictionary = extract_many(text,paths)
	if not checked["ok"]: return ""
	for name: String in spans:
		if not checked[name]["present"] or checked[name]["span"] != spans[name]: return ""
	return text

## A transaction must reject ambiguous inner data even when transport preserves it.
## No known-social exemption applies within this standalone semantic-gating value.
static func unique_value(span: String) -> bool:
	var scanner := Scanner.new()
	scanner.text = span
	scanner.social_opaque = false
	return scanner.scan(false)

static func _result(ok: bool) -> Dictionary:
	return {"ok": ok, "present": false, "span": "", "start": -1, "end": -1}
