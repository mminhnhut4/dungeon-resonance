# NPC trọng thương, rút lui và hồi phục — 08/10/2026

Trạng thái: candidate trong worktree sect-path-repair, chưa ghép bản chính. Owner/UI và fixture nonlethal đã qua import và focused headless 60/120Hz, mỗi lượt 137/137 checks. Root giữ quyền ghép, binding trở về từ chuyến đi và kiểm tra cuối. Người dùng vẫn đang chơi; phiên này chỉ chạy QA headless với save riêng.

## Quyết định đang áp dụng

- Tất cả NPC giữ tính mạng. Bị hạ thì rút về dưỡng thương, trở lại sau một chuyến hầm ngục kết thúc hoặc quay về. Đổi phòng, chờ ngoài đường, mở menu và tải lại không tự hồi phục.
- Trở lại vẫn giữ ID, đời sống, quan hệ và ký ức. Dừng tay sau khi gây thương tích không tạo lòng biết ơn hoặc món nợ đối với người tấn công.
- Phản ứng tự vệ tại chỗ khác với việc cả tông môn biết. Quy tắc chứng kiến/báo tin/bằng chứng đã được chọn, nhưng hệ lưu danh tiếng, truy nã và hợp đồng thuê chưa thuộc owner patch này.
- Tự vệ không tăng truy nã. Đánh người đang rút lui là hành vi gây hấn mới.
- Một người đồng hành cho một chuyến, trả trước mức Linh Thạch cố định, không chia loot là quyết định thiết kế đã chọn; tài liệu này không gọi việc thuê là feature runtime đã hoàn tất.

## Owner và dữ liệu

NpcWorldState tiếp tục sở hữu HP, vị trí, lịch cư dân, quan hệ và sidecar .npc_v1.json; tên file giữ nguyên. Schema mới là 3, có đúng tám stable ID: sáu cư dân cũ và thanh_van_disciple_01, xich_lo_guard_01. Definition/schedule cho hai tu sĩ mới đặt trong NpcPilotCatalog; combat/presentation subclass có payload và kiểm tra riêng.

Schema1 chỉ chấp nhận đúng năm ID lịch sử và 12 field/record; schema2 chỉ chấp nhận sáu ID cũ và 14 field. Không dùng danh sách mới để kết luận save cũ thiếu NPC, và không bổ sung NPC vào dữ liệu lỗi. Schema3 yêu cầu đúng tám ID và 15 field, trong đó legacy_death là dictionary bắt buộc.

death trong schema3 luôn rỗng, HP tối thiểu 1. legacy_death rỗng hoặc chứa nguyên năm field của tombstone cũ: event_id, killer_id, tick, room, context. Đây là sự kiện lịch sử, không phải trạng thái chết hiệu lực. Trường hợp bị thương về sau tăng episode hiện tại; event ID trong archive vẫn giữ episode lịch sử.

Migration đã xác thực schema1/2 mới tạo đúng những identity mới. Legacy dead/downed/recovering được chuyển sang recovering, HP1, remaining0; trust/fear/debt/greeted/episode/vị trí/room giữ nguyên. Tombstone không bị xóa mà chuyển vào legacy_death. Không phát thưởng, không tạo life ID mới, không ghi canonical profile chứa social/courier/cultivation/UID.

Migration commit qua IO hiện có trước khi công bố authority mới. Lỗi open/backup/replace khôi phục toàn bộ view legacy và đặt instance read-only; khởi tạo reader mới có thể thử lại cùng nguồn hợp lệ. Future/malformed hoặc mất primary trong khi còn .bak/.tmp/.previous vẫn quarantine. Không lấy backup sống cũ để bỏ lịch sử.

Backup .bak hiện có giữ byte nguồn ở thời điểm migration, sau đó là backup xoay của owner. File trước migration bất biến .pre_nonlethal_v1.json hoặc v2 được copy/readback qua IO hiện có trước khi chuyển schema; nếu đã có khác byte thì quarantine, không ghi đè. Primary mất trong khi còn bản bất biến cũng không được xem là profile mới. Các nhánh này đã qua focused test 60/120Hz.

## Chuyển trạng thái

DamageResolver vẫn áp health floor trước khi trả DamageResult, vì vậy hit hạ NPC không có killed=true và không phát reward giết. HP chạm1 tự chuyển recovering; NpcPopulation bỏ representation khỏi phòng và bỏ tương tác. Resolver chặn direct/DOT khi đang recovering. Sáu cư dân cũ vẫn dùng tuyến đi hiện có.

decide(id, token, kill, confirmed) giữ call surface để từ chối callback cũ: bất kỳ kill=true đều false. Compatibility downed có thể gọi kill=false để rút lui, không cộng debt/trust. Thoại/nút giết bị bỏ; callback pilot_confirm_kill không thể đi vòng owner.

recover_after_expedition() do root GameFlow gọi sau một run thật quay về. Nó chuyển các record recovering/downed sang rest, 50% HP theo giá trị hồi phục cũ, giữ ký ức/episode/life ID. Toàn bộ hồi phục là một lần save; lỗi lưu rollback RAM, không phát rest thành công. Nếu không có NPC cần hồi phục thì trả true và không save. emitting_recovery tránh listener checkpoint cultivation ghi thêm cùng sự kiện.

Kiểm tra source tìm thấy trạng thái nghỉ giữa đường trước đây không thể tiếp tục: hết remaining nhưng x chưa trùng stop nên nhánh chuyển sang walk không chạy. Owner được sửa để đi tiếp tới stop đang chờ sau quãng nghỉ; chỉ tăng schedule cursor khi đã đứng tại stop. Điều này tránh NPC vừa hồi phục hoặc chạy trốn xong đứng yên vô hạn. Test cold recovery đã xác minh đi lại sau 12 tick ở 60/120Hz.

Hai tu sĩ có runtime motion hold qua set_local_control(id, active) và update_local_position(id, x): chỉ hai ID mới được dùng, vị trí bị clamp trong đoạn patrol, không ghi đĩa mỗi frame. Khi held, lịch4Hz bỏ qua actor đó. Mode và pose combat thuộc actor mới; hold không lưu xuống save, teardown phòng giải phóng, cold load không giữ combat cũ. receive_hit có tham số record_cause để resolver tu sĩ gộp cùng root không trừ quan hệ lặp nhưng vẫn cập nhật HP.

## Phạm vi kiểm tra

Fixture mới tests/npc_nonlethal_recovery_test.gd yêu cầu DUNGEON_QA_DATA_ROOT khớp user data trước mọi write; path riêng theo Hz/PID/time. Các nhóm kiểm tra được viết:

- Nonlethal thật qua Hurtbox/Resolver/Health, chặn DOT lúc rút lui, callback giết không còn hiệu lực.
- Không tự hồi sau 400 giây gameplay, không tự hồi khi tải lại; root recovery idempotent.
- Một commit hồi phục, rollback khi final replace thất bại, giữ quan hệ, cold load.
- Migration schema1/2, archive nguyên dữ kiện, cùng life ID, không đụng canonical profile sentinel, retry sau lỗi open/immutable-copy/backup/primary. Bản bất biến giữ nguyên qua hồi phục, chấn thương mới và backup xoay; xung đột hoặc mất primary giữ quarantine.
- Future/corrupt/missing-primary quarantine, không dùng backup cũ để repopulate.
- Local control không tranh vị trí với tick4Hz, clamp/NaN/no-per-frame-write và release/cold load.

Các nhóm trên đã chạy 60/120Hz, 137/137 mỗi lượt, exit0 và diagnostics rỗng. Bằng chứng GameFlow thực quay về và actor tu sĩ đánh trả thuộc các fixture owner tương ứng; không cộng số từ chúng vào test này.

Lượt đầu 60Hz có 7 assertion fail, raw log vẫn được giữ: archive tick đọc lại từ JSON còn float thay vì int và phép so sánh readonly legacy view với fixture typed đã nhầm khác biệt kiểu số là thay đổi dữ kiện. Owner nay normalize legacy_death.tick khi cold restore; các assertion readonly so sánh canonical numeric đầy đủ, vẫn giữ kiểm tra primary/backup byte-identical riêng. Rerun 60Hz và lượt 120Hz đều sạch; không bỏ kiểm tra dữ kiện lịch sử để lấy PASS.

Lệnh chạy qua C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/probes/run_probe.ps1 với -Project trỏ worktree này, -Headless -Script res://tests/npc_nonlethal_recovery_test.gd -UserArgs --hz=60 hoặc --hz=120 -TimeoutSeconds 60. Import dùng cùng helper với -Import. Raw stdout/stderr/RUN_RESULT của cả lượt fail và pass, cùng hash source nằm trong [verification/nonlethal_rune_20261008/EVIDENCE_MANIFEST.json](verification/nonlethal_rune_20261008/EVIDENCE_MANIFEST.json). Lượt pass: npc_nonlethal_60_r2_0750 và npc_nonlethal_120_0751, kết thúc 07:50:46 UTC.

## Fixture cũ đã cập nhật theo luật mới

Root đã chuyển ownership chín fixture sau cho worker nonlethal. Ban đầu cập nhật code và để root chạy trong strict R1; kết quả và sửa sau gate ghi bên dưới:

- npc_population_test.gd, npc_lived_opening_test.gd: sáu→tám ID, một→hai actor ở P01/P02, downed/Tha thưởng/giết vĩnh viễn, schema1 generated từ current default và migration chỉ đọc.
- opening_social_quarantine_test.gd, opening_npc_life_adapter_test.gd, opening_profile_writer_test.gd, opening_cultivation_gameplay_test.gd: fixture tạo active dead trực tiếp phải dùng withdrawn cho life fence, hoặc legacy schema1/2 đúng shape nếu mục tiêu là history/quarantine.
- opening_progression_guide_test.gd, opening_runtime_wiring_test.gd: mất NPC do rút lui và quay lại sau chuyến đi, không còn callback giết.
- opening_combined_owner_test.gd: dùng NpcWorldState hiện tại để kiểm tra kết hợp với các extension fixture. Owner lịch sử đóng đinh schema2/14 field nhưng lấy default từ catalog hiện tại, nên không dùng owner đó để phát sinh save schema3. Các fixture lịch sử vẫn nguyên vẹn.

npc_visual_capture.gd không thuộc payload worker: kịch bản Kill/Spare không còn đúng; không chạy GPU trong phiên người dùng đang chơi.

Các file tests/integration_fixtures/reviewed_opening/ là snapshot lịch sử riêng. Không đổi tất cả chữ dead sang recovering một cách máy móc, không bỏ assertions để lấy PASS. Giữ các negative guard, cost, writer fault, tamper, UID và life fences.

Kiểm tra tĩnh git diff --check qua bốn runtime file và chín fixture không phát lỗi. Agent đã nhả headless lane lúc 07:50:49 UTC cho đo combat FPS/save của stuck_audit. Chín fixture cũ để root chạy trong gate tổng hợp, tránh chạy lặp. Kết quả actor tu sĩ 60/120Hz trước đó thuộc báo cáo actor agent và chưa bao phủ phần immutable backup/stale-dialog bổ sung sau lượt chạy ấy.

## Giới hạn còn nguyên

Không có bằng chứng visual/playtest/GPU mới, không thêm portrait/animation raster vào owner patch này. Chưa có luật truy nã, nhân chứng truyền tin, full faction store, dịch vụ thay thế cho mọi NPC nhiệm vụ hoặc thực thi hợp đồng thuê. Core NPC vốn không có Hurtbox không được biến thành một combat actor chỉ bởi migration. Outside Player vẫn theo health floor hiện hành; luật thua trận ngoài trời không tự đổi.

## Sau strict R1 — 08:49 UTC

Strict R1 đã kết thúc dưới root, không là PASS tổng thể. Các suite population/lived/social-quarantine/life-adapter/profile-writer/cultivation-gameplay/combined-owner và nonlethal owner đạt60/120. Visual actor và flow native mới được ghi riêng ở [SECT_PROGRESSION_VISUAL_20261008.md](SECT_PROGRESSION_VISUAL_20261008.md), không lấy số của chúng làm bằng chứng cho migration.

R1 phát hiện `opening_runtime_wiring` giữ registry representation của pilgrim sau callback cũ khi fixture đã tắt process population để đứng yên. Owner callback đã chặn tiến triển và đóng dialogue, nhưng cleanup actor chỉ chờ `_process`; vì vậy hai assertion không đạt. Sửa đúng owner: nhánh callback thấy `recovering/dead` gọi `_remove_withdrawn_actor` ngay rồi đóng dialogue/return. Giữ nguyên assertion kiểm actor bị loại, controls mở, mode recovering và death rỗng; không che lỗi bằng cách bỏ assertion hoặc chỉ hide sprite.

Cùng fixture, các sự kiện harvest/craft được đổi sang `cult_<next_event>` theo owner compact schema2 hiện hành. Vẫn dùng Model.propose + SanctuaryProfile.commit_cultivation, giữ nguyên origin lineage, một herb/một pill và đúng chi phí hai dust cùng các negative guard khác. Đây là sửa caller test cũ, không nới validator hoặc đổi phần thưởng.

Theo root, NpcPopulation cũng nối `CultivatorCatalog.dialogue_lines(id)` cho hai ID tu sĩ khỏe trước extension choices. Chỉ thêm lời kể từ catalog owner khác; không thêm lựa chọn nhận quest, tiền, luật phe hoặc hợp đồng thuê. Lời kể chưa đổi lịch sử/roster/life IDs. Bốn file vừa sửa đang chờ root cấp lane/checkpoint; không tự gọi đó là đã kiểm sau sửa.

Hai fixture được root giao thêm: `opening_loop_test` thêm actual mouse confirmation sau chọn HP và assertion chưa chi/trả trước xác nhận; vẫn giữ các fault/cost/UID/loop/reload checks. `armor_test` cập nhật nhãn chính xác `Sát thương trang bị: +2`, giữ checks armor/damage pipeline. Không chỉnh các historical fixtures.

## Kiểm lại sau sửa R1 — 09:00 UTC

Helper isolated QA đã chạy tuần tự headless60: `sect_r1fix_opening_runtime_wiring_60_0859`111/111, `sect_r1fix_opening_progression_guide_60_0859`202/202, `sect_r1fix_opening_loop_60_0859`315/315, `sect_r1fix_armor_60_0859`31/31. Cả bốn exit0, không timeout, diagnostics rỗng. Raw và hash được giữ trong [POST_R1_NATIVE_AND_CLICK_MANIFEST.json](verification/sect_progression_visual_20261008/POST_R1_NATIVE_AND_CLICK_MANIFEST.json); hash source lấy sau lượt chạy được ghi thời gian riêng, không gán ngược cho bản lịch sử.

Cleanup actor ngay tại callback, sequence ID cultivation và fixture xác nhận HP nói trên đã có kiểm thực sau sửa. Tu sĩ khỏe kể chuyện và hai PNG mới được kiểm native32/32 bởi visual fixture lúc08:58, báo cáo pixel/giới hạn ở [SECT_PROGRESSION_VISUAL_20261008.md](SECT_PROGRESSION_VISUAL_20261008.md). Đây không phải full faction/witness/hire hoặc trải nghiệm animation hoàn thiện. Root vẫn giữ strict/backup/merge; chưa áp bản chính từ worker này.
