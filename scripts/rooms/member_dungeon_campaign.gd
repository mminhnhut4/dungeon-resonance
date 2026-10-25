class_name MemberDungeonCampaign
extends DepthCampaign
## Additive member floors: original opening and floors4–8 retain their owners.
const MemberCatalog=preload("res://data/member_floor_catalog.gd")
var member_active: bool=false
var member_floor: int=8
var member_progress: MemberDungeonProgress
var _member_pending: int=0
var _member_chests: Dictionary[int,bool]={}
var _member_chest: TreasureChest
var _member_data: Dictionary={}
var member_defeats: int=0
func _ready() -> void:
	super._ready()
	if profile!=null:
		member_progress=MemberDungeonProgress.new();member_progress.initialize(profile)
	if is_instance_valid(floor_exit):remove_child(floor_exit);floor_exit.queue_free()
	floor_exit=preload("res://scripts/ui/member_floor_exit_panel.gd").new();add_child(floor_exit);floor_exit.initialize(self)
func can_continue_after_warden() -> bool:
	return not member_active and not is_opening_segment() and room_number==5 and portal_active and outcome==&"" and is_instance_valid(room) and not room.locked and player.health.current_health>0 and not transition_pending
func can_continue_to_depth() -> bool:return super.can_continue_to_depth() or can_continue_after_warden()
func _continue_to_depth() -> bool:
	if can_continue_after_warden():return _enter_member_floor(9)
	return super._continue_to_depth()
func enter_room(number: int) -> bool:
	if number>=6:return _enter_member_floor(number+3)
	if member_active:return false
	return super.enter_room(number)
func _enter_member_floor(number: int) -> bool:
	if not MemberCatalog.valid(number) or outcome!=&"" or player.health.current_health<=0 or has_pending_rewards():return false
	if member_progress==null or not member_progress.unlocked():return false
	if not member_active and (number!=9 or not can_continue_after_warden()):return false
	if member_active and number!=member_floor+1:return false
	# Check the next content before releasing the room or carried entities.
	var data: Dictionary=MemberCatalog.floor_data(number)
	if data.is_empty() or not ResourceLoader.exists(data["background"]):return false
	_member_data=data
	if is_instance_valid(floor_exit) and floor_exit.is_open:floor_exit.close()
	gear.modal.close();content.close();survival.clear_room();feedback.reset_feedback();executor.clear_entities();gear.loot.clear()
	gear.loot.process_mode=Node.PROCESS_MODE_INHERIT
	if is_instance_valid(room):remove_child(room);room.queue_free()
	member_active=true;member_floor=number;room_number=number-3;stage=room_number;wave=1
	boss=null;reward_chest=null;branch_chest=null;_member_chest=null;portal_active=number==30;portal_visual=null;processed_deaths.clear()
	var next:=MemberDungeonRoom.new();next.floor_number=number;next.room_number=room_number;next.player=player;next.feedback=feedback
	next.member_enemy_defeated.connect(_member_enemy_died)
	room=next;add_child(room)
	PlayerTravel.relocate(player,MemberCatalog.ENTRY,PlayerTravel.Kind.INTRA_EXPEDITION);player.controls_enabled=true
	var camera:=player.get_node("Camera2D") as Camera2D
	camera.limit_left=32;camera.limit_right=roundi(MemberCatalog.width(number))-32;camera.limit_top=0;camera.limit_bottom=800
	camera.reset_smoothing();camera.force_update_scroll()
	presentation.rebuild(false);presentation.foyer_art.clear()
	for child: Node in presentation.atmosphere.room_art.get_children():
		if child is DungeonBackdrop:(child as CanvasItem).hide()
	var inherited: Node=room.get_node_or_null("ExistingMapRaster")
	if inherited!=null:inherited.call("clear");room.remove_child(inherited);inherited.queue_free()
	presentation.atmosphere.ambient.color=Color(.82,.82,.88)
	_spawn_member_chest(next,data)
	if survival.enabled:survival.place_campfire(MemberCatalog.camp_point(number))
	transition_pending=false
	if is_instance_valid(depth_hud):depth_hud.show()
	return true
func _member_enemy_died(enemy: BaseEnemy) -> void:
	if not member_active or not is_instance_valid(room) or not room.is_ancestor_of(enemy):return
	var id: int=enemy.get_instance_id()
	if processed_deaths.has(id):return
	processed_deaths[id]=true;member_defeats+=1
	# Reuse the guarded original loot owner; no new currency/save contract.
	_spawn_depth_loot.call_deferred(enemy.global_position,enemy.enemy_type,enemy.enemy_type==&"member_emperor",room.get_instance_id())
func _check_clear() -> void:
	if not member_active:super._check_clear()
	# Member floors stay traversable whether enemies live or die; no implicit gate.
func _spawn_member_chest(next: MemberDungeonRoom,data: Dictionary) -> void:
	if data["chest"]==null or _member_chests.has(member_floor):return
	var chest:=TreasureChest.new();chest.name="MemberOptionalChest";chest.player=player;chest.spawner=gear.loot
	chest.position=Vector2(float(data["chest"][0]),float(data["chest"][1]));chest.locked=true
	chest.opened.connect(_member_chest_opened.bind(member_floor));room.add_child(chest);_member_chest=chest
	for barrier: EnvironmentBarrier in next.barriers:
		if barrier.requires_fire:barrier.opened.connect(chest.unlock)
func _member_chest_opened(number: int) -> void:_member_chests[number]=true
func _record_member_exit() -> bool:
	if member_progress==null:return false
	if member_progress.record(member_floor):
		_member_pending=0
		return true
	_member_pending=member_floor;pending_save_changed.emit();return false
func advance_room() -> bool:
	if not member_active:
		if can_continue_after_warden():return _enter_member_floor(9)
		return super.advance_room()
	if member_floor>=30 or not can_choose_floor_exit() or has_pending_rewards() or (is_instance_valid(floor_exit) and floor_exit.is_open):return false
	if not _record_member_exit():return false
	return _enter_member_floor(member_floor+1)
func request_floor_return() -> bool:
	if member_active and (not can_choose_floor_exit() or has_pending_rewards() or not _record_member_exit()):return false
	return super.request_floor_return()
func can_choose_floor_exit() -> bool:
	if not member_active:return super.can_choose_floor_exit()
	return outcome==&"" and not transition_pending and is_instance_valid(room) and not room.locked and player.health.current_health>0 and not gear.modal.is_open and not content.panel_open and player.global_position.x>MemberCatalog.exit_point(member_floor).x-20
func win() -> bool:
	if member_active and (member_floor!=30 or not can_choose_floor_exit()):return false
	return super.win()
func global_floor_number() -> int:return member_floor if member_active else super.global_floor_number()
func _physics_process(delta: float) -> void:
	if not member_active:super._physics_process(delta);return
	if outcome!=&"" or gear==null:return
	if player.global_position.y>850:player.health.apply_damage(999)
	elif can_choose_floor_exit() and player.controls_enabled and Input.is_action_just_pressed(&"interact"):floor_exit.open()
func _process(delta: float) -> void:
	if not member_active:
		super._process(delta)
		if is_instance_valid(title):title.text=title.text.replace("/8","/30")
		if is_instance_valid(depth_heading):depth_heading.text=depth_heading.text.replace("/8","/30")
		return
	if gear==null:return
	hp_bar.max_value=player.health.maximum_health;hp_bar.value=player.health.current_health;energy_bar.value=player.energy.current
	title.text="%s · TẦNG %d/30"%[_member_data["name"],member_floor];boss_panel.hide()
	depth_heading.text=_member_data["name"];depth_tactic.hide();depth_gate.hide()
	_refresh_depth_exit()
func _refresh_depth_exit() -> void:
	if not member_active:super._refresh_depth_exit();return
	if is_instance_valid(floor_exit) and floor_exit.is_open:floor_exit.continue_button.disabled=has_pending_rewards()
func pending_reward_state() -> Dictionary:
	var state: Dictionary=super.pending_reward_state()
	state["objective_count"]=int(state["objective_count"])+(1 if _member_pending>0 else 0)
	state["member_objective_count"]=1 if _member_pending>0 else 0
	return state
func has_pending_rewards() -> bool:return super.has_pending_rewards() or _member_pending>0
func retry_pending_rewards() -> bool:
	if _reward_retry_busy:return false
	super.retry_pending_rewards()
	if _member_pending>0 and member_progress!=null and member_progress.record(_member_pending):_member_pending=0
	pending_save_changed.emit();return not has_pending_rewards()
