# Mở và thao tác bản AMD201 - hướng dẫn cho team

Áp dụng cho nhánh `review/amd201-20261105` của `mminhnhut4/dungeon-resonance` trên Windows. Đây là bản source thử nghiệm; không phải file game cài một lần là chạy.

## 1. Hiểu đúng bản đang dùng

Bản hướng dẫn này dùng **API QA SQLite trên máy của bạn**, game Godot và cổng React. Các luồng này đã được kiểm local. PostgreSQL thật chưa có kết quả vì bước tạo role/credential còn chờ phê duyệt; Docker, Actions và deploy Internet chưa được xác minh.

Nút “cloud” hiện lưu vào API local. Mỗi máy có dữ liệu thử riêng; cùng email trên hai máy không tự đồng bộ với nhau. Không dùng tài khoản, mật khẩu hay save cá nhân thật cho bản QA.

## 2. Chuẩn bị phần mềm

- Windows, PowerShell; Git nếu chọn clone.
- Godot **4.7.2 stable**, Compatibility. Repo không kèm engine. Ghi lại đường dẫn đầy đủ tới file `.exe` đã giải nén.
- **.NET SDK 9** để biên dịch API, không chỉ .NET Runtime.
- Node.js **24** và npm/npx đi kèm. Các lệnh dưới dùng pnpm **11.25.0** qua npx, không cần cài pnpm toàn máy.

Kiểm trong PowerShell: `dotnet --list-sdks`, `node --version`, `npx --version`. Nếu không nhận lệnh, hoàn tất cài phần mềm rồi mở cửa sổ PowerShell mới. Không đổi ExecutionPolicy hoặc tắt bảo vệ máy để chạy bản thử. Môi trường .NET9 cần được nâng có kiểm thử trước production.

## 3. Lấy đúng source

```powershell
git clone --branch review/amd201-20261105 --single-branch https://github.com/mminhnhut4/dungeon-resonance.git
cd dungeon-resonance
Test-Path .\project.godot
```

Lệnh cuối phải in `True`. Nếu không dùng Git, mở nhánh trên GitHub, chọn Code → Download ZIP, giải nén rồi mở PowerShell ngay trong thư mục có `project.godot`. Không chạy trong thư mục ZIP hoặc thư mục cha của source.

## 4. Chuẩn bị API và web lần đầu

Từ thư mục source, chạy lần lượt. Restore/install cần Internet lần đầu; dừng nếu một lệnh báo lỗi.

```powershell
dotnet restore online/tools/Dungeon.QaHost/Dungeon.QaHost.csproj --locked-mode
dotnet build online/tools/Dungeon.QaHost/Dungeon.QaHost.csproj --no-restore
npx --yes pnpm@11.25.0 --dir online/web install --frozen-lockfile --ignore-scripts
npx --yes pnpm@11.25.0 --dir online/web build
```

Build web tạo nội dung cho API phục vụ. Không cần mở Vite hoặc cài PostgreSQL cho luồng QA này. Không chạy `--migrate` để thay thế các bước QA trên.

## 5. Cửa sổ PowerShell A: bật API QA

Vẫn tại thư mục source, chạy:

```powershell
$projectDir = (Get-Location).Path
$qaData = Join-Path $projectDir 'AMD201Data\api-qa'
New-Item -ItemType Directory -Path $qaData -Force | Out-Null
Set-Content -LiteralPath (Join-Path $projectDir 'AMD201Data\.gdignore') -Value ''
$env:DUNGEON_AMD_QA_ROOT = $qaData
$env:ASPNETCORE_ENVIRONMENT = 'Testing'
$env:ASPNETCORE_CONTENTROOT = Join-Path $projectDir 'online\src\Dungeon.Api'
dotnet "$projectDir\online\tools\Dungeon.QaHost\bin\Debug\net9.0\Dungeon.QaHost.dll"
```

Giữ cửa sổ A chạy. Mở trình duyệt tới **http://127.0.0.1:5086/**; phải thấy trang đăng nhập Dungeon Resonance. Địa chỉ `/health` dùng để kiểm API có phản hồi; nó không chứng minh đang dùng PostgreSQL.

## 6. Cửa sổ PowerShell B: mở game AMD

Mở cửa sổ mới trong cùng thư mục source. Thay đường dẫn ví dụ bằng file Godot thật trên máy bạn:

```powershell
.\Run-AMD201.ps1 -GodotPath 'C:\Tools\Godot_v4.7.2-stable_win64.exe'
```

Launcher tự chạy import Godot trước khi mở game. Lần đầu hoặc khi thiếu cache sẽ lâu hơn; chờ thông báo, không mở nhiều launcher cùng lúc. Nếu import lỗi, game không được mở; xem log trong `AMD201Data\launcher-logs`, sửa lỗi được báo rồi thử lại. Không cần tự xóa cache hoặc mở Godot Editor/F5.

Launcher tạo `AMD201Data` riêng cho bản AMD. Nếu thấy Hub ngay mà không qua màn tài khoản, có thể bạn đã dùng F6/F5 hoặc mở entry game thường; hãy dùng launcher ở trên. `CHAY_TEAM_TEST.cmd` là bản mở khóa test khác, không phải luồng tài khoản AMD.

Trong game, nhập email thử của riêng mình và mật khẩu 12-128 ký tự, chọn Đăng ký. Sau thông báo thành công, nhập lại mật khẩu rồi chọn Đăng nhập. Không gửi mật khẩu trong nhóm hoặc báo cáo lỗi.

## 7. Điều khiển và menu

| Thao tác | Phím / chuột |
|---|---|
| Đi trái/phải | A/D hoặc mũi tên trái/phải |
| Nhảy | Space hoặc W |
| Lướt | Shift hoặc K |
| Đánh cận chiến | Chuột trái hoặc J |
| Cast bùa/phép | Chuột phải hoặc I; cần trạng thái, mana, cooldown hợp lệ |
| Ngắm | Di chuyển chuột |
| Tương tác gần đối tượng | E |
| Hành trang / bùa | Tab |
| Bản đồ / nhiệm vụ | M |
| Tài khoản / Cloud | F9 hoặc nút góc dưới phải |
| Đóng menu Cloud | Esc hoặc Đóng |

Trong menu Cloud, Tab/Shift+Tab và phím mũi tên đổi focus, Space kích hoạt nút đang chọn. World tạm dừng khi menu mở; HTTP vẫn chạy. Đóng menu để chơi tiếp, kể cả lúc đang chờ mạng. Nếu hành trang/hội thoại khác đang mở, đóng nó trước khi dùng menu Cloud. Bản AMD giữ progression thường; không mặc định mở mọi map hay cấp mọi bùa.

## 8. Demo tài khoản - lưu - tải - xem web

1. Đăng nhập trong game; đóng menu bằng Esc, thử đi và cast. Không cần đi hết dungeon để demo AMD.
2. Trở về Hub, đóng hội thoại/hành trang. F9 → **Lưu Hub lên cloud / thử lại hàng chờ**. Chờ thông báo lưu thành công và ghi revision. Không demo upload giữa chuyến đi.
3. Trên web local, đăng nhập cùng tài khoản. Đối chiếu revision, tài nguyên và dữ liệu hiển thị. Chọn Làm mới nếu game vừa lưu.
4. Đóng game, giữ API A chạy. Mở lại bằng launcher, đăng nhập cùng tài khoản rồi chọn **Tải cloud · giữ bản local cũ**. Kiểm thông báo thành công. Game tạo slot mới và giữ bản cũ, không khôi phục HP/cooldown giữa chuyến.
5. Tại Hub, đăng xuất rồi đăng nhập tài khoản thử khác: không được thấy tiến trình của tài khoản đầu. Trên máy mới, tải cloud trước khi ghi tiếp để tránh đè bản đã lưu; lưu ý API local của máy khác là database khác.
6. Có thể đóng rồi bật lại API theo bước 5 để tiếp tục dữ liệu SQLite QA. Không xóa hoặc di chuyển `AMD201Data` trong khi API/game đang chạy.

## 9. Lỗi thường gặp

- **Không nhận dotnet/node/npx:** thiếu phần mềm hoặc terminal chưa nhận PATH; mở terminal mới và kiểm phiên bản. Không cần cài Docker để làm demo QA này.
- **Không tìm thấy Godot/sai phiên bản:** sửa `-GodotPath` tới đúng EXE4.7.2; launcher không tự tải engine.
- **Import thất bại:** giữ log `AMD201Data\launcher-logs` và gửi bước tái hiện đã che đường dẫn riêng. Không bỏ qua lỗi để mở game; không gửi cả thư mục dữ liệu cá nhân.
- **Web không vào được hoặc game báo network:** kiểm cửa sổ A, địa chỉ5086 và log lỗi. Nếu cổng đang được ứng dụng khác dùng, dừng đúng tiến trình của mình hoặc nhờ người phụ trách, không kill bừa.
- **Web404/trang trắng:** chạy lại build web ở bước4; `ASPNETCORE_CONTENTROOT` phải trỏ tới thư mục API source. Khởi động lại API sau build nếu cần.
- **Không đăng nhập được:** đăng ký tài khoản trên chính API local này; kiểm mật khẩu và thông báo lỗi. Nếu bị giới hạn số lần thử, chờ rồi thử lại.
- **Lưu/tải bị từ chối:** về Hub, đóng menu game khác; đọc thông báo. Với xung đột revision, giữ dữ liệu local và tải cloud để đối chiếu. Không sửa tay JSON, seal hoặc database để ép qua lỗi.
- **Không cast được:** đóng menu, kiểm mana/cooldown và tổ hợp bùa. Kiểm phím I/chuột phải; không coi mọi lần bấm đều phải phát phép.
- **PowerShell chặn script:** ghi lại thông báo để người phụ trách kiểm chính sách máy; không dùng lệnh bypass hay thay ExecutionPolicy theo hướng dẫn không rõ nguồn.

## 10. Dừng và gửi lỗi cho team

Lưu ở Hub nếu cần, đăng xuất rồi đóng game. Tại PowerShell A bấm **Ctrl+C** để dừng API. Đóng trình duyệt. Dữ liệu QA được giữ cho lần sau; không commit `AMD201Data`, log chứa dữ liệu riêng hoặc mật khẩu.

Khi báo lỗi, gửi branch/commit, bước tái hiện, thông báo đã che thông tin riêng, và xác nhận đang dùng AMD hay TEAM TEST. Không nói PostgreSQL/deploy đã pass vì demo SQLite chạy được.

## Phạm vi đã xác minh

Source của hướng dẫn đã đối chiếu với launcher, QA host và InputMap. Kiểm thêm cho hướng dẫn: restore/build QA host pass, web install giữ lockfile và kiểm nguồn gói pass, build web pass; API khởi động với thư mục QA mới, `/health/ready` và trang web trả HTTP200 rồi đã dừng. Web được kiểm bằng pnpm CLI11.25.0 sẵn có; chưa chạy nguyên lệnh npx cài mới trên một máy Windows khác.

Gói review đã import Godot sạch; backend9pass/1PGskip, web3test pass. Các bằng chứng trước đó gồm native menu41/cold restore11 và demo browser6pass, dùng SQLite synthetic. Chưa chứng minh cài đặt sạch trên mọi máy hoặc toàn bộ hành trình ổn định. PostgreSQL thật, Docker/CI/deploy và crash/khựng lịch sử vẫn còn giới hạn như báo cáo AMD.

Giới hạn upload mới khớp reader game: profile 524.288 byte, NPC 32.768 byte UTF-8. Bản cloud cũ vẫn được API giữ/đọc nguyên văn; nếu vượt trần reader, game từ chối tải và giữ local, không tự cắt hoặc sửa save.

Kiểm tập trung sau sửa ngày05/11: source sạch tự import, thiếu class cache được khôi phục và lỗi asset import chặn mở game; backend18pass/1PGskip, capsule38pass, native lưu30pass và cold restore11pass qua SQLite. Chưa phải kiểm toàn bộ game hoặc PostgreSQL.
