extends SceneTree
var checks: int=0
var failures: int=0
func _initialize() -> void:call_deferred("run")
func step(n: int) -> void:
	for i: int in n:await physics_frame;await process_frame
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok:failures+=1;print("FAIL: "+label)
func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--hz="):Engine.physics_ticks_per_second=int(arg.trim_prefix("--hz="))
	AudioServer.set_bus_mute(0,true)
	var qa: String=OS.get_environment("DUNGEON_QA_DATA_ROOT").replace("\\","/")
	check(not qa.is_empty() and OS.get_user_data_dir().replace("\\","/").begins_with(qa+"/"),"Isolated profile for roster fixture")
	var flow: GameFlow=preload("res://scenes/maps/prologue_hub.tscn").instantiate();flow.save_path_override="user://harrier-roster/profile.json";root.add_child(flow);await step(12);flow.start_campaign();await step(12)
	var campaign: WorldCampaign=flow.active_scene as WorldCampaign
	check(campaign!=null and campaign.stage==1,"Canonical connected opening uses WorldCampaign stage1")
	var live: Array[Node2D]=campaign.living_enemies();var prototypes: Array[Node2D]=live.filter(func(e: Node2D)->bool:return e.get_script().resource_path=="res://scripts/actors/enemies/runic_slime_harrier.gd")
	check(live.size()==4 and prototypes.size()==1,"Exactly one existing slot among the same four enemies becomes ranged")
	check(live.filter(func(e: Node2D)->bool:return e is BaseEnemy and e.definition.id==&"ancient_guard").size()==2 and live.filter(func(e: Node2D)->bool:return e is BaseEnemy and e.definition.id==&"bloodwing_bat").size()==1,"Two Guards and Bat retain their authored roster")
	var prototype: SlimeEnemy=prototypes[0] as SlimeEnemy
	check(prototype.has_node("ElementAfflictionVFX") and prototype.get_node("ElementAfflictionVFX") is ElementAfflictionVFX,"Real campaign presentation binds the merged elemental adapter to Runic")
	check(prototype.health.maximum_health==60 and prototype.get_meta(&"enemy_type")==&"runic_slime" and prototype.contact_damage_enabled,"Same60HP/contact flag/reward enemy_type as the original slot")
	campaign.enter_stage(3);await step(6);live=campaign.living_enemies()
	check(live.size()==4 and not live.any(func(e: Node2D)->bool:return e.get_script().resource_path=="res://scripts/actors/enemies/runic_slime_harrier.gd"),"Later opening wave retains its four original actors, no prototype expansion")
	check(live.any(func(e: Node2D)->bool:return e is SlimeEnemy and e.get_meta(&"enemy_type",&"")==&"runic_slime" and e.health.maximum_health==60),"Later Runic slot remains the ordinary60HP Slime")
	flow.queue_free();current_scene=null;await step(5)
	check(get_nodes_in_group(&"runic_harrier_bolts").is_empty(),"Scene replacement frees owned projectiles")
	print("RESULT HarrierRoster checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
