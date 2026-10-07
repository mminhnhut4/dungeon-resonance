extends "res://tests/survival_test_base.gd"


func _initialize() -> void:
	suite = "spell_matrix"
	super._initialize()


func test_system() -> void:
	session.set_enabled(false)
	player.energy.enabled = false
	var controller: ResonanceController = player.resonance_controller
	var expected: Array[float] = [10, 12, 12, 20, 16, 14, 18, 12, 10, 17]
	_check(GearInventory.RUNES.size() == 5, "Matrix exposes five independent rune resources")
	for index: int in 10:
		var id: StringName = ContentSession.PAIR_IDS[index]
		_check(level.content.select_recipe(id), "Debug catalog equips exact pair %s" % id)
		controller.reset_runtime()
		var spell: SpellSnapshot = controller.commit_cast()
		_check(spell != null and is_equal_approx(spell.damage, expected[index]), "Recipe %s computes exact base damage" % id)
		_check(spell.recipe_id == id and spell.behavior_id == id, "Recipe %s freezes its distinct behavior" % id)
		var recipe: ResonanceDefinition = controller.get_recipe()
		var reverse: Array[StringName] = recipe.recipe_rune_ids.duplicate()
		reverse.reverse()
		_check(controller.resolver.resolve(reverse, 3, controller.recipes) == recipe, "Recipe %s ignores rune order" % id)
		_check(not controller.can_cast(), "Recipe %s commits a real cooldown" % id)
	var dummy: TrainingDummy = level.dummy_a
	dummy.set_physics_process(false)
	dummy.health.maximum_health = 1000.0
	dummy.health.reset_health()
	var statuses := dummy.hurtbox.damage_resolver.status_controller as ElementStatusController
	for index: int in 3:
		var ice: DamageEvent = _damage(dummy.hurtbox, 1.0)
		ice.slow_multiplier = 0.6
		ice.slow_seconds = 2.0
		ice.freeze_points = 35.0
		dummy.hurtbox.take_damage(ice)
	_check(statuses.freeze_meter == 100.0 and statuses.is_stunned(), "Three Ice hits accumulate a finite freeze")
	var thermal: DamageEvent = _damage(dummy.hurtbox, 20.0)
	thermal.thermal_shock = true
	var result: DamageResult = dummy.hurtbox.take_damage(thermal)
	_check(result.actual_damage == 60.0 and statuses.freeze_meter == 0.0 and not statuses.is_stunned(), "Thermal Shock triples damage and consumes frozen state")
	statuses.clear()
	var poison: DamageEvent = _damage(dummy.hurtbox, 1.0)
	poison.poison_stacks = 3
	dummy.hurtbox.take_damage(poison)
	var hp: float = dummy.health.current_health
	await _time(1.05)
	_check(is_equal_approx(dummy.health.current_health, hp - 30.0), "Three poison stacks tick three percent maximum HP per second")
	var combustion: DamageEvent = _damage(dummy.hurtbox, 18.0)
	combustion.consume_poison = true
	combustion.poison_stacks = 1
	result = dummy.hurtbox.take_damage(combustion)
	_check(result.actual_damage > 90.0 and statuses.poison_count == 0, "Combustion consumes remaining poison duration without reapplying stacks")
	statuses.clear()
	var superconduct: DamageEvent = _damage(dummy.hurtbox, 1.0)
	superconduct.armor_break_seconds = 5.0
	dummy.hurtbox.take_damage(superconduct)
	var physical: DamageEvent = _damage(dummy.hurtbox, 20.0)
	physical.physical_damage = true
	result = dummy.hurtbox.take_damage(physical)
	_check(result.actual_damage == 25.0, "Superconduct increases received physical damage by twenty-five percent")
	await _time(5.1)
	result = dummy.hurtbox.take_damage(_damage(dummy.hurtbox, 20.0))
	_check(result.actual_damage == 20.0 and statuses.armor_break_remaining == 0.0, "Armor reduction expires after five seconds")
	statuses.clear()
	for enemy: SlimeEnemy in level.enemies:
		enemy.global_position = Vector2(870, 640)
		enemy.health.reset_health()
		enemy.statuses.clear()
	level.enemies[1].global_position.x += 55.0
	await _step(3)
	level.content.select_recipe(&"frost_venom")
	controller.reset_runtime()
	var frost: SpellSnapshot = controller.commit_cast()
	level.spell_executor.primary_hit(level.enemies[0].hurtbox, SpellContext.new(frost), CombatIds.next_id(), Vector2.RIGHT)
	_check(level.enemies[0].statuses.is_stunned() and (level.enemies[1].statuses as ElementStatusController).poison_count > 0, "Frost-Venom freezes the main target and spreads bounded poison to a neighbor")
	level.content.select_recipe(&"neurotoxin")
	controller.reset_runtime()
	var neuro: SpellSnapshot = controller.commit_cast()
	level.enemies[0].statuses.clear()
	level.enemies[0].state_machine.transition_to(&"attack")
	level.spell_executor.primary_hit(level.enemies[0].hurtbox, SpellContext.new(neuro), CombatIds.next_id(), Vector2.RIGHT)
	_check(level.enemies[0].state_machine.get_state_id() == &"hurt" and level.enemies[0].statuses.is_stunned(), "Neurotoxin interrupts an enemy attack")
	level.content.select_recipe(&"miasma_cloud")
	controller.reset_runtime()
	var cloud: SpellSnapshot = controller.commit_cast()
	var context := SpellContext.new(cloud)
	level.spell_executor.wall_hit(Vector2(900, 620), context)
	level.spell_executor.wall_hit(Vector2(900, 620), context)
	_check(level.spell_executor.get_children().filter(func(node: Node) -> bool: return node is ElementField).size() == 1, "One root cast creates one four-second cloud")
	await _time(4.2)
	_check(level.spell_executor.get_children().filter(func(node: Node) -> bool: return node is ElementField).is_empty(), "Cloud expires without retaining a proc context")
	await _key(KEY_F6)
	_check(level.content.panel_open and not player.controls_enabled, "F6 opens the ten-recipe catalog and gates gameplay input")
	level.content.close()
