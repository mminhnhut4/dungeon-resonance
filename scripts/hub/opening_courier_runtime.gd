class_name OpeningCourierRuntime
extends "res://scripts/hub/courier_opportunity.gd"
## Preserve the reviewed adapter; expose the common owner's quarantine to UI.
func objectives() -> Dictionary:
	if profile == null or not profile.extension_transactions_available("courier"):
		return CourierProgress.snapshot(CourierProgress.empty(),true)
	return super.objectives()
