# Backlog khởi động nhóm

Snapshot2026-10-08. **Owner chưa phân công**; điền username sau khi nhóm nhận việc. Các task dưới là việc tiếp theo, không ghi đè mốc đã ghép ngàyOct7.

| ID | Ưu tiên / trạng thái | Task cụ thể | Acceptance / phụ thuộc |
|---|---|---|---|
| DR-001 | P0 / Todo | Đo khựng còn lại khi mastery/save trong trận thật | A/B cùng seed/engine/scene; p95/p99/max và mẫu hitstop; xác minh bottleneck trước sửa, giữ durability/seal/rollback |
| DR-002 | P0 / Todo | Sửa map/quest cards ở800×600 | Tái hiện baseline trước; nút/scroll/focus đọc được,1280×720 không hồi quy; giữ input/reward |
| DR-003 | P0 / Todo | Điều tra native crash lịch sử nếu tái hiện | Source/engine exact, exit/crash/log và ablation; không gắn nhãn đã fix từ gate sạch đơn lẻ |
| DR-004 | P0 / Todo | Sửa fixture nguồn hit rồi tiếp tục strict | Lượt đóng gói Oct8 dừng campaign_60:31 assertions/exit0 nhưng ERROR ObjectDB. SurvivalTestBase dùng source_id987654 giả, EnemyHitAggro gọi instance_from_id. Fixture cần nguồn sống đúng contract; giữ runtime và không lọc ERROR. Các gate sau chưa chạy. Xem PACKAGING_VERIFICATION.json |
| DR-005 | P0 / Todo | Playtest opening tự nhiên, fresh save | Không warp/clear/directgrant; đánh Slime, ghép bùa, boss/retreat, rèn/cất, load lại; timed notes và lỗi thực |
| DR-006 | P1 / Todo | Native readability5bùa+10 cặp trong trận | Kiểm hướng/windup/active/contact/recovery, blocked/miss và boss;10 cặp logic cũ không thay native proof |
| DR-007 | P1 / Todo | Audit animation quái/NPC hiện hữu | Bảngstate/asset/binding/clock; ưu tiên silhouette fallback đang có; không thêm archetype mới |
| DR-008 | P1 / Todo | Polish art tuyến ngoại cảnh hiện có | P01 pack đang bind; các phòng khác prototype. Art-only giữ collider/transform, ray grounding/occlusion và voice/light budget |
| DR-009 | P1 / Todo | Đo và phân biệt3buildgear+bùa | Nhận kit từ UI/quest thật, cùng encounter; clear time/cast/dash/energy/damage nhận, không tự chốt balance |
| DR-010 | P2 / Design | Chọn một slice tu luyện/NPC/reward còn thiếu | Đối chiếu code/state trước viết; brief được duyệt, có ownership/save contract; phụ thuộcM1/M3 |

## Mẫu cập nhật khi nhận task

`DR-xxx | owner:@username | branch:fix/dr-xxx-slug | files:... | status:Doing | base:<commit> | GPU:<khung giờ nếu cần>`

Trạng thái: Todo → Doing → Review → Verified private → Merged main. Blocked ghi điều kiện cụ thể. `Verified private` cần log/exit/ảnh khi liên quan; `Merged main` cần commit main và hậu kiểm. Không cộng dồn113/268checks cũ để cho task mới PASS.

## Owner và candidate tiếp tục08/10 — chưa ghép

Owner: Codex root/integrator duy nhất; private DgContinue_20261008, base main fe4017e. DR-001 đã đo A/B và loại thử writer không cải thiện; cold-cast prewarm private đã kiểm, mastery/save còn Todo. DR-002 Verified private UI800/native. DR-004 Verified private fixture live-source, default strict đang chạy. DR-006 Verified private10cặp native, wall-contact recipe còn thiếu. DR-008 Verified private background/terrain routes; props/NPC legacy còn prototype. DR-005 và DR-009 giữ Todo cần người chơi thử tự nhiên. DR-003 vẫn chưa rõ native teardown; retry sạch không là fix. Phạm vi được người dùng mở mới: năm tầng/roster khác/boss2phase/NPC Lạc Ấn, private native+focused đã có receipt; chưa Merged main. Xem ../CONTINUATION_20261008.md.

**Root checkpoint 01:43 UTC:** candidate B default strict241/241 sạch,2.193source freeze; root sole integrator chuẩn bị backup/exact-target apply và hậu kiểm main. Không coi focused PNG/logic là playtest tự nhiên.

**Root chốt 01:47 UTC:** đã ghép216exact-target sau strictB241/241; main import/numeric64/native82-17ảnh sạch, backup/hashrollback/save5nguyênbyte. Root soleintegration kết thúc, các agent không chạyGPU. Masterysave peaks/nativecrash chưa rõ/cân bằng tự nhiên còn cần playtest; không mở việc mới.

## 2026-10-08 — Kẹt WestStair và hướng tông môn

DR-011 | owner:Codex root | private:sect-path-repair | base:f626fd9 | files:DungeonRoom, regression và docs | status:Doing | GPU:root only sau khi game người dùng đóng. Agent stuck_audit/sect_research/sect_reference read-only. Root là integrator duy nhất, backup/preimage trước ghép; saveQA riêng.

User chốt: danh tiếng cả môn phái qua nhân chứng/báo tin/bằng chứng; mọi NPC chỉ trọng thương/rút lui, không chết vĩnh viễn. Triển khai NPC mới cần giữ owner nhân quả/save và bảo vệ vòng nhiệm vụ. Chi tiết/câu hỏi chưa chốt ghi trong tài liệu nghiên cứu của phiên.

### Ownership cập nhật sau khi user chốt bốn luật — 08/10/2026
- Root: integrator duy nhất; GameFlow, ExteriorHub, tests/npc_expedition_recovery_test.gd, research doc, state/decisions/backlog/journal, runner registration/strict. Main và save thật chưa sửa; user vẫn chơi, chỉ QA headless ở nền.
- stuck_audit: scripts/rooms/dungeon_room.gd; tests/world/dungeon/dungeon_corner_escape_test.gd; docs/DUNGEON_CORNER_ESCAPE_20261008.md. Tái hiện trước fix, giữ motor; giữ headless lane đến khi báo nhả.
- sect_research: scripts/npc/npc_world_state.gd, npc_pilot_catalog.gd, npc_population.gd, npc_pilot_resolver.gd nếu cần; tests/npc_nonlethal_recovery_test.gd; docs/NPC_NONLETHAL_RECOVERY_20261008.md. Schema3 giữ legacy facts/ID/quan hệ; nonpermadeath và chỉ recovery theo realrunreturn. Chưa giữ QA lane.
- sect_reference: các file mới scripts/npc/cultivator_catalog.gd, cultivator_actor.gd và helpers prefixcultivator_; tests/cultivator_patrol_test.gd; docs/CULTIVATOR_PATROL_SLICE_20261008.md. Hai tu sĩ patrol/self-defense/damage đúngpipeline; tương tác với life owner qua contract, không sửa file agent khác. Chưa giữ QA lane.
- Các file .gd.uid mới thuộc cùng owner .gd. Agent không apply/commit main, không cùng sửa file, không GPU; root cấp QA lane tuần tự. Cả môn phái ghi thù/truy nã/thuê1người1chuyến đang ở nghiên cứu, chưa coi NPC riêng lẻ là hệ tông môn đã hoàn thiện.
Owner mở rộng sect_research: cập nhật fixtures npc_population_test, npc_lived_opening_test, opening_social_quarantine_test, opening_npc_life_adapter_test, opening_profile_writer_test, opening_cultivation_gameplay_test, opening_progression_guide_test, opening_runtime_wiring_test theo chính sách nonlethal/schema3. Giữ fault/quarantine/cost/UID guards; historical reviewed_opening fixture tách riêng không sửa máy móc. Root không sửa các file này. Root giữ runner registration và flow-integration test.

### 2026-10-08 07:30 UTC — user steering / private continuation
- Root: GameFlow expedition-only NPC recovery, fault/retry test, strict registration, max_mana catalog/component/quest copy + world_economy assertions. Real save remains untouched; main unchanged.
- sect_research: add opening_combined_owner_test.gd to assigned fixture ownership, preserving reviewed historical fixture source.
- sect_reference: PrologueHub shop/Soul-upgrade confirmation; shop_purchase_confirmation test, npc_dialogue/two_column_service_ui/preview_world_building fixture updates; dedicated report. No overlap with root UI guide files.
- stuck_audit: performance investigation now takes priority. Read-only copy of real save + size-matched measurements, no GPU while user plays. Current game reported severe FPS drops; full cultivation ledger is a newly observed blocker. Implementation ownership will be recorded after measured plan.
- New user requests retained: readable rune acquisition/learning route, max HP + max mana using Souls; max HP already exists, improve discoverability. Fixed companion fee prepaid in Linh Thach, no loot share.

### 2026-10-08 07:40 UTC — ownership additions after user feedback
- stuck_audit owns opening_cultivation_state.gd, opening_cultivation_session.gd, sanctuary_profile.gd, new bounded-ledger test/report. Confirmed size-matched warm synchronous mastery costs 144–160 ms at 980 receipts; original real profile now reaches 1024. Keep writer protocol and per-hit durability; migrate through the same atomic owner with immutable backup.
- sect_research owns new RuneLearningService, rune_learning_test and report. Five finite learning receipts; repeat crafting uses existing atomic economy owner, not an ever-growing receipt list. sect_reference integrates the UI in its PrologueHub ownership.
- Root owns GearInventoryModal acquisition text; InventoryScreen detailed equipment readout; OpeningProgressionGuide/OpeningQuestCards and cultivation panel next-step guidance; opening_quest_cards_test and inventory UI regressions. These are background changes while FPS validation takes the engine lane.

### 2026-10-08 08:10 UTC — deadline và kiểm bản có hình
- Hạn mới do người dùng chốt: 17:00 Asia/Ho_Chi_Minh ngày 08/10, tức 10:00 UTC. Kiểm giờ trước nhóm việc mới; tới hạn không bắt đầu việc mới.
- stuck_audit: native frame-time before/after bằng cùng save QA, giữ riêng normal/hitstop-off; sole GPU lane được cấp. Không sửa thêm parser/writer sau khi đo cho thấy lợi ích không đủ.
- sect_research: chuẩn bị tests/sect_progression_visual_probe.gd + UID và báo cáo ảnh; chỉ chạy sau khi được nhả GPU lane. Root xem ảnh thực để kiểm layout/input/hitbox.
- sect_reference: docs/SECT_STORY_ROADMAP_20261008.md; ghi hướng gia nhập, tâm pháp/võ công, khiêu chiến, chưởng môn và map từng phái theo yêu cầu mới, phân biệt đề xuất với runtime đã có.
- Root: đổi duy nhất tên boss HUD trong DepthCampaign thành Huyền Uyên Chấp Ấn để khớp Lạc Ấn; không đổi cơ chế. Chuẩn bị strict, backup/exact preimage và báo cáo cuối. Main chưa ghép.

### 2026-10-08 09:05 UTC — gia hạn và lựa chọn tầng
- Người dùng gia hạn đến18:00 Asia/Ho_Chi_Minh (11:00UTC); mốc17:00 trước đó đã hết hiệu lực. Kiểm giờ trước từng nhóm, dừng an toàn khi tới hạn.
- sect_research nhận tạm ownership InventoryScreen.gd + visualprobe để giải quyết hover/wheel mà vẫn giữ click trang bị. Các source còn lại của worker frozen trừ phân công mới bên dưới; một engine lane.
- sect_reference: DepthProgress, DepthGuide, phần depth-only trong GameFlow/DepthCampaign, test mới depth_floor_selection và báo cáo. Cho chọn tầng đã hoàn tất1..cleared; không cấp progress/loot khi chọn, không skip tầng chưa xong. Không đổi schema/balance hoặc mở tầng mới trong slice này.
- stuck_audit: chỉ script backup/rollback và smoke bên ngoài checkout; đã kiểm rollback partial/all-before/all-after/third-hash20/20. Không chạm save thật.
- Root giữ đầu mối ghép. Strict R1 rejected21/257 được giữ bằng chứng, chưa main; sau source cuối phải strict mới sạch. Yêu cầu nếu dư thời gian: tầng sâu hơn, map rộng/lâu hơn và quái/skill/animation riêng được lưu vào roadmap, không gọi thiết kế là runtime.

### 2026-10-08 09:39 UTC — Vân Thạch rộng, một owner và đường hoàn tác riêng
- sect_reference nhận ba runtime DepthFloorCatalog/DepthRoom/DepthCampaign, hai fixture depth_campaign/depth_terrain_art và test depth_wide_floor mới. Root giữ runner; sect_research chỉ audit đọc. Chỉ tầng1 rộng1920, ba guard cũ, nhánh rương thường; không migration tầng6 hoặc đổi cân bằng quái.
- stuck_audit đã chụp checkpoint sáu preimage và hai đường test mới vắng mặt, kèm2183 hash core. Root niêm phong afterimage trước strict để có thể loại riêng wide mà giữ toàn bộ FPS/rune/NPC/selector đã kiểm. Main/save thật chưa sửa.
- Root xem PNG native thật, sau đó strict cuối kiểm source frozen. Không đồng thời chạy GPU nặng; nguồn hình/stat/motor và các tầng2–5 giữ theo contract.
### 2026-10-08 10:36UTC — core đã ghép, tiếp tục nối tầng theo yêu cầu mới
- Core105targets main đã ghép sau263/263strict; hậuimport/numeric64/copiedsave110/nativeFPS11 sạch, nguyênsave tới10:29:01. User mởeditor/game sauđó; GPUUIpost bịguardchặn trướclaunch, khôngkillgame.
- Yêu cầu mới: nămảiDepth trởthành tầng4–8 của hầmngụcchính sauGolemopening. sect_reference ownWorldCampaign/DepthCampaign +testsegment, sect_research ownGameFlow bridge +testcarry, rootUIguide/labels/runner/integrator. GiữlocalprogressIDs vàsave; draftngoàicheckout tới root nhảsource. stuck_audit chỉauditcontract/rollback. KhôngGPU khiuserđangchơi.
## Tiếp tục sau18h — root giữ ownership connector/tông môn

Người dùng yêu cầu tiếp tục các việc dở gồm map tông môn; mốc18h cũ không còn là điểm dừng của lần tiếp tục. Không gọi thêm agent. Root dùng private2611f63, nối bốn map/quest/NPC, kiểm input/native/schema4 và strict cuối rồi mới ghép. Đã ghép main525355d sau strict273/273, có backup/hash guard; xem hậu kiểm và giới hạn trong báo cáo tiếp tục. [Báo cáo](../SECT_MAPS_RESUME_20261008.md). Còn witness/truy nã/hire/kế nhiệm/animation riêng, đã ghi roadmap; không đổi motor, cân bằng kinh tế hay dùng save thật cho QA.
