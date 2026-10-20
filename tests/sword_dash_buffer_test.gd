extends SceneTree
## Headless contract fixture, not an earned-save/native encounter.
## Actual Player/Input/FSM/Weapon and test_level collisions; explicit test placement,
## disabled AI/survival, isolated damage source, and two fixture equipment UIDs.
## --headless --fixed-fps 60 --script res://tests/sword_dash_buffer_test.gd
## -- --hz=60 --expect-buffer=false (baseline) / true (candidate); also run at120.

var level: Node2D
var player: Player
var weapon: Weapon
var damage_source: Node2D
var expect_buffer: bool = false
var checks: int = 0
var failures: int = 0
var case_id: String = "setup"
var events: Array[Dictionary] = []
var commits: Array[Dictionary] = []
var active_starts: Array[Dictionary] = []
var previous_active: bool = false
var active_during_dash: int = 0
var commits_during_dash: int = 0
var original_uid: int = 0
var second_uid: int = 0
var dash_exit_tick: int = -1

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() != "headless":
		push_error("Sword dash fixture requires headless; this is not native approval.")
		quit(2)
		return
	var expectation_supplied: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
		elif argument in ["--expect-buffer=true", "--expect-buffer=false"]:
			expect_buffer = argument.ends_with("true")
			expectation_supplied = true
	if not expectation_supplied or Engine.physics_ticks_per_second not in [60, 120]:
		push_error("Require --hz=60/120 and explicit --expect-buffer=true/false.")
		quit(2)
		return
	level = (load("res://scenes/test_level.tscn") as PackedScene).instantiate()
	root.add_child(level)
	current_scene = level
	player = level.player
	weapon = player.equipped_weapon
	level.survival.set_enabled(false)
	level.survival.director.automatic = false
	level.combat_feedback.hit_stop_seconds = 0.0
	player.energy.enabled = true
	player.energy.regeneration = 0.0
	player.gear_switch_enabled = false
	player.resonance_controller.casting_enabled = false
	for enemy: SlimeEnemy in level.enemies:
		enemy.ai_enabled = false
	damage_source = Node2D.new()
	damage_source.name = "SwordBufferSyntheticDamageSource"
	root.add_child(damage_source)
	original_uid = level.gear.inventory.equipped_weapon_uid
	# Explicit fixture item creation, never a player save or native evidence.
	second_uid = level.gear.inventory.add_item(&"weapon", &"ancient_sword").uid
	player.action_state_machine.state_changed.connect(_state_changed)
	weapon.attack_committed.connect(_committed)
	await _step(3)
	_check(weapon.definition.id == &"ancient_sword", "Actual Common sword timeline is used")
	_check(is_equal_approx(player.motor.dash_duration, 0.16), "Authored160ms dash unchanged")
	await _positive("late_first_eligible", 0.08, false, false)
	await _positive("late_expiry_tick", 1.0 / Engine.physics_ticks_per_second + 0.000001, false, false)
	await _positive("late_held", 0.08, true, false)
	await _positive("late_repeated", 0.08, false, true)
	await _early()
	await _no_tap()
	await _ready_control()
	for cancel_kind: String in ["wall", "hurt", "dead", "suspend", "relocate", "reset", "same_definition_uid"]:
		await _cancel_case(cancel_kind)
	await _disabled_controls()
	await _hitstop()
	await _disabled_during_hitstop()
	_check(commits_during_dash == 0, "No commit while motor is dashing")
	_check(active_during_dash == 0, "No active hitbox while motor is dashing")
	_release()
	case_id = "teardown"
	level.queue_free()
	damage_source.queue_free()
	await _step(4)
	player = null
	weapon = null
	level = null
	damage_source = null
	var receipt: Dictionary = {
		"scope": "Headless contract fixture; positioned actual Player, disabled AI/survival, synthetic resolved damage and fixture gear UIDs. No earned/native gameplay claim.",
		"hz": Engine.physics_ticks_per_second, "expect_buffer": expect_buffer,
		"checks": checks, "failures": failures, "events": events,
		"commits_during_dash": commits_during_dash, "active_during_dash": active_during_dash,
		"unsupported": "Direct Weapon.equip(same definition) without owner lifecycle is not covered.",
	}
	var output_root: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	if not output_root.is_empty():
		DirAccess.make_dir_recursive_absolute(output_root)
		var output: FileAccess = FileAccess.open(output_root.path_join("sword-dash-buffer.json"), FileAccess.WRITE)
		_check(output != null, "Evidence file opens in explicit QA evidence root")
		if output != null:
			receipt["checks"] = checks
			receipt["failures"] = failures
			output.store_string(JSON.stringify(receipt, "\t"))
			output.close()
	print("RESULT: %d checks, %d failures; expect_buffer=%s; hz=%d" % [checks, failures, expect_buffer, Engine.physics_ticks_per_second])
	call_deferred("quit", 0 if failures == 0 else 1)

func _prepare(id: String, position_world: Vector2 = Vector2(500, 100)) -> void:
	_release()
	case_id = "prepare"
	player.controls_enabled = true
	player.reset_movement_at(position_world)
	level.combat_feedback.reset_feedback()
	level.combat_feedback.hit_stop_seconds = 0.0
	var inventory: GearInventory = level.gear.inventory
	inventory.explicit_weapon_selection = true
	inventory.equipped_weapon_uid = original_uid
	inventory.changed.emit()
	await _step(3)
	case_id = id
	commits.clear()
	active_starts.clear()
	previous_active = false
	dash_exit_tick = -1
	_check(player.action_state_machine.get_state_id() == &"ready", id + ": starts ready")

func _start_dash() -> void:
	_press(&"move_right")
	_press(&"dash")
	await _step(1)
	Input.action_release(&"dash")
	Input.action_release(&"move_right")
	_check(player.motor.is_dashing and player.action_state_machine.get_state_id() == &"dash", case_id + ": actual Input accepts dash")
	_check(is_equal_approx(player.energy.current, player.energy.maximum - 25.0), case_id + ": actual dash pays25mana")

func _wait_remaining(maximum: float) -> void:
	for frame: int in Engine.physics_ticks_per_second:
		if not player.motor.is_dashing or player.motor.dash_remaining <= maximum:
			break
		await _step(1)
	_check(player.motor.is_dashing and player.motor.dash_remaining > 0.0 and player.motor.dash_remaining <= maximum + 0.000001, case_id + ": requested natural clock boundary reached")

func _tap_attack() -> void:
	_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")

func _positive(id: String, remaining: float, held: bool, repeated: bool) -> void:
	await _prepare(id)
	await _start_dash()
	await _wait_remaining(remaining)
	_check(player.motor.dash_remaining <= 0.080001, id + ": tap falls inside final80ms")
	_press(&"attack")
	await _step(1)
	if not held:
		Input.action_release(&"attack")
	if repeated:
		# All extra presses happen before expiry; none can queue combo in Attack.
		await _step(1)
		if player.motor.is_dashing and player.motor.dash_remaining > 2.0 / Engine.physics_ticks_per_second:
			await _tap_attack()
			_check(player.motor.is_dashing, id + ": second tap stays inside dash")
	await _time(0.8)
	Input.action_release(&"attack")
	_check(commits.size() == (1 if expect_buffer else 0), id + ": exactly expected commit count")
	_check(active_starts.size() == (1 if expect_buffer else 0), id + ": exactly expected active window count")
	if expect_buffer and commits.size() == 1 and active_starts.size() == 1:
		var commit: Dictionary = commits[0]
		_check(int(commit["combo_index"]) == 0, id + ": only first sword step, no automatic combo")
		_check(int(commit["tick"]) == dash_exit_tick, id + ": commits on natural dash exit tick")
		_check(is_equal_approx(float(commit["phase_remaining"]), float(commit["windup"])), id + ": commit starts with full authored windup")
		var elapsed: float = float(int(active_starts[0]["tick"]) - int(commit["tick"])) / Engine.physics_ticks_per_second
		_check(elapsed + 0.000001 >= float(commit["windup"]), id + ": active hitbox waits full windup after commit")

func _early() -> void:
	await _prepare("early_outside_window")
	await _start_dash()
	var dt: float = 1.0 / Engine.physics_ticks_per_second
	await _wait_remaining(0.08 + dt)
	_check(player.motor.dash_remaining > 0.08, "Early tap is outside80ms before motor tick")
	await _tap_attack()
	await _time(0.8)
	_check(commits.is_empty() and active_starts.is_empty(), "Early tap never becomes a future attack")

func _no_tap() -> void:
	await _prepare("no_attack_tap")
	await _start_dash()
	await _time(0.8)
	_check(commits.is_empty() and active_starts.is_empty(), "Dash without attack input does not attack")

func _ready_control() -> void:
	await _prepare("ready_tap_control")
	await _tap_attack()
	await _time(0.8)
	_check(commits.size() == 1 and active_starts.size() == 1, "Existing ready-state attack still works on both builds")

func _cancel_case(kind: String) -> void:
	var origin: Vector2 = Vector2(1128, 100) if kind == "wall" else Vector2(500, 100)
	await _prepare("cancel_" + kind, origin)
	await _start_dash()
	await _wait_remaining(0.08)
	await _tap_attack()
	_check(player.motor.is_dashing, case_id + ": cancellation starts after queued tap, before expiry")
	match kind:
		"wall":
			for frame: int in 12:
				if not player.motor.is_dashing:
					break
				await _step(1)
			_check(player.is_on_wall() and not player.motor.is_dashing, "Actual room wall cancels dash before natural expiry")
		"hurt", "dead":
			await _wait_remaining(0.04)
			_check(not player.hurtbox.invulnerable, case_id + ": authored dash i-frame has expired")
			var damage: DamageEvent = _damage(9999.0 if kind == "dead" else 30.0)
			var result: DamageResult = player.hurtbox.take_damage(damage)
			_check(not result.blocked and result.actual_damage > 0.0, case_id + ": real resolver accepts synthetic test hit")
			_check(player.action_state_machine.get_state_id() == (&"dead" if kind == "dead" else &"hurt"), case_id + ": actual damage enters cancellation state")
		"suspend":
			player.suspend_controls(true)
			await _step(1)
			player.suspend_controls(false)
		"relocate":
			player.relocate(Vector2(500, 100))
		"reset":
			player.reset_movement_at(Vector2(500, 100))
		"same_definition_uid":
			var before_definition: WeaponDefinition = weapon.definition
			var inventory: GearInventory = level.gear.inventory
			inventory.explicit_weapon_selection = true
			inventory.equipped_weapon_uid = second_uid
			inventory.changed.emit()
			_check(second_uid != original_uid and weapon.definition == before_definition and level.gear._applied_weapon_uid == second_uid, "GearSession applies distinct UID with the same sword definition")
			_check(player.action_state_machine.get_state_id() == &"ready", "Real UID owner exits dash without a fake weapon_changed signal")
	await _time(0.85)
	_check(commits.is_empty() and active_starts.is_empty(), case_id + ": cancellation leaves no latent attack")

func _disabled_controls() -> void:
	await _prepare("disabled_controls_latch")
	await _start_dash()
	await _wait_remaining(0.08)
	await _tap_attack()
	player.controls_enabled = false
	await _step(1)
	player.controls_enabled = true
	await _time(0.8)
	_check(commits.is_empty(), "One disabled-controls tick discards buffer even if reenabled before expiry")

func _hitstop() -> void:
	await _prepare("hitstop_game_clock")
	await _start_dash()
	await _wait_remaining(0.08)
	var before: float = player.motor.dash_remaining
	level.combat_feedback.enable_global_hitstop(false)
	level.combat_feedback.hit_stop_seconds = 0.06
	var damage: DamageEvent = _damage(1.0)
	var result := DamageResult.new()
	result.actual_damage = 1.0
	level.combat_feedback.on_hit_confirmed(damage, result)
	_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")
	_check(is_equal_approx(player.motor.dash_remaining, before) and commits.is_empty(), "Hitstop preserves dash clock and does not commit attack")
	await _time(0.9)
	_check(commits.size() == (1 if expect_buffer else 0), "Press sampled during hitstop respects final80ms gameplay window")
	level.combat_feedback.reset_feedback()
	level.combat_feedback.hit_stop_seconds = 0.0

func _disabled_during_hitstop() -> void:
	await _prepare("disabled_controls_during_hitstop")
	await _start_dash()
	await _wait_remaining(0.08)
	var before: float = player.motor.dash_remaining
	level.combat_feedback.enable_global_hitstop(false)
	level.combat_feedback.hit_stop_seconds = 0.12
	var damage: DamageEvent = _damage(1.0)
	var result := DamageResult.new()
	result.actual_damage = 1.0
	level.combat_feedback.on_hit_confirmed(damage, result)
	_press(&"attack")
	await _step(1)
	Input.action_release(&"attack")
	_check(level.combat_feedback.is_frozen() and is_equal_approx(player.motor.dash_remaining, before), "Combined case samples late tap on an actually frozen tick")
	player.controls_enabled = false
	await _step(1)
	_check(level.combat_feedback.is_frozen(), "Controls disable is observed during hitstop")
	player.controls_enabled = true
	await _step(1)
	_check(level.combat_feedback.is_frozen() and player.motor.is_dashing, "Controls reenable before hitstop/dash ends, without another attack press")
	await _time(0.9)
	_check(commits.is_empty() and active_starts.is_empty(), "Canceled frozen pending tap cannot rearm or attack after clocks resume")
	level.combat_feedback.reset_feedback()
	level.combat_feedback.hit_stop_seconds = 0.0

func _damage(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = damage_source.get_instance_id()
	event.source_team_id = 2
	event.target_id = player.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	event.hit_reaction = &"knockback"
	event.heavy_hit = true
	event.attack_direction = Vector2.LEFT
	event.knockback = Vector2(-20, 0)
	return event

func _press(action: StringName) -> void:
	events.append({"case": case_id, "event": "input", "action": String(action), "tick": Engine.get_physics_frames(), "state": String(player.action_state_machine.get_state_id()), "dash_remaining": player.motor.dash_remaining})
	Input.action_press(action)

func _state_changed(previous: StringName, next: StringName) -> void:
	if previous == &"dash":
		dash_exit_tick = Engine.get_physics_frames()
	events.append({"case": case_id, "event": "state", "from": String(previous), "to": String(next), "tick": Engine.get_physics_frames(), "dash_remaining": player.motor.dash_remaining, "is_dashing": player.motor.is_dashing})

func _committed(snapshot: AttackSnapshot) -> void:
	var entry: Dictionary = {"case": case_id, "event": "commit", "tick": Engine.get_physics_frames(), "attack_id": snapshot.attack_id, "combo_index": weapon.combo_index, "is_dashing": player.motor.is_dashing, "phase_remaining": weapon._phase_remaining, "windup": weapon.definition.combo_steps[weapon.combo_index].windup_seconds}
	events.append(entry)
	commits.append(entry)
	if player.motor.is_dashing:
		commits_during_dash += 1

func _step(count: int) -> void:
	for frame: int in count:
		await physics_frame
		await process_frame
		if not is_instance_valid(player) or not is_instance_valid(weapon):
			continue
		var active: bool = weapon.hitbox.active
		if active and player.motor.is_dashing:
			active_during_dash += 1
		if active != previous_active:
			var entry: Dictionary = {"case": case_id, "event": "active_start" if active else "active_end", "tick": Engine.get_physics_frames(), "is_dashing": player.motor.is_dashing, "phase_remaining": weapon._phase_remaining}
			events.append(entry)
			if active:
				active_starts.append(entry)
		previous_active = active

func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))

func _release() -> void:
	for action: StringName in [&"move_left", &"move_right", &"attack", &"dash", &"jump", &"spell_cast", &"switch_weapon"]:
		Input.action_release(action)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])
