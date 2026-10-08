# Kẹt nhân vật tại mép trái bậc thềm hầm ngục — 08/10/2026

**Trạng thái lúc 14:05 giờ Việt Nam:** đã xác minh nguyên nhân và sửa trên bản riêng `C:/Users/Admin/.codex/worktrees/sect-path-repair/hầm ngục`, nền commit `f626fd9`. Chưa áp dụng vào `D:/hầm ngục`; root là đầu mối ghép. Chưa chạy GPU hoặc điều khiển phiên chơi đang mở của người dùng.

## Hiện tượng và nguyên nhân đã xác minh

Ảnh người dùng khớp Tiền Sảnh của `WorldCampaign`, stage 1 / `DungeonRoom.room_number = 1`: bậc phía tây ở y534, gallery tây x180–470, gallery đông x790–1120 và ảnh nền `dungeon_temple_v1.png`. Người dùng xác nhận đi trái/phải bị chặn nhưng vẫn tung chiêu được.

Tường trái có mép trong tại x32. Bậc `WestStair` cũ bắt đầu x50, nên khe hở chỉ 18px; capsule Player rộng 20px, cao 36px. Khi đi khỏi mép trái bậc, nhảy từ sàn về sát tường hoặc bị knockback, chân capsule chạm góc bậc đồng thời thân chạm tường. Physics báo hai hướng pháp tuyến đối kháng: tường `(1, 0)` và góc bậc khoảng `(-0.796, -0.605)`. Góc bậc không được nhận là sàn (`is_on_floor = false`); nhân vật dừng tại khoảng `(42.00, 537.93)` dù nhận hướng đi phải. Nhảy thông thường cũng mất điều kiện grounded ở trạng thái này.

Đã tái hiện trên collider và Player motor thật, không đặt nhân vật thẳng vào khe: case đi từ tâm bậc ra mép, case nhảy trái từ spawn `(180,640)`, và case `DamageEvent` gây knockback từ tâm bậc. Sau mỗi cách vào góc, input cast vẫn tăng đúng một lượt commit và phóng một projectile; giữ đi phải một giây vẫn ở x42. Đây là lỗi hình học, không phải modal khóa toàn bộ input hoặc hitstop.

## Thay đổi

`scripts/rooms/dungeon_room.gd` đổi duy nhất hình chữ nhật của `WestStair` từ `Rect2(50,534,80,12)` sang `Rect2(32,534,98,12)`, nối bậc sát tường. Mép phải x130, cao độ y534, độ dày12, one-way/margin4 và anchor `(90,534)` giữ nguyên. Art của bậc đọc chính collider nên cùng mở rộng tới tường. Room1 và room2 dùng chung định nghĩa này; boss room và các `DepthRoom` có layout riêng.

Không đổi Player controller, motor, FSM, capsule, sát thương hoặc tốc độ. Đã đối chiếu SHA256 của tám file Player/motor/FSM/scene với baseline, đều giữ nguyên. Bộ test mới `tests/world/dungeon/dungeon_corner_escape_test.gd` kiểm hành vi thoát góc thay vì chỉ khẳng định kích thước mới.

## Kiểm thử thực chạy

Godot `4.7.2.stable.official.ed1daf0bf`, CLI headless, `--fixed-fps` và physics tick cùng mức 60 hoặc 120. Mỗi lượt có thư mục APPDATA/LOCALAPPDATA và save QA riêng. AI bị dừng và hitstop bằng0 để cô lập va chạm; đây không phải bằng chứng cảm giác chiến đấu, render hoặc FPS. Các case dùng reset vị trí đầu vào xác định, sau đó Input actions, motor, Hurtbox/DamageEvent và CastState thật. Không sửa save thật.

| Lượt | Kết quả | Bằng chứng |
|---|---|---|
| Survey baseline 60Hz | Tái hiện cả đi khỏi bậc, nhảy sát tường, nhảy từ spawn và knockback; ghi normal/collider/cast | `baseline_survey_60_r1` |
| Regression trước sửa 60Hz | 38 checks, **6 FAIL**, exit1; sáu đường thoát tây thất bại ở room1/2 | `baseline_regression_60_r1` |
| Regression trước sửa 120Hz | 38 checks, **6 FAIL**, exit1; cùng sáu đường thoát | `baseline_regression_120_r1` |
| Regression sau sửa 60Hz | **38/38**, exit0, không ERROR/WARNING | `fixed_regression_60_r1` |
| Regression sau sửa 120Hz | **38/38**, exit0, không ERROR/WARNING | `fixed_regression_120_r1` |
| Movement cũ 60Hz | **55/55**, exit0, không ERROR/WARNING | `movement_60_r1` |
| Movement cũ 120Hz | **55/55**, exit0, không ERROR/WARNING | `movement_120_r1` |

Regression 38 checks bao phủ ba cách vào góc tây × hai room, cast commit và projectile thật, đi phải trở lại sàn y640, mép đông khi cửa khóa/mở, đi trái rời mép đông, nhảy xuyên bậc một chiều và lên gallery ở cả hai bên. Sau sửa, case tây đứng trên mặt bậc tại y≈534 rồi đi phải tới x≈352.63 (60Hz) / x≈348.30 (120Hz), hạ xuống sàn y≈639.93. Toàn bộ sáu case tây trước sửa đều giữ x≈42 sau input đi phải.

Lệnh đã chạy qua wrapper `corner_worker/run_fixed.ps1` tương đương:

```powershell
& 'D:/dowload/Godot_v4.7.2-stable_win64.exe' --headless --path 'C:/Users/Admin/.codex/worktrees/sect-path-repair/hầm ngục' --fixed-fps 60 --script 'res://tests/world/dungeon/dungeon_corner_escape_test.gd' -- --hz=60
# Lặp 120 cho cả --fixed-fps và --hz, với QA root mới.
# Movement: thay --script bằng res://tests/movement_test.gd.
```

Wrapper đã đặt biến QA/save riêng trước khi tạo tiến trình Hidden, ghi raw stdout/stderr và `RUN_RESULT.json`; không lọc diagnostics. Bằng chứng ngoài checkout tại `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/corner_worker/`. Mỗi regression giữ thêm `dungeon_corner_escape_60.json` hoặc `_120.json` với vị trí, pháp tuyến, input được nhận và số cast/projectile. `BASELINE_SOURCE_HASHES.json` và `dungeon_room.baseline.gd` giữ preimage; các lượt baseline thất bại được giữ nguyên.

## Handoff và giới hạn

- File do worker sửa: `scripts/rooms/dungeon_room.gd`; thêm `tests/world/dungeon/dungeon_corner_escape_test.gd` và `.uid`; báo cáo này. Không sửa các patch NPC/tông môn đang do root quản lý.
- SHA256 runtime sau sửa: `dbd966e04643435f1c33f01da5073c633501f379317da7c6e08e6a44c3800e40`.
- SHA256 test: `9dae284bf4e87c2cbbd713738a2faa1bef9e13ac86ad2697a6acf2c85bfa6b62`; UID `uid://6xuot6wdlsjc`.
- CLI headless đã nhả lúc 14:04 giờ Việt Nam, không còn tiến trình QA thuộc worker. Chưa full strict, chưa GPU/native; root quyết định kiểm tích hợp phù hợp và đăng ký suite mới vào runner theo ownership.
- Bản đang chơi chưa tự thay geometry đã khởi tạo. Sau khi ghép, cần tải lại phòng hoặc khởi chạy lại bản đã sửa; không tuyên bố phiên đang mở đã được giải kẹt.
- Các kiểm thử này xác nhận lỗi kẹt ở góc được sửa trong fixture; không chứng nhận mọi góc của toàn bộ map hay nhịp chơi tự nhiên.
