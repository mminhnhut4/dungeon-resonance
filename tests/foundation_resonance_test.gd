extends "res://tests/survival_test_base.gd"
var events: Array[Dictionary]=[]
func _initialize() -> void:
	suite="foundation_resonance";super._initialize()
func _install(ids: Array[StringName],enabled: bool) -> SpellSnapshot:
	var controller: ResonanceController=player.resonance_controller
	controller.catalyst_a.runtime_state.opened_slots=5 # Existing high-slot recipe fixtures only.
	var runes: Array[RuneData]=[]
	for id: StringName in ids:runes.append(level.gear.inventory.get_rune(id))
	_check(controller.catalyst_a.install_runes(runes),"Exact existing loadout installs: "+str(ids))
	controller.foundation_resonance_enabled=enabled;controller.reset_runtime();player.energy.reset()
	return controller.commit_cast()
func _observe(event: DamageEvent,result: DamageResult) -> void:
	if not result.blocked and result.actual_damage>0:events.append({"source":event.source_kind,"root":event.root_event_id,"attack":event.attack_id,"damage":result.actual_damage,"allow_resonance":event.allow_resonance})
func _targets() -> void:
	level.spell_executor.clear_entities();await _step(3)
	for tuple: Array in [[level.dummy_a,Vector2(600,640)],[level.dummy_b,Vector2(460,640)]]:
		var target: TrainingDummy=tuple[0]
		target._home_position=tuple[1];target.reset_at_home();target.set_physics_process(false)
	player.reset_movement_at(Vector2(500,640));player.controls_enabled=false
	events.clear();await _step(3)
func test_system() -> void:
	session.set_enabled(false);player.controls_enabled=false;player.energy.enabled=true;player.energy.regeneration=0.0
	for enemy: SlimeEnemy in level.enemies:enemy.contact_damage_enabled=false;enemy.global_position=Vector2(1500,640)
	var controller: ResonanceController=player.resonance_controller
	var before: SpellSnapshot=_install([&"fire",&"wind"],false)
	var cost: float=player.energy.maximum-player.energy.current
	var cooldown: float=controller.cooldown_remaining()
	controller.foundation_resonance_enabled=true
	_check(before.chain_targets==0 and controller.cooldown_remaining()==cooldown and not controller.can_cast(),"Unlocking after a cast cannot alter its frozen payload or clear cooldown")
	var after: SpellSnapshot=_install([&"fire",&"wind"],true)
	_check(after.chain_targets==1 and after.damage==before.damage and after.explosion_damage==before.explosion_damage and after.effect_radius==before.effect_radius and after.windup==before.windup,"Truc Co adds one real chain without changing primary/AOE damage, radius or cast timing")
	_check(cost==ResonanceController.CAST_ENERGY_COST and player.energy.maximum-player.energy.current==cost and controller.cooldown_remaining()==cooldown,"Mana and cooldown are identical before and after")
	for raw: Array in [[&"fire"],[],[&"fire",&"lightning"],[&"fire",&"fire",&"wind",&"lightning"],[&"fire",&"fire",&"wind",&"lightning",&"lightning"]]:
		var ids: Array[StringName]=[];ids.assign(raw)
		var payload: SpellSnapshot=_install(ids,true)
		_check(payload!=null and payload.chain_targets== (0 if ids.size()<2 else 2),"Basic/single stay unchanged; exact lightning and four/five-rune recipes retain the two-link cap")
	_check(GearInventory.RUNES[2].chain_targets==2 and GearInventory.RUNES[0].burn_damage==3.0,"Derived unlock never mutates shared rune Resources")
	var invalid: Array[RuneData]=[GearInventory.RUNES[0],GearInventory.RUNES[0]]
	controller.catalyst_a.install_runes(invalid);controller.reset_runtime();player.energy.reset()
	_check(controller.get_recipe()==null and controller.commit_cast()==null and player.energy.current==player.energy.maximum,"An invalid exact multiset still cannot cast or spend mana")
	level.dummy_b.hurtbox.hit_resolved.connect(_observe)
	await _targets()
	before=_install([&"fire",&"wind"],false)
	before.origin=player.aim.global_position;before.direction=Vector2.RIGHT
	var chain_before: int=level.spell_executor.chain_hit_count
	level.spell_executor.spawn_cast(before);await _time(0.45)
	_check(level.dummy_a.hit_count>0 and level.dummy_b.hit_count==0 and level.spell_executor.chain_hit_count==chain_before,"Real pre-breakthrough projectile hits the front target but not the neighbor behind its source")
	await _targets()
	after=_install([&"fire",&"wind"],true)
	after.origin=player.aim.global_position;after.direction=Vector2.RIGHT
	level.spell_executor.spawn_cast(after);await _time(0.45)
	_check(level.dummy_a.hit_count>0 and level.dummy_b.hit_count==1 and level.spell_executor.chain_hit_count==chain_before+1,"Real post-breakthrough projectile uses the existing chain consumer to hit the second target once")
	_check(events.size()==1 and events[0]["source"]==DamageEvent.SourceKind.RESONANCE and events[0]["root"]==after.root_id and not events[0]["allow_resonance"] and is_equal_approx(events[0]["damage"],after.damage*SpellExecutor.CHAIN_DAMAGE_FACTOR),"Secondary damage retains root, sixty-percent factor and recursion guard")
	await _targets()
	after=_install([&"fire",&"wind"],true);after.origin=player.aim.global_position
	level.dummy_b.hurtbox.set_invulnerable(true)
	level.spell_executor.spawn_cast(after);await _time(0.4)
	_check(events.is_empty() and level.spell_executor.chain_hit_count==chain_before+1,"Invulnerable neighbor receives no false accepted chain hit")
	await _targets()
	after=_install([&"fire",&"wind"],true);after.origin=player.aim.global_position
	level.dummy_b.health.apply_damage(999.0)
	level.spell_executor.spawn_cast(after);await _time(0.4)
	_check(events.is_empty() and level.spell_executor.chain_hit_count==chain_before+1,"Dead neighbor is excluded from chain delivery")
	await _targets()
	var capped: Array[SpellVisual]=[]
	for _i: int in level.spell_executor.maximum_spell_entities:
		var visual:=SpellVisual.new();visual.lifetime=2.0;level.spell_executor.add_child(visual);capped.append(visual)
	after=_install([&"fire",&"ice"],true)
	level.spell_executor.primary_hit(level.dummy_a.hurtbox,SpellContext.new(after),CombatIds.next_id(),Vector2.RIGHT)
	_check(get_nodes_in_group(&"spell_entities").size()==level.spell_executor.maximum_spell_entities,"Chain damage cannot allocate visual entities above the existing sixty-four cap")
	for visual: SpellVisual in capped:visual.queue_free()
	level.spell_executor.clear_entities();await _time(1.3)
	_check(get_nodes_in_group(&"spell_entities").is_empty(),"All projectiles, fields and link visuals release with their existing lifetime")
