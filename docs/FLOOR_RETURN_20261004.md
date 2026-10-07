# Trở về sảnh sau mỗi tầng hiện có

Đã áp bản chính ngày2026-10-04. Tại lối ra bên phải sau khi dọn xong tầng, nhấn **E** để chọn **Tiếp tục xuống tầng**, **Trở về sảnh**, hoặc **Ở lại nhặt đồ**. Bảng dùng AntiqueSkin hiện hành; Enter/A và mũi tên/D-pad, Esc/B hủy. Space chỉ nhảy, không mở/chọn bảng; Tab không mở hành trang khi bảng này đang mở.

## Điều kiện và quyền sở hữu

Campaign hiện có bốn chặng: Tiền Sảnh, khám phá bí mật, đấu trường hai đợt, Golem. Hai chặng chiến đấu cần hết mọi đợt địch và cửa được mở; chặng khám phá vốn không khóa cửa nhưng cần tới lối ra x>1220. Alpha ba phòng dùng cùng lựa chọn sau cửa mở. Boss cuối cần cổng chiến thắng có thật sau khi hạ Golem; không có nút xuống một tầng mới.

Quay về trước Golem dùng outcome `retreat`, giữ snapshot UID/trang bị/rune/vật liệu/đồ tiêu hao đã nhặt và gửi đồng đang mang vào ngân hàng bằng giao dịch save hiện có. Không tự thu đồ còn trên đất. Không ghi `returned_to_hub` hoặc chứng tích/quest chiến thắng chỉ vì quay về sớm; cổng Golem vẫn dùng victory hiện hữu. Lượt sau bắt đầu từ đầu, chuyển quyền sở hữu đồ một lần; không thêm resume giữa run. Luật mất đồ khi chết giữ nguyên.

Lưu thất bại hoặc ngân hàng đầy giữ run và đồ trong RAM; rollback snapshot/đồng/mốc khi chưa commit, không đổi scene hoặc cấp lại loot. Pending Soul/blueprint/chứng tích dùng escrow/retry hiện có. Sau khi đã yêu cầu trở về, chỉ cho retry; không hủy để xóa phần thưởng chưa lưu. Bấm lặp/frame không tự retry giao dịch. Độ bền sau khi tắt tiến trình trước khi save thành công không được mở rộng bằng tính năng này.

## Kiểm đã chạy

- Bản riêng:80/80 headless chuyển tầng/thưởng/save/cold reload/lặp/cancel/Golem/death, thêm15/15 cho Alpha, biển E và ngân hàng đầy. Không chạy fullsuite hoặc120Hz.
- UI native:17/17 với bốn ảnh; review phát hiện dòng HUD cũ bị debug overlay ẩn nên thêm biển E, kiểm hẹp7/7 và hai ảnh mới. Sáu ảnh đã xem; hai lượt GPU đã thoát, không điều khiển cửa sổ người dùng.
- Bản chính:11/11 headless smoke sau áp, profile QA cô lập, giữ UID/đồng, không mở khóa Golem, cold reload và cleanup. Toàn bộ source/import input được đối chiếu hash; NPC R3 không ghép.
- Import editor bản riêng từng thoát native0xC0000005 sau quét, stdout không có ERROR/WARNING; log lỗi giữ riêng, không gọi là đã sửa. Trạng thái import bản chính và mọi log nằm receipt trong workspace.

## File chính

[DungeonRun](../scripts/rooms/dungeon_run.gd) giữ điều kiện tầng/lối ra và yêu cầu một lần; [LinearCampaign](../scripts/rooms/linear_campaign.gd) giữ đi tiếp; [GameFlow](../scripts/hub/game_flow.gd) giữ giao dịch và scene; [FloorExitPanel](../scripts/ui/floor_exit_panel.gd) giữ UI; [kiểm tập trung](../tests/world/dungeon/floor_return_test.gd).
