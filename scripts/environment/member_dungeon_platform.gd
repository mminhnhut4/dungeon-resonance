class_name MemberDungeonPlatform
extends AnimatableBody2D
## Physics carries the rider. Collapse is latched once and survives early departure.
signal phase_changed(value: StringName)
var kind: StringName=&"moving"
var start: Vector2
var finish: Vector2
var platform_size: Vector2=Vector2(124,18)
var period: float=4.2
var player: Player
var feedback: CombatFeedback
var clock: float=0.0
var state: StringName=&"solid"
var remaining: float=0.0
var shape: CollisionShape2D
func _ready() -> void:
	add_to_group(&"member_dungeon_platforms")
	collision_layer=1;collision_mask=0;sync_to_physics=true
	position=start
	shape=CollisionShape2D.new();var rect:=RectangleShape2D.new();rect.size=platform_size
	shape.shape=rect;shape.position=Vector2(platform_size.x*.5,platform_size.y*.5)
	shape.one_way_collision=true;shape.one_way_collision_margin=4;add_child(shape)
	queue_redraw()
func _rider_on_top() -> bool:
	if not is_instance_valid(player) or player.health.current_health<=0:return false
	var p: Vector2=player.global_position-global_position
	return player.is_on_floor() and p.x>=-8 and p.x<=platform_size.x+8 and absf(p.y)<7
func _physics_process(delta: float) -> void:
	if is_instance_valid(feedback) and feedback.is_frozen():return
	clock+=delta
	if kind==&"moving":
		var fraction: float=(1.0-cos(clock*TAU/period))*.5
		position=start.lerp(finish,fraction)
	else:
		if state==&"solid" and _rider_on_top():state=&"warning";remaining=.6;phase_changed.emit(state)
		elif state!=&"solid":
			remaining-=delta
			if remaining<=0:
				if state==&"warning":state=&"fallen";remaining=2.4;shape.set_deferred("disabled",true)
				else:state=&"solid";shape.set_deferred("disabled",false)
				phase_changed.emit(state)
	queue_redraw()
func _draw() -> void:
	var rect:=Rect2(Vector2.ZERO,platform_size)
	if state==&"fallen":draw_rect(rect,Color(.55,.5,.4,.2),false,1);return
	var color:=Color("a6ab94") if kind==&"moving" else Color("827d6a")
	if state==&"warning":color=color.lerp(Color("f0c66b"),(sin(clock*38)+1)*.4)
	draw_rect(rect,color);draw_line(Vector2.ZERO,Vector2(platform_size.x,0),Color("e7d9a6"),3)
	draw_rect(Rect2(Vector2(3,4),platform_size-Vector2(6,7)),Color("454d4b"),false,1)
	if kind==&"moving":
		for x: float in [platform_size.x*.25,platform_size.x*.5,platform_size.x*.75]:
			draw_arc(Vector2(x,platform_size.y*.5),4,0,TAU,12,Color("79ddd0"),1)
			draw_line(Vector2(x-3,5),Vector2(x+3,platform_size.y-4),Color("a8e3d5"),1)
	else:
		for index: int in 3:draw_line(Vector2(index*platform_size.x/3,0),Vector2((index+.6)*platform_size.x/3,platform_size.y),Color("393b36"),2)
