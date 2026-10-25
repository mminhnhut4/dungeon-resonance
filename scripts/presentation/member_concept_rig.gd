class_name MemberConceptRig
extends Node2D
## Static UV mesh + GPU deformation. Reads actor state; never moves actor/hitboxes.
const Catalog=preload("res://data/member_concept_catalog.gd")
const RIG_SHADER=preload("res://shaders/member_concept_rig.gdshader")
var actor: Node2D
var model_id: String
var mesh_node: MeshInstance2D
var rig_material: ShaderMaterial
var clock: float=0.0
var observed_states: Dictionary={}
var state: StringName=&"idle"
var previous_position: Vector2
var base_height: float
var _source_right: bool=true
var _hanh_scene: Node
var _last_health: float=INF
var _hurt_flash: float=0
var pose_progress: float=0
static func attach_to(target: Node2D,id: String) -> MemberConceptRig:
	if not Catalog.MODELS.has(id):return null
	var existing:=target.get_node_or_null("MemberConceptRig") as MemberConceptRig
	if existing!=null:return existing
	var visual:=MemberConceptRig.new();visual.name="MemberConceptRig";visual.actor=target;visual.model_id=id
	target.add_child(visual);return visual
func _ready() -> void:
	var spec: Dictionary=Catalog.definition(model_id)
	var texture: Texture2D=load(Catalog.path(model_id)) as Texture2D
	if texture==null:return
	base_height=float(spec["height"]);_source_right=bool(spec["right"])
	var foot: Vector2=spec["foot"];var factor: float=base_height/foot.y
	var vertices:=PackedVector3Array();var uvs:=PackedVector2Array();var indices:=PackedInt32Array()
	const COLUMNS: int=8
	const ROWS: int=18
	for y: int in ROWS+1:
		for x: int in COLUMNS+1:
			var uv:=Vector2(float(x)/COLUMNS,float(y)/ROWS);uvs.append(uv)
			var p: Vector2=(uv*texture.get_size()-foot)*factor;vertices.append(Vector3(p.x,p.y,0))
	for y: int in ROWS:
		for x: int in COLUMNS:
			var a: int=y*(COLUMNS+1)+x;var b: int=a+COLUMNS+1
			indices.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	var arrays: Array=[];arrays.resize(Mesh.ARRAY_MAX);arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_TEX_UV]=uvs;arrays[Mesh.ARRAY_INDEX]=indices
	var mesh:=ArrayMesh.new();mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh_node=MeshInstance2D.new();mesh_node.name="ConceptUvMesh";mesh_node.mesh=mesh;mesh_node.texture=texture
	mesh_node.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;add_child(mesh_node)
	rig_material=ShaderMaterial.new();rig_material.shader=RIG_SHADER;rig_material.set_shader_parameter("foot_y",foot.y/texture.get_height());mesh_node.material=rig_material
	rig_material.set_shader_parameter("source_forward",1.0 if _source_right else -1.0)
	# Stop only the old presentation draw, retaining all logic and captions.
	if actor.has_method("set_approved_portrait"):
		# Child ready precedes Hạnh's parent ready. Set data without adding siblings
		# while that parent is still setting up children; its own ready builds safely.
		actor.set("portrait",texture)
		var old: Variant=actor.get("body")
		if old is CanvasItem:(old as CanvasItem).hide()
	previous_position=actor.global_position
	var ancestor: Node=actor
	while ancestor!=null:
		if ancestor.has_method("open_exterior_note"):_hanh_scene=ancestor;break
		ancestor=ancestor.get_parent()
func _process(delta: float) -> void:
	if rig_material==null or not is_instance_valid(actor):return
	var old: Variant=actor.get("body")
	if old is CanvasItem:(old as CanvasItem).hide()
	clock+=delta
	var mode: String="idle"
	var registry: Variant=actor.get("world_state")
	var stable: Variant=actor.get("stable_id")
	if registry!=null and stable!=null:
		var records: Dictionary=registry.get("records")
		if records.has(String(stable)):mode=String(records[String(stable)]["mode"])
	if model_id=="hanh":
		mode="work" if fmod(clock,10.0)<7.5 else "idle"
		if is_instance_valid(_hanh_scene) and _hanh_scene.get("pending_note")==&"hanh_encounter":mode="talk"
	state=&"interact" if mode=="talk" else &"move" if mode in ["walk","flee"] else &"work" if mode=="work" else &"hurt" if mode in ["downed","recovering"] else &"idle"
	pose_progress=0
	var machine: Variant=actor.get("state_machine")
	if machine!=null:
		var physical: StringName=machine.get_state_id()
		state=&"death" if physical==&"dead" else &"windup" if physical==&"telegraph" else &"attack" if physical==&"attack" else &"recover" if physical==&"recover" else &"hurt" if physical==&"hurt" else &"move" if physical==&"chase" or (actor as CharacterBody2D).velocity.length()>2 else &"idle"
		var spec: Variant=actor.get("definition");var span: float=.65 if state==&"death" else float(spec.windup) if state==&"windup" else float(spec.active) if state==&"attack" else float(spec.recovery) if state==&"recover" else .18
		pose_progress=clampf(float(actor.get("state_time"))/maxf(.01,span),0,1)
	var combat: Variant=actor.get("combat_phase")
	if combat!=null and String(combat)!="idle":
		state=&"windup" if combat=="tell" else &"attack" if combat=="active" else &"hurt" if combat=="hurt" else &"recover"
		var spec: Dictionary=actor.get("_combat_spec");var key: String="tell" if combat=="tell" else String(combat)
		pose_progress=clampf(1.0-float(actor.get("phase_remaining"))/maxf(.01,float(spec.get(key,.2))),0,1)
	var health: Variant=actor.get("health")
	if health!=null:
		var hp: float=float(health.current_health)
		if hp<_last_health and _last_health<INF:_hurt_flash=.18
		_last_health=hp
	_hurt_flash=maxf(0.0,_hurt_flash-delta)
	if _hurt_flash>0 and state not in [&"death",&"hurt"]:state=&"hurt"
	observed_states[state]=true
	var direction: float=signf(actor.global_position.x-previous_position.x)
	var facing: Variant=actor.get("_facing")
	if facing==null:facing=actor.get("facing")
	if facing!=null:direction=float(facing)
	if not is_zero_approx(direction):scale.x=1 if (direction>0)==_source_right else -1
	previous_position=actor.global_position
	rig_material.set_shader_parameter("clock",clock)
	rig_material.set_shader_parameter("motion",1.0 if state==&"move" else 0.0)
	rig_material.set_shader_parameter("talking",1.0 if state==&"interact" else 0.0)
	rig_material.set_shader_parameter("working",1.0 if state==&"work" else 0.0)
	rig_material.set_shader_parameter("hurt",1.0 if state==&"hurt" or _hurt_flash>0 else 0.0)
	rig_material.set_shader_parameter("windup",pose_progress if state==&"windup" else 0.0)
	rig_material.set_shader_parameter("striking",sin(pose_progress*PI) if state==&"attack" else 0.0)
	rig_material.set_shader_parameter("dying",pose_progress if state==&"death" else 0.0)
