# AMD201 — Nhóm 3: Nhựt, Khánh, Nam

Candidate triển khai ngày 30/10/2026. Luồng Godot–HTTP–SPA đã kiểm bằng host QA SQLite. **Chưa hoàn tất end-to-end PostgreSQL và chưa deploy.** Không dùng dữ liệu thật để demo.

## Kiến trúc

Godot 4.7.2 → HTTP bất đồng bộ → một ASP.NET Core Web API (net9.0) → EF Core/Npgsql/PostgreSQL. React/Vite SPA được phục vụ cùng origin bởi API, dùng chung tài khoản. Chưa có yêu cầu môn học buộc chia nhiều microservice độc lập; ranh giới account/progress nằm trong một API gọn.

Password dùng ASP.NET Identity PasswordHasher (300.000 vòng), token ngẫu nhiên 256 bit chỉ lưu hash ở DB, hạn 8 giờ, logout thu hồi. Token client chỉ giữ trong bộ nhớ. Owner lấy từ session server; không có tham số user ID để đọc progress người khác. Đây là backup riêng, **không phải máy chủ chống gian lận**. Cần HTTPS khi triển khai ngoài loopback; chưa triển khai email verification/password recovery/MFA.

Profile và NPC đi cùng capsule opaque UTF-8, có SHA-256, giới hạn dung lượng/schema. Backend giữ revision + receipt idempotency trong transaction. Godot giữ hàng chờ không chứa credential để retry đúng operation sau mất phản hồi. Không tự đồng bộ mỗi frame. Tải về tạo slot mới, gọi reader/seal/UID của game trước khi đổi active pointer, giữ slot cũ. Core ProfileCommitWriter/journal/seal không đổi. Save thường và TEAM TEST không dùng đường vào này.

## Chạy khi đã có PostgreSQL được phê duyệt

Cần SDK .NET 9, Node 24, pnpm 11.25.0 và PostgreSQL; không có bước tự cài system software. SDK/runtime hiện dùng sắp hết hỗ trợ trong tháng 11/2026: cần kế hoạch nâng .NET trước deployment thật; lượt này chưa đổi SDK máy.

```powershell
cd online
dotnet tool restore
dotnet restore tests/Dungeon.Api.Tests/Dungeon.Api.Tests.csproj --locked-mode
pnpm --dir web install --frozen-lockfile --ignore-scripts
pnpm --dir web test
pnpm --dir web build
# Cung cấp ConnectionStrings__Game qua môi trường riêng, không ghi password vào repo/log.
dotnet run --project src/Dungeon.Api -- --migrate
dotnet run --project src/Dungeon.Api -- --urls http://127.0.0.1:5086
```

Mở `http://127.0.0.1:5086/` cho SPA. Từ root game:

```powershell
.\Run-AMD201.ps1 -GodotPath '<Godot 4.7.2 stable executable>'
```

Launcher tạo vùng `AMD201Data` riêng trước khi Godot khởi động. Nhập cùng email trong game và SPA. Lưu/tải ở Hub; chuyến đi giữ cơ chế bank/return hiện có. Đăng nhập trên máy mới **không tự ghi local rỗng lên cloud**. Normal launcher/main scene không đổi.

Launcher AMD nay chạy import headless tăng dần trước mỗi lần mở để tạo/khôi phục cache class và asset của source checkout. Chờ đúng tiến trình Windows kết thúc; import có lỗi hoặc không tạo được class cache sẽ chặn mở game. Log nằm trong `AMD201Data/launcher-logs`. Không sửa launcher thường hoặc cơ chế lưu lõi.

Giới hạn capsule mới tính theo byte UTF-8, khớp reader hiện hành: profile **524.288 byte**, NPC **32.768 byte**; tổng tối đa **557.056 byte**. API từ chối upload quá ngưỡng bằng HTTP413 trước khi ghi DB. Không đổi schema, seal, revision hay nội dung file. GET dùng đường đọc tương thích cho bản đã lưu theo tổng trần cũ1MiB, giữ nguyên bytes/digest và không sửa DB; client vẫn từ chối file vượt trần reader, giữ slot local. Không tự cắt/chuyển đổi bản cloud cũ hoặc nới reader để nhận nó.

Cold restore đã sửa: số nguyên JSON được Godot parse thành float nên phép membership mảng int từ chối schema hợp lệ; client nay kiểm đúng miền số nguyên, không ép chuỗi/bool/số lẻ. Retry hàng chờ cũng chuẩn hóa số envelope thành integer token cho ASP.NET, giữ nguyên chuỗi profile/NPC. Regression invalid type/schema/digest/seal vẫn từ chối.

Menu cloud đặt dưới vùng HUD, nút ở góc dưới phải. **F9** mở, **Esc/Đóng** trở lại game; Tab/Shift+Tab và phím mũi tên đi trong các nút của menu. Game tạm dừng khi menu mở, HTTP vẫn chạy; có thể đóng menu để chơi trong lúc chờ mạng. Pause chỉ sở hữu nhánh GameFlow, giữ và trả lại các process override của UI cũ, không đổi global pause, combat FSM hay chỉ số. Click đóng không trở thành đòn đánh. Native ở1152×648 và960×540, mở/đóng lặp, focus/keyboard/mouse, di chuyển/cast sau đóng và quyền khóa của owner khác đã kiểm: **41/41 pass**. Cold restore sau thay đổi UI **11/11 pass**, launcher smoke pass. Xem [UI_QA.md](UI_QA.md).

Kiểm launcher không đăng nhập bằng `-SmokeTest -DataRoot '<thư mục QA mới>'`. Smoke test xác nhận vùng lưu tách biệt, chưa tạo profile trước login và main scene thường không đổi. Token server có hạn 8 giờ; khi mạng mất, logout xóa token client nhưng có thể chưa thu hồi được phiên server. Không lưu mật khẩu/token vào profile hay browser storage.

## Kiểm tra

Kiểm lại sau sửa launcher/giới hạn ngày05/11: backend **18 pass / 1 PostgreSQL skip**; Godot capsule **38/38 pass** qua reader thật, gồm dưới/đúng/trên ngưỡng cả hai file. Source sạch tự import và smoke pass; thiếu riêng class cache được khôi phục. Fixture asset import lỗi chặn game trước khi chạy. Native với API SQLite: write **30/30**, cold restore **11/11**, exit0. Bản cloud cũ quá ngưỡng mới vẫn GET nguyên bytes; upload quá ngưỡng trả413 và không đổi revision, capsule hay receipt; upload hợp lệ tiếp theo vẫn hoạt động. Đây là regression tập trung, không phải kiểm PostgreSQL hoặc toàn game.

`dotnet test online/tests/Dungeon.Api.Tests/Dungeon.Api.Tests.csproj` có 9 policy/HTTP test dùng SQLite *chỉ trong test host*. Test PostgreSQL riêng bị skip khi thiếu `AMD201_TEST_PG`; **không tính skip là pass**. Khi được phép có test DB synthetic, set biến đó rồi chạy filter `PostgresTests`; test tạo/xóa schema `qa_<guid>` trong DB test, kiểm migrations, concurrent writers, idempotency và ownership. Không trỏ DB thật.

`online/tools/Dungeon.QaHost` là executable QA SQLite tách khỏi production; không nằm trong Docker image. Chỉ bind loopback 5086 và cần `DUNGEON_AMD_QA_ROOT` trỏ thư mục QA có sẵn. Có endpoint delay 2 giây chỉ phục vụ kiểm không chặn Player. Nó không chứng minh PostgreSQL integration.

Kết quả cuối vòng local: API 9 pass/1 PG skip; web request 3 pass; production SPA build pass; Edge headless 6 pass; Godot import pass; capsule 32 pass; native write 30 pass, cold-read 11 pass, edge 32 pass, combat 14 pass; launcher smoke pass. Native gate cuối exit0, không ERROR/WARNING. Các log fail trước sửa được giữ riêng, không xóa/đổi thành pass. Lỗi guard restore/retry là lỗi client đã sửa; các lỗi combat probe ban đầu là harness input/observation, không thay runtime để qua test.

Đo 1,1 giây HTTP pending cũ: Player đi345,56px, p50 2,655ms, p95 5,598ms, max63,554ms. Đo combat cuối:6 cast, HP115→26,7, 420 physics-frame intervals p50 16,666ms/p95 16,989ms/max22,053ms;28 frame có hitstop chủ ý. Đây là interval physics, không phải render FPS và không phải đối chứng hiệu năng trước/sau. Kịch bản/input hai probe đầu chưa tương đương nên không dùng làm baseline combat. Không dựng lại collector dài và không kết luận khựng/crash lịch sử đã sửa. Writer/engine giữ nguyên.

Vòng UI sau đó có đối chứng hẹp từ snapshot ngay trước sửa menu, cùng cặp save/seed/route Hub/engine/cấu hình: p95 render-interval trước8,989ms, mới đóng9,028ms, mới+HTTP pending8,909ms, baseline lặp9,086ms. Không frame>25ms trong4mẫu2giây. Chưa thấy overhead đáng kể ở route này; không phải kết luận mọi combat/save hoặc crash cũ đã hết. Chi tiết và giới hạn ở UI_QA.

## Docker/DevOps và giới hạn bàn giao

`online/Dockerfile` và `compose.yaml` đã viết, **chưa build/run** do Docker chưa có phép cài. Compose chỉ expose API loopback, DB nội bộ, secret file do người dùng cung cấp qua `AMD201_PG_PASSWORD_FILE`; không có password production mặc định. Migrate là bước riêng trước API. Đã tạo EF migrations và SQL idempotent đủ Accounts/Progress/Receipts/Sessions; chưa chạy SQL trên PG thật.

Workflow `.github/workflows/amd201.yml` và Render image-service template đã có, xem [DEPLOYMENT.md](DEPLOYMENT.md). YAML parse và static guards đã kiểm; **chưa chạy Actions, Docker, publish hoặc deploy**. Publish/deploy bị chặn khi chưa bật các cờ owner. Chưa có link deploy thật hoặc demo push→build→deploy. Những hành động cloud và runtime installation cần quyền riêng; không tạo account/credential/cloud service ở lượt này.

Nguồn chính thức PostgreSQL Windows: https://www.postgresql.org/download/windows/ (liên kết installer/ZIP EDB). Sau quyền cài nội bộ ngày30/10, đã cài **binaries server/CLI17.11** trong thư mục QA ngoài candidate, không pgAdmin/StackBuilder, không service/PATH/autostart. Bốn lệnh version pass. **Chưa chạy initdb, tạo role/password hoặc mở listener**, nên chưa có PostgreSQL integration pass. Cấu hình đề xuất là cluster synthetic riêng tại cổng loopback127.0.0.1:55432, SCRAM, bootstrap admin chỉ trong cluster và app role không superuser. Các hành động credential/ACL riêng cần xác nhận theo phạm vi đã giao. Không gửi password qua chat.
