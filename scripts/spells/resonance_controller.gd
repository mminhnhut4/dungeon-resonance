class_name ResonanceController
extends Node
## Active catalyst, exact recipes, immutable cast commit and persistent cooldowns.

signal resonance_prepared(definition: ResonanceDefinition)
signal resonance_triggered(attack_id: int)

@export var catalyst_a: Catalyst
@export var catalyst_b: Catalyst
var loadout_state: LoadoutRuntime
var resolver: ResonanceResolver
@export var casting_enabled: bool = true
@export var recipes: Array[ResonanceDefinition] = [
	preload("res://data/resonances/basic.tres"),
	preload("res://data/resonances/fire_bolt.tres"),
	preload("res://data/resonances/wind_bolt.tres"),
	preload("res://data/resonances/lightning_bolt.tres"),
	preload("res://data/resonances/firestorm.tres"),
	preload("res://data/resonances/overload.tres"),
	preload("res://data/resonances/charged_slash.tres"),
	preload("res://data/resonances/astral_firestorm.tres"),
	preload("res://data/resonances/eclipse_blades.tres"),
	preload("res://data/resonances/ice_bolt.tres"),
	preload("res://data/resonances/poison_bolt.tres"),
	preload("res://data/resonances/thermal_shock.tres"),
	preload("res://data/resonances/superconduct.tres"),
	preload("res://data/resonances/blizzard.tres"),
	preload("res://data/resonances/combustion.tres"),
	preload("res://data/resonances/frost_venom.tres"),
	preload("res://data/resonances/miasma_cloud.tres"),
	preload("res://data/resonances/neurotoxin.tres"),
]
var actor: Player
var executor: SpellExecutor
var combat_feedback: CombatFeedback
var cast_count: int = 0
var cooldown_multiplier: float = 1.0
var quality_damage_multiplier: float = 1.0
var bonus_proc_chance: float = 0.0
var element_damage_multiplier: float = 1.0
var quality_rng := RandomNumberGenerator.new()
var relic_damage_multiplier: float = 1.0
var relic_cooldown_multiplier: float = 1.0


func _ready() -> void:
	resolver = ResonanceResolver.new()
	loadout_state = LoadoutRuntime.new()
	quality_rng.randomize()
	catalyst_a.loadout_changed.connect(_resolve_loadout)
	_resolve_loadout()


func initialize(owner_actor: Player, effect_executor: SpellExecutor, feedback: CombatFeedback) -> void:
	actor = owner_actor
	executor = effect_executor
	combat_feedback = feedback


func _resolve_loadout() -> void:
	catalyst_a.runtime_state.resolved_resonance = resolver.resolve(catalyst_a.runtime_state.installed_rune_ids, catalyst_a.runtime_state.opened_slots, recipes)
	resonance_prepared.emit(catalyst_a.runtime_state.resolved_resonance)


func _physics_process(delta: float) -> void:
	if is_instance_valid(combat_feedback) and combat_feedback.is_frozen():
		return
	for id: StringName in loadout_state.cooldowns_by_recipe_id:
		loadout_state.cooldowns_by_recipe_id[id] = maxf(0.0, loadout_state.cooldowns_by_recipe_id[id] - delta)


func get_recipe() -> ResonanceDefinition:
	return catalyst_a.runtime_state.resolved_resonance


func cooldown_remaining() -> float:
	var recipe: ResonanceDefinition = get_recipe()
	return loadout_state.cooldowns_by_recipe_id.get(recipe.id, 0.0) if recipe != null else 0.0


func can_cast() -> bool:
	return casting_enabled and is_instance_valid(executor) and get_recipe() != null and cooldown_remaining() <= 0.000001 and (actor == null or actor.energy.can_spend(30.0))


func commit_cast() -> SpellSnapshot:
	if not can_cast():
		return null
	if not actor.energy.spend(30.0):
		return null
	var recipe: ResonanceDefinition = get_recipe()
	var spell := SpellSnapshot.new()
	actor.aim.sample_cursor()
	spell.source_id = actor.get_instance_id()
	spell.root_id = CombatIds.next_id()
	spell.origin = actor.aim.global_position
	spell.target_position = actor.aim.target_position
	spell.direction = actor.aim.direction
	spell.recipe_id = recipe.id
	spell.behavior_id = recipe.behavior_id
	spell.damage = recipe.base_damage
	spell.damage *= quality_damage_multiplier
	spell.speed = recipe.projectile_speed
	spell.windup = recipe.windup_seconds
	spell.recovery = recipe.recovery_seconds
	spell.effect_radius = recipe.effect_radius
	spell.effect_duration = recipe.effect_duration
	spell.pull_speed = recipe.pull_speed
	spell.explosion_damage = recipe.explosion_damage
	spell.explosion_damage *= quality_damage_multiplier
	spell.stun_seconds = recipe.stun_seconds
	spell.slow_multiplier = recipe.slow_multiplier
	spell.slow_seconds = recipe.slow_seconds
	spell.freeze_points = recipe.freeze_points
	spell.poison_stacks = recipe.poison_stacks
	spell.armor_break_seconds = recipe.armor_break_seconds
	spell.thermal_shock = recipe.thermal_shock
	spell.consume_poison = recipe.consume_poison
	spell.interrupt_seconds = recipe.interrupt_seconds
	for rune: RuneData in catalyst_a.runtime_state.installed_runes:
		spell.burn_damage = maxf(spell.burn_damage, rune.burn_damage)
		if rune.burn_damage > 0.0:
			spell.burn_duration = rune.burn_duration
			spell.burn_interval = rune.burn_interval
		spell.speed *= rune.projectile_speed_multiplier
		spell.knockback_multiplier *= rune.knockback_multiplier
		spell.maximum_targets = maxi(spell.maximum_targets, rune.maximum_pierced_targets)
		spell.chain_targets = maxi(spell.chain_targets, rune.chain_targets)
		spell.chain_radius = rune.chain_radius
		spell.slow_multiplier = minf(spell.slow_multiplier, rune.slow_multiplier)
		spell.slow_seconds = maxf(spell.slow_seconds, rune.slow_seconds)
		spell.freeze_points = maxf(spell.freeze_points, rune.freeze_points)
		spell.poison_stacks = maxi(spell.poison_stacks, rune.poison_stacks)
		spell.poison_percent = rune.poison_percent
		spell.poison_seconds = rune.poison_seconds
	if catalyst_a.runtime_state.installed_rune_ids.has(&"fire") or catalyst_a.runtime_state.installed_rune_ids.has(&"lightning"):
		spell.damage *= element_damage_multiplier
		spell.explosion_damage *= element_damage_multiplier
		spell.burn_damage *= element_damage_multiplier
	if quality_rng.randf() < bonus_proc_chance:
		spell.empowered = true
		spell.explosion_damage *= 1.5
		spell.damage *= 1.25
	if recipe.behavior_id == &"firestorm":
		spell.color = Color(1.0, 0.4, 0.1)
	elif recipe.behavior_id == &"overload":
		spell.color = Color(1.0, 0.35, 0.85)
	elif recipe.behavior_id == &"charged_slash":
		spell.color = Color(0.6, 0.75, 1.0)
	elif not catalyst_a.runtime_state.installed_runes.is_empty():
		spell.color = catalyst_a.runtime_state.installed_runes[0].display_color
	var is_resonance: bool = recipe.recipe_rune_ids.size() >= 2
	if is_resonance:
		spell.damage *= relic_damage_multiplier
		spell.explosion_damage *= relic_damage_multiplier
	loadout_state.cooldowns_by_recipe_id[recipe.id] = recipe.cooldown_seconds * cooldown_multiplier * (relic_cooldown_multiplier if is_resonance else 1.0)
	cast_count += 1
	resonance_triggered.emit(spell.root_id)
	return spell


func reset_runtime() -> void:
	loadout_state.cooldowns_by_recipe_id.clear()
