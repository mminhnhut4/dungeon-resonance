class_name OpeningStyleBinding
extends Node
## Existing progression owns unlocks; the ready Player owns ephemeral combat clocks.
## No InputMap mutation, save IO, gear grant, lab unlock or reward telemetry hook.
const StyleRuntime = preload("res://scripts/cultivation/cultivation_style_runtime.gd")
const PLAYER_META: StringName = &"opening_style_binding"
const STYLE_IDS: Array[String] = ["cloud_return", "tether_sigil"]
var profile: SanctuaryProfile
var flow: Node
var scene: Node2D
var player: Player
var runtime: CultivationStyleRuntime
var last_error: StringName = &""
var _room: Node2D

func initialize(permanent: SanctuaryProfile, owner_flow: Node = null) -> bool:
	if permanent == null: return false
	if profile != permanent:
		detach_scene()
		if profile != null and profile.changed.is_connected(_profile_changed): profile.changed.disconnect(_profile_changed)
		profile = permanent
		profile.changed.connect(_profile_changed)
	flow = owner_flow
	return true

func bind_scene(next_scene: Node2D) -> bool:
	if profile == null or not is_instance_valid(next_scene) or next_scene.is_queued_for_deletion() or not next_scene.is_node_ready() or (not next_scene is PrologueHub and not next_scene is DungeonRun):
		last_error = &"scene_not_ready"
		return false
	var next_player: Player = next_scene.player
	var next_room: Node2D = _room_for(next_scene)
	if not is_instance_valid(next_player) or not next_player.is_node_ready() or not is_instance_valid(next_room):
		last_error = &"actor_or_room_not_ready"
		return false
	if player != next_player or not is_instance_valid(runtime):
		detach_scene()
		# One binding owns the optional state registry entry on this existing actor.
		var prior: Variant = next_player.get_meta(PLAYER_META) if next_player.has_meta(PLAYER_META) else null
		if is_instance_valid(prior) and prior != self:
			last_error = &"actor_already_bound"
			return false
		player = next_player
		runtime = StyleRuntime.new()
		runtime.name = "OpeningCultivationStyle"
		player.add_child(runtime)
		if not runtime.initialize(player, next_room):
			_dispose_runtime()
			player = null
			last_error = &"runtime_registration_failed"
			return false
		player.set_meta(PLAYER_META, self)
	else:
		before_travel()
	_disconnect_scene()
	scene = next_scene
	_room = next_room
	if scene is PrologueHub: scene.zone_changed.connect(_zone_changed)
	runtime.bind_room(_room)
	return _apply_committed_snapshot()

func before_travel() -> void:
	# Call before old-room teardown/relocation, even when the actor is retained.
	if is_instance_valid(runtime): runtime.cancel_for_room_transition()

func refresh_room() -> bool:
	if not is_instance_valid(scene) or not is_instance_valid(runtime): return false
	var current: Node2D = _room_for(scene)
	if not is_instance_valid(current) or current.is_queued_for_deletion():
		before_travel()
		last_error = &"room_unavailable"
		return false
	if current != _room:
		runtime.bind_room(current)
		_room = current
	return true

func detach_scene() -> void:
	before_travel()
	_disconnect_scene()
	if is_instance_valid(player) and player.has_meta(PLAYER_META) and player.get_meta(PLAYER_META) == self: player.remove_meta(PLAYER_META)
	_dispose_runtime()
	scene = null
	player = null
	_room = null

func _dispose_runtime() -> void:
	if not is_instance_valid(runtime):
		runtime = null
		return
	# Removal unregisters the action synchronously, before any replacement bind.
	if runtime.get_parent() != null: runtime.get_parent().remove_child(runtime)
	runtime.queue_free()
	runtime = null

func _disconnect_scene() -> void:
	if is_instance_valid(scene) and scene is PrologueHub and scene.zone_changed.is_connected(_zone_changed): scene.zone_changed.disconnect(_zone_changed)

static func _room_for(world: Node2D) -> Node2D:
	if world is ExteriorHub and world.outside: return world.exterior
	if world is PrologueHub: return world.yard
	if world is DungeonRun: return world.room
	return null

func _zone_changed(_zone_id: StringName) -> void:
	# ExteriorHub publishes this after the destination and Player are installed.
	refresh_room()

func _profile_changed() -> void:
	_apply_committed_snapshot()

static func _abilities(value: Variant) -> Dictionary:
	# Strict small adapter contract; convert Strings to typed runtime IDs below.
	if not value is Dictionary or value.size() != 3 or value.get("version") != 1 or not value.get("learned_ids") is Array or not value.get("selected_id") is String: return {}
	var ids: Array[String] = []
	for candidate: Variant in value["learned_ids"]:
		if not candidate is String or candidate not in STYLE_IDS or candidate in ids: return {}
		ids.append(candidate)
	# The opening grants one chosen branch; it never supplies both lab unlocks.
	if ids.size() > 1: return {}
	var selected: String = value["selected_id"]
	if (ids.is_empty() and selected != "") or (not ids.is_empty() and selected not in ids): return {}
	ids.sort()
	return {"version": 1, "learned_ids": ids, "selected_id": selected}

func _apply_committed_snapshot() -> bool:
	if not is_instance_valid(runtime) or profile == null: return false
	if profile.read_only or not profile.has_method("cultivation_abilities"):
		_revoke_runtime()
		last_error = &"profile_abilities_unavailable"
		return false
	var value: Dictionary = _abilities(profile.call("cultivation_abilities"))
	if value.is_empty():
		_revoke_runtime()
		last_error = &"invalid_committed_abilities"
		return false
	var learned: Array[StringName] = []
	for id: String in value["learned_ids"]: learned.append(StringName(id))
	if not runtime.apply_progress_snapshot(learned, StringName(value["selected_id"])):
		_revoke_runtime()
		last_error = &"runtime_snapshot_rejected"
		return false
	last_error = &""
	return true

func _revoke_runtime() -> void:
	if not is_instance_valid(runtime): return
	var none: Array[StringName] = []
	runtime.apply_progress_snapshot(none, &"")

func _input_allowed() -> bool:
	if profile == null or profile.read_only or not is_instance_valid(scene) or scene.is_queued_for_deletion() or not is_instance_valid(player) or not is_instance_valid(runtime) or get_tree().paused: return false
	if not player.controls_enabled or player._resume_guard > 0 or player.health.current_health <= 0.0 or (player.hit_reaction != null and player.hit_reaction.blocks_controls()): return false
	if is_instance_valid(flow) and (flow.get("return_save_pending") == true or flow.get("_return_busy") == true or flow.get("returning") == true): return false
	if scene.get("gear") != null and scene.gear.modal.is_open: return false
	if scene is PrologueHub and (scene.inside_house or scene.station_open or (is_instance_valid(scene.dialogue) and scene.dialogue.is_open)): return false
	if scene is DungeonRun and (scene.outcome != &"" or scene.has_pending_rewards()): return false
	return true

func request_skill(target_world: Vector2) -> bool:
	if not _input_allowed() or not refresh_room():
		last_error = &"gameplay_blocked"
		return false
	var accepted: bool = runtime.request_skill(target_world)
	last_error = &"" if accepted else runtime.last_rejection
	return accepted

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo or (event.physical_keycode != KEY_G and not (event.physical_keycode == 0 and event.keycode == KEY_G)): return
	if not _input_allowed(): return
	player.aim.sample_cursor()
	request_skill(player.aim.target_position)
	get_viewport().set_input_as_handled()

func _physics_process(_delta: float) -> void:
	# Quarantine may change without a success signal. Stop an already-bound action.
	if profile != null and profile.read_only and is_instance_valid(runtime) and runtime.selected != &"": _revoke_runtime()

func _exit_tree() -> void:
	detach_scene()
	if profile != null and profile.changed.is_connected(_profile_changed): profile.changed.disconnect(_profile_changed)
