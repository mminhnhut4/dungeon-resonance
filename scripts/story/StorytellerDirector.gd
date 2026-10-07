class_name StorytellerDirector
extends Node
## Bounded, seeded incident scheduler. One incident at a time, finite recovery.

signal incident_started(id: StringName)
signal incident_ended(id: StringName)
var player: Player
var inventory: GearInventory
var world: Node2D
var condition: BodyConditionComponent
var feedback: CombatFeedback
var enabled: bool = true
var automatic: bool = true
var style: StringName = &"balanced"
var current_incident: StringName = &""
var incident_remaining: float = 0.0
var recovery_remaining: float = 35.0
var toxic_tick: float = 1.0
var wind_clear_remaining: float = 0.0
var shrine_position := Vector2(240, 640)
var rng := RandomNumberGenerator.new()
var sequence_index: int = 0


func _ready() -> void:
	rng.randomize()
	player.resonance_controller.resonance_triggered.connect(_on_cast)
	player.equipped_weapon.attack_committed.connect(_on_attack)


func threat_points() -> float:
	if not is_instance_valid(player) or inventory == null:
		return 0.0
	var equipment: float = 35.0 + inventory.total_shards() * 5.0
	if inventory.items.has(inventory.equipped_weapon_uid):
		# Common replaces the former Normal tier without making starter rooms easier.
		var quality: int = inventory.items[inventory.equipped_weapon_uid].quality
		equipment += [1, 2, 3, 3, 4, 4][clampi(quality, 0, 5)] * 15.0
	var hp_ratio: float = player.health.current_health / maxf(1.0, player.health.maximum_health)
	# Lower health lowers the scheduled budget; chaos changes randomness, not HP math.
	return clampf(equipment * (0.4 + 0.6 * hp_ratio), 10.0, 250.0)


func trigger(id: StringName = &"") -> bool:
	if not enabled or player.health.current_health <= 0.0 or current_incident != &"":
		return false
	var options: Array[StringName] = [&"toxic", &"swarm", &"smuggler", &"eclipse"]
	if id == &"":
		if style == &"steady":
			id = options[sequence_index % options.size()]
			sequence_index += 1
		else:
			id = &"smuggler" if style == &"balanced" and player.health.current_health < player.health.maximum_health * 0.3 and rng.randf() < 0.6 else options[rng.randi_range(0, options.size() - 1)]
	if not options.has(id):
		return false
	current_incident = id
	incident_remaining = 14.0 if style == &"steady" else 22.0 if style == &"chaotic" else 18.0
	toxic_tick = 1.0
	_apply_incident()
	incident_started.emit(id)
	return true


func _physics_process(delta: float) -> void:
	if not enabled or player.health.current_health <= 0.0 or (is_instance_valid(feedback) and feedback.is_frozen()):
		return
	wind_clear_remaining = maxf(0.0, wind_clear_remaining - delta)
	if current_incident == &"":
		if automatic:
			recovery_remaining -= delta
			if recovery_remaining <= 0.0:
				trigger()
		return
	incident_remaining -= delta
	_apply_incident()
	if current_incident == &"toxic":
		if not is_purified(player.global_position):
			condition.add_stress(delta * 2.5)
		toxic_tick -= delta
		if toxic_tick <= 0.0:
			toxic_tick += 1.0
			for actor: Node2D in _actors():
				if not is_purified(actor.global_position):
					_poison(actor)
	if incident_remaining <= 0.0:
		end_incident()


func _actors() -> Array[Node2D]:
	var actors: Array[Node2D] = [player]
	for actor: Node in get_tree().get_nodes_in_group(&"enemies"):
		if world.is_ancestor_of(actor) and actor.health.current_health > 0.0:
			actors.append(actor as Node2D)
	return actors


func is_purified(position: Vector2) -> bool:
	return position.distance_to(shrine_position) <= 90.0 or (wind_clear_remaining > 0.0 and position.distance_to(player.global_position) <= 160.0)


func _poison(actor: Node2D) -> void:
	var event := DamageEvent.new()
	event.source_id = get_instance_id()
	event.target_id = actor.get_instance_id()
	event.attack_id = CombatIds.next_id()
	event.root_event_id = event.attack_id
	event.hit_window_id = 1
	event.source_kind = DamageEvent.SourceKind.ENVIRONMENT
	event.base_damage = 2.0
	actor.hurtbox.take_damage(event)


func _apply_incident() -> void:
	player.resonance_controller.element_damage_multiplier = 2.0 if current_incident == &"eclipse" else 1.0
	player.equipped_weapon.element_damage_multiplier = player.resonance_controller.element_damage_multiplier
	for actor: Node2D in _actors():
		if actor is SlimeEnemy:
			actor.enraged = current_incident == &"swarm"
			actor.attack_rate_multiplier = 1.4 if actor.enraged else 1.0
			actor.hurtbox.team_id = 0 if actor.enraged else 2
			actor.bite_hitbox.collision_mask = 24 if actor.enraged else 8
			actor.get_node("Eyes").default_color = Color(1.0, 0.08, 0.08) if actor.enraged else Color(0.05, 0.16, 0.1)
			if not actor.enraged:
				actor.player = player
		elif actor is BaseEnemy:
			actor.enraged = current_incident == &"swarm"
			actor.attack_rate_multiplier = 1.4 if actor.enraged else 1.0
			actor.hurtbox.team_id = 0 if actor.enraged else 2
			actor.attack_hitbox.collision_mask = 24 if actor.enraged else 8
			if not actor.enraged:
				actor.player = player
		elif actor is BossGolem:
			actor.enraged = current_incident == &"swarm"
			actor.attack_rate_multiplier = 1.4 if actor.enraged else 1.0
			actor.attack_hitbox.collision_mask = 24 if actor.enraged else 8


func end_incident() -> void:
	var old: StringName = current_incident
	current_incident = &""
	incident_remaining = 0.0
	wind_clear_remaining = 0.0
	recovery_remaining = (50.0 if style == &"steady" else rng.randf_range(12.0, 40.0) if style == &"chaotic" else 35.0) * (1.4 - minf(threat_points(), 100.0) / 200.0)
	_apply_incident()
	if old != &"":
		incident_ended.emit(old)


func _on_cast(_id: int) -> void:
	if player.resonance_controller.catalyst_a.runtime_state.installed_rune_ids.has(&"wind"):
		wind_clear_remaining = 3.0


func _on_attack(_attack: AttackSnapshot) -> void:
	if player.equipped_weapon.installed_rune != null and player.equipped_weapon.installed_rune.id == &"wind":
		wind_clear_remaining = 3.0
