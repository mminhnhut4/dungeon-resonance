# Checkpoint: chuyển động và phát đòn của quái hiện có

Đây là patch ưu tiên phần mở đầu, từ bản sao riêng `opening_enemy_polish_private` của `D:\hầm ngục`. Ba file runtime thay đổi: `base_enemy.gd`, `world_enemy_visual.gd`, `slime_sprite_skin.gd`. Pilot quái tầng sâu đã đóng băng ở `deep_encounters_delivery`; patch này độc lập với pilot đó. Chưa ghép vào bản gốc hoặc bản của integrator.

## Kết quả audit và lý do sửa

1. **Body bước–dừng trong cooldown và sprite lật qua lại.** Grounded BaseEnemy đi tới mục tiêu trong tầm đánh khi cooldown chưa hết. Fixture AI thật với mục tiêu lệch ±0,25 px tái hiện 20 lần lật trong 20 tick và trôi 5 px tại 60 Hz, 1,25 px tại 120 Hz. Adapter riêng giảm lật nhưng vẫn còn trôi body. Thêm điều kiện khoảng cách ở nhánh grounded chase xử lý nguyên nhân: trong tầm thì chờ warning kế tiếp, ngoài tầm vẫn đuổi. Nhánh bay giữ cách điều hướng hiện hành.
2. **PNG grounded nhấc chân khỏi pivot tối đa 1,7 px.** Bob theo đồng hồ tổng tạo khoảng hở dù body đang đứng trên sàn. Dáng đi mới scale/rotate quanh pivot chân có sẵn; phase theo quãng đường body đi thực tế. Fixture mặt phẳng và dốc đo khoảng lệch giữa chân sprite và pivot vật lý bằng 0 px. Điều này không chứng minh mọi địa hình đều có tiếp xúc bàn chân hoàn hảo.
3. **Pose ít phân biệt và chuyển trạng thái gắt.** Slime đã có squash/bite/recovery nhưng PNG đi bộ gần như đứng nguyên pose: sau settling chỉ đổi 1 lần trong một giây. Guard reset transform mỗi tick, attack→recover nhảy khoảng 0,195 rad. Thêm gait nén/nhả của slime, preparation và recoil của roster, giảm chấn chuyển pose, cùng mark phát đòn ngắn. Assets vẫn là PNG/atlas tĩnh hiện có; đây là approximation bằng transform, chưa phải walk cycle có chân hoặc art cuối.

Không có AnimationPlayer walk clip để restart trong hai adapter này. Reset transform và nhịp theo đồng hồ là các vấn đề khác với restart clip. Audit tái hiện micro-chase trong cooldown, nhưng chưa chứng minh có jitter render do lệch physics/render trên máy của người dùng; `project.godot`, interpolation và motor dùng chung giữ nguyên.

## Phạm vi implementation

Slime/training slime: gait 28 px mỗi chu kỳ, lean nhỏ, pose attack đọc `_state_time`, vòng vàng chỉ trong tell, mark xanh chỉ khi bite hitbox thật mở, recovery tắt mark cùng hitbox. World roster: gait grounded 36 px mỗi chu kỳ, preparation trong tell, source launch mark tối đa 0,12 s, attack→recover giữ pose liên tục. Facing đang đi đọc vận tốc; vùng crossover đứng chậm ±6 px giữ mirror, warning/active dùng hướng commit thật.

Hurtbox `hit_resolved` chỉ thêm recoil cho hit được nhận, damage > 0, không phải DoT. Adapter không gọi thêm damage, hit-stop, audio hay impact spawn. Duplicate, invulnerable và DoT không restart recoil. Impact xác nhận trúng vẫn thuộc SlicePresentation hiện có. Interrupt tắt local launch/trail và FSM hiện có đóng hitbox; projectile/field đã phóng vẫn theo lifetime hiện hành của chúng. Bind/unbind và teardown ngắt observer; pause/hit-stop dùng đồng hồ gameplay cũ.

## Thông số combat giữ từ baseline

| Actor | Patrol/chase px/s | Tell / active / recovery s | Cooldown s | Attack hiện có |
|---|---:|---:|---:|---|
| Training slime trong hub | 25 / 65 | 0,45 / 0,12 / 0,30 | 0,60 | Bite 5 damage |
| Slime / runic_slime | 65 / 115 | 0,30 / 0,12 / 0,30 | 0,60 | Bite 15 damage |
| Ancient guard | 30 / 55 | 0,45 / 0,18 / 0,55 | 0,80 | Sweep 24, poise trong active |
| Bloodwing bat | 42 / 90 | 0,35 / 0,38 / 0,55 | 1,20 | Dive 16; jade bolt 12 + poison |
| Sword wraith | 45 / 100 | 0,60 / 0,30 / 0,45 | 1,20 | Thrust 20; fade không tạo invulnerability |
| Runic champion | 25 / 45 | 0,60 / 0,16 / 0,70 | 2,10 | Field warning thêm 0,45 s, tick 2 + slow |

HP, shield, range, damage snapshots, economy/loot IDs, progression, seeds, saves, player motor và hai FSM player không thay đổi. Mọi file baseline khác ngoài ba runtime kể trên giữ đúng SHA256; manifest có đủ 1.799 file ban đầu để kiểm tra.

## Số đo cùng fixture trước/sau

| Metric | Trước 60 / 120 Hz | Sau 60 / 120 Hz |
|---|---:|---:|
| Guard sprite-foot gap tối đa px | 1,699 / 1,700 | 0 / 0 |
| Guard attack→recovery bước góc đầu rad | 0,1953 / 0,1951 | 0,0503 / 0,0262 |
| Crossover 20 tick: sprite flip | 20 / 20 | 0 / 0 |
| Crossover 20 tick: body displacement px | 5 / 1,25 | 0 / 0 |
| Slime settled walk: số tick đổi pose trong 1 s | 1 / 1 | 59 / 119 |

Đây là số đo transform/collision headless. Chưa dùng chúng làm verdict về cảm giác đẹp/mượt hay FPS render. Audit JSON ghi SHA256 của cả ba runtime; baseline và patch dùng cùng fixture. `measure_baseline.ps1` trong delivery thay tạm ba file **trong bản riêng này**, xác minh hash và khôi phục byte trong `finally`; không chạy đồng thời với editor/test khác trên bản này.

## Kiểm tra đã chạy

Godot `4.7.2.stable.official.ed1daf0bf`, Compatibility; headless, tuần tự, `APPDATA`/`LOCALAPPDATA` chỉ của process trong bản riêng. `ISOLATED_USER` trong log chỉ đúng `opening_enemy_polish_private/isolated_appdata/Godot/app_userdata/Dungeon Resonance`.

| Suite | 60 Hz | 120 Hz |
|---|---:|---:|
| OpeningEnemyPolish mới | 75/75 | 75/75 |
| WorldEnemy | 55/55 | 55/55 |
| EnemyArt | 43/43 | 43/43 |
| ProceduralActors | 38/38 | 38/38 |
| Movement | 55/55 | 55/55 |
| Combat | 100/100 | 100/100 |

Tổng cuối: **732 assertion, 0 failure**. Validator: **165 scripts, 33 scenes, 0 failure**. Các run cuối exit 0, không có SCRIPT ERROR/ERROR/WARNING/FAIL; raw log giữ nguyên. Kiểm tra mới gồm tường/dốc/slow/crossover, chuẩn bị–active–recovery, shape identity, accepted/blocked/DoT/duplicate, interrupt, opening training tell/damage, pause, hit-stop, resume, observer rebind và teardown.

Một assertion ban đầu ở 120 Hz đo recoil bằng góc tuyệt đối bị sai khi recovery nghiêng chiều ngược lại; đã đổi sang độ thay đổi pose quanh hit. Log fail ban đầu vẫn giữ riêng. Import baseline trước khi sửa runtime hoàn tất asset import nhưng exit native **-1073741819 (0xC0000005)** lúc shutdown. `opening_import.log` giữ nguyên; không gọi import này là PASS, không sửa addon trong patch.

Chạy lại focused gate từ bản riêng:

```powershell
& .\tests\run_opening_enemy_polish.ps1 -IncludeLegacy
```

## Việc chưa xác minh / bàn giao cho integrator

- GPU/render/playtest chưa chạy vì chưa có cửa sổ GPU do parent điều phối. Cần xem prologue training slime và WorldCampaign roster với audio/shake tắt, capture 30/60/120 render FPS trong lúc physics giữ 60 Hz; soi cạnh chân/mirror, cue giai đoạn active, dốc/tường và crowd overlap. `--fixed-fps` của headless phía trên không phải measurement render trên GPU.
- Full strict `tests/run_tests.ps1`, editor/addon shutdown và opening end-to-end/save chưa chạy tại worker. Import native exit là blocker của full gate cần integrator xác minh; focused pass không thay thế full gate.
- Gait bằng PNG tĩnh không giải quyết articulation bàn chân và cần mắt người đánh giá chuyển động/damping. Không có asset mới hoặc claim art cuối.
- Integrator kiểm tra baseline hash trước khi áp dụng. Nếu ba file này đã đổi ở bản tích hợp, đọc diff và ghép có chủ đích; không overwrite file đang có công việc của worker khác.

## Nguồn thiết kế/engine

[Godot 4.7: Fixing jitter, stutter and input lag](https://docs.godotengine.org/en/4.7/tutorials/rendering/jitter_stutter.html) phân biệt vấn đề clock/render, physics/render mismatch và caveat interpolation/input lag. Patch ưu tiên trace và adapter cùng clock; không thay cấu hình hệ thống.

[Mariel Cartwright, GDC 2014: Fluid and Powerful Animation within Frame Restrictions](https://media.gdcvault.com/GDC2014/Presentations/Cartwright_Muriel_Animation_Bootcamp_Fluid.pdf), trang 5–9, 22, 26: pose/silhouette rõ, anticipation cho địch, followthrough và hit-stop. Áp dụng thành pose và cue đơn giản theo timing gameplay có sẵn; không sao chép art hoặc moveset từ các game được trình bày.
