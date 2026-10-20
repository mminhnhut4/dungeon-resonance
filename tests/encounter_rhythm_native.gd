extends "res://tests/combined_combat_gameplay_probe.gd"
## Before/after encounter fixture: same earned profile, fixed spawn seed, real input.
## Seed is QA-only, disclosed; no actor placement/HP/AI/damage/save-field edits.
var pressure_rows: Array[Dictionary]=[]
var peak_pressure: int=0
var overlapping_samples: int=0
var coordinated_samples: int=0
var spawn_seed: int=137
func _init() -> void:
	interrupt_from_far_side=true
func born(node: Node) -> void:
	if node is WorldCampaign:node.run_seed=spawn_seed
	super.born(node)
func observe() -> void:
	super.observe()
	if not is_instance_valid(run_scene) or not is_instance_valid(run_scene.room):return
	var active: Array[String]=[]
	for enemy: Node2D in run_scene.living_enemies():
		if enemy is BaseEnemy and enemy.state_machine.get_state_id() in [&"telegraph",&"attack"]:active.append(String(enemy.enemy_type)+str(enemy.get_instance_id()))
		elif enemy is SlimeEnemy:
			if enemy.state_machine.get_state_id()==&"attack" or float(enemy.get("ranged_windup"))>0 or get_nodes_in_group(&"runic_harrier_bolts").size()>0:active.append("runic"+str(enemy.get_instance_id()))
	peak_pressure=maxi(peak_pressure,active.size())
	if active.size()>1:overlapping_samples+=1
	var gate: Node=run_scene.room.get_node_or_null("OpeningAttackWindow")
	if gate!=null:coordinated_samples+=1
	if pressure_rows.size()<6000:pressure_rows.append({"phase":phase,"active":active,"count":active.size(),"wall_usec":Time.get_ticks_usec(),"guard_count":run_scene.living_enemies().size(),"quiet":gate.get("quiet_remaining") if gate!=null else -1})
func dungeon() -> bool:
	var complete: bool=await super.dungeon()
	if "--after" in OS.get_cmdline_user_args():
		_check(coordinated_samples>0 and peak_pressure<=1 and overlapping_samples==0,"Opening room never overlaps committed enemy tells/attacks/Runic flight in this real-input trace")
	else:_check(peak_pressure>1 and overlapping_samples>0,"Baseline real opening reproduces overlapping committed attacks")
	return complete and failures==0
func finish_combat(complete: bool) -> void:
	var file:=FileAccess.open(evidence.path_join("encounter-rhythm.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"complete":complete,"checks":checks,"failures":failures,"peak_pressure":peak_pressure,"overlapping_samples":overlapping_samples,"coordinated_samples":coordinated_samples,"rows":pressure_rows,"spawn_seed":spawn_seed,"scope":"Earned H7 QA profile; fixed spawn seed137 for before/after comparison. Actual inventory equip Ice+Fire, casts/dash, portal, original4enemies, direct interruption and clear/return. No HP/AI/damage/actor-position overrides. Not a human playtest."},"\t"));file.close()
	await super.finish_combat(complete)
