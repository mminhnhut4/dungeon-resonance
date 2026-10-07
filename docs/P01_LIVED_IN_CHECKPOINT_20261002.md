# P01 — cảnh có sức sống, bản thử riêng

Bản ứng viên ở `C:/Users/Admin/Documents/Codex/2026-10-02/task/exterior_lived_in_20261002_01/project`, Godot **4.7.2.stable.official.ed1daf0bf**, Compatibility. Dự án gốc **`D:/hầm ngục` chưa được áp dụng thay đổi này**. Integrator không đóng/điều khiển phiên Godot của người dùng; PID ghi nhận ban đầu16728 được thay bằng phiên31076 lúc16:44UTC, read-only window metadata xác nhận editor `node_2d.tscn` rồi game DEBUG. PC trước; chưa làm touch/mobile/export.

## Cảnh và phản hồi cây

Bốn PNG runtime từ art pack đã duyệt được nhập nguyên byte: panorama xa, grove/ruin, props và vật liệu địa hình. Ảnh CONCEPT_ONLY chỉ là concept duyệt; mọi ảnh `p01_art_*`, `tree_before_*`, `tree_after_*`, `combined_*`, `npc_p01_*` trong verification được tạo từ GPU/gameplay thật, không dùng concept làm bằng chứng.

P01 có nền núi/miếu xa, lớp grove và phế tích có parallax, đường đá, đèn/lights hữu hạn, đá nhỏ, ghế và miếu đánh dấu cửa hầm. Chỉ P01 MAIN được skin; P02–P04/B01–B04 giữ địa hình prototype hiện hữu. P04 vẫn dùng ba terrace tiến x liên tục đã chọn, không dựng lại switchback superseded.

Phản hồi cây lặp/nổi: ba bản sao pine được giảm thành **một cây điểm nhấn x565**, giữ khoảng nghỉ ở vùng plateau và lối nhảy. Grove dưới thung lũng là silhouette khác, tint/motion sâu hơn, không được trình bày như cây mọc trên đường chơi. Chín điểm mép chân opaque được đo từ PNG thực ở ngưỡng alpha224, so với `floor_y()` tại từng x đã scale; gốc được đặt sâu vừa đủ để mặt đường che phần đá chân trên dốc, thêm2px dự phòng sway. Không dùng tâm canvas hoặc mép halo trong suốt. PNG gốc không bị sửa/lật để giả thêm mẫu cây.

Polygon2D mặt đất dùng UV của texture nguồn và source-region cụ thể; sửa lỗi AtlasTexture bị kéo thành vệt. Mặt đường có chiều sâu hiển thị105px và crop vật liệu giữ tỷ lệ, thay khối300px che cảnh. Bỏ ô cửa xanh của graybox bằng cách ẩn visual; điểm E và collider cửa/hầm giữ nguyên. Mọi StaticBody polygon/shape/layer/mask/transform/one-way/disabled, anchors và interactions được đối chiếu với snapshot trước khi gắn art.

## NPC pilot

Một registry, năm stable IDs, tối đa một representation trong room được chỉ định: khách đường xa P01, người hành hương P03, hái thuốc P04, đưa tin B03, học việc B04. SC01 không spawn. Proxy là `HubNpc/Node2D`, **không có CharacterBody hay đẩy thân**; Hurtbox Area layer16/mask0/team3 dùng DamageEvent hiện hữu. Hình NPC là silhouette vector tạm, chưa là art hoàn chỉnh.

Walk/rest/work/talk/flee/downed/recovering/dead; simulation4Hz, tối đa8 bước bù/frame, dữ liệu ngoài màn hình vẫn tiến trong ExteriorHub. Modal/inventory/pause dừng đồng hồ; không dùng thời gian máy. **Chưa tiến clock trong DungeonRun**, không đi liên vùng, companion/sect AI/witness/incursion/romance chưa có. Tên/ending canon và Hạnh không thay đổi.

Sidecar `<profile>.npc_v1.json` riêng; global profile1/geography/gear UID/economy không đổi schema. DOWNED giữHP1 và `killed=false`, DamageEvent nội bộ/DOT không kết liễu. Tha không xóa fear/trust đã mất, dưỡng thương20s chơi rồi về nửa HP. Giết cần xác nhận và episode token, save thành công mới ghi tombstone, không loot/reward/relic heal. Save lỗi rollback; file hỏng/future/missing-main còn tmp/backup bị quarantine, không suy diễn commit hoặc phục sinh. Live quarantine cũng tháo actor và chặn E; prompt ưu tiên đúng tương tác gần nhất. Caption là gameplay label, giữ hiện khi debug tắt và thẳng khi trọng thương.

## Âm thanh A và những event thật

ZIP A v02 khớp17.697.957byte/SHA256030D8B8A7169EFF2A4872373E7E17EE0DBE3E0380BBFD7B6292E416C092D18A2;119member an toàn/118hash file đã kiểm.17clip runtime được chép nguyên byte,16WAV importPCM16 không nén/không normalize; OGG gió không loop. Nguồn/license/revision đầy đủ giữ ngoài runtime trong incoming bank, provenance nằm dưới docs/verification/. Không nhập nguồn, voice optional, preview montage hoặc v1 metal/block vào gameplay.

Chỉ **metal_A_contact_01/02 và metal_A_parry_01/02** có lựa chọn A của người dùng. API `play_external_event()`/`play_material_result()` giữ gain ban đầu0dB/pitch1, tránh take vừa phát, dedup hit, parry thay contact đã xếp thay vì chồng. Voice chung tối đa16, priority parry90/contact65; foley/ambience thấp hơn, finite deadline và owner ID. API synth/weighted/fire, bus gain/mute/send/effect và PCM22.05kHz cũ được giữ.

**Player hiện chưa có cơ chế/signal parry. Parry và contact kim loại chưa có binding tự động trong P01; API audition không là một đòn phản thực trong gameplay.** Không lấy ordinary block/hit làm parry. Gió/lá/bước/landing/creak/lantern là ứng viên; tắt mặc định. Khi chọn nghe thử riêng, P01 adapter nối bước Player dựa grounded displacement, bước NPC qua cue hook, một gió hữu hạn và lá gần cây. Reject teleport/dash/hurt/dead/modal; travel/teardown dọn owner. Landing/creak/lantern có slot bank nhưng chưa nối tự động. Voice và block alias không có đường bật.

`../preview_p01.ps1` mở P01 tương tác trên màn phụ với APPDATA/LOCALAPPDATA và profile QA riêng; bản mới chưa có cache được import riêng trước khi mở. `-AudioCandidates` là lựa chọn nghe ứng viên, không chứng nhận chúng đã duyệt. Launcher chưa được tự chạy phiên tương tác. Không dùng F5 project copy mà bỏ môi trường riêng, vì tên project vẫn là Dungeon Resonance.

Gói ZIP là payload có guard SHA256, không chứa cache hoặc hồ sơ. Giải nén rồi chạy `./build_private_candidate.ps1`: script kiểm toàn bộ baseline/fixture và payload trước khi tạo `./Private_P01_20261002/project`; từ chối nếu nguồn gốc đã khác hoặc đích đã tồn tại. Sau đó chạy `./Private_P01_20261002/preview_p01.ps1` để xem, hoặc thêm `-AudioCandidates` để nghe ứng viên. Dùng PowerShell tại thư mục gói. Script mặc định đọc `D:/hầm ngục`, không ghi vào đó. Candidate đã import sẵn tại đường dẫn đầu báo cáo cũng có thể mở qua launcher bên cạnh nó.

## Kiểm tra và giới hạn

Kết quả cuối được ghi trong `FINAL_VERIFICATION_SUMMARY.json`; logs trước sửa được giữ, không lọc ERROR/WARNING. **Strict r3 exit0:128 gate,6.729 check,0 ERROR/WARNING/SCRIPT ERROR/FAIL; validator165 script/33 scene.** NPC92/92, Presentation104/104 và Audio70/70 ở cả60/120Hz. Toàn bộ128 raw log của gate cuối nằm trong `evidence/strict_r3_per_gate/` của gói.

GPU cuối có **10 ảnh P01 +8 ảnh NPC,0 failure**. Hai lần nhảy/đáp shelf đều do input Player thực, grounded và vị trí collider được assert; E đi cửa đông cũng được chạy. Đã mở ảnh cuối để kiểm chân cây, plateau, cả hai shelf, caption DOWNED và hộp xác nhận giết. Không gán ảnh concept thành screenshot.

Mix thực WASAPI:185.856frame/3,872s/48kHz, peak sau limiter0,182661563,0sample full-scale,0frame mất,0failure; Master chỉ mute trong process QA sau capture effect. WAV/JSON nằm trong evidence. Đây là kiểm tra mixer/PCM thực, **chưa là xác nhận nghe bằng tai**. Bốn take A được audition qua API, không chứng nhận binding combat chưa tồn tại.

Probe render thật Compatibility/RTX5080 đo60,003FPS trong6,016s và120,018FPS trong6,007s; cùng peak543node/57drawcall,1NPC P01, candidate audio tắt. Phiên Godot/debug31076 của người dùng vẫn hoạt động ở nền; không có headless đồng thời trong probe. Đây là chẩn đoán hữu hạn trên máy này, không chứng nhận hiệu năng chung, số lượng NPC lớn hay dungeon.

- Tree-focused60Hz:104/104; before/after GPU10ảnh mỗi lượt, exit0. Lượt đầu cây có chân hở, còn khối nền lớn; sau sửa đã mở ảnh thật để kiểm chân dốc và plateau.
- NPC-integrated60r2:91/91; sau đó thêm gameplay caption visibility, số cuối92/92 trong strict. NPC GPU r1:8ảnh/0fail; r1 lộ caption debug filter, đã sửa và chụp lại8ảnh cuối. NPC worker độc lập85/85 mỗiHz/strict6366 là bằng chứng của bản worker, không thay gate bản kết hợp.
- Audio-focused60r1:53/53; sau đó thêm16check exact source PCM, số cuối nằm trong strict. Import đầu gặp preload trước asset scan, được sửa sang lazy runtime loader; Wav import mặc địnhQOA được chuyển sangPCM0. Raw logs giữ cả lỗi.
- Strict kết hợp r1 dừng ở asset_pipeline do copy ban đầu bỏ manifest/archive dùng cho test cũ.16fixture baseline/2.440.110byte được bổ sung nguyên hash; gate tập trung hồi phục79/79. Không sửa assertion hoặc giấu warning để vượt gate.
- Strict r2 chạy tới suite cuối, audio120 có3assertion sai mốc nghỉ:4frame ở120Hz chưa hết motor deceleration. Fixture được sửa chờ0,25s và xác nhận grounded/velocity gần0, không đổi motor hoặc cadence; focused cuối70/70 mỗiHz. R3 là gate strict cuối trên candidate này.
- Audit cuối17:13UTC:1.661file gốc đều nguyên SHA256,0file đổi. Fresh read save gốc bị sandbox từ chối ở lần kiểm trước; không retry/bypass và không khẳng định đã hash lại save lần này. Runtime QA chứng minh user-dir nằm trong `.../qa_data/AppData/Godot/app_userdata/Dungeon Resonance/`.

Native editor teardown **0xC0000005/fault0x547F2C** lịch sử chưa rõ nguồn và chưa được sửa; gate sạch không chứng minh hết lỗi gián đoạn. NPC worker initial diagnostic có shared EditorSettings Save OK nhưng không prehash; không tuyên bố settings đó nguyên byte. Các lần của integrator dùng cache/save process-local riêng, không đóng hoặc đổi editor gốc.

## Bước sau an toàn

Review P01/tree/NPC và nghe mix PC. Chỉ sau đó xem xét mở rộng skin ra tám room. Enemy/boss/UI/item-art mới do các worker khác làm riêng, chưa ghép vào checkpoint này. Có kế hoạch một encounter nhỏ dùng enemy/DamageEvent hiện có, telegraph và retreat rõ; trước khi mở phải thống nhất bỏ/giữ SafeHubHP floor ở vùng combat. Encounter chưa triển khai, không ghi T29/T30/T32 hay case companion/canon-death thành PASS từ generic NPC pilot.

## Áp dụng P01 vào dự án gốc — 2026-10-02

Integrator đã áp dụng phạm vi cây/skin P01, NPC pilot và bank A/API được duyệt vào `D:/hầm ngục` sau khi candidate strict128gate/6.729check và18ảnh GPU đạt. Guard kiểm toàn bộ baseline và payload trước ghi; backup sáu file cũ cùng rollback có guard SHA256 giữ tại `C:/Users/Admin/Documents/Codex/2026-10-02/task/exterior_lived_in_20261002_01/original_p01_handoff_20261002/`. Receipt sau ghi xác minh exact payload và các file baseline còn lại. Không ghi save/cache/settings, không điều khiển hoặc đóng phiên Godot của người dùng.

Bằng chứng strict/GPU nêu trên là bản candidate có runtime byte-identical với payload gốc đã áp; ba tài liệu này chỉ được thêm ghi chú activation. GPU smoke trên gốc chưa chạy vì nhóm UI đang dùng cửa sổ GPU. Các session đã mở trước patch có thể còn nạp script/scene cũ; không coi chúng là bằng chứng chạy bản vừa áp. Candidate audio vẫn tắt mặc định, metal A không có binding parry/gameplay tự động. UI/enemy-boss/item-art/cultivation của các worker chưa ghép.

## Kiểm chứng trực tiếp trên bản gốc — hoàn tất 2026-10-02 17:47UTC

Thông tin này thay trạng thái "original smoke chờ UI" ở ghi chú activation phía trên. Đã chạy runner strict mặc định trực tiếp từ `D:/hầm ngục`:128/128gate,6.729check,165script/33scene,0ERROR/WARNING/SCRIPT ERROR/FAIL. NPC92, Presentation104 và Audio70 ở cả60/120Hz. Hash1.677baseline/fixture và86payload được đối chiếu trước/sau strict; payload tiếp tục nguyên hash sau GPU. Ba tài liệu được thêm ghi chú này sau QA; runtime code/assets không thay tiếp.

GPU trên chính bản gốc:10ảnh P01 và8ảnh NPC,0fail; hai lần đáp shelf và E cửa đông do Player/input thực. Đã mở ảnh chân cây, DOWNED và xác nhận giết để kiểm caption/grounding. WASAPI48kHz/185.344frame,peak0,182661563,0full-scale/0dropped; capture mute Master trong process QA, chưa là xác nhận nghe bằng tai. Cả metal A contact và parry vẫn chưa nối tự động gameplay, chỉ API/audition; ambience/footsteps ứng viên vẫn tắt mặc định.

Probe Compatibility/RTX5080 hữu hạn6s đo60,005861/120,014129FPS,543node/57drawcall/1NPC. Phiên Godot người dùng31076 sống trước và sau; không bị đóng/focus/điều khiển. APPDATA/LOCALAPPDATA và user-data thực được xác nhận nằm trong `.../original_qa_data_20261002/`. Import cập nhật cache `.godot` và test ghi evidence của project theo cơ chế engine; không khẳng định cache/project-local editor metadata nguyên byte. Không truy cập save/settings toàn cục của người dùng. Native teardown0xC0000005 lịch sử vẫn chưa được coi là đã sửa. GPU đã trả, không còn phiên kiểm tra riêng.

Ưu tiên mới của người dùng: hoàn thiện opening gameplay trước khi thêm nội dung. Chuyển động/animation và VFX kỹ năng của địch hiện hữu chưa được sửa hoặc chứng nhận bởi FPS/logic gates trên; mốc kế tiếp là audit/fix có giới hạn và QA opening end-to-end. Tạm giữ floor/roster mới; UI/icon được tiếp tục vì phục vụ opening, cultivation chỉ nền tảng vòng đầu. Không ghép worker enemy-boss sâu/UI/item-art/cultivation vào mốc P01 này.

Receipt/log/ảnh trực tiếp nằm tại `C:/Users/Admin/Documents/Codex/2026-10-02/task/exterior_lived_in_20261002_01/original_post_apply_evidence_20261002/`; summary `ORIGINAL_FINAL_VERIFICATION_RESULT.json`. Backup/rollback source có guard vẫn ở `original_p01_handoff_20261002/`; manifest được cập nhật hash đúng ba ghi chú tài liệu, sáu backup trước patch giữ nguyên.
