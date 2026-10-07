class_name PilgrimageAudio
extends Node
## Room-owned audition adapter. Candidate ambience/steps are off until requested.
const STEP_DISTANCE: float = 38.0
var room: ExteriorRoom
var hub: ExteriorHub
var audio: Node
var candidate_mix_enabled: bool = false
var wind_voice: WeakRef
var last_position: Vector2
var tracked: bool = false
var travel: float = 0.0
var cooldown: float = 0.0
var leaves_remaining: float = 4.0
var emitted_steps: int = 0
var emitted_ambient: int = 0

func initialize(owner_room: ExteriorRoom) -> void:
	room = owner_room
	name = "PilgrimageAudio"
	set_physics_process(false)
	call_deferred("_bind")

func _bind() -> void:
	if not is_inside_tree() or not is_instance_valid(room) or not room.get_parent() is ExteriorHub: return
	hub = room.get_parent() as ExteriorHub
	audio = get_node("/root/AudioManager")
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--candidate-audio-preview": candidate_mix_enabled = true
	if is_instance_valid(hub.npc_population): hub.npc_population.cue_requested.connect(_npc_cue)
	set_physics_process(true)

func set_candidate_mix(enabled: bool) -> void:
	candidate_mix_enabled = enabled
	if not enabled and is_instance_valid(audio): audio.stop_owner(self)
	wind_voice = null
	tracked = false
	travel = 0

func _npc_cue(_id: String, cue: StringName, at: Vector2, lifetime_owner: Node) -> void:
	if candidate_mix_enabled and cue == &"npc_footstep" and lifetime_owner.get_parent() == room:
		audio.play_external_event(&"footstep.stone",at,lifetime_owner,true)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(hub) or not is_instance_valid(hub.player): return
	var actor: Player = hub.player
	var playing: bool = candidate_mix_enabled and actor.controls_enabled and actor.health.current_health > 0 and not hub.dialogue.is_open and not hub.gear.modal.is_open and not get_tree().paused
	if not playing:
		if wind_voice != null:
			audio.stop_owner(self)
			wind_voice = null
		tracked = false
		travel = 0
		return
	if wind_voice == null or wind_voice.get_ref() == null:
		var wind: AudioStreamPlayer2D = audio.play_external_event(&"wind",room.to_global(Vector2(room.width*0.5,room.min_y)),self,true)
		if wind != null:
			wind_voice = weakref(wind)
			emitted_ambient += 1
	leaves_remaining -= delta
	if leaves_remaining <= 0:
		leaves_remaining = 7.0
		if absf(room.to_local(actor.global_position).x-565) < 360:
			audio.play_external_event(&"leaves",room.to_global(Vector2(565,room.floor_y(565)-80)),self,true)
	var moving: bool = actor.motor.is_grounded() and not actor.motor.is_dashing and actor.locomotion_state_machine.get_state_id() == &"run" and actor.action_state_machine.get_state_id() not in [&"hurt",&"dead"] and absf(actor.velocity.x) > 8
	if not moving:
		tracked = false
		travel = 0
		return
	if not tracked:
		last_position = actor.global_position
		tracked = true
		return
	var displacement: float = actor.global_position.distance_to(last_position)
	last_position = actor.global_position
	cooldown = maxf(0,cooldown-delta)
	if displacement > 30: travel = 0; return # Door/QA relocation is not a step.
	travel += displacement
	if travel >= STEP_DISTANCE and cooldown <= 0:
		travel = 0
		cooldown = 0.17
		if audio.play_external_event(&"footstep.stone",actor.global_position,self,true) != null: emitted_steps += 1

func _exit_tree() -> void:
	if is_instance_valid(hub) and is_instance_valid(hub.npc_population) and hub.npc_population.cue_requested.is_connected(_npc_cue): hub.npc_population.cue_requested.disconnect(_npc_cue)
	if is_instance_valid(audio): audio.stop_owner(self)
