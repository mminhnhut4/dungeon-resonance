extends SceneTree
## Actual GameFlow/UI/room ownership; historical clear seed and direct roster defeat are explicit fixtures.
const Progress = preload("res://scripts/runtime/depth_progress.gd")
const Catalog = preload("res://data/depth_floor_catalog.gd")
var checks: int = 0
var failures: int = 0
var flow: GameFlow
var capture: bool = false
var path: String

func _initialize() -> void: _run.call_deferred()

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
		if arg == "--native-approved": capture = true
	var allowed: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	if not allowed.is_absolute_path() or not OS.get_user_data_dir().replace("\\","/").begins_with(allowed+"/") or capture != (DisplayServer.get_name() != "headless"):
		print("FAIL: isolated QA root required; capture needs an approved renderer")
		quit(2)
		return
	path = "user://verification/depth_select_%d_%d.json" % [Engine.physics_ticks_per_second,Time.get_ticks_usec()]
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	await _open()
	var hub: PrologueHub = flow.active_scene as PrologueHub
	_check(not flow.start_depth_campaign(1),"Opening Golem gate applies even to first floor")
	_check(flow.profile.record_boss_defeat("selector_historical_opening_proof"),"Fixture establishes opening proof through durable owner")
	_check(not flow.start_depth_campaign(1),"Accepting the deeper journey is still required")
	_check(flow.depth_progress.accept(),"Accept through existing extension transaction")
	_check(flow.depth_progress.can_start_floor(1) and not flow.depth_progress.can_start_floor(2),"Accepted first journey offers only floor one")
	for number: int in [1,2,3]:
		_check(flow.depth_progress.record(StringName("depth_floor_%d" % number),number),"Fixture records historical cleared floor %d" % number)
	await _close()
	await _open()
	hub = flow.active_scene as PrologueHub
	_check(int(flow.depth_progress.state()["cleared"]) == 3,"Cold product entry restores completed floors")
	var before_bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var before_inventory: Dictionary = GearInventoryCodec.encode(hub.gear.inventory)
	var before_revision: int = flow.profile.extension_revision(Progress.SCOPE)
	for number: int in [0,4,5,6,-1]:
		_check(not flow.start_depth_campaign(number),"Product rejects unavailable initial floor %d" % number)
	_check(flow.active_scene == hub and GearInventoryCodec.encode(hub.gear.inventory) == before_inventory and FileAccess.get_file_as_bytes(path) == before_bytes,"Rejected selections cannot consume prepared UIDs or write progress")
	var guide: DepthGuide = hub.get_node("DepthGuide") as DepthGuide
	PlayerTravel.relocate(hub.player,guide.npc.global_position)
	await _step(4)
	await _key(root,KEY_E)
	_check(guide.opened and not hub.player.controls_enabled,"Real E opens the floor selector and suspends controls")
	_check(guide.floor_choice.item_count == 3 and guide.floor_choice.get_item_id(2) == 3,"Selector lists exactly the three completed floors")
	for extent: Vector2i in [Vector2i(800,600),Vector2i(1280,720)]:
		root.size = extent
		guide._resize()
		await _step(3)
		_check(root.get_visible_rect().encloses(guide.panel.get_global_rect()) and guide.panel.get_global_rect().encloses(guide.floor_choice.get_global_rect()) and guide.panel.get_global_rect().encloses(guide.action.get_global_rect()),"Selector and launch action fit %s" % extent)
		_check(guide.floor_scroll.get_global_rect().end.y <= guide.floor_choice.get_global_rect().position.y and guide.floor_choice.get_global_rect().end.y < guide.action.get_global_rect().position.y,"Scrollable floor details do not overlap selection/action at %s" % extent)
		await _picture("selector_%d" % extent.x)
	# Open the actual OptionButton with the mouse; navigate its real popup, not a callback.
	await _click(guide.floor_choice)
	var popup: PopupMenu = guide.floor_choice.get_popup()
	_check(popup.visible,"Mouse opens the actual completed-floor popup")
	print("POPUP before navigation focus=",popup.get_focused_item())
	print("POPUP ui_down events=",InputMap.action_get_events(&"ui_down")," embedded=",popup.is_embedded()," input_connections=",popup.get_signal_connection_list(&"window_input"))
	for _index: int in 3:
		if popup.get_focused_item() == 2: break
		await _key(popup,KEY_DOWN)
	print("POPUP after navigation focus=",popup.get_focused_item())
	await _key(popup,KEY_ENTER)
	print("POPUP selected_floor=",guide.selected_floor)
	_check(guide.selected_floor == 3 and guide.action.text.contains("Xuống tầng 3"),"Popup input selects floor three and updates launch text")
	_check(FileAccess.get_file_as_bytes(path) == before_bytes and flow.profile.extension_revision(Progress.SCOPE) == before_revision,"Changing selection has no save or reward side effect")
	await _picture("selector_chosen_3")
	# The displayed choice can become stale while its modal is open.
	flow.profile.read_only = true
	guide._act()
	_check(flow.active_scene == hub and guide.opened and guide.action.disabled and GearInventoryCodec.encode(hub.gear.inventory) == before_inventory,"UI revalidates a newly quarantined profile before launch")
	_check(not flow.start_depth_campaign(3),"Direct stale request is rejected by GameFlow too")
	flow.profile.read_only = false
	guide.refresh()
	guide.floor_choice.select(2)
	guide.floor_choice.item_selected.emit(2)
	# Keep the real prepared inventory durable when launch storage fails.
	flow.profile._writer.fault_plan = {"write_candidate":true}
	await _click(guide.action)
	_check(flow.active_scene == hub and guide.opened and guide.selected_floor == 3,"Failed preparation save reopens the same selected floor")
	_check(GearInventoryCodec.encode(hub.gear.inventory) == before_inventory and FileAccess.get_file_as_bytes(path) == before_bytes,"Failed launch preserves exact prepared inventory and profile bytes")
	var source_inventory: GearInventory = hub.gear.inventory
	var source_uids: Array = source_inventory.items.keys()
	var old_opening: Dictionary = flow.profile.opening_progress.duplicate(true)
	var old_proofs: Dictionary = flow.profile.boss_proofs.duplicate(true)
	var old_receipts: Array[String] = flow.profile.boss_receipts.duplicate()
	await _click(guide.action)
	await _step(6)
	var run: DepthCampaign = flow.active_scene as DepthCampaign
	_check(run != null and run.room_number == 3 and run.stage == 3,"Actual launch enters selected floor three through GameFlow")
	if run == null:
		await _close()
		_finish()
		return
	_prepare_run(run)
	_check(run.room.locked and run.living_enemies().size() == int(Catalog.floor_data(3)["count"]) and not run.portal_active,"Replay begins with its real locked roster, without free rewards")
	_check(source_uids.all(func(uid: Variant) -> bool: return run.gear.inventory.items.has(uid)) and source_inventory.items.is_empty(),"Prepared UIDs move into exactly one run")
	_check(not flow.start_depth_campaign(3) and flow.active_scene == run,"Duplicate launch cannot create a second run")
	_check(flow.profile.extension_revision(Progress.SCOPE) == before_revision and flow.profile.boss_proofs == old_proofs and flow.profile.boss_receipts == old_receipts,"Launching a replay creates no completion or old boss receipt")
	await _picture("selected_floor_3_live")
	await _clear_roster(run)
	_check(not run.room.locked and not run.has_pending_rewards() and flow.profile.extension_revision(Progress.SCOPE) == before_revision,"Clearing replayed floor is idempotent for persistent progress")
	_check(run.advance_room(),"A cleared replay can continue by the normal next-floor transition")
	await _step(4)
	_prepare_run(run)
	_check(run.room_number == 4 and run.room.locked,"Uncleared next floor still starts locked with enemies")
	await _clear_roster(run)
	_check(int(flow.depth_progress.state()["cleared"]) == 4 and flow.profile.extension_revision(Progress.SCOPE) == before_revision+1,"New fourth-floor completion records exactly once")
	var pickup: LootPickup = run.gear.loot.spawn(&"coins",&"coins",run.player.position,7)
	pickup.automatic = false
	_check(pickup.collect(),"Finite test coins enter carried loot")
	var coins_before: int = flow.profile.coins
	var carried_coins: int = run.gear.inventory.run_coins
	var returned_uids: Array = run.gear.inventory.items.keys()
	PlayerTravel.relocate(run.player,Vector2(1240,640))
	await _step(3)
	_check(run.floor_exit.open(),"Cleared fourth floor offers the existing return modal")
	await _step(2)
	_check(run.floor_exit.notice.text.contains("chọn lại tầng đã hoàn tất"),"Return copy explains the new next-trip choice")
	_check(run.request_floor_return(),"Return uses existing bank/NPC recovery owner")
	await _step(5)
	_check(flow.active_scene is PrologueHub and flow.profile.coins == coins_before+carried_coins,"Replay return banks carried coins exactly once")
	_check(returned_uids.all(func(uid: Variant) -> bool: return flow.active_scene.gear.inventory.items.has(uid)),"Return preserves exact carried UIDs")
	_check(flow.show_hub() and flow.profile.coins == coins_before+carried_coins,"Repeated return callback adds no coins")
	_check(flow.profile.opening_progress == old_opening and flow.profile.boss_proofs == old_proofs and flow.profile.boss_receipts == old_receipts,"Depth replay/retreat does not award opening Golem progress")
	await _close()
	await _open()
	_check(flow.depth_progress.can_start_floor(4) and not flow.depth_progress.can_start_floor(5),"Cold fourth-floor completion still cannot directly launch uncleared fifth")
	_check(returned_uids.all(func(uid: Variant) -> bool: return flow.active_scene.gear.inventory.items.has(uid)) and flow.profile.coins == coins_before+carried_coins,"Cold replay return retains banked coins and UIDs")
	# Seed a historical finished journey through its exact owner, then replay its boss.
	_check(flow.depth_progress.record(&"depth_floor_5",5) and flow.depth_progress.record(&"depth_boss_defeated",5),"Fixture records historical final completion")
	var final_revision: int = flow.profile.extension_revision(Progress.SCOPE)
	_check(flow.start_depth_campaign(5),"A completed fifth floor can launch directly")
	await _step(6)
	run = flow.active_scene as DepthCampaign
	_prepare_run(run)
	_check(run.room_number == 5 and run.room.locked and run.reward_chest.locked and not run.portal_active,"Boss replay requires a fresh actual encounter and chest unlock")
	run.boss.health.apply_damage(99999)
	await _step(8)
	var drops: int = run.gear.loot.spawned_total
	run._finish_boss()
	await _step(2)
	_check(run.portal_active and not run.reward_chest.locked and run.gear.loot.spawned_total == drops,"Repeated boss callback cannot multiply loot in this replay")
	_check(flow.profile.extension_revision(Progress.SCOPE) == final_revision and flow.profile.boss_receipts == old_receipts and flow.profile.boss_proofs == old_proofs,"Replayed boss cannot duplicate depth or opening receipts")
	await _close()
	_finish()

func _open() -> void:
	flow = preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow
	flow.save_path_override = path
	root.add_child(flow)
	current_scene = flow
	await _step(8)

func _close() -> void:
	flow.queue_free()
	current_scene = null
	await _step(6)
	_check(is_equal_approx(Engine.time_scale,1.0),"Teardown releases modal time claims")

func _prepare_run(run: DepthCampaign) -> void:
	run.feedback.hit_stop_seconds = 0.0
	run.feedback.enable_global_hitstop(false)
	run.survival.set_enabled(false)
	run.player.health.minimum_health = 1.0
	run.gear.loot.drop_table = run.gear.loot.drop_table.duplicate(true) as DropTableResource
	run.gear.loot.drop_table.none_chance = 1.0
	run.gear.loot.drop_table.blueprint_chance_total = 0.0
	for enemy: Node2D in run.living_enemies():
		enemy.set("ai_enabled",false)
		if enemy is BaseEnemy: (enemy as BaseEnemy).state_machine.process_mode = Node.PROCESS_MODE_DISABLED

func _clear_roster(run: DepthCampaign) -> void:
	for enemy: Node2D in run.living_enemies(): enemy.health.apply_damage(99999)
	await _step(8)

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion,true)
	await _step(2)
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event,true)
		await _step(1)
	await _step(2)

func _key(_viewport: Viewport, code: Key) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		# Root input routes to the actual embedded popup; direct popup input bypasses that routing.
		root.push_input(event,true)
		await _step(1)
	await _step(2)

func _picture(label: String) -> void:
	if not capture: return
	await RenderingServer.frame_post_draw
	var evidence: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	root.get_texture().get_image().save_png(evidence.path_join(label+".png"))

func _step(count: int) -> void:
	for _index: int in count:
		await physics_frame
		await process_frame

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ")+label)

func _finish() -> void:
	print("RESULT depth_floor_selection checks=%d failures=%d hz=%d" % [checks,failures,Engine.physics_ticks_per_second])
	quit(0 if failures == 0 else 1)
