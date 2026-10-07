class_name OpeningCultivationSession
extends Node
## Gameplay adapter; the profile owns progress/bank and NPC state owns life.
signal ui_changed
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
const Life = preload("res://scripts/cultivation/opening_npc_life_adapter.gd")
const STEP: float = 0.25
const MAX_PULSES: int = 8
var profile: SanctuaryProfile
var flow: Node
var scene: Node2D
var player: Player
var life: RefCounted
var initialized: bool = false
var error: String = ""
var training_actor: String = ""
var accumulator: float = 0.0
var observed_pulses: int = 0
var _busy: bool = false
var _seen_attacks: Dictionary = {}
var _herb: Marker2D
var _herb_id: String = ""
var _location_key: String = ""
var style_binding: Node

func initialize(permanent: SanctuaryProfile, owner_node: Node, seed_override: int = -1) -> bool:
	profile=permanent; flow=owner_node
	if profile.read_only:
		error="profile_quarantined"; return false
	if profile.cultivation_progress.is_empty():
		var seed_value: int = seed_override
		if seed_value<0:
			var rng := RandomNumberGenerator.new(); rng.randomize()
			seed_value=rng.randi_range(0,Model.LIMIT)
		var progress: Dictionary = Model.new_progress(seed_value)
		var tuning: Variant = SanctuaryProfile.CommitWriter.read_json("res://data/cultivation/opening_cultivation_config_v1.json")
		if not tuning is Dictionary:
			error="missing_tuning_config"; return false
		progress["config"]=tuning
		if not Model.valid(progress,profile.material_stash):
			error="invalid_tuning_or_bank"; return false
		if not profile.commit_cultivation(Model.initial_proposal(progress,profile.material_stash,profile.souls,profile.boss_proofs)):
			error=profile.last_commit.get("error","initialization_failed"); return false
	initialized=Model.valid(profile.cultivation_progress,profile.material_stash)
	if not initialized: error="invalid_cultivation"
	profile.changed.connect(_profile_changed)
	if initialized: _sync_insights()
	style_binding=preload("res://scripts/cultivation/opening_style_binding.gd").new()
	add_child(style_binding); style_binding.initialize(profile,flow)
	return initialized

func bind_scene(next_scene: Node2D) -> void:
	detach_scene(); scene=next_scene
	if not is_instance_valid(scene): return
	player=scene.get("player") as Player
	if is_instance_valid(player): player.equipped_weapon.hit_confirmed.connect(_confirmed_hit)
	if scene is ExteriorHub:
		var population: NpcPopulation = scene.npc_population
		if is_instance_valid(population):
			life=Life.new()
			if not life.configure(population.state,profile.save_path): life=null
	_refresh_herb()
	if style_binding!=null: style_binding.bind_scene(scene)

func detach_scene() -> void:
	if style_binding!=null: style_binding.detach_scene()
	stop_training()
	if is_instance_valid(player) and player.equipped_weapon.hit_confirmed.is_connected(_confirmed_hit): player.equipped_weapon.hit_confirmed.disconnect(_confirmed_hit)
	if is_instance_valid(_herb):
		_herb.get_parent().remove_child(_herb); _herb.queue_free()
	_herb=null; _herb_id=""; _location_key=""; scene=null; player=null; life=null
	_seen_attacks.clear()

func snapshot() -> Dictionary:
	var data: Dictionary = profile.cultivation_progress.duplicate(true) if profile!=null else {}
	data.merge({"ready":initialized and not profile.read_only,"error":error,"materials":profile.material_stash.duplicate() if profile!=null else {},"souls":profile.souls if profile!=null else 0,"proofs":profile.boss_proofs.duplicate() if profile!=null else {},"proposal_not_final":true,"training_actor":training_actor,"npc_eligible":life!=null and not life.capture(Model.NPC,false).is_empty()},true)
	return data

func _profile_changed() -> void:
	if not _busy: _sync_insights()
	_refresh_herb(); ui_changed.emit()

func _sync_insights() -> void:
	if not initialized or _busy or profile.read_only: return
	for insight: String in Model.OBSERVATIONS:
		if profile.opening_progress["completed"].has(insight) and not profile.cultivation_progress["actors"][Model.PLAYER]["insight_ids"].has(insight):
			var result: Dictionary = _commit("observe",{"insight_id":insight})
			if not result.get("ok",false): return

func _commit(kind: String, args: Dictionary, fence: Dictionary = {}) -> Dictionary:
	if _busy or not initialized or profile.read_only: return {"ok":false,"error":"profile_unavailable"}
	_busy=true
	var model_args: Dictionary = args.duplicate(true)
	var ability_choice: String = str(model_args.get("branch_id","")); model_args.erase("branch_id")
	var event_id: String = "cult_%d" % int(profile.cultivation_progress["next_event"])
	var proposal: Dictionary = Model.propose(profile.cultivation_progress,profile.material_stash,profile.souls,profile.boss_proofs,kind,model_args,event_id)
	var result: Dictionary = proposal
	if proposal.get("ok",false):
		var guard: Callable = Callable()
		if not fence.is_empty(): guard=life.matches.bind(fence) if life!=null else Callable()
		if not profile.commit_cultivation(proposal,fence,guard,ability_choice): result=profile.last_commit.duplicate(true)
	error=result.get("error","")
	# Keep ownership through publication: a UI listener cannot create another
	# fresh command while the first button's quote is still being published.
	ui_changed.emit(); _busy=false
	return result

func perform(kind: String, args: Dictionary) -> Dictionary:
	# UI never supplies clock/mastery/observation claims. Those trusted inputs
	# come from actual pulses and the existing damage/opening event owners.
	if kind not in ["enroll","breakthrough","craft_pill","consume"] or not scene is PrologueHub or not scene.station_open or scene.current_station!=&"training": return {"ok":false,"error":"training_station_required"}
	var actor: String = str(args.get("actor_id",Model.PLAYER))
	var fence: Dictionary = {}
	if kind=="enroll" and args.get("enabled",false) or actor==Model.NPC:
		if life==null: return {"ok":false,"error":"npc_life_owner_unavailable"}
		fence=life.capture(Model.NPC,false)
		if fence.is_empty(): return {"ok":false,"error":life.last_error}
	return _commit(kind,args,fence)

func start_training(actor_id: String) -> bool:
	if _busy: return false
	stop_training()
	if not initialized or profile.read_only or actor_id not in [Model.PLAYER,Model.NPC] or not profile.cultivation_progress["actors"].has(actor_id): return false
	if actor_id==Model.PLAYER:
		if not scene is PrologueHub or scene.inside_house or (scene is ExteriorHub and scene.outside) or scene.nearest_station()!=&"training": return false
	elif life==null or life.capture(Model.NPC,false).is_empty() or not profile.cultivation_progress["actors"][actor_id]["enrolled"]: return false
	training_actor=actor_id; ui_changed.emit(); return true

func stop_training() -> void:
	training_actor=""; accumulator=0.0; observed_pulses=0

func _playing(ignore_feedback: bool = false) -> bool:
	if not initialized or profile.read_only or _busy or not is_instance_valid(scene) or not is_instance_valid(player) or get_tree().paused or player.health.current_health<=0.0 or not player.controls_enabled or (player.hit_reaction!=null and player.hit_reaction.blocks_controls()): return false
	if flow!=null and (flow.get("return_save_pending")==true or flow.get("_return_busy")==true or flow.get("returning")==true): return false
	if not ignore_feedback and scene.get("feedback")!=null and scene.feedback.is_frozen(): return false
	if scene.get("gear")!=null and scene.gear.modal.is_open: return false
	if scene is PrologueHub and (scene.station_open or scene.dialogue.is_open): return false
	if scene is DungeonRun and (scene.outcome!=&"" or scene.has_pending_rewards()): return false
	return true

func _physics_process(delta: float) -> void:
	# A talk/death boundary must discard partial NPC practice even while the
	# global modal guard freezes gameplay, before talk returns to rest.
	if training_actor==Model.NPC and (life==null or life.capture(Model.NPC).is_empty()):
		accumulator=0.0; observed_pulses=0; return
	if not _playing(): accumulator=0.0; return
	_refresh_herb()
	if training_actor.is_empty(): return
	if training_actor==Model.PLAYER and (not scene is PrologueHub or scene.inside_house or (scene is ExteriorHub and scene.outside) or scene.nearest_station()!=&"training"):
		stop_training(); ui_changed.emit(); return
	if training_actor==Model.NPC and (life==null or life.capture(Model.NPC).is_empty()):
		# Clear partial elapsed time at every ineligible life boundary.
		accumulator=0.0; observed_pulses=0; return
	accumulator=minf(accumulator+maxf(0.0,delta),STEP*MAX_PULSES)
	var pulses: int = 0
	while accumulator+0.0000001>=STEP and pulses<MAX_PULSES:
		accumulator-=STEP; pulses+=1; observed_pulses+=1
		if observed_pulses==8:
			observed_pulses=0
			var actor: Dictionary = profile.cultivation_progress["actors"][training_actor]
			var target: int = maxi(int(profile.cultivation_progress["gameplay_tick"]),int(actor["last_train_tick"]))+8
			var fence: Dictionary = life.capture(Model.NPC) if training_actor==Model.NPC else {}
			if training_actor==Model.NPC and fence.is_empty():
				accumulator=0.0; observed_pulses=0; error="npc_life_changed"; return
			var result: Dictionary = _commit("train",{"actor_id":training_actor,"sessions":1,"target_tick":target},fence)
			if not result.get("ok",false): stop_training(); return

func _confirmed_hit(event: DamageEvent, result: DamageResult) -> void:
	# The same confirmed hit may already have started feedback hitstop via the
	# earlier listener. It remains a real resolved hit, while training stays frozen.
	if not _playing(true) or event.source_kind!=DamageEvent.SourceKind.DIRECT or not event.melee_hit or event.source_id!=player.get_instance_id() or event.target_id==event.source_id or result.blocked or result.actual_damage<=0.0: return
	var target: Node = instance_from_id(event.target_id) as Node
	if not is_instance_valid(target) or target is NpcPilotActor or target is HubNpc or (not target is TrainingDummy and not target.is_in_group(&"enemies")): return
	var key: String = "%d:%d:%d" % [event.source_id,event.attack_id,event.root_event_id]
	if _seen_attacks.has(key): return
	_seen_attacks[key]=true
	# RAM duplicate suppression is session-scoped; persisted commands carry
	# monotonic receipts. No instance ID is persisted as actor identity.
	if _seen_attacks.size()>256: _seen_attacks.erase(_seen_attacks.keys()[0])
	_commit("mastery",{})

func _refresh_herb() -> void:
	if not initialized or not is_instance_valid(scene): return
	var node_id: String = ""
	var parent_node: Node2D
	var point: Vector2
	if scene is ExteriorHub and scene.outside:
		if is_instance_valid(scene.exterior) and scene.exterior.room_id==&"o01_p04" and scene.exterior.route_id==ExteriorRouteCatalog.MAIN:
			node_id="o01_p04_01"; parent_node=scene.exterior
			point=Vector2(1030,scene.exterior.floor_y(1030))
	elif scene is PrologueHub and not scene.inside_house:
		node_id="h00_courtyard_01"; parent_node=scene.yard; point=Vector2(370,640)
	var key: String = node_id+":"+str(parent_node.get_instance_id() if is_instance_valid(parent_node) else 0)
	var available: bool = not node_id.is_empty() and Model.node_available(profile.cultivation_progress,node_id) and not profile.cultivation_progress["harvested_nodes"].has(node_id)
	if _location_key==key and is_instance_valid(_herb) and available: return
	if is_instance_valid(_herb): _herb.get_parent().remove_child(_herb); _herb.queue_free()
	_herb=null; _herb_id=""; _location_key=key
	if not available: return
	_herb=Marker2D.new(); _herb.name="SeededAptitudeHerb"; _herb.position=point
	parent_node.add_child(_herb); _herb_id=node_id
	var visual := Polygon2D.new()
	visual.polygon=PackedVector2Array([Vector2(-10,-4),Vector2(-17,-15),Vector2(-3,-13),Vector2(0,-26),Vector2(4,-13),Vector2(17,-19),Vector2(11,-4)])
	visual.color=Color("91c98c"); _herb.add_child(visual)
	var label := Label.new(); label.text="Dược thảo dưỡng căn · E"; label.position=Vector2(-85,-52)
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; label.set_meta(&"debug_keep",true); _herb.add_child(label)

func herb_near(range_value: float) -> bool:
	return _playing() and is_instance_valid(_herb) and player.global_position.distance_to(_herb.global_position)<range_value

func harvest_near() -> bool:
	if not herb_near(85.0): return false
	var result: Dictionary = _commit("harvest",{"node_id":_herb_id})
	if result.get("ok",false): _refresh_herb()
	return result.get("ok",false)

func _exit_tree() -> void:
	detach_scene()
	if profile!=null and profile.changed.is_connected(_profile_changed): profile.changed.disconnect(_profile_changed)
