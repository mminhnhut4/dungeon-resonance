# Tiếp tục connector và map tông môn — 08/10/2026

Gói connector và map tông môn đã qua nghiệm thu trong checkout riêng `sect-path-repair`; ghép bản chính theo manifest có kiểm hash ở cuối báo cáo. Người dùng đã yêu cầu tiếp tục sau mốc 18:00, bao gồm map tông môn. Không bắt đầu lại gói core FPS đã ghép. Root là người ghép duy nhất, không gọi thêm agent; engine QA chạy tuần tự, profile QA độc lập.

## Những phần đã nối trong bản thử

- Tuyến hầm ngục opening → Golem → năm ải sâu dùng tầng hiển thị **4–8**, cùng Player/GearSession/UID/HP/mana/hồi chiêu; giữ namespace và ID Depth nội bộ 1–5. Lạc Ấn vẫn cho chọn tầng đã vượt. Boss tầng 8 không cấp lại chứng tích Golem. Về sớm sau khi đã vượt Golem ghi đúng mốc quay về; lối tắt không giả lập chiến thắng opening.
- HUD boss và tên vũ khí nằm trong cửa sổ 800×600; hướng dẫn Depth được thu gọn ở góc, chiến thuật vẫn có tooltip. Nhãn `Xuống tầng 1` ở hai lượt kiểm60/120 cũ đã đổi sang số hiển thị tầng 4; không bỏ assertion lưu/UID/ownership.
- Bốn phòng **thực sự đi vào được** qua cửa của `ExteriorHub`, dùng cùng actor/session. Đường chính đi bộ được hai chiều, không yêu cầu mở movement mới. Map/quest journal có 13 nút vị trí, ẩn tên nơi chưa khám phá, các nút không chồng nhau ở 800/1280. Sơ đồ chỉ chỉ đường, không dịch chuyển nhanh.

| Nhánh | Điểm vào | Phòng và chiều dài mặt đường | Khung cảnh |
|---|---|---|---|
| Thanh Vân | P03, sổ ở phía tây cửa môn phái, tách cửa SC01/miếu | Vân Quan 2.600 px → Tùng Đình 2.900 px | Đá nhạt, thông, mây, cầu treo; sân học có cổ thụ và thư các |
| Xích Lô | B04, sổ gần cửa phía tây xưởng Hạnh | Đê Đất Đỏ 2.800 px → Sân Dẫn Thủy 3.200 px | Đá đỏ, kênh làm nguội, đồng và mái gốm; thủy luân và bể nước, tách lò ngầm tầng 7 |

Bốn ảnh nền PNG render mới, có mipmaps, được bind vào phòng đang chơi; không dùng ảnh để tạo collision. Terrain dùng vật liệu sẵn có, không đổi motor. Camera giới hạn theo chiều cao địa hình mới để tránh phóng ảnh theo toàn vùng trống cũ. [Prompt nguyên văn và SHA256](SECT_MAP_ART_PROMPTS_20261008.md).

Hai chấp sự có stable ID mới: **Phùng Yên Trúc** (`thanh_van_steward_01`) và **Tống Hồng Diệp** (`xich_lo_steward_01`). Họ dùng đồng phục và cơ chế combat Thanh Vân/Xích Lô đã có: tuần tra, tự vệ sau sát thương được xác nhận, báo đòn/ra đòn/hồi phục/trúng đòn và rút lui. Đây chưa phải hai bộ sprite animation mới. Không đổi cá nhân bị đánh thành cả môn phái lập tức biết chuyện.

## Cách chơi nhiệm vụ môn phái

1. Đi theo đường bộ tới P03 hoặc B04. Đứng gần **Sổ tiếp nhận môn phái**, nhấn **E**, đọc tới lựa chọn **Nhận việc**. Lối vào khuôn viên của phái đó mới mở.
2. Vào cửa môn phái. Đi tới hai mốc có đèn phía tây/đông, nhấn **E** và chọn **Ghi quan sát**. Đứng gần hoặc đọc rồi chọn Để sau chưa tính đã ghi.
3. Mở **M**, chọn **Đường phải còn người về** hoặc **Giữ dòng nước thông** để đọc địa điểm, điều kiện, số mốc và phần thưởng. Theo dõi nhiệm vụ sẽ chỉ mũi tên tới mốc còn thiếu, rồi tới sổ nộp.
4. Trở lại sổ bên cạnh chấp sự trong khuôn viên, chọn **Trình hai ghi chép**. Cửa đông mở sân trong; cửa tây đưa về nhánh đường bộ cũ. Nếu chấp sự đang dưỡng thương, sổ vẫn nhận nhiệm vụ.

Phần thưởng hiện tại là **quyền khách tham quan sân trong**, không có tiền/đồ hoặc phí mới. Quyền khách không phải gia nhập môn phái, học công pháp hay làm chưởng môn. Hai bản ghi là quan sát địa hình, chưa phải bằng chứng buộc tội một phái.

## Lưu và nhân quả

`sect_journey_v1` là một namespace hữu hạn trong extension transaction owner hiện có: mỗi phái có nhận việc, mốc tây, mốc đông, quyền khách. Tám sự kiện tối đa, lặp lại không thêm receipt. Lỗi writer giữ nguyên bytes/tiến độ, có thể thử lại tại cùng sổ. Geography giữ version 1 và thêm bốn room ID; không đổi nghĩa tám đường cũ hoặc SC01.

NPC sidecar nâng **schema 3 → 4**, từ tám lên mười actor. Mọi dữ liệu tám NPC cũ được giữ; chỉ hai chấp sự có default mới. Trước khi ghi tạo bản bất biến `.npc_v1.json.pre_sect_v3.json`. Bản sao khác bytes, lỗi copy/replace, schema tương lai hoặc records thiếu đều khóa chỉ đọc, không tự dựng lại dân cư. NPC vẫn trọng thương/rút lui, không chết vĩnh viễn; đi bộ, đổi phòng và tải lại không chữa lành. Hồi phục qua owner kết thúc/quay về chuyến hầm ngục và giữ ký ức gây hấn.

Giới hạn giao dịch hai owner từ core vẫn còn: nếu profile đã bank mà NPC sidecar ghi thất bại, retry trong phiên giữ chuyến; đóng game đúng lúc ấy có thể khiến NPC chờ chuyến sau. Chưa có giao dịch atomic xuyên hai file hoặc marker recovery bền mới.

## Bằng chứng đã thực chạy trước full gate

| Kiểm tra | Kết quả đã có | Phạm vi |
|---|---|---|
| Connector responsive native R2 | 49/49, 9 ảnh, exit 0 | Cổng/tầng 4–8, HUD 800/1280; setup có fixture |
| Sect routes native R2 | 276/276, 10 ảnh, exit 0 | E nhận/ghi/nộp, lỗi ghi+retry, đi bộ qua bốn map và quay về, UI/mũi tên, lưu/tải; kiểm nút sơ đồ chiếm phần lớn assertion |
| Sect routes headless cuối | 276/276 ở 120 Hz | Cùng flow product, fixed-fps; không là số FPS |
| Cultivator patrol native | 114/114, 12 ảnh, exit 0 | Bốn tu sĩ gồm hai chấp sự: Player melee thật → tự vệ → Hitbox gây sát thương; hủy đòn, pause và rút lui |
| Sect NPC migration | 39/39 ở 120 Hz | Backup byte-identical, giữ tám record, lỗi copy/replace, future/corrupt, hồi phục và ký ức |
| MapQuest hồi quy | 219/219 ở 120 Hz | Map 13 vị trí, ẩn danh nơi chưa biết, modal/input/save |
| Nonlethal hồi quy | 137/137 ở 120 Hz | Luật rút lui và chuyển schema cũ vẫn giữ |
| Native render từng map | 17/17, 1.204 frame lấy mẫu | Đo wall clock, không dùng fixed-fps; không là trận đông quái |

Render trên RTX 5080, Compatibility, 1280×720, cap 120 FPS, làm ấm 60 physics frame rồi lấy 2,5 giây mỗi map: p99 **8,734–8,859 ms**, max **8,920 ms**, 0 frame >50 ms trong mẫu, 65–72 draw calls tối đa. **Chuyển map đồng bộ 56,6–104,4 ms** chưa được tối ưu; số đo entry gồm cả phần dựng/lưu, chưa tách nguyên nhân bên trong. Không dùng mẫu đứng tại chỗ này để tuyên bố combat dungeon hết lag.

Root đã xem ảnh runtime của đủ bốn map, nhiệm vụ, sơ đồ 800 và đòn chấp sự. Art, logic và capture không thay thế chơi tự nhiên dài, âm thanh hoặc cân bằng. Vòng đường bộ test dùng relocation chỉ để tới P03/B04 ban đầu; đường trong phái thực sự dùng input đi bộ và E. Mẫu hiệu năng dùng seed quyền qua owner, ghi rõ trong JSON.

### Lỗi tìm thấy và sửa trong lần tiếp tục

- Full gate connector trước map: **266 PASS, 3 FAIL**, source không đổi. Hai FAIL do fixture `depth_quest` còn kỳ vọng số hiển thị 1; đã sửa thành 4. Một `enemy_art_120` thoát native `0xC0000005`; chưa xác minh nguyên nhân, không gọi là đã sửa.
- Sơ đồ bốn hàng với nút hai dòng chồng nhau ở layout nhỏ. Chuyển nhãn nút thành một dòng, giữ đầy đủ tên trong tooltip, địa điểm và phần mô tả; kiểm bounds và mọi cặp nút đã đạt.
- Fixture schema tương lai cũ hard-code 4 đã trở thành schema hiện hành; đổi thành `SCHEMA + 1`, giữ kiểm không ghi đè authority hỏng.
- Test backup xung đột ban đầu so cây JSON với dữ liệu runtime có scalar typed; đã chuyển sang so nguyên bytes trước/sau đúng mục tiêu bảo toàn file. Không thay logic migration để làm qua test.

## Chưa hoàn thành

Nhân chứng/báo tin và truy nã cả phái; thuê một đệ tử/một chuyến trả Linh Thạch trước, không chia loot; nghi thức gia nhập, giáo tập, tâm pháp/võ công riêng, khiêu chiến và kế nhiệm chưởng môn; hai phòng võ đài `tv03`/`xl03`; animation raster riêng cho chấp sự và props tiếp nhận đẹp hơn. Nội dung/luật đã lưu ở [roadmap](SECT_STORY_ROADMAP_20261008.md) và [thiết kế nhân quả](SECT_CAUSALITY_DESIGN_20261008.md). Chưa có bằng chứng để gọi toàn bộ hệ tông môn là hoàn thiện.

Ưu tiên sau nghiệm thu: người chơi thử nhịp đi–đọc–nộp và combat hầm ngục trên save của mình; sau đó triển khai witness/incident ledger hữu hạn trước truy nã/thuê người/kế nhiệm. Giữ tự vệ trước người truy sát không tăng truy nã; đánh tiếp người rút lui là sự kiện mới khi hệ đó được triển khai.

## Full gate, ghép và hoàn tác

Default strict cuối **273/273 PASS**, exit0, không ERROR/WARNING; 11:44:13–12:01:47UTC. **2.217 file nguồn giữ nguyên hash**, không có khác biệt trước/sau. Gồm import/editor/addon và mọi suite60/120; Movement55, Combat100, Resolver20 giữ nguyên. Sect routes276, migration39, cultivator patrol114, art175 ở cảhai mức. Lượt enemy_art120 sạch lần này không chứng minh nativecleanupcrash lịch sử đã được sửa.

Bản sao bảy file save hiện dùng mở qua product/cold-reader: **136/136**, giữ inventory/UID/số dư/tiến độ/nhân quả; tạo backup NPCv3 chỉ trên QA. Lượt đầu134check có8FAIL vì fixture đòi vị trí/remaining sau startup giống trước khi4Hz AI chạy; so raw chỉ ra đúng1tick. Verifier cuối dựng expected migration + số tick đã quan sát rồi so đầy đủ record, không bỏ các trường động hoặc sửa runtime. Cảhai lượt giữ nguyên7hash save thật.

Manifest nguồn tại `C:/Users/Admin/Documents/Codex/2026-10-08/sect_resume_1801/handoff/MANIFEST.json`; bản trước ghép ở `source_before/`. Chỉ60target runtime/assets/tests có thay đổi thực; bỏ44khác biệt BOM/xuống dòng, giữ file khác. Thêm10tài liệu theo preimage mới nhất của main `daaa943`. Rollback guard đã diễn tập60target: ghép đủ, ghép dở, và gặp hash lạ đều đúng; gặp hash lạ từ chối trước mọi mutation. Hoàn tác bằng `rollback_guarded.ps1 -ManifestPath <MANIFEST.json>`; không sửa save. Code cũ không hiểu NPCschema4/roomIDmới: giữ save đang chơi và backup `.pre_sect_v3.json`, không chép profile cũ đè tiến độ.

Hậu kiểm bản chính và commit sẽ được ghi tiếp sau khi thực chạy. Biên bản máy nằm tại `handoff/APPLY_RESULT.json` và `handoff/FINAL_RESULT.json`.

Raw evidence: `C:/Users/Admin/Documents/Codex/2026-10-08/sect_resume_1801/`. Full strict: `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/strict_sect_connected_final_r1/`. Save thật đã sao chép cả bảy file hiện có sang QA qua kiểm hash; chưa chạy trên save thật. Mọi hoàn tác source phải giữ save mới và xem backup NPC v3 riêng, không tự chép profile cũ đè tiến độ.

Evidence chọn lọc trong project: `docs/verification/sect_maps_20261008/`; vẫn giữ toàn bộ raw/failure ngoài checkout. Evidence không được Godot import và không tính như asset gameplay.

## Hậu kiểm và chốt bản chính

**Đã ghép runtime/assets/tests vào main `525355df759e0cf973419d8379545367a9de1557`.** Gói70target gồm60nguồn và10tài liệu, đều có preimage/hash guard; nguồn của2.217file so với strict không có khác biệt ngữ nghĩa, chỉ44file cũ khác BOM/xuống dòng được giữ nguyên. Private giữ checkpoint/ảnh/thử nghiệm để đối chiếu; không còn tính năng runtime đã nghiệm thu của gói này chỉ nằm ở private. Các hệ tông môn lớn còn lại vẫn là roadmap, không có bản chơi hoàn chỉnh bị giấu trong nhánh thử.

- **Import main lần đầu FAIL**: scan/import/layout đã chạy xong rồi thoát `0xC0000005`; Windows Application Error1000 ghi offset `0x547F2C`, trùng chữ ký lịch sử. Không sửa cache/editor của người dùng, không lọc exit. Một lượt import kiểm lại sau đó exit0/diagnostics[]. Chưa biết nguyên nhân gốc, không tuyên bố đã chữa crash.
- Validator main **234script/37scene, 0 lỗi**; numeric seal **64/64**.
- Bản sao mới của cả7file save đang dùng: **136/136**, product và cold reader giữ UID/số dư/tiến độ/nhân quả. Chỉ QA tạo `.pre_sect_v3.json`; save thật không bị QA migrate. Verifier so đầy đủ state sau đúng số tick tuần tra quan sát được.
- Native main tông môn **276/276, 10PNG**, exit0/diagnostics[]: đi bốn map, E nhận/ghi/nộp, lỗi lưu+retry, chấp sự dưỡng thương không chặn nhiệm vụ, hai chiều cửa, cùngactor/UID và coldrestore.
- Native main connector **49/49, 9PNG**, exit0/diagnostics[]: chuột qua Golem→4→5→6→7→8→trở về, HUDboss800 nằm trongviewport. Setup chuyển stage/sát thương có fixture, không là chơi tự nhiên cảrun.
- Root xem lại ảnh main TùngĐình, quest800 và boss800; phần render khác đối chiếu ảnh native private cùngnguồn. Kiểm nhỏ riêng800 cho nhãn hai khu tông môn không đè nút hành trang/bản đồ. Tooltip/mũi tên dùng nhịp UI hiện có; chưa đo trải nghiệm đọc tự nhiên.

**Giới hạn còn lại:** entrymap56–104ms; combatcore trước đó còn đỉnh khoảng32,5ms trong mẫu đã đo, chưa cam kết hết lag mọi trận. Nativecleanupcrash nói trên vẫn chưa sửa. Các pose chấp sự dùng ảnh đồng phục cũ, chưa có atlasanimation riêng; prop sổ/cổng cần polish. Nhân chứng/truy nã, đồng hành, tâmpháp và khiêu chiến/chưởngmôn chưa triển khai. Cần người dùng chơi tự nhiên để đánh giá nhịp khám phá, độ rõ của mục tiêu và cảm giác đánh; không lấy PNG hoặc logic PASS làm chứng nhận hoàn thiện trải nghiệm.

Lệnh thực chạy: wrapper `run_strict_candidate.ps1 -Label strict_sect_connected_final_r1` gọi default `tests/run_tests.ps1 -QaDataRoot <isolated> -CollectAllFailures`; các probe dùng `run_probe.ps1 -Project <private/main> -Script <test>`, `--hz=60/120` và `--fixed-fps` chỉ cho logic/đường đi, `--native-approved` cho renderer. `sect_render_probe` dùng wallclock khôngfixed-fps. Snapshot save qua `run_existing_save_copy_post.ps1 -ExpectedFiles 7 -Run`, không chạy game với userdata thật.

Rawfailure và Windows event ở task `main_import/`; kết quả mới ở `main_import_retry`, `main_validate`, `main_numeric`, `main_real_save_copy_smoke`, `main_sect_native`, `main_connected_native`. Backup/rollback và SHA cuối ở `handoff/FINAL_RESULT.json`; mọi script chỉ nhắm file đã ghi trongmanifest. Không publish, không cài phần mềm, không đổi bảo mật/quyền truy cập.
