class_name DepthEnemySkillArt
extends Node2D
## Reads an existing floor-owned hazard. No new clocks, damage or contact emitters.
const MAX_VISUALS: int = 16 # Mirrors the existing WorldEnemyHazard room budget.
const GROUP: StringName = &"depth_enemy_skill_art"
const ART: Script = preload("res://scripts/presentation/rendered_spell_art.gd")
const FORGE: Color = Color(1.0, 0.44, 0.12)
const SPORE: Color = Color(0.36, 1.0, 0.82)
var layers: Array[Sprite2D] = []
var _owner_id: int = 0
var _original_self_modulate: Color = Color.WHITE
var age: float = 0.0
var radius: float = 0.0
var active: bool = false
var element: StringName = &""
var stage: int = ART.FIELD
var kind: StringName = &""
var _target_hurtbox_id: int = 0

static func attach_to(hazard: WorldEnemyHazard) -> bool:
	if not is_instance_valid(hazard) or hazard.is_queued_for_deletion() or hazard.has_node("DepthEnemySkillArt"): return false
	var source: Node = instance_from_id(hazard.source_id) as Node if hazard.source_id != 0 and is_instance_id_valid(hazard.source_id) else null
	if not source is DepthEnemy or source.is_queued_for_deletion(): return false
	if not ((source.depth_floor == 4 and hazard.kind == &"slow_field") or (source.depth_floor == 2 and hazard.kind == &"jade_bolt")): return false
	if hazard.get_tree().get_nodes_in_group(GROUP).size() >= MAX_VISUALS or not ART.available(): return false
	var visual: DepthEnemySkillArt = new()
	visual.name = "DepthEnemySkillArt"
	hazard.add_child(visual)
	visual._bind(hazard)
	return true

func _ready() -> void:
	process_physics_priority = 20
	var ink := CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = ink

func _bind(hazard: WorldEnemyHazard) -> void:
	_owner_id = hazard.get_instance_id()
	_original_self_modulate = hazard.self_modulate
	kind = hazard.kind
	stage = ART.FIELD if kind == &"slow_field" else ART.PROJECTILE
	element = &"fire" if kind == &"slow_field" else &"poison"
	for child: Node in hazard.get_children():
		if child is CollisionShape2D and child.shape is CircleShape2D:
			radius = child.shape.radius
			break
	layers = ART.make_layers(self)
	ART.configure(layers, stage, element, element)
	hazard.self_modulate.a = 0.0 # Only the legacy parent drawing is replaced.
	add_to_group(GROUP)
	if kind == &"slow_field" and is_instance_valid(hazard.player):
		var target: Hurtbox = hazard.player.get("hurtbox") as Hurtbox
		if target != null:
			_target_hurtbox_id = target.get_instance_id()
			target.hit_resolved.connect(_field_contact)
	_sample(hazard)

func _hazard() -> WorldEnemyHazard:
	return instance_from_id(_owner_id) as WorldEnemyHazard if _owner_id != 0 and is_instance_id_valid(_owner_id) else null

func _physics_process(_delta: float) -> void:
	var hazard: WorldEnemyHazard = _hazard()
	if hazard == null or hazard.is_queued_for_deletion(): return
	if is_instance_valid(hazard.feedback) and hazard.feedback.is_frozen(): return
	_sample(hazard)

func _sample(hazard: WorldEnemyHazard) -> void:
	age = hazard.age
	active = kind == &"jade_bolt" or age >= 0.45
	rotation = hazard.direction.angle() if kind == &"jade_bolt" else 0.0
	var opacity: float = 0.86 if active else 0.38
	opacity *= clampf((hazard.lifetime - age) / 0.45, 0.0, 1.0)
	var size := Vector2(radius * 2.0, radius * 2.0) if kind == &"slow_field" else Vector2(54, 26)
	ART.seek(layers, size, opacity, age, stage, element, FORGE if kind == &"slow_field" else SPORE)
	queue_redraw()

func _field_contact(event: DamageEvent, result: DamageResult) -> void:
	var hazard: WorldEnemyHazard = _hazard()
	if hazard == null or hazard.is_queued_for_deletion() or hazard.attack == null: return
	if result.blocked or result.actual_damage <= 0.0 or event.source_kind == DamageEvent.SourceKind.DOT: return
	if event.source_id != hazard.source_id or event.root_event_id != hazard.attack.root_event_id: return
	# Player's existing hit feedback is already resolved. Read the accepted field
	# age now so first active paint cannot remain a warning through hitstop.
	_sample(hazard)

func _draw() -> void:
	if _hazard() == null: return
	if kind == &"slow_field":
		# This exact ring carries the collision radius independently of paint glow.
		var opacity: float = (0.92 if active else 0.55) * clampf((_hazard().lifetime - age) / 0.45, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius, age * 0.42, age * 0.42 + TAU, 32, Color(FORGE, opacity), 2.0, true)
		draw_arc(Vector2.ZERO, radius * 0.67, -age, TAU - age, 24, Color(1.0, 0.70, 0.20, opacity * 0.6), 1.0, true)
	else:
		draw_circle(Vector2(5, 0), 2.0, Color(SPORE, 0.85))

func snapshot() -> Dictionary:
	var hazard: WorldEnemyHazard = _hazard()
	return {"owner_id": _owner_id, "kind": kind, "stage": stage, "element": element, "age": age, "active": active, "radius": radius,
		"center_world": global_position, "heading": rotation, "lifetime": hazard.lifetime if hazard != null else 0.0,
		"layers": layers.size(), "visible_layers": 1, "max_visuals": MAX_VISUALS, "lights": 0, "damage_emitters": 0, "impact_emitters": 0}

func _exit_tree() -> void:
	var target: Hurtbox = instance_from_id(_target_hurtbox_id) as Hurtbox if _target_hurtbox_id != 0 and is_instance_id_valid(_target_hurtbox_id) else null
	if target != null and target.hit_resolved.is_connected(_field_contact): target.hit_resolved.disconnect(_field_contact)
	_target_hurtbox_id = 0
	var hazard: WorldEnemyHazard = _hazard()
	if hazard != null: hazard.self_modulate = _original_self_modulate
	_owner_id = 0
	layers.clear()
