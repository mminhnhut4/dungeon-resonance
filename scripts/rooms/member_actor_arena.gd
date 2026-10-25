class_name MemberActorArena
extends Node2D
## Explicit isolated trial. No permanent profile, loot payout or campaign placement.
const IDS=MemberEnemyCatalog.IDS
@onready var player: Player=$Player
@onready var feedback: CombatFeedback=$CombatFeedback
@onready var executor: SpellExecutor=$SpellExecutor
var gear: GearSession
var room: MemberDungeonRoom
var selected: int=0
var generation: int=0
var processed_deaths: Dictionary[int,bool]={}
var defeats: int=0
var reward_events: int=0
var heading: Label
var detail: Label
func _ready() -> void:
	player.combat_feedback=feedback;executor.combat_feedback=feedback
	player.resonance_controller.initialize(player,executor,feedback)
	gear=GearSession.new();add_child(gear);gear.initialize(player,feedback,self)
	for rune: RuneData in GearInventory.RUNES:gear.inventory.add_rune(rune.id)
	var canvas:=CanvasLayer.new();canvas.layer=20;add_child(canvas)
	heading=Label.new();heading.position=Vector2(36,18);heading.add_theme_font_size_override("font_size",21);canvas.add_child(heading)
	detail=Label.new();detail.position=Vector2(36,52);detail.add_theme_font_size_override("font_size",15);canvas.add_child(detail)
	room=MemberDungeonRoom.new();room.floor_number=18;room.player=player;room.feedback=feedback;add_child(room)
	var camera:=player.get_node("Camera2D") as Camera2D;camera.limit_left=32;camera.limit_right=1248;camera.limit_top=0;camera.limit_bottom=800
	reset_trial(0)
	print("MEMBER_ARENA_STARTED")
func reset_trial(index: int=0) -> void:
	selected=clampi(index,0,IDS.size()-1);generation+=1;set_meta(&"member_trial_generation",generation)
	for enemy: Node in get_tree().get_nodes_in_group(&"member_enemies"):
		if is_ancestor_of(enemy):enemy.get_parent().remove_child(enemy);enemy.queue_free()
	executor.clear_entities();gear.loot.clear();processed_deaths.clear();defeats=0;reward_events=0
	player.reset_movement_at(Vector2(260,640));player.controls_enabled=true
	var enemy:=load("res://scenes/enemies/member_enemy.tscn").instantiate() as MemberEnemy
	enemy.member_type=IDS[selected];enemy.position=Vector2(860,640);enemy.player=player;enemy.combat_feedback=feedback
	add_child(enemy);bind_member_enemy(enemy)
func bind_member_enemy(enemy: BaseEnemy) -> void:
	if not enemy.defeated.is_connected(_defeated):enemy.defeated.connect(_defeated)
func _defeated(enemy: BaseEnemy) -> void:
	var id: int=enemy.get_instance_id()
	if processed_deaths.has(id):return
	processed_deaths[id]=true;defeats+=1
	# This review arena intentionally grants no loot/currency/progression.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode>=KEY_1 and event.keycode<=KEY_5:reset_trial(int(event.keycode)-KEY_1);get_viewport().set_input_as_handled()
		elif event.keycode==KEY_R:reset_trial(selected);get_viewport().set_input_as_handled()
func _process(_delta: float) -> void:
	heading.text="KHU KIỂM QUÁI MỚI · %s"%MemberConceptCatalog.MODELS[String(IDS[selected])]["name"]
	detail.text="1–5: chọn quái · R: lượt mới · A/D/Space/Shift/LMB/RMB: điều khiển gốc · Tab: bùa QA\nKhông lưu/không thưởng · HP %d/%d · %d lần hạ duy nhất"%[roundi(player.health.current_health),roundi(player.health.maximum_health),defeats]
