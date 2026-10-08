class_name RenderedSpellArt
extends RefCounted
## Shared rendered paint, twenty resident crops. No node/actor/context references
## or gameplay clocks are retained here. Sprite layers remain owned by effects.

const SHEET_PATH: String = "res://assets/presentation/rendered_spell_v2.png"
const COLUMNS: int = 5
const ROWS: int = 4
const CAST: int = 0
const PROJECTILE: int = 1
const CONTACT: int = 2
const FIELD: int = 3
const ELEMENTS: Array[StringName] = [&"fire", &"wind", &"lightning", &"ice", &"poison"]
const PAIR_ELEMENTS: Dictionary = {
	&"firestorm": [&"fire", &"wind"],
	&"overload": [&"lightning", &"fire"],
	&"charged_slash": [&"wind", &"lightning"],
	&"thermal_shock": [&"ice", &"fire"],
	&"superconduct": [&"ice", &"lightning"],
	&"blizzard": [&"ice", &"wind"],
	&"combustion": [&"poison", &"fire"],
	&"frost_venom": [&"poison", &"ice"],
	&"miasma_cloud": [&"poison", &"wind"],
	&"neurotoxin": [&"lightning", &"poison"],
	&"astral_firestorm": [&"fire", &"lightning"],
	&"eclipse_blades": [&"wind", &"fire"],
}
static var sheet: Texture2D
static var cells: Array[AtlasTexture] = []
static var ink: CanvasItemMaterial


static func available() -> bool:
	if sheet != null:
		return true
	if not ResourceLoader.exists(SHEET_PATH):
		return false
	sheet = load(SHEET_PATH) as Texture2D
	if sheet == null or sheet.get_width() < COLUMNS or sheet.get_height() < ROWS:
		sheet = null
		return false
	# Crop from actual imported dimensions; never assume a 512px generated cell.
	var size := Vector2(sheet.get_width() / float(COLUMNS), sheet.get_height() / float(ROWS))
	for row: int in ROWS:
		for column: int in COLUMNS:
			var crop := AtlasTexture.new()
			crop.atlas = sheet
			crop.region = Rect2(Vector2(column, row) * size + Vector2(2.0, 2.0), size - Vector2(4.0, 4.0))
			crop.filter_clip = true
			cells.append(crop)
	ink = CanvasItemMaterial.new()
	ink.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return true


static func cell(stage: int, element: StringName) -> AtlasTexture:
	if not available():
		return null
	var column: int = ELEMENTS.find(element)
	if column < 0:
		column = 1 # Neutral/basic paint borrows the pale jade wind silhouette.
	return cells[clampi(stage, 0, ROWS - 1) * COLUMNS + column]


static func elements_for(recipe: StringName, fallback: StringName = &"wind") -> Array[StringName]:
	var result: Array[StringName] = []
	if PAIR_ELEMENTS.has(recipe):
		result.assign(PAIR_ELEMENTS[recipe])
		return result
	for element: StringName in ELEMENTS:
		if recipe == element or recipe == StringName(str(element) + "_bolt"):
			result.append(element)
			return result
	result.append(fallback if ELEMENTS.has(fallback) else &"wind")
	return result


static func make_layers(parent: Node2D) -> Array[Sprite2D]:
	var result: Array[Sprite2D] = []
	if not available():
		return result
	for index: int in 2:
		var sprite := Sprite2D.new()
		sprite.name = "RenderedCore" if index == 0 else "RenderedPairEcho"
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.material = ink
		sprite.visible = false
		parent.add_child(sprite)
		result.append(sprite)
	return result


static func configure(layers: Array[Sprite2D], stage: int, recipe: StringName, fallback: StringName = &"wind") -> bool:
	if layers.size() != 2 or not available():
		return false
	var elements: Array[StringName] = elements_for(recipe, fallback)
	layers[0].texture = cell(stage, elements[0])
	layers[0].visible = true
	layers[1].visible = elements.size() > 1
	layers[1].texture = cell(stage, elements[1]) if elements.size() > 1 else null
	return true


static func seek(layers: Array[Sprite2D], size: Vector2, opacity: float, elapsed: float, stage: int, recipe: StringName, tint: Color = Color.WHITE) -> void:
	if layers.size() != 2 or layers[0].texture == null:
		return
	var width: float = maxf(1.0, layers[0].texture.get_width())
	var height: float = maxf(1.0, layers[0].texture.get_height())
	var base := Vector2(size.x / width, size.y / height)
	var primary: Sprite2D = layers[0]
	var secondary: Sprite2D = layers[1]
	primary.position = Vector2.ZERO
	secondary.position = Vector2.ZERO
	primary.scale = base
	secondary.scale = base * 0.86
	# Preserve the artist's painted value/ink. Snapshot tint is a subtle wash;
	# two different elemental crops carry each pair's actual silhouette.
	primary.modulate = Color(tint.lerp(Color.WHITE, 0.86), opacity)
	secondary.modulate = Color(1.0, 1.0, 1.0, opacity * 0.70)
	primary.rotation = 0.0
	secondary.rotation = PI * 0.15
	if stage == CAST:
		primary.rotation = elapsed * 0.35
		secondary.rotation = -elapsed * 0.55 + PI / 3.0
		secondary.scale = base * 1.03
	elif stage == PROJECTILE:
		# The sheet points right. Anchor its leading paint near the real hitbox
		# (8px for a bolt), letting the rendered body trail behind that contact.
		# Parent rotation already follows the committed snapshot direction.
		primary.position = Vector2(-size.x * 0.36, 0.0)
		primary.scale.y *= 1.0 + 0.045 * sin(elapsed * 13.0)
		secondary.position = primary.position + Vector2(-size.x * 0.12, size.y * 0.06)
		secondary.rotation = -0.22 if recipe in [&"superconduct", &"frost_venom"] else 0.22
		if recipe == &"overload":
			secondary.rotation = PI
	elif stage == CONTACT:
		primary.rotation = elapsed * 0.6
		secondary.rotation = PI * 0.5 - elapsed * 0.7
		secondary.scale = base * 1.02
	elif stage == FIELD:
		primary.rotation = elapsed * (0.22 if recipe == &"miasma_cloud" else 0.42)
		secondary.rotation = -elapsed * (0.55 if recipe == &"miasma_cloud" else 0.85)
		primary.scale *= 1.0 + 0.025 * sin(elapsed * 4.0)
		secondary.scale = base * 0.96
