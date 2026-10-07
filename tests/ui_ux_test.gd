extends SceneTree
## Focused fixture only; no real profile load/save and no economy transaction.
## --capture requires the parent's GPU window. Headless checks produce no images.

var checks: int = 0
var failures: int = 0
var captures: int = 0
var capture_requested: bool = false
var choices_emitted: Array[StringName] = []
var attacks: int = 0
var hub: PrologueHub

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	capture_requested = "--capture" in OS.get_cmdline_user_args()
	if capture_requested and DisplayServer.get_name() == "headless":
		print("FAIL: --capture requires a GPU render window")
		quit(1)
		return
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = Vector2i.ZERO
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	hub = preload("res://scenes/hub/prologue_hub_room.tscn").instantiate() as PrologueHub
	hub.profile = SanctuaryProfile.new()
	hub.profile.save_path = "user://verification/ui_ux_fixture_unused_%d.json" % Time.get_ticks_usec()
	hub.world_building_enabled = true
	root.add_child(hub)
	current_scene = hub
	await _frames(8)
	var screen: InventoryScreen = hub.gear.modal as InventoryScreen
	var box: DialogueBox = hub.dialogue
	var inventory: GearInventory = hub.gear.inventory
	var ui_accept_before: Array[InputEvent] = InputMap.action_get_events(&"ui_accept")
	print("UI ENV user_dir=%s executable=%s" % [OS.get_user_data_dir(), OS.get_executable_path()])
	box.choice_selected.connect(func(id: StringName) -> void: choices_emitted.append(id))
	hub.player.equipped_weapon.attack_committed.connect(func(_snapshot: AttackSnapshot) -> void: attacks += 1)
	_check(screen.tabs.get_tab_count() == 3 and screen.bag_buttons.size() == 20 and screen.equipment_buttons.size() == 7, "Existing equipment/rune tabs and seven/20 cells remain; journal is additive")
	var spare: GearItem = inventory.add_equipment(GearInventory.COMMON_SWORD, GearItem.Quality.RARE)
	var owned_count: int = inventory.items.size()
	var original: int = inventory.equipped_weapon_uid
	var profile_before: Dictionary = {"souls": hub.profile.souls, "coins": hub.profile.coins, "inventory": hub.profile.hub_inventory.duplicate(true)}
	for extent: Vector2i in [Vector2i(800, 600), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = extent
		await _frames(4)
		screen.open()
		await _frames(4)
		_check(root.get_visible_rect().encloses(screen.panel.get_global_rect()), "Inventory remains bounded at %s" % extent)
		var footer: Button = screen.panel.get_child(0).get_child(1) as Button
		_check(root.get_visible_rect().encloses(footer.get_global_rect()), "Inventory close footer remains visible at %s" % extent)
		screen._bag_focus(screen.bag_uids.find(spare.uid))
		await _frames(3)
		_check(root.get_visible_rect().encloses(screen.tooltip.get_global_rect()), "Comparison tooltip remains bounded at %s" % extent)
		_check(not screen.tooltip.get_global_rect().intersects(footer.get_global_rect()), "Comparison preserves the readable close footer at %s" % extent)
		_check(not screen.tooltip.get_global_rect().intersects(screen.bag_buttons[screen.bag_uids.find(spare.uid)].get_global_rect()), "Comparison keeps its selected item visible at %s" % extent)
		_check("SO VỚI ĐANG MẶC" in screen.tooltip_body.text and "tăng" in screen.tooltip_body.text, "Comparison reports a signed increase from actual quality damage factor")
		await _capture("inventory_comparison_%dx%d" % [extent.x, extent.y])
		screen.close()
		_check(hub.open_npc(NpcCatalog.SMITH), "Conversation opens with the real Hub input/time owner")
		var long_line: String = "Ngọn đèn bên bậc đá còn cháy. Hãy đọc dấu nước, hỏi người giữ bến và cân nhắc trước khi đi tiếp. ".repeat(15)
		var menu: Array[Dictionary] = [
			{"id": &"fixture_remove", "text": "Bỏ vật chứng của lời hẹn này để tiếp tục một lựa chọn rất dài cần đọc trọn trên cửa sổ nhỏ", "destructive": true, "confirm_text": "Vật chứng sẽ bị bỏ. Xác nhận lựa chọn này?"},
			{"id": &"fixture_disabled", "text": "Lựa chọn chưa đủ điều kiện", "enabled": false},
		]
		box.open("Người giữ đèn · Tên người nói dài", [long_line], menu)
		box.advance()
		await _frames(5)
		_check(root.get_visible_rect().encloses(box.panel.get_global_rect()) and root.get_visible_rect().encloses(box.close_button.get_global_rect()), "Long dialogue and close footer fit at %s" % extent)
		_check(box.page_label.autowrap_mode == TextServer.AUTOWRAP_OFF and box.page_label.size.x >= box.page_label.get_minimum_size().x, "Page count stays on one line at %s" % extent)
		_check((box.choice_list.get_child(0) as Button).autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Long choice wraps instead of trimming its meaning")
		await _capture("dialogue_long_%dx%d" % [extent.x, extent.y])
		box.select_choice(&"fixture_disabled")
		_check(box.is_open and box.pending_choice == &"" and choices_emitted.is_empty(), "Disabled choice cannot emit or open confirmation")
		box.select_choice(&"fixture_remove")
		_check(box.pending_choice == &"fixture_remove" and box.cancel_button.has_focus() and choices_emitted.is_empty(), "Destructive choice waits with cancel focused and no transaction emitted")
		await _capture("dialogue_confirm_%dx%d" % [extent.x, extent.y])
		await _key(KEY_ESCAPE)
		_check(box.is_open and box.pending_choice == &"" and choices_emitted.is_empty(), "Escape cancels confirmation and keeps the conversation")
		box.close()
	root.size = Vector2i(1280, 720)
	await _frames(4)
	hub.open_npc(NpcCatalog.SMITH)
	box.open("Xác nhận", ["Một lựa chọn có xác nhận."], [{"id": &"fixture_commit", "text": "Tiếp tục", "requires_confirmation": true}])
	box.advance()
	box.select_choice(&"fixture_commit")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	_check(box.confirm_button.has_focus(), "Controller D-pad moves from safe cancel to explicit confirmation")
	await _joy(JOY_BUTTON_B)
	_check(box.is_open and box.pending_choice == &"" and choices_emitted.is_empty(), "Controller B cancels confirmation without emitting")
	box.select_choice(&"fixture_commit")
	await _axis(JOY_AXIS_LEFT_Y, 0.8)
	_check(box.confirm_button.has_focus(), "Left-stick threshold moves confirmation focus")
	await _axis(JOY_AXIS_LEFT_Y, 0.0)
	await _joy(JOY_BUTTON_A)
	box.confirm_choice()
	_check(choices_emitted == [&"fixture_commit"] and not box.is_open, "Confirmation emits exactly once, including a repeated confirm call")
	choices_emitted.clear()
	hub.open_npc(NpcCatalog.SMITH)
	box.open("Hai trang", ["Trang đầu", "Trang cuối"], [{"id": &"fixture_page", "text": "Cuối cuộc thoại"}])
	box.advance()
	box.select_choice(&"fixture_page")
	_check(choices_emitted.is_empty() and box.is_open, "No choice can commit before the final dialogue page")
	await _key(KEY_ESCAPE)
	_check(not box.is_open and hub.player.controls_enabled and is_equal_approx(Engine.time_scale, 1.0), "Dialogue Escape restores its movement/time owner")
	screen.open()
	screen._hide_tooltip()
	var index: int = screen.bag_uids.find(spare.uid)
	await _click(screen.bag_buttons[index], MOUSE_BUTTON_LEFT)
	_check(inventory.equipped_weapon_uid == spare.uid and inventory.items.size() == owned_count, "Real left click swaps UIDs once without duplication")
	screen._hide_tooltip()
	await _click(screen.equipment_buttons[0], MOUSE_BUTTON_RIGHT)
	_check(inventory.equipped_weapon_uid == 0, "Existing right-click unequip still works")
	screen._hide_tooltip()
	index = screen.bag_uids.find(original)
	screen.bag_buttons[index].grab_focus()
	await _key(KEY_ENTER)
	_check(inventory.equipped_weapon_uid == original, "Focused bag cell accepts keyboard equip")
	screen.bag_buttons[screen.bag_uids.find(spare.uid)].grab_focus()
	await _joy(JOY_BUTTON_A)
	_check(inventory.equipped_weapon_uid == spare.uid, "Focused bag cell accepts controller A equip")
	_check(InputMap.action_get_events(&"ui_accept") == ui_accept_before, "Controller fallback stays modal-local and preserves the shared Input Map")
	var before: int = attacks
	await _key(KEY_J)
	await _key(KEY_I)
	await _key(KEY_SPACE)
	await _mouse(Vector2(3, 3), MOUSE_BUTTON_LEFT)
	_check(attacks == before and not hub.player.equipped_weapon.hitbox.active, "World attack/cast/jump inputs stay blocked behind inventory")
	for cycle: int in 8:
		screen.close()
		screen.open()
	await _key(KEY_ESCAPE)
	_check(not screen.is_open and not screen.veil.visible and hub.player.controls_enabled and is_equal_approx(Engine.time_scale, 1.0), "Repeated open/close and Escape restore one time/control owner")
	_check(screen.open_button.has_focus(), "Closing inventory restores focus to its visible trigger")
	screen.open()
	await _joy(JOY_BUTTON_B)
	_check(not screen.is_open and hub.player.controls_enabled, "Controller B closes inventory without opening another modal")
	paused = true
	screen.open()
	await _key(KEY_ESCAPE)
	_check(paused and not screen.is_open and is_equal_approx(Engine.time_scale, 1.0), "Inventory remains cancelable while paused and preserves paused state")
	paused = false
	hub.open_npc(NpcCatalog.SMITH)
	paused = true
	await _key(KEY_SPACE)
	_check(not box.is_typing(), "Paused dialogue still receives reveal input when its world router is paused")
	await _key(KEY_ESCAPE)
	_check(paused and not box.is_open and is_equal_approx(Engine.time_scale, 1.0), "Paused dialogue cancellation preserves pause and releases only its own time claim")
	paused = false
	var journal: QuestJournal = screen.journal
	_check(journal.rows.size() == 6 and journal.tracker_text().is_empty() and not screen.tracker.visible, "Unified page reads canonical opening milestones without a gameplay tracker")
	hub.profile.bounty_accepted = true
	hub.profile.bounty_start_proofs = 2
	hub.profile.boss_proofs[&"golem"] = 2
	hub.profile.changed.emit()
	journal.select_quest(&"golem_defeated")
	_check("Golem" in journal.detail_title.text and journal.graph.objective_room == &"", "Known bounty reveals its title without inventing an exterior boss location")
	hub.profile.boss_proofs[&"golem"] = 3
	hub.profile.changed.emit()
	_check(journal.rows.size() == OpeningProgress.IDS.size() and journal.tracker_text().is_empty(), "Quest rows remain governed by canonical milestones rather than bounty proof arithmetic")
	screen.open_map()
	await _frames(4)
	await _capture("quest_ready")
	_check(screen.tabs.current_tab == 2 and not screen.tracker.visible, "Map and quest details share one modal page")
	hub.profile.bounty_claimed = true
	hub.profile.changed.emit()
	_check(journal.tracker_text().is_empty() and not screen.tracker.visible, "Claimed bounty never creates a persistent gameplay overlay")
	screen.tabs.current_tab = 0
	while inventory.equipment_bag_uids().size() < 20:
		inventory.add_equipment(GearInventory.COMMON_SWORD)
	var retained: int = inventory.equipped_weapon_uid
	screen.selected_equipment_slot = 0
	screen._unequip_selected()
	_check(inventory.equipped_weapon_uid == retained and "đầy" in screen.status.text and "ĐẦY" in screen.pager.text, "Full bag refuses unequip and explains why without item loss")
	screen._hide_tooltip()
	await _capture("inventory_full")
	var bag: Array[int] = inventory.equipment_bag_uids()
	for uid: int in bag: inventory.dismantle(uid)
	screen.refresh()
	_check("TRỐNG" in screen.pager.text and screen.bag_buttons[0].text == "Trống", "Empty bag has explicit visible cell/capacity state")
	await _capture("inventory_empty")
	_check(hub.profile.souls == profile_before["souls"] and hub.profile.coins == profile_before["coins"] and hub.profile.hub_inventory == profile_before["inventory"], "UI projection never purchases or rewrites the safe-save ledger")
	_check(not FileAccess.file_exists(hub.profile.save_path), "Read-only journal and UI never create the unused fixture save")
	screen.close()
	hub.queue_free()
	await _frames(8)
	_check(is_equal_approx(Engine.time_scale, 1.0), "Fixture teardown releases all UI time claims")
	await root.get_node("AudioManager").shutdown()
	print("RESULT ui_ux checks=%d failures=%d captures=%d" % [checks, failures, captures])
	quit(0 if failures == 0 else 1)

func _capture(label: String) -> void:
	if not capture_requested: return
	await _frames(3)
	await RenderingServer.frame_post_draw
	var path: String = "res://docs/verification/ui_ux/%s.png" % label
	var result: Error = root.get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	_check(result == OK, "GPU screenshot saved: %s" % label)
	if result == OK: captures += 1

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	await _frames(2)
	event.pressed = false
	root.push_input(event, true)
	await _frames(2)

func _click(button: Button, code: MouseButton) -> void:
	await _frames(2)
	await _mouse(button.get_global_rect().get_center(), code)

func _joy(button: JoyButton) -> void:
	await _frames(2)
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	root.push_input(event, true)
	await _frames(2)
	event.pressed = false
	root.push_input(event, true)
	await _frames(2)

func _axis(axis: JoyAxis, value: float) -> void:
	await _frames(2)
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	root.push_input(event, true)
	await _frames(2)

func _mouse(position: Vector2, code: MouseButton) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = code
	event.pressed = true
	root.push_input(event, true)
	await _frames(2)
	event.pressed = false
	root.push_input(event, true)
	await _frames(2)

func _frames(count: int) -> void:
	for frame: int in count: await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition: failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])
