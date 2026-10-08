# Nối năm ải Phong Ấn vào hầm ngục chính

Yêu cầu ngày 08/10/2026: các ải đang ở bảng Lạc Ấn phải thành những tầng sâu của cùng hầm ngục. Hạn phiên là 18:00 giờ Việt Nam (11:00 UTC). Phần nối tầng được triển khai trong checkout riêng `C:/Users/Admin/.codex/worktrees/sect-path-repair/hầm ngục`, **chưa ghép vào bản chính**. Bản chính đã có gói sửa FPS/tiến triển tại commit `327c627`.

## Tuyến trong bản thử

| Tầng hiển thị | Nội dung | Điểm cần đọc khi giao chiến |
|---|---|---|
| 1–3 | Tuyến mở đầu, nhánh bí mật và Golem hiện hữu | Giữ cơ chế và thứ tự cũ |
| 4 | Vân Thạch — tàn tích canh giữ | Né quét, phản công khi vệ binh hồi phục; có nhánh rương |
| 5 | Mộc Căn — vòm rễ nấm | Bổ nhào gần, bào tử xa; rời hướng ngắm đã khóa |
| 6 | Hàn Kính — sảnh gương lạnh | Kiếm hồn báo hướng trước cú xuyên; lướt lệch đường đánh |
| 7 | Xích Lô — lò rèn phong ấn | Rời phù trận dưới chân, đánh khi hộ vệ hồi chiêu |
| 8 | U Minh Tháp — Huyền Uyên Chấp Ấn | Boss hai phase hiện hữu, đổi nhịp và gọi hộ vệ |

Đây là tích hợp năm ải đã có, không tính lại thành năm biome mới. Sau Golem có lựa chọn **Đi sâu · Tầng 4/8**, trở về sảnh hoặc ở lại nhặt đồ. Cùng một campaign, Player, GearSession và inventory đi xuyên ranh giới; không tự hồi máu/mana, làm mới hồi chiêu, gửi tiền về kho hoặc phục hồi NPC giữa chuyến.

Lạc Ấn tiếp tục cung cấp lối tắt vào tầng đã vượt. UI dùng số 4–8; save vẫn giữ namespace `depth_expedition_v1` và ID nội bộ 1–5, nên không đổi nghĩa tiến độ cũ. Boss tầng 8 không cấp lại chứng nhận Golem. Khi proof/loot/objective còn chờ lưu hoặc lưu chấp nhận tầng sâu thất bại, game giữ chuyến ở cổng; không tiêu hành trang để tạo một chuyến thay thế.

## Kiểm chứng và giới hạn

- Import bản riêng: exit 0, không ERROR/WARNING.
- `connected_dungeon_test.gd`: **42/42 tại 60 và 120 Hz** ở lượt cuối. Đi qua opening/nhánh/Golem, lỗi proof và retry, nút tiếp tục thật, giữ object/UID/HP/mana/clock, năm tầng và boss cuối; bỏ raster mở đầu khỏi phòng Depth; reset đúng nhãn nút sau tầng 4.
- `connected_depth_flow_test.gd`: **47/47 tại 60 và 120 Hz**. Entry GameFlow thật, lỗi lưu acceptance giữ nguyên bytes, toàn tuyến tới boss, quay về ngân hàng đúng một lần, giữ UID, cold reload và lối tắt.
- Các fixture dùng chuyển stage trực tiếp và sát thương QA để chuẩn bị tình huống; không chứng minh độ khó, nhịp khám phá hoặc cảm giác chiến đấu tự nhiên.
- Chưa chạy default strict trên checkpoint nối tầng. Kết quả strict **263/263** thuộc gói core đã ghép trước thay đổi này, không được dùng như gate mới của connector.

Kết quả hồi quy và ảnh runtime bổ sung, nếu có trước hạn, được ghi ở phần chốt dưới. Không sửa save thật. Các profile kiểm thử đều ở QA root riêng.

## File và bước tiếp theo

Runtime: `scripts/rooms/depth_campaign.gd`, `scripts/ui/connected_floor_exit_panel.gd`, `scripts/hub/game_flow.gd`, `scripts/npc/depth_guide.gd`. Hai suite nối tầng đã được đăng ký trong `tests/run_tests.ps1`; hai fixture Depth cũ được đổi kỳ vọng số tầng hiển thị, giữ nguyên các assertion ownership/lưu/UID.

Tiếp theo: chạy default strict trên checkpoint cuối; sửa lỗi thực nếu xuất hiện, xem ảnh/runtime của cổng và toàn tuyến, rồi chơi thử liên tục. Chỉ sau gate đạt mới sao lưu bản chính mới nhất, đối chiếu hash từng file và ghép bằng một đầu mối. Không chép QA profile hoặc phục hồi save cũ đè tiến độ người chơi.

Chứng cứ gốc: `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/probes/connected_*`. Báo cáo core và giới hạn FPS: [SECT_PATH_REPAIR_20261008.md](SECT_PATH_REPAIR_20261008.md). Hướng dẫn tiến triển đang có trên bản chính: [HUONG_DAN_TIEN_TRINH_20261008.md](HUONG_DAN_TIEN_TRINH_20261008.md).

## Chốt trước hạn 18:00

- Hồi quy Depth cũ **126/126 mỗi 60/120 Hz**, selector **55/55 mỗi mức**, dùng `--fixed-fps` như default strict. Lượt đi bộ đầu thiếu fixed-fps hết timeout 60 giây ở tầng nội bộ 3, chưa có assertion thất bại; raw timeout được giữ, không tính PASS.
- Native **44/44, 9 PNG**, exit 0, không ERROR/WARNING. Root đã xem cả 9 ảnh: cổng Golem ở 800/1280, đủ năm nền/roster/tên tầng 4–8, lựa chọn cuối và căn cứ sau khi bấm trở về. Lượt này trước hai sửa hẹp cuối (nhãn nút tầng sau và milestone quay về sớm); bằng chứng chỉ áp dụng phần render/routing tương ứng, không thay full strict.
- Phát hiện và sửa lỗi nhiệm vụ trong bản thử: hạ Golem rồi xuống sâu và quay về sớm từng chỉ có outcome `retreat`, thiếu `returned_to_hub`. Điều kiện mới chỉ tính cho chuyến connected thực sự đi qua Golem; không cấp khi dùng lối tắt. **21/21 ở 60/120 Hz**, gồm lỗi writer/rollback exact bytes, retry ngân hàng một lần, UID, tải lại và nhánh shortcut âm tính. Flow toàn tuyến chạy lại **47/47 mỗi mức**.
- Import cuối sạch; validator **230 scripts/37 scenes, 0 lỗi**. Đã đăng ký cả ba suite logic mới cho lần strict tiếp theo; chưa chạy full gate trên connector vì không đủ thời gian trước hạn. **Không ghép connector vào main.**
- Giới hạn nhìn thấy: HUD hướng dẫn ở 800×600 chiếm nhiều vùng chơi; thanh máu boss của HUD cũ đặt thấp nên không xuất hiện trong ảnh boss 800×600. Cần sửa/kiểm riêng responsive, không coi native44 là tất cả HUD đã đạt. Cổng phong ấn còn hình thức đơn giản. Chưa có playtest tự nhiên liên tục hoặc đo FPS riêng toàn tuyến mới.
- Bản chính giữ core `327c627`: strict263/263; hậu kiểm import, numeric64, save-copy110 và native combat11. Cùng fixture dài lịch sử save, p99 khoảng157→29ms; đây là giảm khựng đã đo, chưa phải hết lag ở mọi trận. Native cleanup crash lịch sử và giao dịch profile/NPC khác file khi thoát đúng lúc lỗi vẫn còn giới hạn được ghi trong báo cáo core.
- Bản sao nguồn core, manifest hash và rollback có guard nằm ở `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/handoff_core_final_1028`. Không phục hồi save v1 cũ đè tiến độ v2 người dùng đã chơi. Evidence chọn lọc core lưu trong `docs/verification/sect_path_repair_20261008`; connector lưu riêng trong `docs/verification/connected_dungeon_20261008`.

Phần còn thiết kế: nhân chứng/báo tin/truy nã, thuê đồng hành, map tông môn và khiêu chiến lên chưởng môn. Không gọi chúng là đã hoàn thành vì đã có NPC tuần tra. Ưu tiên tiếp theo là strict connector → sửa HUD 800 và chơi thử → backup/ghép; sau đó mới mở nội dung sâu mới theo yêu cầu.

Checkpoint source riêng: `2611f6360d3bc81b089152065ea05e5f9d5e001f`. Snapshot trước/sau17file và manifest ở `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/connected_final_checkpoint`. Đây là bản riêng chưa đủ full gate, không phải commit main.
