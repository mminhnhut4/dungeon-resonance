extends "res://tests/survival_test_base.gd"

const RIG_SCENE: PackedScene = preload("res://scenes/actors/player_visual_rig.tscn")
const RIG_SCRIPT: GDScript = preload("res://scripts/presentation/player_visual_rig.gd")
const SOURCE_PATH: String = "res://assets/sprites/player/player_concept_full.png"


func _initialize() -> void:
	suite = "player_art"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.energy.enabled = false
	player.set_physics_process(false)
	var rig: Node2D = player.get_node("Visuals") as Node2D
	rig.set_physics_process(false)
	rig.set_modular_skin(null) # Explicit historical PNG/14-bone fixture; assertions stay intact.
	rig.swordsman_body_texture = null # Explicit masked-mage fixture.
	rig.prepare_concept(load(SOURCE_PATH))
	var source_hash: String = FileAccess.get_sha256(SOURCE_PATH)
	var raw := Image.new()
	var load_status: Error = raw.load_png_from_buffer(FileAccess.get_file_as_bytes(SOURCE_PATH))
	_check(load_status == OK and raw.get_size() == Vector2i(1248, 832), "Actual player concept loads from a normalized 1248 by 832 PNG")
	_check(raw.get_pixel(0, 0).a == 1.0 and raw.get_pixel(0, 0).r > 0.95, "Original concept retains its opaque pale background")
	var synthetic := Image.create(32, 24, false, Image.FORMAT_RGBA8)
	synthetic.fill(Color.WHITE)
	synthetic.fill_rect(Rect2i(8, 3, 16, 18), Color(0.08, 0.12, 0.18))
	synthetic.fill_rect(Rect2i(12, 5, 8, 6), Color.WHITE)
	var before_pixels: int = hash(synthetic.get_data())
	var data: Dictionary = RIG_SCRIPT.build_edge_mask(synthetic)
	var masked: Image = (data["texture"] as Texture2D).get_image()
	_check(masked.get_pixel(0, 0).a == 0.0 and masked.get_pixel(4, 12).a == 0.0, "Edge-connected pale backdrop becomes transparent at runtime")
	_check(masked.get_pixel(15, 8).a == 1.0 and masked.get_pixel(15, 8).r == 1.0, "An enclosed white face or mask remains fully opaque")
	_check(masked.get_pixel(9, 12).a == 1.0 and hash(synthetic.get_data()) == before_pixels, "Runtime alpha construction preserves colored silhouette and source pixels")
	_check(data["bounds"] == Rect2i(8, 3, 16, 18) and data["foot_pixel"] == Vector2(16, 21), "Alpha bounds and lowest boot midpoint produce a stable foot pivot")
	var blank := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	blank.fill(Color.WHITE)
	_check(RIG_SCRIPT.build_edge_mask(blank).is_empty(), "All-background input cannot create an invisible live sprite")
	_check(rig.concept_sprite != null and rig.concept_pivot != null and rig.concept_sprite.texture.get_size() == Vector2(1248, 832), "Live Player renders the actual concept through a runtime overlay")
	_check(not player.body_sprite.visible and player.body_sprite.texture != null, "Legacy body sprite stays as a hidden feedback adapter rather than a second body")
	var actual_mask: Image = rig.concept_sprite.texture.get_image()
	_check(actual_mask.get_pixel(0, 0).a == 0.0 and actual_mask.get_pixel(1247, 600).a == 0.0, "Actual source background is transparent without rewriting the PNG")
	var face_location := Vector2i(655, 142)
	var original_face: Color = raw.get_pixelv(face_location)
	_check(actual_mask.get_pixelv(face_location).a == 1.0 and original_face.r > 0.7, "White mask on the supplied character survives runtime alpha extraction")
	var cache: Dictionary = rig.concept_body_texture.get_meta(RIG_SCRIPT.CONCEPT_CACHE_KEY, {})
	_check(cache.size() == 3 and cache["texture"] == rig.concept_sprite.texture and (cache["texture"] as Resource).get_script() == null, "Native source texture owns one bounded mask cache without GDScript references")
	var collision: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var physical_foot: Vector2 = collision.to_global(Vector2(0.0, collision.shape.get_rect().end.y))
	_check(rig.get_concept_foot_world().is_equal_approx(physical_foot), "Visible boot pivot aligns with the unchanged physical collider bottom")
	_check(is_equal_approx(rig.concept_sprite.scale.y * rig.concept_bounds.size.y, rig.concept_height), "Concept scales by visible silhouette height instead of the entire canvas margin")
	player.facing_direction = 1.0
	player._update_visuals()
	_aim(player.global_position + Vector2(-250, -50))
	rig.sync_from_player(0.0)
	_check(rig.concept_sprite.flip_h and rig.visual_facing_left and player.facing_direction == 1.0 and not player.body_sprite.flip_h, "Mouse-left flips the art while movement-facing remains right")
	_check(rig.get_concept_foot_world().is_equal_approx(physical_foot), "Asymmetric source boot pivot remains anchored after UV mirroring")
	player.facing_direction = -1.0
	player._update_visuals()
	_aim(player.global_position + Vector2(250, -50))
	rig.sync_from_player(0.0)
	_check(not rig.concept_sprite.flip_h and not rig.visual_facing_left and player.facing_direction == -1.0 and player.body_sprite.flip_h, "Mouse-right flips the art independently of leftward movement")
	player.damage_grace_remaining = 0.5
	player._update_visuals()
	rig.sync_from_player(0.0)
	_check(rig.concept_sprite.modulate == player.body_sprite.modulate and rig.concept_sprite.modulate.g < 0.5, "Actual concept receives existing damage flash and iframe alpha")
	player.damage_grace_remaining = 0.0
	player._update_visuals()
	player.action_state_machine.transition_to(&"ready")
	player.locomotion_state_machine.transition_to(&"idle")
	rig.bind(player)
	rig.sync_from_player(0.0)
	_check(rig.breath_tween != null and rig.breath_tween.is_valid() and rig.breath_tween.is_running(), "Idle starts a single bound breathing Tween")
	var breathing: Tween = rig.breath_tween
	breathing.pause()
	breathing.custom_step(0.6)
	_check(is_equal_approx(rig.concept_pivot.scale.y, 1.03) and rig.get_concept_foot_world().is_equal_approx(physical_foot), "First 0.6-second Tween breath reaches 1.03 without lifting the boots")
	breathing.custom_step(0.6)
	_check(is_equal_approx(rig.concept_pivot.scale.y, 1.0), "Full 1.2-second breathing cycle returns to scale one")
	level.combat_feedback._frozen_this_tick = true
	rig.sync_from_player(0.0)
	_check(rig.breath_tween == breathing and not breathing.is_running(), "Hit-stop pauses the same breathing Tween")
	var paused_scale: Vector2 = rig.concept_pivot.scale
	await _step(5)
	_check(rig.concept_pivot.scale == paused_scale, "Paused breathing cannot advance during freeze")
	level.combat_feedback.reset_feedback()
	rig.sync_from_player(0.0)
	_check(rig.breath_tween == breathing and breathing.is_running(), "Ending hit-stop resumes the existing Tween without duplication")
	player.locomotion_state_machine.transition_to(&"run")
	rig.sync_from_player(0.0)
	_check(rig.breath_tween == null and not breathing.is_valid() and rig.concept_pivot.scale == Vector2.ONE, "Movement kills breathing and restores the foot-pivot scale")
	player.locomotion_state_machine.transition_to(&"idle")
	rig.sync_from_player(0.0)
	var idle_tween: Tween = rig.breath_tween
	var weapon: Weapon = player.equipped_weapon
	var weapon_transform: Transform2D = weapon.global_transform
	player.action_state_machine.transition_to(&"attack")
	var committed: Vector2 = weapon.snapshot.attack_direction
	_aim(player.global_position + Vector2(-250, -50))
	rig.sync_from_player(0.0)
	_check(rig.breath_tween == null and not idle_tween.is_valid() and rig.concept_sprite.flip_h, "Attack stops idle breathing while the art continues to face the pointer")
	_check(weapon.snapshot.attack_direction.is_equal_approx(committed) and rig.committed_direction.is_equal_approx(committed), "Live visual flipping cannot redirect an already committed slash")
	_check(weapon.phase == Weapon.Phase.WINDUP and not weapon.hitbox.active and collision.shape.get_rect().size.y == 36.0 and weapon.global_position.is_equal_approx(weapon_transform.origin), "Art and Tween cannot alter hit-window timing or collider geometry")
	player.action_state_machine.transition_to(&"ready")
	rig.sync_from_player(0.0)
	var before_dead: Tween = rig.breath_tween
	player.action_state_machine.transition_to(&"dead")
	rig.sync_from_player(0.0)
	_check(rig.breath_tween == null and not before_dead.is_valid() and rig.concept_pivot.scale == Vector2.ONE, "Death cancels the breath and restores the visual anchor")
	player.action_state_machine.transition_to(&"ready")
	rig.sync_from_player(0.0)
	rig.bind(null)
	_check(rig.breath_tween == null and rig._actor_id == 0, "Unbind drops both breathing and actor lifetime identity")
	var object_before: int = 0
	var resource_before: int = 0
	for cycle: int in range(8):
		var disposable: Node2D = RIG_SCENE.instantiate()
		disposable.concept_body_texture = rig.concept_body_texture
		root.add_child(disposable)
		disposable.bind(player)
		disposable.sync_from_player(0.0)
		if cycle == 0:
			_check(disposable.concept_sprite.texture == rig.concept_sprite.texture, "Repeated Player rigs reuse the same native alpha texture")
		disposable.queue_free()
		await _step(3)
		if cycle == 1:
			object_before = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resource_before = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var object_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resource_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS: player art objects=%d->%d resources=%d->%d" % [object_before, object_after, resource_before, resource_after])
	_check(object_after <= object_before and resource_after <= resource_before, "Eight concept rig lifecycles release overlays and Tweens without cached-resource growth")
	_check(FileAccess.get_sha256(SOURCE_PATH) == source_hash, "Every runtime mask, mirror and breath leaves original PNG bytes unchanged")
	rig.bind(player)
	rig.set_physics_process(true)
	player.set_physics_process(true)


func _aim(location: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * location
	root.push_input(motion, true)
	player.aim.sample_cursor()
