# Kiểm tra và bàn giao có bằng chứng

## Checkpoint hiện hành 08/10 sau khi ghép map

Xem [SECT_MAPS_RESUME](../SECT_MAPS_RESUME_20261008.md): strict candidate frozen273/273, main validator234/37, numeric64, savecopy136 và native tông môn276/connector49. Đây là evidence của checkpoint đã nghiệm thu, không phải kiểm thử mới khi upload tài liệu. Fixture source_id giả đã sửa; PACKAGING_VERIFICATION.json và phần Oct7 bên dưới giữ lịch sử. Native cleanup crash còn chưa xác định, tải map56–104ms và frame-time cần kiểm tiếp. [Tóm tắt cho nhóm](PROJECT_AND_STORY.md).

## Checkpoint lịch sử trước ZIP đầu

Combat Oct7 trên bản chính: import,268 headless,21 native combat,5 cold-load sạch/exit0; probe4 native walk bổ sung sạch. Atlas resident/save writer có byte guard/journal ẩn coalesce đã ghép; bùa5đơn/Bão Lửa và Golem UV mesh nối runtime. Mẫu RTX5080/Compatibility1152×648/cap120: p99 normal37.578→23.431ms, >25ms21→4;4 mẫu còn lại mang hitstop flag. Đây là mẫu hữu hạn, không đảm bảo mọi trận/máy.

Còn synchronous save peaks; no-hitstop vẫn có spike; layout800×600 fail như baseline; native0xC0000005 lịch sử chưa kết luận cấp engine. Final mesh private/main sạch trong mẫu, không nghĩa mọi native crash đã fix. Chưa full strict/long natural run/native đủ10cặp ở mốc combat. [Báo cáo](../COMBAT_VISUAL_FIX_20261007.md), [ảnh/frame-time](evidence/README.md).

Kiểm tra đóng gói20261008 ghi riêng trong [PACKAGING_VERIFICATION.json](PACKAGING_VERIFICATION.json), không cộng vào số gameplay cũ. ZIP source không phải game export.

## Save thử và lệnh đúng

Runner strict có EnginePath/QaDataRoot. Từ root checkout:

```powershell
$godotExe = 'C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe' # thay bằng đường dẫn thật
& $godotExe --version
./tests/run_tests.ps1 -EnginePath $godotExe
```

Runner mặc định tạo dữ liệu QA dưới Temp, phục hồi APPDATA/LOCALAPPDATA; không dùng save thật. Có thể truyền -QaDataRoot với đường dẫn ngoài project. GameplayOnly chỉ chẩn đoán, không là strict gate. Giữ ERROR/WARNING và mọi fail; không disable case để lấy PASS.

Helper [run_qa.ps1](../../tools/team/run_qa.ps1) mở main hoặc test hẹp với save/evidence riêng:

```powershell
./tools/team/run_qa.ps1 -EnginePath $godotExe -Mode Import
./tools/team/run_qa.ps1 -EnginePath $godotExe -Mode Smoke
./tools/team/run_qa.ps1 -EnginePath $godotExe -Mode Test -Script 'res://tests/resonance_test.gd'
./tools/team/run_qa.ps1 -EnginePath $godotExe -Mode Play -QaDataRoot 'C:\QA\Dungeon_Play_01'
```

Play khởi động Hidden với profile QA riêng; người chơi có thể đưa cửa sổ QA lên màn phụ. Helper không đổi focus/vị trí màn hoặc can thiệp process khác. Import/Smoke/Test bounded60s, logs/receipt trong QA data. Các test cũ có thể ghi docs/verification trong checkout; vì vậy dùng checkout thử. Smoke chỉ chứng minh khởi chạy headless/shutdown, không FPS/hình/audio.

## Chọn kiểm tra

| Thay đổi | Kiểm tra |
|---|---|
| Data/resolver | Exact recipe, ownership, cooldown |
| Map | Traversal/door/anchor/room cleanup,60/120physics nếu đổi geometry |
| Boss/VFX | Native state clock/hitbox/contact, teardown/budget |
| Save/equip | Roundtrip/cold process, lỗi ghi và rollback |
| Docs/ZIP | Path/hash/resource, fresh import/main load; không rerun trận GPU chỉ vì sửa chữ |

Đo cần commit/engine hash/renderer/GPU/resolution/render cap/physicsHz/seed/save QA/scene. Tắt hitstop là ablation, không là fix. Ghi timestamp/hitstop/save phase cùng frame-time; screenshot readback ngoài mẫu đo. Mean FPS không chứng minh smoothness; so p95/p99/max/spike và nguyên nhân.

## Receipt và integration

Giữ lệnh/exit/raw stdout-stderr/checks-fail/ảnh đã xem; fixture dùng warp/direct clear/grant cần ghi rõ. Một GPU owner, không đóng process người khác. Integrator ghi backup/base commit, guard files trước apply, hậu kiểm main. Assertions đạt nhưng quit crash hoặc ERROR/WARNING thì lượt đó FAIL; giữ raw failed riêng.

Phân biệt private verified/main merged/design/asset ready. Tests113 hay full gate lịch sử không chứng minh patch hôm nay hoặc game đã mượt.
