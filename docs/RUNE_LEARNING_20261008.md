# Học và chế thêm bùa — 08/10/2026

Trạng thái: source và fixture trong worktree sect-path-repair đã qua import và focused headless 60/120Hz, mỗi lượt 183/183 checks; chưa ghép bản chính. Hệ này dùng năm nguyên tố hiện có, không thêm bùa hay tổ hợp cộng hưởng. Bằng chứng UI/quest và ghép bản chính do root quản lý.

## Hành vi

Học một nguyên tố dùng Tàn Hồn một lần, lưu kiến thức vĩnh viễn và nhận một bùa Common có UID hữu hạn vào hành trang. Hỏa/Phong giá mẫu 5; Lôi/Băng giá mẫu 10 và cần mốc explored; Độc giá mẫu 15 và cần mốc golem_defeated. Đây là giá prototype được duyệt cho slice, không phải cân bằng cuối. Dịch vụ không khóa việc sử dụng, ghép hay trang bị bùa đã nhặt khi người chơi chưa học nguyên tố đó.

Sau khi học, có thể chế thêm từng bùa với 2 Bột Tinh Thể Phép và 1 Tinh Thạch trong kho. Tinh Thạch là vật liệu crystal, khác tiền Linh Thạch. Mỗi lần chế nhận một UID mới, không phải bùa vô hạn hoặc tăng stack mà không có vật phẩm.

API RuneLearningService.initialize(EconomySession), quote(id), learn(id), craft(id), state(). IDS là năm StringName hiện có. Quote là bản dữ liệu tách rời gồm id, name, learned, can_learn, can_craft, cost Tàn Hồn, craft_materials, lock_hint, learn_lock_hint, craft_lock_hint. UI đọc lại quote khi xác nhận; owner cũng đọc lại trước giao dịch.

Initialize chỉ giữ tham chiếu và đăng ký validator, không ghi save. Có thể khởi tạo sau EconomySession trong ready; quote chỉ mở giao dịch khi SafeInventoryPersistence đã đặt persist_safe_inventory. Dịch vụ khóa khi rời Hub, writer đang busy, hành trang quá giới hạn codec, dữ liệu profile/knowledge bị quarantine hoặc vật liệu/mốc còn thiếu.

## Lưu và hoàn tác

Kiến thức dùng namespace rune_learning_v1 qua extension writer sẵn có. State có đúng hai trường schema=1 và learned, chỉ chấp nhận năm ID duy nhất. Số revision phải bằng số bài đã học; tối đa năm receipt, mỗi nguyên tố một receipt. Chế thêm không tạo receipt nên không tiêu hao giới hạn receipt hữu hạn của profile.

Học giữ economy._busy, tạo rune tạm trong ledger, encode hub_inventory rồi gọi commit_extension_event với souls_cost. Kiến thức, lần học đầu, giá và rune UID nằm trong cùng candidate profile. Chỉ status committed mới công bố rune; already_committed không thể công bố UID tạm mới. Thất bại khôi phục inventory/bag/hub ledger; writer hiện có khôi phục souls/extension state. Không tua lùi global UID counter để tránh tái dùng identity.

Chế giữ cùng khóa, trừ vật liệu kho, thêm rune rồi dùng EconomySession._save_safe. Thất bại hoàn tác nguyên liệu/rune/ledger. Cả hai nhánh chỉ phát inventory changed sau durable commit bằng _publish_commit, giữ khóa xuyên callback để SafeInventoryPersistence không lưu trạng thái tạm hoặc reentry mua hai lần.

Nếu writer báo kết quả chưa chắc chắn và đặt read_only, RAM không công bố phần thưởng tạm. Cold recovery hiện có tự quyết định candidate đã có durable decision hay chưa; khi nhận decision thì khôi phục đồng thời kiến thức, giá và chính UID đã đề xuất. Không tự xóa decision/candidate hoặc tạo writer thứ hai.

Future/malformed knowledge không được coi là danh sách trống. Dịch vụ trả state rỗng và khóa hai giao dịch, giữ nguyên extension trong profile. Quarantine cục bộ không tự chặn những owner độc lập khác. Profile read_only/ledger quarantine vẫn được tôn trọng.

## Kiểm tra đã thực chạy

tests/rune_learning_test.gd yêu cầu QA-root riêng trước mọi write. Fixture dùng SanctuaryProfile v2, EconomySession, GearInventoryCodec, SafeInventoryPersistence và journal fault hooks thật.

- Học một lần, giá/UID/cấp Common chính xác, không học lại, không làm mất bùa nhặt đang ghép.
- Mốc khám phá/boss, ID lạ, vật liệu kho, full inventory, stale Hub và reentry callback.
- Năm bài chỉ có năm receipt, chế lặp giữ nguyên receipt count; cold reload giữ UID/cost/knowledge/equipment.
- Lỗi write_candidate/write_decision/rename_decision/rename_old/commit ở cả học và chế: rollback toàn bộ, primary bytes giữ nguyên, cold load không có reward bị abort.
- Bốn điểm interruption: candidate không có decision bị bỏ; decision được phục hồi với đúng UID/giá/knowledge; lần học đầu không được trao lại.
- Future schema, ID lạ, ID trùng, schema bool và receipt/learned mismatch bị khóa, không reset.

Import exit0/diagnostics rỗng. Focused 60Hz và120Hz đều 183/183 checks, exit0, không timeout, diagnostics rỗng. Raw stdout/stderr/RUN_RESULT cùng source hashes ở [verification/nonlethal_rune_20261008/EVIDENCE_MANIFEST.json](verification/nonlethal_rune_20261008/EVIDENCE_MANIFEST.json); labels pass là rune_learning_60_r2_0750 và rune_learning_120_0751, kết thúc 07:50:48 UTC.

Lượt đầu 60Hz có ba assertion fail khi so sánh nguyên Dictionary candidate JSON với ledger codec đã khôi phục kiểu int cho UID. Sửa fixture thành codec.valid và so sánh canonical numeric toàn bộ ledger, giữ kiểm tra cost và cold replay. Runtime service không phải sửa sau lượt này. Lượt fail vẫn được giữ trong evidence, không lọc warning/error.

Lệnh dùng C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/probes/run_probe.ps1 -Project trỏ worktree này -Headless -Script res://tests/rune_learning_test.gd -UserArgs --hz=60 hoặc --hz=120 -TimeoutSeconds 60. Chỉ save QA riêng do helper thiết lập, không đọc/ghi profile người chơi.

Chưa có cảm nhận chơi hoặc bằng chứng visual của slice này. Không dùng transaction tests làm bằng chứng người chơi đã hiểu cách học hoặc ghép bùa. Headless lane đã nhả cho agent đo combat lúc 07:50:49 UTC.

Sau focused QA, root review phát hiện câu hướng dẫn mốc explored mô tả nhầm khám phá hầm ngục. Đã sửa duy nhất lời khóa Lôi/Băng thành: “Qua ĐƯỜNG BỘ ở sân căn cứ để ghi mốc khám phá, rồi quay về học bùa này.” Mốc dữ liệu, giá và giao dịch không đổi. Không chạy lại 183 checks cho thay đổi câu chữ; manifest giữ hash đã kiểm và ghi hash sau copy riêng. Gate strict tiếp theo của root sẽ kiểm hash mới.
