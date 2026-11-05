extends SceneTree
var boot: AmdBoot
var checks: int = 0
var failures: int = 0
var responses: Dictionary = {}

func _initialize() -> void: _run.call_deferred()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; print("FAIL: ",label)
func step(count: int = 3) -> void:
	for index: int in count: await process_frame
func key(value: Key) -> void:
	var press := InputEventKey.new(); press.keycode=value; press.physical_keycode=value; press.pressed=true; root.push_input(press,true)
	await step(1)
	var release := InputEventKey.new(); release.keycode=value; release.physical_keycode=value; release.pressed=false; root.push_input(release,true)
	await step(3)
func click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position=point; root.push_input(motion,true)
	var press := InputEventMouseButton.new(); press.position=point; press.button_index=MOUSE_BUTTON_LEFT; press.pressed=true; root.push_input(press,true)
	await step(1)
	var release := InputEventMouseButton.new(); release.position=point; release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false; root.push_input(release,true)
	await step()
func hit(tag: String, code: int, data: Dictionary, problem: String) -> void:
	responses[tag]={"code":code,"data":data,"problem":problem}
func wait_for(tag: String) -> Dictionary:
	var deadline: int=Time.get_ticks_msec()+10000
	while not responses.has(tag) and Time.get_ticks_msec()<deadline: await process_frame
	var result: Dictionary=responses.get(tag,{})
	responses.erase(tag); check(not result.is_empty(),"response "+tag); return result
func picture(label: String) -> void:
	await RenderingServer.frame_post_draw
	check(root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(label+".png"))==OK,"capture "+label)
func _run() -> void:
	check(AmdSlotStore.isolated() and DisplayServer.get_name()!="headless","native QA isolation")
	Engine.max_fps=120
	boot=preload("res://scenes/amd201_boot.tscn").instantiate() as AmdBoot; root.add_child(boot)
	boot.api.completed.connect(hit)
	await step(4)
	check(boot.menu.is_visible_in_tree() and not is_instance_valid(boot.flow),"auth menu before world")
	await picture("login_1152x648")
	var identity: Variant=AmdSlotStore.read_json("user://amd201-qa-identity.json")
	check(identity is Dictionary,"known synthetic account")
	if not identity is Dictionary: await finish(); return
	boot.email.text=identity["email"]; boot.password.text="Synthetic QA passphrase 3010"
	boot.authenticate(false); var login: Dictionary=await wait_for("login")
	check(login.get("code")==200 and is_instance_valid(boot.flow),"HTTP login opens world under modal")
	if not is_instance_valid(boot.flow): await finish(); return
	await step(5)
	var hero: Player=boot.flow.active_scene.player
	check(boot.flow.process_mode==Node.PROCESS_MODE_DISABLED,"modal stops only owned game flow")
	check(not paused and boot.api.can_process(),"network and app continue while world modal")
	var extent: Vector2=root.get_visible_rect().size
	check(boot.menu.get_global_rect().position.y>=130 and boot.menu.get_global_rect().end.y<extent.y-42,"dialog below HUD and above footer")
	check(boot.menu.get_global_rect().position.x>=0 and boot.menu.get_global_rect().end.x<=extent.x,"dialog fits viewport")
	await picture("account_open_1152x648")
	var position_before: Vector2=hero.global_position
	var casts_before: int=hero.resonance_controller.cast_count
	Input.action_press(&"move_right"); Input.action_press(&"spell_cast"); Input.action_press(&"attack")
	await create_timer(0.25).timeout
	check(hero.global_position==position_before and hero.resonance_controller.cast_count==casts_before,"held movement/cast/attack do not enter world through menu")
	await key(KEY_TAB); await key(KEY_I)
	var focus: Control=root.gui_get_focus_owner()
	check(focus!=null and boot.menu.is_ancestor_of(focus),"Tab focus stays inside cloud dialog")
	# Space intentionally activates a harmless real UI action, not Close/Logout.
	boot.buttons[4].grab_focus(); await key(KEY_SPACE)
	var keyboard_summary: Dictionary=await wait_for("summary")
	check(keyboard_summary.get("code")==200,"Space activates focused cloud action")
	check(not boot.flow.active_scene.gear.modal.is_open and not paused,"Tab cannot open underlying ALWAYS inventory")
	check(hero.resonance_controller.cast_count==casts_before,"keyboard focus actions do not cast")
	# Close with an actual viewport mouse click, which also maps to attack.
	await click(boot.menu_close)
	check(not boot.menu.is_visible_in_tree() and boot.flow.process_mode==Node.PROCESS_MODE_INHERIT,"mouse close restores original world process mode")
	await create_timer(0.10).timeout
	check(hero.resonance_controller.cast_count==casts_before,"close click has no stale cast")
	check(hero.action_state_machine.get_state_id()==&"ready","close click has no stale melee")
	Input.action_press(&"move_right"); await create_timer(0.25).timeout; Input.action_release(&"move_right")
	check(hero.global_position.distance_to(position_before)>30,"fresh movement works after close")
	check(boot.flow.active_scene.gear.modal.process_mode==Node.PROCESS_MODE_ALWAYS,"underlying inventory process override restored exactly")
	await key(KEY_I); await create_timer(0.25).timeout
	check(hero.resonance_controller.cast_count>casts_before,"fresh cast works after closing modal")
	await picture("account_closed_1152x648")
	for repeat: int in 4:
		await key(KEY_F9)
		check(boot.menu.is_visible_in_tree() and boot.flow.process_mode==Node.PROCESS_MODE_DISABLED,"F9 open "+str(repeat))
		await key(KEY_ESCAPE)
		check(not boot.menu.is_visible_in_tree() and boot.flow.process_mode==Node.PROCESS_MODE_INHERIT,"Esc close "+str(repeat))
	await click(boot.menu_toggle)
	check(boot.menu.is_visible_in_tree(),"footer toggle opens modal")
	# Actual window resize, not a contact sheet. Layout stays inside the canvas.
	root.size=Vector2i(960,540); await step(5)
	extent=root.get_visible_rect().size
	check(Rect2(Vector2.ZERO,extent).encloses(boot.menu.get_global_rect()),"dialog fits resized native window")
	await picture("account_open_960x540")
	boot.refresh(); var summary: Dictionary=await wait_for("summary")
	check(summary.get("code")==200,"HTTP still completes while menu freezes world")
	await click(boot.menu_close)
	check(boot.flow.process_mode==Node.PROCESS_MODE_INHERIT,"resize close restores gameplay")
	hero.controls_enabled=false; boot.set_menu_open(true); boot.set_menu_open(false)
	check(not hero.controls_enabled,"closing cloud does not release another control owner's lock")
	hero.controls_enabled=true
	boot.set_menu_open(true)
	boot.logout(); await wait_for("logout")
	check(boot.menu.is_visible_in_tree() and not is_instance_valid(boot.flow),"logout returns focused auth dialog")
	await finish()
func finish() -> void:
	if is_instance_valid(boot): root.remove_child(boot); boot.queue_free()
	await step()
	print("RESULT AMD_MENU checks=%d failures=%d" % [checks,failures])
	quit(0 if failures==0 else 1)
