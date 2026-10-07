class_name WeaponMotionPose
extends RefCounted
## Cosmetic poses seek the authoritative Weapon clock; no tween drives hits.

static func evaluate(profile: StringName, index: int, phase: int, t: float) -> Dictionary:
	var low: float = -35.0
	var high: float = 85.0
	var thrust: float = 0.0
	var lean: float = 0.0
	match profile:
		&"sweep": low = -48.0; high = 95.0; lean = 0.11
		&"heavy": low = -85.0; high = 115.0; lean = 0.20
		&"dual": low = -50.0 if index % 2 == 0 else 45.0; high = 90.0 if index % 2 == 0 else -85.0; lean = 0.07
		&"thrust": low = -8.0; high = 8.0; thrust = 15.0; lean = 0.13
		&"halberd": low = -60.0; high = 110.0; lean = 0.16; thrust = 12.0 if index == 1 else 0.0
		&"overhead": low = -100.0; high = 70.0; lean = 0.22
		&"crush": low = -75.0; high = 60.0; lean = 0.24
		&"chain": low = -32.0; high = 65.0; thrust = 10.0; lean = 0.10
		&"fan": low = -22.0; high = 55.0; lean = 0.05
		&"staff": low = -12.0; high = 12.0; thrust = 10.0; lean = 0.08
	var swing: float = 0.0
	var extension: float = 0.0
	var weight: float = 0.0
	t = clampf(t, 0.0, 1.0)
	match phase:
		Weapon.Phase.WINDUP:
			swing = lerpf(0, low, t); extension = -thrust * 0.3 * t; weight = -0.4 * t
		Weapon.Phase.ACTIVE:
			swing = lerpf(low, high, t); extension = lerpf(-thrust * 0.3, thrust, t); weight = sin(t * PI * 0.5)
		Weapon.Phase.RECOVERY:
			var fade: float = t * t * (3.0 - 2.0 * t)
			swing = lerpf(high, 0, fade); extension = thrust * (1.0 - fade); weight = 1.0 - fade
	return {"swing": swing, "extension": extension, "lean": lean * weight, "support": -lean * weight * (1.8 if profile in [&"heavy", &"overhead", &"crush", &"thrust", &"halberd"] else 0.5)}
