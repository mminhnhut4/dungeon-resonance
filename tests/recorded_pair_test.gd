extends SceneTree
## Focused observer/mixer contracts. Synthetic events are not gameplay evidence.
var checks: int=0
var failures: int=0
var manager: Node
var events: Array[String]=[]

func _initialize() -> void:call_deferred("_run")
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print("%s: %s"%["PASS" if ok else "FAIL",label])
func born(node: Node) -> void:
	if node is AudioStreamPlayer2D and node.name.begins_with("SFX_"):events.append(String(node.name))
func last_is(cue: String) -> bool:return not events.is_empty() and events[-1].begins_with("SFX_"+cue+"_")
func damage(target: Hurtbox,source: Player) -> DamageEvent:
	var event:=DamageEvent.new()
	event.source_id=source.get_instance_id();event.source_team_id=source.hurtbox.team_id
	event.attack_id=CombatIds.next_id();event.root_event_id=event.attack_id;event.hit_window_id=1
	event.target_id=target.get_actor_id();event.base_damage=1;event.melee_hit=true
	return event

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	manager=root.get_node("AudioManager");node_added.connect(born)
	var owner_node:=Node2D.new();root.add_child(owner_node)
	for cue: StringName in manager._recorded_pair.STREAMS:
		var previous: AudioStreamWAV
		for i: int in 4:
			var stream: AudioStreamWAV=manager._recorded_pair.pick(cue,manager._pitch_rng)
			check(stream!=null and stream!=previous and stream.mix_rate==48000 and not stream.stereo and stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.loop_mode==AudioStreamWAV.LOOP_DISABLED and stream.get_length()>0 and stream.get_length()<.5,"%s variant finite mono PCM and no immediate repeat"%cue)
			previous=stream
		var voice: AudioStreamPlayer2D=manager.play_recorded_event(cue,Vector2.ZERO,owner_node)
		check(voice!=null and voice.pitch_scale==1.0 and voice.bus==&"SFX_Combat" and voice.max_polyphony==1,"%s preserves pitch and uses existing spatial bus"%cue)
	check(manager.play_recorded_event(&"spell_cast",Vector2(INF,0),owner_node)==null,"Invalid location creates no emitter")
	manager.stop_all()
	for i: int in 40:manager.play_recorded_event(&"spell_impact",Vector2.ZERO,owner_node)
	check(manager.get_active_voice_count()==16,"Global voice cap remains sixteen")
	manager.stop_owner(owner_node);check(manager.get_active_voice_count()==0,"Owner cleanup releases every voice")
	var legacy: AudioStreamPlayer2D=manager.play_event(&"swing",Vector2.ZERO,owner_node)
	check(legacy!=null and legacy.stream==manager.get_cue_stream(&"sword_swing"),"Legacy API still returns original legacy stream")
	legacy=manager.play_weighted_event(&"melee_impact",Vector2.ZERO,owner_node)
	check(legacy!=null and legacy.stream==manager.get_weighted_cue_stream(&"melee_impact"),"Weighted API and getter retain their legacy contract")
	manager.stop_all()
	var level: Node2D=preload("res://scenes/test_level.tscn").instantiate();root.add_child(level);current_scene=level
	for i: int in 8:await process_frame
	var player: Player=level.player;player.controls_enabled=false
	level.survival.director.automatic=false
	for enemy: SlimeEnemy in level.enemies:enemy.ai_enabled=false
	var p: SlicePresentation=level.presentation;var weapon: Weapon=player.equipped_weapon
	var hurt: Hurtbox=level.dummy_a.hurtbox
	weapon.equip(preload("res://data/weapons/ancient_sword.tres"))
	manager.stop_all();events.clear()
	weapon.start_combo()
	check(events.is_empty(),"Commit/windup does not emit a premature swing")
	weapon.cancel_combo();p._consume_swing()
	check(events.is_empty() and not p._swing_pending,"Cancelled windup remains silent")
	weapon.start_combo()
	# Unit boundary: feed the real committed snapshot to an accepted-result
	# observer at Active; native run separately verifies actual physics/input.
	weapon.phase=Weapon.Phase.ACTIVE
	var event: DamageEvent=damage(hurt,player);event.attack_id=weapon.snapshot.attack_id
	var result:=DamageResult.new();result.actual_damage=1
	p._on_hit(event,result,hurt)
	check(events.size()==2 and events[0].begins_with("SFX_sword_swing_") and last_is("melee_impact"),"Matching Active contact flushes swing before impact")
	p._consume_swing()
	check(events.size()==2,"Subsequent physics observation cannot repeat swing")
	events.clear()
	var target:=BaseEnemy.new();target.definition=preload("res://data/enemies/runic_champion.tres")
	var previous_actor: Node2D=hurt.actor_body;hurt.actor_body=target
	p._on_hit(event,result,hurt)
	check(events.size()==1 and last_is("armor_impact"),"Existing runic_champion ID selects authored armor contact timbre")
	hurt.actor_body=previous_actor;target.free()
	weapon.cancel_combo();manager.stop_all();events.clear()
	weapon.start_combo();weapon.phase=Weapon.Phase.ACTIVE
	event=damage(hurt,player);event.source_id=123;event.attack_id=weapon.snapshot.attack_id
	p._on_hit(event,result,hurt)
	check(events.size()==1 and p._swing_pending,"Other source cannot consume player's pending swing")
	weapon.cancel_combo();p._consume_swing();events.clear()
	event=damage(hurt,player);result=hurt.take_damage(event)
	check(not result.blocked and result.actual_damage>0 and events.size()==1,"Actual accepted resolver contact emits once")
	hurt.take_damage(event)
	check(events.size()==1,"Resolver replay emits no second contact")
	hurt.invulnerable=true;hurt.take_damage(damage(hurt,player));hurt.invulnerable=false
	check(events.size()==1,"Invulnerable result is silent")
	event=damage(hurt,player);event.source_kind=DamageEvent.SourceKind.DOT;hurt.take_internal_damage(event)
	check(events.size()==1,"DOT creates no hit sound")
	events.clear();event=damage(hurt,player);event.melee_hit=false;event.spell_id=&"fire_bolt";hurt.take_damage(event)
	check(events.size()==1 and last_is("spell_impact"),"Accepted primary spell uses impact rather than hurt")
	events.clear();event=damage(hurt,player);event.melee_hit=false;event.spell_id=&"combustion";event.source_kind=DamageEvent.SourceKind.RESONANCE
	hurt.take_damage(event)
	check(events.is_empty(),"Child damage retains resolver path without another transient")
	p._on_explosion(hurt.global_position,Color.ORANGE,&"fire")
	check(events.size()==1 and last_is("spell_impact"),"Burst has one main transient")
	events.clear();p._on_committed_spell_contact(Vector2.ZERO,Color.ORANGE,Vector2.RIGHT,&"fire_bolt",222,player.get_instance_id())
	check(events.size()==1 and last_is("spell_impact"),"World spell contact has its own impact")
	events.clear()
	var snapshot:=SpellSnapshot.new()
	snapshot.source_id=player.get_instance_id();snapshot.source_team_id=player.hurtbox.team_id;snapshot.root_id=CombatIds.next_id()
	snapshot.recipe_id=&"overload";snapshot.behavior_id=&"overload";snapshot.explosion_damage=1;snapshot.effect_radius=2000
	var nearby: Array[Hurtbox]=level.spell_executor.nearby_targets(hurt.global_position,snapshot.effect_radius,snapshot.source_team_id)
	check(nearby.size()>=2,"Explosion fixture has multiple real target hurtboxes")
	var old_hp: Dictionary={}
	for h: Hurtbox in nearby:old_hp[h.get_instance_id()]=h.health.current_health
	level.spell_executor.wall_hit(hurt.global_position,SpellContext.new(snapshot))
	var damaged: int=0
	for h: Hurtbox in nearby:
		if h.health.current_health<old_hp[h.get_instance_id()]:damaged+=1
	check(damaged>=2 and events.size()==2 and events.all(func(name: String)->bool:return name.begins_with("SFX_spell_impact_")),"Actual wall explosion damages multiple targets with one contact plus one burst, no N child onsets")
	events.clear();event=damage(player.hurtbox,player);event.source_id=123;event.source_team_id=2;event.melee_hit=false
	p._on_hit(event,result,player.hurtbox)
	check(events.size()==1 and last_is("hurt"),"Unknown physical/player damage keeps hurt fallback")
	events.clear();player.action_state_machine.transition_to(&"ready");p._on_spell(Vector2.ZERO)
	check(events.size()==1 and last_is("spell_explosion"),"Non-rune cast keeps existing ranged fallback")
	events.clear()
	player.resonance_controller.loadout_state.cooldowns_by_recipe_id.clear()
	player.action_state_machine.transition_to(&"cast_spell")
	var cast: PlayerCastState=player.action_state_machine.current_state as PlayerCastState
	check(cast!=null and cast.payload!=null,"Rune test enters real committed cast state")
	if cast!=null and cast.payload!=null:
		cast.physics_update(cast.payload.windup+.001)
		check(last_is("spell_cast"),"Committed rune release selects paper cast cue")
	player.action_state_machine.transition_to(&"ready")
	owner_node.queue_free();level.queue_free();current_scene=null
	for i: int in 8:await process_frame
	await manager.shutdown();node_added.disconnect(born)
	print("RESULT RecordedPairFocused checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
