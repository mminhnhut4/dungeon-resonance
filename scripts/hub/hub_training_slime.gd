class_name HubTrainingSlime
extends SlimeEnemy
## Existing FSM and hitboxes; only authored training damage is gentler.

func _bite_contact(target: Hurtbox, attack: AttackSnapshot) -> void:
	var event := DamageEvent.new()
	event.source_id = attack.source_id
	event.source_team_id = 2
	event.target_id = target.get_actor_id()
	event.attack_id = attack.attack_id
	event.root_event_id = attack.root_event_id
	event.hit_window_id = 1
	event.base_damage = 5.0
	event.attack_direction = attack.attack_direction
	event.hit_reaction = &"flinch"
	var result: DamageResult = target.take_damage(event)
	if is_instance_valid(combat_feedback):
		combat_feedback.on_hit_confirmed(event, result)

