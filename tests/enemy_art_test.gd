extends "res://tests/survival_test_base.gd"
## Sprite ownership, alpha footing and real DamageEvent/FSM integration.

const SLIME_SCENE: PackedScene = preload("res://scenes/enemies/slime_enemy.tscn")
const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/boss_golem.tscn")
const MUTANT_SCENE: PackedScene = preload("res://scenes/enemies/mutant_slime.tscn")


func _initialize() -> void:
	suite = "enemy_art"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	for texture: Texture2D in [SlimeSpriteSkin.SPRITE_TEXTURE, BossGolemSkin.SPRITE_TEXTURE]:
		var raw := Image.new()
		var error: Error = raw.load_png_from_buffer(FileAccess.get_file_as_bytes(texture.resource_path))
		_check(error == OK and raw.detect_alpha() != Image.ALPHA_NONE, "Enemy cutout is a readable PNG with real alpha: %s" % texture.resource_path)
		_check(raw.get_pixel(0, 0).a == 0.0 and raw.get_pixel(raw.get_width() - 1, raw.get_height() - 1).a == 0.0, "Enemy PNG corners contain transparent background")
		var data: Dictionary = EnemySpriteArt.alpha_geometry(texture)
		var bounds: Rect2i = data["bounds"]
		_check(bounds.size.y > 100 and bounds.size.x > 100 and bounds.end.y <= raw.get_height(), "Alpha silhouette supplies valid bounds rather than canvas size")
		_check(data.size() == 2 and data == texture.get_meta(EnemySpriteArt.CACHE_KEY), "Native texture cache stores only footprint geometry")
	var slime: SlimeEnemy = level.enemies[0]
	var skin: SlimeSpriteSkin = slime.get_node("SlimeSpriteSkin") as SlimeSpriteSkin
	var body: CollisionShape2D = slime.get_node("BodyCollision") as CollisionShape2D
	var collision_transform: Transform2D = body.global_transform
	var hurt_transform: Transform2D = slime.hurtbox.global_transform
	var collision_id: int = body.shape.get_instance_id()
	var hurt_shape: CollisionShape2D = slime.hurtbox.get_node("CollisionShape2D") as CollisionShape2D
	var hurt_id: int = hurt_shape.shape.get_instance_id()
	_check(skin != null and skin.sprite.texture == SlimeSpriteSkin.SPRITE_TEXTURE and not slime.visual.visible, "Normal room Slime uses the supplied Sprite2D and hides its old green polygon")
	_check(not (slime.get_node("Eyes") as Line2D).visible and skin.sprite.material is ShaderMaterial, "Normal sprite has no placeholder eyes and owns a real white-flash shader")
	_check(is_equal_approx(skin.sprite.scale.y * float((skin.geometry["bounds"] as Rect2i).size.y), SlimeSpriteSkin.NORMAL_HEIGHT), "Slime scale follows its visible alpha height")
	var physical_foot: Vector2 = body.to_global(Vector2(0, body.shape.get_rect().end.y))
	_check(skin.get_foot_world().is_equal_approx(physical_foot), "Slime lowest solid pixels touch its existing physical floor pivot")
	slime._facing = 1.0
	skin.refresh_skin()
	_check(not skin.sprite.flip_h and skin.get_foot_world().is_equal_approx(physical_foot), "Right facing preserves alpha boot/contact pivot")
	slime._facing = -1.0
	skin.refresh_skin()
	_check(skin.sprite.flip_h and skin.get_foot_world().is_equal_approx(physical_foot), "Left mirror compensates asymmetric source padding")
	var result: DamageResult = slime.hurtbox.take_damage(_damage(slime.hurtbox, 5))
	skin.refresh_skin()
	_check(result.actual_damage == 5.0 and slime.health.current_health == 55.0 and skin._material.get_shader_parameter("flash") == 1.0, "Real incoming DamageEvent gives Slime damage and a white flash once")
	_check(slime.state_machine.get_state_id() == &"hurt" and collision_transform == body.global_transform and hurt_transform == slime.hurtbox.global_transform, "Sprite damage feedback cannot move collider or Hurtbox transforms")
	slime._flash_remaining = 0.08
	slime._update_visuals()
	skin.refresh_skin()
	_check(skin._material.get_shader_parameter("flash") == 0.0 and skin.sprite.modulate.g < 0.3, "Slime white flash advances to the original red flash")
	slime._flash_remaining = 0.0
	slime.state_machine.transition_to(&"patrol")
	slime._update_visuals()
	skin.refresh_skin()
	_check(skin.tint == Color.WHITE and skin.sprite.modulate.a == 1.0, "Unhurt normal Slime preserves the supplied green art without a second green tint")
	slime.enraged = true
	slime._update_visuals()
	skin.refresh_skin()
	_check((slime.get_node("Eyes") as Line2D).visible and (slime.get_node("Eyes") as Line2D).default_color.r == 1.0 and (slime.get_node("Eyes") as Line2D).z_index > skin.z_index + skin.sprite.z_index, "Manhunter red-eye overlay draws above the supplied sprite")
	slime.enraged = false
	slime.state_machine.transition_to(&"dead")
	slime._state_time = 0.125
	slime.tick_state(&"dead", 0.0)
	skin.refresh_skin()
	_check(is_equal_approx(skin.sprite.modulate.a, 0.5), "Slime sprite reads the unchanged quarter-second death fade")
	slime.reset_at_home()
	slime._update_visuals()
	skin.refresh_skin()
	_check(body.shape.get_instance_id() == collision_id and hurt_shape.shape.get_instance_id() == hurt_id and slime.health.maximum_health == 60.0, "Sprite reset preserves physical Resource identities and 60HP definition")
	var mutant: MutantSlime = MUTANT_SCENE.instantiate()
	mutant.ai_enabled = false
	level.add_child(mutant)
	await _step(3)
	var mutant_skin: SlimeSpriteSkin = mutant.get_node("SlimeSpriteSkin") as SlimeSpriteSkin
	_check(mutant_skin.tint == SlimeSpriteSkin.POISON_TINT and mutant.scale == Vector2(2, 2), "Poison mutant inherits PNG skin with distinct tint and original double scale")
	mutant.projectile_element = &"ice"
	mutant_skin.refresh_skin()
	_check(mutant_skin.tint == SlimeSpriteSkin.ICE_TINT and mutant.health.maximum_health == 120.0, "Ice mutant retains a separate cold tint and gameplay health")
	mutant.queue_free()
	await _step(3)
	await _test_boss_sprite()
	await _test_lifetimes()


func _test_boss_sprite() -> void:
	var boss: BossGolem = BOSS_SCENE.instantiate()
	boss.ai_enabled = false
	boss.position = Vector2(900, 640)
	level.add_child(boss)
	await _step(3)
	var skin: BossGolemSkin = boss.get_node("GolemStoneSkin") as BossGolemSkin
	var body: CollisionShape2D = boss.get_node("Body") as CollisionShape2D
	var body_id: int = body.shape.get_instance_id()
	var body_transform: Transform2D = body.global_transform
	_check(skin.sprite.texture == BossGolemSkin.SPRITE_TEXTURE and boss.self_modulate.a == 0.0 and skin.sprite.modulate.a == 1.0 and skin.core_light.color == BossGolemSkin.JADE, "Boss PNG replaces its old block, keeps children visible and lights its chest jade green")
	_check(is_equal_approx(skin.sprite.scale.y * float((skin.geometry["bounds"] as Rect2i).size.y), 100.0) and skin.get_foot_world().is_equal_approx(boss.global_position), "Boss feet align to the unchanged 100px physical silhouette")
	_check(boss.health.maximum_health == 500.0 and body.shape.get_rect().size == Vector2(76, 100), "Boss art does not change its 500HP or 76 by 100 collider")
	boss.facing = 1.0
	boss.fsm.transition_to(&"sweep")
	skin.refresh_skin()
	_check(skin._state == &"sweep" and not skin._active and not boss.attack_hitbox.active, "Boss sweep telegraph reads windup without opening the hitbox")
	boss.state_time = 0.5
	boss.tick_state(&"sweep", 0.0)
	await _step(1) # Hitbox deliberately publishes its CollisionShape with set_deferred.
	skin.refresh_skin()
	_check(skin._active and boss.attack_hitbox.active and (boss.attack_hitbox.collision_shape.shape as RectangleShape2D).size == Vector2(320, 26), "Boss active sweep keeps the exact existing 320px gameplay reach")
	boss.fsm.transition_to(&"stomp")
	boss.attack_hitbox.deactivate()
	skin.refresh_skin()
	_check(skin._state == &"stomp" and body.global_transform == body_transform, "Stomp warning changes only art until the original FSM launches")
	boss.phase = 2
	skin.refresh_skin()
	_check(skin.current_tint == BossGolemSkin.AMBER and skin.sprite.modulate.b < 1.0 and boss.movement_speed() == 104.0, "Phase2 keeps warm readable sprite/light and original 30 percent speed increase")
	boss.facing = -1.0
	skin.refresh_skin()
	_check(skin.sprite.flip_h and skin.get_foot_world().is_equal_approx(boss.global_position), "Boss mirror preserves foot pivot even with floating talisman margins")
	var damage: DamageEvent = _damage(boss.hurtbox, 5)
	damage.stagger_force = 100.0
	boss.hurtbox.take_damage(damage)
	skin.refresh_skin()
	_check(skin._stone_flash == 1.0 and skin._staggered and boss.fsm.get_state_id() == &"staggered", "Real boss damage and stagger propagate to PNG shader and rune cue")
	boss.fsm.transition_to(&"dead")
	boss.state_time = 0.3
	skin.refresh_skin()
	_check(is_equal_approx(skin.modulate.a, 0.5) and skin.core_light.energy < 0.6, "Boss PNG and core light fade on the original 0.6-second death clock")
	_check(body.shape.get_instance_id() == body_id and body.global_transform == body_transform, "Every phase, flash and mirror keeps the same body Resource and transform")
	var light_id: int = skin.core_light.get_instance_id()
	boss.queue_free()
	await _step(3)
	_check(not is_instance_id_valid(light_id), "Boss despawn releases its sprite material and core light owner")


func _test_lifetimes() -> void:
	var fixture := Node2D.new()
	root.add_child(fixture)
	var source_hashes: Dictionary = {}
	for texture: Texture2D in [SlimeSpriteSkin.SPRITE_TEXTURE, BossGolemSkin.SPRITE_TEXTURE]:
		source_hashes[texture.resource_path] = FileAccess.get_sha256(texture.resource_path)
	var objects: int = 0
	var resources: int = 0
	for cycle: int in 10:
		var slime: SlimeEnemy = SLIME_SCENE.instantiate()
		slime.ai_enabled = false
		fixture.add_child(slime)
		var slime_skin := SlimeSpriteSkin.new()
		slime.add_child(slime_skin)
		var boss: BossGolem = BOSS_SCENE.instantiate()
		boss.ai_enabled = false
		fixture.add_child(boss)
		var boss_skin := BossGolemSkin.new()
		boss.add_child(boss_skin)
		if cycle == 0:
			_check(slime_skin.sprite.texture == SlimeSpriteSkin.SPRITE_TEXTURE and boss_skin.sprite.texture == BossGolemSkin.SPRITE_TEXTURE, "Repeated enemies share imported PNG resources instead of cloning pixels")
			slime_skin.bind(null)
			boss_skin.bind(null)
			_check(slime.visual.visible and (slime.get_node("Eyes") as Line2D).visible and boss.self_modulate.a == 1.0, "Unbinding restores hidden feedback adapters for editor reuse")
			slime_skin.bind(slime)
			boss_skin.bind(boss)
			_check(not slime.visual.visible and boss.self_modulate.a == 0.0, "Rebinding hides legacy shapes exactly once")
		slime.queue_free()
		boss.queue_free()
		await _step(3)
		if cycle == 1:
			objects = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("STRESS enemy sprites objects=%d->%d resources=%d->%d" % [objects, objects_after, resources, resources_after])
	_check(objects_after <= objects and resources_after <= resources, "Ten Slime/Boss skin lifecycles retain no growing Node/material population")
	for path: String in source_hashes:
		_check(FileAccess.get_sha256(path) == source_hashes[path], "Sprite rendering, flash and mirror leave cutout PNG bytes unchanged")
	fixture.queue_free()
	await _step(3)
