# Hành Trang và kiếm Thường — lát cắt đầu

2026-10-01, Godot4.7.2/Compatibility. Phạm vi đã chọn: làm lần lượt, **Hành Trang + một kiếm Thường** trước. Chưa sản xuất toàn bộ trang phục/phụ kiện và art của mọi moveset.

## Tích hợp

- `scenes/ui/inventory_screen.tscn`: Tab/nút góc phải mở giao diện, 4 ô Vũ khí/Y phục/Nhẫn/Dây chuyền bên trái, 20 ô túi bên phải và tooltip màu theo bậc. Click trái/phải trong túi để trang bị/đổi; chuột phải ô đang mặc để tháo. Trang Bùa giữ sockets và phím tắt cũ; I vẫn niệm phép.
- Một ledger `GearInventory.items` giữ UID sở hữu; các mảng ô chỉ tham chiếu UID. Swap đưa món cũ về túi, tháo vào ô trống đầu tiên. Túi đầy từ chối tháo/nhặt mà giữ đồ; loot/debug lịch sử vượt20món có trang thêm, không bị xóa. Rune/Catalyst/cổ vật giữ UI riêng.
- `EquipmentData` Resource chỉ đọc chứa texture/moveset/slot/bonus; `GearItem` giữ UID và **6 phẩm cấp thay hẳn hệ5**. Save profile schema1 không lưu gear/quality run nên không có quality cũ trong save để migrate.
- `data/equipment/common_sword.tres` dùng PNG kiếm thép từ cột Thường của board đã duyệt, giữ moveset kiếm3hit/base10/timing cũ. Kiếm Thường không thêm halo hoặc hạt phẩm cấp. Nguồn/prompts/hash giữ tại `docs/art_approval`, ảnh mới `assets/sprites/weapons/common_sword.png` có alpha/mipmap.
- `EquipmentVisual` thêm ArmorSprite trống, HandSocket/WeaponPivot/WeaponSprite, slots Line2D/GPUParticles và AccessoryAura chờ. Thân/bóng/Skeleton2D hiện hữu được giữ. Blade riêng ngắm chuột, −35° lấy đà→+85°quét→hồi vị, đọc clock Windup/Active/Recovery để freeze/cancel đồng bộ. Giữ timing moveset thay vì một Tween độc lập lệch hitbox; không phát DamageEvent hoặc slash emitter thứ hai.
- Tháo kiếm chuyển sang `unarmed.tres`: một đấm tầm ngắn/base5/one-hit-window, không vệt kiếm; vẫn ngắm360°/niệm Catalyst. Bùa khảm vũ khí được giữ trong inventory nhưng không cộng vào tay không.
- `EquipmentStats` cập nhật HP/mana capacity, speed/attack/crit từ baseline, không cộng chồng; tăng maxHP không hồi máu hoặc hồi sinh. Thay đổi bên ngoài như giá máu thương nhân được giữ. Bonus và slot khác kiểm bằng fixture, chưa có bộ art y phục/phụ kiện đã duyệt.
- Loot/thương nhân chỉ cấp vũ khí Thường/Hiếm; lửa trại không rèn Hiếm→Cực hiếm. Thợ rèn/công thức/kho/**Bản Nguyên Thần Thạch** chưa triển khai, xem [thiết kế đã chốt](ART_DIRECTION_WEAPONS.md).

## Giới hạn

PNG toàn thân còn là concept, chưa tách animation từng bộ phận. Chỉ kiếm Thường có sprite cầm tay mới; moveset prototype khác giữ combat cũ. Board6bậc không có nghĩa6bộ sprite/VFX đã tích hợp. Coefficients prototype tái dùng: Common1.0/Rare1.1/VeryRare–Epic1.2/Legendary–Divine1.35, slot/proc có plateau tương ứng; **chưa là cân bằng sức mạnh Thần thánh cuối**. Tỉ lệ rơi đá/bản chế tạo và chi phí đúc/khảm chưa tự đặt.

## Kiểm chứng và lỗi đã sửa

Suite mới `inventory_equipment_test.gd` kiểm GUI mouse thật, UID/swap/unequip/full-bag rollback, cooldown, punch contacts, modifier, physical transforms, old-active cancel, death/detached-UI lifetime.

GPU bắt được panel tăng tới1947px, ô bị văng khỏi màn hình; sửa resize sau minimum ổn định và thêm assertion panel/ô cuối phải nằm trong viewport. Callback resize sau detach về Hub được guard. HUD chỉ dùng EquipmentData icon khi UID khớp moveset thực, tránh icon kiếm cũ lúc debug vừa đổi. Không bỏ assertion để che lỗi.

Gate mặc định có các lượt native shutdown `0xC0000005` tại addon/editor, cùng fault offset0x547F2C ghi từ milestone trước. Log lỗi/Windows events được giữ, chưa có root cause/native stack chứng minh; không tắt addon/lọc warning/khẳng định retry sạch đã chữa native. `-CollectAllFailures` chạy đủ mọi gate, tiếp tục thu lỗi rồi vẫn trả lỗi nếu bất kỳ gate thất bại; mặc định vẫn dừng khi gặp lỗi. `-GameplayOnly` chỉ chẩn đoán.

Kết quả cuối ở `docs/verification/inventory_test_summary.json`; baseline2.857 được giữ riêng, không đánh dấu một lượt gate lỗi là pass.

Lượt cuối `tests/run_tests.ps1 -CollectAllFailures` chạy **đầy đủ mọi gate**, exit0/ALL HEADLESS CHECKS PASSED: **2.961/2.961**, giữ2.857baseline; 102 assertion Equipment mới (51 mỗiHz) và2Resource mới. Movement55/Combat100 mỗi60/120Hz, Resolver20; warnings-as-errors validator107scripts/20scenes, content41Resource. Các assertion hợp đồng5tier/giới hạncamp/nhãnNormal được cập nhật đúng thiết kế6tier, không bỏ bài test. Native failures trước lượt cuối vẫn còn log/fingerprint, chưa chứng minh nguyên nhân đã sửa.

GPU preview7capture đạt, gồm clickswap/tooltip/tháo kiếm/Bùa/common-swing/mirror/Boss inventory; source ở `tests/preview_inventory.gd`, log `inventory_gpu_preview.*.log`, ảnh `inventory_*.png`. Stress Hub8cycles **2126→2126 objects/251→251 resources**, projectile **2837→2837/230→230**, loot **2980→2980/230→230**, campaign **1915→1915/252→252**, combatVFX **2838→2838/261→261**. Đây là các chu kỳ hữu hạn đã chạy, không là bảo đảm chơi vô hạn.

Render Compatibility/RTX5080/1152×648, 2s warmup+6s đo, ánh sáng/glow/GPUdust và tải10phép/s+20impact/s+10loot/s, mixer thật/busmute; hitstop tắt riêng phép đo throughput:

| Phòng/cap | FPS trung bình | p95 frame gồm chờ cap | Peak physics |
|---|---:|---:|---:|
| Tiền Sảnh60 | 59.964 | 17.746ms | 4.409ms |
| Tiền Sảnh120 | 119.935 | 8.928ms | 3.312ms |
| Boss60 | 59.963 | 17.643ms | 3.792ms |
| Boss120 | 120.000 | 9.274ms | 3.689ms |

Cả4đạt gate FPS≥95%cap/p95≤1.4×budget, log sạch. Raw JSON được giữ nguyên từ dòng RENDER BENCHMARK của từng stdout thành `inventory_{foyer,boss}_render_{60,120}.json`; lệnh dùng chung output-prefix đã tạo hai file `inventory_60/120.json` cuối của Boss, không dùng chúng thay kết quả Tiền Sảnh. Không suy ra hiệu năng mọi máy từ kết quả hiện tại.

Thử trong Godot: F5→Hub→Đi ải, hoặc F6 từ `scenes/test_level.tscn`. Tab mở Trang bị, chuột phải ô Vũ khí tháo, click kiếm trong túi để cầm lại; Tabđóng, chuột trái thửđấm/chém. Trang Bùa giữ Hỏa/Phong và phép chuộtphải. Khung y phục/phụ kiện còn trống theo phạm vi bướcđầu.
