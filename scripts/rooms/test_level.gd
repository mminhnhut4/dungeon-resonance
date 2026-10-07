extends Node2D
## Movement + two passive combat targets; feedback lifetime belongs to this room.

@export var player: Player
@export var spawn_point: Marker2D
@export var status_label: Label
@export var respawn_below_y: float = 850.0
@export var combat_feedback: CombatFeedback
@export var dummy_a: TrainingDummy
@export var dummy_b: TrainingDummy
@export var combat_hint: Label
@export var spell_executor: SpellExecutor
@export var debug_hud: DebugHUD
@export var enemy_scene: PackedScene
@export var enemies: Array[SlimeEnemy] = []
var _enemy_spawns: Array[Vector2] = []
const FIRE: RuneData = preload("res://data/runes/FireRune.tres")
const WIND: RuneData = preload("res://data/runes/WindRune.tres")
const LIGHTNING: RuneData = preload("res://data/runes/LightningRune.tres")
var _spell_hint_remaining: float = 0.0
var gear: GearSession
var survival: SurvivalSession
var content: ContentSession
var presentation: SlicePresentation
@onready var illusory_wall: EnvironmentBarrier = $Secrets/IllusoryWall
@onready var bramble_gate: EnvironmentBarrier = $Secrets/BrambleGate
@onready var secret_chest: TreasureChest = $Secrets/TreasureChest
const COMBAT_HINT: String = "Chuột: Ngắm hướng chém     J / Chuột trái: Combo     I / Chuột phải: Bùa     R: Đặt lại"


func _ready() -> void:
	player.combat_feedback = combat_feedback
	dummy_a.combat_feedback = combat_feedback
	dummy_b.combat_feedback = combat_feedback
	player.equipped_weapon.hit_confirmed.connect(combat_feedback.on_hit_confirmed)
	player.spell_cast_requested.connect(_on_spell_cast_requested)
	spell_executor.combat_feedback = combat_feedback
	player.resonance_controller.initialize(player, spell_executor, combat_feedback)
	player.hurtbox.damage_resolver.status_controller.combat_feedback = combat_feedback
	dummy_a.hurtbox.damage_resolver.status_controller.combat_feedback = combat_feedback
	dummy_b.hurtbox.damage_resolver.status_controller.combat_feedback = combat_feedback
	debug_hud.player = player
	for enemy: SlimeEnemy in enemies:
		_enemy_spawns.append(enemy.global_position)
		_configure_enemy(enemy)
	gear = GearSession.new()
	add_child(gear)
	gear.initialize(player, combat_feedback, self, true)
	secret_chest.player = player
	secret_chest.spawner = gear.loot
	secret_chest.locked = true
	secret_chest.unlock() # Its wall controls access, not an invisible interaction gate.
	$HUD/Status.offset_top = 235.0
	$HUD/Status.offset_bottom = 280.0
	survival = SurvivalSession.new()
	add_child(survival)
	survival.initialize(player, gear, self, combat_feedback, null, true)
	content = ContentSession.new()
	add_child(content)
	content.initialize(self, player, gear, spell_executor)
	presentation = SlicePresentation.new()
	add_child(presentation)
	presentation.initialize(self, player, combat_feedback, spell_executor)
	presentation.rebuild()


func reset_room() -> void:
	presentation.rebuild()
	content.close()
	survival.panel.close()
	survival.condition.clear()
	survival.director.end_incident()
	gear.modal.close()
	gear.loot.clear()
	illusory_wall.reset()
	bramble_gate.reset()
	secret_chest.reset()
	combat_feedback.reset_feedback()
	player.reset_movement_at(spawn_point.global_position)
	dummy_a.reset_at_home()
	dummy_b.reset_at_home()
	spell_executor.clear_entities()
	for index: int in enemies.size():
		if is_instance_valid(enemies[index]):
			enemies[index].reset_at_home()
		else:
			var enemy := enemy_scene.instantiate() as SlimeEnemy
			enemy.position = _enemy_spawns[index]
			add_child(enemy)
			enemies[index] = enemy
			_configure_enemy(enemy)
	_spell_hint_remaining = 0.0
	for text: Node in get_tree().get_nodes_in_group(&"combat_text"):
		if is_ancestor_of(text):
			text.queue_free()


func _on_spell_cast_requested(_target_position: Vector2, _direction: Vector2) -> void:
	_spell_hint_remaining = 1.0


func _process(delta: float) -> void:
	var presets: Array[StringName] = [&"preset_firestorm", &"preset_overload", &"preset_charged", &"preset_basic"]
	for index: int in presets.size():
		if not gear.modal.is_open and Input.is_action_just_pressed(presets[index]):
			var ids: Array[StringName] = []
			match index:
				0: ids.assign([&"fire", &"wind"])
				1: ids.assign([&"fire", &"lightning"])
				2: ids.assign([&"wind", &"lightning"])
			gear.inventory.equip_catalyst_set(ids)
	if Input.is_action_just_pressed(&"reset_player"):
		reset_room()
	elif player.global_position.y > respawn_below_y:
		combat_feedback.reset_feedback()
		player.reset_movement_at(spawn_point.global_position)
	_spell_hint_remaining = maxf(0.0, _spell_hint_remaining - delta)
	combat_hint.text = ("Chưa gắn phép hợp lệ. Hãy thử combo bằng J / Chuột trái." if not player.resonance_controller.casting_enabled or player.resonance_controller.get_recipe() == null else "Chuột phải / I: Phép theo hướng chuột • Đổi bùa không xóa hồi chiêu") if _spell_hint_remaining > 0.0 else COMBAT_HINT
	var weapon: Weapon = player.equipped_weapon
	var action_detail: String = "Combo: %s  |  %s" % ["%d/%d" % [weapon.combo_index + 1, weapon.definition.combo_steps.size()] if weapon.is_attacking() else "—", weapon.get_phase_name()]
	if player.motor.is_dashing:
		action_detail = "Dash hồi: %.2fs  |  Bất tử: %s" % [player.motor.dash_cooldown_remaining, "Có" if player.hurtbox.invulnerable else "Không"]
	status_label.text = "Di chuyển: %s  |  Hành động: %s\n%s" % [
		player.locomotion_state_machine.get_state_id().to_upper(),
		player.action_state_machine.get_state_id().to_upper(),
		action_detail,
	]


func _configure_enemy(enemy: SlimeEnemy) -> void:
	enemy.player = player
	enemy.combat_feedback = combat_feedback
	enemy.statuses.combat_feedback = combat_feedback


func set_rune_preset(index: int) -> void:
	var runes: Array[RuneData] = []
	match index:
		1: runes = [FIRE, WIND]
		2: runes = [FIRE, LIGHTNING]
		3: runes = [WIND, LIGHTNING]
		4: runes = []
		_: return
	player.resonance_controller.catalyst_a.install_runes(runes)
