# Hai tu sĩ — ảnh riêng và mầm truyện 08/10/2026

Candidate private `sect-path-repair`, chưa ghép main. PNG được tạo qua builtin imagegen; bản gốc, bốn prompt và báo cáo kiểm alpha giữ ở `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/sect_art_staging`. Không sửa ảnh bằng script, không mua/cài công cụ. Hai bản r2 được copy nguyên byte vào `assets/npc/cultivators/`.

| Stable ID | Texture | SHA256 |
|---|---|---|
| `thanh_van_disciple_01` | `thanh_van_disciple.png` | `8C2DF932C0BE53C421EA1B7E81312EDD5AD91D92BF0900064EFD9CD3E0E4749D` |
| `xich_lo_guard_01` | `xich_lo_guard.png` | `56AEEEF27378694050124CF9117BE17178605F9AE663D9B61A1734D3474F6704` |

Cả hai 1024×1536 RGBA. Thanh Vân thanh mảnh, áo ngọc nhạt/ngà/xanh xám và kiếm thẳng; Xích Lô vai lớn, đỏ đất/đồng/giáp tối và đao bản rộng. Alpha≥8 không chạm biên. Hai đế lệch tối đa2px nguồn; head/weapon padding không đều (mép phải đao31px) nhưng không bị cắt. Đây là một pose toàn thân, chưa có atlas hoặc animation đi/chém riêng. Alpha nguồn tối đa254 được giữ nguyên.

`CultivatorCatalog.portrait(id)` trả texture theo đúng identity; actor dùng màu trắng cho thân, giữ tint cũ cho cue chiến đấu. Import mới bật mipmap; kế thừa body60px, alpha foot pivot và flip của `HubNpc`/`EnemySpriteArt`. Không sửa collider, Hurtbox, Hitbox, clock, damage, giá, save hoặc lịch tuần tra. Không thay asset cũ.

`dialogue_lines(id): Array[String]` trả hai đoạn mới theo ID; ID lạ trả mảng rỗng và caller không thể sửa nội dung lần sau. Population owner khác ghép đoạn này vào hội thoại người còn khỏe. Lời đồn dấu niêm tại miếu P03 không khớp hồ sơ bưu trạm B03 là mầm truyện mới, chưa là chứng cứ thủ phạm hoặc một nhiệm vụ. Địa điểm có thật; không hứa bản đồ phái, gia nhập, thuê hay học công pháp chưa có. Không thêm choices/cost/progress/reward.

Kiểm ảnh ngoài engine đã hoàn thành ở staging; đây không thay nghiệm thu native. Test mới `tests/cultivator_art_test.gd` kiểm main→Population binding, texture khác nhau, hash, alpha/padding/mipmap, body60px, foot pivot hai hướng/các pose, capsule không đổi và thoại thật không cấp currency/quest flags. Runtime combat dùng suite cultivator hiện hữu.

Checkpoint09:21UTC: đã đọc raw receipt của root/life agent. `probes/r2_art_import/RUN_RESULT.json`: import headless kết thúc08:57:03UTC, exit0, diagnostics rỗng. `probes/sect_cultivator_art_0858/`: native `sect_progression_visual_probe.gd --native-approved --cultivator-only --expect-mipmaps` kết thúc08:58:16UTC, **32/32 check,6ảnh**, exit0/diagnostics rỗng. Raw nằm dưới thư mục evidence `C:/Users/Admin/Documents/Codex/2026-10-08/sect_path_repair/`. Các check gồm real local FSM/Hitbox, hurt cancel, leash, nonlethal withdrawal và teardown. Root đã xem năm ảnh NPC, xác nhận hai sprite riêng; người viết không tự nhận đã xem cả sáu ảnh native đó.

Focused `probes/r2_repair_cultivator_art/` của root đã chạy **89/89 check**, exit0/diagnostics rỗng: kiểm imported texture/alpha/mipmap/60px/rig và actual healthy dialogue không ghi progress/reward. FullstrictR2 đang do root điều phối; focused này không thay gate. Ảnh tĩnh không chứng minh atlas animation hoặc game feel hoàn chỉnh; human playtest và nghe âm thanh vẫn riêng. Các báo cáo prototype cũ dùng Player sprite mô tả checkpoint trước lần bind ảnh riêng này, không còn là ngoại hình hiện tại của hai stable ID.
