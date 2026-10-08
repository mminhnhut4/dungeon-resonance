# Tông môn, nhân quả và đệ tử đồng hành

Ngày 08/10/2026. Tài liệu nghiên cứu và hợp đồng triển khai, tiếp nối source `f626fd9`. Các mục ghi **đề xuất** chưa là luật đã duyệt hoặc tính năng đã chạy. Lát cắt NPC trong phiên này được kiểm và bàn giao riêng; không lấy NPC có tên môn phái làm bằng chứng hệ truy nã đã hoàn thiện.

## Luật người dùng đã chốt

1. Có các môn phái và đệ tử đi tuần. Tu sĩ có thể đánh trả khi bị tấn công.
2. Cá nhân tại chỗ phản ứng ngay. Cả môn phái chỉ ghi thù sau khi có nhân chứng, báo tin hoặc bằng chứng hợp lệ; không tự biết mọi việc ngoài tầm quan sát.
3. **Mọi NPC không chết vĩnh viễn.** Họ có thể trọng thương, rút lui và dưỡng thương. Yêu cầu này thay cơ chế lựa chọn giết/tombstone trong pilot cũ.
4. NPC trọng thương trở lại sau một chuyến hầm ngục kết thúc hoặc quay về. Giữ danh tính và ký ức về sự việc, không tạo người mới để xóa thù/nhận lại thưởng.
5. Thuê **một người cho một chuyến hầm ngục**, phí Linh Thạch cố định trả trước, không chia loot. Giá cụ thể và điều kiện nhận hợp đồng còn cần cân qua chơi thử.
6. Giữ tu tiên, class do trang bị, bùa/cộng hưởng là tấn công chính và khám phá qua nhiệm vụ. Thuộc môn phái không tự thay class, tăng damage hoặc mở khóa vùng đang bị nhiệm vụ chặn.
7. Người chơi tự vệ trước bên chủ động truy sát không tăng truy nã. Đánh tiếp người đã rút lui là vụ gây hấn mới.

Do luật số 3, thuật ngữ “giết NPC” trong ý tưởng đầu được đổi thành đánh trọng thương hoặc ép rút lui. Truy bắt/truy nã có thể bắt nguồn từ hành hung nghiêm trọng hoặc tái phạm; không ghi tội giết người khi gameplay không có cái chết đó.

## Điều đã có trong source

| Thành phần | Hiện trạng và giới hạn |
|---|---|
| `NpcWorldState`, `NpcPopulation`, `NpcPilotActor` | Sáu cư dân có ID ổn định, lịch đi/làm/nghỉ 4 Hz và actor thuộc phòng. Bản trước phiên này chạy trốn/trọng thương, chưa đánh trả; lựa chọn giết tạo trạng thái terminal trong sidecar schema2. |
| `OpeningSocialRuntime`, `NpcSocialProgress` | Có giao dịch nhường vải cho ba cư dân, quan hệ trust/fear/debt, receipt và kiểm life identity. Đây chưa là danh tiếng tông môn. |
| Thiết Lão, Thanh Vy, Vô Danh, Hạnh, Lạc Ấn | Dùng các owner tương tác/dịch vụ hiện hữu. Không đồng nhất họ với pilot actor có Hurtbox; chưa biến tất cả NPC nhiệm vụ thành đấu sĩ. |
| Damage pipeline | Hitbox → Hurtbox → DamageResolver → Health; có root/parent, source instance và team. Chưa có stable instigator/đơn thuê hoặc quyền tự vệ liên phòng. |
| Ngoại cảnh | SafeHub giữ Player tối thiểu 1 HP. Lát cắt tu sĩ không tự đổi luật mất đồ/chết/bị bắt ngoài trời. |
| Lưu | Core profile/writer giữ seal2/float64/UID và giao dịch; NPC life có owner sidecar hiện hữu. `npc_social` quarantine riêng. Không thêm writer theo từng môn phái. |

Nguồn triển khai: `scripts/npc/`, `scripts/combat/damage_event.gd`, `hurtbox.gd`, `scripts/hub/game_flow.gd`, `scripts/hub/safe_hub_component.gd`, `scripts/cultivation/opening_npc_life_adapter.gd`. Các fixture trong `tests/integration_fixtures` không được tính là runtime đã nối.

## Vòng chơi đề xuất

Người chơi gặp tuần tra và nhìn rõ phù hiệu/tên môn phái, hoạt động cùng thái độ hiện tại. Có thể trò chuyện, nhường đường hoặc gây xung đột. Nếu bị đánh, tu sĩ tự vệ, báo đòn rõ rồi phản công trong khu vực có giới hạn. Khi một bên rút lui hoặc trọng thương, giao tranh dừng theo lý do được hiển thị. Sự việc được nhân chứng mang về báo; sau khi môn phái nhận báo cáo, người chơi thấy lý do quan hệ thay đổi và phương án giải quyết.

Khi đủ điều kiện thuê, người chơi chọn một đệ tử ở căn cứ, xem vai trò, phí và điều kiêng kỵ trước khi nhận hợp đồng. Người đó hỗ trợ cùng chuyến đi, có thể trọng thương/rút lui và trở lại sau chuyến. Không tăng số thành viên bằng cách đi qua cửa, tải lại hoặc gọi NPC nhiều lần.

## Ba loại ký ức cần tách

| Loại | Chủ thể nhớ | Ý nghĩa |
|---|---|---|
| Quan hệ cá nhân | Người bị hại, người được giúp, nhân chứng | Người này tin, sợ hoặc mang ơn ai. Tha người do chính mình đánh không tự tạo công đức. |
| Quan hệ môn phái | Môn phái sau khi nhận báo cáo | Quyết định tiếp khách, giao nhiệm vụ, cho thuê đệ tử, yêu cầu hòa giải. Không suy từ một thành viên xấu tính thành cả phái biết hết. |
| Trạng thái truy nã | Đơn vị thực thi với hồ sơ vụ việc | Một hành động hữu hạn: tìm, cảnh cáo, yêu cầu bồi thường hoặc truy bắt. Không đồng nghĩa mọi NPC cùng chuyển thành quái. |

Các con số ngưỡng, thời gian và phí đều để sau playtest. Không tăng/giảm cả ba chỉ số từ mỗi tick sát thương.

## Hợp đồng nhân quả

Một vụ việc phải trả lời được: **ai khơi mào, ai đánh ai, ai thật sự thấy, ai báo tin, lúc nào môn phái biết và phản ứng vì lý do nào**.

Đề xuất dữ liệu vụ việc gồm `incident_id`, stable actor/life ID của tác nhân và nạn nhân, người ra lệnh nếu có, room, root của đòn đầu, trạng thái giao tranh, kết quả trọng thương/rút lui, danh sách quan sát và báo cáo. Không lưu Node hoặc instance ID làm danh tính lâu dài. `source_id` của DamageEvent vẫn hữu ích để resolve tác nhân đang sống; nó không thay stable ID trong save.

- Chỉ accepted damage hoặc hành động gameplay có owner xác nhận mới tạo hậu quả. Đòn miss, bị block hoặc duplicate không tạo tội như đã gây thương tích.
- DOT, chain/proc và đòn con giữ đường nhân quả về đòn gốc. Một bùa cháy nhiều nhịp không tự thành nhiều vụ độc lập.
- Một đợt cố ý đánh tiếp có thể làm vụ việc nghiêm trọng hơn. Không cho lợi dụng “chỉ một đòn” để trọng thương người rồi luôn được xem là vô ý.
- Tác nhân trực tiếp, người thuê và người ra lệnh là các trường khác nhau. Đồng hành tự vệ không tự động được quy thành người chơi ra lệnh hành hung.
- Rút lui, đổi phòng và save/load không xóa ký ức. Đồng thời kết thúc một giao tranh không cho AI đuổi vô hạn qua mọi scene.

**Tự vệ đã chốt:** phản công kẻ khơi mào không tăng tội mới; tấn công người đã rút lui mở vụ gây hấn mới. Giữ ngữ cảnh người khơi mào thay vì chỉ xét NPC đang màu đỏ. **AoE còn là đề xuất:** một hit lan nhẹ cho cơ hội dừng tay; accepted damage vẫn khiến nạn nhân phòng vệ, và trọng thương do một đòn không được miễn trách nhiệm.

## Nhân chứng và báo tin

Chuỗi trạng thái đề xuất:

`Sự việc xảy ra → Quan sát trực tiếp / phát hiện dấu vết → Đang mang tin → Báo cáo được nhận → Môn phái phản ứng`

Nhân chứng trực tiếp cần ở vị trí và tầm nhìn hợp lệ. Người chỉ nhìn thấy một tu sĩ bị thương chưa chắc biết thủ phạm. Một người nghe kể lại cùng một vụ không tạo thêm chứng cứ độc lập. Nạn nhân còn sống có thể báo khi rút về hoặc hồi phục; đánh trọng thương người báo tin không xóa điều họ đã biết.

NPC báo tin phải có đích đến và thời điểm chuyển giao. Khi đi khỏi phòng, dữ liệu báo tin sống ở owner của phiên/save, không bị hủy theo actor. Không bắt buộc mô phỏng từng bước chân ngoài màn: có thể dùng tiến độ hành trình có điểm xuất phát/đích và sự kiện đến nơi, nhưng kết quả phải theo cùng luật với khi nhìn thấy.

UI nên dùng câu ngắn có nguyên nhân: “Đệ tử đang về báo việc bạn tấn công trước”, “Thanh Vân Môn đã nhận báo cáo”, “Vụ việc đang được hòa giải”. Không âm thầm trừ điểm rồi đột ngột cho cả bản đồ tấn công.

## Truy bắt và giải quyết xung đột

Đề xuất phản ứng tăng dần: đề phòng → yêu cầu giải thích/bồi thường → từ chối một số dịch vụ → tuần tra tìm người → truy bắt hữu hạn. Mỗi đợt có người chỉ huy, vùng tìm kiếm, thời hạn và điều kiện dừng. Không sinh địch ngay trên người chơi, trong modal, tại điểm hồi phục hoặc vô hạn mỗi lần đổi phòng.

Hòa giải cần gắn với vụ việc đã có: bồi thường, cứu giúp, hoàn thành việc chuộc lỗi hoặc có nhân chứng minh oan. Không dùng tiền mua xóa ký ức cá nhân tuyệt đối. Người bị hại có thể vẫn dè chừng dù vụ việc đã giải quyết.

**Chưa chốt:** kết quả khi Player bị tu sĩ hạ ngoài trời (bị đẩy khỏi khu vực, được đưa về căn cứ hay bị giữ để đối thoại), mức phạt và điều kiện truy nã. Lát cắt hiện tại giữ SafeHub 1 HP; không tuyên bố đã có hệ bắt giữ.

## Hợp đồng đồng hành một chuyến

Một hợp đồng do owner chuyến đi giữ, tham chiếu stable NPC/life ID. Chỉ có một slot đồng hành. NPC chuyển room cùng chuyến, không nhân đôi actor/UID hoặc tự vượt cổng khóa nhiệm vụ.

Thông tin trước thuê: vai trò chiến đấu, giá/cách trả, điều kiện rút lui, thái độ với các phái và nơi quay lại sau chuyến. Lệnh tối thiểu đề xuất: theo sau, giữ vị trí, đánh mục tiêu hợp lệ, rút lui. Không điều khiển đệ tử dùng thân đỡ mọi đòn đến chết; trọng thương làm họ rút khỏi chuyến.

Kết thúc hợp đồng khi thắng, thất bại hoặc về sớm. Phí cố định trả trước, không chia loot theo lựa chọn người dùng. Hợp đồng cần nói rõ phí cho sự tham gia hay kết quả và có hoàn phí khi về sớm hay không. Không lấy gear UID của người chơi làm trang bị NPC rồi sinh bản sao. Giá cụ thể chưa chốt.

Nếu người chơi gây hấn với đồng môn của người đi cùng, đệ tử cần báo trước việc từ chối lệnh/rời đội. Các điều kiện đó phải hiện trước khi thuê, không trở thành hình phạt bất ngờ.

## Lát cắt triển khai trong phiên này

- Sửa khe bậc Tiền Sảnh đã tái hiện bằng input/physics thật; không đổi motor/FSM Player.
- Chuyển NPC life sang chính sách không chết vĩnh viễn. Giữ lịch sử tombstone cũ trong dữ liệu lịch sử, không xóa record, thay stable ID, đặt lại quan hệ hoặc cho nhận thưởng lần nữa. Migration phải qua backup/validation/rollback, dữ liệu tương lai/lỗi vẫn quarantine.
- Thêm hai tu sĩ thử nghiệm trên các đoạn đường hiện có: Thanh Vân Môn thiên về kiếm và giữ khoảng cách; Xích Lô Phái thiên về hộ vệ và đòn nặng. Dùng art hiện có để kiểm hành vi; chưa gọi là bộ hình/animation cuối của tông môn.
- Patrol, tự vệ, tell/active/recovery, ngừng đòn khi bị ngắt, giới hạn truy đuổi và rút lui khi trọng thương. Cá nhân giữ quan hệ qua life owner hiện có.
- GameFlow nối hồi phục sau real dungeon return; load game, mở menu hoặc đi cửa đường bộ không tự chữa lành NPC. Lỗi ghi phải giữ trạng thái có thể retry, không nhân đôi tiền/đồ khi về.

Các mục witness/reporting toàn phái, truy nã, hòa giải, hợp đồng thuê và gia nhập môn phái vẫn là thiết kế. Chúng cần lát cắt tiếp theo với UI, persistence và playtest riêng; không tự mở đầy đủ chỉ vì hai NPC mới có faction label.

## Lộ trình và kiểm chứng

| Giai đoạn | Kết quả cần có | Kiểm chứng bắt buộc |
|---|---|---|
| A — Tu sĩ hiện diện | Tuần tra, phản công, ngừng giao tranh, không chết vĩnh viễn | Actual hitbox/damage, tell và active khớp, downed không tiếp tục đánh, không farm thưởng, save/load/migration, leash và scene cleanup |
| B — Một vụ việc có báo tin | Hai thành viên một phái, một người chứng kiến và báo về | Có/không tầm nhìn, chưa báo thì phái chưa biết, đổi scene/cold load giữ tin, cùng vụ không nhân đôi, tự vệ/AoE đúng luật |
| C — Phản ứng phái và hòa giải | Một đợt truy bắt hữu hạn, lý do và đường giải quyết | Không khóa vòng nhiệm vụ, không spawn bất công, làm hòa giữ lịch sử, writer lỗi rollback, không tăng save mỗi hit |
| D — Một hợp đồng | Thuê một người cho một chuyến, ra lệnh và về | Chi phí một lần, qua cửa không nhân đôi, đúng liability, trọng thương/rút lui, về sớm/thắng/thua/cold load và lỗi lưu |

Core extension hiện có trần 8 scope, 256 receipt/scope và state 16 KB. Không ghi mọi hit, bước chân hoặc lời đồn thành receipt riêng; cần gộp incident và chính sách lưu lịch sử hữu hạn có audit trước khi dùng hết hạn mức. Mọi tối ưu phải giữ authority và độ bền save, nhất là khi synchronous save peaks vẫn là lỗi đã đo từ phiên trước.

Headless PASS chứng minh hợp đồng logic trong fixture. Ảnh chứng minh binding/hình ở thời điểm chụp. Nghiệm thu trải nghiệm cần chơi tự nhiên: vô tình trúng NPC, dừng tay, nhìn họ báo tin, thấy hậu quả có lý do, giải quyết rồi thuê đi một chuyến mà không mắc kẹt nhiệm vụ.

## Nguồn tham khảo và giới hạn áp dụng

- [Rockstar, Title Update 1.11](https://support.rockstargames.com/articles/6dT8UroC7aKslsqA38oaxj/red-dead-redemption-2-title-update-1-11-notes-ps4-xbox-one): phần Red Dead Online có sửa nhận diện tự vệ và một số trường hợp bị quy tội nhầm. Dùng làm tiền lệ cho việc xác định người khơi mào, không suy thành thuật toán nhân quả/AoE của game này.
- [ESO, hướng dẫn Questing & Exploration](https://www.elderscrollsonline.com/en-us/newplayerguide/questing): hậu quả liên quan tội bị chứng kiến và bounty. Nạn nhân trong luật đó báo ngay; mô hình mang tin có độ trễ ở tài liệu này là đề xuất riêng theo lựa chọn của người dùng.
- [ESO, Patch Notes v7.0.5](https://forums.elderscrollsonline.com/en/discussion/575323/pc-mac-patch-notes-v7-0-5-blackwood-update-30): tiền lệ về phản hồi quan hệ đồng hành, điều kiện rời đội, lệnh chiến đấu và hồi phục. Đây là tài liệu phiên bản 2021, không được dùng như mô tả tính năng hiện tại của ESO hoặc luật thuê đã có trong Dungeon Resonance.

Không sao chép asset, tên nhân vật, thế giới hay số cân bằng từ các nguồn. Các luật được đánh dấu đã chốt phía trên đến từ người dùng; thuật toán, dữ liệu và lộ trình là đề xuất cho kiến trúc dự án hiện tại.
