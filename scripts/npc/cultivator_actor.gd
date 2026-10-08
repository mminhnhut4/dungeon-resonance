class_name CultivatorActor
extends NpcPilotActor
## Local combat subclass. Registry owns HP/memory/patrol/recovery; no new writer.
var player: Player
var combat_phase: String = "idle"
var phase_remaining: float = 0.0
var aggro_remaining: float = 0.0
var reason: String = "Trung lập"
var strike_hitbox: Hitbox
var accepted_strikes: int = 0
var committed_strikes: int = 0
var _combat_spec: Dictionary = {}
var _simulation_enabled: bool = false
var _engagement_x: float = 0.0
var _strike: AttackSnapshot
var _cultivator_resolver: CultivatorResolver
var _rest_reason_remaining: float = 0.0

func bind_road_idle_art() -> void:
	# Each stable identity owns one full-body idle image; combat clocks stay physical.
	set_approved_portrait(CultivatorCatalog.portrait(stable_id))

func _ready() -> void:
	_combat_spec = CultivatorCatalog.definition(stable_id)
	super._ready()
	var previous_resolver: DamageResolver = hurtbox.damage_resolver
	_cultivator_resolver = CultivatorResolver.new()
	_cultivator_resolver.health = health
	_cultivator_resolver.world_state = world_state
	_cultivator_resolver.stable_id = stable_id
	_cultivator_resolver.player = player
	_cultivator_resolver.origin_offset_x = room.global_position.x
	add_child(_cultivator_resolver)
	hurtbox.damage_resolver = _cultivator_resolver
	previous_resolver.queue_free()
	hurtbox.hit_resolved.connect(_accepted_hit)
	strike_hitbox = ActorCombatRig.hitbox(self,8)
	strike_hitbox.name = "SelfDefenseHitbox"
	strike_hitbox.contact_detected.connect(_strike_contact)
	caption.position.x = -160.0
	caption.size.x = 320.0
	body.modulate = Color.WHITE
	_refresh_caption()

func sync_record(emit_cues: bool = true, interpolation_time: float = 0.0, frame_delta: float = 0.0) -> void:
	_simulation_enabled = emit_cues
	if not emit_cues and combat_phase in ["tell","active"]: _set_phase("recover",float(_combat_spec["recover"]))
	if combat_phase == "idle":
		super.sync_record(emit_cues,interpolation_time,frame_delta)
	else:
		# Local physics writes the bounded record; inherited schedule cannot move it.
		super.sync_record(false)
	if caption != null:
		caption.position.x = -160.0
		_refresh_caption()
	if body != null:
		EnemySpriteArt.set_facing(body,alpha_geometry.get("foot_pixel",Vector2.ZERO),_facing < 0.0)
		body.rotation = _facing * (-0.09 if combat_phase == "tell" else 0.13 if combat_phase == "active" else 0.0)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(strike_hitbox): return
	if world_state == null or world_state.read_only or not world_state.records.has(stable_id):
		_set_phase("idle")
		aggro_remaining = 0.0
		if world_state != null: world_state.set_local_control(stable_id,false)
		return
	var mode: String = world_state.records[stable_id]["mode"]
	if mode in ["downed","recovering","dead","talk"]:
		_stop_defense("Đã rút về dưỡng thương" if mode == "recovering" else "Đã ngừng đánh")
		return
	if not _simulation_enabled or not is_instance_valid(player) or not player.controls_enabled or get_tree().paused:
		if combat_phase in ["tell","active"]: _set_phase("recover",float(_combat_spec["recover"]))
		return
	if is_instance_valid(player.combat_feedback) and player.combat_feedback.is_frozen(): return
	var step: float = minf(delta,0.1)
	_rest_reason_remaining = maxf(0.0,_rest_reason_remaining-step)
	if combat_phase == "idle": return
	if not _target_in_leash():
		_stop_defense("Đã ngừng truy đuổi · Bạn đã rời đoạn đường")
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
			strike_hitbox.sample_contacts()
			if phase_remaining <= 0.0: _set_phase("recover",float(_combat_spec["recover"]))
		"recover", "hurt":
			if phase_remaining <= 0.0: _set_phase("approach")
	_refresh_caption()
	queue_redraw()

func _target_in_leash() -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree() or not is_instance_valid(room) or room.route_id != ExteriorRouteCatalog.MAIN: return false
	var spec: Dictionary = NpcPilotCatalog.definition(stable_id)
	var target_x: float = player.global_position.x-room.global_position.x
	return target_x >= float(spec["left"])-40.0 and target_x <= float(spec["right"])+40.0 and absf(target_x-_engagement_x) <= float(_combat_spec["leash"]) and absf(player.global_position.y-global_position.y) <= 130.0

func _position_for_strike(delta: float) -> void:
	var difference: Vector2 = player.global_position-global_position
	if absf(difference.x) > 0.1: _facing = signf(difference.x)
	var spacing: float = float(_combat_spec["spacing"])
	var move_direction: float = 0.0
	if absf(difference.x) > spacing+8.0: move_direction = _facing
	elif absf(difference.x) < spacing-8.0: move_direction = -_facing
	if move_direction != 0.0:
		var previous_x: float = position.x
		world_state.update_local_position(stable_id,position.x+move_direction*float(_combat_spec["speed"])*delta)
		position.x = float(world_state.records[stable_id]["x"])
		position.y = room.floor_y(position.x)
		_motion_distance += absf(position.x-previous_x)
	if absf(player.global_position.x-global_position.x) <= float(_combat_spec["reach"])-8.0 and absf(difference.y) <= 44.0:
		_commit_strike()

func _commit_strike() -> void:
	_strike = AttackSnapshot.new()
	_strike.source_id = get_instance_id()
	_strike.source_team_id = hurtbox.team_id
	_strike.attack_id = CombatIds.next_id()
	_strike.root_event_id = _strike.attack_id
	_strike.base_damage = float(_combat_spec["damage"])
	_strike.attack_origin = global_position+Vector2(0,-26)
	_strike.aim_position = player.global_position+Vector2(0,-26)
	_strike.attack_direction = (_strike.aim_position-_strike.attack_origin).normalized()
	if _strike.attack_direction.is_zero_approx(): _strike.attack_direction = Vector2(_facing,0)
	committed_strikes += 1
	_set_phase("tell",float(_combat_spec["tell"]),false)

func _open_strike() -> void:
	if _strike == null: return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(float(_combat_spec["reach"]),float(_combat_spec["height"]))
	strike_hitbox.rotation = _strike.attack_direction.angle()
	strike_hitbox.activate(_strike,shape,Vector2(0,-26)+_strike.attack_direction*float(_combat_spec["reach"])*0.5)
	combat_phase = "active"
	phase_remaining = float(_combat_spec["active"])
	strike_hitbox.sample_contacts()

func _strike_contact(target: Hurtbox, snapshot: AttackSnapshot) -> void:
	if world_state == null or world_state.read_only or not world_state.records.has(stable_id) or world_state.records[stable_id]["mode"] in ["talk","downed","recovering","dead"]: return
	if combat_phase != "active" or not _simulation_enabled or not is_instance_valid(player) or not player.controls_enabled or target != player.hurtbox: return
	# A query rectangle is only the broad phase. Existing world solids block reach.
	var sight := PhysicsRayQueryParameters2D.create(global_position+Vector2(0,-26),player.global_position+Vector2(0,-26),1)
	if not get_world_2d().direct_space_state.intersect_ray(sight).is_empty(): return
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
	event.physical_damage = true
	event.melee_hit = true
	event.heavy_hit = stable_id == "xich_lo_guard_01"
	event.hit_reaction = &"flinch"
	var result: DamageResult = target.take_damage(event)
	if result.actual_damage > 0.0: accepted_strikes += 1

func _accepted_hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0.0: return
	if world_state.records[stable_id]["mode"] in ["downed","recovering","dead"]:
		_stop_defense("Trọng thương · Rút về dưỡng thương")
		return
	# Every real injury cancels a committed strike; only the actual player provokes.
	if not _cultivator_resolver.is_player_cause(event):
		if combat_phase != "idle": _set_phase("hurt",float(_combat_spec["hurt"]))
		return
	if combat_phase == "idle": _engagement_x = position.x
	world_state.set_local_control(stable_id,true)
	aggro_remaining = float(_combat_spec["aggro"])
	reason = "Tự vệ · Bạn vừa gây thương tích"
	_set_phase("hurt",float(_combat_spec["hurt"]))
	_refresh_caption()

func _set_phase(phase: String, seconds: float = 0.0, cancel_snapshot: bool = true) -> void:
	if is_instance_valid(strike_hitbox): strike_hitbox.deactivate()
	if cancel_snapshot: _strike = null
	combat_phase = phase
	phase_remaining = seconds

func _stop_defense(message: String) -> void:
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
	if combat_phase != "idle":
		var phases: Dictionary = {"hurt":"Đang chịu đòn", "approach":"Giữ cự ly", "tell":"Sắp ra đòn", "active":"Ra đòn", "recover":"Thu chiêu"}
		activity = "%s · %s" % [reason,phases.get(combat_phase,combat_phase)]
	elif _rest_reason_remaining > 0.0:
		activity = reason
	elif world_state.records[stable_id]["mode"] == "recovering":
		activity = "Đã rút về dưỡng thương"
	else:
		activity = "Trung lập · " + activity
	caption.text = "%s\n%s" % [_combat_spec["sect"],activity]

func _draw() -> void:
	super._draw()
	if _combat_spec.is_empty() or combat_phase == "idle": return
	var tint: Color = _combat_spec["tint"]
	var direction: Vector2 = _strike.attack_direction if _strike != null else Vector2(_facing,0)
	var center := Vector2(0,-26)
	if combat_phase == "tell":
		draw_line(center,center+direction*float(_combat_spec["reach"]),Color(tint,0.75),2.0)
		draw_arc(center,float(_combat_spec["reach"]),direction.angle()-0.3,direction.angle()+0.3,12,Color(tint,0.7),2.0)
	elif combat_phase == "active":
		draw_line(center,center+direction*float(_combat_spec["reach"]),Color(tint,0.95),5.0)
	elif combat_phase == "hurt":
		draw_arc(center,30.0,0,TAU,24,Color(1.0,0.45,0.3,0.5),2.0)

func _exit_tree() -> void:
	if is_instance_valid(strike_hitbox): strike_hitbox.deactivate()
	_strike = null
	if world_state != null: world_state.set_local_control(stable_id,false)
