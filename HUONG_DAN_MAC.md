# Chạy Dungeon Resonance AMD trên Mac

Bản nguồn: review/amd201-20261105, commit f7cb7be56a0ee5e7bf371929e614b4e74e84f949. Cài ngày 13/11/2026. Đây là bản AMD review, không phải xác nhận toàn game đã hoàn thiện.

1. Trong Finder, mở Documents → Dungeon Resonance → CHAY_AMD_MAC.command.
2. Chờ import asset và API cục bộ. Cửa sổ Terminal phải còn mở trong lúc chơi.
3. Ở màn đăng nhập, tạo tài khoản demo bằng email thử và mật khẩu thử; không dùng mật khẩu thật. Sau đó đăng nhập.
4. Dùng A/D hoặc mũi tên để di chuyển, Space để nhảy, Shift để lướt. Chuột trái/J đánh, chuột phải/I ghép bùa/tung phép. E tương tác.
5. F9 mở menu cloud, Esc đóng. Chọn Lưu khi ở Hub; thoát rồi mở lại và tải bản đã lưu để minh họa khôi phục. Tải xuống tạo slot mới, giữ slot trước.
6. Mở http://127.0.0.1:5086/ trên trình duyệt và đăng nhập cùng tài khoản để xem tiến trình.
7. Đóng game sẽ dừng API nếu launcher đã mở API đó. Không có service tự chạy khi bật máy.

## Phạm vi

- API demo dùng SQLite riêng trên Mac, không phải PostgreSQL. Cùng email trên PC không truy cập được database cục bộ Mac và ngược lại. Không gọi đây là đồng bộ qua Internet.
- Bản lưu AMD mới ở ~/Library/Application Support/Dungeon Resonance AMD201 Mac. Bản lưu game cũ được giữ nguyên.
- Godot dùng bản 4.7.2 Mono đang có ở Downloads/Godot_mono.app. Backend net9.0 chạy bằng .NET10 đã có, với DOTNET_ROLL_FORWARD=Major trong launcher; không cài thêm .NET9 hết hỗ trợ.
- Launcher tạo project/cache riêng trong `.amd-mac-runtime` (đã gitignore), dùng liên kết tới tài nguyên của checkout và tên dữ liệu AMD riêng. `project.godot` gốc và save của launcher thường không đổi. Không đổi gameplay.
- Logs trong thư mục dữ liệu AMD/launcher-logs. Nếu API chưa lên, giữ log để kiểm tra; không xóa dữ liệu hay cài lại tùy tiện.

## Kiểm tra thực tế trên Mac ngày 13/11

Godot import và smoke dữ liệu riêng đạt; capsule 38/38, web 3/3 và build đạt. Native Godot qua API SQLite: ghi 30/30 và khởi động lại/tải 11/11 đạt. Bản Mac dùng Apple M5 Pro, Compatibility/OpenGL. Log native còn hai dòng macOS `getApplicationProperty: called with invalid property`; mẫu ngắn HTTP pending có khoảng frame lớn nhất 167,597ms, nên chưa kết luận toàn game mượt hay hết crash lịch sử. PostgreSQL, Docker, deployment chưa được kiểm trong lượt cài Mac.

Bản project cũ có chỉnh sửa chưa commit đã được chuyển nguyên vẹn vào Thùng rác với tên `Dungeon Resonance old 2026-11-13`, không xóa vĩnh viễn. Đừng dọn Thùng rác trước khi đã kiểm tra mọi dữ liệu cần giữ. Bản lưu cũ ở `~/Library/Application Support/Godot/app_userdata/Dungeon Resonance` vẫn giữ nguyên.


## Chuẩn bị trên một Mac khác

Cần Git, Godot 4.7.2 stable (đặt GODOT_EXE nếu không ở Downloads/Godot_mono.app), .NET SDK 10 và Node 24. Launcher không tự cài phần mềm và không tự tải dependency.

Trong thư mục gốc checkout, chạy một lần:

```sh
dotnet restore online/tools/Dungeon.QaHost/Dungeon.QaHost.csproj --locked-mode
dotnet build online/tools/Dungeon.QaHost/Dungeon.QaHost.csproj --no-restore -c Release
npx --yes pnpm@11.25.0 --dir online/web install --frozen-lockfile --ignore-scripts
npx --yes pnpm@11.25.0 --dir online/web test
npx --yes pnpm@11.25.0 --dir online/web build
./CHAY_AMD_MAC.command --smoke-test
./CHAY_AMD_MAC.command
```

Smoke-test chỉ kiểm import, cache, vùng dữ liệu AMD riêng và trạng thái trước đăng nhập; không kiểm API/PostgreSQL hoặc đo độ mượt. Để dựng lại sau đổi source API/web, lặp các bước build tương ứng. Không dùng dữ liệu thật trong QA host. Không thay cấu hình .NET production chỉ vì QA Mac chạy được.

Launcher từ chối khởi động khi cổng 5086 đang có server khác; đóng phiên AMD trước rồi mở lại. Không tự dùng chung server đang chạy, tránh gửi tài khoản/save vào nhầm database.
