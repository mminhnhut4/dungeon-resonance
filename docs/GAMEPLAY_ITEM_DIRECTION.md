# Định hướng vật phẩm, build và căn cứ

Cập nhật 2026-10-01. Tài liệu thiết kế cho game 2D offline Godot hiện hành; không phải báo cáo gate toàn dự án. Mười hai vật phẩm đợt đầu đã được người dùng duyệt mỹ thuật. Giá bán, tỉ lệ rơi và chi phí sửa dưới đây là thông số prototype, chưa được chứng minh bằng cân bằng hoặc playtest dài hạn.

## Những quyết định đã chốt

- Bảy ô mặc riêng: Vũ khí, Áo, Quần, Giày, Găng tay, Nhẫn, Dây chuyền. Bộ khởi đầu giản dị; giữ kiếm sĩ cổ phong đã duyệt, ảnh chibi chỉ tham khảo cách chia bộ phận.
- Một hệ phẩm cấp: Thường → Hiếm → Cực hiếm → Sử thi → Huyền thoại → Thần thánh. Nguyên tố quyết định màu hiệu ứng; phẩm cấp quyết định độ đặc biệt và bùng nổ. Đồ Thường dùng hiệu ứng cơ bản gọn, dễ đọc.
- Thường/Hiếm mua ở Kael; Cực hiếm trở lên cần bản chế tạo và rèn tại Thiết Lão. World-Building bổ sung10 họ/60qualityvariants/40công thức; model riêng từng bậc làm sau lần lượt.
- Đồ hỏng phải sửa mới dùng được. Vật phẩm rơi dùng được ngay có một lợi thế nhỏ so với hàng thương nhân cùng phẩm cấp, không tự vượt sang phẩm cấp khác; tối đa một affix nhỏ. Nhánh hiện tại áp lợi thế sát thương 3–8% cho vũ khí rơi và một affix có giới hạn. Áo/găng rơi nhận affix nhỏ; không nhân toàn bộ chỉ số áo/găng thêm 3–8%.
- Vật phẩm rơi mang phẩm cấp Cực hiếm+ là **phôi**, không thể lách yêu cầu chế tạo bằng thao tác sửa hoặc xóa cờ hỏng.
- Đúc/khảm Huyền thoại+ cần Bản Nguyên Thần Thạch **chỉ rơi ở Boss đặc biệt sẽ làm sau**, không quái/elite/Golem thường/rương/shop. Hiện không có nguồn hợp lệ. Thần thánh50% thành công, thất bại mất toàn bộ vật liệu lần thử nhưng giữ công thức; tỉ lệ đá/Boss đặc biệt chưa chốt. Blueprint0,5%tổng/elite hoặcBoss rồi ưu tiên họ chưa học.
- Cường hóa tách phẩm cấp: +12 tối đa, +3%sát thương gốc/cấp,100%thành công; sáu cấp đá ghép5:1, mỗi cấp phục vụ hai mốc+.
- Quái có thể rơi rỗng hoàn toàn, có pool nguyên liệu sinh tồn theo archetype. Rương ẩn nhiều món và lượng/phẩm cấp thường tốt hơn. Các tỉ lệ guaranteed12-item bên dưới là fixture Prologue cũ; WorldCampaign dùng DropTableResource thay thế, không bảo đảm tinh thạch/Tàn Hồn mỗi kill.
- Vật liệu đã gửi kho căn cứ được giữ khi chết; vật liệu đang mang trong run mất. Đồng từ bán vật liệu tại Kael được lưu riêng với Tàn Hồn. Không đổi Tàn Hồn thành tiền mua vật phẩm thông thường.

## Nghiên cứu từ nguồn chính thức

**Hollow Knight:** Team Cherry mô tả bùa có chức năng khác nhau, tốn số notch khác nhau và có giới hạn số bùa mặc đồng thời. Có cả tiện ích nhặt tiền, định hướng bản đồ và lựa chọn đổi rủi ro lấy sức mạnh. Giá trị của danh mục nằm ở quyết định loadout và công dụng, thay vì chỉ tăng sức mạnh nền. [Nguồn: Team Cherry — Revealing the Power of the Charms](https://www.teamcherry.com.au/blog/revealing-the-power-of-the-charms).

**Hades II:** bài giới thiệu Unseen Update ngày 17-06-2025 trình bày Hidden Aspects mở một phong cách đánh khác cho từng vũ khí chính, bên cạnh nâng cấp phép và mở rộng quan hệ nhân vật. Đây là thông tin về bản cập nhật đó, không phải khẳng định phiên bản mới nhất hiện nay. [Nguồn: Supergiant — Hades II: The Unseen Update](https://www.supergiantgames.com/blog/hades2-unseen-update/).

**Tale of Immortal:** trang do nhà phát triển/nhà phát hành cung cấp trên Steam mô tả công pháp, các nhóm kỹ năng, đột phá tu luyện, quan hệ NPC, kỳ ngộ và chế tạo. Ứng dụng phù hợp cho dự án này là để căn cứ tạo mục tiêu dài hạn và mở cách chơi, trong khi mỗi run vẫn có bộ quyết định ngắn rõ ràng. [Nguồn: Tale of Immortal trên Steam](https://store.steampowered.com/app/1468810/_Tale_of_Immortal/).

**Elden Ring:** hướng dẫn chiến đấu của Bandai Namco giải thích cam kết hành động, input buffer, tiêu hao thể lực và khác biệt giữa đánh thường, chạy đánh hoặc nhảy đánh. Suy ra cho game này: tầm đánh, hướng, khoảng ra đòn/phục hồi và cửa né cần có giá trị thiết kế trước khi thêm nhiều tên vật phẩm. Giữ nhịp nhanh đã được người dùng chọn; không tự chuyển game sang nhịp Souls chậm. [Nguồn: Bandai Namco — Combat Guide](https://www.bandainamcoent.com/es_mx/news/elden-ring-introduction-part-4-combat-guide).

Những đề xuất ở phần tiếp theo là suy luận thiết kế từ các nguồn trên và quyết định của người dùng, không phải mô tả cơ chế đã triển khai trong game tham chiếu.

## Build nên được hình thành như thế nào

Một build kết hợp **moveset vũ khí + bùa khảm + Catalyst + phụ kiện + lựa chọn sinh tồn**. Mỗi nhóm cần trả lời một câu hỏi chơi khác nhau:

| Nhóm | Quyết định cho người chơi | Ví dụ hướng mở rộng, chưa triển khai |
|---|---|---|
| Vũ khí | Đánh ở khoảng cách nào, ra đòn/hồi vị ra sao? | Kiếm quét nhiều mục tiêu; dao áp sát nhanh; trượng giữ khoảng cách; roi kiểm soát vùng |
| Bùa vũ khí | Đòn trái để lại trạng thái hoặc tạo cơ hội nào? | Đốt cản đường, giữ độc trên mục tiêu, tạo cửa cho đòn Lôi tiếp theo |
| Catalyst | Chuột phải giải quyết tình huống nào, với chi phí nào? | Hút nhóm quái bằng Bão Lửa, tách nhóm hoặc giữ một cửa thoát |
| Nhẫn/dây chuyền | Cách di chuyển, tài nguyên hoặc rủi ro nào được ưu tiên? | Hoàn năng lượng có điều kiện; trợ lực khi thấp máu; hỗ trợ khám phá |
| Áo/quần/giày/găng | Bảo vệ hoặc hỗ trợ phong cách gì? | Bộ linh hoạt, bộ chịu đòn, bộ dùng phép; chỉ chọn một đánh đổi dễ hiểu mỗi món |
| Vật liệu/tiêu hao | Mang tiếp hay gửi kho, dùng ngay hay giữ cho Boss? | Bình hồi máu, băng bó chảy máu, thuốc giải đúng trạng thái Poison |

Một món mới nên tạo ít nhất một lựa chọn có thể quan sát: khoảng đánh, động tác, điều kiện kích hoạt, công dụng môi trường, quản lý năng lượng hoặc đánh đổi sinh tồn. Một tên/ảnh mới chỉ tăng ATK hơn món trước không được xem là một phong cách đánh mới. Quality runtime vẫn được phép ảnh hưởng damage/slot/proc theo quyết định hiện hành; không quay lại luật cũ cấm mọi thay đổi chỉ số.

Vũ khí nhẹ cần phản hồi nhanh và vệt gọn. Vũ khí nặng/chí mạng có nhịp và lực rõ hơn. Không để hiệu ứng Huyền thoại che telegraph hoặc tăng phạm vi va chạm vì sprite to hơn. Đòn đang bay giữ snapshot nguyên tố/phẩm cấp đã commit; thay trang bị không làm đạn cũ đổi màu, sát thương hoặc proc.

## Danh mục mỹ thuật đợt đầu — 12 món đã duyệt

Tên trong bảng là nhãn tiếng Việt dùng để giao tiếp. UID, phẩm cấp, nguồn, cờ hỏng và affix nằm trong GearItem runtime; ảnh món hỏng không phải một Definition mạnh hơn.

| Vật phẩm | ID/kiểu runtime | Vai trò và nguồn hiện tại | Giá/quy tắc prototype |
|---|---|---|---|
| Tinh Thạch | `material/crystal` | Nguyên liệu bán; pool Kiếm Linh/Hộ Pháp/Golem và rương | Kael mua5Đồng/viên từ kho; không guaranteed mỗi quái |
| Tinh Chất Slime | `material/slime_essence` | Nguyên liệu bán trong pool Slime | Kael mua3Đồng/món từ kho; quái có lượt rơi rỗng |
| Mảnh Kim Loại Cổ | `material/metal` | Rã đồ và sửa trang bị; có thể gửi/lấy kho | Chưa có giá mua/bán |
| Bột Tinh Thể Phép | `material/dust` | Rã đồ/bùa, sửa trang bị và chế tạo tiêu hao hiện hữu | Chưa có giá mua/bán |
| Kiếm Sắt Hỏng | `weapon/ancient_sword`, `broken=true` | Kiếm common trong nhóm rơi hỏng | Cần sửa trước khi đánh |
| Dao Găm Hỏng | `weapon/shadow_dagger`, `broken=true` | Dao common trong nhóm rơi hỏng | Cần sửa trước khi đánh |
| Trượng Phép Hỏng | `weapon/storm_arcane_staff`, `broken=true` | Trượng common trong nhóm rơi hỏng | Cần sửa trước khi dùng |
| Áo Lữ Hành Hỏng | `equipment/starter_top`, `broken=true` | Áo common trong nhóm rơi hỏng | Cần sửa trước khi mặc |
| Găng Tay Lữ Hành Hỏng | `equipment/starter_gloves`, `broken=true` | Găng common trong nhóm rơi hỏng | Cần sửa trước khi mặc |
| Bình Hồi Máu | `consumable/potion` | Nhặt vào túi trong run Prologue, dùng qua hệ tiêu hao | Hồi 30 HP nền, chịu hiệu quả hồi máu hiện hành; không dùng khi không hồi được máu |
| Băng Gạc | `consumable/bandage` | API loot sẵn, nối cơ chế băng bó hiện hữu | Chỉ dùng khi chảy máu |
| Thuốc Giải Độc | `consumable/antidote` | API loot sẵn, dùng qua hệ tiêu hao | Chỉ xóa Poison; không hồi HP hoặc chữa mọi vết thương |

Nhóm rơi trang bị hỏng có xác suất **8% tổng cộng** mỗi lần xử lý rơi đồ của quái trong chế độ Prologue; chọn đều giữa năm món common ở trên. Đây không phải 8% cho từng món. Lượt rơi tinh chất và lượt rơi đồ hỏng độc lập, dùng RNG kiểm soát được bằng seed. Bandage/antidote đã có đường spawn/nhặt/dùng; chưa gán thêm xác suất rơi tự động cho chúng trong bảng quái.

Sửa Thường dùng **2 kim loại + 1 bột**, sửa Hiếm dùng **4 + 2**, lấy từ kho an toàn. UI phải báo rõ giá, thiếu vật liệu hoặc phôi cần chế tạo. Giữ UID/quality/affix khi sửa; một lần bấm không reroll. Nếu ghi save thất bại thì trả vật liệu và giữ trạng thái hỏng. Rã đồ kiểm cả hai trần vật liệu trước khi tiêu hao món; đầy túi không làm mất UID.

Các flag kinh tế/loot Prologue mặc định tắt trong fixture và phòng cũ để giữ hợp đồng hồi quy. Các test cũ không được diễn giải là cân bằng cuối của nội dung mới.

## Mở rộng danh mục theo từng đợt

Đề xuất tiếp theo là một đợt nhỏ có mục đích: xác minh thương nhân, sửa đồ, bảy ô thay trang phục và hai động tác khác nhau trước khi thêm một họ vũ khí nữa. Sau đó mở vật liệu chế tạo, công thức và phụ kiện theo một khu/boss có nguồn farm rõ ràng. Mỗi đợt có ảnh mẫu được duyệt, definition/runtime riêng, luồng loot/equip/craft và hồi quy phù hợp.

Hàng trăm, rồi khoảng 1.000 vật phẩm có thể là mục tiêu dài hạn của danh mục; **chưa phải nội dung đã triển khai hoặc phạm vi được duyệt để sản xuất ngay**. Không tính các bản đổi màu, sáu phẩm cấp của cùng một moveset hoặc nhiều ATK hơn thành hàng nghìn cơ chế khác nhau. Chia theo chức năng thật: họ moveset, biến thể đòn, nguyên tố, phụ kiện có điều kiện, bộ y phục, tiêu hao, công thức, vật liệu, đồ nhiệm vụ và đồ khám phá.

Trước mỗi đợt art mới, chốt nhóm chức năng, nguồn kiếm đồ, phẩm cấp, cách dùng và bộ ảnh duyệt. Ví dụ build/phụ kiện trong tài liệu này chỉ để chọn hướng; không tự triển khai khi người dùng chưa quyết định. Shop/rèn/quest/nâng cấp NPC đã được giao trong World-Building; cảnh giới và quan hệ NPC hoàn chỉnh vẫn là bước sau. [Báo cáo triển khai](WORLD_BUILDING_REPORT.md).

## Bằng chứng của phần kinh tế hiện hành

- `tests/economy_test.gd`: **117/117 ở cả 60 và 120 physics Hz**, bao gồm nhặt một lần, frozen UID/affix, RNG seed, run mất vật liệu khi chết, kho/Đồng còn sau reload, rollback ghi file bốn tầng, load schema 1 cũ/invalid payload, sửa đồ/phôi/Q guard, thuốc giải chỉ Poison và rã đồ ở trần vật liệu.
- `save_transaction`58, `inventory_equipment`51, `Alpha`80, `crafting`32, `gear`35, `conditions`29 ở cả hai mức Hz đều 0 fail trong focused checks; sau sửa cap rã đồ đã chạy lại crafting32 và economy117 ở hai mức Hz.
- Logs: `docs/verification/prologue_economy_{60,120}_r4.log`, `prologue_crafting_{60,120}_r4.log`; các focused checks liên quan giữ ở `prologue_<suite>_<hz>_r3.log`.
- Đây là kiểm tra headless logic, không chứng minh hình ảnh hoặc cân bằng kinh tế. Full strict gate và preview/benchmark của mốc Prologue được root tổng hợp riêng sau khi tất cả module ổn định.
