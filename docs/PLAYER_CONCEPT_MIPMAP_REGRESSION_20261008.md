# Player concept mask — mipmap compatibility repair

## Phạm vi và trạng thái

08/10/2026 08:47 UTC. Chỉ ở bản riêng sect-path-repair; chưa ghép main. Owner: stuck_audit. Không sửa PNG, import metadata, motor, shader hoặc gameplay. Chưa chạy engine sau sửa; chờ lane QA.

## Nguyên nhân đã xác minh

Native A/B của root xác nhận bật mipmap cho player_swordsman.png làm NPC bớt viền đen/răng cưa khi thu nhỏ. Tuy nhiên, strict R1 phát hiện đường Player concept cũ nhận Image có mip-chain: get_data() trả cả base level và mip levels nhưng build_edge_mask tạo ảnh mới với use_mipmaps=false. Kích thước buffer vì vậy không khớp (8,386,948 bytes so với 6,291,360 bytes base RGBA8). Đây là lỗi tương thích đường alpha mask, không phải nguyên nhân để tắt mipmap NPC.

## Thay đổi

PlayerVisualRig.build_edge_mask gọi clear_mipmaps() trên bản Image duplicate cục bộ trước đọc/mask base pixels. Không thay đổi Image nguồn dùng chung, Texture2D đã import hoặc PNG. Giữ output mask một base level như trước. Không dùng use_mipmaps=true vì các mip levels nguồn chưa nhận alpha mask mới.

player_art_test bổ sung input mipmapped thực và xác nhận output hợp lệ, base pixels/alpha giống input không mipmap, bounds/pivot không đổi, toàn bộ pixels và mip-chain nguồn bất biến.

## Kiểm chứng và giới hạn

Chưa chạy sau sửa tại thời điểm ghi mục này. Kết quả focused và strict tiếp theo phải được ghi sau khi thực chạy. Art NPC vẫn tái sử dụng sprite prototype, chưa chứng minh đã khớp phong cách Player modular hoặc hoàn thiện chuyển động.

## Focused kiểm chứng sau sửa

Root thực chạy 08/10/2026 khoảng 09:19 UTC trên bản riêng: player_art 40/40 và player_rig 52/52, exit 0, diagnostics rỗng. cultivator_art 89/89 là kiểm tra headless binding; native NPC riêng đạt32/32 với6ảnh, do root giữ và xem. Không gộp hai loại bằng chứng. Chưa dùng các kết quả focused này thay cho strict R2 đang chạy. Nguồn Player mask và player_art được giữ frozen sau sửa.

## Consumer fixture cập nhật sau strict R2

R2 đã qua PlayerArt và PlayerRig ở60/120, nhưng game_feel vẫn so toàn buffer nguồn có mipmap với output chỉ có base level. Fixture được sửa để so cùng định dạng RGBA8/base level và thêm xác nhận nguồn cùng toàn bộ mip-chain không đổi sau40lần thay vũ khí. Không thay runtime để khớp fixture. Focused game_feel36/36 cả60/120, exit0/diagnostics[] lúc09:37UTC. R2 vẫn giữ trạng thái FAILED do hai lỗi fixture; strict mới phải được báo riêng.