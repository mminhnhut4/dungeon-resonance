extends "res://tests/depth_raster_refinement_test.gd"
## Real first-contact regression; --legacy-binding reproduces the stale tell.

func _enemy(_floor_id: int) -> void:
	pass

func _boss() -> void:
	await _first_outgoing(1)
	await _first_outgoing(2)

func _lifetimes() -> void:
	pass

func _fresh_boss(position: Vector2) -> BossGolem:
	var boss: BossGolem = await super._fresh_boss(position)
	if "--legacy-binding" in OS.get_cmdline_user_args():
		boss.attack_hitbox.contact_detected.disconnect(boss.presentation._outgoing_contact)
	return boss
