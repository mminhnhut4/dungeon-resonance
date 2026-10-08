# Xác nhận mua và dịch vụ học bùa — 2026-10-08

Phạm vi: bản riêng `C:/Users/Admin/.codex/worktrees/sect-path-repair/hầm ngục`. Chưa áp dụng vào `D:/hầm ngục`, chưa commit. Thông số học/chế bùa và nâng cấp là prototype, chưa phải cân bằng cuối.

## Hành vi

- Kael: chọn trang bị mở thẻ tên, ảnh hiện có, quality, số lượng, giá Linh Thạch, tiền đang có và số dư sau mua. Thanh Vy: mua thuốc dùng cùng xác nhận. Chưa xác nhận không gọi giao dịch, không trừ tiền, không cấp đồ.
- `Xác nhận mua` mới gọi EconomySession hiện có. Callback tiêu thụ token trước khi gọi owner, nên callback cũ hoặc nhấn lặp không thanh toán lần hai. Xác nhận kiểm tra lại cửa hàng, trạng thái hồ sơ, khả năng mua, chỗ trống và giá hiện tại. Giá thay đổi phải chọn lại, không tự thu giá mới.
- `Hủy` là nút nhận focus mặc định. Esc lần đầu hủy lựa chọn, Esc tiếp theo đóng cửa hàng. Đóng cửa hàng hủy token; controls/modal/TimeScaleClaims vẫn dùng owner hiện hành.
- Nâng cấp Tàn Hồn tại Thanh Vy dùng confirmation sẵn của DialogueBox. Nội dung có giá và số dư; xác nhận kiểm tra lại cấp/giá/khả năng mua. Danh sách đọc WorldProgressionCatalog và có `Dưỡng thần · Mana tối đa`.
- Thanh Vy có mục `Học & chế bùa`: năm thẻ Hỏa/Phong/Lôi/Băng/Độc. Mỗi thẻ hiện điều kiện mở khóa; chưa học hiện giá Tàn Hồn và phần thưởng một bùa Thường. Sau khi học, thẻ chuyển sang chế một bùa Thường bằng vật liệu trong kho. Bùa nhặt được vẫn sử dụng ngay dù chưa học.
- Học/chế bùa xác nhận cùng modal; học hiện Tàn Hồn, chế hiện từng vật liệu đang có/cần có. Khi xác nhận, đọc lại RuneLearningService.quote và so sánh kiến thức/giá/vật liệu, rồi mới gọi service. Không thêm save writer hoặc thay luật ghép bùa.

## Ownership

UI trong `scripts/hub/prologue_hub.gd`; giao dịch thiết bị/thuốc/Tàn Hồn vẫn do EconomySession. RuneLearningService do agent `sect_research` sở hữu, sử dụng SanctuaryProfile/commit hiện hành. Root sở hữu max_mana catalog/component và hướng dẫn trong hành trang. Không mở rộng sang Bí Thương trong SurvivalSession.

## Kiểm thử

Đã soạn `tests/shop_purchase_confirmation_test.gd`: input chuột thật ở 800×600 và 1280×720; chọn/hủy/Esc; mua một lần; callback cũ; cold reload; giá/tiền/capacity/trạng thái thay đổi; lỗi commit writer và rollback; thuốc không tự uống; HP/Mana Tàn Hồn; mục học bùa/khóa điều kiện/cost/craft từ kho.

Đã cập nhật fixture `npc_dialogue_test.gd`, `two_column_service_ui_test.gd` theo luồng xác nhận. `preview_world_building.gd` thêm capture xác nhận Kael để dùng trong lượt GPU riêng sau này.

Trạng thái tại 07:58 UTC: root thông báo import source hiện tại đã sạch trong lượt agent trước; lượt riêng `shop_purchase_confirmation_test.gd` đạt **123/123 ở 60 Hz và 123/123 ở 120 Hz**, exit 0, diagnostics rỗng. Source runtime không thay đổi trong lượt QA này. Chín file UI/service/owner/fixture đã đối chiếu SHA trước/sau, không drift. Headless lane đã trả root 07:58:35 UTC.

Evidence dùng helper `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/probes/run_probe.ps1`, Godot 4.7.2, profile/evidence cách ly, process Hidden:

- `probes/shop_confirmation_60_r2/{stdout.log,stderr.log,RUN_RESULT.json}`
- `probes/shop_confirmation_120_r2/{stdout.log,stderr.log,RUN_RESULT.json}`
- `probes/shop_source_r2_before.json` và `shop_source_r2_after.json`.
- Lượt `shop_confirmation_60_r1` và `shop_confirmation_60_diagnostic` giữ nguyên raw: 3 lỗi fixture. Cold reload cần so sánh canonical JSON thay vì Dictionary chứa kiểu StringName; fault writer phải dùng hồ sơ v2 thật thay vì backend legacy v1; hướng dẫn mở Lôi đổi thành đường bộ nên kiểm ý nghĩa không khóa chữ hoa. Sửa fixture rồi chạy lại cả 60/120 sạch.

Agent service đã review API UI học/chế bùa, chưa thấy blocker. `npc_dialogue_test.gd` và `two_column_service_ui_test.gd` chờ strict chung theo phân công root, không chạy lặp trong lane này. Chưa QA hình ảnh/GPU, chưa chạy strict toàn dự án; không coi headless là bằng chứng thẩm mỹ. Thẻ mua hiện tên/quality/mô tả/giá, chưa là giao diện thống kê đầy đủ mọi chỉ số trang bị.
