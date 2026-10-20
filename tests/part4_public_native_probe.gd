extends "res://tests/part4_causality_runtime_test.gd"
## Native verification of real local reporting and readable relationship journal.
var native_captures: Array[String]=[]
func _choose(id: StringName) -> void:
	await super._choose(id)
	if id==&"pilot_kill_sect":await shot("execution_confirmation")

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join(label+".png"))==OK,"Native screenshot: "+label)
	native_captures.append(label)

func _run() -> void:
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/") or DisplayServer.get_name()=="headless" or not "--native-approved" in OS.get_cmdline_user_args():quit(2);return
	root.unfocusable=true;root.size=Vector2i(1152,648);Engine.max_fps=60;Engine.physics_ticks_per_second=60;AudioServer.set_bus_mute(0,true)
	prefix="user://verification/part4_public_native_"
	await _case("p03");await _execute_du();await _world_time(1)
	_check(not hub.tan_dang.reporting.is_empty(),"Living eyewitness is visibly reporting before publication")
	await shot("report_in_progress")
	await _world_time(2.5)
	var actor: CultivatorActor=hub.npc_population.actors[TanDangProgress.LAM] as CultivatorActor
	await _wait_phase_in_world(actor,"tell",3)
	_check(actor.combat_phase=="tell" and not actor.strike_hitbox.active,"Real published case reaches harmless actual attack tell")
	await shot("reported_retaliation_tell")
	await _key(root,KEY_M)
	var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	screen.journal.relations_button.grab_focus();await _key(root,KEY_ENTER);await _step(4)
	_check(screen.journal.selected_id==&"tan_dang_relations" and "CÁO THỊ SÁT HẠI" in screen.journal.objective_label.text and "Lâm Tước báo tin" in screen.journal.objective_label.text,"Actual relationship page exposes reason/reporter/place after publication")
	for dims: Vector2i in [Vector2i(1152,648),Vector2i(800,600)]:
		if dims.x==800:root.content_scale_size=dims # Explicit compact logical variant only.
		root.size=dims;await _step(5)
		_check(root.get_visible_rect().grow(2).encloses(screen.panel.get_global_rect()),"Modal fits the declared logical viewport")
		_check(screen.panel.get_global_rect().encloses(screen.journal.relations_button.get_global_rect()),"Relationship entry stays inside the antique frame")
		screen.journal.detail_scroll.scroll_vertical=0;await _step(3);await shot("relations_top_%d"%dims.x)
		screen.journal.detail_scroll.scroll_vertical=int(screen.journal.detail_scroll.get_v_scroll_bar().max_value);await _step(3);await shot("relations_public_%d"%dims.x)
	screen.close();await _close()
	var file:=FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("native.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"checks":checks,"failures":failures,"captures":native_captures,"scope":"Room/downed/position and player minHP1 are declared fixtures. Actual execution confirmation samples real sight; witness reports over real gameplay time; existing actor retaliates without pose override. Actual M/keyboard journal. Native1152 product stretch;800 explicitly changes logical content_scale_size for compact inspection. Muted, no FPS or manual-play claim."},"\t"));file.close()
	await root.get_node("AudioManager").shutdown()
	print("RESULT Part4PublicNative checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
