class_name DamageResult
extends RefCounted
## Read-only-by-convention result for UI/VFX and after-hit reactions.

var actual_damage: float
var blocked: bool
var block_reason: StringName
var killed: bool
var applied_status_ids: Array[StringName] = []
