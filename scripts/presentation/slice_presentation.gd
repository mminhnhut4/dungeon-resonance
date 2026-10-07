class_name SlicePresentation
extends Node2D
## Cosmetic event adapter. Damage, FSM clocks and weapon snapshots remain upstream.

const MAX_IMPACTS: int = 24
const MAX_IMPACT_LIGHTS: int = 8
const MAX_PROJECTILE_LIGHTS: int = 12
const MAX_PROJECTILE_TRAILS: int = 24
const MAX_FOOTSTEP_DUST: int = 8
const ACTOR_LIGHT_MARGIN: float = 64.0
const FOOTSTEP_DISTANCE: float = 22.0
const FOOTSTEP_INTERVAL: float = 0.16
const SLASH_SCENE: PackedScene = preload("res://scenes/vfx/slash_arc.tscn")
const LIGHT: Texture2D = preload("res://assets/presentation/light_radial.png")
const CAST_CUE = preload("res://scripts/presentation/rune_cast_cue.gd")
var cast_cue: Node2D
var atmosphere: DungeonAtmosphere
var debug_overlay: DungeonDebugOverlay
var foyer_art: FoyerArt
var trail: WeaponTrail
var art_hud: ArtHUD
var world: Node2D
var actor: Player
var feedback: CombatFeedback
var executor: SpellExecutor
var audio: Node
var impacts: Node2D
var foot_dust: Node2D
var movement_vfx: MovementVFX
var foot_dust_count: int = 0
var _was_grounded: bool = false
var _last_vertical_speed: float = 0.0
var _step_distance: float = 0.0
var _step_cooldown: float = 0.0
var _step_last_position: Vector2 = Vector2.ZERO
var _step_tracking: bool = false
var bound_actors: Dictionary[int, bool] = {}
var light_owners: Dictionary[int, bool] = {}
var projectile_vfx_owners: Dictionary[int, bool] = {}
var campfire_owners: Dictionary[int, bool] = {}
var scan_remaining: float = 0.0
var impact_count: int = 0
var sfx_count: int = 0
var _swing_id: int = 0
var _swing_pending: bool = false
var _wall_probe_pending: bool = false
var _weapon_self_modulate: Color = Color.WHITE

func initialize(owner_world: Node2D, player: Player, combat_feedback: CombatFeedback, spell_executor: SpellExecutor) -> void:
	process_physics_priority = 20
	world = owner_world
	actor = player
	feedback = combat_feedback
	executor = spell_executor
	audio = get_node("/root/AudioManager")
	var player_camera: Camera2D = actor.get_node("Camera2D") as Camera2D
	player_camera.enabled = true
	player_camera.make_current()
	feedback.camera = player_camera
	feedback.enable_global_hitstop(DisplayServer.get_name() != "headless")
	debug_overlay = DungeonDebugOverlay.new()
	add_child(debug_overlay)
	debug_overlay.initialize(world)
	atmosphere = DungeonAtmosphere.new()
	add_child(atmosphere)
	atmosphere.initialize(player)
	foyer_art = FoyerArt.new()
	foyer_art.name = "FoyerAtlasSkin"
	add_child(foyer_art)
	impacts = Node2D.new()
	impacts.name = "FiniteImpactPool"
	add_child(impacts)
	foot_dust = Node2D.new()
	foot_dust.name = "FiniteFootDustPool"
	add_child(foot_dust)
	movement_vfx = MovementVFX.new()
	movement_vfx.name = "MovementVFX"
	add_child(movement_vfx)
	movement_vfx.initialize(actor, feedback)
	cast_cue=CAST_CUE.new(); cast_cue.name="CommittedRuneSeal"; add_child(cast_cue); cast_cue.bind(actor)
	trail = SLASH_SCENE.instantiate() as WeaponTrail
	trail.name = "WeaponSlashTrail"
	actor.equipped_weapon.add_child(trail)
	trail.bind(actor.equipped_weapon, feedback)
	_weapon_self_modulate = actor.equipped_weapon.self_modulate
	actor.equipped_weapon.self_modulate.a = 0.0
	actor.equipped_weapon.attack_committed.connect(_on_attack)
	actor.action_state_machine.state_changed.connect(_on_action)
	actor.locomotion_state_machine.state_changed.connect(_on_locomotion)
	executor.presentation_cast.connect(_on_spell)
	executor.presentation_burst.connect(_on_explosion)
	executor.presentation_contact.connect(_on_spell_contact)
	art_hud = ArtHUD.new()
	art_hud.name = "ArtHUD"
	add_child(art_hud)
	art_hud.bind(world, actor, null, world.get("boss_hp") as ProgressBar, world.get("boss_name") as Label)
	_bind_actor(actor)
	get_tree().node_added.connect(_on_node_added)
	_scan()

func rebuild(boss_room: bool = false) -> void:
	audio.stop_owner(self)
	_release_campfire_audio(true)
	movement_vfx.clear()
	for burst: Node in impacts.get_children():
		impacts.remove_child(burst)
		burst.queue_free()
	for puff: Node in foot_dust.get_children():
		foot_dust.remove_child(puff)
		puff.queue_free()
	_was_grounded = false
	_last_vertical_speed = 0.0
	_reset_footsteps()
	atmosphere.rebuild(boss_room)
	if boss_room:
		foyer_art.clear()
	else:
		foyer_art.rebuild(world)
	_scan.call_deferred()

func _on_node_added(node: Node) -> void:
	# Actor fields are initialized by _ready, which follows node_added.
	if not _is_active():
		return
	# A queued Node argument can be freed before Godot dispatches the call.
	# Resolve its ID only after checking this room's lifetime.
	if node is Player or node is SlimeEnemy or node is BossGolem or node is TrainingDummy or node is SpellProjectile or node is TreasureChest or node is LootPickup or node is Campfire:
		_bind_added.call_deferred(node.get_instance_id())

func _is_active() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(world) and world.is_inside_tree() and not world.is_queued_for_deletion() and world.is_ancestor_of(self)

func _owns_target(target: Node) -> bool:
	return _is_active() and is_instance_valid(target) and target.is_inside_tree() and not target.is_queued_for_deletion() and world.is_ancestor_of(target)

func _bind_added(target_id: int) -> void:
	if not _is_active() or not is_instance_id_valid(target_id):
		return
	var node: Node = instance_from_id(target_id) as Node
	if not _owns_target(node):
		return
	if node is Player or node is SlimeEnemy or node is BossGolem or node is TrainingDummy:
		_bind_actor(node)
	elif node is SpellProjectile:
		_bind_projectile(node)
	elif node is TreasureChest:
		_bind_prop(node)
	elif node is LootPickup:
		_bind_loot(node)
	elif node is Campfire:
		_bind_campfire(node)

func _bind_loot(target: Node) -> void:
	if not _owns_target(target) or target.has_node("LootVisualSkin"):
		return
	var skin := LootVisualSkin.new()
	skin.name = "LootVisualSkin"
	target.add_child(skin)
	skin.bind(target as LootPickup)

func _bind_campfire(target: Node) -> void:
	if not _owns_target(target):
		return
	var skin: CampfireVisualSkin = target.get_node_or_null("CampfireVisualSkin") as CampfireVisualSkin
	if skin == null:
		skin = CampfireVisualSkin.new()
		skin.name = "CampfireVisualSkin"
		target.add_child(skin)
		skin.bind(target as Campfire, actor)
	var id: int = skin.get_instance_id()
	if not campfire_owners.has(id):
		campfire_owners[id] = true
		skin.tree_exiting.connect(_campfire_left.bind(id), CONNECT_ONE_SHOT)

func _campfire_left(id: int) -> void:
	campfire_owners.erase(id)

func _release_campfire_audio(only_started: bool = false) -> void:
	for id: int in campfire_owners.keys():
		var skin: CampfireVisualSkin = instance_from_id(id) as CampfireVisualSkin if is_instance_id_valid(id) else null
		# Initial scene rebuild precedes the adapter's first process frame. A
		# silent/new fire has no old cue to revoke and still gets its first play.
		if skin != null and (not only_started or skin.sound_deadline > 0):
			skin.release_ambience()

func _bind_actor(target: Node) -> void:
	if not _owns_target(target):
		return
	var id: int = target.get_instance_id()
	if bound_actors.has(id):
		return
	var hurt: Hurtbox = target.get("hurtbox") as Hurtbox
	if hurt == null:
		return
	bound_actors[id] = true
	hurt.hit_resolved.connect(_on_hit.bind(hurt))
	target.tree_exiting.connect(_actor_left.bind(id), CONNECT_ONE_SHOT)
	if target is SlimeEnemy:
		var slime := target as SlimeEnemy
		slime.state_machine.state_changed.connect(_on_enemy_state.bind(slime))
		var slime_skin := SlimeSpriteSkin.new()
		slime_skin.name = "SlimeSpriteSkin"
		target.add_child(slime_skin)
		slime_skin.bind(slime)
	elif target is BossGolem:
		(target as BossGolem).fsm.state_changed.connect(_on_boss_state.bind(target as BossGolem))
		var skin := BossGolemSkin.new()
		skin.name = "GolemStoneSkin"
		target.add_child(skin)
		skin.bind(target as BossGolem)
	elif target is TrainingDummy:
		_bind_prop(target)
	if not target.has_node("ElementAfflictionVFX"):
		var affliction := ElementAfflictionVFX.new()
		affliction.name = "ElementAfflictionVFX"
		target.add_child(affliction)
		affliction.initialize(target as Node2D, hurt, feedback)

func _bind_prop(target: Node) -> void:
	if not _owns_target(target) or target.has_node("PropSpriteSkin"):
		return
	var skin := PropSpriteSkin.new()
	skin.name = "PropSpriteSkin"
	target.add_child(skin)
	skin.bind(target as Node2D)

func _actor_left(id: int) -> void:
	bound_actors.erase(id)

func _process(delta: float) -> void:
	if _swing_pending:
		var weapon: Weapon = actor.equipped_weapon
		if weapon.snapshot == null or weapon.snapshot.attack_id != _swing_id or weapon.phase == Weapon.Phase.NONE:
			_swing_pending = false
		elif weapon.phase == Weapon.Phase.ACTIVE:
			_sound(&"sword_swing", actor.aim.global_position)
			_swing_pending = false
	scan_remaining -= delta
	if scan_remaining <= 0:
		scan_remaining = 0.08
		_scan()
	_refresh_spell_lighting()

func _scan() -> void:
	if not _is_active():
		return
	for enemy: Node in get_tree().get_nodes_in_group(&"enemies"):
		_bind_actor(enemy)
	for node: Node in world.find_children("*", "CharacterBody2D", true, false):
		if node is TrainingDummy:
			_bind_actor(node)
	for chest: Node in get_tree().get_nodes_in_group(&"chests"):
		_bind_prop(chest)
	for pickup: Node in get_tree().get_nodes_in_group(&"loot"):
		_bind_loot(pickup)
	for camp: Node in get_tree().get_nodes_in_group(&"campfires"):
		_bind_campfire(camp)
	# The cap includes effects from all casts in this room. Lights die with their effect.
	for effect: Node in get_tree().get_nodes_in_group(&"spell_entities"):
		if not _owns_target(effect) or not is_instance_valid(executor) or executor.is_queued_for_deletion() or not executor.is_ancestor_of(effect) or not effect is Node2D:
			continue
		if effect is SpellProjectile:
			_bind_projectile(effect)
		var id: int = effect.get_instance_id()
		if light_owners.has(id) or light_owners.size() >= MAX_PROJECTILE_LIGHTS:
			continue
		var color := Color(0.48, 0.6, 1)
		if effect is SpellProjectile:
			color = (effect as SpellProjectile).context.snapshot.color
		elif effect is FirestormEffect:
			color = Color(1, 0.36, 0.08)
		elif effect is SpellVisual:
			color = (effect as SpellVisual).color
		var light := PointLight2D.new()
		light.name = "ResonanceGlow"
		light.texture = LIGHT
		light.texture_scale = 2.3 if effect is SpellProjectile else 3.5
		light.color = color
		light.energy = 1.7
		if effect is SpellProjectile and (effect as SpellProjectile).context.snapshot.weapon_family_visual:
			var grade: int = clampi((effect as SpellProjectile).context.snapshot.cosmetic_quality, 0, 5)
			light.energy = 0.5 + grade * 0.3
			light.texture_scale = 1.4 + grade * 0.18
		light.shadow_enabled = false
		effect.add_child(light)
		var emissive := CanvasItemMaterial.new()
		emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		(effect as CanvasItem).material = emissive
		light_owners[id] = true
		effect.tree_exiting.connect(_light_left.bind(id), CONNECT_ONE_SHOT)
	_refresh_spell_lighting()

func _protected_actor_centers() -> Array[Vector2]:
	var centers: Array[Vector2] = []
	for id: int in bound_actors.keys():
		if not is_instance_id_valid(id):
			continue
		var target: Node2D = instance_from_id(id) as Node2D
		if not (target is Player or target is BossGolem) or not _owns_target(target):
			continue
		var hurt: Hurtbox = target.get("hurtbox") as Hurtbox
		centers.append(hurt.global_position if is_instance_valid(hurt) else target.global_position)
	return centers

func _light_reaches_actor(light: PointLight2D, centers: Array[Vector2]) -> bool:
	if not is_instance_valid(light) or light.texture == null:
		return false
	var support: float = float(maxi(light.texture.get_width(), light.texture.get_height())) * light.texture_scale * 0.5
	var x: Vector2 = light.global_transform.x
	var y: Vector2 = light.global_transform.y
	var a: float = x.length_squared()
	var b: float = y.length_squared()
	var dot: float = x.dot(y)
	var basis_scale: float = sqrt(maxf(0.0, 0.5 * (a + b + sqrt((a - b) * (a - b) + 4.0 * dot * dot))))
	var radius: float = support * basis_scale + ACTOR_LIGHT_MARGIN
	for center: Vector2 in centers:
		if light.global_position.distance_squared_to(center) <= radius * radius:
			return true
	return false

func _refresh_spell_lighting() -> void:
	if not _is_active():
		return
	var centers: Array[Vector2] = _protected_actor_centers()
	for id: int in light_owners.keys():
		if not is_instance_id_valid(id):
			continue
		var effect: Node = instance_from_id(id) as Node
		if not _owns_target(effect):
			continue
		var glow: PointLight2D = effect.get_node_or_null("ResonanceGlow") as PointLight2D
		if is_instance_valid(glow):
			glow.enabled = not _light_reaches_actor(glow, centers)
	for burst: ImpactBurst in impacts.get_children():
		if burst.flash.enabled and _light_reaches_actor(burst.flash, centers):
			burst.flash.enabled = false

func _light_left(id: int) -> void:
	light_owners.erase(id)

func _bind_projectile(projectile: Node) -> void:
	if not _owns_target(projectile) or not is_instance_valid(executor) or executor.is_queued_for_deletion() or not executor.is_ancestor_of(projectile):
		return
	var id: int = projectile.get_instance_id()
	if projectile_vfx_owners.has(id) or projectile_vfx_owners.size() >= MAX_PROJECTILE_TRAILS:
		return
	var visual := SpellProjectileVFX.new()
	visual.name = "SpellTrailVFX"
	projectile.add_child(visual)
	visual.bind(projectile as SpellProjectile, feedback)
	projectile_vfx_owners[id] = true
	projectile.tree_exiting.connect(_projectile_left.bind(id), CONNECT_ONE_SHOT)

func _projectile_left(id: int) -> void:
	projectile_vfx_owners.erase(id)

func _physics_process(delta: float) -> void:
	if is_instance_valid(actor) and not feedback.is_frozen():
		var grounded: bool = actor.motor.is_grounded()
		if grounded and not _was_grounded and _last_vertical_speed > 100.0:
			spawn_foot_dust(_player_foot())
			_sound(&"landing", _player_foot())
		_was_grounded = grounded
		_last_vertical_speed = actor.velocity.y
		_update_footsteps(delta, grounded)
	if not _wall_probe_pending or feedback.is_frozen():
		return
	var weapon: Weapon = actor.equipped_weapon
	if weapon.snapshot == null or weapon.snapshot.attack_id != _swing_id or weapon.phase == Weapon.Phase.NONE:
		_wall_probe_pending = false
		return
	if weapon.phase != Weapon.Phase.ACTIVE:
		return
	_wall_probe_pending = false
	if weapon.snapshot.weapon_definition.attack_kind != &"melee" or weapon.hitbox._query_shape == null:
		return
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = weapon.hitbox._query_shape
	query.transform = weapon.hitbox.global_transform
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var contact: Dictionary = world.get_world_2d().direct_space_state.get_rest_info(query)
	if not contact.is_empty():
		spawn_impact(contact.point, Color(1, 0.67, 0.2), &"physical", weapon.snapshot.attack_direction)

func _reset_footsteps() -> void:
	_step_distance = 0.0
	_step_cooldown = 0.0
	_step_tracking = false
	_step_last_position = actor.global_position if is_instance_valid(actor) else Vector2.ZERO

func _update_footsteps(delta: float, grounded: bool) -> void:
	# Observe actual travel, not held input or velocity against a wall. A floor
	# landing/dash has its own single puff and never shares this cadence.
	var running: bool = grounded and actor.controls_enabled and actor.health.current_health > 0.0 and not actor.motor.is_dashing and actor.locomotion_state_machine.get_state_id() == &"run" and absf(actor.velocity.x) > 8.0
	if not running:
		_reset_footsteps()
		return
	if not _step_tracking:
		_step_last_position = actor.global_position
		_step_tracking = true
		return
	var elapsed: float = maxf(delta, 0.0)
	var travelled: float = absf(actor.global_position.x - _step_last_position.x)
	_step_last_position = actor.global_position
	# Room relocation/respawn is not a step. Keep the test based on frame travel
	# permissive enough for gear speed modifiers without emitting after a warp.
	var maximum_travel: float = maxf(24.0, absf(actor.velocity.x) * elapsed * 2.0 + 1.0)
	if travelled > maximum_travel:
		_reset_footsteps()
		return
	_step_cooldown = maxf(0.0, _step_cooldown - elapsed)
	_step_distance += travelled
	if _step_distance >= FOOTSTEP_DISTANCE and _step_cooldown <= 0.0:
		spawn_foot_dust(_player_foot(), actor.velocity)
		_step_distance = 0.0
		_step_cooldown = FOOTSTEP_INTERVAL

func _on_attack(snapshot: AttackSnapshot) -> void:
	_swing_id = snapshot.attack_id
	_swing_pending = true
	_wall_probe_pending = true

func _on_action(_previous: StringName, next: StringName) -> void:
	if next == &"dash":
		_reset_footsteps()
		_sound(&"dash", actor.global_position)
		spawn_foot_dust(_player_foot(), actor.velocity)

func _on_locomotion(previous: StringName, next: StringName) -> void:
	if next == &"jump":
		_sound(&"jump", _player_foot())
		if previous in [&"idle", &"run"] and actor.controls_enabled and actor.health.current_health > 0.0 and actor.motor.is_grounded() and actor.velocity.y < 0.0:
			spawn_foot_dust(_player_foot(), actor.velocity)
		_reset_footsteps()

func _on_boss_state(previous: StringName, next: StringName, boss: BossGolem) -> void:
	if previous == &"stomp" and next == &"recover":
		feedback.notify_boss_stomp()
		spawn_foot_dust(boss.global_position)
		_sound(&"boss_impact", boss.global_position)

func _on_enemy_state(previous: StringName, next: StringName, enemy: SlimeEnemy) -> void:
	if previous == &"patrol" and next == &"chase":
		_sound(&"aggro", enemy.global_position)

func _on_spell(location: Vector2) -> void:
	_sound(&"spell_explosion", location)

func _on_explosion(location: Vector2, color: Color, element: StringName) -> void:
	spawn_impact(location, color, element)
	feedback.notify_spell_explosion()
	_sound(&"spell_explosion", location)

func _on_spell_contact(location: Vector2, color: Color, direction: Vector2) -> void:
	spawn_impact(location, color, &"spell_contact", direction)

func _on_hit(event: DamageEvent, result: DamageResult, hurt: Hurtbox) -> void:
	if result.blocked or result.actual_damage <= 0 or event.source_kind == DamageEvent.SourceKind.DOT:
		return
	var element: StringName = &"physical"
	var color := Color(1, 0.85, 0.6)
	if event.spell_id == &"overload":
		# Match the existing committed magenta cast/burst, rather than the fire-only contact ink.
		element = &"lightning"
		color = Color(1.0, 0.35, 0.85)
	elif event.burn_damage > 0 or event.spell_id in [&"firestorm", &"combustion", &"fire_bolt"]:
		element = &"fire"
		color = Color(1, 0.4, 0.08)
	elif event.freeze_points > 0 or event.slow_seconds > 0:
		element = &"ice"
		color = Color(0.35, 0.85, 1)
	elif event.poison_stacks > 0:
		element = &"poison"
		color = Color(0.55, 1, 0.26)
	elif event.stun_seconds > 0 or event.spell_id in [&"lightning_bolt", &"charged_slash"]:
		element = &"lightning"
		color = Color(0.7, 0.52, 1)
	elif event.spell_id == &"wind_bolt":
		element = &"wind"
		color = event.cosmetic_tint
	if event.melee_hit and not event.cosmetic_element.is_empty():
		element = event.cosmetic_element
		color = event.cosmetic_tint
	# Keep the resolved element at contact: the Fire lance ends in a flame
	# fracture, Ice in shards, Lightning in branches, all on accepted damage.
	var burst: ImpactBurst = spawn_impact(hurt.global_position, color, element, event.attack_direction)
	if event.melee_hit:
		burst.configure_combat(event.cosmetic_quality, event.critical, event.cosmetic_combo_index)
		burst.enable_melee_sparks()
	_sound(&"melee_impact" if event.melee_hit else &"hurt", hurt.global_position)

func _player_foot() -> Vector2:
	var collision: CollisionShape2D = actor.get_node("BodyCollision") as CollisionShape2D
	return collision.to_global(Vector2(0, collision.shape.get_rect().end.y))

func spawn_foot_dust(location: Vector2, travel: Vector2 = Vector2.ZERO) -> FootstepDust:
	while foot_dust.get_child_count() >= MAX_FOOTSTEP_DUST:
		var old: Node = foot_dust.get_child(0)
		foot_dust.remove_child(old)
		old.queue_free()
	var puff := FootstepDust.new()
	puff.configure(location, travel)
	foot_dust.add_child(puff)
	foot_dust_count += 1
	return puff

func spawn_impact(location: Vector2, color: Color, element: StringName, direction: Vector2 = Vector2.UP) -> ImpactBurst:
	while impacts.get_child_count() >= MAX_IMPACTS:
		var old: Node = impacts.get_child(0)
		impacts.remove_child(old)
		old.queue_free()
	var burst := ImpactBurst.new()
	burst.configure(location, color, element, direction)
	var flashes: Array[PointLight2D] = []
	for previous: ImpactBurst in impacts.get_children():
		if previous.flash.enabled:
			flashes.append(previous.flash)
	while flashes.size() >= MAX_IMPACT_LIGHTS:
		flashes.pop_front().enabled = false
	impacts.add_child(burst)
	if _light_reaches_actor(burst.flash, _protected_actor_centers()):
		burst.flash.enabled = false
	impact_count += 1
	return burst

func _sound(cue: StringName, location: Vector2) -> void:
	if audio.play_weighted_event(cue, location, self) != null:
		sfx_count += 1

func _exit_tree() -> void:
	var tree: SceneTree = get_tree()
	if tree.node_added.is_connected(_on_node_added):
		tree.node_added.disconnect(_on_node_added)
	if is_instance_valid(audio):
		audio.stop_owner(self)
	_release_campfire_audio()
	if is_instance_valid(trail):
		trail.bind(null)
		trail.queue_free()
	if is_instance_valid(actor) and is_instance_valid(actor.equipped_weapon):
		actor.equipped_weapon.self_modulate = _weapon_self_modulate
	bound_actors.clear()
	light_owners.clear()
	projectile_vfx_owners.clear()
	campfire_owners.clear()
