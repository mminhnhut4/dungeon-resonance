class_name NpcCatalog
extends RefCounted
## Approved Vietnamese dialogue; portraits are supplied only after art review.

const SMITH: StringName = &"npc_smith"
const HEALER: StringName = &"npc_healer"
const WANDERER: StringName = &"npc_wanderer"
const NAMES: Dictionary[StringName, String] = {
	SMITH: "Thiết Lão", HEALER: "Thanh Vy", WANDERER: "Vô Danh",
}
const LINES: Dictionary[StringName, Array] = {
	SMITH: ["Thanh kiếm cổ rỉ sét trên tay ngươi... nếu tìm được Thiết Tinh và Thần Thạch trong hầm ngục, ta có thể đúc lại uy phong thực sự cho nó."],
	HEALER: ["Bùa chú trong hầm ngục đã bị oán khí ăn mòn. Đem Tàn Hồn về đây, ta sẽ giúp ngươi tịnh hóa linh thức."],
	WANDERER: ["Ta từng đi đến Tầng 4... con quái đá Golem đó không sợ kiếm chém thông thường, ngươi phải đánh vỡ lõi phù trận của nó."],
}

static func dialogue(id: StringName) -> Array[String]:
	var result: Array[String] = []
	result.assign(LINES.get(id, []))
	return result
