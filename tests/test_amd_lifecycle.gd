extends SceneTree
var checks: int = 0
var failures: int = 0
var responses: Dictionary = {}
var boot: AmdBoot
var phase: String = "write"
const PASS: String = "Synthetic QA passphrase 3010"

func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("phase="): phase = argument.trim_prefix("phase=")
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ", label)

func wait_for(tag: String) -> Dictionary:
	var deadline: int = Time.get_ticks_msec() + 10000
	while not responses.has(tag) and Time.get_ticks_msec() < deadline: await process_frame
	var result: Dictionary = responses.get(tag,{})
	responses.erase(tag)
	check(not result.is_empty(), "response " + tag)
	return result

func hit(tag: String, code: int, data: Dictionary, problem: String) -> void:
	responses[tag] = {"code":code,"data":data,"problem":problem}

func _run() -> void:
	check(AmdSlotStore.isolated(),"QA userdata isolated before boot")
	boot = preload("res://scenes/amd201_boot.tscn").instantiate() as AmdBoot
	root.add_child(boot)
	boot.api.completed.connect(hit)
	if phase == "combat": await combat_segment()
	elif phase == "edge": await edge_cases()
	elif phase == "read": await cold_read()
	else: await first_write()
	if is_instance_valid(boot): root.remove_child(boot); boot.queue_free()
	await process_frame
	await process_frame
	print("RESULT AMD_LIFECYCLE phase=%s checks=%d failures=%d" % [phase,checks,failures])
	quit(0 if failures == 0 else 1)

func sign_in(address: String, create: bool) -> bool:
	if create:
		boot.email.text = address; boot.password.text = PASS; boot.authenticate(true)
		var registered: Dictionary = await wait_for("register")
		check(registered.get("code") == 201,"register " + address)
	boot.email.text = address; boot.password.text = PASS; boot.authenticate(false)
	var logged: Dictionary = await wait_for("login")
	check(logged.get("code") == 200 and boot.user_id != "" and is_instance_valid(boot.flow),"login opens account-owned flow")
	for index: int in 3: await process_frame
	return boot.user_id != "" and is_instance_valid(boot.flow)

func first_write() -> void:
	var nonce: String = AmdSlotStore.new_id().substr(0,8)
	var email_a: String = "godot-a-" + nonce + "@amd.test"
	if not await sign_in(email_a,true): return
	check(boot.flow.active_scene is ExteriorHub,"real Hub scene")
	check(not boot.flow.qa_tools_enabled,"normal progression, no team unlock")
	var a: String = boot.user_id
	var original: String = boot.flow.profile.save_path
	check(AmdSlotStore.owns(a,original),"profile path belongs to A")
	boot.flow.profile.souls = 321
	boot.flow.profile.coins = 17
	boot.upload()
	var saved: Dictionary = await wait_for("save")
	check(saved.get("code") == 200 and saved.get("problem") == "","Godot capsule accepted by HTTP API")
	check(int(boot.local_slot.get("baseRevision",0)) == 1 and boot.store.pending(a).is_empty(),"save receipt persisted, pending cleared")
	var valid: Dictionary = boot.capsule.capture(boot.flow,a)
	check(not valid.is_empty(),"committed profile and NPC pair captured")
	var broken: Dictionary = valid.duplicate(true)
	broken["files"]["profile"]["text"] += "corrupt"
	check(boot.capsule.stage(broken,a,boot.store) == "","digest corruption rejected")
	broken = valid.duplicate(true); broken["profileSchema"] = 999
	check(boot.capsule.stage(broken,a,boot.store) == "","future schema rejected")
	check(boot.store.read_active(a)["path"] == original,"failed restore leaves active slot unchanged")
	check(not AmdSlotStore.owns(a,"user://sanctuary_v1.json") and not AmdSlotStore.valid_user("../elsewhere"),"personal path and traversal rejected")
	# Keep enough identity for a separate Godot process; no token/password is written.
	var identity: Dictionary = {"email":email_a,"user":a,"original":original}
	var file := FileAccess.open("user://amd201-qa-identity.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(identity)); file.close()
	# A pending request must not freeze the actual Player motor.
	boot.menu.visible = false
	var player: Player = boot.flow.active_scene.player
	var start: Vector2 = player.global_position
	boot.api.send("delay","/api/qa/delay")
	Input.action_press("move_right")
	var started: int = Time.get_ticks_usec()
	var samples: Array[float] = []
	var previous: int = started
	while Time.get_ticks_usec() - started < 1100000:
		await process_frame
		var now: int = Time.get_ticks_usec(); samples.append(float(now-previous)/1000.0); previous=now
	Input.action_release("move_right")
	check(player.global_position.distance_to(start) > 50,"player moves while HTTP pending")
	check(not responses.has("delay"),"2s delay still pending during 1.1s movement")
	samples.sort()
	print("METRIC AMD_HTTP_PENDING frames=%d p50_ms=%.3f p95_ms=%.3f max_ms=%.3f movement=%.2f" % [samples.size(),samples[samples.size()/2],samples[int(samples.size()*0.95)],samples[-1],player.global_position.distance_to(start)])
	var delayed: Dictionary = await wait_for("delay")
	check(delayed.get("code") == 200,"delayed request completed")
	boot.logout()
	await wait_for("logout")
	check(boot.user_id == "" and boot.api.access_token == "" and not is_instance_valid(boot.flow),"logout disposes world and memory token")
	if not await sign_in("godot-b-"+nonce+"@amd.test",true): return
	check(boot.user_id != a and boot.flow.profile.souls != 321 and boot.flow.profile.save_path != original,"B cannot inherit A local progress")
	boot.refresh()
	check((await wait_for("summary")).get("code") == 404,"B cannot read A cloud progress")
	boot.logout(); await wait_for("logout")

func edge_cases() -> void:
	var identity: Variant = AmdSlotStore.read_json("user://amd201-qa-identity.json")
	check(identity is Dictionary,"known synthetic identity")
	if not identity is Dictionary or not await sign_in(identity["email"],false): return
	# Establish the latest legitimate cloud revision before each edge scenario;
	# previous failed QA runs are evidence, never silently reset/overwritten.
	boot.download()
	var initial: Dictionary = await wait_for("load")
	check(initial.get("code") == 200 and boot.status.text.begins_with("Đã tải cloud"),"edge precondition cloud loaded")
	if initial.get("code") != 200 or not boot.status.text.begins_with("Đã tải cloud"): return
	var a: String = boot.user_id
	var active: String = boot.flow.profile.save_path
	var base: int = int(boot.local_slot["baseRevision"])
	var captured: Dictionary = boot.capsule.capture(boot.flow,a)
	check(not captured.is_empty(),"safe real pair capture")
	var pending: Dictionary = boot.store.set_pending(a,{"expectedRevision":base,"capsule":captured})
	check(not pending.is_empty(),"pending transaction persisted before HTTP")
	# Server commits; intentionally do not deliver this acknowledgement to the
	# save UI. This simulates a lost response without changing the backend/store.
	boot.api.send("lost_ack","/api/progress",HTTPClient.METHOD_PUT,pending["body"],pending["operation"])
	check((await wait_for("lost_ack")).get("code") == 200,"first commit reached actual HTTP server")
	check(int(boot.local_slot["baseRevision"]) == base and not boot.store.pending(a).is_empty(),"unacknowledged transaction retained")
	boot.upload(); boot.upload()
	check(boot.api._requests.size() == 1,"double click creates one retry request")
	var replay: Dictionary = await wait_for("save")
	print("METRIC AMD_RETRY status=%d problem=%s revision=%d" % [int(replay.get("code",0)),str(replay.get("problem","")),int(boot.local_slot["baseRevision"])])
	check(replay.get("data",{}).get("replayed") == true and int(boot.local_slot["baseRevision"]) == base+1,"same operation replays once, no duplicate revision")
	check(boot.store.pending(a).is_empty(),"acknowledged pending removed")
	if not boot.store.pending(a).is_empty(): return
	# Focused handler tests inject malformed/older responses; they are not
	# production DB integration claims. No active slot may change.
	var broken: Dictionary = captured.duplicate(true)
	broken["files"]["profile"]["text"] += "corrupt"
	boot._response("load",200,{"revision":base+1,"capsule":broken},"")
	check(boot.flow.profile.save_path == active and boot.store.read_active(a)["path"] == active,"corrupt response leaves local untouched")
	boot._response("load",200,{"revision":base,"capsule":captured},"")
	check(boot.flow.profile.save_path == active and boot.status.text.contains("cũ hơn"),"older cloud revision cannot roll local back")
	broken = captured.duplicate(true)
	var forged: Dictionary = JSON.parse_string(broken["files"]["profile"]["text"])
	forged["coins"] = int(forged.get("coins",0))+1
	broken["files"]["profile"]["text"] = JSON.stringify(forged,"",true,true)
	broken["files"]["profile"]["sha256"] = broken["files"]["profile"]["text"].sha256_text()
	boot._response("load",200,{"revision":base+1,"capsule":broken},"")
	check(boot.flow.profile.save_path == active and boot.status.text.contains("profile_reader_rejected"),"valid digest cannot bypass existing v2 seal")
	var blocker: String = AmdSlotStore.home(a)+"/active.json.tmp"
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(blocker)) == OK,"QA-only write fault directory")
	var unused_slot: String = boot.store.create_slot(a)
	check(not boot.store.activate(a,unused_slot,base+2),"metadata open failure reported")
	check(boot.store.read_active(a)["path"] == active,"write failure preserves active authority")
	check(DirAccess.remove_absolute(ProjectSettings.globalize_path(blocker)) == OK,"remove exact empty QA fault directory")
	check(not boot.api.configure("http://example.com") and not boot.api.configure("https://user:password@example.com"),"remote cleartext/userinfo rejected")
	check(boot.api.configure("http://127.0.0.1:5086"),"loopback allowed")
	boot.api.send("late","/api/qa/delay")
	boot.logout(); await wait_for("logout")
	check(boot.api.access_token == "" and boot.user_id == "","logout clears A memory")
	var b_email: String = identity["email"].replace("godot-a-","godot-b-")
	if not await sign_in(b_email,false): return
	var b: String = boot.user_id
	await create_timer(2.1).timeout
	check(b != a and not responses.has("late") and AmdSlotStore.owns(b,boot.flow.profile.save_path),"late A response cannot affect B")
	boot.refresh(); check((await wait_for("summary")).get("code") == 404,"B still has no A cloud data")
	boot.logout(); await wait_for("logout")

func combat_segment() -> void:
	var identity: Variant = AmdSlotStore.read_json("user://amd201-qa-identity.json")
	check(identity is Dictionary,"synthetic account for normal combat")
	if not identity is Dictionary or not await sign_in(identity["email"],false): return
	boot.download(); await wait_for("load")
	check(boot.status.text.begins_with("Đã tải cloud"),"combat starts from banked cloud gear")
	if not boot.status.text.begins_with("Đã tải cloud"): return
	boot.menu.visible = false
	seed(20261030)
	boot.flow.start_campaign()
	check(boot.flow.active_scene is DungeonRun and not boot.flow.qa_tools_enabled,"normal authored campaign, no unlock tools")
	if not boot.flow.active_scene is DungeonRun: return
	var run: DungeonRun = boot.flow.active_scene
	var hero: Player = run.player
	var start: Vector2 = hero.global_position
	var hp: float = hero.health.current_health
	var initial_no_fixture: bool = hero.health.minimum_health == 0 and not hero.hurtbox.invulnerable
	var damaged: bool = false
	var samples: Array[float] = []
	var hitstop_frames: int = 0
	for warmup: int in 30: await physics_frame
	print("METRIC AMD_COMBAT_SETUP state=%s can_cast=%s recipe=%s slots=%s hp_floor=%.1f initial_invulnerable=%s" % [str(hero.action_state_machine.get_state_id()),str(hero.resonance_controller.can_cast()),str(hero.resonance_controller.get_recipe().id if hero.resonance_controller.get_recipe()!=null else &"none"),str(run.gear.inventory.slots),hero.health.minimum_health,str(not initial_no_fixture)])
	boot.api.send("combat_delay","/api/qa/delay")
	var previous: int = Time.get_ticks_usec()
	for index: int in 420:
		for action: StringName in [&"spell_cast",&"attack",&"move_left",&"move_right"]: Input.action_release(action)
		var enemies: Array = run.living_enemies()
		for enemy: Node2D in enemies:
			damaged = damaged or enemy.health.current_health < enemy.health.maximum_health
		if not enemies.is_empty() and hero.health.current_health > 0:
			var target: Node2D = enemies[0]
			var dx: float = target.global_position.x-hero.global_position.x
			var hurtbox: Hurtbox = target.get_node_or_null("Hurtbox") as Hurtbox
			var aim_point: Vector2 = hurtbox.global_position if hurtbox != null else target.global_position-Vector2(0,20)
			var motion := InputEventMouseMotion.new(); motion.position=hero.get_canvas_transform()*aim_point; root.push_input(motion)
			if absf(dx)>110: Input.action_press(&"move_right" if dx>0 else &"move_left")
			if hero.action_state_machine.get_state_id()==&"ready" and hero.resonance_controller.can_cast():
				var cast_event := InputEventAction.new(); cast_event.action=&"spell_cast"; cast_event.pressed=true; root.push_input(cast_event)
			elif absf(dx)<65 and index%25==0:
				var attack_event := InputEventAction.new(); attack_event.action=&"attack"; attack_event.pressed=true; root.push_input(attack_event)
			damaged = damaged or target.health.current_health < target.health.maximum_health
		await physics_frame
		var now: int = Time.get_ticks_usec(); samples.append(float(now-previous)/1000.0); previous=now
		if hero.combat_feedback.is_frozen(): hitstop_frames += 1
	for action: StringName in [&"spell_cast",&"attack",&"move_left",&"move_right"]: Input.action_release(action)
	check(initial_no_fixture and hero.health.minimum_health == 0,"no HP floor or immunity fixture in campaign; ordinary hurt iframes allowed")
	check(hero.resonance_controller.cast_count>0,"actual input committed casts")
	check(damaged or run.living_enemies().is_empty(),"actual authored enemies take damage")
	check(hero.global_position.distance_to(start)>50,"actual motor traverses campaign")
	check(responses.has("combat_delay") and responses["combat_delay"]["code"]==200,"HTTP completes during combat")
	boot.upload()
	check(not boot.busy and boot.status.text.contains("Trở về Hub"),"cloud upload cannot snapshot a live expedition")
	samples.sort()
	print("METRIC AMD_COMBAT casts=%d hp_before=%.1f hp_after=%.1f p50_physics_ms=%.3f p95_physics_ms=%.3f max_physics_ms=%.3f hitstop_frames=%d" % [hero.resonance_controller.cast_count,hp,hero.health.current_health,samples[samples.size()/2],samples[int(samples.size()*0.95)],samples[-1],hitstop_frames])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("amd_combat.png"))
	boot.api.send("end_session","/api/auth/logout",HTTPClient.METHOD_POST); await wait_for("end_session")
	boot.api.forget_account()

func cold_read() -> void:
	var identity: Variant = AmdSlotStore.read_json("user://amd201-qa-identity.json")
	check(identity is Dictionary,"identity fixture exists after process restart")
	if not identity is Dictionary: return
	if not await sign_in(identity["email"],false): return
	check(boot.flow.profile.souls == 321 and boot.flow.profile.coins == 17,"cold local account reload exact currency")
	boot.download()
	var loaded: Dictionary = await wait_for("load")
	print("METRIC AMD_RESTORE_STATUS ",boot.status.text)
	check(loaded.get("code") == 200 and int(boot.local_slot.get("baseRevision",0)) == int(loaded.get("data",{}).get("revision",-1)),"cold cloud reload matches returned revision")
	check(boot.flow.profile.save_path != identity["original"],"cloud activates a NEW slot")
	check(FileAccess.file_exists(identity["original"]) and FileAccess.file_exists(identity["original"] + NpcWorldState.NPC_SUFFIX),"old profile and NPC retained")
	check(boot.flow.profile.souls == 321 and boot.flow.profile.coins == 17 and boot.flow.npc_life != null and not boot.flow.npc_life.read_only,"cloud pair loads actual existing readers")
	var image: Image = root.get_texture().get_image()
	var capture: String = OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT")
	if not capture.is_empty() and not image.is_empty(): image.save_png(capture.path_join("amd_account_hub.png"))
	boot.logout(); await wait_for("logout")
