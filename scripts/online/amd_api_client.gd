class_name AmdApiClient
extends Node
## HTTPRequest is polled asynchronously by Godot; no synchronous sockets/waits.
signal completed(tag: String, status: int, body: Dictionary, problem: String)
var base_url: String = "http://127.0.0.1:5086"
var access_token: String = ""
var generation: int = 0
var _requests: Array[HTTPRequest] = []

func configure(url: String) -> bool:
	var clean: String = url.trim_suffix("/")
	var pattern := RegEx.new()
	pattern.compile("^https://[A-Za-z0-9.-]+(:[0-9]{1,5})?$|^http://(127\\.0\\.0\\.1|localhost|\\[::1\\])(:[0-9]{1,5})?$")
	if pattern.search(clean) == null: return false
	base_url = clean
	return true

func forget_account() -> void:
	generation += 1
	access_token = ""
	for request: HTTPRequest in _requests:
		request.cancel_request()
		request.queue_free()
	_requests.clear()

func send(tag: String, route: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}, operation: String = "") -> bool:
	if _requests.size() >= 4 or not route.begins_with("/"): return false
	var request := HTTPRequest.new()
	request.timeout = 8.0
	request.body_size_limit = 1200000
	request.accept_gzip = false
	add_child(request)
	_requests.append(request)
	request.request_completed.connect(_done.bind(request, tag, generation), CONNECT_ONE_SHOT)
	var headers := PackedStringArray(["Accept: application/json", "Content-Type: application/json"])
	if access_token != "": headers.append("Authorization: Bearer " + access_token)
	if operation != "": headers.append("Idempotency-Key: " + operation)
	# Persisted pending JSON is parsed as floats. Emit integral envelope values
	# as JSON integer tokens for ASP.NET int/long, leaving opaque save TEXT exact.
	var encoded: String = "" if body.is_empty() else preload("res://scripts/runtime/profile_commit_writer.gd").canonical(body)
	var error: Error = request.request(base_url + route, headers, method, encoded)
	if error != OK:
		_requests.erase(request)
		request.queue_free()
		return false
	return true

func _done(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray, request: HTTPRequest, tag: String, epoch: int) -> void:
	_requests.erase(request)
	request.queue_free()
	if epoch != generation: return
	var data: Variant = JSON.parse_string(bytes.get_string_from_utf8()) if not bytes.is_empty() else {}
	var parsed: Dictionary = data if data is Dictionary else {}
	var problem: String = ""
	if result != HTTPRequest.RESULT_SUCCESS: problem = "network_timeout_or_unavailable"
	elif status >= 400: problem = str(parsed.get("title", "http_" + str(status)))
	elif not data is Dictionary: problem = "invalid_server_response"
	completed.emit(tag, status, parsed, problem)
