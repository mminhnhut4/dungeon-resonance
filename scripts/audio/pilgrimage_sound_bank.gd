class_name PilgrimageSoundBank
extends RefCounted
## Selected A recordings and separately gated outdoor candidates. Resources immutable.
const ENTRIES: Dictionary = {
	&"contact.metal":{"approved":true,"bus":&"SFX_Combat","gain":0.0,"streams":["res://assets/audio/pilgrimage_A_v02/combat/metal_A_contact_01.wav","res://assets/audio/pilgrimage_A_v02/combat/metal_A_contact_02.wav"]},
	&"parry.metal":{"approved":true,"bus":&"SFX_Combat","gain":0.0,"streams":["res://assets/audio/pilgrimage_A_v02/combat/metal_A_parry_01.wav","res://assets/audio/pilgrimage_A_v02/combat/metal_A_parry_02.wav"]},
	&"footstep.stone":{"approved":false,"bus":&"SFX_Combat","gain":-11.0,"streams":["res://assets/audio/pilgrimage_A_v02/footsteps/step_stone_01.wav","res://assets/audio/pilgrimage_A_v02/footsteps/step_stone_02.wav","res://assets/audio/pilgrimage_A_v02/footsteps/step_stone_03.wav","res://assets/audio/pilgrimage_A_v02/footsteps/step_stone_04.wav"]},
	&"landing.stone":{"approved":false,"bus":&"SFX_Combat","gain":-9.0,"streams":["res://assets/audio/pilgrimage_A_v02/landings/landing_stone_01.wav","res://assets/audio/pilgrimage_A_v02/landings/landing_stone_02.wav"]},
	&"wind":{"approved":false,"bus":&"Ambient","gain":-10.0,"streams":["res://assets/audio/pilgrimage_A_v02/ambience/wind_designed_loop_01.ogg"]},
	&"leaves":{"approved":false,"bus":&"Ambient","gain":-14.0,"streams":["res://assets/audio/pilgrimage_A_v02/ambience/leaves_rustle_01.wav","res://assets/audio/pilgrimage_A_v02/ambience/leaves_rustle_02.wav","res://assets/audio/pilgrimage_A_v02/ambience/leaves_rustle_03.wav"]},
	&"wood.creak":{"approved":false,"bus":&"Ambient","gain":-12.0,"streams":["res://assets/audio/pilgrimage_A_v02/ambience/wood_creak_01.wav","res://assets/audio/pilgrimage_A_v02/ambience/wood_creak_02.wav"]},
	&"lantern":{"approved":false,"bus":&"Ambient","gain":-15.0,"streams":["res://assets/audio/pilgrimage_A_v02/ambience/lantern_metal_motion_candidate_01.wav"]},
}
var previous: Dictionary = {}
var cached: Dictionary = {}

func definition(kind: StringName, allow_candidate: bool = false) -> Dictionary:
	if not ENTRIES.has(kind) or (not ENTRIES[kind]["approved"] and not allow_candidate): return {}
	return ENTRIES[kind].duplicate(true)

func pick(kind: StringName, rng: RandomNumberGenerator) -> AudioStream:
	var streams: Array = ENTRIES[kind]["streams"]
	var last: int = int(previous.get(kind,-1))
	var index: int = 0
	if streams.size() > 1:
		index = rng.randi_range(0,streams.size()-2) if last >= 0 else rng.randi_range(0,streams.size()-1)
		if last >= 0 and index >= last: index += 1
	previous[kind] = index
	if not cached.has(kind):
		var loaded: Array[AudioStream] = []
		for path: String in streams: loaded.append(load(path) as AudioStream)
		cached[kind] = loaded
	return cached[kind][index] as AudioStream
