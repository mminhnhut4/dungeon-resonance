extends RefCounted
## Three existing generic residents. Small memories never promise friendship.
const IDS: Array[String] = ["pilot_traveler", "pilot_bridge_keeper", "pilot_pilgrim"]
const HELP_MATERIAL: StringName = &"linen_fiber"
const HELP_COST: int = 2
const DEFINITIONS: Dictionary = {
	"pilot_traveler": {
		"personality":"Thận trọng", "help_trust":1, "help_debt":1,
		"first":"Ta còn lên xuống đoạn đèn và ghế nghỉ. Đường xa không cần vội; tin người cũng vậy.",
		"attack":"Ta nhớ ngươi đã đánh ta. Lời hỏi thăm chưa đủ để ta quên việc ấy.",
		"mercy":"Ta nhớ ngươi đã dừng tay khi ta trọng thương. Ta ghi nhận, nhưng vẫn cần giữ khoảng cách.",
		"help":"Sợi vải ngươi nhường giúp ta buộc lại đồ đi đường. Ta nhận việc giúp ấy, chưa nhận lời đi cùng.",
		"hint":"Từ mái miếu trước cửa hầm, cứ theo nền đá tới đèn nghiêng rồi ghế nghỉ. Nhánh cao là tùy chọn; đường dưới đi bộ được.",
		"help_activity":"Buộc lại đồ đi đường"
	},
	"pilot_bridge_keeper": {
		"personality":"Thực dụng", "help_trust":0, "help_debt":2,
		"first":"Ta xem dây ở hai đầu cầu rồi nghỉ cạnh đường. Người đi qua cần một lối chắc chân.",
		"attack":"Đòn của ngươi làm ta phải bỏ dở việc. Cầu vẫn cần người chăm; đừng xem im lặng là đồng ý.",
		"mercy":"Ngươi đã tha ta. Ta còn việc ở cầu phải làm; một món nợ không khiến ta thành người của ngươi.",
		"help":"Hai sợi vải đã được dùng để buộc đồ sửa dây. Ta ghi nhận món nợ này, không hứa tình bạn.",
		"hint":"Giữ nền đường qua giữa hai trụ cầu dây. Vai núi phía trên là lối nhìn cao, không bắt buộc nhảy để đi tiếp.",
		"help_activity":"Sắp đồ chăm dây cầu"
	},
	"pilot_pilgrim": {
		"personality":"Ôn hòa, giữ giới hạn", "help_trust":1, "help_debt":1,
		"first":"Ta chăm đèn rồi nghỉ cạnh miếu. Ta tự chọn công việc này và sẽ còn trở lại với nó.",
		"attack":"Ta nhớ vết thương ngươi gây ra. Ta vẫn có thể nói chuyện, nhưng nỗi sợ chưa mất.",
		"mercy":"Ta nhớ lúc ngươi dừng tay. Tha cho ta sống có ý nghĩa; nó không xóa điều xảy ra trước đó.",
		"help":"Sợi vải giúp ta chuẩn bị đồ chăm đèn. Ta biết ơn việc giúp, không hứa chuyện vượt ngoài khả năng mình.",
		"hint":"Cơ cấu đường giữ đèn nằm bên trái miếu. Cổng đường hầm và đường bộ là hai lối riêng; cứ theo nền khô để trở về.",
		"help_activity":"Chuẩn bị đồ chăm đèn"
	}
}

static func definition(id: String) -> Dictionary:
	return DEFINITIONS.get(id,{}).duplicate(true)

static func memory_lines(id: String, attacked: bool, spared: bool, helped: bool, returned: bool) -> Array[String]:
	var result: Array[String] = []
	if id not in IDS: return result
	var spec: Dictionary = definition(id)
	if returned and (attacked or spared or helped): result.append("Lại là ngươi. Ta nhớ lần gặp trước.")
	if spared: result.append(spec["mercy"])
	elif attacked: result.append(spec["attack"])
	if helped: result.append(spec["help"])
	if result.is_empty(): result.append(spec["first"])
	return result
