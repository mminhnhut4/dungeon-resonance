class_name PilgrimageArtPack
extends Resource
## Immutable presentation slots. Incoming originals are referenced only after inspection.
@export var far_panorama: Texture2D
@export var middle_panorama: Texture2D
@export var terrain_texture: Texture2D
@export var terrain_cap: Texture2D
@export var terrain_body: Texture2D
@export var prop_textures: Dictionary[StringName,Texture2D] = {}
@export var prop_foot_pivots: Dictionary[StringName,Vector2] = {}
@export var prop_ground_profiles: Dictionary[StringName,PackedVector2Array] = {}
@export var prop_scales: Dictionary[StringName,float] = {}
@export var prop_reference_heights: Dictionary[StringName,float] = {}
@export var alpha_cleanup: Shader
@export var alpha_cleanup_enabled: bool = false
@export var far_scroll_scale: Vector2 = Vector2(0.12,0.06)
@export var middle_scroll_scale: Vector2 = Vector2(0.38,0.18)
@export var far_tint: Color = Color(0.70,0.76,0.79)
@export var stone_tint: Color = Color(0.72,0.78,0.77)
@export var provenance_label: String = "Existing project assets; temporary references"
