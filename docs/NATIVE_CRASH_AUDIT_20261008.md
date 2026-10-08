# Audit crash native 0x547F2C — 08/10/2026

Đọc dữ liệu có sẵn lúc09:14–09:22UTC, không chạy Godot, sửa source/test/config, cài debugger, đổi engine hoặc tải symbol. **Chưa xác định nguyên nhân gốc và chưa có bản sửa crash.** Hai lượt bị crash vẫn là gate FAILED dù đã in assertion PASS.

## Bằng chứng hiện tại

| Lượt | Dữ kiện |
| --- | --- |
| strict R1 `damage_numbers_120` | 08:41:22UTC, PID7952, Event1000 record406398. In34checks/0fail và teardown assertions, sau đó exit-1073741819 (`0xC0000005`). |
| `r2_selector_import` | 09:12:29UTC, PID11404, Event1000 record406451. Headless editor/import, log cuối `[DONE] loading_editor_layout`; exit-1073741819, không timeout, diagnostics[] nhưng `passed:false`. |

Cả hai Windows events ghi fault module `Godot_v4.7.2-stable_win64.exe`, version4.7.2.0, timestamp`6a826550`, offset`0x547F2C`, cùng WER bucket`1161908200763835012`. EXE `D:/dowload/Godot_v4.7.2-stable_win64.exe` hiện có SHA256`ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424`, khớp engine ghi ở báo cáo Oct7.

Minidump của hai PID còn nguyên tại `C:/Users/Admin/AppData/Local/CrashDumps`. Parser read-only dùng Python chuẩn đã đọc exception/module/thread streams và PE `.pdata/.xdata`. ExceptionInformation[0]=0 là **đọc** địa chỉ không truy cập được theo [Microsoft MINIDUMP_EXCEPTION](https://learn.microsoft.com/en-us/windows/win32/api/minidumpapiset/ns-minidumpapiset-minidump_exception). Cả hai address khác0 và bằng R13+8. Không có memory-info stream trong dump, nên chưa kết luận vùng đó đã free hay vì sao pointer sai.

Chuỗi frame RVA từ regular x64 unwind của cả hai trùng:

`547F2C → 3E3BAF8 → 60539 → 52ADF → 52B7E → 10C9 → 13F6`

Phương pháp dựa bảng unwind của đúng executable theo [Microsoft x64 exception handling](https://learn.microsoft.com/en-us/cpp/build/exception-handling-x64). Đây là unwind giới hạn không có symbols, không phải stack đã giải tên hàm đầy đủ. Function chứa60539 có địa chỉ đầu60240 và các string reference đọc từ executable: `Main::Cleanup`, `Shutdown`, `main/main.cpp`, `cleanup`. Do đó **bằng chứng ủng hộ hai crash đi qua cùng đường cleanup/shutdown engine**. Function chứa fault bắt đầu547EE0 có references `cowdata.h` và `self_list.h`, nhưng chúng là template dùng nhiều nơi; chưa đủ để đặt tên hàm fault hay buộc lỗi cho một class/game script.

Đã đọc10dump Godot Oct7–8 có sẵn: tất cả cùng fault offset và read-violation signature; hai PID mới được nối chắc chắn với raw run/Event1000. Không giả định mọi dump cũ do cùng bước gameplay hoặc cùng nguyên nhân khởi phát. Không copy, upload hay đưa toàn bộ dump vào project.

## Giới hạn và quan hệ với workaround UV cũ

PE hiện tại không có COFF symbol table và debug directory. Không thấy `.pdb/.map` cạnh engine hoặc cdb/windbg/dumpchk/objdump trong PATH và SDK debugger directory đã kiểm. Không tìm tiếp toàn ổ đĩa, không tải hay cài gì. Không có symbol khớp để giải tên hai frame đầu.

[COMBAT_VISUAL_FIX_20261007.md](COMBAT_VISUAL_FIX_20261007.md) đã ghi thay UV Polygon2D bằng ArrayMesh làm các probe riêng sạch, đồng thời không nhận là fix mọi native crash. Import headless hiện tại cùng offset cho thấy không thể lấy riêng workaround Golem/GPU draw làm lời giải đủ cho crash mới. Read violation có thể phù hợp nhiều lỗi lifetime/pointer, nhưng dump này chưa chứng minh use-after-free, double-free, GPU driver hoặc lỗi do mipmap.

## Bước cô lập nhỏ khi được cấp lane riêng

1. Chạy standalone `damage_numbers_test.gd --hz=120` trên chính checkpoint, engine và QA root riêng; giữ toàn stdout/stderr, exitcode và Event1000/dump. Một lượt sạch chỉ là mẫu sạch, không xóa crash R1.
2. Nếu cần phân biệt project với engine, tạo project rỗng **ngoài checkout** và cùng engine/headless quit/import, không đổi plugin/config của project thật. Thử số lượt hữu hạn có ghi trước; không lặp đến khi PASS rồi gọi là đã sửa.
3. Nếu crash còn có cùng stack ở project rỗng, lưu minimal reproduction để điều tra engine sau. Nếu chỉ project hiện tại gây crash, thu nhỏ phần khởi tạo/teardown trong fixture riêng từng nhóm, giữ gate đầy đủ và không sửa game chỉ để che exitcode.

Các bước trên là đề xuất, **chưa thực chạy trong audit này**. Root giữ full strict R2 và quyết định checkpoint. Gate import/editor vẫn bắt buộc; logic34/34 hoặc diagnostics[] không thể thay exit0.

Evidence read-only nằm tại `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/crash_audit`: `read_minidumps.py`, `MINIDUMP_AUDIT.json` (hash từng dump, exception và frame offsets), `WINDOWS_EVENTS_1000.json`, `IMPORT_RUN_RESULT.json`, raw import stdout/stderr. Dump gốc giữ tại CrashDumps; không đưa vào artifact công khai. Raw strict R1 còn nguyên ở `strict_candidate_r1/strict_raw.log`, dòng1937–1976.

## Hai crash strict R3 — audit09:58–10:01UTC

R3 bắt đầu09:55:48UTC và còn đang chạy lúc audit này; chưa kết luận các gate chưa xong. Không chạy Godot hoặc sửa source/test/config trong lúc root giữ lane.

| Gate | Event1000 và dump mới | Quan sát raw |
| --- | --- | --- |
| `addon_entrypoints` | 09:56:00UTC, record406457, PID26212; dump4.52MB | `addon_cleanup_entrypoints.gd` là compile-only gate: load4plugin entrypoint, chờ5frame, in8checks/0fail rồi thoát0xC0000005. |
| `player_rig_editor` | 09:56:15UTC, record406459, PID14848; dump4.65MB | Headless editor mở PlayerRig, unload phantom_camera/rmsmartshape/beehave, log `EditorSettings: Save OK!`, rồi thoát0xC0000005. |

Parser cũ đọc hai dump mới: cùng executable hash, read-violation tại R13+8, offset547F2C và **cùng toàn bộ7frame RVA** với audit đầu. WER bucket vẫn1161908200763835012. Tổng12dump đọc được hiện có cùng signature này. Không có symbol hay memory-info mới; nguyên nhân pointer sai và tên hàm fault vẫn chưa biết. Hai file raw crash được trích nguyên block (không bỏ WARNING/ERROR) vào `R3_addon_entrypoints_raw.log`, `R3_player_rig_editor_raw.log`; raw tổng thể R3 vẫn là nguồn gốc.

Evidence mới tách riêng `MINIDUMP_AUDIT_R3_0958.json`, `WINDOWS_EVENTS_R3_1000.json`, giữ audit đầu nguyên vẹn. Dump PID26212 SHA256`4970badc99b10477b83cf2e367e02dec48ede02a1e8c48172bab061c9375bcff`; PID14848 SHA256`4e46c578c5b40caa6d45b1919c3e9958aae11f392b93451ebbd4d1fb1792c113`.

Compile-only fixture cũng crash cùng cleanup path làm yếu giả thuyết chỉ cần giao chiến/rig GPU đang chạy mới xảy ra. Tuy vậy project vẫn nạp autoload và plugin resources; chưa có phép cô lập project rỗng để loại chúng. Không quy trách nhiệm cho wide-floor, NPC, mipmap, một addon cụ thể, hoặc engine thuần chỉ bằng cùng offset.

Đề xuất hữu hạn cho root sau khi R3 kết thúc: **một** tiến trình headless editor60frame, cùngEXE, project rỗng và user/cache root riêng ngoài checkout. Nếu cùng crash/stack tái hiện ở đó, bằng chứng sẽ mạnh hơn rằng không cần content/plugin của project. Nếu lượt rỗng sạch, chỉ xác nhận mẫu sạch; chưa loại lifetime/resource-trigger gián đoạn. Đây là đề xuất chưa chạy, phải có engine lane riêng.

Sau đó nếu root chọn một lượt full strict R4 trên source frozen, R4 là gate mới của checkpoint; không được đổi gate sang GameplayOnly hoặc bỏ exitcode. Một R4 sạch cũng không chứng minh crash đã sửa vì chưa có remediation. Nếu còn native failure, giữ bản thử/chặn merge theo gate đã thống nhất; không lặp không giới hạn để tìm một lượt xanh. Mọi kết quả R3/R4 và canary phải giữ riêng, không thay thế hoặc che các lượt bị crash.

Root đã duyệt chuẩn bị đúng một empty-project canary sauR3. Helper `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/crash_audit/empty_project_canary.ps1` đã viết lúc10:02UTC, kèm `empty_project/project.godot` chỉ có config_version và tên project. Helper ghim EXE hash, từ chối khi còn Godot process hoặc đã có LAUNCHED receipt hoặc đến11:00UTC; dùng APPDATA/LOCALAPPDATA/QA root mới riêng, không copy profile. Start-Process Hidden, headless editor60frame, timeout60giây, chỉ terminate Process object do chính helper tạo, lưu raw stdout/stderr/exit/diagnostics và hoàn lại biến môi trường của shell. Đây là chuẩn bị tĩnh: PowerShell parser0errors; **worker chưa thực thi helper/engine**. Root sẽ ghi kết quả khi giữ lane sauR3.

## Crash thứ ba trong R3 — audit10:09UTC

`enemy_art_120` in43checks/0fail, gồm teardown và stress objects4547→4546/resources541→541, rồi exit-1073741819. Windows Event1000 record406461 ghi10:05:03UTC, PID29212, cùngEXE/timestamp/fault547F2C. Dump`Godot_v4.7.2-stable_win64.exe.29212.dmp` còn nguyên4.70MB, SHA256`9b5da35711d8475ea2c0ca72142602a052c1977d9d51f46dcde0d1d04839cc46`.

Parser xác minh READ tại`0x22b61d79810`=R13+8, cùng7frameRVA đi qua cleanup như các lần trước, vẫn thiếu memory-info/symbols. Tổng13dump hiện có cùngsignature; không cộng checks đã in thành một gate PASS. Test stress không tăng Node/resource chỉ loại một biểu hiện tăng đếm trong mẫu, không chứng minh an toàn mọi pointer lúc engine shutdown.

Giữ audit cũ và thêm `MINIDUMP_AUDIT_R3_1009.json`, `WINDOWS_EVENTS_R3_ENEMY_1000.json`, `R3_enemy_art_120_raw.log` trong crash_audit. Raw gốc nằm `strict_candidate_r3/strict_raw.log` dòng926–974. Không chạy engine hay sửa source; R3 vẫn chưa kết thúc lúc đọc. Lỗi này không làm thay đổi kế hoạch hữu hạn canary/R4 hoặc cho phép bỏ native gate.

## Canary đã chạy một lượt

Root thực chạy helper duy nhất10:12:02–10:12:05UTC. Project rỗng, cùng hashEXE, headlesseditor60frame, profileQA mới riêng: exit0, khôngtimeout, diagnostics[]. Receipt tại `crash_audit/empty_project_canary_once_20261008/RUN_RESULT.json`. Không copy save hoặc tài nguyên game. Đây chỉ là một mẫu startup/shutdown sạch của project rỗng; không xác định rootcause, không phủ định lỗi trên project đầy đủ và không thay strict. Root chạy R4 cùng2185sourcehash củaR3 sau mẫu này.