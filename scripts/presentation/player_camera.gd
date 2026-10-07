class_name PlayerCamera
extends Camera2D
## Lookahead owns position; bounded trauma noise owns offset only while active.

@export var follow_enabled: bool = true
@export var lookahead_limit: float = 40.0
@export var lookahead_speed: float = 8.0
var lookahead: Vector2 = Vector2.ZERO
var base_position: Vector2 = Vector2(0, -40)
@export_range(0.0, 1.0) var shake_intensity: float = 1.0
@export var max_shake_offset: Vector2 = Vector2(12.0, 8.0)
@export var trauma_decay: float = 2.2
@export var noise_speed: float = 18.0
var trauma: float = 0.0
var _noise := FastNoiseLite.new()
var _noise_clock: float = 0.0
var _shake_active: bool = false
var _last_process_usec: int = 0


func _ready() -> void:
	_noise.seed = int(get_instance_id() % 2147483647)
	_noise.frequency = 1.0
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_last_process_usec = Time.get_ticks_usec()

func _process(delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var real_delta: float = float(now - _last_process_usec) / 1000000.0 if _last_process_usec > 0 else delta
	_last_process_usec = now
	advance_shake(real_delta)
	if not follow_enabled:
		return
	var actor: Node2D = get_parent() as Node2D
	var aim: PlayerAim = actor.get_node_or_null("Combat/Aim") as PlayerAim if actor != null else null
	if actor == null or not is_instance_valid(aim):
		return
	var target: Vector2 = ((aim.target_position - actor.global_position) * 0.15).limit_length(lookahead_limit)
	lookahead = lookahead.lerp(target, 1.0 - exp(-lookahead_speed * delta))
	position = base_position + lookahead


func add_shake(amount: float) -> void:
	trauma = clampf(trauma + maxf(amount, 0.0), 0.0, 1.0)
	_shake_active = trauma > 0.0


func shake_amplitude() -> float:
	return trauma * trauma * shake_intensity


func advance_shake(real_delta: float) -> void:
	if not _shake_active:
		return
	var delta: float = clampf(real_delta, 0.0, 0.25)
	_noise_clock += delta * noise_speed
	var amplitude: float = shake_amplitude()
	var sample := Vector2(_noise.get_noise_2d(0.0, _noise_clock), _noise.get_noise_2d(31.0, _noise_clock))
	var target: Vector2 = sample * max_shake_offset * amplitude
	offset = offset.lerp(target, 1.0 - exp(-35.0 * delta))
	trauma = maxf(0.0, trauma - trauma_decay * delta)
	if trauma <= 0.00001 or shake_intensity <= 0.0:
		reset_shake()


func reset_shake() -> void:
	trauma = 0.0
	_shake_active = false
	offset = Vector2.ZERO


func _exit_tree() -> void:
	reset_shake()
