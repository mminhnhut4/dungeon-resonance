extends Node2D
## One player-owned seal, seeking the existing cast state's committed clocks.
var actor_id: int = 0
var root_id: int = 0
var preparation: float = 0.0
var released: bool = false
var tint: Color = Color.WHITE
var alpha: float = 0.0
func bind(player: Player) -> void: actor_id=player.get_instance_id()
func _ready() -> void:
	z_index=7; process_physics_priority=20; visible=false
	var ink:=CanvasItemMaterial.new(); ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED; material=ink
func _physics_process(_delta: float) -> void: refresh()
func refresh() -> void:
	visible=false; root_id=0
	if actor_id==0 or not is_instance_id_valid(actor_id): return
	var player: Player=instance_from_id(actor_id) as Player
	var state: PlayerCastState=player.action_state_machine.current_state as PlayerCastState
	if state==null or state.payload==null: return
	var payload: SpellSnapshot=state.payload
	root_id=payload.root_id; tint=payload.color; released=state._launched
	preparation=clampf(1.0-state._remaining/maxf(payload.windup,0.001),0.0,1.0)
	alpha=clampf(state._remaining/maxf(payload.recovery,0.001),0.0,1.0) if released else 0.55+preparation*0.45
	global_position=player.aim.global_position+payload.direction*28.0
	global_rotation=payload.direction.angle(); visible=true; queue_redraw()
func _draw() -> void:
	var radius: float=18.0+preparation*5.0 if not released else 25.0
	var ink:=Color(0.025,0.055,0.065,alpha*0.9)
	var color:=Color(tint.r,tint.g,tint.b,alpha)
	draw_arc(Vector2.ZERO,radius,0.0,TAU,32,ink,5.0,true)
	draw_arc(Vector2.ZERO,radius,0.0,TAU,32,color,2.0,true)
	for index: int in 6:
		var angle: float=index*TAU/6.0
		var point: Vector2=Vector2.from_angle(angle)*radius
		draw_line(point*0.78,point*1.08,ink,5.0,true); draw_line(point*0.78,point*1.08,color,2.0,true)
	var arrow:=PackedVector2Array([Vector2(-9,-6),Vector2(12,0),Vector2(-9,6),Vector2(-4,0),Vector2(-9,-6)])
	draw_polyline(arrow,ink,5.0,true); draw_polyline(arrow,Color(1.0,0.95,0.73,alpha),2.0,true)
func _exit_tree() -> void: actor_id=0; root_id=0
