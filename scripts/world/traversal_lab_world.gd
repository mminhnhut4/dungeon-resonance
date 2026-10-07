class_name TraversalLabWorld
extends PrologueHub
## Private technical fixture, intentionally separate from the authored campaign.
const ORIGIN := Vector2(8000,0)
var lab: TraversalLabRoom
var checkpoint := TraversalLabCheckpoint.new()
var reject_next_load: bool = false
var door_latched: bool = false
var title: Label

func _ready() -> void:
	# Opening this QA scene directly can never load the user's real profile.
	if profile == null: profile = SanctuaryProfile.new()
	profile.save_path = "user://verification/traversal_lab_profile_v1.json"
	super._ready()
	yard.hide()
	yard.process_mode = Node.PROCESS_MODE_DISABLED
	house.process_mode = Node.PROCESS_MODE_DISABLED
	presentation.foyer_art.clear()
	presentation.atmosphere.hide()
	title = summary
	title.position = Vector2(410,24)
	title.add_theme_font_size_override("font_size",16)
	if not transition_lab(TraversalLabRoom.IDS[0],&"west",false): push_error("QA lab could not create its initial valid room")

func transition_lab(id: StringName, entry: StringName, commit: bool = true) -> bool:
	if not _can_travel(): return false
	var target := TraversalLabRoom.new()
	if reject_next_load:
		reject_next_load = false
		target.free()
		return false
	if not target.configure(id,checkpoint.gate_open) or not target.valid_anchor(entry):
		target.free()
		return false
	var prior_room: StringName = checkpoint.room
	var prior_anchor: StringName = checkpoint.anchor
	checkpoint.room = id
	checkpoint.anchor = entry
	if commit and not checkpoint.save():
		checkpoint.room = prior_room
		checkpoint.anchor = prior_anchor
		target.free()
		return false
	# All validation and disk work precede the sole actor relocation.
	# PlayerTravel then preserves committed motor/build and recipe clocks.
	target.position = ORIGIN
	if is_instance_valid(lab):
		remove_child(lab)
		lab.queue_free()
	executor.clear_entities()
	feedback.reset_feedback()
	presentation.rebuild()
	presentation.atmosphere.hide()
	presentation.foyer_art.clear()
	get_node("/root/AudioManager").stop_owner(presentation)
	add_child(target)
	lab = target
	PlayerTravel.relocate(player,ORIGIN + target.anchors[entry])
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = int(ORIGIN.x)
	camera.limit_right = int(ORIGIN.x + target.width)
	camera.limit_top = 0
	camera.limit_bottom = 1040
	camera.reset_smoothing()
	camera.force_update_scroll()
	door_latched = true
	refresh_summary()
	zone_changed.emit(id)
	return true

func refresh_summary() -> void:
	if not is_instance_valid(lab) or not is_instance_valid(title):
		super.refresh_summary()
		return
	var index: int = TraversalLabRoom.IDS.find(lab.room_id) + 1
	title.text = "LAB%02d · QA riêng · W đi bộ / J nhảy\n%s" % [index,"Cua gấp chưa đạt · xem diagnostic" if index == 2 else "Fixture kỹ thuật · chưa phải O01/O02"]

func _can_travel() -> bool:
	return is_instance_valid(player) and player.health.current_health > 0 and player.controls_enabled and not gear.modal.is_open and not station_open and not dialogue.is_open and (player.hit_reaction == null or not player.hit_reaction.blocks_controls())

func nearest_station() -> StringName:
	if not is_instance_valid(lab): return &""
	var best: StringName = &""
	var distance: float = INTERACTION_RANGE
	for id: StringName in lab.marks:
		var next: float = player.global_position.distance_to(ORIGIN + lab.marks[id])
		if next < distance:
			distance = next
			best = id
	return best

func interact_station(id: StringName) -> bool:
	if not _can_travel() or not player.motor.is_grounded() or id != nearest_station(): return false
	if id in [&"door_west",&"door_east"]:
		if door_latched: return false
		var index: int = TraversalLabRoom.IDS.find(lab.room_id)
		var next: int = (index + (1 if id == &"door_east" else 2)) % 3
		return transition_lab(TraversalLabRoom.IDS[next],&"west" if id == &"door_east" else &"east")
	if id == &"gate_lever":
		if checkpoint.gate_open: return true
		checkpoint.gate_open = true
		if not checkpoint.save():
			checkpoint.gate_open = false
			return false
		lab.set_gate(true)
		return true
	if id == &"checkpoint":
		var previous: StringName = checkpoint.anchor
		checkpoint.anchor = &"checkpoint"
		if not checkpoint.save():
			checkpoint.anchor = previous
			return false
		return true
	return false

func restore_checkpoint() -> bool:
	if not _can_travel(): return false
	var recovered := TraversalLabCheckpoint.new()
	recovered.path = checkpoint.path
	if not recovered.load_checkpoint(): return false
	var previous_gate: bool = checkpoint.gate_open
	checkpoint.gate_open = recovered.gate_open
	if not transition_lab(recovered.room,recovered.anchor,false):
		checkpoint.gate_open = previous_gate
		return false
	return true

func _process(_delta: float) -> void:
	if not is_instance_valid(lab): return
	var id: StringName = nearest_station()
	if not Input.is_action_pressed(&"interact"): door_latched = false
	prompt.text = "E · Cửa thử hai chiều" if id in [&"door_west",&"door_east"] else "E · Mở cổng từ phía xa" if id == &"gate_lever" else "E · Ghi mốc khô (không hồi / bank)" if id == &"checkpoint" else "QA · A/D đi bộ · Space nhảy · Shift dash · Tab hành trang"
	# The Hub's hard-coded y>850 respawn is intentionally not used by this fixture.
	# Every lab has a continuous W floor; failed optional jumps land on that floor.
