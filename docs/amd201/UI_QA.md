# Cloud menu — kiểm native và đối chứng giới hạn 30/10

Đổi trong `scripts/online/amd_boot.gd`: panel kín, cuộn khi cần, nằm dưới HUD; toggle góc dưới, F9/Esc; focus ring chỉ các control hiện/enable. Khi mở, giữ process mode gốc của GameFlow và các override con, tạm cho con kế thừa rồi dừng đúng subtree. HTTP không thuộc subtree đó và tiếp tục chạy. Khi đóng trả lại mode gốc, giữ khóa controls của owner khác, dùng resume guard2frame sẵn có và xóa action đang giữ để không lọt click/phím. Không sửa Player/FSM/motor/stats/save writer hay normal entrypoint.

Native gate cuối `amdui5`:41PASS/0FAIL/exit0, không ERROR/WARNING. Đã xem ảnh thật 1152×648 và960×540: HP/mana/tài nguyên và các nút HUD phía trên vẫn đọc được. Kiểm mouse open/close, F9/Esc4vòng, Tab focus, Space kích hoạt Refresh qua HTTP, held move/cast/attack không vào thế giới, Tab không mở inventory phía sau, fresh move/cast sau đóng, modeALWAYS của inventory được khôi phục, khóa controls của owner khác giữ nguyên. `amdcold4`:11PASS/exit0, slot restore mới vẫn hoạt động dưới modal; launcher smoke mới PASS, profile không tạo trước login.

Lượt đầu bắt được Tab xuyên qua inventory cũ dùng PROCESS_MODE_ALWAYS. Sửa trong modal owner, không sửa inventory core. Lượt focus trung gian thiếu focus ban đầu; bổ sung ring và grab focus hợp lý. Error `rp_node null` thuộc assertion harness gọi is_ancestor_of(null), stack chỉ đúng dòng test; đã thêm null guard. Giữ toàn bộ log lỗi, không gọi đó là engine crash hay xóa evidence.

Đối chứng `amduiperf1`:21PASS/exit0/no diagnostics, chỉ4đoạn2giây trong một native process. Cùng Godot4.7.2/Compatibility/1152×648, cap120FPS/physics60Hz, clone byte-identical profile+NPC, seed20261030, cùng Hub và thao tác đi phải1s/trái1s. Staging/auth và30physicsframe warm-up nằm ngoài mẫu. Start/end/maxX của4lượt trùng nhau, không cast/hitstop. Baseline là snapshot trước UI, chỉ đổi class name để test cùng project; không phải nhánh main engine khác. Lượt HTTP gọi endpoint delay thật của QA host loopback, chờ xuyên242renderframe và hoàn tất sau đó. Setup danh tính của phép đo là fixture synthetic, không kiểm auth/DB ở phép đo này.

| Điều kiện | Frame | p50 ms | p95 ms | Max ms | >25ms |
|---|---:|---:|---:|---:|---:|
| UI trước sửa, đóng |241|7,963|8,989|11,817|0|
| UI mới, đóng |241|7,946|9,028|12,482|0|
| UI mới + HTTP pending |242|8,061|8,909|12,693|0|
| UI trước sửa, lặp kiểm drift |241|7,952|9,086|12,126|0|

P95 mới tăng0,039ms so với baseline đầu, nhỏ hơn drift baseline0,097ms. Không thấy overhead render đáng kể trong đoạn Hub này. Mỗi điều kiện chỉ một đoạn rất ngắn, không suy ra ý nghĩa thống kê hoặc hiệu năng combat/I/O/cloud Internet. Không chạy thêm vòng để săn số đẹp. Phép đo hoàn tất trước bổ sung focus ring cuối; ring chỉ chạy lúc mở/đóng hoặc cập nhật buttons, không chạy trong interval đóng đã đo. Menu mở chủ ý dừng world nên không dùng FPS khi mở để tuyên bố tăng hiệu năng gameplay.

PostgreSQL vẫn chưa cài/kiểm; QAhost là SQLite synthetic. Không có Docker build, Actions run, publish hoặc deploy. Crash/stutter lịch sử chưa được chứng minh sửa. Không upload ảnh; evidence giữ local trong thư mục QA ngoài source candidate.
