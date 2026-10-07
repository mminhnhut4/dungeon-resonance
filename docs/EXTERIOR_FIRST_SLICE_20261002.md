# Ngoài trời — prototype đầu tiên, 2026-10-02

## Kết quả và cách xem

Main thực tại **D:/hầm ngục**, Godot **4.7.2.stable.official.ed1daf0bf**, renderer Compatibility, đã nối Căn Cứ Lữ Khách H00 với tám phòng O01 P01–P04 và O02 B01–B04. Đi toàn tuyến W và quay lại bằng A/D và E ở cửa; không cần nhảy/dash. Giữ một Player/GearSession/inventory/EconomySession xuyên tuyến ngoài trời. Cửa đi dungeon có sẵn vẫn riêng và chạy theo WorldCampaign cũ.

Trong editor dự án này, dùng **F5 main**, tới biển **ĐƯỜNG BỘ · BẾN TRẦM →** ở sân Hub, gần(750,640), bấmE. Dùng Space ở nhánh cao tùy chọn. Tại P03, E ở cơ cấu đường giữ đèn mở SC01; quay về cửa hầm và đi hành lang P02 thực tới P01. Hạnh ở B04 mở thoại; Space/E hiện hết/tiếp trang, chuột chọn “Ghi lại dấu mốc” hoặc “Để sau”, Esc/Tab/đóng thoại để hủy. Miếu và cột nước chỉ ghi vị trí địa lý. Dùng main để GameFlow sở hữu việc khởi tạo/hydrate UID; không dùng F6 scene Hub độc lập làm đường thử lưu tiến trình sản phẩm. `scenes/qa/exterior_traversal_lab.tscn` là fixture kỹ thuật riêng.

Đây là geometry/session/minimal story-hook prototype, không phải art hoàn thiện, campaign20h hay triển khai toàn bộ35case. Hạnh dùng silhouette vector trung tính vì chưa có portrait đã duyệt cho nhân vật này. B01 nhánh ụ thấp và B03 gác kho chưa dựng; các enemy optional ngoài trời chưa bật.

## Thiết kế đã chốt và tiêu chí thay thế

Người dùng chọn **phương án1 lúc2026-10-02 13:31UTC**: đường W dốc liên tục, landing, cầu, nhánh cao, shortcut; giữ motor và haiFSM. P04 có ba terrace cao độ thật theo tiến trình x liên tục. Ba hairpin phải/trái/phải xếp chồng của spec trước **SUPERSEDED, không PASS**. Không thêm cơ chế depth/lane, leo thang hay drop-through để ép hình cũ.

Lý do đo đạc: colliderB20/C36, floor_snap1. Các20biến thể fold mỗi60/120Hz không có biến thể đi bộ đủ cả hai chiều; khoảng hở48/58px cho chiều xuống ở một số mẫu nhưng không cho chiều ngược. Step control1/2px qua được,4px trở lên không. Đây là kết quả hữu hạn của hình dựng/motor hiện tại, không kết luận bất khả thi cho mọi engine hay mọi thiết kế. Khe0,3H dưới cầuP02 khoảng34,5px còn thấp hơnC36, nên SC01 được dựng thành **sector hành lang P02** qua cửa hầm bình thường P01/P03; người chơi phải đi bộ qua cổng và dốc trong sector, không chuyển thẳngP03→P01.

Tiêu chí tương đương được áp dụng cho hình mới:

| Tiêu chí cũ | Trạng thái cũ | Tiêu chí của phương án1 | Bằng chứng hiện tại |
|---|---|---|---|
| T07 ba switchback xếp chồng | SUPERSEDED | Ba terrace xuống bến đổi cao độ collider thật; W đi đủ hai chiều không jump/dash | PASS tuyến thực60/120Hz; GPU ba terrace |
| T08 nhảy tắt khúc cua | SUPERSEDED | Nhảy tùy chọn cắt đoạn dốc ngắn từz3,3H tới catchpadz3,05H rộng160px; mainW liên tục bên dưới | PASS camera tại takeoff và landings thực; không drop-through |
| T13 quay tại các hairpin | SUPERSEDED | Quay lại qua cả ba terrace mới và các bounds; nền/actor nhìn thấy trong camera hiện hành | W chiều ngược PASS, ảnh ba terrace đã xem; stress đổi hướng tại mọi điểm cùng modal chưa kiểm riêng |

Không dùng kết quả phương án1 để ghi PASS cho hình switchback literal cũ.

## Hình học và topology thực

Tám roomID là authored layout trong `ExteriorRouteCatalog`, dựng bằng cùng `ExteriorRoom`; không phải tám file.tscn độc lập. Mỗi phòng chỉ tải một lần ở origin(8000,0); cửa E chuyển tới anchor khô của phòng liền kề. Collider là solid strip dày70px với transform(1,1), không one-way; bounds có vách ở hai đầu. Optional shelf rộng110px/dày8px và có W bắt rơi bên dưới.

| Room | Cao độ W theoH115px | Rộngpx | Nội dung có trong prototype |
|---|---|---:|---|
| P01 |5→6,3→5,5|2420| Đèn nghiêng, bậc đá, J1 hai bệ, cửa hầm tây |
| P02 |5,5→6,2→4,3→4|3280| J2 hai bệ, cầu dây cố định, khe nước |
| P03 |4→5,1→4,1|2680| LeverSC01, miếu/mốc địa lý, cửa hầm đông |
| P04 |4,1→4,6→3,3→3,05→2,2→1,2→0,8|5000| Ba terrace, nhảy cắt dốc và catchpad |
| B01 |0,8→1,6→0,8|2060| Cột nước, hai dấu lũ, mốc khô/record |
| B02 |0,8→1,3→0,8|1940| Phố thấp dưới mặt nước cosmetic, quảng trường cao, mái nhà hai bệ |
| B03 |0,8→2,2→1→1|3380| Bưu trạm/record và hình kho |
| B04 |1→1,3→0,8|2280| Xưởng, Hạnh, record và hình cầu tàu |
| P02 guard_corridor |5→4|1840| GateSC01x640/cao130, dốc thực và hai cửa |

W: `H00 ↔ P01 ↔ P02 ↔ P03 ↔ P04 ↔ B01 ↔ B02 ↔ B03 ↔ B04`. Nhánh mởSC01: `P01 cửa hầm ↔ P02 guard_corridor ↔ P03 cửa hầm`. Gate vật lý đóng trước khi leverP03 được xác nhận, khi mở state được lưu bằngID. Không có nhánh teleport thẳng bỏ qua corridor.

## Đo motor và kiểm chứng

| Thông số |60Hz|120Hz|
|---|---:|---:|
| B/C colliderpx |20/36|20/36|
| H đứng/chạypx |115,058/115,010|117,562/117,507|
| Upx |229,338|232,012|
| Dgpx |141,667|141,666|
| Theta_walk candidate |15°|20°|
| Theta_safe dùng dựng |10°|10° dùng chung bảo thủ|
| Dash tick/quan sát |10/0,166667s|20/0,166667s|

Dash cấu hình0,16s/cooldown0,65s, camera zoom1,35; vùng nhìn khoảng948,148×533,333px. Floor_max_angle45° không được dùng thay phép đo ổn định. Ramp10° đã thử đi lên/xuống, thả input, nhảy và dash ở join; builder tăng chiều ngang theo `abs(lift)/tan(10°)+0,5`. Không sửa speed320, floor_snap1, collider, motor hoặcFSM.

Trace nhảy đã đo các đích0,+0,35/+0,45/+0,55/+0,65H và−0,35/−0,65/−1H. E(+0,45H) đứng bảo thủ còn158,24px edge gap; lấy75% còn118,68px. J1 tăng40,25px mỗi bệ, J2/mái46px; gaps110/70px. P04 giảm28,75px tới catchpad rộng160px, không có hố trênW. Headless lặp3lần trên mỗi7bước nhảy =21landings ở từngHz, kiểm cả góc chân/headroom của bệ đích trong camera tại điểm takeoff thật. Đây không thay thế biến thể hụt/thả input/đổi hướng thủ công của mọi case.

| Gate cuối | Kết quả | Evidence trongdocs/verification |
|---|---|---|
| Focused authored60/120Hz |149checks mỗiHz,0fail |`exterior_authored_60_r3.log`, `exterior_authored_120_r3.log`|
| Full strict actual project |6196checks,122PASS gates,117RESULT,0ERROR/WARNING/FAIL,exit0; validator156scripts/33scenes |`exterior_authored_full_strict_r1.log`|
| GPU authored actual main |146checks,0fail,25captures,exit0 |`exterior_authored_gpu_r1.log`, rawstdout/stderr và `exterior_*.png`|
| GPU legacy Hub/dungeon roundtrip |61checks,0fail,3captures,exit0 |`exterior_legacy_roundtrip_gpu_r1.log`, `travel_proof_*.png`|
| Hạnh full text/choices supplemental |2captures thực sau typewriter,exit0; chỉ scriptQA ngoài project |`exterior_hanh_review_capture.log`, `exterior_hanh_dialogue_revealed.png`, `exterior_hanh_dialogue_choices.png`|
| LAB riêng trước authored |58checks mỗi60/120Hz; GPU64checks/6captures |`exterior_labs_*_r2.log`, `exterior_lab_original_gpu_r2.log`|
| Loadbench dungeon hiện có60/120 |59,9903715/120,0028201FPS,passed=true |`world_render_60.json`, `world_render_120.json`, `exterior_world_loadbench_*.log`|

Strict giữ Movement55/Combat100 ở mỗiHz và Resolver20, import/editor/addon gate nguyên vẹn; không dùng GameplayOnly, không lọc warning. GPU authored dùng1repeat thay3repeat ở nhảy và thêm25capture checks, vì vậy số146 khác149. Hai ảnh Hạnh bổ sung làm rõ thoại đang hiện từng chữ trong ảnh đầu, không đổi mã game/gate đã kiểm. Pixel đã xem: landmarksP01/P02/P03/B01–B04, ba terraceP04, bốn ảnh nhánh cao,SC01đóng/mở, ba legacy travel và hai trang thoại Hạnh đủ chữ. Không coi việc chỉ tạoPNG là đã đọc toàn bộ mọi ảnh.

Benchmark RTX5080/Compatibility tại1152×648,2s warmup/6s sample, physics60/120Hz; p95frame gồm capwait17,776/9,276ms, peakphysics3,034/2,841ms. Tải fixture dungeon gồm guard/bat/wraith/champion/Slime AI,10fan/wavecasts/s,20impact/s,10loot/s, light/particle/audio hữu hạn. HP được giữ, spell damage0,1 và hitstop tắt, Master mute chỉ ở fixture. Đây là regression throughput dungeon cũ, chưa phải benchmark toàn tuyến ngoài trời hay bảo đảm mọi frame/cảrun/mọi máy.

Walking input time60/120Hz: toàn lượt ngoài66,6/66,4s; đoạn mainP01→P03 16,65/16,5833s; corridorSC01 5,1667/5,1417s. GPU ghi66,7667/16,6833/5,1667s. Đó là tổng ticks đang chạyA/D của automation, không phải wall time người chơi, nhịp thoại/khám phá hay mục tiêu90–150phút. Chưa có subjective playtest.

## Session, lưu tiến trình và giới hạn

`ExteriorHub : PrologueHub` thêm road, rooms, camera bounds và hooks. Tạo target/anchor hợp lệ trước, save geography trước khi thay thế room; lỗi target hoặc atomic file replacement giữ actor/vị trí/geography cũ. E cần gần marker, grounded và guard modal/Hurt; giữE không bounce cửa mới. Chặn travel khi inventory/shop/dialogue đang sở hữu modal. Room-owned entities/feedback/audio/time claims dọn trước khi đổi phòng.

Không thay player controller/motor/FSM/rig, DamageEvent authority, immutable definitions hoặc EconomySession. Cùng actor giữ HP37/energy41 trong fixture, UID list, coins700 và carried13, committed dash/air-charge/recipe/grace clocks qua relocation; ticks grounded tiếp sau được phép hồi air-charge theo luật motor cũ. Đi cửa không tự mở expedition D01, bank escrow hay starter award. D01 vẫn bốn stageWorldCampaign hiện có; **chưa chia D01 thành8phòng** và không mở service lane/companion bypass boss.

Profile global vẫn `version:1`. Extension `exterior_progress.version:1` chứa room/region/route/anchor, discovered_rooms, notes vàsc01_open; không chứa HP/energy/item ledger. Legacy absent default chưa khám phá/cổng đóng, nếu không dùng thì extension vẫn absent. IDs/list size/duplicates được kiểm; malformed geography quarantine riêng khỏi current safeUIDledger; future extension version cao hơn bị chặn load/save/overwrite. Same-session profileload+restore giữ actor/HP/clocks/UID. Cold process dùng GameFlow startup hiện có rồi khôi phục geography; không tuyên bố coldload giữ HP/clocks transient. Cold startup ngoài trời cần người dùng đánh giá thêm như một flow sản phẩm.

Ngoài trời kế thừa SafeHub minimum_health1/body-condition-disabled, không có enemy/hazard phase này; nước chỉ trình diễn, không swimming/movingfloor/damage. Fallback khi vượt bounds đặt vềlastvalidanchor cùng actor, không heal. Đây chưa phải triển khai luật chết overworld/respawn mới. Miếu/cột nước và lever không refill/bank. Dialogue xác nhận mới ghi note, hủy không commit; duplicate note/lever không save reward lặp. Notes không cấp companion/quan hệ/chìa khóa/quest reward hay kết luận nguyên nhân lũ từ thông tin chưa đủ.

## Ledger35case — tách phạm vi đã kiểm khỏi phần chưa chạy

PASS chỉ áp dụng phạm vi ghi ở cộtEvidence. NOT RUN nghĩa chưa hoàn thành toàn tiêu chí của case, kể cả có phần đã được test. Không có thông cáo35/35.

| Case | Status | Evidence/phần còn thiếu |
|---|---|---|
| T01 |PASS| Đo B/C/H/U/E/Dg ở60/120Hz, clocks và motor hash giữ nguyên |
| T02 |PASS cho10°| Ramp probe lên/xuống/idle/jump/dash ở join60/120Hz; không suy từ floor_max_angle |
| T03 |NOT RUN toàn case|21 landings/Hz ở7 bước nhảy tùy chọn; chưa thử đủ thả/giữ input và đổi hướng ở từng bước |
| T04 |PASS phạm vi nhánh hiện có| Bệ/headroom nhìn thấy và actual jump; không dựng hidden ceiling/one-way |
| T05 |PASS| Actual main H00→8 rooms và W quay lại bằng A/D/E, không jump/dash |
| T06 |NOT RUN toàn case| J1/J2 actual jumps và catch floor; chưa fault-inject hụt từng gap riêng |
| T07 |SUPERSEDED| Hình hairpin literal không PASS; equivalent3 terraces W đủ hai chiều PASS |
| T08 |SUPERSEDED| Equivalent optional P04 cut/catchpad/camera landing PASS; chưa test riêng mọi kiểu hụt |
| T09 |NOT RUN| D01 service/companion lane mới không triển khai; legacy dungeon gates giữ nguyên |
| T10 |NOT RUN toàn case| Measured ramp probe kiểm representative joins; chưa dash hai hướng ở mọi join authored |
| T11 |NOT RUN| Optional one-way không bật; W không phụ thuộc |
| T12 |PASS phạm vi7 takeoffs| Actual camera landing/headroom assert ở7 bước tùy chọn; W không có jump bắt buộc |
| T13 |SUPERSEDED| W ngược/capture terrace mới đã kiểm; modal/camera stress tại mọi điểm quay NOT RUN |
| T14 |PASS phạm vi hiện có| Actual E road/room doors/held latch và legacy TravelClocks; chưa scripted dash-grazing mọi trigger |
| T15 |PASS injected paths| Reject target và lỗi atomic replace trước commit giữ room/actor/state; không half-travel |
| T16 |PASS phạm vi inventory/dialogue| Inventory chặn travel; confirm/cancel Hạnh trả controls/time claims; toàn bộ service permutations NOT RUN |
| T17 |NOT RUN| Death overworld chưa đổi; same-session dry-anchor load PASS, chết trước/sau cửa chưa kiểm |
| T18 |PASS phạm vi ngoài trời| Backtracking/travel dọn room/camera bounds và time claims; outside không có boss music |
| T19 |PASS| Closed collider chặn; leverP03 mở; đi corridor hai hướng; corridor5,16s so main16,65s; không bank |
| T20 |PASS phạm viQA| Save/load SC/notes; rebuild room từ profile; legacy defaults gate closed; restore QA older-save riêng chưa kiểm đầy đủ |
| T21 |NOT RUN trường hợp mới| Legacy boss/proof strict giữ pass; chưa ghé exterior trong chuỗi save/load reward theo case |
| T22 |PASS phần ngoài trời| H00/O01/O02 không mở DungeonRun/expedition; legacy WorldCampaign không sửa, D01 eight rooms NOT RUN |
| T23 |PASS| Shrine anchor/lever không heal/refill/bank; water dry-anchor geometry/GPU; không rest reward |
| T24 |NOT RUN kết nối recordD01| Falsewall/firebarrier gate cũ hồi quy; note outside chỉ minimal record |
| T25 |NOT RUN D01_06/08| HaiID mới chưa có; old dungeon combat strict/GPU/loadbench giữ pass |
| T26 |NOT RUN| Optional overworld combat không bật |
| T27 |PASS giới hạn| Hạnh begin/cancel/confirm; prompts/landmarks trên nền khô; đọc/hủy toàn bộ4 notes chưa test riêng |
| T28 |PASS geometry/render| B02 low street nằm dưới cosmetic water; W/anchors khô; không bơi/nền nổi/hazard |
| T29 |PATH VALIDATED / AI NOT RUN| Actor đã đi W hai hướng, World-only mask1/layer2; chưa spawn companion proxy hay persistent-ID AI |
| T30 |NOT RUN| NPC schedule/offscreen reify không triển khai |
| T31 |NOT RUN| Kill/spare/downed/permanent death chưa có |
| T32 |NOT RUN| Hạnh permadeath/evidence fallback chưa có; record hook không thay hệ đó |
| T33 |NOT RUN| Incursion/evacuation chưa bật |
| T34 |NOT RUN| Social gate/compensation chưa bật |
| T35 |NOT RUN| Chỉ đo automated walking ticks; chưa human playtest/thời lượng/encounter/rơi lạc |

## Bảo toàn nguồn, QA và lỗi native đã biết

Bốn đầu vào đã nhận thủ công, kiểm SHA256, đọc đủUTF8 và xemPNG trước triển khai: `Graybox_dia_hinh_tuyen_dau.txt`38616bytes; `Graybox_test_cases.txt`9088bytes; `Dungeon_Resonance_truyen_va_the_gioi.txt`181737bytes; PNG1900×1400/207414bytes, SHA256`616C3E79EB3F481F4BDB5A3897570772C71BE3F335217564C2F4EAC34364CE4C`. Browser đặt tênPNG“Ảnh ChatGPT 19_17_26 2 thg10,2026.png”; canonicalcopy`So_do_graybox_tuyen_dau.png`. Manifest4records tạiworkspace `exterior_inputs_manual_20261002/manifest.json`; không cần thêmLibrary/connectiondiagnostics.

Backup trước map tại `C:/Users/Admin/Documents/Codex/2026-10-02/task/exterior_baseline_20261002_1218`:511files/all scripts-scenes-data/project/AGENTS/selecteddocs, manifestSHA256 và runner gốc riêng. Save thật `.json` và`.bak` được backup; cảhai2819bytes/SHA256`003000B0D925417D31F4F7C45D1903C762C6F946FF3A8E0EFBF1DCFFB40A1F23`. QA dùng process-localAPPDATA riêng; Godotuser_data_dir đã probe nằm trongworkspace trước khi chạy fullsuite. Profile thật không dùng làmQAfixture.

Thay đổi source cũ chỉ `sanctuary_profile.gd` và mainsceneext_resource; runner thêm LAB/ExteriorRoute ở60/120Hz; docsPROJECT_STATE/DECISIONS/PROJECT_ARCHITECTURE cập nhật. Source mới:4ExteriorGDs+3LABGDs/UIDs,2scene wrappers,2tests/UIDs. Audit cuối kèmcheckpoint đối chiếu baseline, source mới, corehash, profile thật vàeditorPID16728. Không sửaAGENTS/.codex/memory, addons, engine/version/settings.

**Known limitation: native editor rig teardown chưa được chữa.** LAB-era fullstrictR2 và exactretry đềuexit−1073741819 (`0xC0000005`), Windowsfaultoffset`0x547F2C`. Exactargv:

```text
D:\dowload\Godot_v4.7.2-stable_win64_console.exe --headless --path "D:\hầm ngục" --editor res://scenes/actors/player_visual_rig.tscn --quit-after 60 --verbose
```

R2APPDATA `task/qa_exterior_strict_20261002_r2/AppData`, retryAPPDATA `task/qa_exterior_strict_20261002_r3/AppData`. Logs dừng sau rigload/addonunload/“EditorSettings: Save OK!”; không SCRIPTERROR/WARNING/native stack. WindowsEvents ngày2026-10-02 lúc20:02:05,702142+07 và20:10:15,8625859+07; scanCrashDumps trảfound[]. Giữ `exterior_original_full_strict_r2.log`, `exterior_player_rig_editor_retry.log`, `exterior_native_crash_events.json`, `exterior_native_dump_metadata.json`. Editor tương tácPID16728 khác cácQAprocess này và được giữ mở. LượtLABstrictR3 và authoredstrict cuối qua hết không chứng minh lỗi gián đoạn đã hết. Chưa có gameplayfailure do lỗi này; chưa đủ bằng chứng kết luận chỉrig hoặc driverRTX lànguyênnhân. Không đổi engine/settings/cài debugger để kết thúc lát cắt.

## Việc tiếp theo an toàn

Người dùng chơi F5 tuyến mới, đánh giá độ dài/hướng đi/P04/SC01 và cảm giác camera; ghi T35 bằng thời gian thực. Sau đó ưu tiên các biến thể còn thiếu T03/T06/T10/T13/T14/T17 và flow coldload. Chỉ triển khai D01 phân phòng/service lane, NPC sim/companion/permadeath, art Hạnh hoặc enemy ngoài trời khi có phạm vi tiếp theo được giao. Giữ backlog tách khỏi kết quả prototype đã hoàn tất này.
