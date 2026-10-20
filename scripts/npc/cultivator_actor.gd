class_name CultivatorActor
extends NpcPilotActor
## Local combat subclass. Registry owns HP/memory/patrol/recovery; no new writer.
var player: Player
var combat_phase: String = "idle"
var phase_remaining: float = 0.0
var aggro_remaining: float = 0.0
var reason: String = "Trung lập"
## Local causal attribution only; never copied into the NPC/profile save.
var response_owner_id: String = ""
## Event-local target only. Player grievance remains owned by the existing
## response path and always takes priority over this transient encounter.
var living_enemy: SlimeEnemy
## Keeps an expired event target distinct from an ordinary Player grievance.
var _defending_living: bool = false
var witness_provider: Callable
var report_hint: String=""
var living_hint: String=""
var greeting_hint: String=""
var strike_hitbox: Hitbox
var accepted_strikes: int = 0
var committed_strikes: int = 0
var _combat_spec: Dictionary = {}
var _simulation_enabled: bool = false
var _engagement_x: float = 0.0
var _strike: AttackSnapshot
var _cultivator_resolver: CultivatorResolver
var _rest_reason_remaining: float = 0.0
var cooldown_remaining: float = 0.0
var _strike_center: Vector2
var _strike_window: int = 0
var _moving_shape := CapsuleShape2D.new()
var _spawn_synced: bool = false
var _one_way_solids: Array[RID] = []
var new_sprite: TanDangSpriteArt
## Cosmetic history only: recovery must never imply an impact for a cancelled tell.
var _visual_window_opened: bool = false
var _visual_hit_window: int = 0
var _visual_direction := Vector2.RIGHT

func bind_road_idle_art() -> void:
	# Each stable identity owns one full-body idle image; combat clocks stay physical.
	set_approved_portrait(CultivatorCatalog.portrait(stable_id))

func _ready() -> void:
	_combat_spec = CultivatorCatalog.definition(stable_id)
	super._ready()
	if stable_id in TanDangSpriteArt.IDS:
		new_sprite = TanDangSpriteArt.new()
		if body == null:
			body = Sprite2D.new()
			body.name = "TanDangAtlasSprite"
			add_child(body)
		if not new_sprite.configure(self,body,stable_id): body.visible = false
	health.maximum_health = NpcPilotCatalog.maximum_health(stable_id)
	health.current_health = float(world_state.records[stable_id]["hp"])
	health.minimum_health = world_state.damage_health_floor(stable_id)
	_moving_shape.radius = 8.0
	_moving_shape.height = 40.0
	_collect_one_way_solids()
	var previous_resolver: DamageResolver = hurtbox.damage_resolver
	_cultivator_resolver = CultivatorResolver.new()
	_cultivator_resolver.health = health
	_cultivator_resolver.world_state = world_state
	_cultivator_resolver.stable_id = stable_id
	_cultivator_resolver.player = player
	_cultivator_resolver.origin_offset_x = room.global_position.x
	_cultivator_resolver.witness_provider=witness_provider
	add_child(_cultivator_resolver)
	hurtbox.damage_resolver = _cultivator_resolver
	previous_resolver.queue_free()
	hurtbox.hit_resolved.connect(_accepted_hit)
	strike_hitbox = ActorCombatRig.hitbox(self,8)
	strike_hitbox.name = "SelfDefenseHitbox"
	strike_hitbox.contact_detected.connect(_strike_contact)
	_layout_caption()
	if body != null: body.modulate = Color.WHITE
	_sync_new_sprite(0.0)
	_refresh_caption()

func sync_record(emit_cues: bool = true, interpolation_time: float = 0.0, frame_delta: float = 0.0) -> void:
	_simulation_enabled = emit_cues
	if not emit_cues and combat_phase in ["tell","active"]: _set_phase("recover",float(_combat_spec["recover"]))
	var prior_position: Vector2 = position
	if combat_phase == "idle":
		super.sync_record(emit_cues,interpolation_time,frame_delta)
	else:
		# Local physics writes the bounded record; inherited schedule cannot move it.
		super.sync_record(false)
	# The registry's 4Hz position is a desired sample, never a teleport through a
	# solid. Initial room placement is trusted authored data; subsequent motion
	# sweeps the same small body envelope used by local combat.
	if _spawn_synced and is_inside_tree() and prior_position != position:
		var desired_position: Vector2 = position
		position = _safe_position(prior_position,desired_position)
		if combat_phase == "idle" and not position.is_equal_approx(desired_position) and world_state.set_local_control(stable_id,true):
			world_state.update_local_position(stable_id,position.x)
			world_state.set_local_control(stable_id,false)
	_spawn_synced = true
	if caption != null:
		_layout_caption()
		_refresh_caption()
	if new_sprite != null and new_sprite.available:
		_sync_new_sprite(frame_delta)
	elif body != null:
		EnemySpriteArt.set_facing(body,alpha_geometry.get("foot_pixel",Vector2.ZERO),_facing < 0.0)
		body.rotation = _facing * (-0.09 if combat_phase == "tell" else 0.13 if combat_phase == "active" else 0.0)
	queue_redraw()

func _sync_new_sprite(frame_delta: float) -> void:
	if new_sprite == null or not new_sprite.available or world_state == null or not world_state.records.has(stable_id): return
	var playing: bool = _simulation_enabled and is_instance_valid(player) and player.controls_enabled and not get_tree().paused
	if is_instance_valid(player) and is_instance_valid(player.combat_feedback) and player.combat_feedback.is_frozen(): playing = false
	new_sprite.sync(self,combat_phase,phase_remaining,_combat_spec,str(world_state.records[stable_id]["mode"]),playing,frame_delta,_facing,_strike_window)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(strike_hitbox): return
	if world_state == null or world_state.read_only or world_state.get("compound_locked") == true or not world_state.records.has(stable_id):
		_set_phase("idle")
		aggro_remaining = 0.0
		_defending_living = false
		living_enemy = null
		strike_hitbox.collision_mask = 8
		if world_state != null: world_state.set_local_control(stable_id,false)
		return
	var mode: String = world_state.records[stable_id]["mode"]
	if stable_id in NpcPilotCatalog.TAN_DANG_IDS and not response_owner_id.is_empty() and world_state.karma(response_owner_id).get("grievance","")=="":
		_stop_defense("Đã đình chiến · Giữ bản ghi cũ")
		return
	if mode in ["downed","recovering","dead","talk"]:
		_stop_defense("Đã rút về dưỡng thương" if mode == "recovering" else "Đã ngừng đánh")
		return
	if not _simulation_enabled or not is_instance_valid(player) or not player.controls_enabled or get_tree().paused:
		if combat_phase in ["tell","active"]: _set_phase("recover",float(_combat_spec["recover"]))
		return
	if is_instance_valid(player.combat_feedback) and player.combat_feedback.is_frozen(): return
	var step: float = minf(delta,0.1)
	cooldown_remaining = maxf(0.0,cooldown_remaining-step)
	_rest_reason_remaining = maxf(0.0,_rest_reason_remaining-step)
	if combat_phase == "idle": return
	if not _target_in_leash():
		_stop_defense("Yêu thú ngoài tầm · Giữ đường về" if _defending_living else "Đã ngừng truy đuổi · Bạn đã rời đoạn đường")
		return
	aggro_remaining = maxf(0.0,aggro_remaining-step)
	if aggro_remaining <= 0.0:
		_stop_defense("Đã ngừng đánh · Giữ khoảng cách")
		return
	phase_remaining = maxf(0.0,phase_remaining-step)
	match combat_phase:
		"approach":
			_position_for_strike(step)
		"tell":
			if phase_remaining <= 0.0: _open_strike()
		"active":
			if _combat_spec["pattern"] == "lunge" and _strike != null:
				_move_local(_strike.attack_direction.x*float(_combat_spec["lunge_speed"])*step)
			strike_hitbox.sample_contacts()
			if phase_remaining <= 0.0:
				if _combat_spec["pattern"] == "double_cut" and _strike_window == 1:
					_strike_window = 2
					_set_phase("tell",float(_combat_spec["followup_tell"]),false)
				else: _set_phase("recover",float(_combat_spec["recover"]))
		"recover", "hurt":
			if phase_remaining <= 0.0: _set_phase("approach")
	_refresh_caption()
	queue_redraw()

func _target_in_leash() -> bool:
	return _target_in_leash_from(_engagement_x)

func _target_in_leash_from(engagement_x: float) -> bool:
	var target_actor: Node2D = _combat_target()
	if not is_instance_valid(target_actor) or not target_actor.is_inside_tree() or not is_instance_valid(room) or room.route_id != ExteriorRouteCatalog.MAIN: return false
	if living_enemy != null and (not is_instance_valid(living_enemy) or living_enemy.get_parent() != room or living_enemy.health.current_health <= 0.0): return false
	var spec: Dictionary = NpcPilotCatalog.definition(stable_id)
	var limits: Vector2 = TanDangLivingCatalog.bounds(stable_id,str(world_state.records[stable_id]["room"])) if stable_id in NpcPilotCatalog.TAN_DANG_IDS else Vector2(float(spec["left"]),float(spec["right"]))
	var target_x: float = target_actor.global_position.x-room.global_position.x
	return target_x >= limits.x-40.0 and target_x <= limits.y+40.0 and absf(target_x-engagement_x) <= float(_combat_spec["leash"]) and absf(target_actor.global_position.y-global_position.y) <= 130.0

func _combat_target() -> Node2D:
	if _defending_living: return living_enemy if is_instance_valid(living_enemy) else null
	return player

func _position_for_strike(delta: float) -> void:
	var target_actor: Node2D = _combat_target()
	if not is_instance_valid(target_actor): return
	var difference: Vector2 = target_actor.global_position-global_position
	if absf(difference.x) > 0.1: _facing = signf(difference.x)
	var spacing: float = float(_combat_spec["spacing"])
	var move_direction: float = 0.0
	if absf(difference.x) > spacing+8.0: move_direction = _facing
	elif absf(difference.x) < spacing-8.0: move_direction = -_facing
	if move_direction != 0.0:
		_move_local(move_direction*float(_combat_spec["speed"])*delta)
	if cooldown_remaining <= 0.0 and absf(target_actor.global_position.x-global_position.x) <= float(_combat_spec["reach"])-8.0 and absf(difference.y) <= 44.0 and _clear_line(global_position+Vector2(0,-26),target_actor.global_position+Vector2(0,-26)):
		_commit_strike()

func _safe_position(origin: Vector2, desired: Vector2) -> Vector2:
	if origin.is_equal_approx(desired): return origin
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _moving_shape
	query.transform = Transform2D(0,room.to_global(origin+Vector2(0,-30)))
	query.motion = desired-origin
	query.collision_mask = 1
	query.collide_with_areas = false
	query.exclude = _one_way_solids
	query.margin = 0.5
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	# cast_motion ignores existing overlap; reject it explicitly rather than
	# allowing a body already pressed against a wall to jump to its far side.
	if not space.intersect_shape(query,1).is_empty(): return origin
	var fractions: PackedFloat32Array = space.cast_motion(query)
	var safe_fraction: float = fractions[0] if fractions.size() == 2 else 0.0
	var result: Vector2 = origin.lerp(desired,clampf(safe_fraction,0.0,1.0))
	result.y = room.floor_y(result.x)
	return result

func _collect_one_way_solids() -> void:
	# This grounded controller follows the main heightfield, never jumps onto
	# optional shelves. Shape queries lack CharacterBody's one-way filtering;
	# ignore only bodies whose entire enabled geometry is explicitly one-way.
	_one_way_solids.clear()
	for candidate: Node in room.find_children("*","StaticBody2D",true,false):
		var solid: StaticBody2D = candidate as StaticBody2D
		var found: bool = false
		var only_one_way: bool = true
		for child: Node in solid.get_children():
			if child is CollisionShape2D or child is CollisionPolygon2D:
				if child.get("disabled") == true: continue
				found = true
				if child.get("one_way_collision") != true: only_one_way = false
		if found and only_one_way: _one_way_solids.append(solid.get_rid())

func _move_local(distance: float) -> void:
	var bounds: Dictionary = NpcPilotCatalog.definition(stable_id)
	var limits: Vector2 = TanDangLivingCatalog.bounds(stable_id,str(world_state.records[stable_id]["room"])) if stable_id in NpcPilotCatalog.TAN_DANG_IDS else Vector2(float(bounds["left"]),float(bounds["right"]))
	var desired_x: float = clampf(position.x+distance,limits.x,limits.y)
	var desired := Vector2(desired_x,room.floor_y(desired_x))
	var next: Vector2 = _safe_position(position,desired)
	if not world_state.update_local_position(stable_id,next.x): return
	_motion_distance += position.distance_to(next)
	position = next

func _clear_line(origin: Vector2, target: Vector2) -> bool:
	var query := PhysicsRayQueryParameters2D.create(origin,target,1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _commit_strike() -> void:
	var target_actor: Node2D = _combat_target()
	if cooldown_remaining > 0.0 or not is_instance_valid(target_actor): return
	_strike = AttackSnapshot.new()
	_strike.source_id = get_instance_id()
	_strike.source_team_id = hurtbox.team_id
	_strike.attack_id = CombatIds.next_id()
	_strike.root_event_id = _strike.attack_id
	_strike.base_damage = float(_combat_spec["damage"])
	_strike.attack_origin = global_position+Vector2(0,-26)
	_strike.aim_position = target_actor.global_position+Vector2(0,-26)
	_strike.attack_direction = (_strike.aim_position-_strike.attack_origin).normalized()
	if _strike.attack_direction.is_zero_approx(): _strike.attack_direction = Vector2(_facing,0)
	_strike_center = _strike.aim_position
	_strike_window = 1
	cooldown_remaining = float(_combat_spec["cooldown"])
	committed_strikes += 1
	_set_phase("tell",float(_combat_spec["tell"]),false)

func _open_strike() -> void:
	if _strike == null: return
	# Each contact window is a separate immutable delivery under the same root.
	# A cancelled first cut can never silently reopen its follow-up.
	var window := AttackSnapshot.new()
	window.source_id = _strike.source_id
	window.source_team_id = _strike.source_team_id
	window.attack_id = _strike.attack_id
	window.root_event_id = _strike.root_event_id
	window.hit_window_id = _strike_window
	window.base_damage = _strike.base_damage
	window.attack_origin = _strike.attack_origin
	window.aim_position = _strike.aim_position
	window.attack_direction = _strike.attack_direction
	var shape: Shape2D
	var offset: Vector2
	if _combat_spec["pattern"] == "seal":
		var circle := CircleShape2D.new()
		circle.radius = float(_combat_spec["radius"])
		shape = circle
		offset = to_local(_strike_center)
	else:
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(float(_combat_spec["reach"]),float(_combat_spec["height"]))
		shape = rectangle
		offset = Vector2(0,-26)+_strike.attack_direction*float(_combat_spec["reach"])*0.5
	strike_hitbox.rotation = _strike.attack_direction.angle()
	strike_hitbox.activate(window,shape,offset)
	_visual_window_opened = true
	_visual_hit_window = _strike_window
	_visual_direction = window.attack_direction
	combat_phase = "active"
	phase_remaining = float(_combat_spec["active"])
	strike_hitbox.sample_contacts()

func _strike_contact(target: Hurtbox, snapshot: AttackSnapshot) -> void:
	if world_state == null or world_state.read_only or world_state.get("compound_locked") == true or not world_state.records.has(stable_id) or world_state.records[stable_id]["mode"] in ["talk","downed","recovering","dead"]: return
	var target_actor: Node2D = _combat_target()
	if combat_phase != "active" or not _simulation_enabled or get_tree().paused or not is_instance_valid(player) or not player.controls_enabled or not is_instance_valid(target_actor) or target != target_actor.get("hurtbox") or not _target_in_leash(): return
	# A query rectangle is only the broad phase. Existing world solids block reach.
	if not _clear_line(global_position+Vector2(0,-26),target_actor.global_position+Vector2(0,-26)): return
	if _combat_spec["pattern"] == "seal" and not _clear_line(snapshot.attack_origin,_strike_center): return
	var event := DamageEvent.new()
	event.source_id = snapshot.source_id
	event.source_team_id = snapshot.source_team_id
	event.target_id = target.get_actor_id()
	event.attack_id = snapshot.attack_id
	event.root_event_id = snapshot.root_event_id
	event.hit_window_id = snapshot.hit_window_id
	event.base_damage = snapshot.base_damage
	event.attack_direction = snapshot.attack_direction
	event.attack_origin = snapshot.attack_origin
	event.aim_position = snapshot.aim_position
	event.physical_damage = _combat_spec["pattern"] != "seal"
	event.melee_hit = _combat_spec["pattern"] != "seal"
	event.heavy_hit = _combat_spec["pattern"] in ["cleave","lunge"]
	event.hit_reaction = &"flinch"
	var result: DamageResult = target.take_damage(event)
	if result.actual_damage > 0.0: accepted_strikes += 1

func _accepted_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0.0: return
	if world_state.records[stable_id]["mode"] in ["downed","recovering","dead"]:
		_stop_defense("Trọng thương · Rút về dưỡng thương" if world_state.records[stable_id]["mode"] == "recovering" else "Trọng thương · Đã dừng đánh")
		return
	# Every real injury cancels a committed strike; only the actual player provokes.
	if not _cultivator_resolver.is_player_cause(event):
		if combat_phase != "idle": _set_phase("hurt",float(_combat_spec["hurt"]))
		return
	if combat_phase == "idle": _engagement_x = position.x
	if _defending_living:
		_defending_living = false
		living_enemy = null
		strike_hitbox.collision_mask = 8
	world_state.set_local_control(stable_id,true)
	aggro_remaining = float(_combat_spec["aggro"])
	response_owner_id = stable_id
	reason = "Tự vệ · Bạn vừa gây thương tích"
	_set_phase("hurt",float(_combat_spec["hurt"]))
	_refresh_caption()

func can_request_living_defense(enemy: SlimeEnemy) -> bool:
	if stable_id not in NpcPilotCatalog.TAN_DANG_IDS or not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion() or enemy.health.current_health <= 0.0: return false
	if not is_inside_tree() or _combat_spec.is_empty() or world_state == null or world_state.read_only or world_state.compound_locked or combat_phase != "idle" or not _simulation_enabled: return false
	if not is_instance_valid(player) or not player.controls_enabled or get_tree().paused or enemy.get_parent() != room: return false
	if world_state.records[stable_id]["mode"] in ["talk","dead","downed","recovering"]: return false
	if not world_state.karma(stable_id).get("grievance","").is_empty(): return false
	var local_x: float = enemy.global_position.x-room.global_position.x
	var limits: Vector2 = TanDangLivingCatalog.bounds(stable_id,str(world_state.records[stable_id]["room"]))
	return local_x >= limits.x-40.0 and local_x <= limits.y+40.0 and absf(local_x-position.x) <= float(_combat_spec["leash"]) and absf(enemy.global_position.y-global_position.y) <= 130.0 and _clear_line(global_position+Vector2(0,-26),enemy.global_position+Vector2(0,-26))

func request_living_defense(enemy: SlimeEnemy) -> bool:
	if not can_request_living_defense(enemy) or not world_state.set_local_control(stable_id,true): return false
	living_enemy = enemy
	_defending_living = true
	strike_hitbox.collision_mask = 16
	_engagement_x = position.x
	aggro_remaining = 12.0
	reason = "Bảo vệ người bên đường"
	_set_phase("approach")
	_refresh_caption()
	return true

func stop_living_defense() -> void:
	if not _defending_living: return
	_stop_defense("Đã dừng chống đỡ yêu thú")

## Explicit local retaliation from an already-persisted grievance. The life/
## relationship owner decides whether it is eligible; this method never saves,
## spawns an actor, clears a grievance, or renews the timer on its own.
func can_request_retaliation(reason_code: String = "", grievance_owner: String = "") -> bool:
	if not is_inside_tree() or _combat_spec.is_empty(): return false
	if stable_id not in NpcPilotCatalog.CULTIVATOR_IDS: return false
	if world_state == null or world_state.read_only or world_state.get("compound_locked") == true or not world_state.records.has(stable_id) or combat_phase != "idle" or not _simulation_enabled or not is_instance_valid(player) or not player.controls_enabled: return false
	if get_tree().paused: return false
	if world_state.records[stable_id]["mode"] in ["talk","dead","downed","recovering"]: return false
	if _persisted_retaliation_reason(reason_code,grievance_owner).is_empty(): return false
	# Eligibility uses a prospective engagement origin, without changing clocks,
	# local-control ownership, position, grievance, or any durable receipt.
	return _target_in_leash_from(position.x)

func request_retaliation(reason_code: String = "", grievance_owner: String = "") -> bool:
	if not can_request_retaliation(reason_code,grievance_owner): return false
	if not world_state.set_local_control(stable_id,true): return false
	_engagement_x = position.x
	aggro_remaining = float(_combat_spec["aggro"])
	response_owner_id = stable_id if grievance_owner.is_empty() else grievance_owner
	reason = _persisted_retaliation_reason(reason_code,grievance_owner)
	_set_phase("approach")
	_refresh_caption()
	return true

func is_responding_to(grievance_owner: String) -> bool:
	if grievance_owner.is_empty() or response_owner_id != grievance_owner or aggro_remaining <= 0.0: return false
	if not is_inside_tree() or combat_phase not in ["approach","tell","active","recover","hurt"]: return false
	if world_state == null or world_state.read_only or world_state.get("compound_locked") == true or not world_state.records.has(stable_id): return false
	return world_state.records[stable_id]["mode"] not in ["talk","dead","downed","recovering"]

func _persisted_retaliation_reason(reason_code: String = "", grievance_owner: String = "") -> String:
	if not world_state.has_method("karma"): return ""
	var owner_id: String = stable_id if grievance_owner.is_empty() else grievance_owner
	if owner_id != stable_id and (stable_id not in CultivatorCatalog.TAN_DANG_IDS or owner_id not in CultivatorCatalog.TAN_DANG_IDS): return ""
	if not world_state.records.has(owner_id): return ""
	var relation: Variant = world_state.call("karma",owner_id)
	if not relation is Dictionary: return ""
	var grievance: Variant = relation.get("grievance","")
	if not grievance is String or grievance.is_empty(): return ""
	if not reason_code.is_empty() and reason_code != grievance: return ""
	var same_person: bool = owner_id == stable_id
	if not same_person and not TanDangCausality.knows(world_state.records,owner_id,grievance,stable_id):return ""
	if grievance == "attacked": return "Trả đũa · Còn ghi việc bị tấn công" if same_person else "Trả đũa · Đồng môn bị tấn công"
	if grievance == "player_murder": return "Trả đũa · Còn ghi việc sát hại" if same_person else "Trả đũa · Đồng môn bị sát hại"
	return ""

func _set_phase(phase: String, seconds: float = 0.0, cancel_snapshot: bool = true) -> void:
	if phase == "recover":
		_visual_window_opened = _visual_window_opened and combat_phase == "active"
	else:
		_visual_window_opened = false
	if is_instance_valid(strike_hitbox): strike_hitbox.deactivate()
	if cancel_snapshot:
		_strike = null
		_strike_window = 0
	combat_phase = phase
	phase_remaining = seconds
	if phase == "idle": response_owner_id = ""

func _stop_defense(message: String) -> void:
	response_owner_id = ""
	living_enemy = null
	_defending_living = false
	if is_instance_valid(strike_hitbox): strike_hitbox.collision_mask = 8
	if combat_phase == "idle": return
	_set_phase("idle")
	aggro_remaining = 0.0
	reason = message
	_rest_reason_remaining = 3.0
	world_state.set_local_control(stable_id,false)
	_refresh_caption()

func _refresh_caption() -> void:
	if caption == null or _combat_spec.is_empty(): return
	var activity: String = str(_combat_spec["style"])
	var mode: String = str(world_state.records[stable_id]["mode"])
	if mode == "downed":
		activity = "Trọng thương · Chờ quyết định"
	elif mode == "dead":
		activity = "Đã qua đời"
	elif mode == "recovering":
		activity = "Đã rút về dưỡng thương"
	elif combat_phase != "idle":
		var phases: Dictionary = {"hurt":"Đang chịu đòn", "approach":"Giữ cự ly", "tell":"Sắp ra đòn", "active":"Ra đòn", "recover":"Thu chiêu"}
		activity = "%s · %s" % [reason,phases.get(combat_phase,combat_phase)]
		if combat_phase in ["tell","active"]: activity = "%s · %s%s" % [_combat_spec["skill"],phases[combat_phase]," %d/2" % _strike_window if _combat_spec["pattern"] == "double_cut" else ""]
	elif _rest_reason_remaining > 0.0:
		activity = reason
	elif not greeting_hint.is_empty():activity=greeting_hint
	elif not report_hint.is_empty():activity=report_hint
	elif not living_hint.is_empty():activity=living_hint
	else:
		if stable_id in NpcPilotCatalog.TAN_DANG_IDS:
			activity = NpcPilotCatalog.activity_label(stable_id,world_state.records[stable_id])
			if stable_id == TanDangLivingCatalog.LAM:
				var living: Dictionary = world_state.living_view(stable_id)
				var event_phase: String = str(living.get("event_phase","none"))
				match event_phase:
					"outbound": activity = "Đi tìm mảnh phù ở P01"
					"collecting": activity = "Tìm mảnh phù · Đá kê đèn"
					"danger": activity = "Cảnh giác trước yêu thú"
					"returning": activity = "Trở về kể chuyện vật liệu"
				if bool(living.get("convalescing",false)): activity = "Dưỡng thương sau chuyến tìm vật liệu"
		else: activity = "Trung lập · " + activity
	caption.text = "%s · %s\n%s" % [NpcPilotCatalog.definition(stable_id)["name"],_combat_spec["stage_label"],activity]

func _layout_caption() -> void:
	if stable_id in TanDangSpriteArt.IDS: caption.z_index = 3
	# These residents stand forty pixels apart. Separate only their text boxes;
	# canonical positions, interaction radii and physical footprints stay owned
	# by the NPC catalog and the room.
	if stable_id == "tan_dang_lam_tuoc":
		caption.position = Vector2(-220,-158).rotated(-rotation)
		caption.size = Vector2(220,72)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif stable_id == "tan_dang_du_hanh":
		caption.position = Vector2(0,-108).rotated(-rotation)
		caption.size = Vector2(220,72)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif stable_id == "tan_dang_moc_yen":
		caption.position = Vector2(-120,-170).rotated(-rotation)
		caption.size = Vector2(240,72)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		caption.position.x = -160.0
		caption.size.x = 320.0

func _draw() -> void:
	if new_sprite != null and new_sprite.available:
		draw_set_transform(Vector2.ZERO,-rotation,Vector2(1,0.25))
		draw_circle(Vector2.ZERO,15,Color(0.02,0.02,0.02,0.35))
		draw_set_transform(Vector2.ZERO)
	elif stable_id == "tan_dang_moc_yen":
		TanDangSealArt.draw_keeper(self,combat_phase,TanDangSealArt.progress(combat_phase,phase_remaining,_combat_spec),_facing)
	else:
		super._draw()
	if stable_id in NpcPilotCatalog.TAN_DANG_IDS and combat_phase == "idle" and world_state != null and world_state.records.has(stable_id) and world_state.records[stable_id]["mode"] == "work" and _simulation_enabled:
		# A small hand-held task prop, visible only while actually working at a
		# stop. It has no collision, damage, clock or reward effect.
		var point := Vector2(_facing*21.0,-34.0+sin(_pose_clock*3.0)*1.5)
		var tint := Color("e7c68a") if stable_id == TanDangLivingCatalog.MOC else Color("a3d8b7") if stable_id == TanDangLivingCatalog.LAM else Color("c3b4df")
		draw_line(Vector2(_facing*9.0,-33.0),point,tint,2.0)
		draw_rect(Rect2(point+Vector2(-6,-5),Vector2(12,9)),Color(tint,0.28),true)
		draw_rect(Rect2(point+Vector2(-6,-5),Vector2(12,9)),tint,false,1.0)
	if _combat_spec.is_empty() or combat_phase == "idle": return
	var tint: Color = _combat_spec["tint"]
	var direction: Vector2 = _strike.attack_direction if _strike != null else Vector2(_facing,0)
	var center := Vector2(0,-26)
	if stable_id in TanDangSpriteArt.IDS:
		if not _presentation_effect_allowed(): return
		if combat_phase == "recover" and not _visual_window_opened: return
		if combat_phase == "active" and (not is_instance_valid(strike_hitbox) or not strike_hitbox.active): return
		var visual_window: int = _visual_hit_window if combat_phase == "recover" else _strike_window
		var fraction: float = TanDangSealArt.progress(combat_phase,phase_remaining,_combat_spec,visual_window)
		if combat_phase == "recover": direction = _visual_direction
		if stable_id == "tan_dang_moc_yen" and combat_phase in ["tell","active","recover"]:
			TanDangSealArt.draw_seal(self,to_local(_strike_center),float(_combat_spec["radius"]),combat_phase,fraction,_facing)
			return
		if stable_id in ["tan_dang_lam_tuoc","tan_dang_du_hanh"] and combat_phase in ["tell","active","recover"]:
			var displacement: Vector2 = new_sprite.actual_displacement if new_sprite != null and not new_sprite.teleport_discarded else Vector2.ZERO
			TanDangCombatArt.draw_weapon(self,str(_combat_spec["pattern"]),combat_phase,fraction,direction,float(_combat_spec["reach"]),float(_combat_spec["height"]),visual_window,tint,displacement)
			return
	if combat_phase == "tell":
		if _combat_spec["pattern"] == "seal":
			var target: Vector2 = to_local(_strike_center)
			draw_line(center,target,Color(tint,0.35),1.0)
			draw_arc(target,float(_combat_spec["radius"]),0,TAU,24,Color(tint,0.8),2.0)
			draw_line(target-Vector2(8,0),target+Vector2(8,0),Color(tint,0.8),2.0)
		else:
			draw_line(center,center+direction*float(_combat_spec["reach"]),Color(tint,0.75),2.0)
			var spread: float = 0.65 if _combat_spec["pattern"] == "cleave" else 0.3
			draw_arc(center,float(_combat_spec["reach"]),direction.angle()-spread,direction.angle()+spread,12,Color(tint,0.7),2.0)
			if _combat_spec["pattern"] == "double_cut": draw_circle(center+Vector2(-8*_facing,-12),3.0*_strike_window,Color(tint,0.8))
	elif combat_phase == "active":
		if _combat_spec["pattern"] == "seal": draw_circle(to_local(_strike_center),float(_combat_spec["radius"]),Color(tint,0.24))
		else: draw_line(center,center+direction*float(_combat_spec["reach"]),Color(tint,0.95),5.0)
	elif combat_phase == "hurt":
		draw_arc(center,30.0,0,TAU,24,Color(1.0,0.45,0.3,0.5),2.0)

func _presentation_effect_allowed() -> bool:
	if not _simulation_enabled or not is_instance_valid(player) or not player.controls_enabled or get_tree().paused: return false
	if world_state == null or world_state.read_only or world_state.get("compound_locked") == true or not world_state.records.has(stable_id): return false
	return world_state.records[stable_id]["mode"] not in ["talk","downed","recovering","dead"]

func _exit_tree() -> void:
	if is_instance_valid(strike_hitbox): strike_hitbox.deactivate()
	_strike = null
	response_owner_id = ""
	if world_state != null: world_state.set_local_control(stable_id,false)
