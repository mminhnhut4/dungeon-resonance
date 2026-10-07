# Private opening progression repair — candidate thứ ba

Candidate riêng từ nguồn 155; chưa áp dụng vào `D:/hầm ngục` và không ghép campfire/NPC motion NEXT21 hoặc map branch P02.

Hai gap đã tái hiện trên 155 nguyên trạng: regression 16 checks/3 failures, stderr trống. 256 lượt world loot tạo 786 pickup/0 rune; legacy chest có 2/3 rune. GameFlow thật thắng Golem, có một proof/receipt và quay về Hub với zero Soul, nhưng không ghi `returned_to_hub`, kể cả cold reload.

`GameFlow.show_hub` nay ghi return từ outcome victory tại giao dịch return đã có. `reward_collected` vẫn chỉ do nhặt Soul boss thật; không mint Soul/coin, không ghi giả reward. Pending save/reward, rollback, explicit retry và reentrant guards giữ nguyên. Defeat đầu không tạo mốc successful return; mốc trước đó giữ khi chết.

World chest khôi phục đúng luật rune ở nhánh legacy hiện có: rương nhỏ 2, lớn 3 rune, cùng IDs và chọn quality. Không đổi material/coin/Soul/blueprint probabilities, none_chance=0.35 hoặc nguồn Thần Thạch. TreasureChest mở một lần, pickup collect một lần, UID/bank/death do owner cũ. Rune đang mang mất khi chết; victory mang rune về. Không thêm nguồn miễn phí từ menu/restart/quest.

Guide có hai file mới và hai UI hunks từ worker onboarding; acquisition sentence/test cập nhật theo nguồn rương thật. Copy điều tức ghi “năng lượng cơ bản; tư chất ảnh hưởng lượng thực nhận” từ hunk R2, có fixture thực nhận 9 so với base 8. Projection vẫn read-only, không tạo writer/schema/reward; không đổi permission của map worker.

Focused hiện đã chạy: regression 16 và recovery 64 checks mỗi 60/120; guide 202 mỗi 60/120; world economy 83 ở 60. Recovery dùng rương/pickup/Player thật để ghép Firestorm, kiểm repeat chest/collect/boss/return, cold reload, death loss, zero Soul và bốn biên lỗi ghi Windows. Lượt đầu assertion QA World Economy dùng nhầm tên owner inventory, đã sửa thành carried; raw lỗi được giữ, lượt sau 83/83 sạch. Các assertion vật liệu cũ giữ kiểm 3–5 pickup thường/tổng stack; thêm assertion hai RuneShard hợp lệ.

Default `tests/run_tests.ps1` giữ các gate cũ và thêm ba suite mới ở cả 60/120. 185 gates/17.081 checks là kỳ vọng; xem receipt ngoài candidate để biết kết quả chạy thật. Không dùng GameplayOnly/CollectAllFailures hoặc lọc ERROR/WARNING. Headless không chứng minh hình ảnh, playback hoặc performance GPU.
