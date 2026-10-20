extends RefCounted
## Shared presentation wording only; stage indices and costs stay with the model.
const STAGES: Array[String] = ["Luyện Khí sơ", "Luyện Khí trung", "Luyện Khí hậu", "Trúc Cơ sơ"]
static func breakthrough_action(stage: int) -> String:
	if stage < 0 or stage >= 3: return ""
	return "%s %s" % ["Đột phá" if stage == 2 else "Tiến tầng", STAGES[stage + 1]]
