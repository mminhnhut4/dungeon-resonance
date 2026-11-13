# Kiểm lại checkout tích hợp trên Mac, 13/11/2026

## Các mốc source

- `7dc57db`: ảnh AMD thật, kịch bản demo theo rubric mới và nhãn browser/revision chính xác.
- `437827d`: cherry-pick bản sửa save-capacity đã review `77f4c31`. Chỉ thay giới hạn namespace dùng chung và thêm regression; không đổi schema, seal, UID hay giới hạn byte.
- Lượt kiểm dưới đây chạy trên runtime liên kết tới **checkout review tích hợp 437827d**, user directory và database synthetic mới, không dùng save cá nhân. Commit tài liệu/UID/.gdignore tiếp theo không thay runtime logic.

Main không được checkout, merge hoặc sửa. Chỉnh sửa editor chưa commit trong `project.godot` giữ nguyên từng byte và không được stage. Ảnh AMD ở thư mục evidence vẫn mang mốc source chụp `9d82d48`, không đổi nhãn thành ảnh của bản tích hợp.

## Kết quả sau tích hợp

| Kiểm | Kết quả |
|---|---:|
| Import mới | Pass, không script error |
| Owner/save-capacity | 217/217; owner thứ chín và trần 16/17 đúng |
| Tiến trình mới đọc sealed profile/NPC | 42/42 |
| Capsule reader/schema/byte/digest | 38/38 |
| Launcher smoke đúng env | Pass: isolated, chưa tạo profile trước login, main thường giữ nguyên |
| Native Godot → HTTP → SQLite write | 30/30 |
| Native cold restore | 11/11 |
| Native retry/corruption/stale/ownership edge | 32/32 |
| Native menu/input/pause/network | 41/41 |
| API policy/HTTP | 18 pass / 0 fail / **1 PostgreSQL skip** |
| Web unit tests / syntax harness | 3/3 và `node --check` pass |

Các ca owner/capsule chạy headless; các ca lifecycle/menu chạy native Compatibility trên Godot 4.7.2 Mono / Apple M5 Pro. API test chạy bằng .NET 10 đã có với roll-forward Major; không cài thêm runtime và không chứng minh container net9. Native write ghi một mẫu HTTP pending: p95 render interval 14,184 ms, max 61,981 ms, Player đi 329,56 px. Không gọi đó là full-game benchmark hoặc chứng minh hết khựng/crash.

Lượt smoke đầu thiếu `AMD201_API_URL` trong môi trường harness nên assertion tổng hợp trả false; giữ log đó, đặt đúng env rồi chạy lại cùng code đạt. Một lượt backend runner bị sandbox chặn giao tiếp local và đã dừng; chạy lại với quyền thực thi phù hợp đạt 18/1 skip. Không sửa runtime để che hai vấn đề môi trường này. Native còn diagnostic macOS IMK mach-port; không quy thành bug gameplay hoặc bỏ qua trong tuyên bố ổn định.

Evidence local nằm trong nhóm bằng chứng Mac ngày 13/11, thư mục `integrated-20261113-113115`. Không đưa raw log chứa đường dẫn máy, user data hoặc credential vào Git. Bộ ảnh phát cho người dùng chỉ có tài khoản synthetic `@amd.test`, không có mật khẩu/token.

## Trạng thái sử dụng

Bản local review có luồng AMD và một điểm chặn progression đã được kiểm lại. **Chưa là bản release/production hoặc bài cuối kỳ hoàn tất.** Các gate SQL Server/PostgreSQL thực, Docker build/run, Actions của đúng commit, registry digest, PaaS HTTPS/live link, slide nhóm và báo cáo cá nhân vẫn còn theo `DEMO_DIEM_NOI_BAT.md`. Cần full opening-loop playtest/soak và kiểm hiệu năng đủ dài trước tuyên bố ổn định toàn game.

Save có hơn tám scope cần client đã vá; binary cũ với trần tám có thể từ chối. Không hạ client cũ hoặc chép đè save để ép tương thích.
