class_name BossGolemSkin
extends Node2D
## PNG replacement reads the original FSM; no collider or attack clock is moved.

const LIGHT_TEXTURE: Texture2D = preload("res://assets/presentation/light_radial.png")
const SPRITE_TEXTURE: Texture2D = preload("res://assets/sprites/enemies/boss_golem.png")
const ART_RIG = preload("res://scripts/presentation/golem_art_rig.gd")
var art_rig: Node2D
const FLASH_SHADER: Shader = preload("res://shaders/hit_flash.gdshader")
const CYAN: Color = Color(0.20, 0.89, 1.0)
const JADE: Color = Color(0.18, 0.95, 0.67)
const AMBER: Color = Color(1.0, 0.48, 0.12)
const BODY_HEIGHT: float = 100.0
const MAX_HIT_FLASH: float = 0.12
const PHASE_ONE_CORE_ENERGY: float = 0.25
const PHASE_TWO_CORE_ENERGY: float = 0.32

var sprite: Sprite2D
var core_light: PointLight2D
var clock: float = 0.0
var current_tint: Color = CYAN
var geometry: Dictionary = {}
var _stone_flash: float = 0.0
var _staggered: bool = false
var _fade: float = 1.0
var _actor_id: int = 0
var _original_self_modulate: Color = Color.WHITE
var _material: ShaderMaterial
var _state: StringName = &"idle"
var _facing: float = -1.0
var _active: bool = false
var motion: Node2D
var actor_shadow: ActorShadow
var stomp_vfx: GolemStompVFX
var _observed_fsm: ActorStateMachine
var _target_hurt: Hurtbox
var _state_time: float = 0.0
var _emitted_orbs: int = 0


func bind(owner_boss: Node2D) -> void:
	_disconnect_owner_events()
	_release_stomp_vfx()
	_restore_body()
	_actor_id = owner_boss.get_instance_id() if is_instance_valid(owner_boss) else 0
	if _actor_id == 0:
		if is_instance_valid(actor_shadow):
			actor_shadow.bind(null)
		return
	_original_self_modulate = owner_boss.self_modulate
	# Hides only the parent's legacy drawing; its children remain fully visible.
	owner_boss.self_modulate.a = 0.0
	if is_instance_valid(actor_shadow):
		actor_shadow.bind(owner_boss as CharacterBody2D, Vector2.ZERO, 62.0, 12.0)
	if owner_boss is BossGolem:
		stomp_vfx = GolemStompVFX.new()
		add_child(stomp_vfx)
		stomp_vfx.bind(owner_boss as BossGolem)
		_connect_owner_events(owner_boss as BossGolem)
	refresh_skin()


func _ready() -> void:
	z_index = 2
	process_physics_priority = 15
	motion = Node2D.new()
	motion.name = "GolemFootDynamics"
	add_child(motion)
	sprite = Sprite2D.new()
	sprite.name = "GolemSprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	motion.add_child(sprite)
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	sprite.material = _material
	geometry = EnemySpriteArt.configure(sprite, SPRITE_TEXTURE, BODY_HEIGHT)
	if not geometry.is_empty():
		art_rig=ART_RIG.new(); art_rig.name="CombatClockStoneRig"; motion.add_child(art_rig)
		art_rig.build(SPRITE_TEXTURE,geometry["foot_pixel"],sprite.scale.x,_material)
		sprite.visible=false # Retain the reviewed foot/shader contract as a reference.
	core_light = PointLight2D.new()
	core_light.name = "GolemCoreLight"
	core_light.position = Vector2(0, -58)
	core_light.texture = LIGHT_TEXTURE
	core_light.texture_scale = 1.65
	core_light.shadow_enabled = false
	add_child(core_light)
	actor_shadow = ActorShadow.new()
	actor_shadow.name = "ActorShadow"
	add_child(actor_shadow)
	if _actor_id == 0 and get_parent() is CharacterBody2D:
		bind(get_parent() as Node2D)
	elif _actor_id != 0 and is_instance_id_valid(_actor_id):
		actor_shadow.bind(instance_from_id(_actor_id) as CharacterBody2D, Vector2.ZERO, 62.0, 12.0)
	refresh_skin()


func _physics_process(delta: float) -> void:
	if _actor_id == 0:
		return
	if not is_instance_id_valid(_actor_id):
		queue_free()
		return
	var boss: Node2D = instance_from_id(_actor_id) as Node2D
	_bind_target_contact()
	var feedback: Node = boss.get("feedback") as Node
	actor_shadow.set_feedback(feedback)
	if is_instance_valid(feedback) and bool(feedback.call("is_frozen")):
		return
	clock += maxf(delta, 0.0)
	refresh_skin()


func refresh_skin() -> void:
	if _actor_id == 0 or not is_instance_id_valid(_actor_id):
		return
	var boss: Node2D = instance_from_id(_actor_id) as Node2D
	var phase: int = int(boss.get("phase"))
	current_tint = AMBER if phase == 2 else CYAN
	_stone_flash = clampf(float(boss.get("flash")) / 0.12, 0.0, 1.0)
	var machine: Node = boss.get("fsm") as Node
	_state = StringName(machine.call("get_state_id")) if is_instance_valid(machine) else &"idle"
	_state_time = float(boss.get("state_time"))
	_emitted_orbs = int(boss.get("emitted_orbs"))
	_staggered = _state == &"staggered"
	_fade = maxf(0.0, 1.0 - float(boss.get("state_time")) / 0.6) if _state == &"dead" else 1.0
	modulate.a = _fade
	_facing = float(boss.get("facing"))
	var hitbox: Node = boss.get("attack_hitbox") as Node
	_active = bool(hitbox.get("active")) if is_instance_valid(hitbox) else false
	var pulse: float = 0.9 + sin(clock * (12.0 if _staggered else 3.5)) * 0.08
	if sprite != null and not geometry.is_empty():
		var body: CharacterBody2D = boss as CharacterBody2D
		var still: bool = body != null and absf(body.velocity.x) < 8.0
		motion.scale.y = ProceduralAnimator.breathing_scale(clock, 1.8) if _state == &"idle" and still else 1.0
		sprite.modulate = Color(1.16, 0.82, 0.65) if phase == 2 else Color.WHITE
		# Port the reviewed precursor shader fix as well as its bounded light-only cap.
		var flash_visible: bool = float(boss.get("flash")) > 0.040001
		_material.set_shader_parameter("flash", _stone_flash * MAX_HIT_FLASH if flash_visible else 0.0)
		_material.set_shader_parameter("active", false)
		EnemySpriteArt.set_facing(sprite, geometry["foot_pixel"], _facing < 0.0)
		if art_rig != null:
			art_rig.modulate=sprite.modulate
			art_rig.seek(_state,_state_time,body.velocity,_facing,float(boss.get("flash")),clock,body.is_on_floor(),_active)
	if core_light != null:
		core_light.position.y = -58.0 * motion.scale.y
		core_light.color = JADE if phase == 1 else AMBER
		var core_energy: float = PHASE_ONE_CORE_ENERGY if phase == 1 else PHASE_TWO_CORE_ENERGY
		core_light.energy = core_energy * pulse * _fade * (1.0 - _stone_flash)
	queue_redraw()


func _draw() -> void:
	# Reproduce telegraphs hidden with the old parent drawing, at unchanged sizes.
	if _state == &"sweep":
		_draw_sweep_lane()
	elif _state == &"stomp" and not is_instance_valid(stomp_vfx):
		draw_circle(Vector2(0, -45), 60, Color(1.0, 0.45, 0.1, 0.22))
	elif _state == &"orbs":
		# The seal sits on the existing EnemyHazard spawn socket. Its three
		# notches reflect actual emitted_orbs, never a second attack timer.
		var socket:=Vector2(_facing*46.0,-65.0)
		var opacity: float=1.0-smoothstep(0.9,1.3,_state_time)
		var radius: float=7.0+smoothstep(0.0,0.55,_state_time)*10.0
		draw_arc(socket,radius,0.0,TAU,24,Color(0.04,0.05,0.025,opacity),5.0,true)
		draw_arc(socket,radius,0.0,TAU,24,Color(current_tint,opacity),2.0,true)
		for index: int in 3:
			var point: Vector2=socket+Vector2.from_angle(index*TAU/3.0)*radius
			draw_circle(point,2.5,Color(current_tint.lightened(0.4) if index>=_emitted_orbs else current_tint.darkened(0.55),opacity))
	if _staggered:
		draw_arc(Vector2(0, -58), 19.0, 0.3, 2.5, 14, current_tint.lightened(0.25), 1.6, true)


func _connect_owner_events(boss: BossGolem) -> void:
	_observed_fsm = boss.fsm
	if is_instance_valid(_observed_fsm) and not _observed_fsm.state_changed.is_connected(_on_boss_state):
		_observed_fsm.state_changed.connect(_on_boss_state)
	_bind_target_contact()

func _bind_target_contact() -> void:
	var boss: BossGolem = instance_from_id(_actor_id) as BossGolem if _actor_id != 0 and is_instance_id_valid(_actor_id) else null
	var next: Hurtbox = boss.player.hurtbox if boss != null and is_instance_valid(boss.player) else null
	if next == _target_hurt: return
	if is_instance_valid(_target_hurt) and _target_hurt.hit_resolved.is_connected(_on_target_hit):
		_target_hurt.hit_resolved.disconnect(_on_target_hit)
	_target_hurt = next
	if is_instance_valid(_target_hurt): _target_hurt.hit_resolved.connect(_on_target_hit)

func _on_boss_state(_previous: StringName, _next: StringName) -> void:
	_bind_target_contact()
	refresh_skin()

func _on_target_hit(event: DamageEvent, result: DamageResult) -> void:
	if event.source_id != _actor_id or result.blocked or result.actual_damage <= 0.0 or event.source_kind == DamageEvent.SourceKind.DOT: return
	# The resolved contact can freeze later physics observers in this tick.
	# Commit the current physical window now, without advancing any actor clock.
	refresh_skin()

func _disconnect_owner_events() -> void:
	if is_instance_valid(_observed_fsm) and _observed_fsm.state_changed.is_connected(_on_boss_state):
		_observed_fsm.state_changed.disconnect(_on_boss_state)
	if is_instance_valid(_target_hurt) and _target_hurt.hit_resolved.is_connected(_on_target_hit):
		_target_hurt.hit_resolved.disconnect(_on_target_hit)
	_observed_fsm = null
	_target_hurt = null

func sweep_readability_snapshot() -> Dictionary:
	return {"state":_state,"actor_time":_state_time,"phase":"tell" if _state_time < 0.5 else "active" if _active else "recovery","physical_active":_active,"lane":Rect2(-30 if _facing > 0.0 else -290,-26,320,26),"facing":_facing}

func _draw_sweep_lane() -> void:
	# All ink stays in the existing320x26 damage lane; only emphasis changes.
	var lane:=Rect2(-30 if _facing > 0.0 else -290,-26,320,26)
	if _state_time < 0.5:
		var preparation: float=clampf(_state_time/0.5,0.0,1.0)
		draw_rect(lane,Color(0.70,0.34,0.10,0.07))
		draw_rect(lane,Color(0.95,0.66,0.28,0.35+preparation*0.45),false,1.4)
		for index: int in 4:
			var point:=Vector2(_facing*(35+index*62),-13)
			draw_polyline(PackedVector2Array([point+Vector2(-_facing*7,-5),point,point+Vector2(-_facing*7,5)]),Color(0.97,0.73,0.39,0.35+preparation*0.5),1.5,true)
	elif _active:
		draw_rect(lane,Color(1.0,0.42,0.12,0.28))
		draw_rect(lane,Color(1.0,0.74,0.36,0.92),false,2.0)
		draw_line(Vector2(_facing*20,-13),Vector2(_facing*275,-13),Color(1.0,0.72,0.29,0.78),2.0,true)
	else:
		draw_rect(lane,Color(0.60,0.32,0.14,0.12),false,1.0)

func get_foot_world() -> Vector2:
	return EnemySpriteArt.foot_world(sprite, geometry["foot_pixel"]) if sprite != null and not geometry.is_empty() else global_position


func _restore_body() -> void:
	if _actor_id != 0 and is_instance_id_valid(_actor_id):
		var boss: Node2D = instance_from_id(_actor_id) as Node2D
		boss.self_modulate = _original_self_modulate


func _exit_tree() -> void:
	_disconnect_owner_events()
	_release_stomp_vfx()
	_restore_body()
	_actor_id = 0
	geometry = {}

func _release_stomp_vfx() -> void:
	if is_instance_valid(stomp_vfx):
		remove_child(stomp_vfx)
		stomp_vfx.queue_free()
	stomp_vfx = null
