# Module di chuyển — bản thử đầu tiên

Scene chơi thử: `res://scenes/test_level.tscn`; đây là main scene hiện tại nên **F5** chạy ngay. **F6** chạy scene này khi đang mở nó trong editor.

## Phím điều khiển

| Thao tác | Phím |
|---|---|
| Trái / phải | A / D hoặc ← / → |
| Nhảy | Space hoặc W |
| Lướt | Shift hoặc K |
| Về điểm xuất phát | R |

Phòng 1280×720 có sàn, tường, sáu bục ở độ cao khác nhau và hố thử. Player xuất phát tại (640, 640). R hoặc rơi xuống dưới y=850 sẽ hồi sinh, dọn velocity, buffer, dash và bất tử. Sprite chữ nhật có dấu hướng và lật theo hướng di chuyển; sáng hơn trong cửa sổ bất tử.

## Cách các component phối hợp

1. Player đọc Input Map trên physics tick, cập nhật hướng nhìn và đưa timer/input cho Motor.
2. Action FSM xử lý Ready/Attack/CastSpell/Dash/Dead. Dash ưu tiên khi nhấn đồng thời dash/nhảy và có thể ngắt Attack/CastSpell; chi tiết combat tại [COMBAT.md](COMBAT.md).
3. Jump buffer được tiêu một lần khi có sàn hoặc coyote time. Nhảy giữ nút không tự tạo nhảy lần hai. Tap đã nhả trước khi tiếp đất vẫn tạo nhảy thấp nếu buffer còn hiệu lực.
4. Locomotion FSM chọn Idle/Run/Jump/Fall; state gọi Motor với gia tốc đất hoặc trên không. Dash tạm thay vận tốc bằng chuyển động ngang, không chịu gravity.
5. Motor gọi `move_and_slide()` đúng một lần. Va tường kết thúc dash ngay; Player cập nhật FSM, hướng Sprite và Hurtbox.

Motor là nơi duy nhất sửa velocity. Timer dùng physics delta; tốc độ tính px/s và gravity/gia tốc tính px/s², theo [CharacterBody2D](https://docs.godotengine.org/en/stable/classes/class_characterbody2d.html). Không nhân velocity với delta trước `move_and_slide()`.

## Thông số chỉnh trong Inspector: Player → Motor

| Thông số | Giá trị đầu tiên | Tác dụng |
|---|---:|---|
| Run speed | 320 px/s | Tốc độ chạy tối đa |
| Ground acceleration | 2600 px/s² | Thời gian đạt tốc độ chạy |
| Ground deceleration | 3600 px/s² | Dừng nhanh, ít trượt |
| Turn acceleration | 3600 px/s² | Đảo hướng nhạy |
| Air acceleration / deceleration | 2000 / 1600 px/s² | Điều chỉnh ngang khi trên không |
| Jump speed | 600 px/s | Vận tốc ban đầu hướng lên |
| Rise / fall gravity | 1500 / 2250 px/s² | Lên mềm hơn, rơi nhanh hơn |
| Maximum fall speed | 1000 px/s | Giới hạn tốc độ rơi |
| Jump release multiplier | 0.45 | Nhả nút cắt vận tốc hướng lên đúng một lần |
| Coyote duration | **0.12s** | Cửa sổ nhảy sau khi rời sàn; yêu cầu người dùng |
| Jump buffer duration | **0.10s** | Nhớ nhấn nhảy trước lúc tiếp đất; yêu cầu người dùng |
| Dash speed / duration | 850 px/s / 0.16s | Độ dài lướt xấp xỉ 136 px khi không có vật cản |
| Dash cooldown | 0.65s từ lúc bắt đầu | Không reset khi chạm đất |
| Dash invulnerability | 0.10s | Bất tử ngắn hơn thời gian dash |

Các giá trị còn lại là lựa chọn triển khai để thử nghiệm. Người dùng đã thao tác bản này và phản hồi "rất ổn định"; giữ chúng làm mốc tham chiếu cho các buổi sau, không tự coi là cân bằng cuối.

Dash dùng hướng input, hoặc hướng nhìn gần nhất nếu không giữ trái/phải. Cho phép lướt trên mặt đất và **một lần mỗi lượt ở trên không**. Chạm đất hồi lại quyền dash, nhưng vẫn cần hết cooldown. Không được dash lần hai khi còn trên không dù cooldown đã hết. Kết thúc dash kẹp vận tốc ngang về tốc độ chạy; va tường/hồi sinh cũng dọn override và bất tử.

Hurtbox chặn `receive_damage(DamageEvent)` ngay trong cửa sổ bất tử; `monitorable` được cập nhật deferred để an toàn với physics. Collision của body với sàn/tường vẫn hoạt động. Melee, phép, Slime bite và DOT hiện đi qua Hurtbox/HP/DamageResolver; hit-stop dừng cả đồng hồ movement và combat nhưng vẫn buffer input.

## Kiểm chứng đã chạy ngày 2026-09-30

- Godot 4.7.2 import và chạy main scene headless: exit code 0, không có lỗi runtime.
- Integration test dùng scene thật, action input, sàn/bục/tường thật: **55/55** ở 60 Hz và **55/55** ở 120 Hz.
- Bao gồm nhảy bên trong/bên ngoài coyote window; buffer còn hạn/hết hạn; không double-jump; dash khóa trục dọc; chặn/nhận lại DamageEvent; hết bất tử trước khi dash kết thúc; cooldown và quyền dash tách nhau; dash vào tường; hồi sinh và phím R.
- Độ cao đo được: giữ nút **115.07 px** ở 60 Hz và **117.57 px** ở 120 Hz; tap **44.25 px** và **42.01 px**. Tap yêu cầu 35ms được làm tròn lên physics tick; các timer có độ phân giải theo tick.
- Đã mở phòng thử với renderer Compatibility, kiểm tra Sprite/bục/HUD/tiếng Việt. Người dùng đã playtest bàn phím và phản hồi ổn định. Chưa đo FPS hoặc đánh giá hiệu năng GPU.

Chạy lại test khi thay đổi module liên quan bằng PowerShell:

```powershell
& 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\hầm ngục' --fixed-fps 60 --script res://tests/movement_test.gd
& 'D:\dowload\Godot_v4.7.2-stable_win64_console.exe' --headless --path 'D:\hầm ngục' --fixed-fps 120 --script res://tests/movement_test.gd -- --hz=120
```

`--fixed-fps` dùng để chạy kiểm tra có delta cố định, không phải bằng chứng FPS của gameplay thực. Tránh thay thông số chỉ để test qua; cập nhật tiêu chí quan sát khi chủ đích game feel thay đổi.
