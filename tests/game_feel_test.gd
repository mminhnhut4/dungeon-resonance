extends "res://tests/survival_test_base.gd"

func _initialize() -> void:
	suite = "game_feel"
	super._initialize()

func test_system() -> void:
	session.set_enabled(false)
	player.set_physics_process(false)
	var camera: PlayerCamera = player.get_node("Camera2D") as PlayerCamera
	var rig: PlayerVisualRig = player.get_node("Visuals") as PlayerVisualRig
	rig.set_physics_process(false)
	rig.set_modular_skin(null) # Explicit historical PNG/14-bone fixture; assertions stay intact.
	_check(camera.is_current() and level.combat_feedback.camera == camera, "Player camera owns follow and original combat shake")
	_check(camera.zoom == Vector2(1.35, 1.35), "Gameplay zoom is 1.35 on both axes")
	camera.set_process(false)
	camera.lookahead = Vector2.ZERO
	var position_before: Vector2 = player.position
	player.aim.target_position = player.global_position + Vector2(1000, 0)
	camera._process(0.02)
	_check(camera.lookahead.x > 0 and camera.lookahead.x < 40, "Lookahead moves smoothly toward cursor")
	for frame: int in 100:
		camera._process(0.02)
	_check(camera.lookahead.length() <= 40.001 and camera.lookahead.x > 39.9, "Lookahead converges to the 40px cap")
	player.aim.target_position = player.global_position + Vector2(-1000, -1000)
	for frame: int in 100:
		camera._process(0.02)
	_check(camera.lookahead.x < 0 and camera.lookahead.y < 0 and camera.lookahead.length() <= 40.001, "Diagonal lookahead respects vector length rather than per-axis caps")
	camera.offset = Vector2(2, -3)
	camera._process(0.02)
	_check(camera.offset == Vector2(2, -3) and player.position == position_before, "Follow cannot overwrite shake or move the physical Player")
	camera.offset = Vector2.ZERO
	var overlay: DungeonDebugOverlay = level.presentation.debug_overlay
	_check(not overlay.enabled and not level.content.info.visible and not level.dummy_a.stats_label.visible, "Debug defaults off including hints and dummy names")
	_check(level.debug_hud.hp_bar.is_visible_in_tree() and not level.debug_hud.get_node("Panel").visible, "Only Player HP remains outside the hidden debug panel")
	var toggle := InputEventKey.new()
	toggle.physical_keycode = KEY_QUOTELEFT
	_check(InputMap.action_has_event(&"debug_overlay", toggle), "Backtick/tilde key is configured without taking F1 from incidents")
	await _key(KEY_QUOTELEFT)
	_check(overlay.enabled and level.dummy_a.stats_label.visible, "Physical debug shortcut shows the registered labels")
	await _key(KEY_QUOTELEFT)
	_check(not overlay.enabled and not level.dummy_a.stats_label.visible, "Second shortcut hides the whole debug cluster")
	var dynamic := Label.new()
	dynamic.text = "Dynamic enemy HP"
	level.add_child(dynamic)
	await _step(2)
	_check(not dynamic.visible, "New labels from spawned enemies also default off")
	var registered_count: int = overlay.widgets.size()
	dynamic.queue_free()
	await _step(2)
	_check(overlay.widgets.size() == registered_count - 1, "Despawned labels immediately release registry references and callbacks")
	var modal := PanelContainer.new()
	level.add_child(modal)
	var instructions := Label.new()
	modal.add_child(instructions)
	await _step(2)
	_check(instructions.visible, "Inventory and crafting modal text remains usable")
	var float_root := Node2D.new()
	float_root.add_to_group(&"combat_text")
	level.add_child(float_root)
	var damage_number := Label.new()
	float_root.add_child(damage_number)
	await _step(2)
	_check(damage_number.visible, "Floating combat numbers remain visible")
	var collision: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var hurt_transform: Transform2D = player.hurtbox.transform
	var shape: Shape2D = collision.shape
	var mage: Texture2D = load("res://assets/sprites/player/player_concept_full.png")
	var swordsman: Texture2D = load("res://assets/sprites/player/player_swordsman.png")
	var alpha: Image = swordsman.get_image()
	_check(alpha.detect_alpha() != Image.ALPHA_NONE and alpha.get_pixel(0, 0).a == 0, "Swordsman PNG contains genuine transparent background")
	var file_hash: String = FileAccess.get_sha256("res://assets/sprites/player/player_swordsman.png")
	for id: String in ["ancient_sword", "shadow_dagger", "demon_greatsword", "gale_dual_daggers", "storm_arcane_staff"]:
		var definition: WeaponDefinition = load("res://data/weapons/%s.tres" % id)
		player.equipped_weapon.equip(definition)
		rig.sync_from_player()
		_check(rig.concept_body_texture == (mage if definition.attack_kind != &"melee" else swordsman), "Gear selects correct skin: " + id)
		_check(rig.get_concept_foot_world().is_equal_approx(collision.to_global(Vector2(0, collision.shape.get_rect().end.y))), "Gear skin keeps boots anchored: " + id)
	player.equipped_weapon.equip(load("res://data/weapons/ancient_sword.tres"))
	rig.sync_from_player()
	var cached: Texture2D = rig.concept_sprite.texture
	var rendered: Image = cached.get_image()
	_check(rendered.get_data() == alpha.get_data(), "Transparent sprite retains every original alpha and ivory fabric pixel")
	for cycle: int in 40:
		player.equipped_weapon.equip(load("res://data/weapons/storm_arcane_staff.tres"))
		rig.sync_from_player()
		player.equipped_weapon.equip(load("res://data/weapons/ancient_sword.tres"))
		rig.sync_from_player()
	_check(rig.concept_sprite.texture == cached, "Repeated gear swaps reuse the same source-owned texture cache")
	_check(player.hurtbox.transform == hurt_transform and collision.shape == shape, "Skin swaps preserve physical collider and Hurtbox")
	_check(FileAccess.get_sha256("res://assets/sprites/player/player_swordsman.png") == file_hash, "Skin swaps never rewrite imported PNG bytes")
	var run: DungeonRun = preload("res://scenes/dungeon_run.tscn").instantiate()
	run.profile = profile
	root.add_child(run)
	run.enter_room(3)
	await _step(2)
	_check(run.boss_panel.visible and run.boss_hp.is_visible_in_tree() and run.boss_name.text == "Golem Cổ Bảo", "Boss HP and clean name remain visible in battle")
	_check(not run.boss_stagger.visible and not run.energy_bar.visible and not run.title.visible, "Boss diagnostics remain hidden by default")
	run.queue_free()
	await _step(4)
	_check(is_instance_valid(overlay) and not overlay.enabled, "Debug state and registry are scoped to each room lifetime")
