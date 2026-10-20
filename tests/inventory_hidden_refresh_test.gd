extends SceneTree
## Targeted read-model regression: hidden loot signals must not rebuild UI.
var checks: int = 0
var failures: int = 0
var baseline: bool = false

func _initialize() -> void:
	Engine.physics_ticks_per_second = 120 if "--hz=120" in OS.get_cmdline_user_args() else 60
	baseline = "--expect-baseline" in OS.get_cmdline_user_args()
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("PASS: " if ok else "FAIL: ") + label)

func step(count: int) -> void:
	for _i: int in count:
		await physics_frame
		await process_frame

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await step(2)
	event.pressed = false
	Input.parse_input_event(event)

func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\", "/")
	check(not qa.is_empty() and OS.get_user_data_dir().replace("\\", "/").begins_with(qa + "/"), "Isolated QA profile")
	if failures: quit(2); return
	AudioServer.set_bus_mute(0, true)
	var flow: GameFlow = preload("res://scenes/maps/prologue_hub.tscn").instantiate()
	flow.save_path_override = "user://verification/inventory_hidden.json"
	root.add_child(flow)
	await step(8)
	var inventory: GearInventory = flow.active_scene.gear.inventory
	var screen: InventoryScreen = flow.active_scene.gear.modal
	check(not screen.is_open and not screen.panel.visible, "Real inventory starts closed")
	var material: StringName = MaterialCatalog.IDS[0]
	var before_count: int = inventory.materials.get(material, 0)
	var first_card: int = screen.carried_page.get_child(0).get_instance_id()
	var first_quest: int = screen.journal.quest_list.get_child(0).get_instance_id()
	var times: Array[float] = []
	for _i: int in 6:
		var started: int = Time.get_ticks_usec()
		inventory.add_material(material, 1)
		inventory.add_material(material, 1)
		times.append((Time.get_ticks_usec() - started) / 1000.0)
		await step(1)
	var rebuilt: bool = screen.carried_page.get_child(0).get_instance_id() != first_card or screen.journal.quest_list.get_child(0).get_instance_id() != first_quest
	check(rebuilt if baseline else not rebuilt, "Baseline reproduces hidden rebuild" if baseline else "Closed loot updates preserve carried and quest UI trees")
	check(inventory.materials[material] == before_count + 12, "Inventory owner receives all twelve material pickups")
	await key(KEY_TAB)
	check(screen.is_open and screen.panel.visible and not flow.active_scene.player.controls_enabled, "Tab opens and keeps input ownership")
	check(is_equal_approx(Engine.time_scale, 0.1), "Inventory slowdown remains intentional")
	check(screen.carried_page.has_node("BagMaterial_" + String(material)), "Opening displays material acquired while closed")
	var visible_before: int = screen.carried_page.get_child(0).get_instance_id()
	inventory.add_rune(&"fire")
	check(screen.carried_page.has_node("BagRune_fire") and screen.carried_page.get_child(0).get_instance_id() != visible_before, "Visible inventory publication still updates synchronously")
	await key(KEY_TAB)
	check(not screen.is_open and is_equal_approx(Engine.time_scale, 1.0), "Closing restores gameplay time")
	var explicit_before: int = screen.carried_page.get_child(0).get_instance_id()
	screen.refresh()
	check(screen.carried_page.get_child(0).get_instance_id() != explicit_before, "Explicit hidden refresh retains its synchronous API")
	await key(KEY_M)
	check(screen.is_open and screen.tabs.current_tab == 2 and screen.journal.is_visible_in_tree(), "M still opens the live quest/map projection")
	screen.close()
	var total: float = 0.0
	for value: float in times: total += value
	print("METRIC ", JSON.stringify({"baseline": baseline, "two_pickup_ms": times, "mean_ms": total / times.size(), "max_ms": times.max(), "hidden_rebuilt": rebuilt}))
	flow.queue_free()
	await step(4)
	await root.get_node("AudioManager").shutdown()
	print("RESULT inventory_hidden_refresh checks=%d failures=%d" % [checks, failures])
	quit(1 if failures else 0)
