extends SceneTree
## Fresh synthetic first loop through viewport inputs. No grants, warps, HP
## floors, direct damage, enemy clock edits or forced loot/quest outcomes.
const Sink = preload("res://tests/part1_timing_sink.gd")
class CombatBot:
	extends Node
	var run: DungeonRun
	var tick: int = 0
	var enabled: bool = false
	var jump_until: int=0
	var releases: Array[StringName] = []
	func action(id: StringName, down: bool) -> void:
		var event := InputEventAction.new();event.action=id;event.pressed=down;Input.parse_input_event(event)
	func stop() -> void:
		enabled=false
		for id: StringName in [&"attack",&"spell_cast",&"jump",&"dash",&"move_left",&"move_right"]:action(id,false)
		releases.clear()
	func _physics_process(_delta: float) -> void:
		for id: StringName in releases:action(id,false)
		releases.clear()
		if not enabled or not is_instance_valid(run) or run.outcome!=&"" or not run.player.controls_enabled:return
		tick+=1
		if tick>=jump_until:action(&"jump",false)
		var enemies: Array[Node2D]=run.living_enemies()
		if enemies.is_empty():action(&"move_left",false);action(&"move_right",false);return
		var target: Node2D=enemies[0]
		for enemy: Node2D in enemies:
			if enemy.global_position.distance_squared_to(run.player.global_position)<target.global_position.distance_squared_to(run.player.global_position):target=enemy
		var difference: Vector2=target.global_position-run.player.global_position
		var event := InputEventMouseMotion.new();event.position=target.get_global_transform_with_canvas()*Vector2(0,-26);get_tree().root.push_input(event,true)
		var direction: float=signf(difference.x)
		var move: bool=absf(difference.x)>42.0
		action(&"move_left",move and direction<0);action(&"move_right",move and direction>0)
		if tick%12==0 and absf(difference.x)<105 and absf(difference.y)<100:
			action(&"attack",true);releases.append(&"attack")
		if tick%90==10 and run.player.energy.current>=30.0:
			action(&"spell_cast",true);releases.append(&"spell_cast")
		if difference.y < -55 and tick%45==0:
			action(&"jump",true);jump_until=tick+12
		var dangerous: bool=false
		for enemy: Node2D in enemies:
			if enemy is BaseEnemy and enemy.global_position.distance_to(run.player.global_position)<170:
				var mob: BaseEnemy=enemy as BaseEnemy
				if mob.state_machine.get_state_id()==&"attack" or (mob.state_machine.get_state_id()==&"telegraph" and mob.state_time>=mob.definition.windup-0.13):dangerous=true
			elif enemy is BossGolem:
				var boss: BossGolem=enemy as BossGolem
				dangerous=boss.fsm.get_state_id() in [&"sweep",&"orbs",&"stomp"] and boss.state_time>0.42
		if dangerous and run.player.motor.is_grounded():action(&"jump",true);jump_until=tick+12
		if dangerous and absf(difference.x)<180 and run.player.motor.can_dash() and run.player.energy.current>=25.0:
			action(&"move_left",direction<0);action(&"move_right",direction>=0);action(&"dash",true);releases.append(&"dash")

var flow: GameFlow
var bot: CombatBot
var checks: int=0
var failures: int=0
var phase: String="load"
var evidence: String
var native: bool=false
var rows: Array[Dictionary]=[]
var stages: Array[Dictionary]=[]
var before_usec: int=0
var draw_start: int=0
var draw_ms: float=0.0
var measuring: bool=true
var profile_path: String
var start_usec: int=0
var attempts: int=0

func _initialize() -> void:_run.call_deferred()
func _pre() -> void:draw_start=Time.get_ticks_usec()
func _post() -> void:draw_ms=(Time.get_ticks_usec()-draw_start)/1000.0
func _sample() -> void:
	var now: int=Time.get_ticks_usec()
	if before_usec>0 and measuring and rows.size()<90000:
		var run: DungeonRun=flow.active_scene as DungeonRun if is_instance_valid(flow) else null
		rows.append({"from_usec":before_usec,"to_usec":now,"ms":(now-before_usec)/1000.0,"draw_ms":draw_ms,"phase":phase,"scale":Engine.time_scale,"frozen":run.feedback.is_frozen() if run!=null else false,"hp":run.player.health.current_health if run!=null else -1.0,"enemies":run.living_enemies().size() if run!=null else 0,"process_cpu_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000.0})
	before_usec=now
func _stage(label: String) -> void:
	phase=label;var entry: Dictionary={"label":label,"at_usec":Time.get_ticks_usec(),"elapsed_s":(Time.get_ticks_usec()-start_usec)/1000000.0}
	stages.append(entry);print("LOOP_STAGE "+JSON.stringify(entry))
func _check(ok: bool,label: String) -> bool:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
	return ok
func _step(count: int) -> void:
	for _i: int in count:await physics_frame;await process_frame
func _key(code: Key) -> void:
	for pressed: bool in [true,false]:
		await physics_frame
		var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=pressed;Input.parse_input_event(event);await _step(2)
func _click(button: Button) -> void:
	if not _check(button!=null and button.is_visible_in_tree() and not button.disabled,"Actual requested button is visible and enabled"):return
	var point: Vector2=button.get_global_rect().get_center()
	await _mouse(point)
func _mouse(point: Vector2) -> void:
	var motion:=InputEventMouseMotion.new();motion.position=point;root.push_input(motion,true)
	for pressed: bool in [true,false]:
		var event:=InputEventMouseButton.new();event.position=point;event.button_index=MOUSE_BUTTON_LEFT;event.pressed=pressed;root.push_input(event,true);await _step(2)
func _walk(player: Player,x: float,maximum_ticks: int=1200) -> bool:
	for _i: int in maximum_ticks:
		if not is_instance_valid(player) or player.health.current_health<=0:return false
		var diff: float=x-player.global_position.x
		if absf(diff)<9.0:bot.action(&"move_left",false);bot.action(&"move_right",false);await _step(2);return true
		bot.action(&"move_left",diff<0);bot.action(&"move_right",diff>0)
		var aim:=InputEventMouseMotion.new();aim.position=player.get_global_transform_with_canvas()*Vector2(signf(diff)*80,-26);root.push_input(aim,true)
		await _step(1)
	bot.stop();return _check(false,"Walking reached its physical target within the bounded tick budget")
func _dialogue_ready(hub: PrologueHub) -> void:
	for _i: int in 40:
		if not hub.dialogue.is_open:return
		if hub.dialogue.page_index==hub.dialogue.pages.size()-1 and not hub.dialogue.is_typing():return
		await _key(KEY_E)
func _talk(hub: PrologueHub,id: StringName) -> bool:
	if not await _walk(hub.player,hub.stations[id].global_position.x):return false
	await _key(KEY_E);await _step(3)
	if not _check(hub.dialogue.is_open and hub.current_npc==id,"E opens the actual intended NPC dialogue"):return false
	await _dialogue_ready(hub);return true
func _shot(label: String) -> void:
	if not native:return
	measuring=false;await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(evidence.path_join(label+".png"))==OK,"Runtime screenshot saved: "+label)
	await _step(3);measuring=true;before_usec=Time.get_ticks_usec()
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/").trim_suffix("/")
	native=DisplayServer.get_name()!="headless"
	if not _check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") and (not native or "--native-approved" in OS.get_cmdline_user_args()),"Explicit native permission and synthetic user directory"):quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=120;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT");start_usec=Time.get_ticks_usec();profile_path="user://part1-first-loop/profile.json"
	process_frame.connect(_sample);RenderingServer.frame_pre_draw.connect(_pre);RenderingServer.frame_post_draw.connect(_post);Sink.events.clear();Sink.enabled=true
	bot=CombatBot.new();root.add_child(bot)
	flow=preload("res://scenes/maps/prologue_hub.tscn").instantiate() as GameFlow;flow.save_path_override=profile_path;root.add_child(flow);await _step(40)
	var hub: PrologueHub=flow.active_scene as PrologueHub
	_check(not flow.qa_tools_enabled and flow.profile.souls==0 and not flow.profile.bounty_accepted,"Fresh product save has no grants or accepted quest")
	_stage("accept_quest")
	if not await _talk(hub,NpcCatalog.WANDERER):await _finish(false);return
	await _click(hub.dialogue.choice_list.get_node_or_null("Choice_bounty_accept") as Button);await _step(4)
	_check(flow.profile.bounty_accepted,"Bounty accepted through actual viewport choice")
	await _key(KEY_ESCAPE);await _shot("quest_accepted")
	for attempt: int in 4:
		attempts=attempt+1;hub=flow.active_scene as PrologueHub
		_stage("departure_%d"%attempts)
		if not await _walk(hub.player,hub.stations[&"portal"].global_position.x):await _finish(false);return
		await _key(KEY_E);await _step(8)
		if not _check(flow.active_scene is DungeonRun,"Actual portal E begins a dungeon run"):await _finish(false);return
		var won: bool=await _expedition()
		if won and flow.profile.souls>=20:break
		for _i: int in 600:
			if flow.active_scene is PrologueHub:break
			await _step(1)
		if not flow.active_scene is PrologueHub:await _finish(false);return
		if flow.profile.boss_proofs[&"golem"]>=1 and flow.profile.souls>=20:break
		_stage("additional_run_to_afford_existing_upgrade")
	if not flow.active_scene is PrologueHub:await _finish(false);return
	if not _check(flow.profile.boss_proofs[&"golem"]>=1,"Fresh input-driven run defeats Golem before the successful return"):await _finish(false);return
	hub=flow.active_scene as PrologueHub;_stage("upgrade")
	if not await _talk(hub,NpcCatalog.HEALER):await _finish(false);return
	var quote: Dictionary=hub.economy.quote_upgrade(&"max_hp")
	if not _check(quote.get("can_buy",false),"Actually collected loot funds the existing HP upgrade"):await _shot("upgrade_unfunded");await _finish(false);return
	var hp: float=hub.player.health.maximum_health;var souls: int=flow.profile.souls
	var button: Button=hub.dialogue.choice_list.get_node_or_null("Choice_upgrade_max_hp") as Button
	hub.dialogue.body_scroll.ensure_control_visible(button);await _step(3);await _click(button)
	_check(hub.dialogue.confirmation.visible and flow.profile.souls==souls,"Upgrade asks confirmation before spending")
	hub.dialogue.body_scroll.ensure_control_visible(hub.dialogue.confirm_button);await _step(3);await _click(hub.dialogue.confirm_button);await _step(4)
	_check(flow.profile.permanent_upgrades[&"max_hp"]==1 and is_equal_approx(hub.player.health.maximum_health,hp+10.0) and flow.profile.souls==souls-int(quote["cost"]) and flow.profile.last_save_ok,"Actual upgrade spends its quote and durably raises maximum HP")
	await _key(KEY_ESCAPE);await _shot("upgraded_and_saved");await _finish(true)
func _expedition() -> bool:
	var run: DungeonRun=flow.active_scene as DungeonRun;bot.run=run
	_check(run.player.health.minimum_health==0.0,"Dungeon retains the real lethal health floor")
	var cleared: int=0
	while cleared<4:
		_stage("combat_%d"%(cleared+1));bot.enabled=true
		for _i: int in 60*180:
			if run.outcome!=&"" or (run.living_enemies().is_empty() and not run.room.locked):break
			await _step(1)
		bot.stop()
		if run.outcome==&"defeat":_stage("defeat");return false
		if not _check(run.living_enemies().is_empty() and not run.room.locked,"Combat actually clears its enemy roster"):return false
		await _step(8);_stage("collect_%d"%(cleared+1))
		for _pick: int in 30:
			var nearest: LootPickup
			for child: Node in run.gear.loot.get_children():
				if child is LootPickup and not child.collected_once and (nearest==null or absf(child.global_position.x-run.player.global_position.x)<absf(nearest.global_position.x-run.player.global_position.x)):nearest=child
			if nearest==null:break
			if not await _walk(run.player,nearest.global_position.x,600):return false
			await _key(KEY_E);await _step(8)
		await _shot("cleared_%d"%(cleared+1))
		await _recover(run)
		_stage("transition_%d"%(cleared+1))
		if not await _walk(run.player,1160.0 if run.portal_active else 1240.0):return false
		print("EXIT_INPUT "+JSON.stringify({"position":str(run.player.global_position),"controls":run.player.controls_enabled,"can_choose":run.can_choose_floor_exit(),"room":run.room_number,"locked":run.room.locked,"modal":run.gear.modal.is_open,"content":run.content.panel_open}))
		await _key(KEY_E);await _step(4)
		if not _check(run.floor_exit.is_open,"E opens the canonical completed-floor choice"):return false
		if run.portal_active:
			await _click(run.floor_exit.return_button)
			for _i: int in 600:
				if flow.active_scene is PrologueHub:_stage("returned");return true
				await _step(1)
			return false
		await _click(run.floor_exit.continue_button);await _step(6);cleared+=1
	return false
func _recover(run: DungeonRun) -> void:
	if not is_instance_valid(run.survival.campfire) or run.player.health.current_health>=run.player.health.maximum_health-10:return
	if run.gear.inventory.materials[&"dust"]<4 and run.gear.inventory.consumables[&"potion"]==0:return
	_stage("campfire_recovery")
	if not await _walk(run.player,run.survival.campfire.global_position.x):return
	await _key(KEY_E);await _step(4)
	var panel: SurvivalPanel=run.survival.panel
	if not _check(panel.is_open,"Real campfire opens its existing recovery UI"):return
	var bar: TabBar=panel.tabs.get_tab_bar()
	if run.gear.inventory.materials[&"dust"]>=4:
		await _mouse(bar.get_global_transform()*bar.get_tab_rect(1).get_center());await _step(3)
		for _i: int in 8:
			if run.gear.inventory.materials[&"dust"]<4:break
			await _click(panel.craft_cards[&"potion"] as Button);await _step(3)
	await _mouse(bar.get_global_transform()*bar.get_tab_rect(2).get_center());await _step(3)
	for _i: int in 8:
		if run.gear.inventory.consumables[&"potion"]<=0 or run.player.health.current_health>=run.player.health.maximum_health:break
		await _click(panel.use_cards[&"potion"] as Button);await _step(3)
	await _click(panel.close_button);await _step(3)
func _finish(complete: bool) -> void:
	bot.stop();Sink.enabled=false
	var state: Dictionary={"checks":checks,"failures":failures,"complete_loop":complete,"attempts":attempts,"elapsed_seconds":(Time.get_ticks_usec()-start_usec)/1000000.0,"stages":stages,"frames":rows,"timing_events":Sink.events,"scope":"Automated viewport actions through fresh product flow; no grants/warps/damage/HP/loot overrides. Audio muted; not subjective manual playtest."}
	if is_instance_valid(flow):
		state["profile_path"]=ProjectSettings.globalize_path(flow.profile.save_path);state["souls"]=flow.profile.souls;state["upgrades"]=flow.profile.permanent_upgrades;state["opening"]=flow.profile.opening_objectives();state["inventory"]=flow.profile.hub_inventory;state["profile_sha256"]=FileAccess.get_sha256(flow.profile.save_path)
	var file:=FileAccess.open(evidence.path_join("first_loop.json"),FileAccess.WRITE);file.store_string(JSON.stringify(state,"\t"));file.close()
	measuring=false;bot.queue_free();flow.queue_free();await _step(8);await root.get_node("AudioManager").shutdown()
	print("RESULT Part1FirstLoop checks=%d failures=%d complete=%s attempts=%d"%[checks,failures,complete,attempts]);quit(0 if complete and failures==0 else 1)
