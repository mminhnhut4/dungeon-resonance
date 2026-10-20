extends RefCounted
## Private recorded audition; finite PCM resources, no runtime import or disk access.
const STREAMS: Dictionary = {
	&"sword_swing": [preload("res://assets/audio/recorded_combat_pair/sword_swing_1.tres"), preload("res://assets/audio/recorded_combat_pair/sword_swing_2.tres")],
	&"melee_impact": [preload("res://assets/audio/recorded_combat_pair/melee_impact_1.tres"), preload("res://assets/audio/recorded_combat_pair/melee_impact_2.tres")],
	&"armor_impact": [preload("res://assets/audio/recorded_combat_pair/armor_impact_1.tres"), preload("res://assets/audio/recorded_combat_pair/armor_impact_2.tres")],
	&"spell_cast": [preload("res://assets/audio/recorded_combat_pair/spell_cast_1.tres"), preload("res://assets/audio/recorded_combat_pair/spell_cast_2.tres")],
	&"spell_impact": [preload("res://assets/audio/recorded_combat_pair/spell_impact_1.tres"), preload("res://assets/audio/recorded_combat_pair/spell_impact_2.tres")],
}
const GAIN_DB: Dictionary = {&"sword_swing": -6.0, &"melee_impact": -1.0, &"armor_impact": -2.0, &"spell_cast": -5.0, &"spell_impact": -1.0}
var previous: Dictionary = {}

func pick(cue: StringName, rng: RandomNumberGenerator) -> AudioStreamWAV:
	var index: int = 1 - int(previous[cue]) if previous.has(cue) else rng.randi_range(0, 1)
	previous[cue] = index
	return STREAMS[cue][index] as AudioStreamWAV
