# Run ngắn, căn cứ tu luyện lâu dài

Ngày nghiên cứu: **2026-10-01**. Tài liệu thiết kế cho bước tiếp theo; chưa triển khai cảnh giới, nhiệm vụ NPC hoặc tuyến phòng mới.

Định hướng người dùng đã chọn: **run 15–20 phút**, tiến triển lâu dài tại căn cứ, combat nhanh và dễ đọc; đại kiếm/chí mạng cần có trọng lượng hơn. Ba ưu tiên là **ba build khác nhau, cảnh giới tu luyện và NPC gắn với khám phá**. Người dùng đã chốt thêm:

- **Đột phá mở động tác mới và cho chọn một nhánh công pháp.** Không coi đây là lựa chọn tăng chỉ số thuần.
- **Đột phá đầu tiên yêu cầu chứng tích Boss và Tàn Hồn.** Chi phí cụ thể còn cần cân bằng.
- **Phòng thưởng cho chọn một trong ba phần thưởng; quái vẫn rơi đồ.** Hai nguồn thưởng cùng tồn tại và cần cân bằng tổng lượng loot.
- **Khi chết giữ Tàn Hồn, cảnh giới, công thức và quan hệ NPC; đồ của run mất.**
- **Khởi đầu bằng kiếm; mở kit dao găm và pháp sư qua nhiệm vụ NPC.**
- **Mỗi tầng có một cơ hội tìm bí mật; vị trí và gợi ý thay đổi theo seed.**
- **Tại Hub chọn một trợ lực NPC trước run; khám phá mở thêm lựa chọn cho những run sau.**

Đây là quy tắc đã được xác nhận cho hướng phát triển. **Cảnh giới, quan hệ/nhiệm vụ NPC và phòng chọn thưởng mới chưa được hiện thực.** Thời lượng campaign hiện tại chưa được cân bằng hoặc xác nhận đạt 15–20 phút.

## Những gì đã có và khoảng trống cần giải quyết

| Phần | Đã có trong project | Khoảng trống của slice tiếp theo |
|---|---|---|
| Combat/build | Gear-driven moveset, melee/cast theo chuột 360°, năm nguyên tố/mười cặp cộng hưởng, cổ vật, energy và cooldown | Chưa có lộ trình khởi đầu kiếm → nhiệm vụ NPC → mở hai kit còn lại; phím debug cấp đồ không thay thế phần thưởng thật |
| Chuyến đi | Tiền sảnh → phòng bí mật 1.5 → hai wave đột biến → Golem 500 HP, retry/victory/Hub | Tuyến ngắn đang là phòng kiểm chứng; chưa có nhịp thưởng và độ dài một run mục tiêu |
| Tiến triển | Tàn Hồn giữ qua chết, mở Quạt 50/Trượng 75, lưu công thức 5; phẩm cấp và chế tạo trong run; lỗi giao dịch save đã có rollback | Chưa có cảnh giới, bí kíp vĩnh viễn theo nhánh hay điều kiện đột phá |
| Khám phá | Tường ảo/rào Hỏa/rương/cổ vật, thương nhân incident | Chưa có nhiệm vụ NPC, quan hệ hoặc bí mật có dấu vết xuyên run |
| Trình diễn | Rig/PNG, HUD, GPU VFX/SFX; procedural animation/hit feedback/audio trọng lượng đã hiện thực trong milestone này | Cảm giác theo tay và chất âm vẫn cần playtest của người dùng; kiểm thử kỹ thuật không tự chứng minh cảm giác tương đương game tham chiếu |

Nguồn trạng thái: [PROJECT_STATE.md](PROJECT_STATE.md), [ALPHA_GAMEPLAY.md](ALPHA_GAMEPLAY.md), [DEEP_ROGUELITE.md](DEEP_ROGUELITE.md), [MILESTONE_CONTENT_REPORT.md](MILESTONE_CONTENT_REPORT.md). Báo cáo Content/Alpha là mốc lịch sử; quyết định hiện hành trong Project State/Decisions có ưu tiên.

## Điều học từ ba trò chơi

- **Hades II:** thông báo Olympic Update nêu weapon Aspects, Crossroads, Allies và Keepsakes. Đây là tham chiếu cho cách vũ khí, NPC và căn cứ tạo lý do quay lại. Trang này không mô tả thuật toán hit-stop, camera hoặc animation nội bộ. [Nguồn Supergiant](https://www.supergiantgames.com/blog/hades2-olympic-update/).
- **Tale of Immortal:** mô tả của nhà phát triển có đột phá tu luyện, võ học/bí kíp, NPC và tông môn. Dự án lấy ý tưởng tiến triển có lựa chọn và quan hệ gắn với khám phá; chưa dựng thế giới mô phỏng NPC độc lập ở quy mô đó. [Trang nhà phát hành trên Steam](https://store.steampowered.com/app/1468810/_Tale_of_Immortal/).
- **Chú Bé Rồng Online:** hướng dẫn chính thức liên kết KI với bay/dùng kỹ năng và điểm tiềm năng với học sách kỹ năng. Tham chiếu hữu ích là tài nguyên chiến đấu dễ hiểu và lộ trình học chiêu; thiết kế bên dưới vẫn giữ game offline. [Hướng dẫn chính thức](https://ngocrongonline.com/trang-chu).

Các cơ chế cụ thể dưới đây là **đề xuất cho Dungeon Resonance**, không phải thông số hoặc hành vi đã được xác nhận của ba game tham chiếu.

## Vòng lặp đề xuất

**Hub: chọn trang bị + một nhánh công pháp đã học + một trợ lực NPC → run: nhặt đồ quái rơi, chọn 1/3 ở phòng thưởng, hoàn thiện cộng hưởng, tìm manh mối → Boss: nhận Tàn Hồn/chứng tích → Hub: học động tác hoặc đột phá, NPC phản hồi sự kiện vừa xảy ra và mở thêm trợ lực cho run sau.**

Theo lựa chọn người dùng, trang bị/bùa/cổ vật nhặt trong run là tài nguyên tạm và mất khi chết. Tàn Hồn, công thức, cảnh giới và quan hệ NPC được giữ xuyên run. Cờ nhiệm vụ gắn với quan hệ cần được lưu riêng với item/UID tạm; đây là thiết kế chưa code. Trong code hiện có, profile mới lưu Soul/unlock/công thức/style/vũ khí khởi đầu; không mô tả các trường cảnh giới/quan hệ tương lai như chức năng đã chạy.

### Nhánh A — Ba build có quyết định khác nhau

Ba bộ sau dùng dữ liệu đang có làm điểm xuất phát; nội dung kit cụ thể vẫn là đề xuất, chưa được cấu hình như chế độ chơi mới. Theo lựa chọn người dùng, lộ trình tương lai khởi đầu kiếm, rồi nhiệm vụ NPC mở kit dao găm và pháp sư. Vũ khí/bùa vẫn đổi tự do sau khi mở, không khóa nhân vật vào class.

Profile hiện tại mặc định đã mở Kiếm Cổ/Dao Găm Ám Khí và campaign prototype còn cấp các archetype để thử. Quy tắc khởi đầu mới **chưa thay các hành vi đó trong code**; khi hiện thực cần một lộ trình fresh start rõ ràng và giữ mở khóa của save cũ, không xóa tiến triển đã có để ép lại tutorial.

| Build thử | Trang bị/cộng hưởng | Quyết định chơi | Đánh đổi và điểm kiểm chứng |
|---|---|---|---|
| **Trảm Hỏa** | Trảm Ma Đao; khảm Hỏa; Catalyst Hỏa+Phong/Bão Lửa; Huyết Thạch | Gom nhóm bằng phép rồi chọn thời điểm chém nặng để kết liễu | Wind-up dài cần đọc telegraph; heal chỉ từ killing blow melee theo luật hiện có, không từ DOT |
| **Tật Lôi** | Tật Phong Chủy Thủ; khảm Lôi; Catalyst Phong+Lôi/Dao Sét; Lông Vũ | Đổi vị trí, đánh gần rồi rút ra để phóng dao phủ nhiều góc | Tầm dao ngắn; dash thêm vẫn chịu energy/cooldown/injury, không nhận charge miễn phí nhờ đổi đồ |
| **Ấn Sư Quá Tải** | Lạc Lôi Trượng; khảm Hỏa hoặc Lôi; Catalyst Hỏa+Lôi/Overload; Chu Sa | Giữ khoảng cách, chọn nhịp niệm và khoảng tụ quái để nổ | Chi phí năng lượng và cooldown làm mất quyền spam; Boss nhận luật chống khống chế hiện có |

**Luật đã chốt:** phòng thưởng đưa ba lựa chọn và người chơi lấy một; quái vẫn rơi đồ qua loot pipeline hiện hữu. Đề xuất nội dung ba lựa chọn là một nối tiếp build hiện tại, một mở hướng khác, một hỗ trợ sinh tồn; mỗi lựa chọn có tên, preview và hành vi. Chọn một chỉ cấp một lần bằng UID/reward ID thật, không phải lệnh debug. Cần tính cả loot quái và phần thưởng phòng khi đo economy, không tăng hai nguồn độc lập rồi kết luận build cân bằng.

**Acceptance của slice A:** fresh start bắt đầu bằng kiếm; UI hiển thị điều kiện nhiệm vụ cho hai kit đang khóa. Hoàn thành nhiệm vụ NPC mở mỗi kit đúng một lần và sau đó chọn/chơi được cả ba từ UI chính; không cần F5/F6 hoặc auto-grant prototype. Save cũ vẫn giữ đồ đã mở. Phòng thưởng chỉ claim một trong ba, không duplicate UID; quái vẫn thả loot theo luật cũ. Đổi bùa không sửa projectile đã phóng/reset cooldown. Qua cùng một phòng và Boss, ba kit phải có chuỗi hành động khác nhau quan sát được; so sánh thời gian clear, số lần cast/dash, sát thương nhận và mức energy cạn. Không kết luận cân bằng chỉ từ DPS bia tập.

### Nhánh B — Cảnh giới mở cách chơi

Đề xuất ba mốc tên tạm: **Luyện Khí → Trúc Cơ → Kết Đan**. Slice đầu chỉ làm **một lần đột phá Luyện Khí→Trúc Cơ**; hai mốc sau giữ trong backlog.

- **Luyện Khí:** học điều khiển và ba archetype; dùng công thức/gear hiện có.
- **Trúc Cơ:** theo luật đã chốt, đột phá mở động tác mới và cho chọn **một nhánh công pháp**. Đề xuất ba nhánh tương ứng ba build; trước run chọn một nhánh đã học. Nội dung động tác cụ thể còn cần thiết kế: nhát nặng được thưởng khi canh thời điểm, chuỗi dao được thưởng khi giữ khoảng cách hợp lý, hoặc niệm phép được thưởng khi chọn thời cơ. Không cộng đồng thời mọi nhánh đã học.
- **Kết Đan:** đề xuất mở thử thách/biến thể Boss và bước tiếp theo của NPC; chưa chốt phần thưởng cơ học.

Đột phá đầu tiên đã được chốt yêu cầu **một chứng tích Boss đã hoàn thành + một khoản Tàn Hồn**. Chi phí chưa chốt; dữ liệu hiện tại là elite 3, Boss 25, mở Quạt 50/Trượng 75 và archive 5 Tàn Hồn. Cần đo số run đến đột phá và nhu cầu cạnh tranh với các khoản mở khóa trước khi đặt giá; không thêm một ví XP mới chỉ để kéo dài grind. Chứng tích phải là tiến độ Boss đã commit, không phải item tạm có thể nhân đôi hoặc mất sau chết.

**Acceptance của slice B:** thiếu chứng tích Boss hoặc thiếu Tàn Hồn đều không đột phá; đủ cả hai mới commit một lần, mở động tác có thể thực hiện thật và chỉ một nhánh công pháp hoạt động. Chết/chuyển phòng không mất cảnh giới đã lưu. Chọn công pháp không sửa Resource định nghĩa dùng chung. Save cũ nạp được sau migration và save hỏng dùng backup; lỗi ghi phải báo thất bại và không trừ Tàn Hồn/mở khóa một nửa. Gói hiện tại đã sửa giao dịch `SanctuaryProfile`: rollback RAM, chỉ phát `changed` sau commit, giữ backup hợp lệ, chặn ghi đè schema tương lai và chọn vũ khí khởi đầu qua setter có giao dịch. `SaveTransaction` đạt **58/58 ở cả 60/120 Hz**. Việc lưu cảnh giới/quan hệ tương lai vẫn chưa code, không được suy ra từ kiểm thử sửa save này.

### Nhánh C — NPC khiến bí mật có ý nghĩa

Đề xuất dùng **Kael**, art thương nhân đã có, làm NPC đầu tiên thay vì đồng loạt thêm nhiều người. Không suy ra art này đã đồng nghĩa một NPC gameplay hoàn chỉnh.

Chuỗi nhiệm vụ đề xuất: **Kael đưa dấu hiệu về kho ngọc → người chơi nhận ra tường ảo trong run → thu manh mối qua vật nhặt thật → trở về Hub hoặc chọn mang theo đến Boss → Kael phản hồi và mở kit dao găm.** Chặng tiếp theo tìm văn khắc/bùa để học kit pháp sư. Nội dung hai chặng chưa được người dùng chốt; chúng thực hiện lộ trình mở kit qua NPC đã xác nhận. Trạng thái tối thiểu từng chặng là chưa nhận/đang tìm/đã tìm/đã trả; scene NPC đọc cờ, không giữ Node của phòng cũ.

- Bí mật được gợi bằng vết nứt, bùa hoặc lời thoại, tránh chỉ có kiến thức ngoài game mới tìm được.
- Theo luật đã chốt, mỗi tầng có một cơ hội bí mật; seed chọn vị trí/gợi ý từ các mẫu đã được dựng và kiểm chứng. Cùng seed/catalog phải chọn cùng cơ hội, nhưng không hứa replay vật lý hoàn toàn xác định. Tuyến phòng hiện tại chưa có cơ chế chọn bí mật theo seed này.
- Rào Hỏa vẫn dùng năng lực nguyên tố hiện có. Main route cần đi được với cả ba build; phần thưởng bí mật có thể khác theo cách mở, nhưng không khóa hoàn thành run vì thiếu Hỏa.
- Theo luật đã chốt, tại Hub người chơi chọn **một trợ lực NPC cho toàn bộ run**. Khám phá mở thêm các lựa chọn cho run sau, không tự đổi hoặc cộng thêm trợ lực vào run đang diễn ra. Có nhiều NPC về sau vẫn không đồng nghĩa lấy một buff từ mỗi NPC rồi chồng tất cả.
- Manh mối/quest reward là giao dịch có ID và cờ claim để không thể nhận lặp bằng chết, retry hoặc load save.

**Acceptance của slice C:** mỗi tầng có đúng một cơ hội bí mật hợp lệ; tập seed thử phải đổi vị trí/gợi ý và không tạo cửa hoặc reward trùng. Tìm bằng tương tác môi trường thật, không F7; có phản hồi khi gặp lại Kael sau thắng và thua. Hai lần nói chuyện không nhân reward. Hub chỉ xác nhận một trợ lực trước run; khám phá mở lựa chọn mới nhưng không sửa trợ lực đã snapshot cho run hiện tại. Quan hệ NPC và cờ quest đã commit giữ qua chết; item nhiệm vụ tạm không được giữ lén cùng inventory của run. Bỏ qua bí mật vẫn tới Boss. Chuyển Hub/dungeon nhiều chu kỳ không giữ NPC, loot hoặc callback của phòng cũ.

## Thứ tự thực hiện và phụ thuộc

| Lát cắt | Phụ thuộc | Đầu ra chơi được | Điều kiện đi tiếp |
|---|---|---|---|
| **P0: Combat đọc được** | Milestone Polish hiện tại đã tích hợp | Nhân vật có nhịp vận động/bóng, impact phân mức, SFX có trọng lượng, hỗ trợ giảm rung | Gate cuối đạt; giữ kiểm chứng trực quan/game feel trong báo cáo milestone |
| **A0: Kit + thưởng** | P0 và inventory UID hiện có | UI khởi đầu kiếm/hiển thị hai kit đang khóa, chọn 1/3 reward sau phòng; cung cấp hook mở kit cho C0 | Reward không dùng debug grant; Acceptance A hoàn tất khi nối nhiệm vụ C0 |
| **R0: Nhịp run** | A0 | Tuyến thử khoảng 10–12 phòng gồm combat, nghỉ/thưởng và tùy chọn khám phá; giữ Boss hiện có | Playtest timed nhiều kit đạt mục tiêu 15–20 phút; ghi riêng thời gian combat, modal, nghỉ, tìm bí mật; số phòng là giả thuyết cần điều chỉnh |
| **B0: Một đột phá** | Giao dịch save an toàn và số run kiếm Soul từ R0 | Luyện Khí→Trúc Cơ mở động tác, chọn một nhánh công pháp trước run | Acceptance B; thêm save migration trước dữ liệu mới |
| **C0: Kael + một bí mật** | Nền inventory/reward A0, lưu cờ quest; reward không duplicate | Một chuỗi NPC mở hai kit/trợ lực; chọn một trợ lực tại Hub, một cơ hội bí mật mỗi tầng theo seed | Acceptance C; không cần sandbox tông môn/NPC tự sống |

B0 và C0 có thể làm song song sau khi nền save/reward ổn, rồi nối vào **cùng một chuyến đi**. Slice tích hợp cần một quan hệ nhân quả chơi được: **build chọn trong Hub → room reward hoàn thiện build → năng lực mở bí mật/manh mối NPC → NPC/chứng tích giúp đột phá → động tác mới thay cách chơi run sau**. Người chơi phải quan sát được các mối nối này, không chỉ mở ba bảng UI độc lập. Không mở thêm mười loại quái hoặc nhiều cảnh giới trước khi slice này có lý do chơi lại rõ ràng.

## Các quyết định định hướng đã chốt

Các câu hỏi định hướng trong vòng trao đổi này đã được trả lời, gồm thời điểm trợ lực NPC: **chọn một tại Hub trước run; discovery mở thêm lựa chọn cho run sau**. Không hỏi lại các quy tắc đã ghi ở đầu tài liệu. Tên công pháp, động tác cụ thể, nội dung nhiệm vụ, giá đột phá và nhịp thưởng vẫn cần thiết kế/playtest trong slice tiếp theo; chúng không làm thay đổi các quyết định đã chốt.

## Ranh giới kiểm chứng

Roadmap chưa chứng minh cân bằng kit, run 15–20 phút, hiệu quả cảnh giới hay mức gắn bó NPC. Gate strict cuối đã đạt **2.857/2.857**, exit0, 0 fail; thêm **448** lượt kiểm tra so với mốc Full Visual 2.409. AudioWeight **47/47**, SaveTransaction **58/58** và DynamicVFX **30/30** ở cả 60/120 Hz; DynamicVFX có kiểm vòng đời HUD sau khi Boss đã giải phóng. Đây là nghiệm thu feel/save của milestone hiện tại, không là bằng chứng hệ cảnh giới/NPC/phòng thưởng hoặc bí mật theo seed đã chạy. Khi từng hệ thống tương lai được hiện thực, cần bổ sung reward idempotency/UID, công pháp snapshot/cooldown, save migration, quest claim/death/retry, seed/secret placement và nhiều chu kỳ Hub↔Dungeon. Gate mặc định vẫn gồm import/editor/addon/gameplay; headless không thay cho playtest cảm giác và nghe âm thanh. Chi tiết kiểm thử/render hiện tại xem báo cáo milestone, không lấy roadmap làm báo cáo hiệu năng.
