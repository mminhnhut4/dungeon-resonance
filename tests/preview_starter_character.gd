extends "res://tests/preview_combat_art.gd"
## Finite GPU inspection: actual approved atlas, real input, real damage and GUI.

var rig: PlayerVisualRig
var camera: PlayerCamera


func _run() -> void:
	var audio: Node = root.get_node("AudioManager")
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	if DisplayServer.get_name() == "headless":
		print("FAIL: Starter character preview requires GPU rendering")
		await audio.shutdown()
		quit(1)
		return
	campaign = preload("res://scenes/linear_campaign.tscn").instantiate() as LinearCampaign
	campaign.profile = SanctuaryProfile.new()
	campaign.profile.save_path = "user://verification/preview_starter_character.json"
	root.add_child(campaign)
	current_scene = campaign
	campaign.survival.director.automatic = false
	_freeze_input_and_ai()
	rig = campaign.player.get_node("Visuals") as PlayerVisualRig
	camera = campaign.player.get_node("Camera2D") as PlayerCamera
	camera.follow_enabled = false
	camera.position = Vector2(0.0, -30.0)
	camera.position_smoothing_enabled = false
	camera.shake_intensity = 0.0
	camera.reset_shake()
	campaign.player.relocate(Vector2(540.0, 640.0))
	campaign.player.health.reset_health()
	campaign.player.energy.reset()
	_pointer(Vector2(850.0, 612.0))
	await _frames(12)
	_verify(rig.is_modular_active() and rig._modular_base.size() >= 12, "Actual Player scene loads the approved separate body atlas")
	_verify(campaign.gear.inventory.equipment_uids.size() == 7 and campaign.gear.inventory.equipment_uids.all(func(uid: int) -> bool: return uid > 0), "All seven starter equipment slots are worn in the real campaign")
	await _starter_capture("foyer_native")
	camera.zoom = Vector2(3.5, 3.5)
	camera.force_update_scroll()
	_pointer(Vector2(850.0, 612.0))
	await _frames(4)
	await _starter_capture("idle_right_closeup")
	_pointer(Vector2(250.0, 612.0))
	await _frames(4)
	_verify(rig.visual_facing_left, "Close-up left pose follows the actual viewport cursor")
	await _starter_capture("idle_left_closeup")
	_pointer(Vector2(850.0, 612.0))
	campaign.player.suspend_controls(false)
	await _frames(4)
	_press(KEY_D, true)
	await _frames(8)
	_verify(rig.displayed_animation == &"run" and campaign.player.velocity.x > 0.0, "Real D input runs the modular actor")
	await _starter_capture("run")
	_press(KEY_D, false)
	await _frames(12)
	campaign.player.relocate(Vector2(540.0, 640.0))
	await _frames(5)
	_press(KEY_SPACE, true)
	await _wait_pose(&"jump", 30)
	await _frames(6)
	_verify(campaign.player.velocity.y < 0.0 and rig.displayed_animation == &"jump", "Real held jump reaches its ascending pose")
	await _starter_capture("jump")
	_press(KEY_SPACE, false)
	await _wait_pose(&"fall", 90)
	await _starter_capture("fall")
	await _wait_pose(&"land", 90)
	await _frames(2)
	await _starter_capture("landing")
	await _frames(16)
	_press(KEY_SHIFT, true)
	await _wait_pose(&"dash", 30)
	await _frames(2)
	_verify(campaign.player.motor.is_dashing, "Real Shift input activates the original dash motor")
	await _starter_capture("dash")
	_press(KEY_SHIFT, false)
	await _frames(28)
	await _capture_inventory_and_shirt()
	await _capture_real_combat()
	await _capture_real_hurt_and_death()
	for code: int in [KEY_D, KEY_SPACE, KEY_SHIFT, KEY_J, KEY_I, KEY_TAB]:
		_press(code, false)
	if campaign.gear.modal.is_open:
		campaign.gear.modal.close()
	campaign.queue_free()
	await _frames(5)
	await audio.shutdown()
	print("STARTER CHARACTER PREVIEW: %d captures; %s" % [captures, "FAIL" if failed else "PASS"])
	quit(1 if failed else 0)


func _capture_inventory_and_shirt() -> void:
	var inventory: GearInventory = campaign.gear.inventory
	var modal: InventoryScreen = campaign.gear.modal as InventoryScreen
	var shirt_uid: int = inventory.equipment_uids[EquipmentData.SlotType.ARMOR]
	_press(KEY_TAB, true)
	await _frames(4)
	_press(KEY_TAB, false)
	_verify(modal.is_open and modal.equipment_buttons.size() == 7, "Real Tab input opens all seven RPG equipment slots")
	await _starter_capture("inventory_seven_slots")
	await _mouse(modal.equipment_buttons[EquipmentData.SlotType.ARMOR], MOUSE_BUTTON_RIGHT)
	_verify(inventory.equipment_uids[EquipmentData.SlotType.ARMOR] == 0 and inventory.equipment_bag_uids().has(shirt_uid), "Actual GUI right-click removes the starter shirt into its bag UID")
	modal.close()
	await _frames(4)
	await _starter_capture("shirt_unequipped")
	modal.open()
	await _frames(3)
	var index: int = modal.bag_uids.find(shirt_uid)
	_verify(index >= 0 and index < modal.bag_buttons.size(), "Removed shirt remains reachable in the visible bag grid")
	if index >= 0 and index < modal.bag_buttons.size():
		await _mouse(modal.bag_buttons[index], MOUSE_BUTTON_LEFT)
	_verify(inventory.equipment_uids[EquipmentData.SlotType.ARMOR] == shirt_uid, "Actual GUI left-click equips the same shirt without duplication")
	modal.close()
	_pointer(campaign.player.global_position + Vector2(280.0, -22.0))
	await _frames(4)
	await _starter_capture("shirt_reequipped")


func _capture_real_combat() -> void:
	campaign.player.relocate(Vector2(540.0, 640.0))
	campaign.player.suspend_controls(false)
	await _frames(5)
	var target: SlimeEnemy
	for enemy: Node2D in campaign.living_enemies():
		if target == null and enemy is SlimeEnemy:
			target = enemy as SlimeEnemy
		else:
			enemy.global_position = Vector2(1120.0, 640.0)
	if target == null:
		_verify(false, "Real melee preview needs a live Slime Hurtbox")
		return
	target.ai_enabled = false
	target.contact_damage_enabled = false
	target.global_position = Vector2(583.0, 640.0)
	var before: int = target.hit_count
	_pointer(target.hurtbox.global_position)
	_press(KEY_J, true)
	await _wait_pose(&"attack_slash_1", 30)
	for frame: int in 45:
		if campaign.player.equipped_weapon.hitbox.active:
			break
		await _frames(1)
	_verify(campaign.player.equipped_weapon.hitbox.active and rig.displayed_animation == &"attack_slash_1", "Real J attack displays the modular slash inside the authoritative hit window")
	await _starter_capture("melee_active")
	_press(KEY_J, false)
	await _frames(30)
	_verify(target.hit_count > before, "Real melee Hitbox resolves contact against the Slime Hurtbox")
	_pointer(campaign.player.global_position + Vector2(220.0, -60.0))
	campaign.player.energy.reset()
	campaign.player.resonance_controller.reset_runtime()
	_press(KEY_I, true)
	await _wait_pose(&"cast_spell", 30)
	await _starter_capture("cast_spell")
	_press(KEY_I, false)
	await _frames(36)
	campaign.executor.clear_entities()


func _capture_real_hurt_and_death() -> void:
	campaign.player.relocate(Vector2(540.0, 640.0))
	await _frames(5)
	campaign.player.hurtbox.set_invulnerable(false)
	campaign.player.damage_grace_remaining = 0.0
	var result: DamageResult = campaign.player.hurtbox.take_damage(_player_damage(6.0))
	var expected: float = 6.0 * 100.0 / (100.0 + campaign.player.hurtbox.damage_resolver.armor_rating)
	_verify(is_equal_approx(result.actual_damage, expected), "Real DamageEvent lowers Player HP once after the starter armor stage")
	await _wait_pose(&"hurt", 50)
	await _starter_capture("hurt")
	await _frames(42)
	campaign.player.hurtbox.set_invulnerable(false)
	campaign.player.damage_grace_remaining = 0.0
	campaign.player.hurtbox.take_damage(_player_damage(999.0))
	await _wait_pose(&"dead", 50)
	for frame: int in 60:
		if rig.displayed_time >= 0.4:
			break
		await _frames(1)
	_verify(campaign.outcome == &"defeat" and campaign.end_panel.visible and rig.displayed_animation == &"dead", "Lethal real damage activates death pose and the actual defeat flow")
	# Hide the overlay only for this isolated pose evidence, then restore its UI.
	campaign.end_panel.hide()
	await _starter_capture("death_pose")
	campaign.end_panel.show()
	await _starter_capture("defeat_flow")


func _player_damage(amount: float) -> DamageEvent:
	var event := DamageEvent.new()
	event.source_id = 987654
	event.source_team_id = 2
	event.target_id = campaign.player.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.base_damage = amount
	event.attack_direction = Vector2.LEFT
	return event


func _press(code: int, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = code
	key.pressed = pressed
	Input.parse_input_event(key)


func _wait_pose(clip: StringName, maximum: int) -> void:
	for frame: int in maximum:
		if rig.displayed_animation == clip:
			return
		await _frames(1)
	_verify(false, "Timed out waiting for actual %s pose; saw %s" % [clip, rig.displayed_animation])


func _mouse(button: Button, code: MouseButton) -> void:
	var click := InputEventMouseButton.new()
	click.position = button.get_global_rect().get_center()
	click.button_index = code
	click.pressed = true
	root.push_input(click, true)
	await _frames(1)
	click.pressed = false
	root.push_input(click, true)
	await _frames(3)


func _verify(condition: bool, label: String) -> void:
	if not condition:
		failed = true
	print("%s: %s" % ["PASS" if condition else "FAIL", label])


func _starter_capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://docs/verification/starter_character_" + label + ".png")
	var status: Error = image.save_png(path)
	_verify(status == OK, "Capture " + path)
	captures += 1
