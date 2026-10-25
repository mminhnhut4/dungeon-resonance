class_name FoundationLesson
extends RefCounted
## Read-only explanation of the existing resolver and committed chain consumer.
const EXAMPLE: ResonanceDefinition = preload("res://data/resonances/firestorm.tres")

static func rune_names(ids: Array[StringName]) -> String:
	var names: Array[String]=[]
	for id: StringName in ids:names.append(RuneLearningService.NAMES.get(id,String(id)))
	return " + ".join(names) if not names.is_empty() else "Trống"

static func comparison(recipe: ResonanceDefinition) -> Dictionary:
	var before: int=0
	if recipe!=null:
		for id: StringName in recipe.recipe_rune_ids:
			for rune: RuneData in GearInventory.RUNES:
				if rune.id==id:before=maxi(before,rune.chain_targets)
	return {"before":before,"after":FoundationResonance.links_after(before) if recipe!=null and recipe.recipe_rune_ids.size()>=2 else before}

static func example_text() -> String:
	var links: Dictionary=comparison(EXAMPLE)
	return "%s → %s · trước Trúc Cơ %d → sau %d liên kết."%[rune_names(EXAMPLE.recipe_rune_ids),EXAMPLE.display_name,links["before"],links["after"]]

static func view(controller: ResonanceController) -> Dictionary:
	if not is_instance_valid(controller) or not is_instance_valid(controller.catalyst_a):return {"valid":false,"text":"Chưa đọc được bộ bùa đang dùng; mở lại sau khi vào vùng chơi."}
	var ids: Array[StringName]=controller.catalyst_a.runtime_state.installed_rune_ids
	var recipe: ResonanceDefinition=controller.get_recipe()
	var links: Dictionary=comparison(recipe)
	var enabled: bool=controller.foundation_resonance_enabled
	var reason: String
	if recipe==null:reason="Chưa có công thức khớp đủ bộ bùa Catalyst: không thể niệm, không trừ mana. Tháo bùa thừa hoặc đổi đủ bộ; bùa trên vũ khí không ghép vào đây."
	elif ids.size()<2:reason="Bộ đơn / trống không nhận thêm Liên Ấn. Ghép ít nhất 2 bùa theo công thức hợp lệ trong Catalyst."
	elif not enabled:reason="Chưa mở Liên Ấn: cần đột phá Trúc Cơ ở Sân Luyện. Phép ghép hiện tại vẫn dùng được; chỉ phần liên kết thêm còn khóa."
	elif links["before"]==links["after"]:reason="Liên Ấn đã mở; bộ này đã đủ trần %d liên kết nên không tăng thêm."%FoundationResonance.MAX_LINKS
	else:reason="Liên Ấn đang dùng: trúng mục tiêu đầu sẽ lan sang mục tiêu còn sống, ở gần và chưa trúng."
	var text: String="BỘ CATALYST · %s → %s\n%s"%[rune_names(ids),recipe.display_name if recipe!=null else "Chưa hợp lệ",reason]
	if recipe!=null:
		var current: int=int(links["after"] if enabled else links["before"])
		var cooldown: float=recipe.cooldown_seconds*controller.cooldown_multiplier*(controller.relic_cooldown_multiplier if ids.size()>=2 else 1.0)
		text+="\nTrước Trúc Cơ %d → sau %d liên kết · hiện tại %d. Mỗi liên kết %.0f%% sát thương đòn bùa; đòn chính / nổ giữ nguyên."%[links["before"],links["after"],current,SpellExecutor.CHAIN_DAMAGE_FACTOR*100.0]
		text+="\n%.0f mana/lần · hồi %.2fs, giữ nguyên khi mở Liên Ấn. Đổi bộ không xóa hồi chiêu."%[ResonanceController.CAST_ENERGY_COST,cooldown]
	text+="\nTỰ THỬ · "+example_text()+" Ở Sân Luyện, đứng giữa hai bia, nhắm bia bên phải và dùng I / chuột phải; nhìn bia sau lưng nhận liên kết."
	return {"valid":recipe!=null,"recipe":recipe,"ids":ids.duplicate(),"before":links["before"],"after":links["after"],"enabled":enabled,"reason":reason,"text":text}
