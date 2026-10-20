extends SceneTree
## Bounded 1/4/12-actor VFX stress fixture; AI/positions fixed equally in A/B.
## Actual status controllers and actor-owned VFX; no claim these are natural spawns.
var level: Node2D
var actors: Array[SlimeEnemy]=[]
var owned_ids: Array[int]=[]
var evidence: String
var checks: int=0
var failures: int=0
var draw_started: int=0
var draw_ms: float=0.0
var source: Node2D
func _initialize() -> void:_run.call_deferred()
func _check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1
	print(("PASS: " if ok else "FAIL: ")+label)
func _step(n: int) -> void:
	for _i: int in n:await physics_frame;await process_frame
func _pre() -> void:draw_started=Time.get_ticks_usec()
func _post() -> void:draw_ms=(Time.get_ticks_usec()-draw_started)/1000.0
func _ignite(n: int) -> void:
	for i: int in n:
		var enemy: SlimeEnemy=actors[i]
		var event:=DamageEvent.new();event.source_id=source.get_instance_id();event.source_team_id=1;event.target_id=enemy.get_instance_id();event.attack_id=CombatIds.next_id();event.root_event_id=event.attack_id;event.burn_damage=0.1;event.burn_duration=1.1;event.burn_interval=0.5
		enemy.statuses.apply(event)
func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	_check(DisplayServer.get_name()!="headless" and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Native multi-emitter fixture isolated")
	if failures:quit(2);return
	root.unfocusable=true;root.current_screen=mini(1,DisplayServer.get_screen_count()-1);root.size=Vector2i(1152,648);Engine.max_fps=120;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	evidence=OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	level=preload("res://scenes/test_level.tscn").instantiate();root.add_child(level)
	level.survival.director.automatic=false;level.combat_feedback.hit_stop_seconds=0.0;level.combat_feedback.shake_strength=0.0
	for enemy: SlimeEnemy in level.enemies:enemy.ai_enabled=false
	source=Node2D.new();level.add_child(source)
	for i: int in 12:
		var enemy: SlimeEnemy=preload("res://scenes/enemies/slime_enemy.tscn").instantiate() as SlimeEnemy
		enemy.name="BurnStress%02d"%i;enemy.position=Vector2(300+(i%6)*150,620-floori(float(i)/6.0)*100);enemy.ai_enabled=false;enemy.combat_feedback=level.combat_feedback;level.add_child(enemy);enemy.statuses.combat_feedback=level.combat_feedback
		level.presentation._bind_actor(enemy);actors.append(enemy);owned_ids.append(enemy.get_instance_id())
	await _step(30)
	var initial_emitters: Array[int]=[]
	for enemy: SlimeEnemy in actors:
		var visual: ElementAfflictionVFX=enemy.get_node("ElementAfflictionVFX") as ElementAfflictionVFX
		var cpu: Node=visual.get_node_or_null("BurnEmbersCompatibility")
		initial_emitters.append(cpu.get_instance_id() if cpu!=null else visual.burn.get_instance_id())
		owned_ids.append(visual.get_instance_id());owned_ids.append(initial_emitters.back())
	RenderingServer.frame_pre_draw.connect(_pre);RenderingServer.frame_post_draw.connect(_post)
	var results: Array[Dictionary]=[]
	for count: int in [1,4,12]:
		for enemy: SlimeEnemy in actors:enemy.statuses.clear()
		await _step(75)
		var before: int=Time.get_ticks_usec();var rows: Array[Dictionary]=[];var max_burning: int=0;var max_cpu: int=0
		for frame: int in 960:
			await process_frame
			var now: int=Time.get_ticks_usec();var burning: int=0;var cpu_burning: int=0
			for i: int in count:
				var visual: ElementAfflictionVFX=actors[i].get_node("ElementAfflictionVFX") as ElementAfflictionVFX
				if visual.burn_visible:
					burning+=1
					var cpu: CPUParticles2D=visual.get_node_or_null("BurnEmbersCompatibility") as CPUParticles2D
					if cpu!=null and cpu.emitting and cpu.visible:cpu_burning+=1
			max_burning=maxi(max_burning,burning);max_cpu=maxi(max_cpu,cpu_burning)
			rows.append({"frame":frame,"from_usec":before,"to_usec":now,"frame_ms":(now-before)/1000.0,"draw_ms":draw_ms,"burning":burning,"cpu_burning":cpu_burning,"time_scale":Engine.time_scale});before=now
			if frame%240==0:
				for i: int in count:actors[i].position.x+=10.0 if floori(float(frame)/240.0)%2==0 else -10.0
				_ignite(count)
		_check(max_burning==count,"All %d actors actually enter live burn during four retriggers"%count)
		_check(max_cpu==count if not "--baseline" in OS.get_cmdline_user_args() else max_cpu==0,"Every active source uses exactly its expected backend")
		results.append({"actor_count":count,"particle_budget":count*9,"max_burning":max_burning,"max_cpu":max_cpu,"samples":rows})
	for i: int in actors.size():
		var visual: ElementAfflictionVFX=actors[i].get_node("ElementAfflictionVFX") as ElementAfflictionVFX
		var cpu: Node=visual.get_node_or_null("BurnEmbersCompatibility")
		_check((cpu.get_instance_id() if cpu!=null else visual.burn.get_instance_id())==initial_emitters[i],"Repeated multi-source cycles preserve emitter identity %d"%i)
	level.queue_free();level=null;actors.clear();await _step(8)
	_check(owned_ids.all(func(id: int)->bool:return not is_instance_id_valid(id)),"All twelve actor/VFX/emitter owners are freed after teardown")
	RenderingServer.frame_pre_draw.disconnect(_pre);RenderingServer.frame_post_draw.disconnect(_post)
	var f:=FileAccess.open(evidence.path_join("multi.json"),FileAccess.WRITE);f.store_string(JSON.stringify({"checks":checks,"failures":failures,"resolution":root.size,"physics_hz":60,"render_cap":120,"vsync":DisplayServer.window_get_vsync_mode(),"engine":Engine.get_version_info(),"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"results":results,"fixture":"Same existing test-level background/lights/actor art,12 added AI-disabled real Slimes;1/4/12 live status-owned burns,4on/off+10px moves per cohort; no screenshots/readback, no gameplay claim, no changes to damage/engine/driver."},"\t"));f.close()
	await root.get_node("AudioManager").shutdown();print("RESULT BurnMulti checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
