class_name FootstepDust
extends Node2D
## Finite cosmetic smoke; no light, collision, physics impulse or gameplay state.

const TEXTURE: Texture2D = preload("res://assets/presentation/light_radial.png")
const LIFETIME: float = 0.34
var remaining: float = LIFETIME
var particles: GPUParticles2D
var initial_position: Vector2
var travel: Vector2 = Vector2.ZERO

func configure(location: Vector2, direction: Vector2 = Vector2.ZERO) -> void:
	initial_position = location
	travel = direction

func _ready() -> void:
	global_position = initial_position
	z_index = 1
	particles = GPUParticles2D.new()
	particles.name = "FootSmoke"
	particles.amount = 4
	particles.lifetime = 0.25
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.emitting = false
	particles.fixed_fps = 60
	particles.texture = TEXTURE
	particles.visibility_rect = Rect2(-64, -48, 128, 96)
	var material_state := CanvasItemMaterial.new()
	material_state.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	particles.material = material_state
	var behavior := ParticleProcessMaterial.new()
	behavior.direction = Vector3(-signf(travel.x), -0.4, 0.0)
	behavior.spread = 75.0
	behavior.gravity = Vector3(0, -20, 0)
	behavior.initial_velocity_min = 12.0
	behavior.initial_velocity_max = 35.0
	behavior.damping_min = 20.0
	behavior.damping_max = 30.0
	behavior.scale_min = 0.04
	behavior.scale_max = 0.08
	var colors := Gradient.new()
	colors.set_color(0, Color(0.65, 0.69, 0.71, 0.30))
	colors.set_color(1, Color(0.65, 0.69, 0.71, 0.0))
	var fade := GradientTexture1D.new()
	fade.gradient = colors
	behavior.color_ramp = fade
	particles.process_material = behavior
	add_child(particles)
	particles.emitting = DisplayServer.get_name() != "headless"

func _process(delta: float) -> void:
	remaining = maxf(0, remaining - delta)
	if remaining <= 0:
		queue_free()
