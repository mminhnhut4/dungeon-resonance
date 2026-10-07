# Phase1: navigation docs và tests

**Trạng thái:** bản riêng đã chuẩn bị để review; chưa áp phase1 vào bản chính. Baseline là bản chính với 2.072 file sau NPC idle, AI20s, Layout8 và sửa nhãn P02/P03. Những số audit 200 script và hash trong catalog cũ vẫn là snapshot lịch sử; không dùng để chép đè source hiện hành.

## Phạm vi cụ thể

| Thao tác | File | Kết quả |
|---|---|---|
| Thêm | `tests/README.md` | Index tất cả 143 file GDScript hiện có, nhóm điều hướng và cách đọc runner. |
| Thêm | `docs/architecture/PHASE1_DOCS_TESTS_PLAN.md` | Chốt batch nhỏ, checks, backup và điều kiện của batch tiếp theo. |
| Sửa | `docs/architecture/README.md` | Hai link đến plan/index và trạng thái các handoff đã áp. |

Ba file Markdown là toàn bộ delta. Không move script/test/UID/scene/resource, không đổi `run_tests.ps1` hay registry. Các script actor/player/NPC/motor/AI/save/presentation giữ đường dẫn và hash; report, evidence, backup và archive vẫn ở chỗ cũ, đọc qua [history index](../history/README.md).

## Thứ tự khi batch được giao áp

1. Đọc lại live freeze; xác nhận README kiến trúc đúng preimage và hai file thêm còn vắng mặt. Nếu live đã thay đổi, refresh proposal theo hunk; không chép cây snapshot cũ đè live.
2. Backup riêng README trước áp; giữ payload, manifest và SHA. Diễn tập rollback: restore một README, remove đúng hai file thêm trong cây riêng, kiểm baseline và paths.
3. Áp đúng ba file Markdown. Kiểm toàn bộ link, Unicode/case và duplicate path; kiểm 2.071 hash không thuộc README kiến trúc giữ nguyên, kiểm script/test/UID/runner đều unchanged. Sau hai file thêm, source freeze dự kiến 2.074 file.
4. Docs-only: không Godot/import/GPU/fullsuite/60–120Hz. Ghi receipt/checkpoint và phân biệt prepared với applied.

## Kiểm đã chuẩn bị

Inventory tests có 143 file; 97 file được runner tham chiếu tĩnh và 46 file không nằm trong tập tham chiếu đó. Nhóm sau gồm helper/fixture/preview và suite focused mới; không suy ra thiếu coverage hoặc lỗi từ danh sách. Inventory đầy đủ cùng SHA/UID và runner-membership ở bundle review, ngoài imported resource tree. Index nhóm theo filename để tìm nhanh; trước khi chọn/move suite phải đọc contract thực của nó.

## Batch sau phase1

Nếu muốn chuyển tests thành thư mục theo module, trước hết chọn tối đa 3–5 test cụ thể, ghi bảng current→target và UID đi cùng. Tìm mọi literal/dynamic `res://tests/...` trong runner, helper, tools, scenes và docs; kiểm đường dẫn runner dựng từ tên suite. Lập diff sửa refs và kế hoạch kiểm seam trước khi giao apply. Không biến phase1 navigation này thành migration hàng loạt hoặc đổi gameplay.

Runtime leaf `profile_json_spans` và các actor/session vẫn là candidate của [proposal migration cũ](MIGRATION_PLAN.md), chưa thuộc phase1 docs/tests này; cần batch riêng với audit fresh và scope cụ thể.
