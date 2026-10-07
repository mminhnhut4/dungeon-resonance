class_name GolemStompVFX
extends Node2D
## Floor marks, cracks and debris follow stomp commit/landing; no extra hazards.
const IMPACT_SECONDS: float = 0.55
const MAX_DEBRIS: int = 12
var boss: BossGolem
var phase: StringName = &""
var progress: float = 0.0
var impact_age: float = IMPACT_SECONDS
var impact_count: int = 0
var linked_wave_count: int = 0
var ground_world: Vector2 = Vector2.ZERO
var _waves_before: int = 0
var _linked_visuals: Array[int] = []

func bind(owner_boss: BossGolem) -> void:
	boss = owner_boss
	name = "GolemStompVFX"
	z_index = -3 # Floor VFX behind the PNG; never a white body overlay.
	process_physics_priority = 20
	_waves_before = boss.shockwave_count
	ground_world = boss.global_position
	_connect_events()
	seek_actor()

func _ready() -> void:
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	ink.blend_mode = CanvasItemMaterial.BLEND_MODE_MIX
	material = ink
	if is_instance_valid(boss):
		_connect_events()

func _connect_events() -> void:
	if not is_inside_tree() or not is_instance_valid(boss):
		return
	if not boss.fsm.state_changed.is_connected(_on_state):
		boss.fsm.state_changed.connect(_on_state)
	if not get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.connect(_on_node_added)

func _on_state(previous: StringName, next: StringName) -> void:
	if not is_instance_valid(boss):
		return
	if next == &"stomp":
		_waves_before = boss.shockwave_count
		impact_age = IMPACT_SECONDS
		_project_floor()
	if previous == &"stomp" and next == &"recover" and boss.is_on_floor() and boss.shockwave_count > _waves_before:
		ground_world = boss.global_position
		impact_age = 0.0
		impact_count += 1
	if next in [&"staggered", &"dead"] or (previous == &"stomp" and next not in [&"stomp", &"recover"]):
		phase = &""
		impact_age = IMPACT_SECONDS
	if next == &"dead":
		_release_wave_visuals()
	seek_actor()

func _project_floor() -> void:
	ground_world = boss.global_position
	if boss.is_on_floor():
		return
	var query := PhysicsRayQueryParameters2D.create(boss.global_position, boss.global_position + Vector2(0, 900), 1)
	query.exclude = [boss.get_rid()]
	var hit: Dictionary = boss.get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		ground_world = hit["position"]

func _physics_process(delta: float) -> void:
	if not is_instance_valid(boss) or boss.is_queued_for_deletion() or not boss.ai_enabled:
		return
	if is_instance_valid(boss.feedback) and boss.feedback.is_frozen():
		return
	impact_age = minf(IMPACT_SECONDS, impact_age + maxf(0.0, delta))
	seek_actor()

func seek_actor() -> void:
	if not is_instance_valid(boss):
		phase = &""
		return
	var state: StringName = boss.fsm.get_state_id()
	if state == &"stomp":
		phase = &"windup" if boss.state_time < 0.5 else &"flight" if boss.state_time < 0.82 else &"plunge"
		progress = clampf(boss.state_time / 0.5, 0.0, 1.0) if phase == &"windup" else clampf((boss.state_time-0.5)/0.32,0.0,1.0) if phase == &"flight" else 1.0
	elif state == &"recover" and impact_age < IMPACT_SECONDS:
		phase = &"recovery"
		progress = clampf(boss.state_time/0.45,0.0,1.0)
	else:
		phase = &""
		progress = 0.0
	queue_redraw()

func _on_node_added(node: Node) -> void:
	if node is EnemyHazard:
		_attach_wave.call_deferred(node.get_instance_id())

func _attach_wave(id: int) -> void:
	if not is_inside_tree() or not is_instance_valid(boss) or not is_instance_id_valid(id):
		return
	var wave: EnemyHazard = instance_from_id(id) as EnemyHazard
	if wave == null or wave.is_queued_for_deletion() or wave.kind != &"wave" or wave.source_id != boss.get_instance_id() or wave.get_parent() != boss.get_parent():
		return
	if wave.has_node("GolemGroundWaveVFX") or get_tree().get_nodes_in_group(&"golem_ground_wave_vfx").size() >= GolemGroundWaveVFX.MAX_VISUALS:
		return # Existing visible legacy wave remains the budget fallback.
	var visual := GolemGroundWaveVFX.new()
	wave.add_child(visual)
	visual.bind(wave)
	_linked_visuals.append(visual.get_instance_id())
	# Scalar IDs only. Expired wave entries never retain Nodes or resources.
	for index: int in range(_linked_visuals.size()-1,-1,-1):
		if not is_instance_id_valid(_linked_visuals[index]):
			_linked_visuals.remove_at(index)
	linked_wave_count += 1

func _draw() -> void:
	if not is_instance_valid(boss):
		return
	var floor_point: Vector2 = to_local(ground_world)
	if phase in [&"windup", &"flight", &"plunge"]:
		_draw_warning(floor_point)
	if impact_age < IMPACT_SECONDS:
		_draw_impact(floor_point)

func _draw_warning(origin: Vector2) -> void:
	var strength: float = 0.4 + progress * 0.4
	for sign_x: float in [-1.0, 1.0]:
		var start: Vector2 = origin + Vector2(sign_x*46,0)
		for index: int in 3:
			var x: float = sign_x * (index*10.0)
			draw_polyline(PackedVector2Array([start+Vector2(x-sign_x*5,-5),start+Vector2(x,0),start+Vector2(x-sign_x*5,5)]), Color(0.91,0.58,0.22,strength),1.5,true)
		draw_line(origin+Vector2(sign_x*14,2),start+Vector2(sign_x*28,2),Color(0.19,0.11,0.06,strength),2.4,true)
	# The fractured landing seal is an outline, not a fictional damage circle.
	for index: int in 8:
		var x: float = -30.0 + index * 8.0
		var depth: float = 3.0 + (index % 3) * 2.0
		draw_polyline(PackedVector2Array([origin+Vector2(x,-2),origin+Vector2(x+3,depth),origin+Vector2(x+6,0)]),Color(0.73,0.40,0.14,strength),1.1,true)
	if phase == &"plunge":
		draw_line(origin+Vector2(-25,-4),origin+Vector2(25,-4),Color(0.94,0.71,0.31,0.85),2.0,true)

func _draw_impact(origin: Vector2) -> void:
	var p: float = impact_age / IMPACT_SECONDS
	var fade: float = 1.0-p
	# Open ground fractures have shape, dark occlusion and finite branching.
	for sign_x: float in [-1.0,1.0]:
		var crack := PackedVector2Array()
		for index: int in 7:
			crack.append(origin+Vector2(sign_x*(8+index*12.0),float((index*7)%9-4)))
		draw_polyline(crack,Color(0.10,0.07,0.04,fade*0.9),3.2,true)
		draw_polyline(crack,Color(0.62,0.34,0.12,fade*0.75),1.0,true)
		for index: int in 3:
			var x: float = sign_x*(25+index*19.0)
			draw_line(origin+Vector2(x,0),origin+Vector2(x+sign_x*8,7-index*3),Color(0.14,0.09,0.05,fade),1.5,true)
	var rim := PackedVector2Array()
	for index: int in 25:
		var angle: float = PI+float(index)/24.0*PI
		rim.append(origin+Vector2(cos(angle)*(22+p*65),sin(angle)*(3+p*5)))
	draw_polyline(rim,Color(0.76,0.49,0.20,fade*0.75),2.0,true)
	for index: int in MAX_DEBRIS:
		var side: float = -1.0 if index%2==0 else 1.0
		var speed: float = 32.0+(index%6)*10.0
		var x: float = side*(8.0+impact_age*speed)
		var y: float = -sin(p*PI)*(14.0+(index%4)*6.0)
		var size: float = 1.4+(index%3)*0.7
		var center: Vector2 = origin+Vector2(x,y)
		var rock := PackedVector2Array([center+Vector2(-size,size*0.3),center+Vector2(-size*0.4,-size),center+Vector2(size,-size*0.3),center+Vector2(size*0.6,size)])
		draw_colored_polygon(rock,Color(0.28,0.21,0.13,fade*0.8))
		draw_line(rock[1],rock[2],Color(0.86,0.65,0.32,fade*0.8),0.8,true)

func snapshot() -> Dictionary:
	return {"phase":phase,"progress":progress,"impact_age":impact_age,"impact_count":impact_count,"linked_wave_count":linked_wave_count,"ground_world":ground_world,"max_debris":MAX_DEBRIS,"max_draw_commands":52,"lights":0,"damage_emitters":0}

func _release_wave_visuals() -> void:
	for id: int in _linked_visuals:
		if is_instance_id_valid(id):
			var node: GolemGroundWaveVFX = instance_from_id(id) as GolemGroundWaveVFX
			if is_instance_valid(node):
				node.restore_source()
				node.queue_free()
	_linked_visuals.clear()

func _exit_tree() -> void:
	if is_instance_valid(boss) and is_instance_valid(boss.fsm) and boss.fsm.state_changed.is_connected(_on_state):
		boss.fsm.state_changed.disconnect(_on_state)
	if get_tree() != null and get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	_release_wave_visuals()
	boss = null
