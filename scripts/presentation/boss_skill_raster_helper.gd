class_name BossSkillRasterHelper
extends Node2D
## Painted cues seek existing boss clocks/windows. No emitter, gameplay clock,
## particle, collider, light, audio voice, RNG, save or damage owner is added.

const ART = preload("res://scripts/presentation/rendered_spell_art.gd")
const MAX_BOSS_VISUALS: int = 4
const ORB_DIAMETER: float = 26.0
var phase: StringName = &""
var phase_progress: float = 0.0
var sweep_rectangle: Rect2 = Rect2()
var visual_active: bool = false
var contact_refreshes: int = 0
var last_contact_root: int = 0
var actor_id: int = 0
var _seal: Array[Sprite2D] = []
var _sweep: Array[Sprite2D] = []
var _last_state: StringName = &""


static func attach(actor: BossGolem) -> BossSkillRasterHelper:
	if not is_instance_valid(actor) or actor.is_queued_for_deletion():
		return null
	var existing: BossSkillRasterHelper = actor.get_node_or_null("BossSkillRasterHelper") as BossSkillRasterHelper
	if existing != null:
		return existing
	if actor.is_inside_tree() and actor.get_tree().get_nodes_in_group(&"boss_skill_raster").size() >= MAX_BOSS_VISUALS:
		return null # Existing mechanics/body cues remain the finite fallback.
	var helper := BossSkillRasterHelper.new()
	helper.name = "BossSkillRasterHelper"
	actor.add_child(helper)
	helper.bind(actor)
	return helper


static func make_orb_glyph(parent: Node2D) -> Sprite2D:
	if not is_instance_valid(parent) or not ART.available():
		return null
	var glyph := Sprite2D.new()
	glyph.name = "RenderedBossOrbGlyph"
	glyph.texture = ART.cell(ART.CAST, &"lightning")
	glyph.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glyph.material = ART.ink
	parent.add_child(glyph)
	seek_orb_glyph(glyph, Vector2.LEFT, 0.0)
	return glyph


static func seek_orb_glyph(glyph: Sprite2D, direction: Vector2, elapsed: float) -> void:
	if not is_instance_valid(glyph) or glyph.texture == null:
		return
	glyph.position = Vector2.ZERO
	glyph.scale = Vector2(ORB_DIAMETER / glyph.texture.get_width(), ORB_DIAMETER / glyph.texture.get_height())
	glyph.rotation = direction.angle() + elapsed * 0.9
	glyph.modulate = Color(1.0, 0.9, 1.0, 0.94)


func _ready() -> void:
	process_physics_priority = 20
	z_index = 5
	add_to_group(&"boss_skill_raster")


func bind(actor: BossGolem) -> void:
	clear()
	if not is_instance_valid(actor):
		return
	actor_id = actor.get_instance_id()
	_ensure_paint()
	if actor.fsm != null and not actor.fsm.state_changed.is_connected(_state_changed):
		actor.fsm.state_changed.connect(_state_changed)
	# The gameplay listener is connected in BossGolem._ready first. Its accepted
	# hit may freeze this very tick before our later physics refresh can run.
	if actor.attack_hitbox != null and not actor.attack_hitbox.contact_detected.is_connected(_contact_published):
		actor.attack_hitbox.contact_detected.connect(_contact_published)
	refresh()


func _actor() -> BossGolem:
	return instance_from_id(actor_id) as BossGolem if actor_id != 0 and is_instance_id_valid(actor_id) else null


func _ensure_paint() -> void:
	if not _seal.is_empty() or not ART.available():
		return
	for index: int in 2:
		var seal := Sprite2D.new()
		seal.name = "BossSealLightning" if index == 0 else "BossSealIce"
		seal.texture = ART.cell(ART.CAST, &"lightning" if index == 0 else &"ice")
		seal.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		seal.material = ART.ink
		seal.visible = false
		add_child(seal)
		_seal.append(seal)
		var sweep := Sprite2D.new()
		sweep.name = "BossSweepLightning" if index == 0 else "BossSweepIce"
		sweep.texture = ART.cell(ART.PROJECTILE, &"lightning" if index == 0 else &"ice")
		sweep.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sweep.material = ART.ink
		sweep.visible = false
		add_child(sweep)
		_sweep.append(sweep)


func _physics_process(_delta: float) -> void:
	var actor: BossGolem = _actor()
	if actor == null or actor.is_queued_for_deletion():
		_hide_paint()
		return
	if is_instance_valid(actor.feedback) and actor.feedback.is_frozen():
		return
	refresh()


func _state_changed(_previous: StringName, _next: StringName) -> void:
	refresh() # Cancellation/death hides the cue on the authoritative boundary.


func _contact_published(_target: Hurtbox, attack: AttackSnapshot) -> void:
	var actor: BossGolem = _actor()
	if actor == null or actor.is_queued_for_deletion() or actor.attack_hitbox == null:
		return
	if attack == null or attack.source_id != actor.get_instance_id() or attack.root_event_id <= 0 or actor.attack_hitbox.attack_snapshot != attack or not actor.attack_hitbox.active:
		return
	contact_refreshes += 1
	last_contact_root = attack.root_event_id
	# Publish the current active geometry after gameplay delivery even if that
	# accepted contact just started hitstop. No clock/damage is advanced here.
	refresh()


func _hide_paint() -> void:
	for sprite: Sprite2D in _seal + _sweep:
		sprite.visible = false
	phase = &""
	phase_progress = 0.0
	visual_active = false
	sweep_rectangle = Rect2()


func refresh() -> void:
	_hide_paint()
	var actor: BossGolem = _actor()
	if actor == null or actor.is_queued_for_deletion() or actor.fsm == null:
		return
	var state: StringName = actor.fsm.get_state_id()
	_last_state = state
	if state not in [&"sweep", &"orbs"]:
		return
	_ensure_paint()
	if _seal.size() != 2 or _sweep.size() != 2:
		return
	var depth: bool = actor is DepthBoss
	var tell: float = actor.tell_seconds() if depth else 0.50 if state == &"sweep" else 0.55
	var active_end: float = tell + actor.active_seconds() if depth and state == &"sweep" else 0.66 if state == &"sweep" else tell + (actor.fan_count() - 1) * 0.10 if depth else 0.85
	var recovery: float = actor.recovery_seconds() if depth else 1.10 - active_end if state == &"sweep" else 1.30 - active_end
	var clock: float = maxf(0.0, actor.state_time)
	phase = &"windup" if clock < tell else &"active" if clock < active_end else &"recovery"
	phase_progress = clampf(clock / tell, 0.0, 1.0) if phase == &"windup" else clampf((clock - tell) / maxf(0.001, active_end - tell), 0.0, 1.0) if phase == &"active" else clampf((clock - active_end) / maxf(0.001, recovery), 0.0, 1.0)
	if state == &"sweep":
		_seek_sweep(actor, depth, clock, tell, active_end)
	else:
		_seek_seal(actor, depth, clock)


func _seek_sweep(actor: BossGolem, depth: bool, clock: float, tell: float, active_end: float) -> void:
	var size := Vector2(280, 32) if depth and actor.phase == 2 else Vector2(140, 30) if depth else Vector2(320, 26)
	var center := Vector2(actor.facing * 120, -22) if depth and actor.phase == 2 else Vector2(actor.facing * 85, -32) if depth else Vector2(actor.facing * 130, -13)
	visual_active = actor.attack_hitbox.active
	if visual_active:
		var actual: RectangleShape2D = actor.attack_hitbox._query_shape as RectangleShape2D
		if actual == null:
			return
		size = actual.size
		center = actor.attack_hitbox.position
		phase = &"active"
	elif clock >= tell and clock < active_end:
		# A blocked/cancelled active window never renders fictitious damage.
		return
	elif clock >= active_end and not actor.attack_started:
		return
	var opacity: float = 0.20 + 0.18 * phase_progress if phase == &"windup" else 0.92 if visual_active else (1.0 - phase_progress) * 0.35
	sweep_rectangle = Rect2(center - size * 0.5, size)
	for index: int in _sweep.size():
		var sprite: Sprite2D = _sweep[index]
		var inset: float = 1.0 if index == 0 else 0.78
		sprite.position = center
		sprite.rotation = 0.0
		sprite.flip_h = actor.facing < 0.0
		sprite.scale = Vector2(size.x / sprite.texture.get_width(), size.y / sprite.texture.get_height()) * inset
		sprite.modulate = Color(1.0, 1.0, 1.0, opacity * (1.0 if index == 0 else 0.52))
		sprite.visible = opacity > 0.001


func _seek_seal(actor: BossGolem, depth: bool, clock: float) -> void:
	var direction: Vector2 = actor.locked_direction if depth else Vector2(actor.facing, 0.0)
	var size: float = 34.0 + phase_progress * 10.0 if phase == &"windup" else 42.0
	var opacity: float = 0.50 + phase_progress * 0.42 if phase == &"windup" else 0.90 if phase == &"active" else (1.0 - phase_progress) * 0.50
	for index: int in _seal.size():
		var sprite: Sprite2D = _seal[index]
		sprite.position = Vector2(actor.facing * 46, -65)
		sprite.rotation = direction.angle() + clock * (0.40 if index == 0 else -0.55)
		sprite.scale = Vector2(size / sprite.texture.get_width(), size / sprite.texture.get_height()) * (1.0 if index == 0 else 0.80)
		sprite.modulate = Color(1.0, 1.0, 1.0, opacity * (1.0 if index == 0 else 0.60))
		sprite.visible = opacity > 0.001


func snapshot() -> Dictionary:
	var actor: BossGolem = _actor()
	var visible_sprites: int = 0
	for sprite: Sprite2D in _seal + _sweep:
		if sprite.visible:
			visible_sprites += 1
	return {"actor_id": actor_id, "state": _last_state, "state_time": actor.state_time if actor != null else 0.0, "phase": phase, "progress": phase_progress, "active": visual_active, "sweep_rectangle": sweep_rectangle, "visible_sprites": visible_sprites, "resident_sprites": _seal.size() + _sweep.size(), "contact_refreshes": contact_refreshes, "last_contact_root": last_contact_root, "max_boss_visuals": MAX_BOSS_VISUALS, "orb_diameter": ORB_DIAMETER, "lights": 0, "damage_emitters": 0, "clock_writers": 0}


func clear() -> void:
	var actor: BossGolem = _actor()
	if actor != null and actor.fsm != null and actor.fsm.state_changed.is_connected(_state_changed):
		actor.fsm.state_changed.disconnect(_state_changed)
	if actor != null and actor.attack_hitbox != null and actor.attack_hitbox.contact_detected.is_connected(_contact_published):
		actor.attack_hitbox.contact_detected.disconnect(_contact_published)
	actor_id = 0
	contact_refreshes = 0
	last_contact_root = 0
	_hide_paint()


func _exit_tree() -> void:
	clear()
	_seal.clear()
	_sweep.clear()
