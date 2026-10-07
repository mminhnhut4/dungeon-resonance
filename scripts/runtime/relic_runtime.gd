class_name RelicRuntime
extends Node
## Three finite passive slots. Runtime modifiers never alter shared definitions.

signal changed
var player: Player
var executor: SpellExecutor
var equipped: Array[RelicData] = []
var owned: Array[RelicData] = []
var dodge_roots: Dictionary[int, bool] = {}
var dodge_count: int = 0
const CATALOG: Array[RelicData] = [
	preload("res://data/relics/soul_bloodstone.tres"),
	preload("res://data/relics/gale_feather.tres"),
	preload("res://data/relics/cinnabar_seal.tres"),
	preload("res://data/relics/phantom_mirror.tres"),
]


func initialize(actor: Player, effects: SpellExecutor) -> void:
	player = actor
	executor = effects
	player.equipped_weapon.hit_confirmed.connect(_on_melee_hit)
	player.hurtbox.hit_resolved.connect(_on_received)
	player.health.died.connect(clear_equipped)


func acquire(id: StringName) -> bool:
	for relic: RelicData in CATALOG:
		if relic.id == id and not owned.has(relic):
			owned.append(relic)
			if equipped.size() < 3:
				equipped.append(relic)
			sync()
			changed.emit()
			return true
	return false


func equip(id: StringName, slot: int) -> bool:
	if slot < 0 or slot >= 3:
		return false
	for relic: RelicData in owned:
		if relic.id == id and not equipped.has(relic):
			if slot < equipped.size():
				equipped[slot] = relic
			elif slot == equipped.size():
				equipped.append(relic)
			else:
				return false
			sync()
			changed.emit()
			return true
	return false


func has_effect(effect_id: StringName) -> bool:
	return get_effect(effect_id) != null


func get_effect(effect_id: StringName) -> RelicData:
	for relic: RelicData in equipped:
		if relic.effect_id == effect_id:
			return relic
	return null


func sync() -> void:
	if not is_instance_valid(player):
		return
	var feather: RelicData = get_effect(&"extra_dash")
	var seal: RelicData = get_effect(&"resonance_power")
	(player.motor as BuildPlayerMotor).extra_air_dashes = maxi(0, roundi(feather.magnitude)) if feather != null else 0
	player.resonance_controller.relic_damage_multiplier = 1.0 + seal.magnitude if seal != null else 1.0
	player.resonance_controller.relic_cooldown_multiplier = seal.cooldown_multiplier if seal != null else 1.0


func clear_equipped() -> void:
	equipped.clear()
	dodge_roots.clear()
	sync()
	changed.emit()


func _on_melee_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.killed and event.melee_hit and has_effect(&"melee_heal"):
		player.health.heal(get_effect(&"melee_heal").magnitude)


func _on_received(event: DamageEvent, result: DamageResult) -> void:
	if not has_effect(&"perfect_dodge") or not result.blocked or event.source_team_id == 1 or event.source_kind == DamageEvent.SourceKind.DOT:
		return
	if player.health.current_health <= 0.0 or not player.motor.is_invulnerable():
		return
	var mirror: RelicData = get_effect(&"perfect_dodge")
	if player.motor.dash_duration - player.motor.dash_remaining > mirror.trigger_window:
		return
	if dodge_roots.has(event.root_event_id):
		return
	if get_tree().get_nodes_in_group(&"spell_entities").size() >= executor.maximum_spell_entities:
		return
	if dodge_roots.size() >= 64:
		dodge_roots.erase(dodge_roots.keys()[0])
	dodge_roots[event.root_event_id] = true
	dodge_count += 1
	var echo := PhantomEcho.new()
	echo.player_id = player.get_instance_id()
	echo.executor = executor
	echo.damage = mirror.magnitude
	echo.delay = mirror.effect_delay
	echo.radius = mirror.effect_radius
	echo.position = player.global_position + Vector2(0, -18)
	executor.add_child(echo)
