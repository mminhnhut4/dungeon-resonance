# Chạy đúng game sau khi giải nén ZIP

## Cách dễ đối chiếu trên Windows

1. Giải nén toàn bộ ZIP mới vào một thư mục riêng. Trong cùng thư mục phải có `project.godot`, `CHAY_GAME.cmd`, `assets`, `addons`, `data`, `scenes` và `scripts`.
2. Mở **CHAY_GAME.cmd**, dán đường dẫn đầy đủ tới Godot **4.7.2 stable** đang có trên máy, rồi Enter. Không cần cài engine thêm nếu đã dùng đúng phiên bản.
3. Đợi bước import hoàn tất. Launcher chạy cố định **main** `scenes/maps/prologue_hub.tscn`; không phụ thuộc scene đang chọn trong editor.
4. Bấm vào cửa sổ game. A/D đi tới cổng bên phải căn cứ, chờ hiện **E · Tiến vào Hầm Ngục (Tầng 1)** rồi nhấn E. Đóng hành trang/thoại đang mở trước khi tương tác cổng.

Launcher dùng **save chơi thử riêng**, mặc định ở `%LOCALAPPDATA%\DungeonResonanceTeamPlay`. Chơi lại bằng cùng launcher tiếp tục bộ save này. Save Godot thông thường của máy không bị xóa hoặc thay thế. Folder `logs/run_...` giữ `launch.txt`, `version.log`, `import.log`, `game.log`; nếu vẫn không vào được, gửi bốn file này cùng tên/chữ hiện tại cổng để đối chiếu.

Có thể truyền đường dẫn engine thay vì nhập:

```bat
CHAY_GAME.cmd "C:\Tools\Godot\Godot_v4.7.2-stable_win64.exe"
```

Đường dẫn ví dụ phải thay bằng EXE thực trên máy. Launcher không cài phần mềm, đổi quyền, thay chính sách bảo mật hoặc sửa Input Map.

## Nếu mở bằng Godot editor

Import **project.godot**, đợi import xong, chọn **Run Project / F5**. Main đúng có node gốc `PrologueGameFlow`, script `GameFlow` và scene `scenes/maps/prologue_hub.tscn`.

`scenes/hub/exterior_hub_room.tscn` là component căn cứ. Chạy riêng component bằng F6 có thể vẫn thấy nhân vật và dòng E ở cổng, nhưng thiếu GameFlow nhận yêu cầu chuyển hầm ngục. Đây là trường hợp đã tái hiện trên bản ZIP; chưa thể kết luận mọi lỗi trên máy thành viên đều do F6.

Lạc Ấn ở gần sân là lối tắt tầng sâu đã mở, không thay cổng chuyến đầu. Hai cổng môn phái ngoài đường bộ mở theo sổ/nhiệm vụ; chúng không phải cổng hầm ngục.

## Những gì đã kiểm tra

Trên ZIP GitHub checkpoint `9c6fe89`, Godot4.7.2/Compatibility, save QA sạch: đi bằng D từ vị trí xuất hiện tới cổng thật, E vào tuyến hầm ngục liên tục, giữ đúng UID và nhân vật có điều khiển. Không cấp đồ, sửa tiến độ, teleport hoặc gọi trực tiếp start_campaign trong phép kiểm này. Chạy riêng component tái hiện cổng không chuyển dù E đã được nhận.

Các phép kiểm dùng sự kiện phím giả lập/headless; không chứng minh bàn phím/focus hoặc bộ save của máy khác đã đúng. Launcher và gói mới có biên bản trong [PORTAL_PACKAGE_VERIFICATION](PORTAL_PACKAGE_VERIFICATION.json). Lượt đóng gói này không chạy lại full strict hoặc GPU; runtime gameplay không thay đổi.

Nếu dùng launcher mà vẫn lỗi, giữ nguyên save/log chơi thử và gửi log. Cần xác minh thông báo lỗi thực trước khi sửa cơ chế lưu, bỏ gate nhiệm vụ hoặc thay phím.
