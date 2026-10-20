class_name CultivatorCombatScaling
extends RefCounted
## A read adapter over the opening cultivation stages, never a progression store.
## Prototype balance: each authored stage adds 50% HP and 20% outgoing damage.
## Existing stage-zero residents retain HP 40 and their previous base damage.
const MAX_HEALTH_MULTIPLIER: float = 2.5
const MAX_DAMAGE_MULTIPLIER: float = 1.6
const MAX_DAMAGE: float = 32.0

static func stage_index(stage_id: String) -> int:
	var stages: Array = OpeningCultivationState.default_config()["stages"]
	return stages.find(stage_id)

static func health_multiplier(stage_id: String) -> float:
	var index: int = stage_index(stage_id)
	return clampf(1.0 + 0.5 * maxi(0,index),1.0,MAX_HEALTH_MULTIPLIER)

static func damage_multiplier(stage_id: String) -> float:
	var index: int = stage_index(stage_id)
	return clampf(1.0 + 0.2 * maxi(0,index),1.0,MAX_DAMAGE_MULTIPLIER)

static func outgoing_damage(stage_id: String, base_damage: float) -> float:
	if not is_finite(base_damage) or base_damage <= 0.0: return 0.0
	return minf(MAX_DAMAGE,base_damage * damage_multiplier(stage_id))
