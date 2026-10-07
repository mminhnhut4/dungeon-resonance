# Core Loop & Resonance Prototype

> Báo cáo mốc lịch sử. Bản hiện tại đã có 5 nguyên tố/10 cặp, boss/campaign/loot/quality/survival/Hub; xem [MILESTONE_CONTENT_REPORT.md](MILESTONE_CONTENT_REPORT.md) và [PROJECT_STATE.md](PROJECT_STATE.md). Kết quả import sạch ở mốc này không áp dụng cho addon mới; xem [ADDONS.md](ADDONS.md).

Chạy `res://scenes/test_level.tscn` bằng F5. Nhảy/chạy đến các bia hoặc Slime; ngắm chuột, đánh/phóng phép, quan sát HP/DPS/status, đổi recipe và R để thử lại.

## Điều khiển

| Input | Hành động |
|---|---|
| A/D, ←/→ | Chạy |
| Space/W | Nhảy; nhả sớm để nhảy thấp |
| Shift/K | Dash; có thể ngắt Attack/Cast |
| J / chuột trái | Combo 3 hit theo chuột |
| I / chuột phải | Phóng phép 360° theo chuột |
| 1 | Hỏa + Phong → Bão Lửa |
| 2 | Hỏa + Lôi → Quá Tải Điện Hỏa |
| 3 | Phong + Lôi → Xung Kích Tích Điện |
| 4 | Tháo bùa → phép cơ bản |
| R | Reset cả phòng, hồi sinh quái/Player/bia, dọn đạn và status |

Phòng có hai bia trên bục và hai Slime trên sàn dưới bên phải. HUD góc phải hiển thị HP, ba ô, phép hiện tại và cooldown. Mỗi Slime 60 HP; khi Player gục, bấm R để thử tiếp.

## Module 1 — Catalyst và rune

CatalystData kế thừa CatalystDefinition: 3 ô mở. RuneData kế thừa RuneDefinition: ID/tên/màu và các scalar modifier. CatalystRuntime lưu bùa đã lắp riêng theo actor; Resource không bị sửa khi lắp/đổi.

| Rune | Payload đang thử |
|---|---|
| Hỏa | Burn 3 damage mỗi 0,5s trong 3s; refresh thời lượng, không cộng vô hạn stack |
| Phong | Đạn nhanh ×1,35; knockback ×1,4; xuyên tối đa 3 mục tiêu |
| Lôi | Lan sang tối đa 2 mục tiêu còn sống, gần nhất trong bán kính 150px mỗi hop; damage child ×0,6 |

Có recipe đơn rõ ràng cho từng rune. Resolver match toàn bộ multiset: Hỏa+Phong = Phong+Hỏa; Hỏa+Hỏa không thành Hỏa; Hỏa+Phong+Lôi chưa có recipe và khóa cast. Catalog key trùng bị từ chối. Loadout rỗng có recipe basic theo yêu cầu mới của người dùng, không là fallback cho tổ hợp lỗi.

| Recipe | Hành vi | Cooldown |
|---|---|---:|
| Basic | Đạn 14 damage, hủy khi trúng/tường | 0,45s |
| Phép đơn | Đạn 14 damage mang rune tương ứng | 0,60s |
| Bão Lửa | Impact 10; một vortex bán kính 110px, hút trong 1s, kết thúc nổ AoE 24; mang burn | 1,20s |
| Quá Tải | Impact 12; nổ AoE 30 có critical text và stun 0,5s; mang burn/chain | 0,95s |
| Xung Kích | 3 dao sét cùng cast, góc -0,25/0/+0,25 rad, mỗi hit chính 12; mang wind/chain | 0,90s |

Ba dao dùng chung registry mục tiêu chính và ngân sách chain; không nhân ngân sách theo projectile. Nổ/vortex tối đa một lần mỗi cast. Child/DOT không kích lại resolver/proc.

## Module 2 — Cast và projectile

PlayerAim lưu chuột trong viewport, đổi sang world qua inverse CanvasTransform nên hỗ trợ camera pan/zoom. Mục tiêu và direction 360° dùng chung cho melee/skill, độc lập Sprite/dash.

CastSpell: Ready → windup 0,12s → phóng → recovery 0,12s → Ready. Giữ nút không auto-repeat. Nhảy/chạy vẫn được; dash/death hủy windup, giữ cooldown đã trả. Recipe/aim/rune được chốt trước windup; origin phóng lấy ở ngực hiện tại. Đổi bộ bùa giữ cooldown theo recipe ID và không sửa projectile đang tồn tại.

Projectile speed nền 560px/s; lifetime 2s. World dùng swept move_and_collide, target dùng Hitbox/DamageEvent. Basic/Hỏa/Lôi hết khi trúng; Phong/dao xuyên theo giới hạn; Firestorm/Overload hết khi impact và sinh đúng hiệu ứng của recipe. Chạm tường cũng kết thúc đạn, Firestorm/Overload nổ/tạo vortex tại điểm va chạm.

Executor thuộc room. Cap 64 entity khi phóng projectile/vortex; effect/chain có ngân sách hữu hạn. R và teardown dọn các entity; không có timer callback sống vượt room.

## Module 3 — Slime

- Patrol 65px/s giữa hai marker; quay khi gặp tường hoặc thiếu mặt sàn phía trước.
- Chase 115px/s khi Player trong 200px và không bị World che; mất aggro ngoài 260px.
- Attack trong 40px: telegraph vàng 0,3s, lao/cắn active 0,12s, gây 15 damage một lần, recovery 0,3s rồi cooldown 0,6s.
- Hurt ngắt bite, flash và knockback; stun giữ FSM tại Hurt 0,5s. Burn tick qua cùng Hurtbox/Resolver. Firestorm tác động Motor bằng lực hút.
- Dead tắt bite, dọn status, fade và tan biến trong 0,25s. R tạo lại Slime đã bị hủy.

## Module 4 — HUD và vòng thử

DebugHUD chỉ đọc runtime, không sửa HP. Preset 1–4 gọi Catalyst.install_runes; scene room giữ references và gán feedback/Player/executor. Số damage có vị trí so le để crit/impact không chồng chữ. Bia hiển thị tổng damage và DPS đo theo gameplay clock; xem [COMBAT.md](COMBAT.md).

Art là placeholder hình học; chưa có animation/SFX, boss, thưởng hoặc save. Các damage/cooldown/radius là thông số để playtest.

## Kiểm thử và kết quả ngày 2026-09-30

`tests/run_tests.ps1` chạy toàn bộ headless và báo lỗi nếu process exit khác 0 hoặc log có ERROR/WARNING/FAIL.

| Bộ kiểm tra | Kết quả |
|---|---|
| Import + validation | 45 script, 11 scene; warnings as errors trong validator; sạch |
| Movement | 55/55 ở 60 và 120 physics tick/giây |
| Combat | 100/100 ở cả hai cấu hình: 84 gốc + 16 aiming |
| Resolver | 20/20 |
| Milestone | 69/69 ở cả hai cấu hình |

Milestone kiểm thực tế input, HUD, cast/cancel/snapshot/cooldown, va tường, DOT/pierce/chain/stun/vortex/ba dao, enemy patrol/mép/tường/aggro/telegraph/15 damage/hurt/dead/reset. Legacy Movement/Combat fixture tắt AI để giữ phép đo nền; AI được kiểm trong milestone với AI bật.

Stress: warm-up rồi 3 burst × 200 yêu cầu phóng các recipe khác nhau; cap 64, chờ hết lifetime từng burst. Object count **1868 → 1868**, Resource count **85 → 85**. MemoryStatic sau burst ở 60Hz: 37.297.040 / 37.298.180 / 37.299.332 byte; 120Hz: 37.299.052 / 37.300.192 / 37.301.344 byte. Không giữ thêm projectile/context/Shape; số đo này là bài thử hữu hạn, chưa là soak test dài.

Benchmark có cửa sổ render thật, **RTX 5080**, Compatibility, **1152×648**, VSync tắt riêng benchmark. Hai Slime, hai bia, bắn phép hỗn hợp mỗi 0,1s, reset mỗi 3s; warm-up 2s rồi đo 6s mỗi cấu hình:

| Mục tiêu | Render FPS trung bình | p95 frame gồm chờ cap | Physics peak | Peak spell entity |
|---|---:|---:|---:|---:|
| 60 FPS / 60 physics Hz | 60,0014 | 17,04ms | 1,638ms | 12 |
| 120 FPS / 120 physics Hz | 120,0014 | 8,50ms | 1,219ms | 13 |

Đây là kết quả của phòng prototype trên máy hiện tại. `--fixed-fps` chỉ dùng cho headless logic, không được dùng để đo render FPS. Benchmark phát đạn qua executor để tạo tải, bỏ cooldown riêng trong tiến trình kiểm thử; gameplay thường vẫn giữ cooldown.

Log/JSON/ảnh ở `docs/verification/`. Ảnh Firestorm, Overload và Charged Slash là pixels render từ Godot, đã được xem để sửa layer/HUD. Người dùng chưa playtest phiên bản resonance mới.

## Lệnh tái chạy

```powershell
& 'D:/hầm ngục/tests/run_tests.ps1'
& 'D:/dowload/Godot_v4.7.2-stable_win64_console.exe' --path 'D:/hầm ngục' --screen 1 --script res://tests/render_benchmark.gd -- --fps=60
& 'D:/dowload/Godot_v4.7.2-stable_win64_console.exe' --path 'D:/hầm ngục' --screen 1 --script res://tests/render_benchmark.gd -- --fps=120
```

Hướng chuột đối chiếu [Godot — CanvasItem](https://docs.godotengine.org/en/stable/classes/class_canvasitem.html). Tổ chức cooldown/proc/FSM/hit-stop là lựa chọn thiết kế của dự án.
