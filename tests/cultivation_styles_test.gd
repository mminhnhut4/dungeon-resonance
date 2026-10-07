extends SceneTree
## Candidate-only focused tests: real actor FSM/motor, physics queries and input.
var arena: Node2D
var hero: Player
var runtime: CultivationStyleRuntime
var feedback: CombatFeedback
var checks: int = 0
var failures: int = 0
var results: Array[StringName] = []
const LEARNED: Array[StringName] = [&"cloud_return", &"tether_sigil"]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="): Engine.physics_ticks_per_second = int(arg.trim_prefix("--hz="))
	print("ISOLATED_USER: ", OS.get_user_data_dir())
	arena = Node2D.new()
	root.add_child(arena)
	current_scene = arena
	_block(Vector2(600, 680), Vector2(1200, 80))
	hero = preload("res://scenes/actors/player/player.tscn").instantiate() as Player
	arena.add_child(hero)
	hero.reset_movement_at(Vector2(500, 640))
	hero.energy.enabled = true
	hero.energy.regeneration = 0
	hero.equipped_weapon.equip(Player.SWORD)
	feedback = CombatFeedback.new()
	feedback.hit_stop_seconds = 0
	arena.add_child(feedback)
	hero.combat_feedback = feedback
	runtime = CultivationStyleRuntime.new()
	hero.add_child(runtime)
	_check(runtime.initialize(hero, arena), "Opt-in action registers without restarting the actor FSM")
	runtime.technique_finished.connect(func(_id: StringName, reason: StringName) -> void: results.append(reason))
	await _step(4)
	await _progress()
	await _sword()
	await _sigil()
	await _compatibility()
	await _cancellation()
	await _finished_snapshot_reentry()
	await _lifecycle()
	arena.queue_free()
	await _step(4)
	_check(get_nodes_in_group(&"cultivation_sigils").is_empty(), "Final actor/room teardown leaves no sigils")
	await _fixture_input()
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _progress() -> void:
	_check(runtime.learned.is_empty() and runtime.selected == &"" and not runtime.request_skill(Vector2(560, 620)), "No automatic or unearned unlock on construction")
	_check(runtime.apply_progress_snapshot(LEARNED, &"cloud_return"), "Shared progression owner supplies learned IDs and selected style")
	_check(not runtime.apply_progress_snapshot([&"cloud_return", &"cloud_return"], &"cloud_return"), "Duplicate IDs are rejected")
	_check(not runtime.apply_progress_snapshot([&"unknown"], &""), "Unknown IDs are rejected without changes")
	_check(not runtime.apply_progress_snapshot([&"cloud_return"], &"tether_sigil") and runtime.selected == &"cloud_return" and runtime.learned == LEARNED, "Unearned selection fails atomically")
	var duplicate := CultivationStyleRuntime.new()
	hero.add_child(duplicate)
	_check(not duplicate.initialize(hero, arena), "Second runtime cannot register a second skill state")
	duplicate.queue_free()
	_check(not hero.action_state_machine.unregister_state(&"ready"), "Live initial FSM state cannot be unregistered")
	_check(not runtime.request_skill(Vector2(560, 620)) and runtime.last_rejection == &"dodge_required" and hero.energy.current == 100, "Sword requires an actual dodge opportunity before any cost")
	hero.energy.enabled = false
	_check(not runtime.request_skill(Vector2(560, 620)) and runtime.last_rejection == &"context", "Candidate refuses the legacy disabled cost pool")
	hero.energy.enabled = true
	await _step(1)

func _sword() -> void:
	await _reset(&"cloud_return")
	var guard: BaseEnemy = _enemy(&"ancient_guard", Vector2(600, 640))
	await _step(3)
	guard.state_machine.transition_to(&"telegraph")
	guard.state_machine.transition_to(&"attack")
	hero._pending_dash = true
	await _step(2)
	_check(hero.motor.is_dashing and hero.motor.is_invulnerable() and not hero.hurtbox.monitorable, "Real dash reaches its deferred contact immunity")
	guard.attack_hitbox.sample_contacts()
	_check(runtime.counter_remaining > 0 and hero.health.current_health == 100 and guard.attack_hitbox._hit_targets.has(hero.get_instance_id()), "Real hostile sweep query grants a ticket from an invulnerable dodge without HP loss")
	var root_id: int = runtime.counter_root
	var ticket: float = runtime.counter_remaining
	guard.attack_hitbox.sample_contacts()
	_check(runtime.counter_root == root_id and runtime.counter_remaining == ticket, "Repeated contact for one hostile root cannot refresh the ticket")
	_check(not runtime.request_skill(guard.hurtbox.global_position) and hero.energy.current == 75, "Cannot counter while the dash action is still active")
	guard.attack_hitbox.deactivate()
	await _time(0.18)
	_check(hero.action_state_machine.get_state_id() == &"ready" and runtime.counter_remaining > 0, "Motor completes its existing dash before the short counter window ends")
	guard.global_position = hero.global_position + Vector2(-52, 0)
	guard.state_machine.transition_to(&"telegraph")
	await _step(2)
	var hp: float = guard.health.current_health
	var impacts: int = feedback.impact_count
	_check(not runtime.request_skill(Vector2(NAN, 0)) and hero.energy.current == 75 and runtime.counter_remaining > 0, "Non-finite counter aim fails before spending or consuming its ticket")
	_check(runtime.request_skill(guard.hurtbox.global_position) and hero.energy.current == 63 and runtime.counter_remaining == 0, "Sword counter costs 12 after the existing 25-energy dash and consumes one ticket")
	_check(not runtime.hitbox.active and guard.health.current_health == hp, "Counter has a readable preparation before contact")
	await _time(0.11)
	_check(guard.health.current_health == hp - 10 and guard.hit_count == 1 and runtime.accepted_hits == 1, "Counter delivers ordinary 10 damage exactly once through a real hitbox")
	_check(guard.state_machine.get_state_id() == &"hurt" and not guard.attack_hitbox.active, "Counter interrupts a vulnerable enemy through its existing Hurt response")
	_check(feedback.impact_count == impacts + 1, "Shared root deduplicates target/source confirmation into one impact")
	_check(hero.action_state_machine.get_state_id() == &"cultivation_skill", "Counter preserves its recovery commitment")
	await _time(0.38)
	_check(hero.action_state_machine.get_state_id() == &"ready" and not runtime.hitbox.active and results.back() == &"completed", "Counter exits a finite recovery with its window closed")
	var cd: float = runtime.cooldowns[&"cloud_return"]
	runtime.apply_progress_snapshot(LEARNED, &"tether_sigil")
	runtime.apply_progress_snapshot(LEARNED, &"cloud_return")
	_check(runtime.cooldowns[&"cloud_return"] == cd and hero.energy.current == 63, "Respec cannot erase cooldowns or refund skill/dash cost")
	await _reset(&"cloud_return")
	guard = _enemy(&"ancient_guard", Vector2(550, 640))
	await _step(2)
	guard.state_machine.transition_to(&"attack")
	runtime.counter_remaining = 0.75 # Fixture-only priming; real priming verified above.
	_check(runtime.request_skill(guard.hurtbox.global_position), "Poise fixture commits the same counter")
	await _time(0.12)
	_check(guard.health.current_health == guard.health.maximum_health - 10 and guard.has_poise() and guard.state_machine.get_state_id() == &"attack", "Counter respects committed enemy Poise; no invented parry or stun bypass")
	await _reset(&"cloud_return")
	runtime.counter_remaining = 0.04
	await _time(0.06)
	_check(not runtime.request_skill(Vector2(550, 620)) and hero.energy.current == 100, "An expired ticket fails without a cost")
	hero.equipped_weapon.equip(Player.DAGGER)
	await _step(2)
	runtime.counter_remaining = 0.5
	_check(not runtime.request_skill(Vector2(550, 620)) and runtime.last_rejection == &"weapon" and hero.energy.current == 100, "Sword technique cannot be executed with a different equipped weapon")
	hero.equipped_weapon.equip(Player.SWORD)
	await _step(2)
	_check(runtime.counter_remaining == 0, "Direct inventory equip clears stale counter opportunities without relying on a Player signal")

func _sigil() -> void:
	await _reset(&"tether_sigil")
	_check(not runtime.request_skill(Vector2(INF, 0)) and not runtime.request_skill(Vector2(900, 620)) and hero.energy.current == 100, "Sigil rejects non-finite and beyond-190px placement before cost")
	var wall: StaticBody2D = _block(Vector2(550, 598), Vector2(12, 80))
	await _step(2)
	_check(not runtime.request_skill(Vector2(590, 620)) and runtime.last_rejection == &"placement", "Placement cannot pass through real terrain")
	wall.queue_free()
	await _step(2)
	var guard: BaseEnemy = _enemy(&"ancient_guard", Vector2(580, 640))
	await _step(2)
	_check(runtime.request_skill(Vector2(580, 620)) and hero.energy.current == 82 and runtime.cooldowns[&"tether_sigil"] == 5, "Placing one planned sigil costs 18 with a five-second cooldown")
	await _time(0.18)
	_check(not is_instance_valid(runtime.mark) and guard.hit_count == 0, "Placement tell gives no early damage or mark")
	await _time(0.16)
	_check(is_instance_valid(runtime.mark) and not runtime.mark.is_armed() and not runtime.mark.hitbox.active and guard.hit_count == 0, "New mark remains harmless and visibly unarmed")
	await _time(0.28)
	_check(not runtime.request_skill(Vector2(580, 620)) and hero.energy.current == 82, "An unarmed mark cannot be activated or charged again")
	await _time(0.13)
	var mark_id: int = runtime.mark.get_instance_id()
	_check(runtime.mark.is_armed() and guard.hit_count == 0, "Armed mark never causes automatic proximity damage")
	hero.global_position.x = 100
	_check(not runtime.request_skill(Vector2(580, 620)) and hero.energy.current == 82 and runtime.mark.is_armed(), "Activation leash rejects remote offscreen triggering without a charge")
	hero.global_position.x = 500
	await _step(2)
	runtime.apply_progress_snapshot(LEARNED, &"tether_sigil")
	_check(runtime.mark.get_instance_id() == mark_id, "Repeated identical progression snapshots preserve a planned mark")
	var root_id: int = runtime.mark.root_id
	_check(runtime.request_skill(Vector2(580, 620)) and hero.energy.current == 74 and runtime._root == root_id, "Explicit activation costs 8 and retains the placement root while cooldown stays running")
	await _time(0.1)
	_check(guard.hit_count == 0 and not runtime.mark.hitbox.active, "Pulse has a separate readable 0.18-second tell")
	await _time(0.13)
	_check(guard.hit_count == 1 and guard.health.current_health == guard.health.maximum_health - 4 and guard.statuses.movement_multiplier == 0.55, "Pulse applies small damage and finite space-control slow through standard statuses")
	await _time(0.4)
	_check(not is_instance_valid(runtime.mark) and not runtime.hitbox.active and hero.action_state_machine.get_state_id() == &"ready", "One pulse consumes its mark and recovers without recurring damage")
	_check(not runtime.request_skill(Vector2(580, 620)) and runtime.last_rejection == &"cooldown" and hero.energy.current == 74, "Consuming a mark does not reopen placement or its resource cost")
	await _time(0.5)
	_check(guard.statuses.movement_multiplier == 1.0 and guard.hit_count == 1, "Control expires without DoT, recursive proc or extra hit")
	await _reset(&"tether_sigil")
	for i: int in range(4): _enemy(&"ancient_guard", Vector2(570 + 12 * i, 640))
	await _step(2)
	runtime.request_skill(Vector2(590, 620))
	await _time(0.75)
	var sigil: CultivationSigil = runtime.mark
	runtime.request_skill(Vector2(590, 620))
	await _time(0.22)
	var total: int = 0
	for enemy: Node in get_nodes_in_group(&"world_enemies"): total += enemy.hit_count
	_check(total == 3 and sigil.attempts == 3 and not sigil.hitbox.active, "Dense overlap is bounded to three target attempts, one delivery per actor")
	await _reset(&"tether_sigil")
	guard = _enemy(&"ancient_guard", Vector2(580, 640))
	await _step(2)
	runtime.request_skill(Vector2(580, 620))
	await _time(0.75)
	guard.hurtbox.set_invulnerable(true)
	runtime.request_skill(Vector2(580, 620))
	await _time(0.22)
	_check(guard.hit_count == 0 and runtime.mark.attempts == 1 and runtime.accepted_hits == 0 and guard.statuses.movement_multiplier == 1, "Invulnerable pulse contact consumes one bounded attempt with no damage/status/accepted feedback")
	await _reset(&"tether_sigil")
	runtime.request_skill(Vector2(580, 620))
	await _time(0.75)
	_check(not runtime.request_skill(Vector2(NAN, 0)) and hero.energy.current == 82 and runtime.mark.is_armed(), "Non-finite activation is also rejected atomically")
	await _time(3.8)
	_check(not is_instance_valid(runtime.mark) and runtime.accepted_hits == 0, "Unused marks expire harmlessly after four seconds")

func _cancellation() -> void:
	await _reset(&"tether_sigil")
	runtime.request_skill(Vector2(580, 620))
	hero._pending_dash = true
	await _step(2)
	_check(hero.action_state_machine.get_state_id() == &"dash" and not runtime.hitbox.active and results.back() == &"cancelled" and hero.energy.current == 57, "Existing dash cancels the new action while preserving both paid costs")
	await _time(0.7)
	_check(not is_instance_valid(runtime.mark) and runtime.cooldowns[&"tether_sigil"] > 4, "Cancelled preparation cannot spawn a delayed mark or reset its cooldown")
	await _reset(&"tether_sigil")
	runtime.request_skill(Vector2(580, 620))
	await _time(0.34)
	runtime.apply_progress_snapshot(LEARNED, &"cloud_return")
	await _step(1) # Finished telemetry is delivered after the FSM exit completes.
	_check(not runtime.hitbox.active and runtime.mark == null and results.back() == &"cancelled" and hero.energy.current == 82, "Respec during post-launch recovery cancels honestly without refund")
	await _step(2)
	_check(get_nodes_in_group(&"cultivation_sigils").is_empty(), "Respec clears all room marks before selecting the other style")
	await _reset(&"tether_sigil")
	runtime.request_skill(Vector2(580, 620))
	await _time(0.75)
	var before_age: float = runtime.mark.age
	var before_cd: float = runtime.cooldowns[&"tether_sigil"]
	paused = true
	await _step(4)
	_check(runtime.mark.age == before_age and runtime.cooldowns[&"tether_sigil"] == before_cd and not runtime.request_skill(Vector2(580, 620)), "Pause stops gameplay clocks and rejects skill input")
	paused = false
	feedback.set_physics_process(false)
	feedback._frozen_this_tick = true
	await _step(4)
	_check(runtime.mark.age == before_age and runtime.cooldowns[&"tether_sigil"] == before_cd and not runtime.request_skill(Vector2(580, 620)), "Existing combat freeze stops mark/cooldown clocks and commit")
	feedback._frozen_this_tick = false
	feedback.set_physics_process(true)
	hero.action_state_machine.transition_to(&"hurt")
	_check(runtime.mark == null and not runtime.hitbox.active, "Hurt clears planned marks before another action can use them")
	await _reset(&"tether_sigil")
	runtime.request_skill(Vector2(580, 620))
	await _time(0.75)
	hero.action_state_machine.transition_to(&"dead")
	_check(runtime.mark == null and not runtime.hitbox.active and not runtime.request_skill(Vector2(580, 620)), "Dead actors cannot retain or trigger marks")
	await _reset(&"tether_sigil")
	hero.energy.current = 17
	_check(not runtime.request_skill(Vector2(580, 620)) and runtime.cooldowns[&"tether_sigil"] == 0 and hero.energy.current == 17, "Insufficient energy cannot start cooldown or action")
	_check(CultivationStyleRuntime.DATA[&"cloud_return"].damage == 10 and CultivationStyleRuntime.DATA[&"tether_sigil"].damage == 4 and Player.SWORD.base_damage == 10, "Technique data and existing shared weapon remain immutable")

func _compatibility() -> void:
	await _reset(&"tether_sigil")
	var visible: BaseEnemy = _enemy(&"ancient_guard", Vector2(560, 640))
	var hidden: BaseEnemy = _enemy(&"ancient_guard", Vector2(630, 640))
	var wall: StaticBody2D = _block(Vector2(610, 598), Vector2(10, 80))
	await _step(3)
	runtime.request_skill(Vector2(580, 620))
	await _time(0.75)
	var sigil: CultivationSigil = runtime.mark
	runtime.request_skill(Vector2(580, 620))
	await _time(0.22)
	_check(visible.hit_count == 1 and hidden.hit_count == 0 and sigil.attempts == 1, "Real pulse LOS ignores occluded targets without stealing a visible target's attempt")
	wall.queue_free()
	await _reset(&"tether_sigil")
	var champion: BaseEnemy = _enemy(&"runic_champion", Vector2(580, 640))
	await _step(2)
	var shield: EnemyShieldHealth = champion.health as EnemyShieldHealth
	var shield_before: float = shield.current_shield
	runtime.request_skill(Vector2(580, 620))
	await _time(0.75)
	runtime.request_skill(Vector2(580, 620))
	await _time(0.22)
	_check(champion.health.current_health == champion.health.maximum_health and shield.current_shield == shield_before - 4 and champion.statuses.movement_multiplier == 0.55, "Sigil uses existing shield absorption and slow semantics without ignoring protection")
	await _reset(&"tether_sigil")
	var boss: BossGolem = preload("res://scenes/enemies/boss_golem.tscn").instantiate() as BossGolem
	boss.position = Vector2(580, 640)
	boss.ai_enabled = false
	boss.player = hero
	boss.feedback = feedback
	arena.add_child(boss)
	await _step(2)
	runtime.request_skill(Vector2(580, 620))
	await _time(0.75)
	runtime.request_skill(Vector2(580, 620))
	await _time(0.22)
	_check(boss.health.current_health == 496 and boss.statuses.movement_multiplier == 0.55 and not boss.statuses.accepts_stun and boss.fsm.get_state_id() != &"staggered", "Boss receives ordinary low damage/slow while keeping its stun immunity and stagger policy")
	await _reset(&"cloud_return")
	boss.global_position = Vector2(555, 640)
	runtime.counter_remaining = 0.75
	runtime.request_skill(boss.hurtbox.global_position)
	await _time(0.12)
	_check(boss.health.current_health == 486 and boss.stagger == 10 and boss.fsm.get_state_id() != &"staggered", "Sword counter contributes one normal stagger root rather than immediately disabling a boss")
	boss.queue_free()
	await _reset(&"cloud_return")
	var guard: BaseEnemy = _enemy(&"ancient_guard", Vector2(580, 640))
	await _step(2)
	guard.state_machine.transition_to(&"attack")
	hero.damage_grace_remaining = 0.5
	await _step(2)
	guard.attack_hitbox.sample_contacts()
	_check(runtime.counter_remaining == 0 and hero.health.current_health == 100, "Ordinary damage-grace immunity creates no dodge counter opportunity")
	guard.attack_hitbox.deactivate()
	hero._pending_dash = true
	await _step(2)
	var dot := DamageEvent.new()
	dot.source_id = guard.get_instance_id()
	dot.source_team_id = 2
	dot.root_event_id = CombatIds.next_id()
	dot.attack_id = dot.root_event_id
	dot.base_damage = 1
	dot.source_kind = DamageEvent.SourceKind.DOT
	hero.hurtbox.take_damage(dot)
	_check(runtime.counter_remaining == 0, "DOT blocked during a real dash cannot prime the sword counter")

func _finished_snapshot_reentry() -> void:
	for expected: StringName in [&"completed", &"cancelled"]:
		await _reset(&"tether_sigil")
		var seen: Array[StringName] = []
		var action_at_callback: Array[StringName] = []
		var snapshot_ok: Array[bool] = []
		var costs_unchanged: Array[bool] = []
		var handler: Callable = func(_id: StringName, reason: StringName) -> void:
			seen.append(reason)
			action_at_callback.append(hero.action_state_machine.get_state_id())
			# Keep a regression on the old synchronous code bounded instead of
			# allowing unbounded recursion to hide the actual double emission.
			if seen.size() > 1: return
			var before_energy: float = hero.energy.current
			var before_cooldown: float = runtime.cooldowns[&"tether_sigil"]
			snapshot_ok.append(runtime.apply_progress_snapshot([&"cloud_return"], &"cloud_return"))
			costs_unchanged.append(hero.energy.current == before_energy and runtime.cooldowns[&"tether_sigil"] == before_cooldown)
		runtime.technique_finished.connect(handler)
		_check(runtime.request_skill(Vector2(580, 620)), "%s callback regression commits one technique" % expected)
		if expected == &"completed":
			await _time(0.12)
			_check(seen.is_empty(), "Completion callback waits for actual recovery, not just launch")
			await _time(0.60)
		else:
			runtime.cancel_for_room_transition()
			_check(seen.is_empty() and hero.action_state_machine.get_state_id() == &"ready" and runtime._mode == &"", "Cancellation clears transient mode and completes FSM transition before notifying")
			await _step(2)
		_check(seen == [expected] and action_at_callback == [&"ready"], "%s handler observes Ready and emits exactly once without FSM exit recursion" % expected)
		_check(snapshot_ok == [true] and runtime.selected == &"cloud_return" and runtime.learned == [&"cloud_return"], "%s handler can revoke/reselect via a changed progression snapshot" % expected)
		_check(costs_unchanged == [true] and hero.energy.current == 82 and runtime.cooldowns[&"tether_sigil"] > 4.1 and runtime.cooldowns[&"tether_sigil"] < 5.0, "%s callback snapshot cannot refund cost or reset cooldown" % expected)
		_check(runtime.mark == null and not runtime.hitbox.active and get_nodes_in_group(&"cultivation_sigils").is_empty(), "%s callback clears prior-style marks and contact windows" % expected)
		await _time(0.10)
		_check(seen == [expected] and hero.action_state_machine.get_state_id() == &"ready", "%s callback stays finite with no repeated completion/cancellation" % expected)
		runtime.technique_finished.disconnect(handler)

func _lifecycle() -> void:
	await _reset(&"tether_sigil")
	var temporary := Node2D.new()
	arena.add_child(temporary)
	runtime.bind_room(temporary)
	runtime.request_skill(Vector2(580, 620))
	temporary.queue_free()
	await _time(0.5)
	_check(hero.action_state_machine.get_state_id() == &"ready" and not is_instance_valid(runtime.mark) and hero.energy.current == 82, "Room deletion during preparation safely closes action without stale-room spawn")
	_check(not runtime.request_skill(Vector2(580, 620)) and runtime.last_rejection == &"context", "A departed room rejects further commits")
	runtime.bind_room(arena)
	var cd: float = runtime.cooldowns[&"tether_sigil"]
	runtime.cancel_for_room_transition()
	_check(runtime.cooldowns[&"tether_sigil"] == cd and hero.energy.current == 82, "Explicit room rebinding preserves spent resources and cooldown")
	runtime.queue_free()
	await _step(3)
	_check(not hero.action_state_machine._states.has(&"cultivation_skill"), "Removing the opt-in runtime unregisters its action and observers")
	runtime = CultivationStyleRuntime.new()
	hero.add_child(runtime)
	_check(runtime.initialize(hero, arena) and runtime.learned.is_empty(), "A fresh runtime reinstalls cleanly and still grants no unlocks")

func _fixture_input() -> void:
	var lab: Node2D = preload("res://scenes/cultivation/style_lab.tscn").instantiate()
	root.add_child(lab)
	current_scene = lab
	await _step(4)
	var weapon_id: StringName = lab.player.equipped_weapon.definition.id
	await _key(KEY_F10)
	_check(lab.techniques.selected == &"tether_sigil" and lab.player.equipped_weapon.definition.id == weapon_id, "Real F10 input selects talisman without the Q/F7 weapon/QA conflict")
	await _key(KEY_F9)
	_check(lab.techniques.selected == &"cloud_return", "Real F9 input selects sword without changing rune presets or the F6 recipe catalog")
	await _key(KEY_G)
	_check(lab.techniques.last_rejection == &"dodge_required" and lab.player.equipped_weapon.definition.id == weapon_id, "Real G skill input reaches runtime and leaves the equipped weapon intact")
	await _composition_compatibility(lab)
	var ids: Array[int] = []
	for enemy: BaseEnemy in lab.fixture_enemies: ids.append(enemy.get_instance_id())
	lab.reset_room()
	await _step(3)
	_check(lab.fixture_enemies.size() == 3 and lab.fixture_enemies[0].get_instance_id() not in ids and lab.techniques.mark == null, "Fixture reset rebuilds its existing enemies and clears transient skills")
	lab.queue_free()
	await _step(5)
	_check(get_nodes_in_group(&"cultivation_sigils").is_empty() and root.get_node("AudioManager").get_active_voice_count() == 0, "Fixture teardown releases skill marks and spatial audio owners")

func _composition_compatibility(lab: Node2D) -> void:
	var subject: Player = lab.player
	var controller: ResonanceController = subject.resonance_controller
	for enemy: SlimeEnemy in lab.enemies: enemy.ai_enabled = false
	for enemy: BaseEnemy in lab.fixture_enemies: enemy.ai_enabled = false
	lab.combat_feedback.hit_stop_seconds = 0
	lab.content.qa_tools_enabled = true # Test QA bindings as well as shipping defaults.
	subject.energy.regeneration = 0
	subject.energy.current = 100
	var pair: Array[StringName] = [&"fire", &"wind"]
	_check(lab.gear.inventory.equip_catalyst_set(pair) and controller.get_recipe().id == &"firestorm", "Existing owned Fire+Wind shards still compose Firestorm through GearSession/Catalyst")
	var slots: Array[StringName] = lab.gear.inventory.slots.duplicate()
	var uids: Array[int] = lab.gear.inventory.slot_uids.duplicate()
	var recipe: ResonanceDefinition = controller.get_recipe()
	controller.loadout_state.cooldowns_by_recipe_id[&"firestorm"] = 0.75
	var old_cooldown: float = controller.cooldown_remaining()
	lab.techniques.apply_progress_snapshot(LEARNED, &"tether_sigil")
	lab.techniques.apply_progress_snapshot(LEARNED, &"cloud_return")
	_check(controller.get_recipe() == recipe and lab.gear.inventory.slots == slots and lab.gear.inventory.slot_uids == uids and controller.cooldown_remaining() == old_cooldown and controller.casting_enabled, "Both technique selections preserve exact recipe, equipped rune UIDs and existing spell cooldown")
	await _key(KEY_F6)
	_check(lab.content.panel_open and not subject.controls_enabled and lab.techniques.selected == &"cloud_return", "Original F6 recipe matrix remains available; technique selection does not replace its UI")
	lab.content.close()
	await _key(KEY_F10)
	await _key(KEY_F9)
	_check(not lab.content.panel_open and subject.controls_enabled and controller.get_recipe() == recipe and lab.gear.inventory.slots == slots and lab.gear.inventory.slot_uids == uids, "F9/F10 work with QA enabled without opening catalog or granting F7 debug rewards")
	# Explicit fresh-cast fixture setup; never called by a style/progression API.
	controller.reset_runtime()
	lab.techniques.apply_progress_snapshot(LEARNED, &"tether_sigil")
	var target: Vector2 = subject.aim.global_position + Vector2(65, 0)
	_check(lab.techniques.request_skill(target), "One planned mark can be prepared alongside an equipped old rune combination")
	await _time(0.72)
	var sigil_id: int = lab.techniques.mark.get_instance_id()
	var cast_count: int = controller.cast_count
	var projectile_count: int = lab.spell_executor.spawned_projectiles
	await _key(KEY_I)
	var cast_state: PlayerCastState = subject.action_state_machine.current_state as PlayerCastState
	_check(controller.cast_count == cast_count + 1 and cast_state != null and cast_state.payload.behavior_id == &"firestorm" and subject.energy.current == 52 and lab.techniques.mark.get_instance_id() == sigil_id, "Physical I still commits composed Firestorm for 30 energy while the mark persists")
	await _time(0.45)
	_check(lab.spell_executor.spawned_projectiles == projectile_count + 1 and subject.action_state_machine.get_state_id() == &"ready" and controller.get_recipe() == recipe, "Existing SpellExecutor launches its composed spell and exits the original cast action")
	old_cooldown = controller.cooldown_remaining()
	_check(lab.techniques.request_skill(target) and subject.energy.current == 44 and controller.cooldown_remaining() == old_cooldown and controller.cast_count == cast_count + 1, "Explicit mark pulse keeps the old recipe cooldown and cannot manufacture a second composed cast")
	await _time(0.6)
	old_cooldown = controller.cooldown_remaining()
	var no_techniques: Array[StringName] = []
	lab.techniques.apply_progress_snapshot(no_techniques, &"")
	_check(controller.get_recipe() == recipe and controller.casting_enabled and lab.gear.inventory.slots == slots and controller.cooldown_remaining() == old_cooldown, "Revoking optional techniques leaves the existing talisman-composition identity intact")
	await _time(0.8)
	await _key(KEY_I)
	_check(controller.cast_count == cast_count + 2 and subject.energy.current == 14 and lab.techniques.selected == &"", "Existing composed casting remains usable with every cultivation technique locked")
	await _time(0.4)

func _reset(id: StringName) -> void:
	runtime.cancel_for_room_transition()
	for enemy: Node in get_nodes_in_group(&"world_enemies") + get_nodes_in_group(&"world_enemy_hazards") + get_nodes_in_group(&"combat_text"):
		if arena.is_ancestor_of(enemy): enemy.queue_free()
	await _step(3)
	feedback.reset_feedback()
	hero.reset_movement_at(Vector2(500, 640))
	hero.equipped_weapon.equip(Player.SWORD)
	hero.controls_enabled = true
	hero.energy.enabled = true
	hero.energy.regeneration = 0
	runtime.cooldowns[&"cloud_return"] = 0
	runtime.cooldowns[&"tether_sigil"] = 0
	runtime.accepted_hits = 0
	runtime.apply_progress_snapshot(LEARNED, id)
	await _step(3)

func _enemy(id: StringName, position: Vector2) -> BaseEnemy:
	var enemy: BaseEnemy = (load("res://scenes/enemies/%s.tscn" % id) as PackedScene).instantiate() as BaseEnemy
	enemy.position = position
	enemy.player = hero
	enemy.combat_feedback = feedback
	enemy.ai_enabled = false
	arena.add_child(enemy)
	return enemy

func _block(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 1
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	body.add_child(collision)
	arena.add_child(body)
	return body

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await _step(2)
	event = InputEventKey.new()
	event.physical_keycode = key
	Input.parse_input_event(event)
	await _step(2)

func _time(seconds: float) -> void:
	await _step(ceili(seconds * Engine.physics_ticks_per_second))

func _step(frames: int) -> void:
	for frame: int in frames:
		await physics_frame
		await process_frame

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures += 1
	print("%s: %s" % ["PASS" if ok else "FAIL", message])
