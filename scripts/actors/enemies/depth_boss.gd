class_name DepthBoss
extends BossGolem
## Huyền Uyên Chấp Ấn: separate clocks/windows on the proven boss protocol.

const ART: Script = preload("res://scripts/presentation/depth_boss_art.gd")
var locked_target: Vector2 = Vector2.ZERO
var locked_direction: Vector2 = Vector2.LEFT
var current_move: StringName = &"thrust"
var presentation: Node2D
var fan_directions: Array[Vector2] = []

func _ready() -> void:
	set_meta(&"custom_boss_visual", true)
	super._ready()
	add_to_group(&"depth_bosses")
	presentation = ART.new() as Node2D
	presentation.name = "DepthBossArt"
	add_child(presentation)
	presentation.bind(self)

func tell_seconds() -> float:
	return 0.90 if phase == 2 else 0.70

func active_seconds() -> float:
	return 0.22 if phase == 2 else 0.18

func recovery_seconds() -> float:
	return 0.80 if phase == 2 else 0.65

func fan_count() -> int:
	return 5 if phase == 2 else 3

func enter_state(id: StringName) -> void:
	super.enter_state(id)
	if id in [&"sweep", &"orbs"]:
		locked_target = player.global_position + Vector2(0, -24) if is_instance_valid(player) else global_position + Vector2(facing * 160.0, -50)
		locked_direction = (locked_target - (global_position + Vector2(0, -55))).normalized()
		current_move = &"seal_fan" if id == &"orbs" else &"seal_sweep" if phase == 2 else &"thrust"
		fan_directions.clear()
		var spread: float = 0.62 if phase == 2 else 0.34
		for index: int in fan_count():
			fan_directions.append(locked_direction.rotated(lerpf(-spread, spread, float(index) / float(fan_count() - 1))))

func tick_state(id: StringName, _delta: float) -> void:
	match id:
		&"idle":
			if not is_instance_valid(player) or player.health.current_health <= 0.0: return
			if absf(player.global_position.x - global_position.x) > 115.0:
				desired_speed = facing * movement_speed()
			if state_time >= wait_seconds() and _target_path_clear():
				var next: StringName = &"orbs" if attack_counter % 3 == 1 else &"sweep"
				attack_counter += 1
				fsm.transition_to(next)
		&"sweep":
			if not attack_started and state_time >= tell_seconds():
				attack_started = true
				var shape := RectangleShape2D.new()
				shape.size = Vector2(280, 32) if phase == 2 else Vector2(140, 30)
				attack_hitbox.activate(_attack(20.0), shape, Vector2(facing * 120, -22) if phase == 2 else Vector2(facing * 85, -32))
			if state_time >= tell_seconds() + active_seconds(): attack_hitbox.deactivate()
			if state_time >= tell_seconds() + active_seconds() and state_time < tell_seconds() + active_seconds() + 0.25:
				desired_speed = -facing * movement_speed() * 0.6
			if state_time >= tell_seconds() + active_seconds() + recovery_seconds(): fsm.transition_to(&"idle")
		&"orbs":
			while emitted_orbs < fan_count() and state_time >= tell_seconds() + emitted_orbs * 0.10:
				_spawn_hazard(&"orb", fan_directions[emitted_orbs])
				emitted_orbs += 1
			if emitted_orbs >= fan_count() and state_time < tell_seconds() + (fan_count() - 1) * 0.10 + 0.25:
				desired_speed = -facing * movement_speed() * 0.6
			if state_time >= tell_seconds() + (fan_count() - 1) * 0.10 + recovery_seconds(): fsm.transition_to(&"idle")
		&"recover":
			if state_time < 0.25: desired_speed = -facing * movement_speed() * 0.6
			if state_time >= recovery_seconds(): fsm.transition_to(&"idle")
		&"staggered":
			if state_time >= 1.0: fsm.transition_to(&"idle")
		&"dead":
			if state_time >= 0.6: queue_free()

func _spawn_hazard(kind: StringName, direction: Vector2) -> void:
	if not is_instance_valid(player) or get_tree().get_nodes_in_group(&"enemy_hazards").size() >= 24: return
	var hazard := EnemyHazard.new()
	hazard.kind = kind
	hazard.player = player
	hazard.feedback = feedback
	hazard.source_id = get_instance_id()
	hazard.hit_reaction = &"flinch"
	hazard.position = global_position + Vector2(facing * 46, -65)
	get_parent().add_child(hazard)
	# The shared hazard initializes aim in _ready; commit the fan after that initialization.
	hazard.direction = direction.normalized()

func _draw() -> void:
	pass # The actor-owned raster adapter renders the body and exact window cues.
