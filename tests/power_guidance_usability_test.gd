extends "res://tests/power_progression_guide_test.gd"
const Labels = preload("res://scripts/cultivation/opening_cultivation_labels.gd")
func _pure() -> void:
	super._pure()
	var profile := CountingProfile.new(); profile.cultivation_progress=Model.new_progress(4);profile.bounty_accepted=true;profile.coins=7;profile.souls=0
	var inv: GearInventory=HubPreparation.starter_inventory(profile);inv.items[inv.equipped_weapon_uid].enhancement_level=1;inv.add_rune(&"fire");inv.equip(0,&"fire")
	var actor: Dictionary=profile.cultivation_progress["actors"]["player"]
	actor["mastery"]=1;profile.material_stash[&"crystal"]=7
	var view: Dictionary=PowerProgressionGuide.row(profile,inv)
	check(view["power"]["key"]==&"cultivation" and view["power"]["station"]==&"stash" and "Rút 1" in view["power"]["guidance"],"Missing carried crystal exposes its actual withdrawal source in power guidance")
	check("Linh Thạch: 7" in view["power"]["guidance"] and "Tàn Hồn: 0" in view["power"]["guidance"] and "0 trong túi, 7 trong kho" in view["power"]["guidance"] and "khác mana" in view["power"]["guidance"],"Wallets, bag/stash crystal and cultivation energy are distinct read-only balances")
	check("Luyện Khí I → Luyện Khí II" in view["power"]["current"],"Current and next realm are visible together")
	profile.material_stash[&"crystal"]=0;view=PowerProgressionGuide.row(profile,inv)
	check("rương hầm ngục" in view["power"]["guidance"] and "ngẫu nhiên" in view["power"]["guidance"],"No stored supply falls back to the verified random source rather than a guaranteed reward")
	for stage: int in 3:
		actor["stage"]=stage;actor["energy"]=profile.cultivation_progress["config"]["energy_thresholds"][stage];actor["mastery"]=profile.cultivation_progress["config"]["mastery_thresholds"][stage];actor["insight_ids"]=["explored","thanh_vy_met"];inv.materials[&"dust"]=3
		var hint: Dictionary=OpeningProgressionGuide.cultivation_view(profile,inv)
		check(hint["status"]=="requirements_ready" and Labels.breakthrough_action(stage) in hint["action"],"Ready guidance names the exact existing panel action for stage%d"%stage)
		check(("Hồi Phong Kiếm" in hint["action"])==(stage==2),"Only the final existing gate advertises the two branch choices")
	actor["stage"]=2;actor["energy"]=24;actor["mastery"]=4;profile.cultivation_progress["config"]["energy_thresholds"]=[12,24,40]
	view=PowerProgressionGuide.row(profile,inv)
	check(need(view,&"crystal")["need"]==2 and "Luyện Khí III → Trúc Cơ sơ kỳ" in view["power"]["current"],"Legacy saved thresholds remain the authority for remaining training sessions")
	actor["energy"]=40;profile.cultivation_progress["config"]["final_dust_cost"]=3;inv.materials[&"dust"]=2;profile.material_stash[&"dust"]=1
	view=PowerProgressionGuide.row(profile,inv)
	check(view["power"]["station"]==&"stash" and "Rút 1" in view["power"]["guidance"] and need(view,&"dust")["missing"]==1,"A partial stored legacy dust cost points to the same withdrawal as its source text")
	actor["stage"]=0;actor["energy"]=0;actor["mastery"]=1;profile.cultivation_progress["config"]["training_cost"]=3;inv.materials[&"crystal"]=2;profile.material_stash[&"crystal"]=1
	view=PowerProgressionGuide.row(profile,inv)
	check(view["power"]["station"]==&"stash" and "Rút 1" in view["power"]["guidance"],"A partial stored legacy training cost routes to withdrawal before searching more loot")
	profile.cultivation_progress=Model.new_progress(4);actor=profile.cultivation_progress["actors"]["player"];actor["stage"]=3;actor["energy"]=16;actor["mastery"]=4;actor["insight_ids"]=["explored","thanh_vy_met"]
	var capped: Dictionary=OpeningProgressionGuide.cultivation_view(profile,inv)
	check(capped["status"]=="opening_complete" and "chưa có" in capped["body"] and "Kết Đan" not in capped["action"],"Completed opening cannot promise an unimplemented next realm")
	var before: String=Writer.canonical({"progress":profile.cultivation_progress,"stash":profile.material_stash,"inventory":GearInventoryCodec.encode(inv),"coins":profile.coins,"souls":profile.souls})
	for index: int in 5:PowerProgressionGuide.row(profile,inv)
	check(profile.saves==0 and before==Writer.canonical({"progress":profile.cultivation_progress,"stash":profile.material_stash,"inventory":GearInventoryCodec.encode(inv),"coins":profile.coins,"souls":profile.souls}),"New guidance neither saves nor alters progress, wallets, material counts or UIDs")
func _product() -> void:
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override="user://power-usability/profile.json";root.add_child(flow);await step(12)
	var hub: ExteriorHub=flow.active_scene as ExteriorHub;var screen: InventoryScreen=hub.gear.modal as InventoryScreen
	screen.open_map();await step(3);screen.journal.select_quest(PowerProgressionGuide.ID);await step(3)
	check(screen.journal.guide_label.is_visible_in_tree() and "NGUỒN / CÁCH THỰC HIỆN" in screen.journal.guide_label.text and "PHÂN BIỆT TÀI NGUYÊN" in screen.journal.guide_label.text,"Actual power page exposes source and resource explanations that were previously hidden")
	check(not screen.tracker.visible and screen.journal.tracker_text().is_empty(),"Guidance stays inside the existing mission page, with no persistent HUD overlay")
	flow.profile.coins=8;flow.profile.changed.emit();await step(5)
	check("Linh Thạch: 8" in screen.journal.guide_label.text,"Existing profile signal refreshes visible balance text")
	screen.close();flow.queue_free();await step(8)
	await super._product()
