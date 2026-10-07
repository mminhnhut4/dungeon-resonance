extends SceneTree
## Presentation integration: real Weapon snapshots/phases and finite impact owners.

const TRAIL_SCRIPT: Script = preload("res://scripts/presentation/weapon_trail.gd")
const BURST_SCRIPT: Script = preload("res://scripts/presentation/impact_burst.gd")
const BOSS_SKIN_SCRIPT: Script = preload("res://scripts/presentation/boss_golem_skin.gd")

var fixture: Node2D
var weapon: Weapon
var aim: PlayerAim
var trail: Node2D
var checks: int = 0
var failures: int = 0
var render_preview: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--hz="):
			Engine.physics_ticks_per_second = int(argument.trim_prefix("--hz="))
		elif argument == "--render-preview":
			render_preview = true
	fixture = Node2D.new()
	root.add_child(fixture)
	current_scene = fixture
	aim = PlayerAim.new()
	aim.show_direction_marker = false
	fixture.add_child(aim)
	aim._has_cursor_event = true
	aim._cursor_viewport_position = Vector2(300, 0)
	weapon = preload("res://scenes/weapons/weapon.tscn").instantiate()
	fixture.add_child(weapon)
	weapon.initialize(12345, aim)
	trail = TRAIL_SCRIPT.new()
	weapon.add_child(trail)
	trail.bind(weapon)
	trail.set_process(false)
	await _step(2)
	print("VFX TEST: %d physics ticks/s" % Engine.physics_ticks_per_second)
	_test_trails()
	await _test_impacts()
	await _test_boss_skin()
	await _test_cleanup()
	if render_preview:
		await _preview_gpu()
	fixture.queue_free()
	await _step(3)
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_boss_skin() -> void:
	var boss_actor: BossGolem = preload("res://scenes/enemies/boss_golem.tscn").instantiate()
	boss_actor.ai_enabled = false
	fixture.add_child(boss_actor)
	var skin: Node2D = BOSS_SKIN_SCRIPT.new()
	boss_actor.add_child(skin)
	skin.bind(boss_actor)
	_check(skin.core_light.texture != null and skin.core_light.texture == BURST_SCRIPT.LIGHT_TEXTURE, "Golem skin reuses the shared light texture with one bounded core light")
	_check(skin.current_tint == BOSS_SKIN_SCRIPT.CYAN and boss_actor.phase == 1, "Phase one presents a cyan rune without changing boss state")
	var damage := DamageEvent.new()
	damage.source_id = fixture.get_instance_id()
	damage.source_team_id = 1
	damage.target_id = boss_actor.hurtbox.get_actor_id()
	damage.attack_id = CombatIds.next_id()
	damage.hit_window_id = 1
	damage.root_event_id = damage.attack_id
	damage.base_damage = 2.0
	damage.stagger_force = 100.0
	boss_actor.hurtbox.take_damage(damage)
	skin.refresh_skin()
	_check(skin._stone_flash > 0.0 and skin._staggered, "Damage flash and real stagger state propagate to the faceted skin")
	boss_actor.phase = 2
	skin.refresh_skin()
	_check(skin.current_tint == BOSS_SKIN_SCRIPT.AMBER and not boss_actor.attack_hitbox.active, "Phase two switches to amber emission without opening any gameplay hitbox")
	boss_actor.fsm.transition_to(&"dead")
	boss_actor.state_time = 0.3
	skin.refresh_skin()
	_check(is_equal_approx(skin.modulate.a, 0.5) and skin.core_light.energy < 0.6, "Death fades the whole skin and its core light on the original boss clock")
	var skin_id: int = skin.get_instance_id()
	boss_actor.queue_free()
	await _step(3)
	_check(not is_instance_id_valid(skin_id), "Boss disposal frees its skin and light as child nodes")


func _preview_gpu() -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "GPU preview requires an actual display driver")
		return
	Engine.max_fps = 60
	var background := ColorRect.new()
	background.position = Vector2(-100, -100)
	background.size = Vector2(1600, 1000)
	background.color = Color(0.055, 0.063, 0.105)
	background.z_index = -10
	fixture.add_child(background)
	var paths: Array[String] = ["demon_greatsword", "gale_dual_daggers", "storm_arcane_staff", "blood_spiked_whip"]
	var elements: Array[StringName] = [&"fire", &"ice", &"poison", &"lightning"]
	var colors: Array[Color] = [Color(1, 0.4, 0.1), Color(0.35, 0.85, 1), Color(0.5, 1, 0.2), Color(0.65, 0.4, 1)]
	aim._cursor_viewport_position = Vector2(3000, 0)
	for index: int in paths.size():
		var demo: Weapon = preload("res://scenes/weapons/weapon.tscn").instantiate()
		demo.definition = load("res://data/weapons/%s.tres" % paths[index])
		demo.position = Vector2(210 + index * 260, 330)
		fixture.add_child(demo)
		demo.initialize(90000 + index, aim)
		var mesh_trail: Node2D = TRAIL_SCRIPT.new()
		demo.add_child(mesh_trail)
		mesh_trail.bind(demo)
		mesh_trail.set_process(false)
		demo.start_combo()
		var step: AttackStepDefinition = demo.definition.combo_steps[0]
		demo.advance(step.windup_seconds + step.active_seconds * 0.75)
		mesh_trail.refresh_visual()
		var label := Label.new()
		label.position = Vector2(125 + index * 260, 200)
		label.text = demo.definition.display_name
		label.add_theme_font_size_override("font_size", 19)
		fixture.add_child(label)
		var burst: Node2D = BURST_SCRIPT.new()
		burst.configure(Vector2(260 + index * 260, 465), colors[index], elements[index])
		fixture.add_child(burst)
	await _step(12)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://verification")
	var error: Error = image.save_png("user://verification/vfx_preview.png")
	_check(error == OK and image.get_width() > 0, "Compatibility GPU renders all four ribbon shaders and particle sparks")
	print("VFX PREVIEW: %s" % ProjectSettings.globalize_path("user://verification/vfx_preview.png"))
	await _step(22)


func _test_trails() -> void:
	var paths: Array[String] = ["demon_greatsword", "gale_dual_daggers", "storm_arcane_staff", "blood_spiked_whip"]
	var styles: Array[StringName] = [&"greatsword", &"daggers", &"staff", &"whip"]
	for index: int in paths.size():
		weapon.equip(load("res://data/weapons/%s.tres" % paths[index]))
		weapon.start_combo()
		trail.refresh_visual()
		var step: AttackStepDefinition = weapon.definition.combo_steps[0]
		_check(trail.style_id == styles[index], "Archetype %s selects its own luminous ribbon" % paths[index])
		_check(trail.ribbon.visible and not weapon.hitbox.active, "Wind-up telegraph does not open the gameplay hitbox")
		_check(trail.vertex_count == 66 and trail.ribbon.mesh.get_surface_count() == 1, "Ribbon uses one bounded triangle mesh")
		weapon.advance(step.windup_seconds + step.active_seconds * 0.45)
		trail.refresh_visual()
		_check(weapon.phase == Weapon.Phase.ACTIVE and trail.ribbon.visible, "Trail follows the real active weapon window")
		var before: float = trail.visual_progress
		trail.refresh_visual()
		_check(is_equal_approx(trail.visual_progress, before), "Unadvanced hit-stop clock freezes the shader and mesh progress")
		var attack_id: int = weapon.snapshot.attack_id
		var direction: Vector2 = weapon.snapshot.attack_direction
		aim._cursor_viewport_position = Vector2(-300, 100)
		aim.sample_cursor()
		trail.refresh_visual()
		_check(trail.rendered_attack_id == attack_id and Vector2.from_angle(trail.global_rotation).is_equal_approx(direction), "Cursor movement cannot retarget an already committed VFX swing")
		weapon.advance(step.active_seconds * 0.55 + step.recovery_seconds * 0.25)
		trail.refresh_visual()
		_check(weapon.phase == Weapon.Phase.RECOVERY and trail.ribbon.visible and not weapon.hitbox.active, "Recovery fades the trail after hitbox deactivation")
		weapon.cancel_combo()
		trail.refresh_visual()
		_check(not trail.ribbon.visible and trail._snapshot == null, "Cancel and weapon swap release the attack snapshot immediately")
		aim._cursor_viewport_position = Vector2(300, 0)
	weapon.equip(load("res://data/weapons/training_sword.tres"))
	weapon.start_combo()
	trail.refresh_visual()
	_check(trail.ribbon.visible and trail.vertex_count == 66, "Legacy rectangular weapons keep a cosmetic fallback without changing authored reach")
	weapon.cancel_combo()
	trail.bind(null)
	weapon.start_combo()
	_check(trail._snapshot == null and not trail.ribbon.visible, "Unbinding disconnects the previous owner and releases its committed snapshot")
	trail.bind(weapon)
	trail.refresh_visual()
	_check(trail.rendered_attack_id == weapon.snapshot.attack_id, "Binding to an already running swing restores its current visual without a new attack")
	weapon.cancel_combo()


func _test_impacts() -> void:
	var offset_pool := Node2D.new()
	offset_pool.position = Vector2(150, 75)
	fixture.add_child(offset_pool)
	var placed: Node2D = BURST_SCRIPT.new()
	placed.configure(Vector2(320, 180), Color.WHITE, &"fire")
	offset_pool.add_child(placed)
	_check(placed.global_position.is_equal_approx(Vector2(320, 180)), "Configuring before attachment preserves world impact location under a transformed parent")
	offset_pool.queue_free()
	await _step(2)
	var elements: Array[StringName] = [&"physical", &"fire", &"ice", &"poison", &"lightning"]
	var live: Array[Node2D] = []
	for element: StringName in elements:
		var burst: Node2D = BURST_SCRIPT.new()
		fixture.add_child(burst)
		burst.configure(Vector2(320, 180), Color(0.5, 0.8, 1.0), element, Vector2.RIGHT)
		burst.set_process(false)
		live.append(burst)
		_check(burst.particles.one_shot and burst.particles.amount <= 16 and burst.duration <= 0.5, "%s impact has a bounded one-shot particle/lifetime budget" % element)
		_check(burst.flash.texture != null and burst.flash.energy > 0.0, "%s impact has a radial illumination flash" % element)
		burst._process(0.2)
		_check(burst.flash.energy < 1.4 and burst.remaining > 0.0, "%s flash fades during its finite lifetime" % element)
	_check(live[0].particles.process_material != live[1].particles.process_material, "Separate elemental impacts own separate particle state")
	_check(live[0].particles.texture == live[1].particles.texture and live[0].flash.texture == live[1].flash.texture, "Impact bursts share cached PNG textures without regenerating radial images")
	for burst: Node2D in live:
		burst._process(0.5)
	await _step(3)
	var all_freed: bool = true
	for burst: Node2D in live:
		all_freed = all_freed and not is_instance_valid(burst)
	_check(all_freed, "Every elemental burst releases particles and light without waiting for GPU finished")
	live.clear()


func _test_cleanup() -> void:
	await _burst_batch(30)
	var objects_before: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_before: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	for index: int in 3:
		await _burst_batch(30)
		if index == 0:
			# The yielding stress loop owns one coroutine-state object itself.
			# Compare subsequent bursts with this same control-flow baseline.
			objects_before = int(Performance.get_monitor(Performance.OBJECT_COUNT))
			resources_before = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var objects_after: int = int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var resources_after: int = int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	print("VFX STRESS: objects %d -> %d; resources %d -> %d" % [objects_before, objects_after, resources_before, resources_after])
	_check(objects_after == objects_before and resources_after == resources_before, "Repeated impact teardown returns object and Resource counts to warmed baseline")
	var trail_id: int = trail.get_instance_id()
	trail.queue_free()
	await _step(2)
	weapon.start_combo()
	weapon.cancel_combo()
	_check(not is_instance_id_valid(trail_id), "Removing the presentation child disconnects signals while the weapon keeps working")


func _burst_batch(count: int) -> void:
	for index: int in count:
		var burst: Node2D = BURST_SCRIPT.new()
		fixture.add_child(burst)
		burst.configure(Vector2.ZERO, Color(1.0, 0.4, 0.1), &"fire")
		burst.set_process(false)
		burst._process(0.5)
	await _step(3)


func _step(frames: int) -> void:
	for frame: int in frames:
		await process_frame


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
	print("%s: %s" % ["PASS" if condition else "FAIL", label])
