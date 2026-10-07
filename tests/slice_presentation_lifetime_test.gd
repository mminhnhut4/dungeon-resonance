extends SceneTree
## Deferred presentation work must belong to a live room, including same-frame exits.

const LEVEL: PackedScene = preload("res://scenes/test_level.tscn")
const DUMMY: PackedScene = preload("res://scenes/training_dummy.tscn")
var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
	var sandbox: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/")
	var user_dir: String = OS.get_user_data_dir().replace("\\", "/")
	_check(not sandbox.is_empty() and user_dir.begins_with(sandbox + "/"), "user:// is inside the isolated QA directory")
	if failures > 0:
		quit(1)
		return
	print("LIFETIME TEST: %d Hz; user://=%s" % [Engine.physics_ticks_per_second, user_dir])
	await _detached_room()
	await _queued_target()
	await _same_frame_flow()
	await _step(4)
	_check(is_equal_approx(Engine.time_scale, 1.0), "Room exits restore the global time scale")
	_check(root.get_node("AudioManager").get_active_voice_count() == 0, "Room exits release their audio voices")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _new_level() -> Node2D:
	var level: Node2D = LEVEL.instantiate()
	root.add_child(level)
	level.survival.director.automatic = false
	for enemy: SlimeEnemy in level.enemies:
		enemy.ai_enabled = false
	return level

func _detached_room() -> void:
	var old: Node2D = _new_level()
	await _step(3)
	var adapter: SlicePresentation = old.presentation
	adapter.rebuild()
	var late_dummy: TrainingDummy = DUMMY.instantiate() as TrainingDummy
	old.add_child(late_dummy)
	var late_chest := TreasureChest.new()
	old.add_child(late_chest)
	root.remove_child(old)
	_check(not node_added.is_connected(adapter._on_node_added), "Detached presentation disconnects SceneTree.node_added")
	var replacement: Node2D = _new_level()
	await _step(3)
	_check(adapter.bound_actors.is_empty(), "Deferred actor callback cannot bind into the detached room")
	_check(not late_dummy.has_node("ElementAfflictionVFX") and not late_dummy.has_node("PropSpriteSkin"), "Detached actor receives no late visual children")
	_check(not late_chest.has_node("PropSpriteSkin"), "Deferred prop callback cannot skin the detached room")
	_check(replacement.presentation.bound_actors.size() == 5, "Replacement room binds its five production actors")
	_check(is_instance_valid(replacement.presentation.trail) and is_instance_valid(replacement.presentation.art_hud), "Replacement room keeps its weapon trail and HUD")
	var live_dummy: TrainingDummy = DUMMY.instantiate() as TrainingDummy
	replacement.add_child(live_dummy)
	await _step(3)
	_check(replacement.presentation.bound_actors.has(live_dummy.get_instance_id()) and live_dummy.has_node("ElementAfflictionVFX") and live_dummy.has_node("PropSpriteSkin"), "Live node_added still binds actor and presentation after ready")
	var bound_count: int = replacement.presentation.bound_actors.size()
	replacement.presentation._scan()
	_check(replacement.presentation.bound_actors.size() == bound_count, "Live scan does not duplicate actor bindings")
	old.free()
	replacement.presentation.rebuild()
	root.remove_child(replacement)
	replacement.queue_free()
	await _step(3)
	_check(not is_instance_valid(replacement), "Detached room frees while its pending scan is discarded")

func _queued_target() -> void:
	var level: Node2D = _new_level()
	await _step(3)
	var late_dummy: TrainingDummy = DUMMY.instantiate() as TrainingDummy
	level.add_child(late_dummy)
	var target_id: int = late_dummy.get_instance_id()
	late_dummy.queue_free()
	level.presentation._scan()
	_check(not level.presentation.bound_actors.has(target_id), "Scan skips an actor queued for deletion")
	await _step(3)
	_check(not is_instance_id_valid(target_id) and not level.presentation.bound_actors.has(target_id), "Queued actor leaves no presentation binding")
	var freed_dummy: TrainingDummy = DUMMY.instantiate() as TrainingDummy
	# Isolate this adapter's pending work from DebugOverlay's separate label queue.
	level.presentation._on_node_added(freed_dummy)
	freed_dummy.free()
	await _step(3)
	_check(level.presentation.bound_actors.size() == 5, "Freed target is ignored by its pending node_added callback")
	var queued_chest := TreasureChest.new()
	level.add_child(queued_chest)
	level.presentation.rebuild()
	level.queue_free()
	level.presentation._scan()
	_check(not queued_chest.has_node("PropSpriteSkin"), "Scan skips a room queued for deletion")
	await _step(3)
	_check(not is_instance_valid(level), "Queued room releases all deferred presentation owners")

func _same_frame_flow() -> void:
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.world_building_enabled = false
	flow.campaign_scene = null
	flow.save_path_override = "user://verification/slice_lifetime_%d.json" % Engine.physics_ticks_per_second
	root.add_child(flow)
	for cycle: int in 2:
		flow.start_run()
		(flow.active_scene as DungeonRun).finish(&"defeat")
		flow.show_hub(true)
		flow.start_campaign()
		(flow.active_scene as DungeonRun).finish(&"defeat")
		flow.show_hub(true)
	await _step(5)
	var hub: PrologueHub = flow.active_scene as PrologueHub
	_check(hub != null and hub.is_inside_tree(), "Same-frame Hub/run/campaign exits leave the final Hub active")
	_check(is_instance_valid(hub.presentation.trail) and is_instance_valid(hub.presentation.art_hud) and hub.presentation.bound_actors.has(hub.player.get_instance_id()), "Final Hub retains player binding, trail and HUD")
	hub.presentation.rebuild()
	flow.queue_free()
	await _step(4)
	_check(not is_instance_valid(flow), "Same-frame flow teardown releases its final scene")

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])
