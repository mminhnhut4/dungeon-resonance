class_name CatalystRuntime
extends RefCounted
## Unique state for a catalyst instance within one actor/run.

var opened_slots: int = 0
var installed_rune_ids: Array[StringName] = []
var installed_runes: Array[RuneData] = []
var resolved_resonance: ResonanceDefinition
