extends SceneTree
## Synthetic committed-owner integration; no saves, lab unlocks or project settings.
const Binding = preload("res://scripts/cultivation/opening_style_binding.gd")
const PlayerScene = preload("res://scenes/actors/player/player.tscn")
var checks: int = 0
var failures: int = 0

class CommittedProfile extends SanctuaryProfile:
	var ability_snapshot: Dictionary = {"version": 1, "learned_ids": [], "selected_id": ""}
	func cultivation_abilities() -> Dictionary:
		return ability_snapshot.duplicate(true)

class HubFixture extends PrologueHub:
	# Only the production ready Player and the adapter run in this minimal world.
	func _ready() -> void: pass
	func _process(_delta: float) -> void: pass
	func _physics_process(_delta: float) -> void: pass
	func _exit_tree() -> void: pass

func _initialize() -> void:
	call_deferred("_run")

func _check(condition: bool, label: String) -> void:
	checks += 1
	if condition: print("PASS: " + label)
	else: failures += 1; print("FAIL: " + label)

func _run() -> void:
	var actions_before: Array[StringName] = InputMap.get_actions()
	var permanent := CommittedProfile.new()
	var bank_before: Dictionary = permanent.material_stash.duplicate()
	var hub := HubFixture.new()
	hub.yard = Node2D.new(); hub.yard.name = "FirstRoom"; hub.add_child(hub.yard)
	hub.player = PlayerScene.instantiate() as Player
	hub.add_child(hub.player)
	root.add_child(hub)
	var actor: Player = hub.player
	actor.set_physics_process(false)
	actor.energy.enabled = true; actor.energy.regeneration = 0.0
	actor.energy.set_physics_process(false)
	var original_weapon: WeaponDefinition = actor.equipped_weapon.definition
	var weapons_before: Array[WeaponDefinition] = actor.available_weapons.duplicate()
	var binding := Binding.new()
	root.add_child(binding)
	binding.set_physics_process(false)
	_check(binding.initialize(permanent) and binding.bind_scene(hub), "Ready existing Player binds an empty committed ability snapshot")
	var runtime: CultivationStyleRuntime = binding.runtime
	runtime.set_physics_process(false)
	_check(runtime.get_parent() == actor and actor.get_meta(Binding.PLAYER_META) == binding, "Actor owns combat runtime; metadata exposes only the travel adapter")
	_check(actor.action_state_machine.get_state_id() == &"ready" and runtime.learned.is_empty() and runtime.selected == &"", "Binding registers an optional action without granting a branch")
	var target: Vector2 = actor.aim.global_position + Vector2(80, 0)
	_check(not binding.request_skill(target) and actor.energy.current == 100.0, "Unlearned branch cannot spend energy or activate")
	permanent.ability_snapshot = {"version": 1, "learned_ids": ["tether_sigil"], "selected_id": "tether_sigil"}
	permanent.changed.emit()
	_check(runtime.selected == &"tether_sigil" and runtime.learned == [&"tether_sigil"] and typeof(runtime.learned[0]) == TYPE_STRING_NAME, "Only committed owner change supplies typed runtime technique IDs")
	actor.controls_enabled = false
	_check(not binding.request_skill(target) and actor.energy.current == 100.0, "Disabled controls block technique input without an energy charge")
	actor.controls_enabled = true
	paused = true
	_check(not binding.request_skill(target) and actor.energy.current == 100.0, "Paused gameplay cannot request a technique")
	paused = false
	hub.station_open = true
	_check(not binding.request_skill(target) and actor.energy.current == 100.0, "Existing station modal blocks the adapter")
	hub.station_open = false
	var motion := InputEventMouseMotion.new()
	motion.position = actor.get_canvas_transform() * target
	actor.aim._input(motion)
	var key := InputEventKey.new(); key.physical_keycode = KEY_G; key.pressed = true
	binding._unhandled_key_input(key)
	_check(actor.action_state_machine.get_state_id() == &"cultivation_skill" and actor.energy.current == 82.0 and runtime.cooldowns[&"tether_sigil"] == 5.0, "Ephemeral physical G activates the committed technique and its actual combat cost")
	key.echo = true; binding._unhandled_key_input(key)
	_check(actor.energy.current == 82.0, "Repeated key echo cannot create another activation")
	runtime.advance_skill(0.31)
	_check(is_instance_valid(runtime.mark) and runtime.mark.get_parent() == hub.yard, "Actual runtime creates the mark under the bound room")
	var mark_id: int = runtime.mark.get_instance_id()
	permanent.changed.emit()
	_check(is_instance_valid(runtime.mark) and runtime.mark.get_instance_id() == mark_id, "Unrelated committed-profile publication leaves the existing technique intact")
	var runtime_id: int = runtime.get_instance_id()
	binding.before_travel()
	_check(runtime.mark == null and runtime.counter_remaining == 0.0 and actor.action_state_machine.get_state_id() == &"ready", "Before travel cancels mark, counter ticket and optional action")
	_check(actor.energy.current == 82.0 and runtime.cooldowns[&"tether_sigil"] == 5.0, "Travel cancellation retains spent energy and committed cooldown")
	var next_room := Node2D.new(); next_room.name = "SecondRoom"; hub.add_child(next_room)
	hub.yard = next_room; hub.zone_changed.emit(&"yard")
	_check(binding.runtime.get_instance_id() == runtime_id and runtime._room == next_room, "Zone publication rebinds room while retaining the same actor runtime")
	_check(actor.energy.current == 82.0 and runtime.cooldowns[&"tether_sigil"] == 5.0, "Room rebinding neither refunds energy nor resets cooldown")
	permanent.ability_snapshot = {"version": 1, "learned_ids": ["cloud_return"], "selected_id": "cloud_return"}
	permanent.changed.emit()
	_check(runtime.selected == &"cloud_return" and runtime.cooldowns[&"tether_sigil"] == 5.0, "Committed branch change revokes old selection and retains prior cooldown")
	_check(not binding.request_skill(target) and actor.energy.current == 82.0, "Sword branch cannot synthesize a dash counter ticket")
	permanent.ability_snapshot = {"version": 1, "learned_ids": ["cloud_return", "tether_sigil"], "selected_id": "cloud_return"}
	permanent.changed.emit()
	_check(runtime.learned.is_empty() and runtime.selected == &"" and binding.last_error == &"invalid_committed_abilities", "Malformed two-branch opening snapshot fails closed")
	permanent.ability_snapshot = {"version": 1, "learned_ids": ["tether_sigil"], "selected_id": "tether_sigil"}
	permanent.changed.emit()
	permanent.read_only = true; binding._physics_process(0.0)
	_check(runtime.learned.is_empty() and not binding.request_skill(target), "Quarantined profile revokes active input without a save-success signal")
	_check(actor.equipped_weapon.definition == original_weapon and actor.available_weapons == weapons_before, "Binding preserves the existing gear-driven weapon/catalyst architecture")
	_check(InputMap.get_actions() == actions_before and permanent.material_stash == bank_before and permanent.souls == 0, "Adapter adds no InputMap action, bank mutation or telemetry reward")
	binding.detach_scene()
	_check(not actor.has_meta(Binding.PLAYER_META) and actor.action_state_machine.get_state_id() == &"ready" and binding.runtime == null, "Detach removes travel ownership and optional runtime synchronously")
	permanent.read_only = false; permanent.ability_snapshot = {"version": 1, "learned_ids": [], "selected_id": ""}
	_check(binding.bind_scene(hub), "Actor may rebind after registry cleanup without duplicate state ownership")
	binding.detach_scene(); binding.queue_free(); hub.queue_free()
	await process_frame
	await process_frame
	print("RESULT OpeningStyleBinding checks=%d failures=%d" % [checks, failures])
	quit(0 if failures == 0 else 1)
