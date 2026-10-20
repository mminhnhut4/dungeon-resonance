extends SceneTree
const Model = preload("res://scripts/cultivation/opening_cultivation_state.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var qa: String = OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	if qa.is_empty() or not OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"):quit(2);return
	var profile := SanctuaryProfile.new(); profile.cultivation_progress = Model.new_progress(4)
	var actor: Dictionary = profile.cultivation_progress["actors"]["player"]; actor["energy"]=4;actor["mastery"]=1
	var inventory: GearInventory = HubPreparation.starter_inventory(profile); inventory.items[inventory.equipped_weapon_uid].enhancement_level=1;inventory.add_rune(&"fire");inventory.equip(0,&"fire")
	var row: Dictionary = PowerProgressionGuide.row(profile,inventory)
	var hub := Node.new();var session := Node.new();var controls := VBoxContainer.new();root.add_child(hub);root.add_child(session);root.add_child(controls)
	OpeningCultivationPanel._breakthrough_button(hub,session,controls,"player",actor,profile.cultivation_progress["config"],inventory.materials,profile.souls,profile.boss_proofs,true)
	var button: Button = controls.get_node("CultivationBreakthrough_player") as Button
	var journal := QuestJournal.new();root.add_child(journal);journal.bind_progress(profile,inventory);journal.select_quest(PowerProgressionGuide.ID)
	for index: int in 4:await physics_frame;await process_frame
	var result: Dictionary={"reproduction_only":true,"ready_action":row["card"]["action"],"actual_button":button.text,"wrong_action_label":"Đột phá" in row["card"]["action"] and button.text.begins_with("Tiến tầng"),"source_exists_in_projection":"Tu vi khác mana" in row["body"],"source_label_visible":journal.guide_label.visible,"power_selected":journal.selected_id==PowerProgressionGuide.ID}
	var confirmed: bool = result["wrong_action_label"] and result["source_exists_in_projection"] and not result["source_label_visible"] and result["power_selected"]
	var f := FileAccess.open(OS.get_environment("DUNGEON_QA_EVIDENCE_ROOT").path_join("power-before.json"),FileAccess.WRITE);f.store_string(JSON.stringify(result,"\t"));f.close()
	journal.queue_free();hub.queue_free();session.queue_free();controls.queue_free()
	for index: int in 4:await physics_frame;await process_frame
	_finish.call_deferred(confirmed)
func _finish(confirmed: bool) -> void:
	# Release projection/temporary UI local references before engine finalization.
	for index: int in 3:await process_frame
	await root.get_node("AudioManager").shutdown();print("RESULT PowerBefore existing_defects_confirmed=%s"%confirmed);quit(0 if confirmed else 1)
