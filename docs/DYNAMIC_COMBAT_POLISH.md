# Dynamic Combat Polish — chuyển động, lực đánh và save an toàn

Cập nhật 2026-10-01, Godot 4.7.2 / Compatibility. Gói này bổ sung procedural animation, bóng chân, hitstop theo thời gian thực, trauma camera, vệt chém/bụi và âm thanh có trọng lượng vào TestLevel, Alpha và campaign. Player motor, hai FSM, hướng commit theo chuột và các shape/transform Hitbox/Hurtbox giữ nguyên.

**Nghiệm thu:** gate strict mặc định sau sửa HUD đạt **2.857/2.857 assertion, 0 fail**, giữ đủ **2.409** mốc trước (gồm **2.027** baseline) và bổ sung **448**. Preview GPU cuối đạt **14 captures**; cả bốn benchmark Tiền Sảnh/Boss 60/120 FPS đều PASS. Gate 2.843 trước đó đã sạch nhưng playtest thật phát hiện cast tham chiếu Boss đã free; lỗi được tái hiện/sửa và toàn bộ gate chạy lại. [Log 2.843 được giữ](verification/hades_juice_interim_2843_strict.log), [log strict cuối](verification/hades_juice_strict_suite.log), [summary](verification/polish_test_summary.json). Mốc Full Visual trước giữ bằng chứng riêng trong [COMBAT_ART_POLISH.md](COMBAT_ART_POLISH.md).

## Chuyển động có nhịp, không đổi vật lý

- `scripts/utils/procedural_animator.gd` chứa đồng hồ và phép tính pose, không giữ actor hoặc ghi vận tốc. Player đi trên sàn có bob tối đa 2,5px hướng lên, lean tối đa 8° theo vận tốc và hồi vị mượt. `ConceptDynamics` nhận pose dưới pivot chân; Skeleton/WeaponSocket/Hurtbox không nghiêng theo sprite.
- Idle đạt scale Y tối đa 1,035. Player vẫn giữ Tween thở 1→1,03→1 / 1,2s đã kiểm chứng; tầng visual bù tỷ lệ để đạt 1,035 tổng. Slime/Boss đọc clock trình diễn và trạng thái đứng yên. Đây là co giãn toàn PNG, chưa phải animation atlas hoặc deform từng xương.
- Slime đọc telegraph của đòn cắn hiện có: anticipation 1,35×0,65 trong 0,12s; nhịp lao 0,75×1,3; đáp 1,25×0,75 rồi đàn hồi về một. Hop 6px là offset mỹ thuật. **Không bổ sung nhảy vật lý, vượt bục hoặc thay AI của Slime**; đòn cắn vẫn lao ngang theo FSM cũ.
- `ActorShadow` là ellipse 24 đỉnh, node trình diễn thuộc actor, chiếu xuống World bằng ray query được tái sử dụng. Giới hạn 30 query/giây/actor, kể cả dash; bóng nhỏ/mờ dần theo độ cao, không giữ collider hoặc tạo texture mỗi frame. Pose và shadow dừng cùng feedback khi hitstop.

## Hitstop và camera

`CombatFeedback.enable_global_hitstop()` tạo một `HitstopManager` con. `SlicePresentation` bật chế độ này khi renderer **không phải headless**; headless giữ local hitstop 0,05s cho các fixture hồi quy cũ. `combat_juice_test.gd` chủ động bật chế độ live để kiểm chính logic global trong headless; đây không phải bỏ kiểm thử tính năng mới.

- Melee xác nhận sát thương đặt `Engine.time_scale=0.05` trong 0,06s thực. Critical/heavy hoặc melee trúng target thuộc group `bosses` dùng 0,12s. Đòn bị chặn/không gây damage và DOT không tạo hitstop; contact phép thường không áp policy melee, critical phép vẫn có thể thuộc nhóm nặng.
- Một SceneTreeTimer dùng `create_timer(duration, true, false, true)` bỏ qua pause/time scale. Deadline dùng thời gian thực; nhiều request chỉ kéo dài deadline của một burst, không tạo một timer cho mỗi mục tiêu. Actor/weapon clocks đã đọc `is_frozen()` và không còn một đuôi local freeze sau khi global kết thúc.
- Root ID được deduplicate trong cache có trần 64. Cùng một nhát trúng mục tiêu thường rồi Boss nâng burst lên nặng một lần. `hit_stop_seconds=0` vẫn tắt cả global hitstop để các benchmark throughput và fixture hiện hữu giữ chính sách của chúng.
- `TimeScaleClaims` hợp thành các owner theo mức nhỏ nhất. Tab sở hữu 0,1, hitstop sở hữu 0,05; hết hitstop khi Tab còn mở trả về 0,1. Đóng Tab trước không giải phóng claim combat. Owner cuối trả baseline có trước claim; không cố ghi 1 trong khi owner khác còn hoạt động.
- Metadata của claims chỉ giữ ID/scalar. `GameFlow` giải phóng claim của subtree run trước khi detach; teardown manager ngắt callback timer. Reset feedback không giải phóng inventory của owner khác.

`PlayerCamera.add_shake(amount)` dùng FastNoiseLite × trauma² và decay mượt. Melee thêm 0,2; explosion thêm 0,4; transition thật của Boss từ stomp sang recover thêm 0,7. Trauma bị chặn ở 1. Shake cập nhật bằng thời gian thực trên `offset`, lookahead 40px vẫn dùng `position`, zoom vẫn 1,35. `shake_intensity` cho phép giảm về 0 mà không sửa actor hoặc damage. Camera2D legacy của fixture vẫn nhận đường shake cũ; không ép các bài Combat100 đổi camera.

## Flash, vệt chém và bụi

- `shaders/hit_flash.gdshader` có `active`, `flash_color` và tham số `flash` tương thích adapter cũ. RGB trở thành trắng, alpha lấy từ source texture và tint gốc. Player nghe DamageResult thật; Slime/Boss/dummy đọc hurt clock hiện có. Cửa sổ trắng 0,08s theo clock visual/actor; clock này dừng cùng hitstop, nên không coi 0,08s là cam kết thời gian thực độc lập freeze.
- `scenes/vfx/slash_arc.tscn` là entrypoint cùng `WeaponTrail`. Crescent bạc/jade quét 120° trong 0,12s visual, bắt đầu ở Active và có thể tiếp tục vào Recovery, fade recovery 0,12s. Viền mực dùng chính mesh 66 đỉnh, không thêm damage, emitter mỗi nhát hoặc hitbox. Hướng đọc snapshot đã commit; shader không dùng TIME để vệt chém không tự trôi trong freeze.
- Sparks vàng cam và spell wake từ mốc Full Visual được giữ. `FootstepDust` thêm bốn hạt một lần ở dash/landing và Boss stomp; tối đa tám owner trong pool theo phòng, lifetime owner 0,34s. Không thêm light pass/collision. Đứng trên sàn không liên tục phát bụi; headless không emitting GPU nhưng vẫn kiểm lifetime.

## Âm thanh có trọng lượng

`assets/audio/default_bus_layout.tres` tạo `Master`, `SFX`, `SFX_Combat`, `Ambient` và route legacy `DungeonSFX`. Combat→SFX→Master; Ambient→Master. Master có HardLimiter ceiling −0,8dB. AudioManager chỉ thêm bus/effect thiếu, giữ mute/gain/effect do người dùng cấu hình và chỉ gỡ phần do nó tạo khi teardown.

API `play_weighted_event()` có chín cue: swing, dash, spell explosion, aggro, hurt, jump, landing, melee impact và boss impact. PCM procedural trộn click/body/sub-bass tại startup rồi phát **một voice** cho mỗi sự kiện, pitch 0,88–1,12. `play_event()` legacy giữ năm cue, pitch 0,9–1,1 và API cũ. Cả hai chia budget 16 spatial voice, dùng owner ID, deadline thời gian thực và cleanup cùng room/quit mixer. Không thêm yêu cầu Aseprite hoặc âm thanh tải ngoài.

Các cue mới đã nối với Jump/Dash/landing thật, melee DamageResult và Boss stomp. File [weighted_sfx_preview.wav](verification/weighted_sfx_preview.wav) đã được xuất thật, 5,51s, save status 0; [audio export log](verification/hades_juice_audio_export.log) giữ 47/47 kiểm tra AudioWeight và shutdown sạch. Mixer/PCM/limiter có kiểm tự động; preview dùng bus mute, nên chưa thay cho đánh giá chất âm bằng tai.

## Lỗi giao dịch save đã sửa

Khảo sát phát hiện SanctuaryProfile trước đây có thể trừ Tàn Hồn hoặc công bố unlock dù save thất bại. `spend`, `unlock_weapon`, `archive`, `add_souls`, `discover`, `set_style` và `set_starting_weapon` nay rollback RAM khi commit thất bại, chỉ phát `changed` sau save thành công. Sanctuary Hub phân biệt thiếu Soul/mở khóa trùng với lỗi ghi; lựa chọn vũ khí khởi đầu quay lại mục đã commit khi save lỗi, kèm thông báo giữ lựa chọn trước. Không cho UI hiển thị một lựa chọn chưa được lưu như đã thành công.

Save ghi `.tmp`, flush/đọc kiểm hợp lệ, chỉ rotate main đã validate sang backup rồi commit bằng native rename với `.previous` để phục hồi khi commit lỗi. Main hỏng không ghi đè backup tốt. Reload lọc unknown/duplicate progress; save schema tương lai bị từ chối cả load và ghi để bản cũ không phá dữ liệu mới. Fault suite chủ động gây lỗi mở writer, copy backup, rename backup/main và kiểm rollback/không nhân đôi phần thưởng.

**Schema vẫn là version 1**, chỉ bảy field vĩnh viễn hiện có. Chưa thêm cảnh giới hoặc quan hệ NPC. Đây là recovery qua các lỗi I/O được kiểm và backup, không phải tuyên bố hai rename luôn nguyên tử hoặc mọi trường hợp mất điện đều giữ lần ghi cuối.

## Sửa vòng đời HUD sau khi Boss chết

Playtest campaign thật phát hiện `ArtHUD.refresh_hud()` cast `world.get("boss") as BossGolem` trước khi kiểm tra object còn sống. Dead FSM đã `queue_free()` Boss sau 0,6s, nhưng thuộc tính `world.boss` còn tham chiếu hết hiệu lực; refresh lặp sinh `Trying to cast a freed object` và giữ text/tooltip cũ. Suite HUD cũ chỉ đặt HP về 0 nên chưa kiểm trường hợp actor thực sự bị giải phóng.

ArtHUD nay kiểm Variant thô bằng `is_instance_valid` trước cast thuộc tính world/legacy WeakRef. Khi Boss chết hoặc vắng, footer ẩn và xóa ID/HP/text/tooltip; thanh Boss đang sống chỉ cập nhật dữ liệu hiện hành, không bị reset về 0 giữa các frame. HUD giữ ID/WeakRef, không giữ actor sống nhân tạo. Khi Player đã rời cây, HUD ẩn cả cụm Player/Boss.

Regression mới cho lethal DamageEvent đi qua Hurtbox, đợi Dead FSM giải phóng, refresh lặp rồi thử retry/Boss thay thế, chuyển phòng và HUD sống lâu hơn world. [Tái hiện trước sửa](verification/hades_juice_freed_boss_repro.log) có 30 checks/2 fail và script error; [focused sau sửa](verification/hades_juice_freed_boss_fix.log) đạt 30/30, không ERROR/WARNING. Đây là lỗi GDScript đã tái hiện, riêng với lỗi native editor gián đoạn lịch sử.

## Kiểm thử và bằng chứng

Runner mặc định giữ đủ import/editor/addon/validator/main/source/gameplay gate, không lọc ERROR/WARNING. Năm suite mới chạy ở cả 60 và 120 physics Hz:

| Suite | Assertion mỗi Hz | Hành vi chính |
|---|---:|---|
| Procedural Actors | 38 | Pose/foot/collider không đổi, flash alpha, shadow query budget, tám vòng teardown |
| Combat Juice | 51 | Melee Hitbox thật, deadline real, critical/Boss/dedup, 50 request, pause/modal/scene exit, trauma/accessibility |
| Audio Weight | 47 | Bus/limiter/PCM/pitch/voice cap, owner drain, teardown và API legacy |
| Dynamic VFX | 30 | Jump/dash/landing thật, dust pool/arc/geometry; Boss chết/free, retry/chuyển phòng và HUD teardown |
| Save Transaction | 58 | Fault I/O, rollback, idempotency, corrupt recovery, future-schema protection và Hub selector/status |

Tổng bổ sung **448**, giữ baseline **2.409** từ mốc trước; gate toàn bộ sau sửa HUD đạt **2.857/2.857, 0 fail**, gồm 58 kiểm tra SaveTransaction và 30 DynamicVFX mỗi mức. Validator **103 script/19 scene** và **39 Resource gameplay** đạt. Import, addon entrypoints/editor fixture/lifecycle, rig editor, main scene và tất cả suite source/gameplay đều exit 0; log kết thúc `ALL HEADLESS CHECKS PASSED`, summary có `all_strict_gates_passed=true`. Không bỏ gate hoặc lọc ERROR/WARNING. [Gate trung gian 2.817](verification/hades_juice_interim_2817_strict.log) được giữ trước khi tăng SaveTransaction 45→58, [gate trung gian 2.843](verification/hades_juice_interim_2843_strict.log) trước khi tăng DynamicVFX 23→30.

Tại cả 60/120Hz, kiểm mới xác nhận global hitstop/Inventory/pause/scene teardown, nguyên vị trí/resource của collision và hitbox, finite dust/mesh/voice/shadow lifetime và fault-save không duplicate. Sau warm-up, combat VFX **2591→2591 objects /251→251 resources** ở cả hai mức; procedural actors **2574→2567 /230→230** ở 120Hz. Các stress hữu hạn không tăng retention trong những luồng đã chạy; không coi đó là bằng chứng không thể rò rỉ ở mọi run.

[Preview GPU cuối](verification/hades_juice_preview_boss_lifetime_final.stdout.log) đã đạt **14 captures, PASS**, exit 0/stderr rỗng. Ảnh `combat_art_dynamic_*_r3.png` ghi Tiền Sảnh idle/shadow, chạy nghiêng, jump/shadow, Air Dash/landing dust, Slime anticipation/hop/landing, melee thật trúng Hurtbox và Boss idle/heavy hit/stomp. Hai ảnh thêm [Boss đã giải phóng/HUD đã ẩn](verification/combat_art_dynamic_boss_removed_hud_released.png) và [Victory qua cổng bằng E](verification/combat_art_dynamic_boss_victory_flow.png) kiểm lethal DamageEvent→Dead FSM→unlock portal→Victory thật. Các đoạn input/Hitbox/FSM thật có assertion trong `tests/preview_dynamic_polish.gd`; một số pose Slime được seek để kiểm silhouette, không dùng ảnh đó để khẳng định AI có nhảy vật lý.

Bốn benchmark GPU mới đều **PASS** trên RTX5080 / Compatibility / 1152×648, warm-up 2s + đo 6s:

| Kịch bản/cap | FPS trung bình | p95 frame gồm chờ cap | Peak physics | Peak draw calls |
|---|---:|---:|---:|---:|
| Tiền Sảnh 60 | 59,989 | 17,435ms | 2,770ms | 300 |
| Tiền Sảnh 120 | 119,980 | 9,007ms | 3,012ms | 350 |
| Boss 60 | 60,001 | 17,644ms | 3,440ms | 412 |
| Boss 120 | 120,000 | 9,289ms | 3,680ms | 472 |

JSON: `verification/hades_juice_{foyer,boss}_render_{60,120}.json`. Tải stress vẫn có 10 phép/s, 20 impact/s, 10 loot/s, ánh sáng/particles và mixer thật bus mute; thêm **10 foot-puff/s**, peak 4 owner/16 hạt. Projectile trail peak 10/11 ở Foyer và 14 ở Boss; budgets impact 24, flash light 8, spell light 12 và voice 16 giữ nguyên. Hitstop tắt riêng để đo throughput; preview động phía trên đã bật và xác nhận hitstop thật. Không lấy benchmark mute làm kiểm cảm nhận âm thanh bằng tai.

Benchmark render cần GPU/display thật; headless/fixed-fps không chứng minh FPS. Kết quả hữu hạn trên máy hiện tại không bảo đảm mọi thiết bị hoặc run vô hạn. Lỗi native editor shutdown 0xC0000005 gián đoạn đã ghi ở các lượt trước vẫn chưa có root cause đã chứng minh; import/editor của gate cuối sạch nhưng không coi lượt này là chứng minh đã sửa lỗi native.

Phiên campaign **screen1/màn phụ PID32048** đã kết thúc; startup sạch nhưng chơi thật phát sinh lỗi HUD nêu trên. [Session lỗi được giữ](verification/hades_juice_playtest_freed_boss_session.json) và [stderr lỗi](verification/hades_juice_playtest_freed_boss.stderr.log) giữ bằng chứng, không còn coi phiên này đang mở hoặc đã chơi sạch.

Sau gate 2.857, bản sửa `linear_campaign.tscn` đã mở lại ở **screen1/màn phụ PID29500**. [Session hiện hành](verification/hades_juice_playtest_session.json), [stdout r2](verification/hades_juice_playtest_visible_r2.stdout.log) và [stderr r2](verification/hades_juice_playtest_visible_r2.stderr.log) ghi phiên mới; đây là khởi chạy để người dùng chơi, không chứng minh toàn bộ thời lượng playtest hoặc quit sạch. Editor PID8568 với nội dung chưa lưu được giữ nguyên. Trong game: chuột trái chém, chuột phải phép, F5 đổi vũ khí, F8 tới Boss, backtick/tilde bật debug.

## Định hướng tiếp theo đã chọn và phần chưa triển khai

Người dùng chọn run 15–20 phút kết hợp căn cứ tu luyện lâu dài, combat nhanh/dễ đọc và trọng lượng rõ hơn cho chiêu nặng/chí mạng. Ba nhánh tiếp theo là build, cảnh giới và NPC/khám phá. Các lựa chọn cụ thể đã xác nhận:

- Đột phá mở chiêu mới để chọn một nhánh; đột phá đầu yêu cầu chứng tích Boss + Tàn Hồn, chi phí chưa chốt.
- Người mới khởi đầu với kiếm, các kit khác mở qua nhiệm vụ NPC.
- Chọn **một** trợ lực NPC tại Hub trước run; khám phá trong run mở thêm lựa chọn cho các run sau.
- Reward room cho chọn một trong ba; ordinary drops giữ riêng.
- Mỗi tầng có một cơ hội bí mật; vị trí và dấu hiệu thay đổi theo seed.
- Thiết kế death giữ Tàn Hồn/cảnh giới/công thức/quan hệ NPC nhưng mất gear trong run.

Những mục trên là **định hướng thiết kế đã xác nhận, chưa được hiện thực trong gói polish này**. Hiện mới Soul/unlock/công thức/style có save v1; chưa có cảnh giới, quest NPC, reward-room UI, placement bí mật theo seed hoặc run đã đo đủ 15–20 phút. Các lựa chọn vũ khí/free-gear và phòng bí mật có trong prototype vẫn phục vụ luồng cũ; không đồng nghĩa kit đã mở bằng quest hoặc bí mật đã được procedural hóa. [CULTIVATION_RUN_ROADMAP.md](CULTIVATION_RUN_ROADMAP.md) phân tích tham chiếu Hades II/Tale of Immortal/Chú Bé Rồng và các lát cắt tiếp theo. Không lấy cơ chế đề xuất của Dungeon Resonance làm mô tả thuật toán nội bộ các game tham chiếu.
