class_name PropSpriteSkin
extends Node2D
## Dummy/chest PNG adapter. Interaction, damage and physical motion stay upstream.

const DUMMY_TEXTURE: Texture2D = preload("res://assets/environment/props/dummy.png")
const CHEST_TEXTURE: Texture2D = preload("res://assets/environment/props/chest.png")
const FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const LIGHT_TEXTURE: Texture2D = preload("res://assets/presentation/light_radial.png")
const JADE: Color = Color(0.18, 0.95, 0.67)
const DUMMY_HEIGHT: float = 48.0
const CHEST_HEIGHT: float = 28.0

var sprite: Sprite2D
var pivot: Node2D
var opened_icon: Line2D
var chest_light: PointLight2D
var geometry: Dictionary = {}
var kind: StringName = &""
var wobble_tween: Tween
var wobble_count: int = 0
var wobble_angle: float = 0.0:
	set(value):
		wobble_angle = value
		if is_instance_valid(pivot):
			pivot.rotation = deg_to_rad(value)

var _actor_id: int = 0
var _original_self_modulate: Color = Color.WHITE
var _visuals: Dictionary[int, bool] = {}
var _body: Polygon2D
var _result_host: Node
var _material: ShaderMaterial
var _wobble_paused_by_hitstop: bool = false


func bind(target: Node2D) -> void:
	_disconnect_result()
	_stop_wobble()
	_restore_placeholders()
	_actor_id = target.get_instance_id() if is_instance_valid(target) else 0
	kind = &""
	if _actor_id == 0:
		if sprite != null:
			sprite.visible = false
			opened_icon.visible = false
		if chest_light != null:
			chest_light.enabled = false
		return
	if target.has_node("Visuals/Body"):
		kind = &"dummy"
		_body = target.get_node("Visuals/Body") as Polygon2D
		for item: Node in target.get_node("Visuals").get_children():
			if item is CanvasItem:
				_visuals[item.get_instance_id()] = (item as CanvasItem).visible
				(item as CanvasItem).visible = false
		var hurtbox: Node = target.get("hurtbox") as Node
		_result_host = hurtbox.get("damage_resolver") as Node
		_result_host.connect(&"damage_resolved", _on_hit_resolved)
	elif target.has_method("interact") and target.has_method("unlock"):
		kind = &"chest"
		_original_self_modulate = target.self_modulate
		target.self_modulate.a = 0.0
	else:
		_actor_id = 0
		return
	_build_nodes()
	sprite.visible = true
	if kind == &"chest" and chest_light == null:
		chest_light = PointLight2D.new()
		chest_light.name = "ChestJadeLight"
		chest_light.texture = LIGHT_TEXTURE
		chest_light.texture_scale = 0.9
		chest_light.position = Vector2(0, -15)
		chest_light.color = JADE
		chest_light.shadow_enabled = false
		add_child(chest_light)
	if chest_light != null:
		chest_light.enabled = kind == &"chest"
	var source: Texture2D = DUMMY_TEXTURE if kind == &"dummy" else CHEST_TEXTURE
	geometry = EnemySpriteArt.configure(sprite, source, DUMMY_HEIGHT if kind == &"dummy" else CHEST_HEIGHT)
	pivot.position = Vector2.ZERO
	if kind == &"dummy":
		var collision: CollisionShape2D = target.get_node("BodyCollision") as CollisionShape2D
		pivot.position.y = collision.position.y + collision.shape.get_rect().end.y
	refresh_skin()


func _build_nodes() -> void:
	if pivot != null:
		return
	pivot = Node2D.new()
	pivot.name = "PropFootPivot"
	add_child(pivot)
	sprite = Sprite2D.new()
	sprite.name = "PropSprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pivot.add_child(sprite)
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	sprite.material = _material
	opened_icon = Line2D.new()
	opened_icon.name = "OpenedCheckmark"
	opened_icon.position = Vector2(0, -CHEST_HEIGHT - 5.0)
	opened_icon.points = PackedVector2Array([Vector2(-4, 0), Vector2(-1, 3), Vector2(5, -4)])
	opened_icon.width = 2.0
	opened_icon.antialiased = true
	opened_icon.default_color = Color(0.42, 1.0, 0.78)
	var emissive := CanvasItemMaterial.new()
	emissive.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	opened_icon.material = emissive
	opened_icon.visible = false
	add_child(opened_icon)


func _ready() -> void:
	z_index = 2
	if _actor_id == 0 and get_parent() is Node2D:
		bind(get_parent() as Node2D)


func _process(_delta: float) -> void:
	if _actor_id == 0:
		return
	if not is_instance_id_valid(_actor_id):
		queue_free()
		return
	refresh_skin()


func refresh_skin() -> void:
	if _actor_id == 0 or not is_instance_id_valid(_actor_id) or sprite == null:
		return
	var target: Node2D = instance_from_id(_actor_id) as Node2D
	if kind == &"dummy":
		var flash: float = float(target.get("_flash_remaining"))
		var tint: Color = _body.modulate
		if flash > 0.0 and flash <= 0.12:
			tint *= _body.color
		sprite.modulate = tint
		_material.set_shader_parameter("flash", 1.0 if flash > 0.12 else 0.0)
		_material.set_shader_parameter("active", flash > 0.080001)
		var health: Node = target.get("health") as Node
		if health != null and float(health.get("current_health")) <= 0.0:
			sprite.modulate = sprite.modulate.darkened(0.6)
		var feedback: Node = target.get("combat_feedback") as Node
		if wobble_tween != null and wobble_tween.is_valid():
			if is_instance_valid(feedback) and bool(feedback.call("is_frozen")):
				if wobble_tween.is_running():
					_wobble_paused_by_hitstop = true
					wobble_tween.pause()
			elif _wobble_paused_by_hitstop:
				_wobble_paused_by_hitstop = false
				wobble_tween.play()
	else:
		var opened: bool = bool(target.get("is_open"))
		var locked: bool = bool(target.get("locked"))
		opened_icon.visible = opened
		sprite.modulate = Color(0.66, 0.73, 0.72) if opened else Color(0.66, 0.73, 1.0) if locked else Color.WHITE
		chest_light.energy = 0.2 if opened else 0.4 if locked else 0.55
		_material.set_shader_parameter("flash", 0.0)
		_material.set_shader_parameter("active", false)


func _on_hit_resolved(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0.0 or event.source_kind == DamageEvent.SourceKind.DOT:
		return
	_stop_wobble()
	var direction: float = signf(event.attack_direction.x)
	if is_zero_approx(direction):
		direction = -1.0 if wobble_count % 2 == 1 else 1.0
	wobble_count += 1
	wobble_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	wobble_tween.finished.connect(_on_wobble_finished, CONNECT_ONE_SHOT)
	wobble_tween.tween_property(self, "wobble_angle", 3.0 * direction, 0.045).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	wobble_tween.tween_property(self, "wobble_angle", -1.5 * direction, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble_tween.tween_property(self, "wobble_angle", 0.0, 0.09).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	refresh_skin()


func get_foot_world() -> Vector2:
	return EnemySpriteArt.foot_world(sprite, geometry["foot_pixel"]) if sprite != null and not geometry.is_empty() else global_position


func _stop_wobble() -> void:
	if wobble_tween != null and wobble_tween.is_valid():
		wobble_tween.kill()
	wobble_tween = null
	_wobble_paused_by_hitstop = false
	wobble_angle = 0.0


func _on_wobble_finished() -> void:
	wobble_tween = null
	_wobble_paused_by_hitstop = false
	wobble_angle = 0.0


func _disconnect_result() -> void:
	if is_instance_valid(_result_host) and _result_host.is_connected(&"damage_resolved", _on_hit_resolved):
		_result_host.disconnect(&"damage_resolved", _on_hit_resolved)
	_result_host = null


func _restore_placeholders() -> void:
	for id: int in _visuals:
		if is_instance_id_valid(id):
			(instance_from_id(id) as CanvasItem).visible = _visuals[id]
	_visuals.clear()
	if kind == &"chest" and _actor_id != 0 and is_instance_id_valid(_actor_id):
		(instance_from_id(_actor_id) as Node2D).self_modulate = _original_self_modulate
	_body = null


func _exit_tree() -> void:
	_disconnect_result()
	_stop_wobble()
	_restore_placeholders()
	_actor_id = 0
	geometry = {}
