class_name MemberDungeonRoom
extends DungeonRoom
const Catalog=preload("res://data/member_floor_catalog.gd")
const Art=preload("res://data/member_floor_art_catalog.gd")
var floor_number: int=9
var player: Player
var feedback: CombatFeedback
var member_data: Dictionary
var room_width: float
var surfaces: Array[StaticBody2D]=[]
var traps: Array[MemberDungeonTrap]=[]
var platforms: Array[MemberDungeonPlatform]=[]
var barriers: Array[EnvironmentBarrier]=[]
var reference_background: Sprite2D
signal member_enemy_defeated(enemy: BaseEnemy)
var encounters: MemberDungeonEncounter
var spawn_member_enemies: bool=true
func _rect(raw: Array) -> Rect2:return Rect2(float(raw[0]),float(raw[1]),float(raw[2]),float(raw[3]))
func _surface(rect: Rect2,one_way: bool=false) -> StaticBody2D:
	var body: StaticBody2D=_block(rect.get_center(),rect.size,Color(member_data["palette"]))
	var collider:=body.get_node("Shape") as CollisionShape2D
	collider.one_way_collision=one_way;collider.one_way_collision_margin=4
	body.set_meta(&"dungeon_architectural_surface",true);surfaces.append(body)
	return body
func _ready() -> void:
	assert(Catalog.valid(floor_number));member_data=Catalog.floor_data(floor_number);room_width=Catalog.width(floor_number)
	var art: Dictionary=Art.definition(floor_number);member_data["background"]=art["background"]
	_build_background()
	var atmosphere:=MemberDungeonAtmosphere.new();atmosphere.name="MemberEnvironmentVfx"
	atmosphere.floor_number=floor_number;atmosphere.room_width=room_width;atmosphere.palette=Color(member_data["palette"]);add_child(atmosphere)
	var left: float=0.0
	for gap: Array in member_data["pits"]:
		_surface(Rect2(left,640,float(gap[0])-left,100))
		_surface(Rect2(float(gap[0]),748,float(gap[1]),70))
		left=float(gap[0])+float(gap[1])
	_surface(Rect2(left,640,room_width-left,100))
	_block(Vector2(16,400),Vector2(32,800),Color("222c38")).name="MemberWestBoundary"
	_block(Vector2(room_width-16,400),Vector2(32,800),Color("222c38")).name="MemberEastBoundary"
	for raw: Array in member_data["shelves"]:_surface(_rect(raw),true)
	for raw: Array in member_data["rocks"]:_surface(_rect(raw))
	for data: Dictionary in member_data["walls"]:
		var barrier:=MemberEnvironmentBarrier.new();barrier.requires_fire=bool(data["fire"])
		barrier.size=Vector2(float(data["width"]),float(data["height"]));barrier.position=Vector2(float(data["x"]),float(data["y"]))
		barrier.name="FireBramble" if barrier.requires_fire else "CrackedWall";add_child(barrier);barriers.append(barrier)
	for data: Dictionary in member_data["hazards"]:
		var trap:=MemberDungeonTrap.new();trap.kind=StringName(data["kind"]);trap.width=float(data["width"])
		trap.position=Vector2(float(data["x"]),float(data["y"]));trap.phase_offset=float(data["offset"])
		trap.player=player;trap.feedback=feedback;add_child(trap);traps.append(trap)
	for raw: Array in member_data["collapse"]:
		var platform:=MemberDungeonPlatform.new();platform.kind=&"collapse";platform.start=_rect(raw).position;platform.platform_size=_rect(raw).size
		platform.player=player;platform.feedback=feedback;add_child(platform);platforms.append(platform)
	for data: Dictionary in member_data["moving"]:
		var platform:=MemberDungeonPlatform.new();platform.kind=&"moving"
		platform.start=Vector2(float(data["from"][0]),float(data["from"][1]));platform.finish=Vector2(float(data["to"][0]),float(data["to"][1]))
		platform.platform_size=Vector2(float(data["size"][0]),float(data["size"][1]));platform.period=float(data["period"])
		platform.player=player;platform.feedback=feedback;add_child(platform);platforms.append(platform)
	var skin:=DepthTerrainArt.new();skin.name="MemberTerrainArt";add_child(skin)
	skin.rebuild(surfaces,int(art["material"]),Color(member_data["palette"]))
	for tile: Sprite2D in skin.sprites:tile.modulate=Color(art["tint"]).lightened(.35)
	# Thin painted cap separates walkable silhouettes from the detailed backdrop.
	for surface: StaticBody2D in surfaces:
		var collision:=surface.get_node("Shape") as CollisionShape2D
		var dimensions: Vector2=(collision.shape as RectangleShape2D).size
		var edge:=Line2D.new();edge.z_index=-1;edge.width=1.3;edge.default_color=Color(Color(art["tint"]).lightened(.3),.72)
		edge.points=PackedVector2Array([collision.position-dimensions*.5,collision.position+Vector2(dimensions.x*.5,-dimensions.y*.5)]);surface.add_child(edge)
	door=_block(Vector2(room_width-90,360),Vector2(24,720),Color("887659"));door.name="MemberExitSeal"
	door_shape=door.get_node("Shape") as CollisionShape2D
	arrow=Label.new();arrow.name="MemberExitPrompt";arrow.set_meta(&"debug_keep",true)
	arrow.position=Vector2(room_width-280,535);arrow.text="E · ĐI TIẾP / TRỞ VỀ";arrow.add_theme_font_size_override("font_size",17);add_child(arrow)
	traversal_points={&"entry":Catalog.ENTRY,&"exit":Catalog.exit_point(floor_number),&"return":Catalog.ENTRY}
	set_locked(false)
	if spawn_member_enemies and is_instance_valid(player):
		encounters=MemberDungeonEncounter.new();encounters.name="MemberEncounters";encounters.floor_number=floor_number
		encounters.player=player;encounters.feedback=feedback
		encounters.enemy_defeated.connect(func(enemy:BaseEnemy)->void:member_enemy_defeated.emit(enemy));add_child(encounters)
func _build_background() -> void:
	var base:=Polygon2D.new();base.z_index=-40
	base.polygon=PackedVector2Array([Vector2.ZERO,Vector2(room_width,0),Vector2(room_width,800),Vector2(0,800)])
	base.color=Color(member_data["palette"]).darkened(.75);add_child(base)
	# Only a clean pre-existing texture; member screenshots contain baked UI/player.
	var texture: Texture2D=load(member_data["background"]) as Texture2D
	if texture!=null:
		reference_background=Sprite2D.new();reference_background.texture=texture;reference_background.z_index=-30
		reference_background.position=Vector2(room_width*.5,360)
		reference_background.scale=Vector2.ONE*maxf(room_width/texture.get_width(),720.0/texture.get_height())
		reference_background.modulate=Color(Art.definition(floor_number)["tint"]).lightened(.15);add_child(reference_background)
func set_locked(value: bool) -> void:
	locked=value
	if is_instance_valid(door_shape):door_shape.set_deferred("disabled",not value)
	if is_instance_valid(door):door.visible=value
	if is_instance_valid(arrow):arrow.text="PHONG ẤN" if value else "E · TRỞ VỀ SẢNH" if floor_number==30 else "E · TẦNG KẾ / TRỞ VỀ →"
