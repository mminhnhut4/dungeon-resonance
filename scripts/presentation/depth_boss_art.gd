class_name DepthBossArt
extends Node2D
## Raster body and committed seal tells. Reads boss state; never owns damage.

const RASTER: Script = preload("res://scripts/presentation/depth_enemy_art.gd")
const FLASH: Shader = preload("res://shaders/hit_flash.gdshader")
var actor: BossGolem
var sprite: Sprite2D
var shadow: ActorShadow
var raster_ready: bool = false
var selected_clip: StringName = &"idle"
var selected_frame: int = 0
var selected_progress: float = 0.0
var walk_distance: float = 0.0
var hit_count: int = 0
var _frames: Array[AtlasTexture] = []
var _pivots: Array[Vector2] = []
var _clips: Dictionary = {}
var _geometry: Dictionary = {}
var _world_scale: float = 1.0
var frame_scales: Array[float] = []
var primary_frames: int = 0
var walk_frames: int = 0
var _faces_left: bool = false
var _material: ShaderMaterial
var _last_position: Vector2

func bind(target: BossGolem) -> void:
	actor = target
	process_physics_priority = 15
	sprite = Sprite2D.new()
	sprite.name = "SealBossRasterSprite"
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(sprite)
	_material = ShaderMaterial.new()
	_material.shader = FLASH
	sprite.material = _material
	var sampler: WorldEnemyVisual = RASTER.new() as WorldEnemyVisual
	raster_ready = sampler.configure_raster("boss", 0, 110.0)
	if raster_ready:
		_frames = sampler._frames.duplicate()
		_pivots = sampler._pivots.duplicate()
		_clips = sampler._clips
		_world_scale = sampler._world_scale
		frame_scales = sampler.frame_scales.duplicate()
		primary_frames = sampler.primary_frames
		walk_frames = sampler.walk_frames
		_faces_left = sampler._source_faces_left
	else:
		_geometry = EnemySpriteArt.configure(sprite, load("res://assets/sprites/enemies/regions/world_champion.tres") as Texture2D, 110.0)
	sampler.free()
	shadow = ActorShadow.new()
	add_child(shadow)
	shadow.bind(actor, Vector2.ZERO, 84, 8, actor.feedback)
	_last_position = actor.global_position
	actor.fsm.state_changed.connect(_state_changed)
	actor.hurtbox.hit_resolved.connect(_hit)
	actor.attack_hitbox.contact_detected.connect(_outgoing_contact)
	refresh()

func _physics_process(_delta: float) -> void:
	if not is_instance_valid(actor): return
	if is_instance_valid(actor.feedback) and actor.feedback.is_frozen(): return
	var distance: float = absf(actor.global_position.x - _last_position.x)
	_last_position = actor.global_position
	if actor.fsm.get_state_id() == &"idle" and distance < 32.0: walk_distance += distance
	refresh()

func refresh() -> void:
	if not is_instance_valid(actor): return
	var state: StringName = actor.fsm.get_state_id()
	var tell: float = actor.tell_seconds()
	selected_clip = &"idle_phase2" if actor.phase == 2 else &"idle"
	selected_progress = fposmod(actor.state_time / 1.6, 1.0)
	if state == &"idle" and absf(actor.velocity.x) > 2.0:
		selected_clip = &"walk"
		selected_progress = fposmod(walk_distance / 48.0, 1.0)
	elif state == &"sweep":
		if actor.state_time < tell:
			selected_clip = &"telegraph_sweep" if actor.phase == 2 else &"telegraph"
			selected_progress = actor.state_time / tell
		elif actor.state_time < tell + actor.active_seconds():
			selected_clip = &"attack_sweep" if actor.phase == 2 else &"attack"
			selected_progress = (actor.state_time - tell) / actor.active_seconds()
		else:
			selected_clip = &"recover_sweep" if actor.phase == 2 else &"recover"
			selected_progress = (actor.state_time - tell - actor.active_seconds()) / actor.recovery_seconds()
	elif state == &"orbs":
		if actor.state_time < tell:
			selected_clip = &"telegraph_fan"
			selected_progress = actor.state_time / tell
		elif actor.emitted_orbs < actor.fan_count():
			selected_clip = &"attack_fan"
			selected_progress = float(actor.emitted_orbs) / actor.fan_count()
		else:
			selected_clip = &"recover"
			selected_progress = (actor.state_time - tell - (actor.fan_count() - 1) * 0.10) / actor.recovery_seconds()
	elif state == &"recover": selected_clip = &"recover"; selected_progress = actor.state_time / actor.recovery_seconds()
	elif state == &"staggered": selected_clip = &"hurt_phase2" if actor.phase == 2 else &"hurt"; selected_progress = actor.state_time
	elif state == &"dead": selected_clip = &"dead"; selected_progress = actor.state_time / 0.6
	if actor.flash > 0.075 and state != &"dead": selected_clip = &"hurt_phase2" if actor.phase == 2 else &"hurt"
	selected_progress = clampf(selected_progress, 0, 1)
	if raster_ready:
		var defaults: Dictionary = {"idle": [0], "idle_phase2": [7], "walk": [1], "telegraph": [2], "attack": [3], "recover": [4], "recover_sweep": [10], "hurt": [5], "hurt_phase2": [11], "dead": [5], "telegraph_fan": [6], "attack_fan": [6], "telegraph_sweep": [8], "attack_sweep": [9]}
		var choices: Array = _clips.get(String(selected_clip), defaults.get(String(selected_clip), [0]))
		selected_frame = int(choices[mini(choices.size() - 1, floori(selected_progress * choices.size()))])
		selected_frame = clampi(selected_frame, 0, _frames.size() - 1)
		sprite.texture = _frames[selected_frame]
		sprite.centered = false
		sprite.scale = Vector2.ONE * frame_scales[selected_frame]
		_geometry = {"foot_pixel": _pivots[selected_frame]}
		EnemySpriteArt.set_facing(sprite, _pivots[selected_frame], (actor.facing < 0) != _faces_left)
	else:
		EnemySpriteArt.set_facing(sprite, _geometry.foot_pixel, actor.facing < 0)
	sprite.modulate = Color(1, 1, 1, maxf(0.0, 1 - actor.state_time / 0.6) if state == &"dead" else 1.0)
	_material.set_shader_parameter("flash", 1.0 if actor.flash > 0.075 else 0.0)
	queue_redraw()

func _state_changed(_previous: StringName, _next: StringName) -> void:
	refresh()

func _hit(event: DamageEvent, result: DamageResult) -> void:
	if result.blocked or result.actual_damage <= 0 or event.source_kind == DamageEvent.SourceKind.DOT: return
	hit_count += 1
	refresh()

func _outgoing_contact(target: Hurtbox, attack: AttackSnapshot) -> void:
	# BossGolem's delivery is connected first. Seek the already committed window
	# before accepted Player damage freezes the next presentation physics tick.
	if not is_instance_valid(actor) or not is_instance_valid(target) or attack == null: return
	if attack.source_id != actor.get_instance_id() or not actor.attack_hitbox.active or actor.attack_hitbox.attack_snapshot != attack: return
	refresh()

func snapshot() -> Dictionary:
	return {"raster_ready": raster_ready, "clip": selected_clip, "frame": selected_frame, "progress": selected_progress, "foot": EnemySpriteArt.foot_world(sprite, _geometry.get("foot_pixel", Vector2.ZERO)), "frames": _frames.size(), "primary_frames": primary_frames, "walk_frames": walk_frames, "scale": sprite.scale, "phase": actor.phase, "state_time": actor.state_time, "flash": _material.get_shader_parameter("flash")}

func _draw() -> void:
	if not is_instance_valid(actor): return
	var state: StringName = actor.fsm.get_state_id()
	var tint := Color(0.72, 0.43, 1.0) if actor.phase == 1 else Color(1, 0.30, 0.62)
	var socket := Vector2(actor.facing * 46, -65)
	if state in [&"sweep", &"orbs"] and actor.state_time < actor.tell_seconds():
		var progress: float = clampf(actor.state_time / actor.tell_seconds(), 0, 1)
		draw_arc(socket, 17 + progress * 7, -progress, TAU - progress, 24, Color(tint, 0.85), 2)
		if state == &"orbs":
			for direction: Vector2 in actor.fan_directions:
				draw_line(socket + direction * 25, socket + direction * (65 + 40 * progress), Color(tint, 0.4 + progress * 0.45), 2)
		else:
			var size := Vector2(280, 32) if actor.phase == 2 else Vector2(140, 30)
			var center := Vector2(actor.facing * 120, -22) if actor.phase == 2 else Vector2(actor.facing * 85, -32)
			draw_rect(Rect2(center - size * 0.5, size), Color(tint, 0.08 + 0.08 * progress), true)
			draw_rect(Rect2(center - size * 0.5, size), Color(tint, 0.65), false, 1.5)
	if actor.attack_hitbox.active:
		var shape: Shape2D = actor.attack_hitbox._query_shape
		if shape is RectangleShape2D:
			draw_rect(Rect2(actor.attack_hitbox.position - shape.size * 0.5, shape.size), Color(tint, 0.18), true)
			draw_rect(Rect2(actor.attack_hitbox.position - shape.size * 0.5, shape.size), Color(tint, 0.95), false, 3)
	if actor.phase == 2:
		draw_arc(Vector2(0, -56), 54, 0, TAU, 32, Color(tint, 0.3), 1.5)

func _exit_tree() -> void:
	if is_instance_valid(actor):
		if is_instance_valid(actor.fsm) and actor.fsm.state_changed.is_connected(_state_changed): actor.fsm.state_changed.disconnect(_state_changed)
		if is_instance_valid(actor.hurtbox) and actor.hurtbox.hit_resolved.is_connected(_hit): actor.hurtbox.hit_resolved.disconnect(_hit)
		if is_instance_valid(actor.attack_hitbox) and actor.attack_hitbox.contact_detected.is_connected(_outgoing_contact): actor.attack_hitbox.contact_detected.disconnect(_outgoing_contact)
	actor = null
	_frames.clear()
	_pivots.clear()
	frame_scales.clear()
