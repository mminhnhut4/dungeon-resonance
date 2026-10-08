# Vân Thạch rộng — checkpoint riêng 2026-10-08

Trạng thái 09:55:20 UTC: đã tích hợp và kiểm focused/native trong private `C:/Users/Admin/.codex/worktrees/sect-path-repair/hầm ngục`; đã nhả engine và đóng băng đúng 7 file trong [FINAL_MANIFEST.json](C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/task/wide_floor_draft/FINAL_MANIFEST.json). Root bắt đầu strict R3 lúc 09:55:48 UTC rồi mới quyết định ghép main. Chưa tự áp main, chưa commit, chưa claim strict PASS.

## Nội dung đã nối runtime

- Tầng Vân Thạch rộng 1920 thay 1280; nền chiến đấu liên tục ở y640, tường phải x1904, phong ấn x1830, điểm tương tác lối ra x1870. Không có tầng sáu hoặc schema mới.
- Ba hộ vệ cũ giữ nguyên definition/HP/tốc độ/đòn đánh, đặt ở x600/1120/1660. Không thêm AI hoặc thay controller Player.
- Ba mốc dùng texture cột có sẵn: Bậc Mây x285, Hành Lang Cột Đá x1080, Trụ Phong Ấn x1660. Caption y540 nằm dưới HUD compact và vẽ trên skin nền tảng. Không sinh PNG mới.
- Một rương thường ở (560,356), trên nhánh nhảy hiện có. E qua GearSession/TreasureChest thật; bảng loot thường gốc, không có thưởng tiến độ/boss mới. Ledger `_opened_branch_chests` thuộc chuyến đi: mở rồi dựng lại phòng trong cùng chuyến không sinh lại; chuyến mới có một rương mới. Bỏ đồ trên đất vẫn tuân theo owner loot/return hiện tại.
- Camera đọc chiều rộng mỗi lần enter_room, bao gồm reset về32..1248 ở tầng hai đến năm. Nền dùng uniform cover, giữ aspect. Bốn đuốc và72 hạt bụi trải theo chiều rộng, không tăng số owner ánh sáng/VFX. Terrain tầng một dùng50 sprite trong cap64.
- Tầng hai đến năm giữ hình học gốc. 12 golden signature cho locked/unlocked/relocked của bốn tầng này vẫn được so đúng. Tầng một có fixture hình học1920 tường minh, không thay hash hàng loạt từ chính implementation.

## Phạm vi file

Runtime: `data/depth_floor_catalog.gd`, `scripts/rooms/depth_room.gd`, `scripts/rooms/depth_campaign.gd`.

QA: `tests/depth_campaign_test.gd` chỉ dùng điểm lối ra theo catalog và tăng giới hạn đi bộ hữu hạn; `tests/depth_terrain_art_test.gd` thêm fixture hình học tầng một; `tests/depth_wide_floor_test.gd` và `.uid` mới. Root tự sở hữu việc đăng ký runner. Hash đầy đủ ở manifest trên; preimage `base/` và bản cuối `patch/` nằm tại `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/task/wide_floor_draft`.

## Kết quả thực chạy

Tất cả nhãn dưới nằm ở `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/probes/`; mỗi thư mục giữ stdout, stderr, RUN_RESULT.json không lọc lỗi/cảnh báo.

| Nhãn | Kết quả | Phạm vi |
| --- | --- | --- |
| wide_import_r1 | exit0, diagnostics[] | Import sau tích hợp |
| wide_60_r4 | 47/47, exit0, diagnostics[] | Headless60, bản cuối |
| wide_120_r4 | 47/47, exit0, diagnostics[] | Headless120, bản cuối |
| wide_native_r4 | 47/47, exit0, diagnostics[] | Native60, 7PNG thật |
| wide_terrain60_r1 | 171/171, exit0, diagnostics[] | Required raster, năm tầng |
| wide_terrain120_r1 | 171/171, exit0, diagnostics[] | Required raster, năm tầng |
| wide_fixed60_r4 | 47/47, exit0, diagnostics[], 6.43s | Console engine + `--fixed-fps60`, timeout60 giống strict |
| wide_fixed120_r4 | 47/47, exit0, diagnostics[], 8.26s | Console engine + `--fixed-fps120`, timeout60 giống strict |

Lệnh tiêu biểu: gọi `probes/run_probe.ps1 -Project <private> -Label wide_60_r4 -Headless -Script res://tests/depth_wide_floor_test.gd -UserArgs @('--hz=60') -TimeoutSeconds180`. Native bỏ `-Headless`, thêm `--native-approved`. Helper ngoài checkout `run_wide_fixed_probe.ps1` giữ isolation/raw/Hidden của helper gốc, dùng console engine và thêm engine flag `--fixed-fps` trước `--`.

Probe kiểm melee Player commit thật khiến hộ vệ ghi nhớ rồi đuổi qua x1280; đi bộ tới cả ba điểm bằng input; camera800/1280; seal không bị bypass; ba lần nhảy theo controller gốc; E mở rương; không double loot; không receipt mới; nhánh trở lại nền; pending commit chặn dispose; retry; Player identity giữ qua chuyển tầng; room/chest cũ được giải phóng; camera tầng hai reset; re-enter cùng chuyến không tái sinh rương; chuyến mới có rương mới.

## Ảnh và ranh giới chấp nhận

Đã mở xem đủ7 ảnh cuối trong `probes/wide_native_r4`: `wide_800_180.png`, `wide_800_1000.png`, `wide_800_1770.png`, `wide_1280_180.png`, `wide_1280_1000.png`, `wide_1280_1770.png`, `wide_branch_before_open.png`. Hash/byte size nằm trong `NATIVE_PNG_MANIFEST.json`. Nền không méo/hở, caption cuối rõ ngoài HUD; bước chân lên bục và vị trí rương đã quan sát. Root cũng đã xem mốc giữa800 và nhánh.

Native fixture đo đuổi theo 12.813s, tổng đi bộ qua hai kích thước 18.631s, nhảy/mở/rơi khỏi nhánh 7.079s. Đây là thời gian thực của probe: phần hình học/rương tắt AI, hạ roster dùng Health fixture; không phải thời lượng chơi thông thường. Chưa đo một chuyến chiến đấu tự nhiên qua đủ năm tầng, chưa chứng minh tầng thú vị hơn hoặc cân bằng cuối; không lấy chiều rộng làm bằng chứng cho nhận định đó. Kiểm native này cũng không thay phép đo FPS core riêng.

Fixture `_picture` chưa kiểm returncode `save_png`; checkpoint này chấp nhận bằng kiểm tra7file thật, mở xem và hash ở ngoài. Không đổi fixture sau freeze để tránh trôi nguồn. Agent sect_research đã audit read-only camera/chest/lifetime và không tìm blocker.

## Những lượt không đạt vẫn giữ raw

- `wide_60_r1`:40/41. Test ban đầu cho chase12s, nhưng tốc độ guard55 cần hơn12.36s để đi từ600 qua1280, còn hurt/knockback. Chỉ sửa budget fixture theo distance/speed+2; giữ assert phải vượt ranh và còn memory20s. Lượt sau xác nhận x1280.77, memory7.18s. Không chỉnh AI để làm test xanh.
- Native r2/r3 logic đạt nhưng review pixel tìm caption bị HUD800 rồi shelf skin che. Sửa duy nhất vị trí/Z caption; r4 chụp lại đủ7ảnh và tất cả focused cuối dùng cùng source này.

Không tự mở rộng nội dung tiếp trong checkpoint này. Nếu strict R3 không đạt trước hạn, root có checkpoint core ngoài checkout để chỉ rollback phần wide-floor; không ghép một lát cắt còn lỗi vào main.

**Audit hình cửa sau review của root:** dải xám cao ở lối phong ấn là Polygon2D24×720 đã có trong ảnh baseline `docs/verification/continue_20261008/main_depth_native/floor_1_roster.png`, không phải lỗi kéo rộng mới. Cửa tạo sau skin ground/shelves nên chưa có texture riêng. Giữ geometry/lock guard; đây là phần art còn cần hoàn thiện, không gọi toàn map đã hoàn thiện hình ảnh.