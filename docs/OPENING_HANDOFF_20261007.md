# Bàn giao baseline mở đầu — 2026-10-07

Nguồn hiện hành là `D:/hầm ngục`, game Dungeon Resonance, Godot `4.7.2.stable.official.ed1daf0bf`, renderer GL Compatibility. Main scene là `res://scenes/maps/prologue_hub.tscn`. Đây là baseline nguồn local có phần mở đầu đã kiểm ở phạm vi dưới đây; chưa là nghiệm thu toàn bộ game hoặc bản phát hành.

## Thay đổi mới đã áp dụng

Chỉ một runtime file `scripts/ui/quest_journal.gd`: đưa nút **Bỏ theo dõi nhiệm vụ** lên hàng tiêu đề, nhìn thấy ngay mà không cần cuộn. Giữ callback, disabled state, theme cổ vàng–đỏ, hai cột map/quest và luồng input hiện hành. Source output SHA256 `cc26be9ce0000af4a907c3ee0f3410e2f8c18edceea9068dadb6e4ae869bafb4`. Không áp lại gói NPC/quái/khung vùng28file của Oct3, không thay schema/save writer hoặc currency backend.

## Kết quả mới

Trước làm việc, 2.112 nguồn khớp checkpoint Oct5; không thiếu, không drift hoặc nguồn bổ sung. Toàn bộ nguồn đã sao lưu và bản riêng không lấy cache hoặc save thật. Runtime patch có backup preimage và diễn tập restore chính xác byte trong thư mục riêng.

- Bản riêng sau ghép UX: journey59/59 và coldload13/13, hai tiến trình riêng.
- Owner UX: headless34/34 và native44/44,8ảnh đã xem tại800x600/1280x720; click/Enter và A giả lập trong viewport riêng. Không kiểm tay cầm vật lý.
- Sau apply trên bản gốc: untrack34/34, journey59/59, coldload/native20/20 =113/113; exit0 và raw stderr rỗng. Hai ảnh native bản gốc đã xem riêng. Không dùng số private thay số original.

Journey dùng main cấu hình thật với QA chest mặc định tắt và profile QA mới. M/Enter nhận quest; Tab/1/F lắp bùa Hỏa từ rương thật; mouse aim/I chạy action FSM và đạn thật (HP Slime60→39, một cast); J chạy weapon clocks/hitbox thật (HP60→48, một accepted hit). E và Enter thực thi lựa chọn đi tiếp/trở về. Trong Kael, Enter mua kiếmThường20LinhThạch, chọn bán chưa mất món, xác nhận bán trả5, bán một pha lê trả5; cất vật liệu và cường hóa +1 dùng5LinhThạch/một đá, giữUID/phẩm cấp. E đọc đủ hai trang Thanh Vy rồi Enter nâng HP dùng20TànHồn. Kết thúc/coldload:25LinhThạch,5TànHồn,HPupgrade1,weapon+1 cùngUID; soldUID không trở lại; numeric seal2 hợp lệ và toàn bộ decimal loot/ô trang bị/canonical quest còn đúng. Theo dõi nhiệm vụ chỉ trong phiên, coldload không giữ selection. Trở về sớm không tạo Golem proof/victory/bounty.

Đây là integration fixture có kiểm input trong chính viewport Godot. Fixture dùng API đi đường/mở dịch vụ, PlayerTravel đặt vị trí, direct health clear để rút ngắn tầng đầu, hai Slime thật đứng yên, seed rương4242, chặn random enemy drops và finite pickup40coins/25Souls/1stone/3crystal. Rương thật cung cấp thêm6crystal, tổng9trước bán. Không suy ra độ khó, drop rate tự nhiên, gamefeel hoặc thời lượng chơi từ fixture này.

## Lỗi native còn chưa kết luận

Lỗi `0xC0000005` ở editor/import lịch sử, gồm lượt originalOct5, chưa có nguyên nhân/fix. Oct7 chỉ hai đối chiếu editor riêng bật đủ ba plugin với cold/warm cache: exit0, stderr rỗng; verbose còn ghi socket bind Error3 và một static StringName khi thoát, raw log được giữ. Chưa gọi strict/fullsuite mới hoặc coi hai lượt này là sửa crash. Không đổi engine/driver/OS hoặc tắt plugin sản phẩm để che lỗi. Cần chẩn đoán tiếp nếu tái hiện được trên đúng cùng nguồn/engine.

## Phần mỹ thuật còn giới hạn

12 owner/binding hiện hành và52resource literal được kiểm hash/tồn tại; không thiếu file trong phạm vi đó. Cả5icon bùa đã được bind, kể cảLôi/Băng/Độc tích hợpOct4; danh sách thiếu icon cũ đã lỗi thời.

- `pilot_gatherer` (Người hái thuốc), `pilot_courier` (Người đưa tin), `pilot_apprentice` (Học việc ở bến) vẫn dùng vector fallback; chưa bind thân vẽ riêng.
- `pilot_bridge_keeper` và `pilot_pilgrim` có một frame idle trong road atlas. TravelerR3 có walk cutout/rig tạm đã tích hợp; chưa nghiệm thu bộ animation thương mại hoặc death riêng.
- Golem dùng PNG hiện có. Bat/Wraith/Champion dùng atlas tĩnh với chuyển động/VFX theo physics; Guard có authored frames. Không coi polish damage cues là bộ body animation mới.
- Painted pilgrimage pack chỉ gắn `o01_p01` tuyến chính; các phòng đường bộ khác giữ presentation prototype hiện hữu.
- Player dùng full-body texture/rig hiện tại; scene rig độc lập chưa có atlas từng chi. Một số gear có thể dùng shield fallback theo catalog.

InkR4 vẫn HOLD riêng, không nằm trong baseline. Handbook/GDD có nội dung tương lai không đồng nghĩa floor/roster sâu đã chạy trong main. Cân bằng và playtest tự nhiên còn việc riêng; pending reward escrow vẫn trong RAM, chưa có bảo đảm power-loss atomicity.

## Mở và phối hợp cho thành viên

Mở `project.godot` bằng đúngGodot4.7.2, GL Compatibility; F6 chạy scene chọn hoặc F5 main. Dùng AGENTS.md, PROJECT_ARCHITECTURE.md, PROJECT_STATE.md, DECISIONS.md và nhật ký mới nhất làm ngữ cảnh. Các helperF5–F8 cấp đồ/warp của fixture không bật trong main sản phẩm. Chia owner module trước khi chỉnh các file UI/GameFlow/profile dùng chung; giữ Gear UIDledger/definition ownership và numericseal2, coins/Souls/energy tách biệt.

Gói local `Dungeon-Resonance-Source-Baseline-20261007.zip` có nguồn hiện hành và manifestSHA256. Giữ cả16file source/provenance dưới `docs/verification/asset_pipeline_sources` và manifest asset pipeline vì chúng nằm trong baseline đã chốt. Cache `.godot`, `.git`, evidence QA còn lại, save thật và executable engine được loại khỏi gói. Đây là source handoff, chưa là game export. Backup và raw proof ở `C:/Users/Admin/Documents/Codex/2026-10-02/task/opening_handoff_20261007/`; `FINAL_RECEIPT.json`, `ART_SCOPE_GAPS_CURRENT.json` và manifest ghi exact scope/paths/hashes. Chưa upload, publish, mời thành viên hoặc thay quyền truy cập; chọn đích chia sẻ là thao tác riêng.
