# Bản chuẩn bị CI / registry / PaaS — chưa thực thi

Workflow `.github/workflows/amd201.yml` có verify trên PR/main: restore lockfiles → policy/HTTP test + PostgreSQL service synthetic → SPA test/build → Docker build. Không cần secret production để chạy verify. Test database của CI có password fixture rõ ràng, không dùng cho dịch vụ thật. Chưa chạy workflow trên GitHub trong lượt này.

Sau khi được phép publish/deploy, owner review workflow và bảo vệ hai environment `amd201-publication`, `amd201-demo`. Các cờ repository `AMD201_PUBLISH_ENABLED`, `AMD201_DEPLOY_ENABLED` mặc định chưa đặt: publish/deploy bị skip. Khi owner cho phép bật cả hai, push **main** đạt verify sẽ publish GHCR bằng `GITHUB_TOKEN` của job và gọi hook Render với image digest của đúng commit. Không cần tạo PAT trong mã. Không bật cờ hoặc tạo secret ở lượt triển khai local hiện tại.

Render template nằm ở `online/deploy/render.service.template.yaml`, không tự áp dụng. Cần image/registry đã được phép, DB PostgreSQL riêng đã được duyệt và DSN Npgsql dạng `Host=...;Database=...;Username=...;Password=...;SSL Mode=VerifyFull`. Không chép URL `postgres://...` thẳng vào cấu hình Npgsql. DSN/hook chỉ nhập trong secret settings được phép; không commit hoặc gửi qua chat.

Template giữ plan free và không tự tạo DB. Chạy `dotnet Dungeon.Api.dll --migrate` bằng cùng image trên approved runner có kết nối DB, trước khi bật service; khi schema không đổi không cần chạy lại. Nếu muốn migration tự động bằng pre-deploy command, cần chọn một plan hỗ trợ tính năng đó và phê duyệt chi phí trước. Không âm thầm nâng plan. [Render blueprint](https://render.com/docs/blueprint-spec) và [deploy hooks](https://render.com/docs/deploy-hooks) là tài liệu tham chiếu cho cấu hình; đã đọc nhưng chưa xác minh bằng tài khoản cloud.

Demo phải thu được bằng chứng thật, chưa có trong candidate:

1. Push commit được phép lên main; ghi SHA và URL Actions run.
2. Verify PostgreSQL không skip, image build pass; ghi digest GHCR và kết quả publish.
3. Hook response chỉ xác nhận yêu cầu deploy. Chờ PaaS báo deploy thành công, kiểm `/health/ready` và SPA HTTPS, ghi link deploy thật.
4. Tạo account synthetic mới; Godot login → chơi → về Hub lưu → thoát → mở lại → tải cùng account; SPA hiển thị cùng revision. Account khác không thấy dữ liệu.
5. Ghi lỗi mạng/409/corruption test và giới hạn còn lại; không dùng save cá nhân hoặc gọi SQLite QA là PostgreSQL pass.

Chưa có link deploy, registry image, Actions run hay demo push→build→deploy đã chứng minh. Docker/PG installation và các hành động cloud vẫn cần quyền. SDK net9 hiện phục vụ môi trường local; cần nâng runtime được hỗ trợ trước public production, sau một lượt upgrade được phê duyệt và kiểm tương thích.
