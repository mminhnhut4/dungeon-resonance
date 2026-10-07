# Kiến trúc để scale — proposal và đích đến

Bộ navigation/audit/proposal này đã được đưa vào bản chính. **Các đường dẫn đề xuất là đích đến; runtime chưa migration.** Snapshot audit trước nhật ký có 2.044 file nguồn; baseline sau nhật ký có 2.047 file, chỉ khác tài liệu. Code/assets của snapshot vẫn nguyên hash. Godot 4.7.2, Compatibility; main là `scenes/maps/prologue_hub.tscn`.

- [Module map và quyền sở hữu](MODULE_MAP.md)
- [Quy ước phát triển](CONVENTIONS.md)
- [Các batch migration và kiểm tối thiểu](MIGRATION_PLAN.md)
- [Catalog 200 script hiện tại → đường dẫn đề xuất](MIGRATION_CATALOG.csv), [JSON đầy đủ kèm UID/hash/dependency](MIGRATION_CATALOG.json)
- [Index báo cáo lịch sử](../history/README.md)

Đọc [quyết định hiện hành](../DECISIONS.md), [trạng thái](../PROJECT_STATE.md) và [nhật ký](<../../nhật ký vấp ngã/README.md>) khi tiếp tục. Các báo cáo gate cũ là lịch sử; không suy từ số test rằng patch đã có trong game. Camp/Guard/Quest, NPC idle, AI aggro20s, geometry hầm đầu và sửa nhãn P02/P03 đã có receipt áp/hậu kiểm riêng. Walk cycle NPC và gallery pursuit vẫn chưa nghiệm thu; xem nhật ký để biết giới hạn. Tài liệu audit này không nhận là runtime đã migration.

Audit thấy 200 script sản phẩm, 189 global class, 845 tham chiếu class/type, 259 literal resource path. Đây là static scan, không phải call graph hoặc chứng minh dependency chạy vòng. 10.199 file/607.835.637 byte ở docs/verification, gồm output và node_modules; cache .godot không được đọc. Bằng chứng và backup gốc không bị xóa/di chuyển.

Catalog UID/hash phản ánh snapshot trước các handoff AI/map/NPC đang chờ. Trước từng migration phải chụp baseline mới và tìm lại cả literal/dynamic path references; không coi hash trong proposal là yêu cầu chép đè live.

## Phase1 docs/tests — chuẩn bị để review

- [Phạm vi ba file và kiểm tối thiểu](PHASE1_DOCS_TESTS_PLAN.md)
- [Index tests tại đường dẫn hiện tại](../../tests/README.md)

Phase1 chỉ tổ chức navigation; việc move tests hoặc runtime cần batch cụ thể riêng.
