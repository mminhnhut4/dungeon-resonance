# Ba icon rune hiện hữu — áp dụng 2026-10-04

Gói local `Dungeon-Resonance-Missing-Icons-v1.zip` có SHA256 `a1fe92b8dd47d65c35286c15e7d632f4d0352c084eb30a9a1c6b4a4183d23834`, CRC và đường dẫn sạch. Chỉ nhập ba PNG lightning/ice/poison và metadata import; không nhập trap/starter_pants. Pixels/alpha master1254×1254 giữ nguyên, import lossless có mipmap trong project Temp chỉ ba ảnh. Không import editor toàn dự án.

`ItemArtCatalog.RUNE_ICONS` giữ Fire/Wind và thêm đúng ba ID. HUD bỏ nhánh riêng chỉ Fire/Wind, đọc cùng registry và giữ palette. Unknown/empty vẫn dùng fallback phù hợp; Bùa giữ ô trống, HUD giữ emblem trống. Không đổi gameplay, recipe/slot capacity/giá/UID/save/movement/collision/floor-return. Một fixture legacy HUD giữ31 assertions, thay hai kỳ vọng generic shield bằng texture/palette đúng của ba rune.

Bản riêng và bản chính đều headless39/39 + regression HUD31/31, exit0/stderr rỗng. Một lượt GPU bản riêng63/63, tám ảnh thực ở800×600/1280×720, exit0/stderr rỗng; đã xem đủ tám ảnh. Bùa hiện silhouette và tên Lôi/Băng/Độc, HUD44px giữ đúng palette. Chi tiết master không đọc hết ở Bùa28px; không claim final art polish. Kho chỉ giữ vật liệu và shop giữ danh mục trang bị hiện hữu, không có giao dịch ba rune mới. Snapshot inventory/coins không đổi sau các view và native install/remove.

Backup trước ghi gồm ba source/test và PROJECT_STATE/nhật ký; rollback source restore3/remove6 đã diễn tập. Hậu kiểm hash giữ numeric seal2 reader, TravelerR3, floor-return, guide/combat. Không fullsuite, journey rerun,120Hz, upload, publishing, installs hay save người dùng.

Lịch sử QA được giữ: probe r1 dùng Image.has_alpha không có trong engine; r2 ternary tạo Array chưa typed. Cả hai dừng/timeout, không tính PASS. Harness cuối dùng get_format/alpha pixels và Array[Vector2i] khởi tạo trực tiếp; r3 sạch. Gói từng thiếu local nay đã nhận đúng SHA; không trộn gói Item-Icons-v1 khác hash. Native crash lịch sử của các milestone trước chưa có kết luận sửa.

Các gap khác giữ nguyên: ba NPC vector, Golem body cũ, Traveler art tạm, coverage animation/phòng ngoài P01, material/parry audio và natural20–30min pace. Automated journey/checkpoint2094 vẫn là bằng chứng runtime cũ có kiểm soát; icon delta này không biến toàn opening thành hoàn chỉnh.
