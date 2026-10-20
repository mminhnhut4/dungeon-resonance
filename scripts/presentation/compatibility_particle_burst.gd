class_name CompatibilityParticleBurst
extends CPUParticles2D
## Selected small emitters avoid the measured GLES3 particle draw stalls.
## Keep the authored GPU node as an inactive parameter source. Owner teardown
## frees both nodes. Only explicitly attached emitters change simulation backend;
## their authored parameters and gameplay remain with the original owners.
var _source: GPUParticles2D

static func supported() -> bool:
	return DisplayServer.get_name()!="headless" and RenderingServer.get_current_rendering_method()=="gl_compatibility"

static func attach(source: GPUParticles2D) -> CompatibilityParticleBurst:
	if not supported():return null
	var burst:=CompatibilityParticleBurst.new()
	burst._source=source
	burst.name=String(source.name)+"Compatibility"
	burst.convert_from_particles(source)
	burst.texture=source.texture
	burst.material=source.material
	burst.transform=source.transform
	burst.z_index=source.z_index
	burst.show_behind_parent=source.show_behind_parent
	burst.texture_filter=source.texture_filter
	burst.modulate=source.modulate
	burst.self_modulate=source.self_modulate
	source.get_parent().add_child(burst)
	burst.refresh_parameters()
	burst.set_emission(source.emitting)
	source.hide()
	return burst

func refresh_parameters() -> void:
	if not is_instance_valid(_source):return
	var behavior: ParticleProcessMaterial=_source.process_material as ParticleProcessMaterial
	if behavior==null:return
	# Reconfiguration changes paint without restarting an in-flight one-shot.
	amount=_source.amount
	color=behavior.color
	color_ramp=(behavior.color_ramp as GradientTexture1D).gradient if behavior.color_ramp is GradientTexture1D else null
	direction=Vector2(behavior.direction.x,behavior.direction.y)
	gravity=Vector2(behavior.gravity.x,behavior.gravity.y)
	spread=behavior.spread
	initial_velocity_min=behavior.initial_velocity_min
	initial_velocity_max=behavior.initial_velocity_max
	damping_min=behavior.damping_min
	damping_max=behavior.damping_max
	scale_amount_min=behavior.scale_min
	scale_amount_max=behavior.scale_max
	texture=_source.texture

func set_emission(value: bool) -> void:
	emitting=value
	if is_instance_valid(_source):_source.emitting=false

func _process(_delta: float) -> void:
	if is_instance_valid(_source):speed_scale=_source.speed_scale
