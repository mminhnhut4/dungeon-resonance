# Dungeon Resonance — TEAM TEST 25/10/2026

Bản thử source có menu chọn toàn bộ nội dung đang chạy. Godot **4.7.2**, renderer **Compatibility**. Không kèm engine binary, cache hay save. Main của dự án vẫn mở khóa theo nhiệm vụ bình thường; scene TEAM TEST là entry riêng.

## Lấy bản và chạy trên Windows

```powershell
git clone --branch team-test-20261025 --single-branch https://github.com/mminhnhut4/dungeon-resonance.git
cd dungeon-resonance
$env:GODOT_BIN = 'C:\Tools\Godot_v4.7.2-stable_win64.exe'
.\CHAY_TEAM_TEST.cmd
```

Hoặc `powershell -NoProfile -File tools/run_team_test.ps1 -EnginePath '<đường-dẫn-Godot4.7.2>'`. Launcher dùng đường dẫn tương đối theo thư mục repo và không tải/cài engine hay đổi chính sách PowerShell. Lần đầu Godot import asset có thể mất thời gian. Giữ cả source khi đổi chỗ.

**F10** mở/đóng menu, bánh xe cuộn menu. A/D chạy, Space nhảy, Shift lướt, chuột trái đánh, chuột phải cast; Tab hành trang/ghép bùa; M nhiệm vụ/bản đồ; E tương tác. Chọn map rồi bấm Mở; menu tạm dừng scene khi đang chọn.

## Phạm vi mở khóa

- **64 lựa chọn chạy được:** Hub/nhà, 12 phòng ngoài trời/môn phái và hành lang SC01; 4 chặng mở đầu, 5 tầng sâu4–8, 22 tầng9–30; các chặng Alpha/Linear/World legacy; khu luyện, lab công pháp G và5actor quái. Những chặng legacy là biến thể hiện có, không phải63map art mới.
- **21 definition vũ khí**, gồm19món chơi/bounty và2fixture training/unarmed. 10họ vũ khí có60variant quality hiện hữu; 19resource trang bị, bảy ô mặc. Có chọn quality6bậc và cường hóa+0…+12. Giữ giới hạn túi20món; nếu thử thêm fixture làm đầy túi, dỡ món qua hành trang hoặc reset slot QA.
- **5nguyên tố/18recipe**, gồm basic/single/cặp và bộ nâng cao. Menu lắp đúng multiset, tự cấp ô Catalyst QA nếu cần; vẫn có thể ghép tay bằng Tab. Nút quality Bùa/Catalyst cho thử6bậc, không sửa definition dùng chung.
- **4cổ vật** chọn riêng hoặc tắt; không tự buff preset yếu. Dịch vụ kho, học/chế bùa, sửa/rèn, cường hóa, ghép đá, dược, mua/bán, tu luyện dùng UI/owner thật tại Hub.
- Preset **Yếu/Vừa/Mạnh/Tối đa** dùng profile riêng từng preset/nhánh. Tối đa cấp các nâng cấp hiện có, Divine+12 và Trúc Cơ; chọn riêng G Hồi Phong Kiếm hoặc Tỏa Linh Ấn. Các proof mở map được ghi rõ là grant test, không là chứng minh người chơi đã kiếm được chúng.
- Tông môn quản trị/đồng hành và nội dung chỉ có ý tưởng trong tài liệu chưa thành hệ thống đầy đủ. Các nhiệm vụ/phản ứng NPC phân nhánh hiện có vẫn diễn ra qua thoại/điều kiện runtime; dùng chế độ progression riêng để kiểm thứ tự mở khóa gốc.

**Bất tử** và **mana vô hạn** mặc định TẮT. Bất tử đặt sàn HP1; mana vô hạn hồi đầy nhưng giữ cooldown. Nạp tài nguyên là nút riêng, không bắt buộc bật cheat. Thảo dược/đan dược đi qua lineage thu hoạch/chế dược, không cộng số lượng sai hợp đồng dữ liệu. Reset encounter dựng lại scene và giữ build đã lưu; không là tiếp tục combat với HP/clock cũ.

## Save và reset

Launcher TEAM TEST chỉ dùng `TeamTestData/sandbox/`; `CHAY_TIEN_TRINH_QA.cmd` dùng `TeamTestData/normal_progression/`, chơi bình thường với profile khác. Cả hai thay user directory của toàn bộ tiến trình trước autoload, không đọc/ghi save cá nhân mặc định. Không chép save cá nhân vào hai thư mục này.

Bấm **Lưu build QA** trước khi đóng nếu vừa đổi đồ bằng UI gốc. Menu preset đổi namespace; chọn lại preset nạp trạng thái đã lưu. Reset save QA tạo slot mới và giữ file slot cũ. Muốn reset hẳn chế độ, đóng game rồi chạy launcher với `-ResetProfile`: thư mục cũ được đổi tên thành backup, không xóa. Cheat trở về tắt khi khởi động/preset mới. Mở scene TEAM TEST trực tiếp trong editor không có env isolation sẽ từ chối nạp profile; hãy dùng launcher.

## Cân bằng và giới hạn

Đã áp bảng theo tầng cố định cho9–30, không scale theo loadout. Giữ14tầng encounter tùy chọn/8tầng nghỉ-bẫy và cổng không bắt clear. Nhện11 sinh3con;16/19 sinh4. Preset nhiều tiền/đồ của TEAM TEST không đại diện progression thường.

Kiểm riêng cân bằng trước gói này: 9cặp native W/S/H ở9/15/29; config/brood108, flow/save/reward181, safety136, physics95 và naturalfloor9. W29 chưa hạ miniboss trong cửa sổ20giây; không gọi mọi build đã cân bằng cuối.

TEAM TEST đã kiểm selector64lựa chọn, exact18recipe,21weapon/19equipment,4relic, preset/hai nhánh G, actual cast/contacts, reset/reload và toggle OFF; xem `TEAM_TEST_COVERAGE.md` cho phạm vi và kết quả cuối. Không là full playthrough/soak/audio audition hoặc gate strict toàn game. Khựng/IO/crash lịch sử chưa được coi đã sửa. Import đầu trong sandbox từng Safe save failed/0xC0000005, lượt sau sạch; gói này được kiểm import lại từ snapshot sạch. Rig nhân vật từ ảnh concept, một số viền sáng và asset nền tái dùng còn giới hạn art.

Asset/addon giữ các README/LICENSE/credits đi kèm. Đây là nhánh review cho team, không phải bản phát hành.

`scenes/rooms/test_room.tscn` là khung vật lý chưa có session gameplay đầy đủ, không được tính là map nội dung trong menu. Lab công pháp dùng nhánh G chọn trong menu TEAM TEST; F10 dành cho menu.

Hồi Phong Kiếm cần kiếm cổ và một lần lướt né trúng đòn vật lý; G là phản kích trong cửa sổ đó, không là phép bấm tự do. Preset tối đa Hồi Phong chọn kiếm cổ; Tỏa Linh có thể dùng trượng. Launcher tạo `.gdignore` cho TeamTestData để editor không quét save/shader cache.
