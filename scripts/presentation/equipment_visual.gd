class_name EquipmentVisual
extends Node2D
## Independent hand/armor layers. Authoritative Weapon phase owns all timing.

var player: Player
var inventory: GearInventory
var hand_socket: Marker2D
var weapon_pivot: Node2D
var weapon_sprite: Sprite2D
var armor_sprite: Sprite2D
var accessory_aura: Node2D
var weapon_trail: Line2D
var weapon_vfx: GPUParticles2D
var shown_uid: int = -1
var shown_texture: Texture2D
var _data: EquipmentData
var _rig: PlayerVisualRig
var _shown_modular: bool = false
var _wearable_uids: Dictionary = {}
var _wearable_data: Dictionary = {}


func _ready() -> void:
	name = "EquipmentVisual"
	_rig = get_parent() as PlayerVisualRig
	z_index = 7
	armor_sprite = Sprite2D.new()
	armor_sprite.name = "ArmorSprite"
	armor_sprite.centered = false
	add_child(armor_sprite)
	hand_socket = Marker2D.new()
	hand_socket.name = "HandSocket"
	add_child(hand_socket)
	weapon_pivot = Node2D.new()
	weapon_pivot.name = "WeaponPivot"
	hand_socket.add_child(weapon_pivot)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.name = "WeaponSprite"
	weapon_sprite.centered = false
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	weapon_pivot.add_child(weapon_sprite)
	weapon_trail = Line2D.new()
	weapon_trail.name = "WeaponTrail"
	weapon_pivot.add_child(weapon_trail)
	weapon_vfx = GPUParticles2D.new()
	weapon_vfx.name = "WeaponVFX"
	weapon_vfx.emitting = false
	weapon_pivot.add_child(weapon_vfx)
	# The existing room-owned WeaponTrail is the sole slash emitter. These slots
	# stay empty for the Common sword rather than duplicating its combat VFX.
	accessory_aura = Node2D.new()
	accessory_aura.name = "AccessoryAura"
	add_child(accessory_aura)
	inventory.changed.connect(refresh_equipment)
	_rig.modular_skin_changed.connect(_on_modular_skin_changed)
	refresh_equipment()
	refresh_pose()


func refresh_equipment() -> void:
	shown_uid = inventory.equipped_weapon_uid
	var item: GearItem = inventory.items.get(shown_uid)
	_data = item.equipment_definition if item != null else null
	shown_texture = _data.world_sprite_texture if _data != null else null
	weapon_sprite.texture = shown_texture
	weapon_sprite.visible = shown_texture != null
	if shown_texture != null:
		weapon_sprite.scale = Vector2.ONE * (_data.displayed_weapon_length / shown_texture.get_width())
		weapon_sprite.offset = -_data.hand_origin
	var next_modular: bool = _rig.is_modular_active()
	if next_modular != _shown_modular:
		_wearable_uids.clear()
		_wearable_data.clear()
	_shown_modular = next_modular
	if _shown_modular:
		for slot: int in range(1, EquipmentData.SLOT_COUNT):
			var group: StringName = EquipmentData.SLOT_KINDS[slot]
			var equipped: GearItem = inventory.items.get(inventory.equipment_uids[slot])
			var uid: int = equipped.uid if equipped != null else 0
			var data: EquipmentData = equipped.equipment_definition if equipped != null else null
			var mounted: bool = _rig._modular_equipment.has(group)
			if _wearable_uids.get(group, -1) == uid and _wearable_data.get(group) == data and mounted == (data != null):
				continue
			if equipped != null and equipped.equipment_definition != null:
				_rig.set_equipment_parts(group, equipped.equipment_definition.visual_parts)
			else:
				_rig.clear_equipment_parts(group)
			_wearable_uids[group] = uid
			_wearable_data[group] = data
	var armor: GearItem = inventory.items.get(inventory.equipment_uids[EquipmentData.SlotType.ARMOR])
	armor_sprite.texture = armor.equipment_definition.world_sprite_texture if armor != null and armor.equipment_definition != null else null
	armor_sprite.visible = armor_sprite.texture != null and not _shown_modular


func _process(_delta: float) -> void:
	if shown_uid != inventory.equipped_weapon_uid or _shown_modular != _rig.is_modular_active():
		refresh_equipment()
	refresh_pose()


func _on_modular_skin_changed() -> void:
	# Replacing an active skin clears its mounted sprites even when the same
	# owned gear and modular boolean remain selected. Rebind exactly once here.
	refresh_equipment()
	refresh_pose()


func refresh_pose() -> void:
	if not is_instance_valid(_rig.concept_pivot) or not is_instance_valid(player):
		return
	# Sockets are cosmetic; neither the old WeaponSocket nor Hurtbox is reparented.
	var facing: float = -1.0 if _rig.visual_facing_left else 1.0
	var foot: Vector2 = _rig.concept_pivot.position
	if _rig.is_modular_active():
		hand_socket.position = to_local(_rig.get_hand_world_position())
	else:
		hand_socket.position = foot + Vector2(7.0 * facing, -25.0 + _rig.procedural.bob)
	var weapon: Weapon = player.equipped_weapon
	var angle: float = player.aim.direction.angle()
	var swing: float = 0.0
	var extension: float = 0.0
	if weapon.snapshot != null and weapon.phase not in [Weapon.Phase.NONE, Weapon.Phase.COMBO_WAIT]:
		angle = weapon.snapshot.attack_direction.angle()
		facing = -1.0 if weapon.snapshot.attack_direction.x < 0.0 else 1.0
		var t: float = clampf(1.0 - weapon._phase_remaining / maxf(weapon._phase_duration, 0.001), 0.0, 1.0)
		match weapon.phase:
			Weapon.Phase.WINDUP: swing = lerpf(0.0, -35.0, t)
			Weapon.Phase.ACTIVE: swing = lerpf(-35.0, 85.0, t)
			Weapon.Phase.RECOVERY: swing = lerpf(85.0, 0.0, t * t * (3.0 - 2.0 * t))
		if weapon.snapshot.weapon_definition.visual_profile != &"legacy":
			var pose: Dictionary = WeaponMotionPose.evaluate(weapon.snapshot.weapon_definition.visual_profile, weapon.combo_index, weapon.phase, t)
			swing = float(pose["swing"])
			extension = float(pose["extension"])
	weapon_pivot.position = Vector2.from_angle(angle) * extension
	weapon_pivot.rotation = angle + deg_to_rad(swing) * facing
	weapon_sprite.flip_v = cos(angle) < 0.0
	weapon_sprite.modulate = player.body_sprite.modulate
	if armor_sprite.texture != null and not _shown_modular:
		armor_sprite.position = _rig.concept_dynamics.position + foot
		armor_sprite.scale = _rig.concept_sprite.scale * _rig.concept_pivot.scale * _rig.concept_dynamics.scale
		armor_sprite.offset = _rig.concept_sprite.offset
		armor_sprite.flip_h = _rig.visual_facing_left
		armor_sprite.rotation = _rig.concept_dynamics.rotation
		armor_sprite.modulate = player.body_sprite.modulate
	visible = player.health.current_health > 0.0


func _exit_tree() -> void:
	if is_instance_valid(_rig) and _rig.modular_skin_changed.is_connected(_on_modular_skin_changed):
		_rig.modular_skin_changed.disconnect(_on_modular_skin_changed)
	if inventory != null and inventory.changed.is_connected(refresh_equipment):
		inventory.changed.disconnect(refresh_equipment)
	_wearable_uids.clear()
	_wearable_data.clear()
