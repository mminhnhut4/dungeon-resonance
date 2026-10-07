# Traveler R3 đã tích hợp riêng vào bản chính

Ngày2026-10-04, R3 đã được reviewer chính xem và áp vào `D:/hầm ngục` trên nền2.080 source/import inputs sau tính năng trở về từng tầng. Phạm vi sản phẩm: [NpcPilotActor](../scripts/npc/npc_pilot_actor.gd) thêm đúng ba đoạn gắn [NpcTravelerWalkArt](../scripts/presentation/npc_traveler_walk_art.gd), cộng bảy file helper/UID/atlas/calibration/provenance. Không chép toàn bộ project riêng hoặc cấu hình QA. Tám file chức năng [trở về từng tầng](FLOOR_RETURN_20261004.md) giữ byte/hash nguyên vẹn.

## Hình và quyền sở hữu

Đúng NPC `pilot_traveler` ở P01 nay dùng cùng rig áo nâu/túi/tay cho walk, world idle/rest, hurt hold và downed. R2 bị giữ vì đổi sang PNG idle áo khác khi dừng/nhận hit; R3 loại bỏ việc đổi hình này. Portrait vẫn là PNG idle đã duyệt trước, hai NPC road khác giữ row idle cũ. Rig12part/14AtlasTexture regions dùng byte PNG nguồn nguyên vẹn; không tạo thêm raster.

Rest/upper-body settle0,12s bằng Transform2D; lời giải chân khi walk giữ nguyên. Hurt hold0,16s giữ hướng đang hiển thị rồi tiếp tục flee. Trong hold, root có thể tiếp tục chạy theo motor flee hiện hữu; không khẳng định foot world-lock cho mọi pose nghỉ/trúng đòn. Downed vẫn1HP và góc nghiêng actor cũ, chưa có authored animation chết mới. Art cutout vẫn tạm, chưa phải polish cuối. Giới hạn stretch chân của bằng chứng R2 còn tới khoảng16,8%; không coi R3 đã chữa hoặc cân bằng lại.

Helper là con của actor, chỉ có Sprite2D con; Hurtbox/capsule và Health/resolver/AI/social/save/schedule vẫn thuộc owner cũ. Không đổi collider/Player motor/geometry/loot/quest/Golem. Nhịp âm bước hiện hữu không được chứng minh đồng bộ chính xác với contact mới bằng scope này.

## Bằng chứng và hậu kiểm

- Tái dùng18 headless R3 và27 kiểm GPU từ producer, một GPU đã thoát sạch05:11:28UTC, PID8184. Parser producer exit0. Không chạy thêm GPU, fullsuite,120Hz hoặc loop locomotion trong tích hợp chính.
- Reviewer chính xem chín PNG ở kích thước chơi và64 frame movie được chọn từ157 frame:54–85 và118–149, gồm cặp dừng59→60, quay75→76, hit123→124. Áo/túi/tay giữ cùng hình; downed giữ cùng rig. Đây là review frame chọn và ảnh tĩnh, không là playback toàn movie hoặc human playthrough. Bốn contact sheet CPU dùng crop/phóng chỉ để QA; không sửa asset.
- Đối chiếu riêng chín function locomotion và sáu file UID/art/calibration với R2: byte/code nguyên vẹn. Actor trước áp khớp baseline14c518…, payload sau áp d607d6…. Bản render producer có trước floor-return; việc giữ nguồn mới được kiểm riêng trên main, không gọi video ấy là render của bản chính2.080/2.088 inputs.
- Sao lưu mới actor, PROJECT_STATE và nhật ký ngày04-10; diễn tập hoàn tác một file đổi và xóa bảy file mới trong workspace riêng. Import headless bản chính một lượt exit0, log không ERROR/WARNING. Hậu kiểm mới20/20 với profile cô lập: gắn R3/portrait/Hurtbox, không đổi records khi sync, P02/P03 idle cũ, cleanup, campaign first-floor retreat gửi đúng UID/đồng một lần và không mở khóa Golem/victory, remount P01 sau về sảnh.
- Sau kiểm,2.087 inputs sản phẩm khớp hash; cập nhật ba file tài liệu/nhật ký cho2.088 inputs chốt. Chỉ feature doc mới thêm; nhật ký giữ mục floor-return cũ và index ngày không đổi. Không đọc save người dùng, mở GPU hay thao tác cửa sổ người dùng; không upload/publish.

Import editor private của producer từng thoát native0xC0000005 sau quét; log lịch sử được giữ, nguyên nhân chưa rõ. Lượt import main sạch không chứng minh lỗi native này đã sửa; hậu kiểm tập trung không phải gate editor/addon/gameplay đầy đủ.

Receipt, manifest/hash, bản sao lưu và log nằm tại workspace `traveler_r3_integration_on_live2080_20261004_25`; package local kèm hình/bằng chứng tái dùng và reference tới AVI gốc. Dùng checkpoint mới nhất thay vì các handoff candidate/HOLD lịch sử.
