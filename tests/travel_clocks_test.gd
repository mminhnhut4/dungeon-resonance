extends SceneTree
## Existing safe/intra-expedition travel contracts; not the blocked exterior layout.
class FailedCommitProfile extends SanctuaryProfile:
	var reject_commit: bool = false
	func _replace_file(temporary: String, target: String) -> bool:
		if reject_commit: return false
		return super._replace_file(temporary, target)
	func _open_writer(path: String) -> FileAccess:
		# Root-2 journal commits use the same IO host, without the v1 replace hook.
		if reject_commit: return null
		return super._open_writer(path)

var checks: int = 0
var failures: int = 0
var gpu: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	gpu = DisplayServer.get_name() != "headless"
	if gpu:
		root.size = Vector2i(1152, 648)
		root.content_scale_size = Vector2i(1280, 720)
		AudioServer.set_bus_mute(0, true)
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = "user://verification/travel_clocks_%d_%d_%d.json" % [Engine.physics_ticks_per_second,OS.get_process_id(),Time.get_ticks_usec()]
	root.add_child(flow)
	current_scene = flow
	await _step(12)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	hub.feedback.hit_stop_seconds = 0.0
	var actor: Player = hub.player
	var inventory: GearInventory = hub.gear.inventory
	var owned: Array = inventory.items.keys()
	flow.profile.coins = 700
	inventory.run_coins = 13
	inventory.changed.emit()
	_check(flow.profile.save(), "Isolated safe inventory checkpoint saves")
	actor.health.current_health = 37.0
	actor.energy.current = 41.0
	actor.energy.regeneration_delay = 100.0
	actor.damage_grace_remaining = 0.32
	for cycle: int in 3:
		actor.motor.dash_cooldown_remaining = 0.55
		actor.motor.air_dash_available = false
		(actor.motor as BuildPlayerMotor).air_dashes_used = 1
		actor.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"basic_bolt"] = 7.5
		_check(hub.enter_house(), "Safe A->B enters existing home, cycle %d" % cycle)
		_check(hub.player == actor and hub.gear.inventory == inventory and inventory.items.keys() == owned, "Safe travel retains one actor, one ledger and exact UIDs")
		_check(actor.health.current_health == 37.0 and actor.energy.current == 41.0 and actor.damage_grace_remaining == 0.32, "Safe travel cannot heal/refill or erase damage grace")
		_check(actor.motor.dash_cooldown_remaining == 0.55 and not actor.motor.air_dash_available and (actor.motor as BuildPlayerMotor).air_dashes_used == 1, "Safe travel preserves committed dash and consumed air charges")
		_check(actor.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"basic_bolt"] == 7.5, "Safe travel preserves recipe cooldown")
		var camera: Camera2D = actor.get_node("Camera2D") as Camera2D
		_check(camera.limit_left == 3200 and camera.limit_right == 4480, "Home entry applies its real camera bounds")
		_check(hub.leave_house(), "Safe B->A returns to existing yard")
		_check(actor.motor.dash_cooldown_remaining == 0.55 and actor.health.current_health == 37.0 and actor.energy.current == 41.0, "Immediate roundtrip has no free dash, HP or energy")
		_check(flow.profile.coins == 700 and inventory.run_coins == 13 and inventory.items.keys() == owned, "Roundtrip never banks escrow, awards starter gear or duplicates items")
	var original_position: Vector2 = actor.global_position
	_check(not PlayerTravel.relocate(actor, Vector2(INF, 640)), "Nonfinite entry is rejected")
	_check(not PlayerTravel.relocate(actor, Vector2(100, 640), PlayerTravel.Kind.END_EXPEDITION) and actor.global_position == original_position, "Ending an expedition cannot be routed through scene relocation")
	hub.gear.modal.open()
	var paused_cooldown: float = actor.motor.dash_cooldown_remaining
	_check(not hub.enter_house() and actor.motor.dash_cooldown_remaining == paused_cooldown, "Inventory modal blocks door without resetting clocks")
	hub.gear.modal.close()
	_check(hub.open_npc(NpcCatalog.HEALER), "Real NPC dialogue opens")
	_check(not hub.enter_house() and hub.dialogue.is_open, "Dialogue owns input until it closes; no silent transition")
	hub.dialogue.close()
	_check(TimeScaleClaims.owner_count(self) == 0 and actor.controls_enabled, "Closing both real modals releases input/time ownership")
	hub.open_station(&"training")
	_check(not hub.enter_house(), "Station modal blocks travel")
	hub.close_station()
	actor.relocate(hub.stations[&"house"].global_position)
	actor.motor.dash_cooldown_remaining = 0.9
	var first_input_frame: int = Engine.get_physics_frames()
	await _key(KEY_E)
	var first_elapsed: float = float(Engine.get_physics_frames() - first_input_frame) / Engine.physics_ticks_per_second
	_check(hub.inside_house and absf(actor.motor.dash_cooldown_remaining - maxf(0.0, 0.9 - first_elapsed)) <= 1.1 / Engine.physics_ticks_per_second, "Actual E input enters home with naturally elapsed dash cooldown")
	_check(actor.is_on_floor() and actor.global_position.x >= 3200 and actor.global_position.x <= 4480, "Real home entry settles on valid terrain")
	await _capture("travel_proof_home")
	var before_return_clock: float = actor.motor.dash_cooldown_remaining
	var return_input_frame: int = Engine.get_physics_frames()
	await _key(KEY_E)
	var return_elapsed: float = float(Engine.get_physics_frames() - return_input_frame) / Engine.physics_ticks_per_second
	_check(not hub.inside_house and actor.is_on_floor() and absf(actor.motor.dash_cooldown_remaining - maxf(0.0, before_return_clock - return_elapsed)) <= 1.1 / Engine.physics_ticks_per_second, "Actual E return retains dash cooldown after measured physics ticks, including GPU captures")
	await _capture("travel_proof_yard")
	actor.energy.current = 80.0
	actor.resonance_controller.loadout_state.cooldowns_by_recipe_id.clear()
	actor.action_state_machine.transition_to(&"cast_spell")
	_check(actor.action_state_machine.get_state_id() == &"cast_spell", "Authoritative cast windup begins")
	var committed_energy: float = actor.energy.current
	var committed_clocks: Dictionary = actor.resonance_controller.loadout_state.cooldowns_by_recipe_id.duplicate()
	var spawned: int = hub.executor.spawned_projectiles
	_check(hub.enter_house() and actor.action_state_machine.get_state_id() == &"ready", "Travel cancels the old-room cast action")
	_check(actor.energy.current == committed_energy and actor.resonance_controller.loadout_state.cooldowns_by_recipe_id == committed_clocks, "Canceled cast retains committed cost and cooldown")
	await _step(30)
	_check(hub.executor.spawned_projectiles == spawned and hub.executor.get_child_count() == 0, "Canceled old-room cast cannot spawn a delayed projectile")
	actor.action_state_machine.transition_to(&"hurt")
	_check(hub.leave_house() and actor.action_state_machine.get_state_id() == &"ready" and not actor.hit_reaction.blocks_controls(), "Scripted safe relocation clears Hurt ownership without healing")
	var loaded := SanctuaryProfile.new()
	loaded.save_path = flow.save_path_override
	_check(loaded.load_profile(), "Existing profile schema reloads after repeated safe travel")
	var decoded: GearInventory = GearInventoryCodec.decode(loaded.hub_inventory)
	_check(decoded != null and decoded.items.keys() == owned and loaded.coins == 700 and decoded.run_coins == 13, "Reload retains exact safe UID ledger and does not bank held coins")
	var failing := FailedCommitProfile.new()
	failing.save_path = flow.save_path_override
	_check(failing.load_profile(), "Failed-commit fixture uses the same isolated saved baseline")
	failing.reject_commit = true
	var economy: EconomySession = hub.economy
	var original_profile: SanctuaryProfile = economy.profile
	economy.profile = failing
	var before_file: String = FileAccess.get_file_as_string(flow.save_path_override)
	_check(not economy.buy_weapon(&"common_sword", GearItem.Quality.COMMON), "Real purchase rejects failed save commit")
	_check(failing.coins == 700 and inventory.items.keys() == owned and FileAccess.get_file_as_string(flow.save_path_override) == before_file, "Failed save rolls back coins/items and preserves saved ledger")
	economy.profile = original_profile
	flow.start_campaign()
	await _step(6)
	var run: DungeonRun = flow.active_scene as DungeonRun
	run.feedback.hit_stop_seconds = 0.0
	run.player.health.current_health = 43.0
	run.player.energy.current = 49.0
	run.player.energy.regeneration_delay = 100.0
	run.player.motor.dash_cooldown_remaining = 0.61
	run.player.motor.air_dash_available = false
	(run.player.motor as BuildPlayerMotor).air_dashes_used = 1
	run.player.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"basic_bolt"] = 6.0
	var run_actor: Player = run.player
	var run_inventory: GearInventory = run.gear.inventory
	_check(run.enter_room(2), "Existing intra-expedition room transition succeeds")
	_check(run.player == run_actor and run.gear.inventory == run_inventory and run_inventory.items.keys() == owned, "Intra-expedition travel keeps the actor/session/UIDs")
	_check(run.player.health.current_health == 43.0 and run.player.energy.current == 49.0 and run.player.motor.dash_cooldown_remaining == 0.61, "Intra-expedition travel cannot heal/refill/refund dash")
	_check(not run.player.motor.air_dash_available and (run.player.motor as BuildPlayerMotor).air_dashes_used == 1 and run.player.resonance_controller.loadout_state.cooldowns_by_recipe_id[&"basic_bolt"] == 6.0, "Intra-expedition travel retains air charges and spell clocks")
	_check(flow.profile.hub_inventory.is_empty() and run_inventory.run_coins == 13 and flow.profile.coins == 700, "Expedition ownership stays moved; room switch never banks escrow")
	await _capture("travel_proof_dungeon_room")
	var proven_image: PackedByteArray = FileAccess.get_file_as_bytes(flow.save_path_override)
	var corrupt: FileAccess = FileAccess.open(flow.save_path_override, FileAccess.WRITE)
	corrupt.store_string('{"version":1,"weapons":{}}')
	corrupt.close()
	var recovered := SanctuaryProfile.new()
	recovered.save_path = flow.save_path_override
	# Opening milestone commits may rotate the backup after the wardrobe moved.
	# A consumed ledger needs quarantine; an already-empty durable backup does not.
	if flow.profile.profile_version==2:
		_check(not recovered.load_profile() and recovered.read_only and recovered.hub_inventory.is_empty(), "Sealed profile corruption cannot restore a consumed wardrobe from an older backup")
	else:
		var durable_backup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(flow.save_path_override + ".bak"))
		var backup_inventory: Variant = durable_backup.get("hub_inventory", {})
		var backup_already_empty: bool = backup_inventory is Dictionary and backup_inventory.is_empty()
		_check(recovered.load_profile() and recovered.hub_inventory.is_empty() and (recovered.hub_inventory_quarantined or backup_already_empty), "Backup recovery cannot restore the consumed pre-expedition wardrobe")
	_check(run_inventory.items.keys() == owned, "Recovery cannot create a second carried UID ledger")
	if flow.profile.profile_version==2:
		# Restore only this test's exact pre-corruption bytes, never a gameplay repair.
		var fixture_restore: FileAccess = FileAccess.open(flow.save_path_override,FileAccess.WRITE)
		fixture_restore.store_buffer(proven_image); fixture_restore.close()
	_check(flow.profile.save(), "Repair only the private fixture save after corruption")
	run.player.motor.dash_cooldown_remaining = 0.7
	run.player.motor.air_dash_available = false
	(run.player.motor as BuildPlayerMotor).air_dashes_used = 1
	run.player.reset_movement_at(Vector2(180, 640))
	_check(run.player.motor.dash_cooldown_remaining == 0.0 and run.player.motor.air_dash_available and (run.player.motor as BuildPlayerMotor).air_dashes_used == 0 and run.player.energy.current == run.player.energy.maximum and run.player.health.current_health == run.player.health.maximum_health, "Legitimate reset/respawn still refills HP/energy and resets dash charges")
	flow.queue_free()
	await _step(8)
	_check(TimeScaleClaims.owner_count(self) == 0 and is_equal_approx(Engine.time_scale, 1.0), "Fixture teardown releases all modal/time claims")
	print("RESULT TravelClocks %d checks, %d failures" % [checks, failures])
	await process_frame
	quit(0 if failures == 0 else 1)

func _check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		print("FAIL: " + message)

func _step(count: int) -> void:
	for index: int in count:
		await physics_frame
		await process_frame

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await _step(2)
	event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = false
	root.push_input(event, true)
	await _step(2)

func _capture(filename: String) -> void:
	if not gpu: return
	await _step(3)
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	_check(picture.save_png("res://docs/verification/" + filename + ".png") == OK, "GPU fixture screenshot saved")
