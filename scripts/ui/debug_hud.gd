class_name DebugHUD
extends CanvasLayer
## Presentation reads actor/runtime data; UI never writes HP or spell state.

var player: Player
@onready var hp_bar: ProgressBar = $Panel/HealthBar
@onready var hp_label: Label = $Panel/HealthText
@onready var recipe_label: Label = $Panel/Recipe
@onready var cooldown_label: Label = $Panel/Cooldown
@onready var slots: Array[Label] = [$Panel/Slots/Slot1, $Panel/Slots/Slot2, $Panel/Slots/Slot3]


func _ready() -> void:
	hp_bar.reparent(self)
	hp_bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	hp_bar.position = Vector2(40, 36)
	hp_bar.size = Vector2(270, 18)


func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	hp_bar.max_value = player.health.maximum_health
	hp_bar.value = player.health.current_health
	hp_label.text = "HP  %d / %d" % [roundi(player.health.current_health), roundi(player.health.maximum_health)]
	var controller: ResonanceController = player.resonance_controller
	var installed: Array[RuneData] = controller.catalyst_a.runtime_state.installed_runes
	for index: int in slots.size():
		var rune: RuneData = installed[index] if index < installed.size() else null
		slots[index].text = rune.display_name if rune != null else "Ô %d · Trống" % (index + 1)
		slots[index].modulate = rune.display_color if rune != null else Color(0.6, 0.67, 0.76)
	var recipe: ResonanceDefinition = controller.get_recipe()
	recipe_label.text = recipe.display_name if recipe != null else "Không có công thức hợp lệ"
	cooldown_label.text = "Đã gục · R để thử lại" if player.health.current_health <= 0.0 else "Hồi chiêu: %.2fs" % controller.cooldown_remaining() if controller.cooldown_remaining() > 0.0 else "Sẵn sàng · Chuột phải / I"
