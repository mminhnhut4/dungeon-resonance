class_name LootAffixCatalog
extends RefCounted
## Scalar prototype limits. A runtime item has at most one of these IDs;
## affixes never emit attacks, statuses, extra drops or resonance children.

const IDS: Array[StringName] = [&"vitality", &"ward", &"focus", &"stride", &"precision"]
const BOUNDS: Dictionary[StringName, Vector2] = {
	&"vitality": Vector2(3.0, 6.0), # Flat maximum HP.
	&"ward": Vector2(1.0, 2.0), # Flat armor rating.
	&"focus": Vector2(3.0, 6.0), # Flat maximum energy/mana.
	&"stride": Vector2(0.01, 0.025), # Fraction of base running speed.
	&"precision": Vector2(0.005, 0.015), # Critical probability, not percent points.
}
const NAMES: Dictionary[StringName, String] = {
	&"vitality": "Sinh lực",
	&"ward": "Hộ thể",
	&"focus": "Tụ khí",
	&"stride": "Khinh hành",
	&"precision": "Sắc bén",
}


static func bounded_value(id: StringName, value: float) -> float:
	if not BOUNDS.has(id) or not is_finite(value) or value <= 0.0:
		return 0.0
	return minf(value, BOUNDS[id].y)
