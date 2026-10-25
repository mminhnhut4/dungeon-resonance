class_name MemberDungeonTrap
extends Node2D
## Finite room-owned environment damage through Hurtbox; never applies an impulse.
signal damage_applied(amount: float)
var kind: StringName=&"fixed_spikes"
var width: float=110.0
var phase_offset: float=0.0
var player: Player
var feedback: CombatFeedback
var age: float=0.0
var tick_remaining: float=0.0
var sigil_state: StringName=&"idle"
var sigil_remaining: float=0.0
var damage_events: int=0
var last_event: DamageEvent
func _ready() -> void:
	add_to_group(&"member_dungeon_traps");z_index=4
func phase() -> StringName:
	if kind==&"fixed_spikes":return &"active"
	if kind==&"sigil":return sigil_state
	if kind==&"pendulum":return &"active"
	var cycle: float=fposmod(age+phase_offset,2.85 if kind==&"spikes" else 3.2)
	if kind==&"spikes":return &"hidden" if cycle<1.4 else &"warning" if cycle<1.85 else &"active"
	return &"hidden" if cycle<1.6 else &"warning" if cycle<2.2 else &"active"
func bell_center() -> Vector2:
	var angle: float=sin((age+phase_offset)*TAU/3.4)*.96
	return Vector2(sin(angle),cos(angle))*220.0
func danger_rect() -> Rect2:
	if kind==&"pendulum":return Rect2(bell_center()-Vector2(32,30),Vector2(64,60))
	return Rect2(-width*.5,-275 if kind==&"fire" else -100 if kind==&"sigil" else -24,width,285 if kind==&"fire" else 110 if kind==&"sigil" else 34)
func _within() -> bool:
	if not is_instance_valid(player) or player.health.current_health<=0:return false
	var foot: Vector2=player.global_position-global_position
	var body: Rect2=Rect2(foot-Vector2(10,68),Vector2(20,70))
	return danger_rect().intersects(body)
func _physics_process(delta: float) -> void:
	if is_instance_valid(feedback) and feedback.is_frozen():return
	age+=delta;tick_remaining=maxf(0.0,tick_remaining-delta)
	if kind==&"sigil":
		if sigil_state==&"idle" and _within():sigil_state=&"warning";sigil_remaining=.6
		elif sigil_state!=&"idle":
			sigil_remaining-=delta
			if sigil_remaining<=0:
				if sigil_state==&"warning":
					sigil_state=&"active";sigil_remaining=.16
					if _within():_damage(14.0)
				# The visible flash is part of the authored1.8s rest, not extra delay.
				elif sigil_state==&"active":sigil_state=&"cooldown";sigil_remaining=1.64
				else:sigil_state=&"idle"
	elif phase()==&"active" and tick_remaining<=0 and _within():
		_damage(12.0 if kind in [&"fire",&"pendulum"] else 10.0)
	queue_redraw()
func _damage(amount: float) -> void:
	if not is_instance_valid(player):return
	tick_remaining=.7
	var event:=DamageEvent.new()
	event.source_id=get_instance_id();event.target_id=player.get_instance_id();event.source_team_id=0
	event.attack_id=CombatIds.next_id();event.root_event_id=event.attack_id;event.hit_window_id=1
	event.source_kind=DamageEvent.SourceKind.ENVIRONMENT;event.base_damage=amount
	event.attack_origin=global_position;event.hit_position=player.global_position
	event.knockback=Vector2.ZERO;event.hit_reaction=&"";event.allow_resonance=false
	last_event=event
	var result: DamageResult=player.hurtbox.take_damage(event)
	if not result.blocked:damage_events+=1;damage_applied.emit(result.actual_damage)
func _draw() -> void:
	var state: StringName=phase()
	var gold:=Color("f0c66b");var danger:=Color("e96c45")
	if kind==&"pendulum":
		var center: Vector2=bell_center()
		draw_arc(Vector2.ZERO,220,PI*.2,PI*.8,40,Color(.8,.6,.3,.12),2)
		draw_line(Vector2.ZERO,center,Color("978365"),5)
		for i: int in 8:draw_arc(center*float(i)/8,4,0,TAU,8,Color("c3a778"),1)
		draw_colored_polygon(PackedVector2Array([center+Vector2(-19,-28),center+Vector2(19,-28),center+Vector2(28,16),center+Vector2(35,25),center+Vector2(-35,25),center+Vector2(-28,16)]),Color("96703a"))
		draw_arc(center+Vector2(0,24),35,0,PI,24,gold,4);draw_line(center-Vector2(19,20),center+Vector2(19,-20),gold,3)
		return
	if kind==&"sigil":
		var color: Color=gold if state==&"warning" else danger if state==&"active" else Color("638c92")
		draw_arc(Vector2(0,-3),width*.5,0,TAU,40,color,3)
		for index: int in 6:
			var p: Vector2=Vector2.from_angle(index*TAU/6)*width*.34
			draw_line(p+Vector2(-4,-8),p+Vector2(4,8),color,2)
		if state==&"warning":draw_arc(Vector2(0,-3),width*.5*clampf(sigil_remaining/.6,0,1),0,TAU,36,gold,3)
		if state==&"active":
			draw_rect(Rect2(-width*.5,-100,width,100),Color(1,.64,.2,.22))
			for i: int in 5:draw_line(Vector2((i-2)*width/5,-5),Vector2((i-2)*width/5,-95),Color(1,.8,.4,.7),3)
		elif state==&"cooldown":draw_arc(Vector2(0,-3),width*.45,0,TAU,32,Color(.28,.44,.45,.35),1)
		return
	draw_rect(Rect2(-width*.5,-3,width,10),Color("4b4b49"))
	if kind==&"fire":
		draw_arc(Vector2.ZERO,width*.5,PI,TAU,16,Color("ad824e"),5)
		if state==&"warning":
			for index: int in 5:
				draw_circle(Vector2(sin(age*9+index)*15,-18-index*12),6+index,Color(.5,.43,.35,.3))
				draw_circle(Vector2(cos(age*5+index)*11,-8-index*9),2,Color(1,.65,.18,.7))
		elif state==&"active":
			draw_colored_polygon(PackedVector2Array([Vector2(-width*.5,0),Vector2(-width*.3,-210),Vector2(0,-275),Vector2(width*.4,-200),Vector2(width*.5,0)]),Color(1,.3,.08,.85))
			draw_line(Vector2(sin(age*17)*5,-12),Vector2(0,-230),Color(1,.85,.35,.8),width*.22)
			for i: int in 4:draw_line(Vector2((i-1.5)*width*.18,-30),Vector2(sin(age*14+i)*width*.22,-120-i*32),Color(1,.7,.2,.5),3)
		return
	var height: float=23.0 if state==&"active" else 7.0 if state==&"warning" else 2.0
	var color: Color=gold if state==&"warning" else Color("ccd0cd")
	if state==&"warning":draw_line(Vector2(-width*.5,-2),Vector2(width*.5,-2),Color(1,.7,.2,.5+.3*sin(age*32)),3)
	for index: int in maxi(1,roundi(width/16)):
		var x: float=-width*.5+index*16
		draw_colored_polygon(PackedVector2Array([Vector2(x,0),Vector2(x+7,-height),Vector2(x+14,0)]),color)
