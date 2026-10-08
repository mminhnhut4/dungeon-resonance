class_name DepthCampaign
extends WorldCampaign
## Opt-in five-floor expedition. The parent retains player, gear, save escrow and return ownership.
const Catalog=preload("res://data/depth_floor_catalog.gd")
const RoomScript=preload("res://scripts/rooms/depth_room.gd")
const ENEMY_SCENE: String="res://scenes/enemies/depth_enemy.tscn"
const BOSS_SCENE: String="res://scenes/enemies/depth_boss.tscn"
signal depth_floor_cleared(floor_number: int)
signal depth_completed
signal depth_event(event_id: StringName,floor_number: int)
@export_range(1,5) var initial_floor: int=1
@export var connected_opening: bool=false
var depth_entry_authorizer: Callable
var _opening_active: bool=false
var depth_deaths: int=0
var depth_progress_committer: Callable
var _depth_events_pending: Dictionary[StringName,int]={}
var _cleared_floors: Dictionary[int,bool]={}
var _summons_created: bool=false
var branch_chest: TreasureChest
var _opened_branch_chests: Dictionary[int,bool]={}
var depth_hud: PanelContainer
var depth_heading: Label
var depth_tactic: Label
var depth_gate: Label
func _ready() -> void:
	_opening_active=connected_opening
	super._ready()
	gear.loot.drop_table=preload("res://data/loot/world_drop_table.tres")
	gear.loot.permanent_profile=survival.profile
	_build_depth_hud()
	depth_hud.visible=not _opening_active
	if connected_opening:
		remove_child(floor_exit); floor_exit.queue_free()
		floor_exit=preload("res://scripts/ui/connected_floor_exit_panel.gd").new()
		add_child(floor_exit); floor_exit.initialize(self)
	pending_save_changed.connect(_refresh_depth_exit)
	get_viewport().size_changed.connect(_resize_depth_hud)
	_resize_depth_hud()
func enter_stage(number: int) -> bool:
	return super.enter_stage(number) if _opening_active else enter_room(number)
func enter_room(number: int) -> bool:
	if _opening_active: return super.enter_room(number)
	if stage==0: number=initial_floor
	if not Catalog.valid(number) or player.health.current_health<=0.0 or outcome!=&"" or has_pending_rewards(): return false
	# Validate dependencies before touching the current room and its carried inventory.
	var path: String=BOSS_SCENE if number==Catalog.FLOOR_COUNT else ENEMY_SCENE
	if not ResourceLoader.exists(path): return false
	if is_instance_valid(floor_exit) and floor_exit.is_open: floor_exit.close()
	gear.modal.close(); content.close(); survival.clear_room()
	feedback.reset_feedback(); executor.clear_entities(); gear.loot.clear()
	gear.loot.process_mode=Node.PROCESS_MODE_INHERIT
	if is_instance_valid(room): remove_child(room); room.queue_free()
	room_number=number; stage=number; wave=1
	boss=null; reward_chest=null; branch_chest=null; portal_active=false; portal_visual=null; _summons_created=false
	processed_deaths.clear()
	room=RoomScript.new() as DungeonRoom; room.room_number=number; add_child(room)
	PlayerTravel.relocate(player,Catalog.ENTRY,PlayerTravel.Kind.INTRA_EXPEDITION)
	_apply_room_camera()
	player.controls_enabled=true
	if number==Catalog.FLOOR_COUNT:
		boss=load(BOSS_SCENE).instantiate() as BossGolem
		boss.position=Vector2(870,640); boss.player=player; boss.feedback=feedback
		room.add_child(boss)
		if survival.enabled: survival._attach_condition(boss)
		boss.phase_two_started.connect(_summon_adds); boss.defeated.connect(_boss_defeated)
		reward_chest=TreasureChest.new(); reward_chest.player=player; reward_chest.spawner=gear.loot
		reward_chest.locked=true; reward_chest.large=true; reward_chest.position=Vector2(980,640)
		room.add_child(reward_chest)
	else:
		_spawn_wave()
		_spawn_branch_chest(number)
	transition_pending=false
	presentation.rebuild(number==Catalog.FLOOR_COUNT)
	_apply_depth_presentation()
	return true
func _apply_room_camera() -> void:
	var camera: Camera2D=player.get_node("Camera2D") as Camera2D
	camera.limit_left=32; camera.limit_right=roundi(Catalog.room_width(room_number))-32
	camera.limit_top=0; camera.limit_bottom=720
	camera.reset_smoothing(); camera.force_update_scroll()
func _spawn_branch_chest(number: int) -> void:
	var at: Vector2=Catalog.branch_chest_point(number)
	if at==Vector2.ZERO or _opened_branch_chests.has(number): return
	branch_chest=TreasureChest.new(); branch_chest.name="DepthBranchChest"
	branch_chest.player=player; branch_chest.spawner=gear.loot; branch_chest.position=at
	branch_chest.opened.connect(_branch_chest_opened.bind(number))
	room.add_child(branch_chest)
func _branch_chest_opened(number: int) -> void:
	# Run-local ownership: revisiting/rebuilding this room cannot refresh the same chest.
	_opened_branch_chests[number]=true
func _apply_depth_presentation() -> void:
	presentation.foyer_art.clear()
	# WorldCampaign ancestry may attach its legacy raster; depth owns its own full room art.
	var inherited_raster: Node=room.get_node_or_null("ExistingMapRaster")
	if inherited_raster!=null:
		inherited_raster.call("clear"); room.remove_child(inherited_raster); inherited_raster.queue_free()
	var data: Dictionary=Catalog.floor_data(room_number)
	presentation.atmosphere.ambient.color=data["ambient"]
	for child: Node in presentation.atmosphere.room_art.get_children():
		if child is DungeonBackdrop: (child as CanvasItem).hide()
	var width_ratio: float=Catalog.room_width(room_number)/1280.0
	for light: PointLight2D in presentation.atmosphere.torches:
		light.color=data["palette"].lightened(.25); light.energy=1.0
		var holder: Node2D=light.get_parent() as Node2D
		holder.position.x*=width_ratio
	var dust: GPUParticles2D=presentation.atmosphere.dust
	dust.position.x=Catalog.room_width(room_number)*.5
	dust.visibility_rect=Rect2(-Catalog.room_width(room_number)*.5-40,-400,Catalog.room_width(room_number)+80,800)
	(dust.process_material as ParticleProcessMaterial).emission_box_extents.x=Catalog.room_width(room_number)*.5
func _spawn_depth_enemy(number: int,location: Vector2) -> BaseEnemy:
	var enemy: BaseEnemy=load(ENEMY_SCENE).instantiate() as BaseEnemy
	enemy.set("depth_floor",number); enemy.position=location
	enemy.player=player; enemy.combat_feedback=feedback
	enemy.is_elite=number==4
	room.add_child(enemy)
	if survival.enabled: survival._attach_condition(enemy)
	enemy.defeated.connect(_depth_enemy_died)
	return enemy
func _spawn_wave() -> void:
	if _opening_active:
		super._spawn_wave(); return
	for location: Vector2 in Catalog.enemy_anchors(room_number): _spawn_depth_enemy(room_number,location)
func _summon_adds() -> void:
	if _opening_active:
		super._summon_adds(); return
	if _summons_created or room_number!=Catalog.FLOOR_COUNT or outcome!=&"": return
	_summons_created=true
	_spawn_depth_enemy(4,Vector2(550,640)); _spawn_depth_enemy(4,Vector2(1030,640))
func _depth_enemy_died(enemy: BaseEnemy) -> void:
	var id: int=enemy.get_instance_id()
	if processed_deaths.has(id): return
	processed_deaths[id]=true; depth_deaths+=1
	_spawn_depth_loot.call_deferred(enemy.global_position,enemy.enemy_type,enemy.is_elite,room.get_instance_id())
	_check_clear.call_deferred()
func _spawn_depth_loot(location: Vector2,enemy_id: StringName,elite: bool,room_id: int) -> void:
	if outcome!=&"" or not is_instance_valid(room) or room.get_instance_id()!=room_id: return
	gear.loot.enemy_drop(location,enemy_id,elite,false)
func _check_clear() -> void:
	if _opening_active:
		super._check_clear(); return
	if outcome!=&"" or room_number==Catalog.FLOOR_COUNT or not living_enemies().is_empty(): return
	room.set_locked(false)
	if not _cleared_floors.has(room_number):
		_cleared_floors[room_number]=true
		_record_depth_event(StringName("depth_floor_%d" % room_number),room_number)
		depth_floor_cleared.emit(room_number)
	if survival.enabled: survival.place_campfire(Catalog.camp_point(room_number))
func advance_room() -> bool:
	if _opening_active:
		if has_pending_rewards() or transition_pending: return false
		if stage<4: return super.advance_room()
		return _continue_to_depth()
	if not is_instance_valid(room) or room.locked or room_number>=Catalog.FLOOR_COUNT or transition_pending or outcome!=&"" or gear.modal.is_open or content.panel_open or has_pending_rewards() or (is_instance_valid(floor_exit) and floor_exit.is_open): return false
	transition_pending=true
	var accepted: bool=enter_room(room_number+1)
	if not accepted: transition_pending=false
	return accepted
func _finish_boss() -> void:
	# Ignore delayed callbacks after their defeated boss/room has been replaced.
	if not is_instance_valid(boss) or boss.health.current_health>0.0: return
	if _opening_active:
		super._finish_boss()
		if is_instance_valid(portal_visual):
			for child: Node in portal_visual.get_children():
				if child is Label: child.text="E · ĐI SÂU / TRỞ VỀ SẢNH"
		return
	if outcome!=&"" or portal_active or not is_instance_valid(boss): return
	# Reuse the finite existing boss loot, never the old Golem proof or opening receipt.
	_spawning_boss_rewards=true
	gear.loot.enemy_drop(boss.global_position,&"depth_seal_warden",false,true)
	_spawning_boss_rewards=false
	for enemy: Node2D in living_enemies(): enemy.queue_free()
	for hazard: Node in get_tree().get_nodes_in_group(&"enemy_hazards"):
		if room.is_ancestor_of(hazard): hazard.queue_free()
	room.set_locked(false); reward_chest.unlock(); portal_active=true
	portal_visual=Polygon2D.new(); portal_visual.name="DepthReturnPortal"; portal_visual.position=Vector2(1160,590)
	portal_visual.polygon=PackedVector2Array([Vector2(-24,-50),Vector2(24,-50),Vector2(24,50),Vector2(-24,50)])
	portal_visual.color=Color(.63,.42,.85,.7); room.add_child(portal_visual)
	_cleared_floors[room_number]=true
	_record_depth_event(&"depth_floor_5",5); _record_depth_event(&"depth_boss_defeated",5)
	depth_floor_cleared.emit(5); depth_completed.emit(); pending_save_changed.emit()
func _on_pickup_spawned(pickup: LootPickup) -> void:
	super._on_pickup_spawned(pickup)
	if not _opening_active: pickup.opening_reward=false
func record_opening_milestone(id: StringName) -> void:
	if _opening_active: super.record_opening_milestone(id)
func _record_depth_event(id: StringName,number: int) -> void:
	if not Catalog.valid(number) or id != StringName("depth_floor_%d" % number) and not (id==&"depth_boss_defeated" and number==5): return
	depth_event.emit(id,number)
	if depth_progress_committer.is_valid() and not bool(depth_progress_committer.call(id,number)):
		_depth_events_pending[id]=number; pending_save_changed.emit()
func pending_reward_state() -> Dictionary:
	var state: Dictionary=super.pending_reward_state()
	state["objective_count"]=int(state["objective_count"])+_depth_events_pending.size()
	state["depth_objective_count"]=_depth_events_pending.size()
	return state
func has_pending_rewards() -> bool: return super.has_pending_rewards() or not _depth_events_pending.is_empty()
func retry_pending_rewards() -> bool:
	if _reward_retry_busy: return false
	# The inherited owner retries Golem proof, opening milestones and pickup escrow first.
	super.retry_pending_rewards()
	_reward_retry_busy=true
	if depth_progress_committer.is_valid():
		for id: StringName in _depth_events_pending.keys():
			if bool(depth_progress_committer.call(id,_depth_events_pending[id])): _depth_events_pending.erase(id)
	var complete: bool=not has_pending_rewards()
	_reward_retry_busy=false
	pending_save_changed.emit()
	return complete
func _physics_process(_delta: float) -> void:
	if _opening_active:
		super._physics_process(_delta); return
	if outcome!=&"" or gear==null or not is_instance_valid(room): return
	if player.global_position.y>850.0: player.health.apply_damage(999.0)
	elif not portal_active and not room.locked and player.global_position.x>Catalog.exit_point(room_number).x-10.0 and player.controls_enabled and Input.is_action_just_pressed(&"interact") and not gear.modal.is_open:
		floor_exit.open(); _refresh_depth_exit()
func _process(_delta: float) -> void:
	if _opening_active:
		super._process(_delta)
		if title!=null: title.text="%s · TẦNG %d/8" % [STAGE_NAMES[stage-1],global_floor_number()]
		return
	if gear==null or not is_instance_valid(room): return
	hp_bar.max_value=player.health.maximum_health; hp_bar.value=player.health.current_health
	energy_bar.value=player.energy.current
	var data: Dictionary=Catalog.floor_data(room_number)
	title.text="%s · TẦNG %d/8" % [data["name"],global_floor_number()]
	boss_panel.visible=room_number==5 and is_instance_valid(boss) and boss.health.current_health>0.0
	if boss_panel.visible:
		boss_hp.max_value=boss.health.maximum_health; boss_hp.value=boss.health.current_health
		boss_stagger.value=boss.stagger; boss_name.text="Huyền Uyên Chấp Ấn"
		presentation.art_hud.boss_name.text=boss_name.text
	if is_instance_valid(depth_heading):
		var compact: bool=get_viewport_rect().size.x<1000
		depth_heading.text="%s · TẦNG %d/8" % [String(data["name"]).split(" · ")[0],global_floor_number()] if compact else title.text
		depth_heading.tooltip_text=String(data["tactic"])
		depth_tactic.text=data["tactic"]
		depth_gate.text="Phong ấn còn giữ · %d mục tiêu" % living_enemies().size() if room.locked else "Rương đã mở khóa · E ở cổng để trở về sảnh" if portal_active else "Tầng đã dọn · E tại lối phải: đi tiếp / về / ở lại nhặt"
	if portal_active and outcome==&"" and player.controls_enabled and Input.is_action_just_pressed(&"interact") and player.global_position.distance_to(Catalog.PORTAL)<90.0:
		floor_exit.open()
	_refresh_depth_exit()
func can_choose_floor_exit() -> bool:
	if _opening_active: return super.can_choose_floor_exit()
	if outcome!=&"" or transition_pending or not is_instance_valid(room) or room.locked or player.health.current_health<=0.0 or gear.modal.is_open or content.panel_open: return false
	return player.global_position.distance_to(Catalog.PORTAL)<90.0 if portal_active else room_number<5 and living_enemies().is_empty() and player.global_position.x>Catalog.exit_point(room_number).x-10.0
func _refresh_depth_exit() -> void:
	if _opening_active: return
	if not is_instance_valid(floor_exit) or not floor_exit.is_open: return
	if outcome!=&"": return # Existing save failure/retry notice remains canonical.
	floor_exit.continue_button.disabled=has_pending_rewards()
	floor_exit.heading.text="ĐÃ HẠ THỦ LĨNH U MINH THÁP" if portal_active else "ĐÃ DỌN TẦNG %d/8" % global_floor_number()
	floor_exit.notice.text="Mang về đồ đã nhặt và Linh Thạch đang mang. Đồ còn trên đất không tự thu. Gặp Lạc Ấn để chọn lại tầng đã hoàn tất cho chuyến sau."
	if not portal_active: floor_exit.notice.text+="\nChưa hạ thủ lĩnh tầng 8; trở về lúc này kết thúc chuyến đi sớm."
func _build_depth_hud() -> void:
	var canvas:=CanvasLayer.new(); canvas.layer=16; add_child(canvas)
	depth_hud=PanelContainer.new(); depth_hud.name="DepthFloorGuide"; depth_hud.mouse_filter=Control.MOUSE_FILTER_IGNORE
	depth_hud.theme=AntiqueSkin.make_theme(); depth_hud.add_theme_stylebox_override("panel",AntiqueSkin.panel_style(12)); canvas.add_child(depth_hud)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",4); depth_hud.add_child(column)
	depth_heading=DungeonUI.label("",18,AntiqueSkin.WARM); depth_heading.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; depth_heading.mouse_filter=Control.MOUSE_FILTER_PASS; column.add_child(depth_heading)
	depth_tactic=DungeonUI.label("",14); depth_tactic.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(depth_tactic)
	depth_gate=DungeonUI.label("",14,AntiqueSkin.JADE); depth_gate.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; column.add_child(depth_gate)
func _resize_depth_hud() -> void:
	if not is_instance_valid(depth_hud): return
	var extent: Vector2=get_viewport_rect().size
	var compact: bool=extent.x<1000
	depth_tactic.visible=not compact
	depth_gate.visible=not compact
	depth_heading.add_theme_font_size_override("font_size",15 if compact else 18)
	depth_hud.position=Vector2(400,20)
	depth_hud.custom_minimum_size.x=maxf(180,extent.x-420) if compact else minf(540,extent.x-660)
	depth_hud.size.x=depth_hud.custom_minimum_size.x
	depth_hud.size.y=0

func is_opening_segment() -> bool: return _opening_active
func global_floor_number() -> int:
	return (1 if stage<=2 else stage-1) if _opening_active else room_number+3
func can_continue_to_depth() -> bool:
	return _opening_active and stage==4 and portal_active and outcome==&"" and is_instance_valid(room) and not room.locked and player.health.current_health>0.0 and not transition_pending
func _continue_to_depth() -> bool:
	if not can_continue_to_depth() or has_pending_rewards() or gear.modal.is_open or content.panel_open or (is_instance_valid(floor_exit) and floor_exit.is_open): return false
	if not ResourceLoader.exists(ENEMY_SCENE) or not depth_entry_authorizer.is_valid() or not bool(depth_entry_authorizer.call()): return false
	transition_pending=true
	_opening_active=false
	var old_stage: int=stage
	stage=0
	var accepted: bool=enter_room(1)
	if not accepted:
		_opening_active=true; stage=old_stage; transition_pending=false
	elif is_instance_valid(depth_hud): depth_hud.show()
	return accepted
