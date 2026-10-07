# Candidate hai công pháp mở đầu — 2026-10-03

Chỉ làm trong `cultivation_styles_private`, bản copy mới từ `D:\hầm ngục` theo approval 23:49. Không ghi original, không merge, không sửa các bản deeper/opening đã đóng băng. Main integrator giữ quyền tích hợp; worker cảnh giới giữ shared progression/codec. Các hình vòng/ấn/vệt là procedural placeholder, chưa có final art hay đánh giá game feel bằng mắt.

**Revision r3, compatibility theo clarification 01:01:** giữ hệ tu luyện mới đã được duyệt. Cảnh giới/tư chất/công pháp cùng trang bị và ghép Rune quyết định lối đánh; không chọn một bên rồi bỏ bên kia. Hai technique là phần thêm cho progression của owner, không thay hoặc tắt spell-combination identity của game. DECISIONS/CULTIVATION_RUN_ROADMAP ghi kiếm mở đầu, kit dao/pháp sư qua NPC và Boss proof+Souls cho đột phá; candidate này không cấp kit, không rollback realm/aptitude và không nhận ownership của save đó.

## Ý đồ chơi và thông số

Hồi Phong Kiếm trả phần thưởng cho né xuyên đòn rồi đổi hướng đánh trả. Nó dùng Ancient Sword đã tồn tại và đòn 10 damage thông thường; không thêm parry, stun hoặc nhân damage. Kẻ có Poise vẫn giữ đòn đã commit; boss nhận stagger bình thường. Tỏa Linh Ấn yêu cầu dự đoán vị trí địch và chi hai lần để mở vùng kiểm soát nhỏ. Không có sát thương tự động khi địch đi qua ấn và không tự cấp catalyst/trượng. Hai phong cách khác ở quyết định vị trí/thời điểm, không ở tăng chỉ số.

| Technique ID | Phí và cooldown | Tell / active / recovery | Giới hạn |
| --- | --- | --- | --- |
| `cloud_return` | Dash hiện có 25, phản kích 12; hồi 3s | 0,08 / 0,09 / 0,28s | Cửa 0,75s chỉ sau hostile DIRECT bị i-frame dash thật chặn; cần Ancient Sword; một mục tiêu, damage 10/stagger 10 |
| `tether_sigil` đặt | 18; hồi 5s từ commit | 0,30 / 0,06 / 0,25s | Một mark, LOS/tầm 190px, arm 0,35s sau xuất hiện, hết hạn 4s |
| `tether_sigil` kích | 8; giữ cooldown đặt | 0,18 / 0,12 / 0,25s | Radius 72px, tối đa 3 mục tiêu có LOS, damage 4/slow 0,55 trong 0,7s; actor cách mark tối đa 260px và có LOS khi commit/launch |

Resource trong `data/cultivation` giữ tuning dùng chung; energy/cooldown/ticket/mark/dedup nằm trong runtime riêng từng actor. Chiêu hụt/hủy vẫn mất phí và giữ cooldown. Không có DoT/proc/roll loot mới, không RNG mới, không sửa IDs/catalog hoặc hệ economy.

## Hợp đồng tích hợp tối thiểu

`CultivationStyleRuntime.initialize(player, current_room)` đăng ký một action opt-in mà không reinitialize FSM. `apply_progress_snapshot(learned_ids: Array[StringName], selected_id: StringName)` nhận kết quả đã xác thực từ shared progression owner. Runtime mặc định locked, từ chối ID lạ/trùng/selection chưa học atomic; không có save hoặc auto grant. Snapshot y hệt là idempotent. Respec/revoke hủy transient, giữ energy/cooldown.

`request_skill(target_world)` là đầu vào cho binding/UI của integrator. `bind_room(room)` khi travel và `cancel_for_room_transition()` trước relocate/reset/teardown đóng hitbox, xóa mark/ticket/action, giữ clock/cost. Room `tree_exiting` và guard trước launch cũng chặn stale spawn. Runtime đi cùng Player qua room travel; không tạo lại mỗi room. Nếu GameFlow tạo Player mới, owner quyết định quy tắc chuyển clock, không dùng fixture như save owner.

Signals `technique_committed(id, root_id)`, `technique_finished(id, completed/cancelled)`, `counter_readied(root_id)` chỉ là telemetry; không tự claim quest, tiền hoặc unlock. Realm/quest/codec owner quyết định quyền học, selection và chi phí respec. Không thêm trường profile/save.

Revision r2 sửa notification `technique_finished`: đóng hitbox và xóa `_mode`/definition/launch/root trước, capture ID/reason rồi defer signal qua message queue sau FSM transition. Callback progression có thể gọi snapshot khác learned/selected mà không re-enter `exit()` hoặc phát event thứ hai. Khi hoàn tất/cancel-for-room callback thấy Ready; khi bị dash/Hurt/Dead ngắt, callback thấy state kế tiếp tương ứng. Cooldown và energy không bị xóa/refund. Không đổi FSM transition chung hoặc motor để sửa lỗi này.

Core delta: `ActorStateMachine.register_state/unregister_state` thêm action riêng có setup/exit rõ; `Player` thêm `cultivation_skill` vào hai allowlist dash/jump. Motor, locomotion FSM, Dash clocks/cost/i-frame, DamageEvent/Resolver, gear/economy/floor/save giữ baseline. Inventory equip trực tiếp cũng hủy ticket/mark bằng quan sát definition, không phụ thuộc mỗi signal Player.

Đã đọc lại đường `GearSession.sync_loadout → Catalyst.install_runes → ResonanceResolver exact multiset → ResonanceController.commit_cast → PlayerCastState → SpellExecutor`. Style selection/revocation không sửa Rune UIDs/slots, capacity/rarity, recipe catalog, casting_enabled hay cooldown phép. `selected_id` là slot chiêu G, không hard class selector; I/chuột phải giữ phép ghép bùa. Kiếm chỉ yêu cầu Ancient Sword để chạy counter, không khóa kit/cast khác. `allow_resonance=false` chỉ áp event mới của prototype để không nhân proc; không gỡ bùa vũ khí/catalyst hoặc thay ma trận. Tỏa Linh có thể giữ mark rồi cast tổ hợp cũ và sau đó kích mark với các phí/cooldown độc lập trên cùng energy pool.

ASSET_PIPELINE giữ PNG/Atlas source/provenance/collision contracts. Candidate không đổi PNG/atlas/shader/collider/resources; fixture dùng skin/art actor, SpellExecutor/VFX và CombatFeedback cũ. Vòng/ấn thêm là procedural placeholder có giới hạn; không import/generate art mới và không tuyên bố đã final/render-tested.

## Chạy thử và bằng chứng

Scene opt-in `res://scenes/cultivation/style_lab.tscn` là test fixture ghi rõ candidate: F9 kiếm, F10 ấn, G kích; R reset room theo điều khiển cũ và rebuild ba enemy đã có. `fixture_unlocks=true` chỉ ở scene này, main/GameFlow không đổi. Không dùng Q/1/2 vì trùng vũ khí/rune, không dùng F5–F8 vì QA ContentSession có catalog/secret/boss. F6 vẫn mở ma trận khi bật QA. Không tự bật scene này trong run thật.

Đã chạy Godot 4.7.2 Compatibility **headless** với APPDATA/LOCALAPPDATA riêng nằm trong private copy; `user://` ở `isolated_appdata/Godot/app_userdata/Dungeon Resonance`. Không dùng real save. Import exit 0; validator **174 scripts/34 scenes**, không lỗi/warning.

Ở **mỗi** mức 60/120 Hz: candidate **99** checks sạch; focused legacy WorldEnemy **55**, Movement **55**, Combat **100**, Gear **35**, Resonance **20**, SpellMatrix **64** sạch. Tổng **856 assertions**, không lỗi/warning trong final logs. Candidate cuối đã chạy lại sau r3; legacy core suites chạy với cùng Player/FSM delta không đổi; hai suite ghép bùa chạy bổ sung sau audit. Có input thật F9/F10/G/I/F6, real dash + hostile Hitbox query sau deferred immunity, damage/dedup/Poise/recovery, LOS/NaN/range, shield/boss, DOT/damage grace không prime, pause/freeze, respec/room free/Hurt/Dead/teardown và mark budgets. R2 có 14 callback regression checks mỗi Hz; r3 thêm 10 checks giữ exact recipe/Rune UIDs/per-recipe cooldown và cast Firestorm thật lúc mark tồn tại/cả khi techniques bị revoke. Old F6 catalog vẫn hoạt động và F9/F10 không chạm F7 debug rewards.

Bản trước r2 tái hiện **5 failures/89 checks ở 60 Hz** bằng callback có cap; raw `cultivation_styles_60_reentry_reproduced.log` giữ trong evidence. Raw fixture lỗi starting weapon và typed array khi gọi API qua Node dynamic cũng giữ; đã sửa fixture, không coi các lượt đó là PASS vì runner bắt SCRIPT ERROR dù process exit 0. Final logs sạch.

Chưa chạy GPU/render/audio/playtest, `tests/run_tests.ps1` strict/editor/addon gate, hoặc end-to-end realm/NPC/UI/codec/save. Headless không chứng minh độ đẹp/readability hay balance cuối. Không có blocker của isolated candidate; các kiểm tra và wiring này là bước còn lại của sole integrator trước merge.

Runner `tests/run_cultivation_styles.ps1 -IncludeLegacy -IncludeComposition` chỉ tập trung; không gắn nhãn full PASS. Delivery kèm unified patch, 1.830-file baseline manifest, baseline bytes cho hai file sửa, source SHA256/evidence và script rebuild byte-verified. Nếu baseline drift, integrator phải đối chiếu hunk thay vì chép đè Player/FSM.

Nguồn chính: AGENTS/GDD/PROJECT_STATE/PROJECT_ARCHITECTURE/DECISIONS và runtime motor/twoFSM/Weapon/Hurtbox/Hitbox/DamageEvent/GearSession hiện hữu của chính project; constraints skill `godot-dungeon-dev`. API không chắc về immunity được kiểm bằng Godot engine thực tế qua physics query. Thiết kế mới tự dựng, không sao chép hình/nội dung Tale of Immortal và không tải thêm art/package/engine.
