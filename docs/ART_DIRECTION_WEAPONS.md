# Mỹ thuật, hành trang và nguồn trang bị

Chốt với người dùng ngày 2026-10-01. Bản thử đã duyệt: [sáu bậc kiếm](art_approval/sword_rarity_6_tiers_approved_v1.png). Một hệ phẩm cấp duy nhất thay toàn bộ hệ năm bậc cũ: **Thường → Hiếm → Cực hiếm → Sử thi → Huyền thoại → Thần thánh**.

- Vũ khí Thường: đòn cơ bản, hiệu ứng gọn, không lấp lánh quá mức. Nguyên tố quyết định màu; phẩm cấp quyết định mức độ đặc biệt/bùng nổ. Kiếm trang trí mạnh hiện tại được xem là hướng mỹ thuật Huyền thoại.
- Làm lần lượt nhiều moveset. Phần triển khai kế tiếp được chọn: **Hành Trang + một kiếm Thường** để kiểm chứng click thay đồ. Chưa sản xuất hàng loạt mọi vũ khí/trang phục.
- Tháo kiếm: có đòn đấm tay không cơ bản; Catalyst vẫn niệm phép. WeaponSocket/Hitbox/Hurtbox vật lý giữ nguyên vị trí; đấm có hit shape riêng qua dữ liệu moveset.
- UI: Tab mở 4 ô Vũ khí/Y phục/Nhẫn/Dây chuyền và 20 ô túi; bùa vẫn có trang riêng. I giữ niệm phép theo Input Map đã có.
- Bản kiếm đơn: `art_approval/common_sword_world_candidate_v1.png`, imagegen từ cột Thường của board đã duyệt, PNG alpha; không là sprite sheet animation. Prompt/metadata giữ cạnh ảnh. Nguồn gốc AI không bảo đảm trùng từng pixel.

## Quy tắc thu nhận và chế tạo đã xác nhận

| Bậc | Nguồn chính đã chốt |
|---|---|
| Thường, Hiếm | Có thể mua ở thương nhân |
| Cực hiếm, Sử thi | Vũ khí phải chế tạo tại thợ rèn, farm nguyên liệu |
| Huyền thoại | Thợ rèn; đúc và khảm cần Bản Nguyên Thần Thạch |
| Thần thánh | Boss có tỉ lệ rất thấp rơi bản chế tạo; thợ rèn, nguyên liệu cao cấp và Bản Nguyên Thần Thạch |

**Bản Nguyên Thần Thạch** chứa một ít sức mạnh thần linh, **chỉ Boss đặc biệt tương lai** được quyền rơi theo yêu cầu mới nhất. Không rơi từ quái thường, tinh anh, Golem hiện tại, rương hoặc shop. Dùng để đúc/khảm hai bậc Huyền thoại và Thần thánh. Chưa chốt Boss đặc biệt/tỉ lệ rơi/thao tác khảm cần đá; không tự áp phí cho mọi lần đổi bùa trên giao diện prototype. Công thức rèn prototype đã có chi phí, nguồn kiếm đá vẫn bị khóa để làm sau.

Nguyên liệu dự kiến do người dùng nêu: đá ma thuật, thép tinh luyện, đá nguyên tố, đá thần, thép thần cần tinh luyện, trận pháp đồ gia trì, phù nguyên lực. Chưa chốt công thức/số lượng từng món.

Chế tạo Thần thánh: **50% thành công mỗi lần**, thất bại mất **toàn bộ vật liệu của lần thử**, bản chế tạo được giữ như công thức đã học. Không tự thêm bảo hiểm hoặc pity. Vật liệu đã mang về kho căn cứ giữ khi chết; đồ/vật liệu đang mang trong run mất. Kho nguyên liệu, thương nhân và công thức rèn cao cấp là bước sau hành trang kiếm Thường, chưa triển khai trong slice đầu.

## Nghiên cứu hỗ trợ thiết kế rèn (đề xuất, chưa là luật mới)

Tách bản chế tạo đã học khỏi túi nguyên liệu và món GearItem UID; giao diện cho thấy lượng đang có/cần trước khi xác nhận. Cách trình bày này tham khảo [Foundry & Crafting FAQ chính thức của Warframe](https://support.warframe.com/hc/en-us/articles/203733700-Foundry-Crafting-FAQ), không sao chép thời gian chờ hay cơ chế trả phí.

Với các lần thử độc lập xác suất 50%, xác suất thành công ít nhất một lần sau N lần là `1 - 0.5^N`: 1 lần 50%, 2 lần 75%, 3 lần 87.5%, 5 lần 96.875%; kỳ vọng 2 lần, không bảo đảm lần thứ hai thành công. Do toàn bộ vật liệu bị mất khi trượt, UI cần hiển thị rõ 50% và danh sách vật liệu tiêu hao, kể cả Thần Thạch. Tỉ lệ bản chế tạo/đá và chi phí phải cân bằng cùng nhau sau khi có nhịp farm thực tế.

Khi triển khai dùng RNG riêng cho loot và rèn, lưu seed/state với giao dịch để không reroll do mở/đóng UI hay retry save. [Godot 4.7 RandomNumberGenerator](https://docs.godotengine.org/en/4.7/classes/class_randomnumbergenerator.html) hỗ trợ seed/state riêng; đây là đề xuất kỹ thuật cho bước rèn sau.

## Phạm vi kiểm chứng

Board mỹ thuật đã duyệt. Định lượng damage/slot/proc của bậc mới chưa là cân bằng cuối. Chỉ cập nhật trạng thái triển khai và kết quả test sau khi chạy thật; headless không chứng minh game feel/ảnh GPU.
