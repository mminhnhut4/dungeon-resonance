# Audit shutdown damage_numbers — giới hạn chứng cứ

Audit boss_audit00:53–00:57UTC, deadline02:00UTC. Chỉ đọc project source/Windows fault events và chạy3focused processes có ngân sách cố định; không GPU, không sửa runtime/tests/assets sản phẩm, không đổi/install debugger/security/access. Main không được sửa. Strict run hiện hữu vẫn FAILED; không nhận clean rerun là crash fix.

## Failure đã xác minh

Root strict damage_numbers_60 stdout đạt34/34, objects1700→1700/resources107→107 và cả room teardown assertions, stderr rỗng; process exit -1073741819/C0000005 lúc00:51. Historical fixed60 r1 lúc00:20 cũng34/34 rồi cùng exit; editor import của helper lúc00:35 lỗi exit tương tự nhưng không chạy damage suite. Các lỗi không bị lọc và không thể coi exit0 assertion-only là gate đạt.

Windows Application Error/WER đọc-only trong WINDOWS_FAULT_EVENTS.json xác minh cùng Godot_v4.7.2-stable_win64.exe4.7.2.0 fault module, exception0xC0000005, offset0x547f2c và WER bucket1161908200763835012 cho3process:

| UTC Event1000 | PID | Receipt |
|---|---:|---|
|00:20:16.313|31708 /0x7BDC|fixture_damage_numbers_fixed60|
|00:35:17.230|6972 /0x1B3C|depth_enemy_skill_import_r1|
|00:51:22.956|1144 /0x478|strict damage_numbers_60|

Điều này xác minh native exit fault cùng signature ở cả runtime test và editor import. Chưa có stack/symbol để chỉ ra function hoặc chứng minh lỗi engine, AudioManager, font, renderer hay fixture cụ thể. Không suy causal từ fault offset hoặc từ việc retry sạch. WER archive còn Report.wer; không có usable debugger được phát hiện bởi command lookup, không cài thêm.

## Three focused runs đã định trước

Same binary D:/dowload/Godot_v4.7.2-stable_win64.exe SHA256ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424. Runner dùng --path PROJECT --fixed-fps60 --headless --script SCRIPT; APPDATA/LOCALAPPDATA/DUNGEON_QA_DATA_ROOT tách từng label, WindowStyle Hidden. Test mặc định physics60 giống strict60; không filter diagnostics.

| Label | Project/script | Kết quả |
|---|---|---|
|current_fixed60_repro_r1|private current res://tests/damage_numbers_test.gd|00:54:43.348→44.003,34/34,exit0,diagnostics[]|
|current_fixed60_repro_r2|same current source,new process/profile|00:54:44.457→45.113,34/34,exit0,diagnostics[]|
|baseline_live_source_fixed60|original_snapshot project,external baseline_live_source.gd|00:54:45.559→46.214,34/34,exit0,diagnostics[]|

Counterpart giữ source/assets/data của original_snapshot. External fixture lấy nguyên baseline tests/damage_numbers_test.gd và chỉ thay fake987654 source_id bằng room.get_instance_id() đang sống; không sửa baseline source/data hoặc main. Đây cần để loại invalid instance lookup đã xác minh trước, không che shutdown diagnostics. Baseline objects1699→1699/resources106→106; current1700→1700/resources107→107. Không chạy thêm vòng để “đủ pass”.

## Source/lifetime review và ranh giới chấp nhận

DamageNumberSpawner giữ numeric IDs, max32live/max64recent results, prune queued/freed Nodes và clear arrays ởexit. FloatingCombatText dùng existing feedback guard, finite elapsed/lifetime và queue_free. Fixture clear finite bursts, queues room rồi chờ3physics/process flush trước kiểm owner/number IDs không còn. Có local/members trỏ Node đãfree nhưng chỉ dùng numeric IDs sau room teardown; chưa tìm đường dereference freed product object trên source trace. Spawner/FloatingCombatText/AudioManager SHA hashes current đúng original_snapshot; không có causal bằng chứng buộc sửa chúng hoặc newDepth actor/VFX.

AudioManager headless Dummy không tạo playback; shutdown() có safe stop/wait cho real mixer nhưng fixture gọi SceneTree.quit trực tiếp. Đây chỉ là điểm có thể khảo sát nếu có stack/audio-driver proof; không tự thêm shutdown/đổi clocks nhằm làm test pass khi native cause chưa xác minh. Room-owned objects/resources có gate finite clean ở tất cả receipts đã đọc.

Kết luận: gameplay/lifetime assertions hẹp sạch trong3fresh runs và baseline counterpart, nhưng failure intermittent vẫn là vấn đề thật chưa rõ native cause. Không có code/test fix đề xuất từ dữ liệu này. Root có thể tiếp tục đọc các strict checks độc lập; strict kết quả trước vẫn FAILED cho tới một strict gate mới sạch theo quyết định của root. Nếu rerun lại sạch thì ghi fresh validation và prior intermittent shutdown unresolved, không ghi đã sửa crash. Bước điều tra causal tiếp cần native crash stack/symbol ở cùng binary hoặc minimized unrelated shutdown reproduction; không mở thêm nội dung, không đổi engine/cài phần mềm trong phiên này.
