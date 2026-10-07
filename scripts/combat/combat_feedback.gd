class_name CombatFeedback
extends Node
## Room-owned feedback. Legacy local clocks stay available to isolated fixtures.

@export var camera: Camera2D
@export var hit_stop_seconds: float = 0.05
@export var shake_duration: float = 0.16
@export var shake_strength: float = 2.5
var hit_stop_remaining: float = 0.0
var shake_remaining: float = 0.0
var impact_count: int = 0
var _frozen_this_tick: bool = false
var _last_attack_id: int = -1
var _rng := RandomNumberGenerator.new()
var global_hitstop_enabled: bool = false
var hitstop_manager: HitstopManager
var _recent_global_roots: Dictionary[int, bool] = {}
const MAX_RECENT_ROOTS: int = 64


func _ready() -> void:
	process_physics_priority = -100
	_rng.randomize()


func _physics_process(delta: float) -> void:
	if global_hitstop_enabled:
		_frozen_this_tick = is_instance_valid(hitstop_manager) and hitstop_manager.is_active()
		hit_stop_remaining = hitstop_manager.remaining_seconds() if _frozen_this_tick else 0.0
	else:
		_frozen_this_tick = hit_stop_remaining > 0.000001
		hit_stop_remaining = maxf(0.0, hit_stop_remaining - delta)
		if hit_stop_remaining < 0.000001:
			hit_stop_remaining = 0.0
	shake_remaining = maxf(0.0, shake_remaining - delta)


func is_frozen() -> bool:
	if global_hitstop_enabled:
		# Do not retain one extra scaled local freeze after the real-time release.
		return is_instance_valid(hitstop_manager) and hitstop_manager.is_active()
	return _frozen_this_tick


func enable_global_hitstop(enabled: bool = true) -> void:
	reset_feedback()
	global_hitstop_enabled = enabled
	if enabled and not is_instance_valid(hitstop_manager):
		hitstop_manager = HitstopManager.new()
		hitstop_manager.name = "RealtimeHitstop"
		add_child(hitstop_manager)


func on_hit_confirmed(event: DamageEvent, result: DamageResult) -> void:
	var impact_id: int = event.root_event_id if event.root_event_id > 0 else event.attack_id
	if result.blocked or result.actual_damage <= 0.0 or event.source_kind == DamageEvent.SourceKind.DOT:
		return
	var heavy: bool = _is_heavy_impact(event)
	if global_hitstop_enabled and _recent_global_roots.has(impact_id):
		# A slash may first hit a Slime, then a Boss. Upgrade that burst once.
		if heavy and not _recent_global_roots[impact_id] and hitstop_manager.is_active() and hit_stop_seconds > 0.0:
			_recent_global_roots[impact_id] = true
			hitstop_manager.request_hitstop(true)
		return
	if not global_hitstop_enabled and impact_id == _last_attack_id:
		return
	_last_attack_id = impact_id
	impact_count += 1
	if global_hitstop_enabled:
		if _recent_global_roots.size() >= MAX_RECENT_ROOTS:
			_recent_global_roots.erase(_recent_global_roots.keys()[0])
		_recent_global_roots[impact_id] = heavy
		if hit_stop_seconds > 0.0 and (event.melee_hit or event.critical or event.heavy_hit):
			hitstop_manager.request_hitstop(heavy)
		hit_stop_remaining = hitstop_manager.remaining_seconds() if hitstop_manager.is_active() else 0.0
	else:
		hit_stop_remaining = maxf(hit_stop_remaining, hit_stop_seconds)
	_frozen_this_tick = hit_stop_remaining > 0.0
	shake_remaining = shake_duration
	if is_instance_valid(camera) and camera.has_method("add_shake"):
		camera.call("add_shake", 0.2 if event.melee_hit or event.spell_id.is_empty() else 0.4)


func _is_heavy_impact(event: DamageEvent) -> bool:
	if event.critical or event.heavy_hit:
		return true
	var target: Node = instance_from_id(event.target_id) as Node if event.target_id > 0 else null
	return is_instance_valid(target) and target.is_in_group(&"bosses")


func notify_spell_explosion() -> void:
	if is_instance_valid(camera) and camera.has_method("add_shake"):
		camera.call("add_shake", 0.4)


func notify_boss_stomp() -> void:
	if is_instance_valid(camera) and camera.has_method("add_shake"):
		camera.call("add_shake", 0.7)


func _process(_delta: float) -> void:
	if camera == null:
		return
	if camera.has_method("add_shake"):
		return # PlayerCamera combines its noise offset with independent lookahead.
	var strength: float = shake_strength * clampf(shake_remaining / maxf(shake_duration, 0.001), 0.0, 1.0)
	camera.offset = Vector2(_rng.randf_range(-strength, strength), _rng.randf_range(-strength, strength)) if strength > 0.0 else Vector2.ZERO


func reset_feedback() -> void:
	hit_stop_remaining = 0.0
	shake_remaining = 0.0
	_frozen_this_tick = false
	_last_attack_id = -1
	_recent_global_roots.clear()
	if is_instance_valid(hitstop_manager):
		hitstop_manager.cancel()
	if is_instance_valid(camera):
		if camera.has_method("reset_shake"):
			camera.call("reset_shake")
		else:
			camera.offset = Vector2.ZERO


func _exit_tree() -> void:
	reset_feedback()
