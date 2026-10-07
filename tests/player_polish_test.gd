extends "res://tests/survival_test_base.gd"
## Regression for the restored placeholder reported beneath the live concept.

const MAGE_PATH: String = "res://assets/sprites/player/player_concept_full.png"
const SWORDSMAN_PATH: String = "res://assets/sprites/player/player_swordsman.png"


func _initialize() -> void:
	suite = "player_polish"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.set_physics_process(false)
	var rig: PlayerVisualRig = player.get_node("Visuals") as PlayerVisualRig
	rig.set_physics_process(false)
	rig.set_modular_skin(null) # Explicit historical PNG/14-bone fixture; assertions stay intact.
	var collision: CollisionShape2D = player.get_node("BodyCollision") as CollisionShape2D
	var hurt_shape: CollisionShape2D = player.get_node("Hurtbox/CollisionShape2D") as CollisionShape2D
	var physical_transform: Transform2D = collision.global_transform
	var hurt_transform: Transform2D = hurt_shape.global_transform
	var weapon_transform: Transform2D = player.equipped_weapon.global_transform
	var body_shape: Shape2D = collision.shape
	var mage_hash: String = FileAccess.get_sha256(MAGE_PATH)
	var swordsman_hash: String = FileAccess.get_sha256(SWORDSMAN_PATH)
	var foot: Vector2 = collision.to_global(Vector2(0.0, collision.shape.get_rect().end.y))
	_check(is_equal_approx(rig.concept_sprite.scale.y * rig.concept_bounds.size.y, 42.0 * 1.25), "Live Player silhouette grows exactly 25 percent above the previous 42px height")
	_check(rig.get_concept_foot_world().is_equal_approx(foot), "Enlarged artwork keeps the visible boot pivot at the stone-floor collider bottom")
	_check(not player.body_sprite.visible and player.body_sprite.self_modulate.a == 0.0, "Legacy colored box is both hidden and locally transparent")
	_check(player.body_sprite.texture != null and player.body_sprite.modulate.a == 1.0, "Hidden feedback adapter retains its texture and authoritative opaque flash data")
	player.body_sprite.visible = true
	_check(not player.body_sprite.visible, "Restoring inherited placeholder visibility immediately suppresses the duplicate body")
	player.damage_grace_remaining = 0.5
	player._update_visuals()
	rig.sync_from_player()
	_check(rig.concept_sprite.modulate == player.body_sprite.modulate and rig.concept_sprite.modulate.g < 0.5, "Hidden adapter still passes damage flash and iframe opacity to the full character")
	_check(player.body_sprite.self_modulate.a == 0.0 and not player.body_sprite.visible, "Damage flash cannot make the blue or white fallback box visible")
	player.damage_grace_remaining = 0.0
	player._update_visuals()
	for weapon_id: String in ["demon_greatsword", "gale_dual_daggers", "storm_arcane_staff", "ancient_sword"]:
		player.equipped_weapon.equip(load("res://data/weapons/%s.tres" % weapon_id))
		rig.sync_from_player()
		var expected: Texture2D = load(MAGE_PATH if weapon_id == "storm_arcane_staff" else SWORDSMAN_PATH)
		_check(rig.concept_body_texture == expected and is_equal_approx(rig.concept_sprite.scale.y * rig.concept_bounds.size.y, 52.5), "Weapon swap keeps its correct enlarged skin: " + weapon_id)
		_check(rig.get_concept_foot_world().is_equal_approx(foot) and not player.body_sprite.visible, "Weapon swap keeps boots grounded with no fallback rendering: " + weapon_id)
	for direction: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2(-1.0, -1.0), Vector2(1.0, 1.0)]:
		player.aim.target_position = player.global_position + direction * 150.0
		rig.sync_from_player()
		_check(rig.concept_sprite.flip_h == (direction.x < 0.0) and rig.get_concept_foot_world().is_equal_approx(foot), "Enlarged asymmetric boots remain anchored while aiming " + str(direction))
	player.action_state_machine.transition_to(&"ready")
	player.locomotion_state_machine.transition_to(&"idle")
	rig.bind(player) # Start a fresh cycle after the test room's warm-up frames.
	rig.sync_from_player()
	var breathing: Tween = rig.breath_tween
	_check(breathing != null and breathing.is_valid(), "Enlarged Player still owns one idle breathing Tween")
	breathing.pause()
	breathing.custom_step(0.6)
	_check(is_equal_approx(rig.concept_pivot.scale.y, 1.03) and rig.get_concept_foot_world().is_equal_approx(foot), "Full inhale enlarges art upward without moving the floor contact")
	breathing.custom_step(0.6)
	_check(rig.concept_pivot.scale == Vector2.ONE and rig.get_concept_foot_world().is_equal_approx(foot), "Full exhale returns to the enlarged base size and the same grounded pivot")
	_aim(player.global_position + Vector2(250.0, -80.0))
	player.action_state_machine.transition_to(&"attack")
	rig.sync_from_player()
	var attack_direction: Vector2 = player.equipped_weapon.snapshot.attack_direction
	_check(rig.breath_tween == null and not breathing.is_valid() and not player.equipped_weapon.hitbox.active, "Attack stops breathing while preserving the original wind-up hit window")
	var step: AttackStepDefinition = player.equipped_weapon.definition.combo_steps[0]
	player.equipped_weapon.advance(step.windup_seconds + step.active_seconds * 0.25)
	var active_hit_transform: Transform2D = player.equipped_weapon.hitbox.global_transform
	_aim(player.global_position + Vector2(-250.0, 80.0))
	rig.sync_from_player()
	_check(player.equipped_weapon.hitbox.active and player.equipped_weapon.hitbox.global_transform.is_equal_approx(active_hit_transform), "Enlarged mirrored artwork cannot shift an active gameplay hitbox")
	_check(rig.committed_direction.is_equal_approx(attack_direction) and player.equipped_weapon.snapshot.attack_direction.is_equal_approx(attack_direction), "Live mouse-facing art cannot redirect the already committed damage direction")
	player.action_state_machine.transition_to(&"ready")
	player.reset_movement_at(player.global_position)
	rig.sync_from_player()
	_check(not player.body_sprite.visible and player.body_sprite.self_modulate.a == 0.0, "Respawn/reset does not restore the colored rectangle")
	_check(collision.global_transform.is_equal_approx(physical_transform) and hurt_shape.global_transform.is_equal_approx(hurt_transform) and collision.shape == body_shape, "All enlarged-skin actions preserve body and Hurtbox geometry")
	_check(player.equipped_weapon.global_transform.origin.is_equal_approx(weapon_transform.origin), "Visual size and grounded pivot never move the independent WeaponSocket")
	_check(FileAccess.get_sha256(MAGE_PATH) == mage_hash and FileAccess.get_sha256(SWORDSMAN_PATH) == swordsman_hash, "Player polish keeps both imported source PNG files unchanged")
	rig.set_physics_process(true)
	player.set_physics_process(true)


func _aim(location: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = root.get_canvas_transform() * location
	root.push_input(motion, true)
	player.aim.sample_cursor()
