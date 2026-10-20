extends EnemyHazard
## Reuses MutantSlime's straight projectile motion/shape/lifetime, not its22damage.
## One committed, non-homing shot. Owner/room/target validity gates every sample.
var source_owner: WeakRef
var room_id: int=0
var resolved_contacts: int=0
const FLIGHT_DISTANCE: float=332.0 # 300px aim range plus Hurtbox/step margin.
func _ready() -> void:
	kind=&"runic_bolt"
	super._ready()
	# A dodged shot must not keep crossing the room/HUD for the legacy five seconds.
	# EnemyHazard owns this clock, including its existing feedback-freeze pause.
	life=minf(life,FLIGHT_DISTANCE/380.0)
	add_to_group(&"runic_harrier_bolts")
	var ink:=CanvasItemMaterial.new();ink.light_mode=CanvasItemMaterial.LIGHT_MODE_UNSHADED;material=ink
func _physics_process(delta: float) -> void:
	var owner_actor: Node=source_owner.get_ref() as Node if source_owner!=null else null
	if not is_instance_valid(owner_actor) or owner_actor.is_queued_for_deletion() or not owner_actor.call("projectile_allowed",player,room_id):
		hitbox.deactivate();queue_free();return
	super._physics_process(delta)
func _hit(target: Hurtbox,_snapshot: AttackSnapshot) -> void:
	var owner_actor: Node=source_owner.get_ref() as Node if source_owner!=null else null
	if is_queued_for_deletion() or not hitbox.active or not is_instance_valid(owner_actor) or not owner_actor.call("projectile_allowed",player,room_id):return
	if target.get_actor_id()!=player.get_instance_id():return
	# The circular query must not reach a Hurtbox through a thin wall edge.
	var query:=PhysicsRayQueryParameters2D.create(global_position,target.global_position,1)
	if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
		hitbox.deactivate();queue_free();return
	var event:=DamageEvent.new()
	event.source_id=source_id;event.source_team_id=2;event.target_id=target.get_actor_id()
	event.attack_id=attack.attack_id;event.root_event_id=attack.root_event_id;event.hit_window_id=1
	event.base_damage=15.0 # Existing Slime bite damage; no poison or new damage bonus.
	event.attack_direction=direction
	target.take_damage(event);resolved_contacts+=1
	hitbox.deactivate();queue_free()
func _draw() -> void:
	# Same legacy Mutant projectile silhouette; explicit hostile rune ink stays
	# readable in the opening's painted darkness without a light or particles.
	draw_colored_polygon(PackedVector2Array([Vector2(-15,10),Vector2(-8,-13),Vector2(0,0),Vector2(8,-18),Vector2(15,10)]),Color(.75,.48,1))
	draw_line(Vector2(-4,1),Vector2(5,-4),Color(.95,.88,1),1.5,true)
