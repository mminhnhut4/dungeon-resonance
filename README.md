# Dungeon Resonance — nguồn review

| Mục | Giá trị |
|---|---|
| Nhánh review | `review/opening-tactics-hold-20261020` |
| Commit nguồn dùng để đối chiếu | `04785c466672d65bc7e784ed3c9b21bc8613815b` |
| Nền snapshot | `6d73a61d640fa7d564cce30a55afc2f8afef260f` |
| Trạng thái | **HOLD: thử nghiệm tactics/poise chưa đạt mục tiêu** |
| Số file nguồn trong phạm vi snapshot | 90 |

Snapshot nghiên cứu riêng. Có 40 lượt native (5 seeds, 4 policies, 2 builds) và 128 focused; chưa chứng minh cân bằng/cửa phản công, không có native poise interrupt trong ma trận. Không ghép vào stable.

Số file ở trên là số đường dẫn thay đổi được chọn, gồm cả UID/import sidecar, không phải tổng số file trong checkout. Nhánh PC được so với nền GitHub; các nhánh còn lại được so với nguồn PC `f36b4bc32b7fe902d0881fe50b690b5b93eb29b4` và kế thừa snapshot PC gồm 363 đường dẫn thay đổi.

Các nhánh ngoài PC cùng kế thừa 86 đường dẫn milestone opening: Runic/DOT/readability, nhịp attack-window/FIFO, mine/revisit/supply và rune prep/power/depth V2. Đây là dependency của snapshot, không phải toàn bộ tính năng đã được nghiệm thu chung. Crash native lịch sử vẫn **FAIL_UNRESOLVED**. Các tài liệu mốc cũ giữ từ nền GitHub có thể không phản ánh nguồn review hiện tại; dùng trạng thái trong README này để phân biệt.

Đây là snapshot mã nguồn, asset và test dành cho review và dựng cục bộ. Commit snapshot có thể khác commit nguồn vì chỉ mang các file đã chọn, không mang lịch sử QA riêng. Chọn đúng nhánh ở trên trong một checkout riêng; các nhánh thử nghiệm có phạm vi và dependency riêng, không phải những patch đã được kiểm khi ghép nối tiếp.

**HOLD** nghĩa là mục tiêu tương ứng còn thiếu bằng chứng hoặc chưa đạt. Mã vẫn có thể được đọc và thử trong môi trường QA, nhưng trạng thái đó không phải chấp thuận merge hay phát hành. Các mục **FAIL_UNRESOLVED** của nguồn vẫn giữ nguyên.

## Mở dự án

`project.godot` khai báo **Godot 4.7**, renderer **GL Compatibility**; runner hiện dùng tên bản **4.7.2** làm mặc định. Dùng Godot 4.7.2 để đối chiếu trước; chưa xác nhận mọi bản Godot 4 khác tương thích.

1. Tạo môi trường QA riêng trước khi mở editor hoặc chạy game: dùng tài khoản hệ điều hành QA, hoặc tiến trình có `APPDATA` và `LOCALAPPDATA` trỏ vào thư mục QA trống. Checkout riêng không tự tách `user://`.
2. Trong Godot Project Manager của môi trường đó, chọn **Import** và mở `project.godot` tại gốc nhánh. Chờ nhập asset hoàn tất rồi mở dự án. Cache `.godot` sẽ được tạo tại máy review.
3. Chỉ chơi hoặc kiểm tra bằng userdata QA. Không dùng, sao chép hay ghi đè save đang chơi; không đưa userdata và kết quả QA vào commit.

Các bước trên dành cho lúc được phép chạy editor/import. Việc chuẩn bị snapshot không tự thực hiện các bước này.

## Kiểm tra bằng runner

`tests/run_tests.ps1` dành cho PowerShell trên Windows. Đọc runner trước khi dùng; snapshot này chưa có strict gate mới. Ví dụ dưới đây dùng thư mục QA tạm mới do runner tự tạo và yêu cầu nhập đường dẫn engine đang cài:

```powershell
$reviewEngine = Read-Host 'Đường dẫn đầy đủ đến Godot 4.7.2 executable'
.\tests\run_tests.ps1 -EnginePath $reviewEngine -GameplayOnly -CheckTimeoutSeconds 60
```

Chạy từ gốc checkout. Không dựa vào đường dẫn engine mặc định của runner.

- `-GameplayOnly` chỉ bỏ nhóm import/addon đầu. Nó **vẫn chạy editor/import cho Player rig**, `asset_pipeline` và các suite đã đăng ký ở 60/120 Hz; đây không phải smoke test hay chế độ không import.
- Runner không có tham số chọn riêng một script/suite. `-CheckTimeoutSeconds` nhận 1–60 giây **cho mỗi check**, không giới hạn toàn lượt.
- Runner tự tách `APPDATA`, `LOCALAPPDATA` và `DUNGEON_QA_DATA_ROOT`, rồi khôi phục biến môi trường khi kết thúc. Có thể chỉ định `-QaDataRoot` bằng một thư mục QA mới. Log/capture vẫn được tạo dưới `docs/verification/` trong checkout.
- Mặc định dừng ở lỗi đầu. `-CollectAllFailures` tiếp tục thu lỗi rồi vẫn báo thất bại; không biến lượt lỗi thành pass.

`tests/asset_pipeline_test.gd` cần manifest, ảnh nguồn và import metadata lưu trữ ngoài snapshot. Vì vậy runner không thể vượt toàn gate nguyên trạng khi thiếu archive này, kể cả với `-GameplayOnly`. Không bổ sung save hay archive riêng vào repository để làm gate xanh. Một số test native/cold cũng cần fixture QA bên ngoài và thiết lập riêng; runner không thay thế các giao thức đó.

QA đã có trên commit nguồn chỉ là bằng chứng cho đúng commit, fixture và điều kiện đã ghi. Nó không đồng nghĩa snapshot mới đã qua strict gate, human playtest, soak, hoặc đã giải quyết các lỗi lịch sử.

## Âm thanh và provenance

Nếu nhánh có `assets/audio/recorded_combat_pair/`, giữ `SOURCES_AND_LICENSES.md` và `BUILD_MANIFEST.json` cùng đủ mười TRES. Bộ này ghi nguồn từ hai pack CC0 của artisticdude và rubberduck; xem tài liệu đi kèm để đối chiếu tác giả, URL và recipe.

Riêng nhánh `review/audio-force-20261020`, hash build cũ của **cả 10 TRES** dùng bytes CRLF, khác bytes LF được Git phân phối. Bản manifest dành cho snapshot đã cập nhật cả 10 hash theo Git LF, giữ hash CRLF dưới nhãn lịch sử và thay hai `copied_from` bằng đường dẫn tương đối kèm commit nguồn. **Không có audio blob nào thay đổi bởi bước này.** Đây là sửa metadata phân phối, không phải thêm một lần xử lý âm hoặc xác nhận đã được nghe duyệt.
