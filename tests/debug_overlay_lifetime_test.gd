extends SceneTree
## Room-owned debug labels survive churn without retaining deferred Node arguments.

class FixtureWorld extends Node2D:
	var hp_bar: ProgressBar
	var boss_hp: ProgressBar
	var debug_hud: Node

var checks: int = 0
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	var sandbox: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/")
	var user_dir: String = OS.get_user_data_dir().replace("\\", "/")
	_check(not sandbox.is_empty() and user_dir.begins_with(sandbox + "/"), "user:// stays in the isolated QA directory")
	if failures > 0:
		quit(1)
		return
	print("DEBUG LIFETIME TEST: %d Hz; user://=%s" % [Engine.physics_ticks_per_second, user_dir])
	await _selectors()
	await _immediate_free()
	await _detach_reenter()
	await _owner_free()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _world() -> FixtureWorld:
	var world := FixtureWorld.new()
	root.add_child(world)
	return world

func _label(parent: Node, title: String) -> Label:
	var label := Label.new()
	label.name = title
	parent.add_child(label)
	return label

func _overlay(world: FixtureWorld) -> DungeonDebugOverlay:
	var overlay := DungeonDebugOverlay.new()
	world.add_child(overlay)
	overlay.initialize(world)
	return overlay

func _selectors() -> void:
	var world: FixtureWorld = _world()
	var debug: Label = _label(world, "DebugLabel")
	var keep: Label = _label(world, "KeepLabel")
	keep.set_meta(&"debug_keep", true)
	var modal := PanelContainer.new()
	world.add_child(modal)
	var modal_text: Label = _label(modal, "ModalLabel")
	var combat := Node2D.new()
	world.add_child(combat)
	combat.add_to_group(&"combat_text")
	var damage: Label = _label(combat, "DamageLabel")
	var health := ProgressBar.new()
	health.name = "HealthBar"
	world.add_child(health)
	world.hp_bar = ProgressBar.new()
	world.add_child(world.hp_bar)
	world.boss_hp = ProgressBar.new()
	world.add_child(world.boss_hp)
	var debug_bar := ProgressBar.new()
	world.add_child(debug_bar)
	var overlay: DungeonDebugOverlay = _overlay(world)
	_check(not debug.visible and overlay.widgets.has(debug.get_instance_id()), "Ordinary debug labels retain release-mode hiding")
	_check(keep.visible and not overlay.widgets.has(keep.get_instance_id()), "debug_keep label stays visible")
	_check(modal_text.visible and not overlay.widgets.has(modal_text.get_instance_id()), "Modal label stays visible")
	_check(damage.visible and not overlay.widgets.has(damage.get_instance_id()), "Damage text stays visible")
	_check(health.visible and world.hp_bar.visible and world.boss_hp.visible, "Player and Boss health bars stay visible")
	_check(not debug_bar.visible and overlay.widgets.has(debug_bar.get_instance_id()), "Debug progress bar keeps its existing visibility contract")
	var foreign: FixtureWorld = _world()
	var other: Label = _label(foreign, "OtherWorldLabel")
	var added: Label = _label(world, "LiveAddedLabel")
	await _step(2)
	_check(other.visible and not overlay.widgets.has(other.get_instance_id()), "Foreign room labels are untouched")
	_check(not added.visible and overlay.widgets.has(added.get_instance_id()), "Live node_added registers a legitimate label after ready")
	overlay.set_enabled(true)
	_check(debug.visible and added.visible and debug_bar.visible and keep.visible and modal_text.visible and damage.visible, "Debug toggle restores only registered widgets")
	overlay.set_enabled(false)
	_check(not debug.visible and not added.visible and keep.visible and modal_text.visible and damage.visible, "Release toggle preserves gameplay and modal labels")
	foreign.free()
	world.free()
	await _step(2)

func _immediate_free() -> void:
	var world: FixtureWorld = _world()
	var overlay: DungeonDebugOverlay = _overlay(world)
	var freed: Label = _label(world, "FreedBeforeDeferred")
	var freed_id: int = freed.get_instance_id()
	freed.free()
	await _step(2)
	_check(not is_instance_id_valid(freed_id) and not overlay.widgets.has(freed_id), "Immediate-free target leaves no registry entry")
	var queued: Label = _label(world, "QueuedBeforeDeferred")
	var queued_id: int = queued.get_instance_id()
	queued.queue_free()
	overlay._register(queued)
	_check(not overlay.widgets.has(queued_id), "Registration skips a label queued for deletion")
	await _step(2)
	_check(not overlay.widgets.has(queued_id), "Queued target leaves no late registration")
	world.free()
	await _step(2)

func _detach_reenter() -> void:
	var world: FixtureWorld = _world()
	var existing: Label = _label(world, "ExistingBeforeDetach")
	var overlay: DungeonDebugOverlay = _overlay(world)
	var delayed: Label = _label(world, "PendingDuringDetach")
	world.remove_child(overlay)
	_check(not node_added.is_connected(overlay._node_added), "Detached overlay disconnects SceneTree.node_added")
	_check(not existing.tree_exiting.is_connected(overlay._unregister.bind(existing.get_instance_id())), "Detached overlay releases widget exit listeners")
	var detached_added: Label = _label(world, "AddedWhileDetached")
	await _step(2)
	_check(overlay.widgets.is_empty(), "Pending registration cannot repopulate a detached overlay")
	_check(delayed.visible and detached_added.visible, "Late callback does not hide labels while overlay is detached")
	overlay.set_enabled(true)
	world.add_child(overlay)
	await _step(2)
	_check(node_added.is_connected(overlay._node_added), "Reentered overlay reconnects its live tree listener")
	_check(overlay.widgets.has(existing.get_instance_id()) and overlay.widgets.has(delayed.get_instance_id()) and overlay.widgets.has(detached_added.get_instance_id()), "Reentry rescans existing and newly added room labels")
	_check(existing.visible and delayed.visible and detached_added.visible, "Reentry applies the current debug visibility state")
	var live: Label = _label(world, "AddedAfterReentry")
	await _step(2)
	_check(overlay.widgets.has(live.get_instance_id()) and live.visible, "New labels still register after reentry")
	var pending: Label = _label(world, "PendingAcrossSameFrameReentry")
	world.remove_child(overlay)
	world.add_child(overlay)
	await _step(2)
	_check(overlay.widgets.has(pending.get_instance_id()) and pending.visible, "Same-frame detach/reentry discards stale work and rescans live labels")
	overlay.set_enabled(false)
	_check(not existing.visible and not pending.visible, "Reentered overlay still obeys release visibility")
	root.remove_child(world)
	root.add_child(world)
	await _step(2)
	_check(overlay.widgets.has(existing.get_instance_id()) and not existing.visible, "Whole-room reentry retains debug presentation")
	world.free()
	await _step(2)

func _owner_free() -> void:
	var world: FixtureWorld = _world()
	var overlay: DungeonDebugOverlay = _overlay(world)
	_label(world, "PendingWhenOwnerFreed")
	world.remove_child(overlay)
	world.free()
	await _step(2)
	_check(overlay.widgets.is_empty() and not node_added.is_connected(overlay._node_added), "Freed owner leaves the retained overlay inert")
	var replacement: FixtureWorld = _world()
	replacement.add_child(overlay)
	overlay.initialize(replacement)
	var label: Label = _label(replacement, "ReplacementRoomLabel")
	await _step(2)
	_check(overlay.widgets.has(label.get_instance_id()) and not label.visible, "Retained overlay can initialize a legitimate replacement room")
	replacement.queue_free()
	await _step(2)
	_check(not is_instance_valid(overlay), "Replacement teardown frees its overlay and callbacks")

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func _check(condition: bool, title: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", title])
