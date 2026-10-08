# Độ trễ giao chiến và lịch sử tu luyện — 08/10/2026

Cập nhật 08:16 UTC: candidate chỉ ở bản riêng, chưa ghép main. Đã có kiểm thử native A/B bằng GPU thật ở phần cuối báo cáo, ngoài các checkpoint headless trước đó. Các mốc “chưa đo native” bên dưới mô tả trạng thái tại thời điểm tương ứng. Không ghi save thật hoặc can thiệp phiên chơi của người dùng.

## Nguyên nhân đã xác minh

- Mỗi đòn melee được xác nhận gọi proposal mastery và lưu profile đồng bộ. Schema tu luyện 1 chứa toàn bộ receipts, được duyệt/normalize/hash/copy nhiều lần trong model, cổng proposal và writer. Chi phí tăng theo lịch sử chơi.
- Bản sao save thật ở 07:27:17 UTC có **1.019 mastery, 1.024 receipts**, 145.987 bytes, profile transaction revision 1.313. `MAX_RECEIPTS=1024` còn chặn mọi command tu luyện mới, không riêng mastery. Không reset/cắt số mastery đã kiếm được để giải quyết giới hạn này.
- Đo CPU/I/O headless trên bản sao có cùng các phần profile khác: lịch sử 980 receipts khiến một proposal+commit mastery mất trung bình **153,010 ms**, tối đa **160,198 ms**; lịch sử 0 trung bình **14,284 ms**. Đây độ trễ đồng bộ trên luồng game, không phải số FPS.
- Bằng chứng native cũ trong `docs/CONTINUATION_20261008.md` và `.../dungeon_continue/FRAME_METRICS.json`: no-hitstop vẫn có frame >25ms; tắt riêng mastery commit loại bỏ các frame >25ms trong probe đó. Vì vậy có khựng ngoài hitstop. Kết quả native cũ chỉ xác lập đường nghi vấn; không thay cho native QA bản sửa hiện tại.

## Thay đổi

1. `opening_cultivation_state.gd` hỗ trợ schema 2 với tối đa **8 receipts gần nhất** và `receipt_floor`, giữ nguyên revision/next_event tăng đơn điệu. Event mới phải đúng `cult_<next_event>`; ID đã rơi khỏi cửa sổ, ID lạ, ID tương lai hoặc có số 0 thừa bị từ chối. Replay còn trong cửa sổ chỉ thành công khi kind/hash khớp; đổi nội dung là conflict. Revision được chặn hữu hạn tới LIMIT, không tràn số hoặc quay vòng. Schema 1 và các fixture arbitrary ID cũ giữ hành vi đọc/propose cũ.
2. `SanctuaryProfile.compact_cultivation_receipts()` tạo backup nguyên byte trước chuyển đổi, đặt cạnh save theo tên `.cultivation_v1.<digest>.bak`. Backup có sẵn chỉ được dùng khi khớp nguyên byte, không bị ghi đè. Chuyển đổi đi qua writer hiện có và seal hiện có. Actors, energy/mastery, nguồn dược liệu, vật liệu, souls, tuning, clocks, opaque fields đều giữ nguyên.
3. `OpeningCultivationSession.initialize()` chuyển đổi trước khi session bắt đầu sinh event/đồng bộ insight. Không thay damage, balance, hitstop, motor hay writer. Mỗi mastery vẫn được ghi bền ngay; chưa gộp RAM/dời lưu sang lúc thoát game.
4. Lỗi ghi xác định được rollback giữ schema cũ và cho retry. Trạng thái transaction không chắc chắn dùng read-only/quarantine/recovery của writer hiện có. Backup vẫn giữ toàn bộ lịch sử trước migration.

Schema 1 có receipt tên dạng `cult_...` nhưng sai số revision không được migration tự động, nhằm tránh receipt cũ bị bỏ rồi trùng một ID mới trong tương lai. Arbitrary ID không dùng tiền tố đó có thể được chuyển đổi nhưng không được phát hành như command mới ở schema 2.

## Đo đã thực chạy

Godot 4.7.2 CLI `--headless`, QA APPDATA/LOCALAPPDATA/DUNGEON_QA_DATA_ROOT riêng, cùng copied source; monotonic `Time.get_ticks_usec()`. Mỗi nhóm 5 mẫu, profile writer được warm bằng một lần save ngoài khoảng đo. Các phần đo lồng nhau không được cộng trực tiếp. Migration nằm ngoài phép đo hit. Các lượt không chạy song song với QA khác; game thật vẫn có thể thay đổi tải hệ thống.

| Lịch sử đầu vào | Runtime | Mean hit ms | Max hit ms | Mean proposal ms | Kết quả |
|---|---|---:|---:|---:|---|
| 0 | Baseline schema1 | 14,284 | 17,439 | 0,282 | 5 commit |
| 980 | Baseline schema1 | 153,010 | 160,198 | 24,078 | 5 commit |
| 1024 thật | Baseline schema1 | 13,534 | 17,513 | 13,533 | 5 reject capacity; không được coi là hit nhanh |
| 980 | Candidate recent16 | 19,024 | 19,631 | 0,714 | 5 commit |
| 1024 thật | Candidate recent16 | 19,121 | 19,828 | 0,710 | 5 commit |
| 0 | Final recent8 | 10,630 | 10,732 | 0,282 | 5 commit |
| 980 | Final recent8 | 15,615 | 19,342 | 0,581 | 5 commit |
| 1024 thật | Final recent8 | 15,724 | 17,870 | 0,556 | 5 commit; mastery 1019→1020 |

Giảm khoảng 89,8% chi phí mean trong mẫu 980 so với baseline; đây so sánh đo thử cỡ nhỏ, không phải cam kết FPS. **Vẫn có transaction trên 16ms** và chưa cộng chi phí render/physics của frame. Candidate 16 không được chọn. Final 8 vẫn giữ chính sách reject receipt bị evict, không cho regrant. Migration copied1024 final mất trung bình 143,293ms một lần lúc khởi tạo, chưa ở giao chiến.

## Kiểm thử đã thực chạy

- `compact_legacy_state_r1`: `tests/opening_cultivation_state_test.gd`, 189/189, exit0, không ERROR/WARNING; xác nhận schema1 fixtures cũ và capacity/replay cũ vẫn hoạt động.
- `compact_contract_r1`: candidate16, 86/86 sạch, evidence lịch sử. Sau đó đổi window8 và bổ sung fixture nhiều actor/lineage.
- **`compact8_contract_r2`: final8, `tests/cultivation_receipt_compaction_test.gd`, 100/100, exit0, không ERROR/WARNING.** Bao gồm cap1024, recent replay/conflict, evicted/future/arbitrary rejection, cold reload, bounded history, full-file backup, opaque numeric values, NPC đã tu luyện, consumed/unconsumed herbs, nguồn lineage/materials, migration retry, writer fault tại candidate/commit/after-decision/after-commit, stale external authority, backup conflict, per-hit retry không tăng hai lần, watermark và counter giới hạn.
- `profile_size_baseline_warm_r2`: baseline 47/47 sạch.
- `profile_size_compact_warm_r1` và `profile_size_compact8_warm_r1`: mỗi lượt 62/62 sạch, same copied source và shape, chưa phải gameplay/native frame-time test.
- Session thêm reset initialized/error lúc retry sau focused run; thay đổi nhỏ này cùng GameFlow/hit pipeline thuộc integration gate kế tiếp của đầu mối ghép.

Không claim đã chạy full strict trên bản hợp nhất. Đầu mối ghép tiếp tục actual GameFlow + real Weapon hit pipeline với bản sao save đã chạm cap, rồi strict gate phù hợp. Native combat frame-time/vòng chơi bằng mắt còn chờ quyền dùng GPU khi game thật được đóng. Không coi headless CPU, ảnh render hoặc logic test là trải nghiệm đã hoàn thiện.

## Evidence và bảo vệ save

Evidence root: `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/`.

- `perf_worker/CAPTURE_RECEIPT.json`, `real_profile_capture.json`: read-only capture, hai lượt đọc có cùng bytes/hash. SHA256 **169f8f5a16ddaa42d296509909ce9d019fe9e15192b490578c7e47913641511b**. Nguồn thật chỉ đọc; các test chỉ ghi user:// trong QA. Không khẳng định save thật không đổi trong lúc người dùng đang chơi.
- `perf_worker/*.baseline`: preimages ba runtime file trước sửa.
- `perf_worker/size_profile_probe.baseline_warm.gd`, `size_profile_compact_probe.gd`, `measured_profile.gd`, `measured_writer.gd`: probe/instrumentation ngoài dự án, không ship vào game.
- `corner_worker/<label>/`: stdout/stderr nguyên bản, `RUN_RESULT.json`, `size_profile_trace.json` nếu là performance probe. Label chính đúng bảng/kiểm thử trên. Không lọc ERROR/WARNING.
- Writer không sửa (`git diff -- scripts/runtime/profile_commit_writer.gd` trống). Hash bytes có thể khác checkout chính do line endings; không dùng byte-hash khác checkout như bằng chứng sửa logic.

Rollback trước ghép: bỏ đúng các file thuộc patch này, không chạm file agent khác. Sau khi schema2 được sử dụng: giữ snapshot save mới trước mọi rollback; build cũ phải giữ nguyên cơ chế fail-closed với schema tương lai. Backup migration là lịch sử tại thời điểm chuyển đổi, **không** là lý do tự khôi phục save cũ và làm mất phần thưởng kiếm sau đó. Khi cần hoàn tác dữ liệu phải đối chiếu snapshot, không tự xóa `receipt_floor` hoặc reset earned counters.

## File bàn giao

Runtime: `scripts/cultivation/opening_cultivation_state.gd`, `scripts/cultivation/opening_cultivation_session.gd`, `scripts/runtime/sanctuary_profile.gd`.

Test: `tests/cultivation_receipt_compaction_test.gd` và `.uid`. Đầu mối ghép thêm test vào strict runner. Report này là checkpoint riêng trước integration/native gates; không là xác nhận đã ghép main.

## Bổ sung integration thực, 07:55 UTC

Đã hoàn thành phần actual GameFlow/Weapon được ghi là còn chờ ở checkpoint trên, không thay ba runtime file đã freeze:

- `tests/cultivation_combat_profile_test.gd` và `.uid`: mặc định tự tạo fixture sealed 1.024 receipts trong QA, không đọc đường dẫn người dùng. Có thể nhận `--seed-profile=<copied-path>` hoặc biến `DUNGEON_CULTIVATION_CAPTURE`; source chỉ đọc, toàn bộ gameplay ghi bản sao trong QA.
- **`actual_combat_copied_cap_r1`: 68/68, exit0, diagnostics[]**, trên đúng capture 145.987 bytes/SHA256 ở trên. Product main scene mở ExteriorHub, migration trước bind, vào WorldCampaign stage1 qua route hiện có. Mastery **1019→1029**, cold reload khớp và seal hợp lệ. Backup migration nguyên byte, nguồn capture không đổi.
- **`actual_combat_portable_60_r1` và `actual_combat_portable_120_r1`: mỗi 67/67, exit0, diagnostics[]**. Chứng minh default fixture tự chạy được ở hai physics rate và không phụ thuộc file capture ngoài máy.
- Dùng InputEventKey J/chuột → Player FSM → Weapon/Hitbox query → Slime Hurtbox/DamageResolver → live cultivation adapter. Không gọi giả `_confirmed_hit`, không phát `hit_confirmed.emit` để cấp mastery. Mỗi lượt có **10 melee roots, 20 confirmed contacts và 40 resolved events**; Lightning chain tạo child damage thật. Hai mục tiêu trong cùng window và proc không làm tăng gấp đôi mastery. Event đầu sau migration bị evict rồi cold reload vẫn reject, không regrant.
- Fixture có chủ ý: ba Slime HP cao, tắt AI/contact damage, đặt hai con sát nhau và con thứ ba trong tầm chain; tắt tự sinh thêm quái; thêm một rune Lightning qua inventory API. Giữ nguyên mọi UID/quality/affix/loot record ban đầu, không xóa metadata để làm source pass. Đây kiểm đường thực thi và save trong gameplay, không phải vòng chiến tự nhiên hay trải nghiệm hoàn thiện.
- Trace nối từ callback `DamageResolver.damage_resolved` tới listener cuối `Weapon.hit_confirmed`, bao gồm feedback/mastery và các listener liên quan. Trên copied save: 5 first-contact samples bật hitstop trung bình **19,243ms**, tối đa **19,616ms**; 5 samples tắt hitstop trung bình **18,406ms**, tối đa **18,810ms**. Listener contact thứ hai cùng root không cấp thêm mastery. Khoảng đo này rộng hơn proposal+commit của microprobe; không cộng hoặc so ngang như cùng đại lượng.
- Trace ghi riêng trạng thái hitstop/time_scale và wall/process/physics samples. Bật hitstop có freeze thực, tắt hitstop vẫn thực hiện mastery và không có freeze chủ ý. **Chi phí callback vẫn vượt 16ms**, native render/physics tổng frame vẫn chưa đo. Không tuyên bố sửa xong toàn bộ tụt FPS.

Raw stdout/stderr, receipt và `cultivation_combat_profile_trace.json` nằm ở `corner_worker/<label>/` tương ứng. Lane headless trả đầu mối ghép lúc 07:55 UTC; không có GPU probe hay can thiệp phiên chơi thật. Full strict hợp nhất và native play/frame-time vẫn thuộc gate tiếp theo của đầu mối ghép.

## Phân rã chi phí còn lại, 08:06 UTC — không đổi product

Khi đầu mối xác nhận phiên chơi thật đã đóng, dùng lane headless riêng đo các hàm static và một bản writer chỉ thêm timestamp trong scratch ngoài dự án. Không thay reader/writer/parser trong product và không lặp thí nghiệm read-after-read đã bị loại.

- parser_cost_baseline_r1: **213/213**, 30 samples interleaved trên derived compact capture 8.028 bytes, SHA256 a81ac9eb573db342cea4a62a44f1e78d6260c2fe2426c2de1b7439fb56096598. Mean native JSON parse 0,161ms; depth walk 0,072ms; full JsonSpans scan 1,784ms; complete read_document 2,326ms; sealed 0,673ms; normalize 0,138ms.
- Instrument riêng _string_end: 527 string scans/6.541 ký tự chỉ **0,279ms** tổng. Không tiếp tục phương án RegEx/native string skipping: trần lợi ích nhỏ so với rủi ro thay scanner đang bảo vệ escapes, Unicode, control characters, duplicate authority và opaque spans.
- compact8_writer_deep_r1 và r2: mỗi **62/62**, exit0, diagnostics[]. Chỉ thêm timestamp, không bỏ flush, đọc lại, seal, stale-authority check hay fault protocol.
- Lượt deep r2, copied1024 hot proposal+commit: **12,026ms mean / 12,473ms max**, sau khi game thật đã đóng. Ba lần read_document/hit (marker, candidate, decision) tổng mean **3,84ms**: opaque scanner 1,96; mở file 1,20; native parse + depth 0,29; restore/normalize 0,27; lấy text 0,10ms. Sealed candidate riêng 0,69ms. Các số đo lồng nhau không được cộng như phase độc lập.
- Lượt r1 có first-sample 17,628ms, candidate read 5,906ms và decision read 3,653ms. Có biến thiên wall-time ở đường đọc; **chưa xác minh nguyên nhân hệ điều hành/antivirus**, không quy kết cho một dịch vụ cụ thể.

Nhánh này giữ candidate recent8. Không có sửa bổ sung ít rủi ro với lợi ích đủ rõ để ghép. Các phép đo khác tải hệ thống không được coi là cải thiện do code. Lane trả lúc 08:06 UTC trước nhóm native dưới đây.

## Native frame-time A/B, 08:13–08:15 UTC

Đã chạy hai engine native **nối tiếp**, không có Godot khác trước/sau từng lượt. Không dùng headless hoặc --fixed-fps. Start-Process Hidden, cửa sổ NO_FOCUS; QA APPDATA/LOCALAPPDATA/user:// riêng. Main D:/hầm ngục giữ HEAD f626fd9edff51ccad6bdcddf40953b10ebce20ea và git status sạch. Không sửa ba runtime đã freeze; không ghi save thật.

Cấu hình giống nhau: Godot 4.7.2-stable official ed1daf0bf; Windows; GL Compatibility, OpenGL 3.3.0 NVIDIA 616.92; GPU **NVIDIA GeForce RTX 5080**; CPU **AMD Ryzen 7 9800X3D 8-Core**; viewport/cửa sổ thực **1280×720**; VSync OFF; render cap120; physics60. File VIDEO_CONTROLLERS.json còn ghi AMD Radeon(TM) Graphics và driver hệ thống; engine stdout xác nhận adapter render thực là RTX5080.

Hai lượt dùng chính xác cùng fixture SHA256 **78f03b478f4e2dcfcc6709ce69e8567d637872ef3c586d83b1310293b1c9ef1c**. Tạo từ capture thật 1.024 receipts bằng cách bỏ đúng 44 receipt mastery cuối và giảm tương ứng mastery1019→975, để baseline còn khả năng commit trong cả phép đo. Giữ mọi metadata, bank, UID, affix, opaque fields khác. Baseline khởi động schema1/980 receipts; private tự chuyển schema2/8 receipts và vẫn975 mastery.

Hành trình thực: product main → ExteriorHub → WorldCampaign stage1; InputEvent chuột/J → Player FSM → Weapon/Hitbox → Slime resolver → cultivation. Controlled fixture dùng ba Slime HP cao/tắt AI, hai con trong cùng hitbox và con thứ ba trong tầm chain; thêm Lightning qua inventory API. Cùng seed critical20261008; hai đòn warm-up ngoài đo, rồi normal và no_hitstop mỗi10 giây, lịch nhấn mỗi0,8 giây. Mỗi pha có **13 accepted roots**; mỗi bản tổng28 roots kể warm-up, **56 chain hits**, mastery975→1003. Baseline kết thúc revision1008, vẫn chưa chạm cap; private cùng revision1008, history8.

Monotonic process-frame gaps được lấy khi renderer native thực chạy. Đây khoảng wall-time giữa frame native, không là GPU timestamp riêng; có ghi process/physics monitors, draw calls, hitstop và time_scale trong raw trace.

| Bản / pha | Frames | p50 ms | p95 ms | p99 ms | Max ms | >33,33ms | >50ms |
|---|---:|---:|---:|---:|---:|---:|---:|
| Main baseline / normal | 987 | 7,992 | 8,848 | **156,909** | **168,359** | 13 | 13 |
| Private recent8 / normal | 1190 | 8,216 | 8,840 | **28,384** | **31,352** | 0 | 0 |
| Main baseline / no hitstop | 984 | 8,005 | 8,874 | **158,941** | **171,297** | 13 | 13 |
| Private recent8 / no hitstop | 1190 | 8,022 | 8,847 | **28,982** | **31,614** | 0 | 0 |

**Khựng ngoài hitstop đã được tái hiện rõ**: baseline vẫn có13 frame trên50ms khi tắt hitstop. Candidate loại bỏ toàn bộ frame trên33,33ms trong hai khoảng đo này; p99 giảm khoảng82%. Callback first-contact gồm các listener và mastery: baseline mean148,045ms normal/149,767ms no-hitstop, private19,310/19,215ms. Khoảng đo không phải chỉ riêng disk I/O.

**Giới hạn còn lại:** vẫn có các frame28–31ms quanh hit, nên chưa đảm bảo frame đều ở60/120FPS. Đây một battle fixture có kiểm soát trong stage1, không là bằng chứng mọi floor/boss/wave hoặc chơi tự nhiên đã hoàn thiện. Không tiếp tục đổi writer rủi ro để chạy theo số liệu. Full strict hợp nhất và native NPC/shop/map QA do đầu mối điều phối tiếp.

Cả native_main980_r1 và native_private980_r1 đều **11/11**, exit0, không ERROR/WARNING, source capture hash giữ nguyên, profile sau trận seal hợp lệ. Tổng4.351 frame đo và52 accepted roots trong các pha đo; warm-up/capture PNG được loại khỏi khoảng đo.

Evidence dưới perf_worker/native_main980_r1 và perf_worker/native_private980_r1: native_combat_trace.json đầy đủ frame/hit timestamps, stdout.log, stderr.log, RUN_RESULT.json, VIDEO_CONTROLLERS.json, GODOT_BEFORE.json, GODOT_AFTER.json và native_battle.png. PNG1280×720 thực đọc từ render framebuffer đã được mở kiểm: đúng sân chiến stage1, nhân vật cầm kiếm đánh nhóm Slime; không là ảnh thiết kế hoặc ảnh sinh giả. Chụp ngoài khoảng đo để không trộn readback stall vào kết quả.

Handoff native hoàn tất lúc08:15:52 UTC, engine/GPU lane đã trả. Đầu mối ghép giữ quyền áp dụng main và bảo vệ/backup save khi đổi build.
