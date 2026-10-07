class_name HitstopManager
extends Node
## One real-time timer per active burst, with bounded deadline extensions.

@export var slow_scale: float = 0.05
@export var regular_seconds: float = 0.06
@export var heavy_seconds: float = 0.12
var request_count: int = 0
var timer_count: int = 0
var _deadline_usec: int = 0
var _timer: SceneTreeTimer


func request_hitstop(heavy: bool = false) -> void:
	if not is_inside_tree():
		return
	var duration: float = heavy_seconds if heavy else regular_seconds
	if duration <= 0.0:
		return
	request_count += 1
	_deadline_usec = maxi(_deadline_usec, Time.get_ticks_usec() + int(duration * 1000000.0))
	TimeScaleClaims.acquire(self, slow_scale)
	if _timer == null:
		_start_timer(remaining_seconds())


func is_active() -> bool:
	return _deadline_usec > Time.get_ticks_usec() and is_inside_tree()


func remaining_seconds() -> float:
	return maxf(0.0, float(_deadline_usec - Time.get_ticks_usec()) / 1000000.0)


func cancel() -> void:
	if _timer != null and _timer.timeout.is_connected(_on_timeout):
		_timer.timeout.disconnect(_on_timeout)
	_timer = null
	_deadline_usec = 0
	TimeScaleClaims.release(self)


func _start_timer(seconds: float) -> void:
	# Ignore time_scale AND tree pause; game clocks remain on normal physics delta.
	_timer = get_tree().create_timer(maxf(seconds, 0.001), true, false, true)
	_timer.timeout.connect(_on_timeout, CONNECT_ONE_SHOT)
	timer_count += 1


func _on_timeout() -> void:
	_timer = null
	var remaining: float = remaining_seconds()
	if remaining > 0.0005:
		_start_timer(remaining)
	else:
		_deadline_usec = 0
		TimeScaleClaims.release(self)


func _exit_tree() -> void:
	cancel()
